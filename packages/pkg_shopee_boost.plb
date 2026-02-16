create or replace PACKAGE BODY PKG_SHOPEE_BOOST IS


    PROCEDURE PROCESS_QUEUE (
        p_shop_id NUMBER
    )
    IS

        v_active_count      NUMBER;
        v_available_slots   NUMBER;
        v_now               DATE := SYSDATE;

        v_item_list         SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
        v_queue_ids         SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();

        v_success_list      SYS.ODCINUMBERLIST;
        v_failure_list      SYS.ODCIVARCHAR2LIST;

        v_exists            NUMBER;
        v_index             NUMBER := 0;

        ------------------------------------------------------------------
        -- mapear item_id -> queue_id
        ------------------------------------------------------------------

        TYPE t_map IS TABLE OF SHOPEE_BOOST_QUEUE.ID%TYPE INDEX BY VARCHAR2(50);
        v_map t_map;

        ------------------------------------------------------------------
        -- retry control
        ------------------------------------------------------------------

        v_retry_count NUMBER;
        v_item_id NUMBER;
        v_queue_id NUMBER;
        v_failed_reason VARCHAR2(4000);

    BEGIN

        ------------------------------------------------------------
        -- 1 Slots disponíveis (tabela já sincronizada!)
        ------------------------------------------------------------

        v_active_count := GET_ACTIVE_BOOST_COUNT(p_shop_id);
        v_available_slots := 5 - v_active_count;

        IF v_available_slots <= 0 THEN
            RETURN;
        END IF;

        ------------------------------------------------------------
        -- 2 Montar lista respeitando prioridade
        ------------------------------------------------------------

        FOR r_item IN (
            SELECT q.*
            FROM SHOPEE_BOOST_QUEUE q
            WHERE q.SHOP_ID = p_shop_id
            AND (
                    q.STATUS = 'PENDING'
                 OR q.STATUS = 'WAITING_RETRY'
                  )
            AND (q.SCHEDULED_AT IS NULL OR q.SCHEDULED_AT <= v_now)
            AND (q.NEXT_RETRY_AT IS NULL OR q.NEXT_RETRY_AT <= v_now)
            ORDER BY
                CASE q.PRIORITY_TYPE
                    WHEN 'FORCED'    THEN 1
                    WHEN 'SCHEDULED' THEN 2
                    WHEN 'RECURRING' THEN 3
                    WHEN 'QUEUE'     THEN 4
                    WHEN 'DEFAULT'   THEN 5
                    ELSE 99
                END,
                q.PRIORITY ASC,
                q.CREATED_AT ASC
        )
        LOOP

            EXIT WHEN v_index >= v_available_slots;

            -- evitar enviar item já boosted
            SELECT COUNT(*)
            INTO v_exists
            FROM SHOPEE_ACTIVE_BOOST
            WHERE SHOP_ID = p_shop_id
            AND ITEM_ID = r_item.ITEM_ID;

            IF v_exists > 0 THEN

                UPDATE SHOPEE_BOOST_QUEUE
                SET SKIP_COUNT = NVL(SKIP_COUNT,0) + 1
                WHERE ID = r_item.ID;

                CONTINUE;

            END IF;        

            v_index := v_index + 1;

            v_item_list.EXTEND;
            v_item_list(v_index) := r_item.ITEM_ID;

            v_map(TO_CHAR(r_item.ITEM_ID)) := r_item.ID;

        END LOOP;

        IF v_item_list.COUNT = 0 THEN
            RETURN;
        END IF;

        ------------------------------------------------------------
        -- 3 Executar boost em lote
        ------------------------------------------------------------

        PKG_SHOPEE_PRODUCT.BOOST_ITEMS(
            p_shop_id      => p_shop_id,
            p_item_id_list => v_item_list,
            p_success_list => v_success_list,
            p_failure_list => v_failure_list
        );

        ------------------------------------------------------------
        -- 4 Tratar SUCESSOS
        ------------------------------------------------------------

        IF v_success_list IS NOT NULL THEN

            FOR i IN 1 .. v_success_list.COUNT
            LOOP

                v_item_id := v_success_list(i);
                IF v_map.EXISTS(TO_CHAR(v_item_id)) THEN
                    v_queue_id := v_map(TO_CHAR(v_item_id));
                ELSE
                    CONTINUE;
                END IF;

                ----------------------------------------------------------
                -- registrar ativo
                ----------------------------------------------------------

                BEGIN
                    INSERT INTO SHOPEE_ACTIVE_BOOST (

                        SHOP_ID,
                        ITEM_ID,
                        END_TIME,
                        UPDATED_AT

                    )
                    VALUES (

                        p_shop_id,
                        v_item_id,
                        v_now + (241/1440),
                        v_now

                    );
                    EXCEPTION
                        WHEN DUP_VAL_ON_INDEX THEN NULL;
                END;

                ----------------------------------------------------------
                -- atualizar fila
                ----------------------------------------------------------

                UPDATE SHOPEE_BOOST_QUEUE
                SET
                    STATUS = 'PROCESSED',
                    EXECUTED_AT = v_now,
                    ERROR_MESSAGE = NULL
                WHERE ID = v_queue_id;

            END LOOP;

        END IF;

        ------------------------------------------------------------------
        -- 5 processar falhas com retry inteligente
        ------------------------------------------------------------------

        IF v_failure_list IS NOT NULL THEN

            FOR i IN 1 .. v_failure_list.COUNT
            LOOP

                ------------------------------------------------------------------
                -- formato esperado: "item_id|failed_reason"
                ------------------------------------------------------------------

                v_item_id :=
                    TO_NUMBER(
                        SUBSTR(
                            v_failure_list(i),
                            1,
                            INSTR(v_failure_list(i),'|') - 1
                        )
                    );

                v_failed_reason :=
                    SUBSTR(
                        v_failure_list(i),
                        INSTR(v_failure_list(i),'|') + 1
                    );

                IF v_map.EXISTS(TO_CHAR(v_item_id)) THEN
                    v_queue_id := v_map(TO_CHAR(v_item_id));
                ELSE
                    CONTINUE;
                END IF;

                ----------------------------------------------------------
                -- obter retry atual
                ----------------------------------------------------------

                SELECT NVL(RETRY_COUNT,0)
                INTO v_retry_count
                FROM SHOPEE_BOOST_QUEUE
                WHERE ID = v_queue_id;

                ----------------------------------------------------------
                -- retry inteligente
                ----------------------------------------------------------

                IF v_failed_reason LIKE '%boost item repeatedly%'
                AND v_retry_count < 10
                THEN

                    UPDATE SHOPEE_BOOST_QUEUE
                    SET
                        STATUS = 'WAITING_RETRY',
                        RETRY_COUNT = v_retry_count + 1,
                        NEXT_RETRY_AT = v_now + (4/24),
                        ERROR_MESSAGE = v_failed_reason
                    WHERE ID = v_queue_id;

                ELSE

                    UPDATE SHOPEE_BOOST_QUEUE
                    SET
                        STATUS = 'ERROR',
                        ERROR_MESSAGE = v_failed_reason,
                        EXECUTED_AT = v_now
                    WHERE ID = v_queue_id;

                END IF;

            END LOOP;

        END IF;

    END PROCESS_QUEUE;


    PROCEDURE FORCE_BOOST (
        p_shop_id NUMBER,
        p_item_id NUMBER
    )
    IS
    BEGIN

        INSERT INTO SHOPEE_BOOST_QUEUE (
            SHOP_ID,
            ITEM_ID,
            STATUS,
            PRIORITY_TYPE,
            PRIORITY,
            SCHEDULED_AT
        )
        VALUES (
            p_shop_id,
            p_item_id,
            'PENDING',
            'FORCED',
            1,
            SYSDATE
        );

        COMMIT;

    END;
    

    FUNCTION IS_BOOST_ENABLED (
        p_shop_id IN NUMBER
    ) RETURN BOOLEAN
    IS
        v_enabled CHAR(1);
    BEGIN

        SELECT BOOST_ENABLED
        INTO v_enabled
        FROM SHOPEE_CONFIG
        WHERE SHOP_ID = p_shop_id;

        RETURN v_enabled = 'Y';

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END;


    FUNCTION GET_ACTIVE_BOOST_COUNT (
        p_shop_id NUMBER
    )
    RETURN NUMBER
    IS
        v_count NUMBER;
    BEGIN

        SELECT COUNT(*)
        INTO v_count
        FROM SHOPEE_ACTIVE_BOOST
        WHERE SHOP_ID = p_shop_id
        AND END_TIME > SYSDATE;

        RETURN v_count;

    EXCEPTION
        WHEN OTHERS THEN

            -- Segurança: nunca quebrar o motor
            RETURN 0;

    END GET_ACTIVE_BOOST_COUNT;


    PROCEDURE RUN_BOOST_CYCLE
    IS

        /**
         * Cursor com todas as shops cadastradas
         */
        CURSOR c_shops IS
            SELECT DISTINCT SHOP_ID
            FROM SHOPEE_USER_SESSION
            WHERE SHOP_ID IS NOT NULL;

    BEGIN

        ------------------------------------------------------------------
        -- Percorrer todas as shops
        ------------------------------------------------------------------

        FOR r_shop IN c_shops LOOP

            BEGIN

                ------------------------------------------------------------------
                -- 1 Garantir que boost está habilitado
                ------------------------------------------------------------------
                -- Verifica se o boost automático está habilitado para a shop
                --
                -- Caso NÃO esteja habilitado, o comando CONTINUE faz com que
                -- o loop ignore completamente esta shop e passe para a próxima,
                -- sem executar nenhuma lógica de boost.
                --
                -- Isso permite que o usuário pause ou desative o boost sem
                -- precisar parar o scheduler ou alterar a infraestrutura.
                --
                -- Exemplo:
                --
                -- SHOP_ID 1001 → BOOST_ENABLED = Y → executa boost
                -- SHOP_ID 1002 → BOOST_ENABLED = N → CONTINUE → ignora shop
                -- SHOP_ID 1003 → BOOST_ENABLED = Y → executa boost
                --
                -- Essa abordagem garante controle total via configuração e
                -- evita chamadas desnecessárias à API da Shopee.
                ------------------------------------------------------------------
                IF NOT IS_BOOST_ENABLED(r_shop.SHOP_ID) THEN
                    CONTINUE; -- pula para próximo loop
                END IF;


                ------------------------------------------------------------------
                -- 2 Sincronizar boosts ativos com Shopee (OBRIGATÓRIO)
                ------------------------------------------------------------------

                SYNC_ACTIVE_BOOSTS(
                    p_shop_id => r_shop.SHOP_ID
                );

                ------------------------------------------------------------------
                -- 3 Processar fila com dados sincronizados
                ------------------------------------------------------------------

                PROCESS_QUEUE(
                    p_shop_id => r_shop.SHOP_ID
                );

            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;

        END LOOP;

    END RUN_BOOST_CYCLE;


    PROCEDURE SYNC_ACTIVE_BOOSTS (
        p_shop_id NUMBER
    )
    IS

        v_response      CLOB;
        v_now           DATE := SYSDATE;

    BEGIN

        ------------------------------------------------------------
        -- 1 Validar parâmetro
        ------------------------------------------------------------

        IF p_shop_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20020,
                'SYNC_ACTIVE_BOOSTS: p_shop_id cannot be null'
            );
        END IF;

        ------------------------------------------------------------
        -- 2 Obter lista de boosts ativos da Shopee
        ------------------------------------------------------------

        v_response :=
            PKG_SHOPEE_PRODUCT.GET_ITEM_BOOSTED_LIST(
                p_shop_id => p_shop_id
            );

        IF v_response IS NULL THEN
            RETURN;
        END IF;

        ------------------------------------------------------------
        -- 3 Remover todos boosts atuais (serão reinseridos)
        ------------------------------------------------------------

        DELETE FROM SHOPEE_ACTIVE_BOOST
        WHERE SHOP_ID = p_shop_id;

        ------------------------------------------------------------
        -- 4 Inserir boosts retornados pela API
        ------------------------------------------------------------

        INSERT INTO SHOPEE_ACTIVE_BOOST (
            SHOP_ID,
            ITEM_ID,
            END_TIME,
            UPDATED_AT
        )
        SELECT
            p_shop_id,
            jt.item_id,
            DATE '1970-01-01' + (jt.end_time / 86400),
            v_now
        FROM JSON_TABLE(
            v_response,
            '$.response.boosted_item_list[*]'
            COLUMNS (
                item_id   NUMBER PATH '$.item_id',
                end_time  NUMBER PATH '$.end_time'
            )
        ) jt;

        COMMIT;

    EXCEPTION

        WHEN OTHERS THEN

            RAISE_APPLICATION_ERROR(
                -20021,
                'SYNC_ACTIVE_BOOSTS failed: ' || SQLERRM
            );

    END SYNC_ACTIVE_BOOSTS;

END PKG_SHOPEE_BOOST;
/