create or replace PACKAGE BODY                    PKG_SHOPEE_AUTH IS

    -- ==========================================================
    -- CONFIGURAÇÕES GLOBAIS DA SUA APLICAÇÃO (FIXAS)
    -- ==========================================================
    --c_partner_id   CONSTANT NUMBER        := 1218643;
    c_partner_key  CONSTANT VARCHAR2(200) := 'shpk4c4d4654437a44525446576c6e4e79626d75615574686d7777494b744b48'; 
    c_redirect_url CONSTANT VARCHAR2(500) := 'https://g52f6de2b11ee34-shophapex.adb.sa-saopaulo-1.oraclecloudapps.com/ords/wksp_shophapex/shoph/oauth';

    -- Define o ambiente atual
    FUNCTION GET_SHOPEE_API_BASE_URL RETURN VARCHAR2 IS
    BEGIN
        -- Certifique-se de que suas chaves c_partner_id/key são do ambiente TEST STABLE
        RETURN 'https://openplatform.sandbox.test-stable.shopee.sg'; 
    END;

    FUNCTION GENERATE_SHOPEE_AUTH_URL RETURN VARCHAR2 IS
        l_path VARCHAR2(50) := '/api/v2/shop/auth_partner';
        l_sign VARCHAR2(200);
        l_timestamp NUMBER := GET_TIMESTAMP;

    BEGIN
        -- 1. Gerar Assinatura para Public API
        l_sign := GENERATE_PUBLIC_API_SIGN(l_path, l_timestamp);

        -- 2. Montar URL para o ambiente test-stable
        RETURN GET_SHOPEE_API_BASE_URL() || l_path || 
                 '?partner_id=' || TO_CHAR(c_partner_id) || 
                 '&timestamp='  || TO_CHAR(l_timestamp) || 
                 '&sign='       || l_sign ||
                 '&redirect='   || c_redirect_url;
    END;

    FUNCTION GET_TIMESTAMP RETURN NUMBER IS
    BEGIN
        RETURN FLOOR((SYSDATE - DATE '1970-01-01') * 86400);
    END;


    -- ==========================================================
    -- 1. GENERATE_PUBLIC_API_SIGN: ALINHADO COM JAVA (Public APIs)
    -- ==========================================================
    FUNCTION GENERATE_PUBLIC_API_SIGN (p_path IN VARCHAR2, p_timestamp IN NUMBER) RETURN VARCHAR2 IS
        l_base VARCHAR2(4000);
    BEGIN
        -- A concatenação deve ser rigorosa: sem espaços ou caracteres ocultos
        l_base := TO_CHAR(c_partner_id) || p_path || TO_CHAR(p_timestamp);

        RETURN LOWER(RAWTOHEX(DBMS_CRYPTO.MAC(
            src => UTL_I18N.STRING_TO_RAW(l_base, 'AL32UTF8'),
            typ => DBMS_CRYPTO.HMAC_SH256,
            key => UTL_I18N.STRING_TO_RAW(c_partner_key, 'AL32UTF8')
        )));
    END;

    -- ==========================================================
    -- 2. GENERATE_AUTHENTICATED_API_SIGN: ALINHADO COM GUIA 20 (Shop APIs)
    -- ==========================================================
    FUNCTION GENERATE_AUTHENTICATED_API_SIGN (p_path IN VARCHAR2, p_timestamp IN NUMBER, p_access_token IN VARCHAR2, p_shop_id IN NUMBER) RETURN VARCHAR2 IS
        l_base VARCHAR2(4000);
    BEGIN
        l_base := TO_CHAR(c_partner_id) || p_path || TO_CHAR(p_timestamp) || p_access_token || TO_CHAR(p_shop_id);

        RETURN LOWER(RAWTOHEX(DBMS_CRYPTO.MAC(
            src => UTL_I18N.STRING_TO_RAW(l_base, 'AL32UTF8'),
            typ => DBMS_CRYPTO.HMAC_SH256,
            key => UTL_I18N.STRING_TO_RAW(c_partner_key, 'AL32UTF8')
        )));
    END;

    -- ==========================================================
    -- OBTENÇÃO DO TOKEN
    -- ==========================================================
    PROCEDURE AUTH_GET_TOKEN (p_code IN VARCHAR2, p_shop_id IN NUMBER) IS
        l_path      VARCHAR2(100) := '/api/v2/auth/token/get';
        l_timestamp NUMBER := GET_TIMESTAMP;
        l_sign      VARCHAR2(200);
        l_response  CLOB;
        l_url       VARCHAR2(1000);
        l_body      VARCHAR2(1000);
    BEGIN
        -- 1. Gerar Assinatura para Public API
        l_sign := GENERATE_PUBLIC_API_SIGN(l_path, l_timestamp);

        -- 2. Montar URL para o ambiente test-stable
        l_url := GET_SHOPEE_API_BASE_URL() || l_path || 
                 '?partner_id=' || TO_CHAR(c_partner_id) || 
                 '&timestamp='  || TO_CHAR(l_timestamp) || 
                 '&sign='       || l_sign;

        -- 3. Body: Seguindo o padrão do seu teste no console
        -- Se falhar com o body completo, use apenas {"code":"'||p_code||'"}
        l_body := '{"code":"' || p_code || '","shop_id":' || TO_CHAR(p_shop_id) || ',"partner_id":' || TO_CHAR(c_partner_id) || '}';

        -- Limpeza de Headers para evitar conflitos
        apex_web_service.g_request_headers.delete();
        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';

        -- 4. Execução da Chamada
        l_response := apex_web_service.make_rest_request(
            p_url         => l_url,
            p_http_method => 'POST',
            p_body        => l_body
        );

        DBMS_OUTPUT.PUT_LINE('PKG_SHOPEE_AUTH.AUTH_GET_TOKEN response:');
        DBMS_OUTPUT.PUT_LINE(l_response);

        -- 5. Processamento do Retorno
        apex_json.parse(l_response);
        
        IF apex_json.get_varchar2('access_token') IS NOT NULL THEN
            MERGE INTO SHOPEE_CONFIG t
            USING dual ON (t.SHOP_ID = p_shop_id)
            WHEN MATCHED THEN
                UPDATE SET t.ACCESS_TOKEN   = apex_json.get_varchar2('access_token'),
                           t.REFRESH_TOKEN  = apex_json.get_varchar2('refresh_token'),
                           t.TOKEN_EXPIRA_EM = SYSDATE + (apex_json.get_number('expire_in')/86400)
            WHEN NOT MATCHED THEN
                INSERT (SHOP_ID, ACCESS_TOKEN, REFRESH_TOKEN, TOKEN_EXPIRA_EM)
                VALUES (p_shop_id, apex_json.get_varchar2('access_token'), apex_json.get_varchar2('refresh_token'), 
                        SYSDATE + (apex_json.get_number('expire_in')/86400));
            COMMIT;

            -- Associa o usuário ao shop_id
            SET_USER_SHOP(V('APP_USER'), p_shop_id);
        ELSE
            -- Se der erro, lançamos o JSON completo da Shopee para diagnóstico
            RAISE_APPLICATION_ERROR(-20001, 'Shopee Response: ' || l_response);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            -- Garante que o erro suba para o APEX para você visualizar no log
            RAISE;
    END;

    -- ==========================================================
    -- REFRESH TOKEN (Também usa SIGN_AUTH conforme seu Java)
    -- ==========================================================
    PROCEDURE REFRESH_TOKEN (p_shop_id IN NUMBER) IS
        l_path          VARCHAR2(100) := '/api/v2/auth/access_token/get';
        l_timestamp     NUMBER := GET_TIMESTAMP;
        l_refresh_token VARCHAR2(500);
        l_sign          VARCHAR2(200);
        l_response      CLOB;
    BEGIN
        SELECT refresh_token INTO l_refresh_token FROM SHOPEE_CONFIG WHERE shop_id = p_shop_id;

        l_sign := GENERATE_PUBLIC_API_SIGN(l_path, l_timestamp);

        apex_web_service.g_request_headers.delete();
        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';

        l_response := apex_web_service.make_rest_request(
            p_url         => GET_SHOPEE_API_BASE_URL() || l_path || '?partner_id='||c_partner_id||'&timestamp='||l_timestamp||'&sign='||l_sign,
            p_http_method => 'POST',
            p_body        => '{"refresh_token":"'||l_refresh_token||'","shop_id":'||p_shop_id||',"partner_id":'||c_partner_id||'}'
        );

        dbms_output.put_line('PKG_SHOPEE_AUTH.REFRESH_TOKEN response:');
        dbms_output.put_line(l_response);

        apex_json.parse(l_response);
        
        IF apex_json.get_varchar2('access_token') IS NOT NULL THEN
            UPDATE SHOPEE_CONFIG SET 
                ACCESS_TOKEN    = apex_json.get_varchar2('access_token'),
                REFRESH_TOKEN   = apex_json.get_varchar2('refresh_token'),
                TOKEN_EXPIRA_EM = SYSDATE + (apex_json.get_number('expire_in')/86400)
            WHERE shop_id = p_shop_id;
            COMMIT;
        ELSE
            DELETE FROM shopee_config WHERE shop_id = p_shop_id;
            COMMIT;

            RAISE_APPLICATION_ERROR(-20002, 'Login Shopee expirado. Reautorização necessária.');
        END IF;
    END;

    -- ==========================================================
    -- Retorna sempre um token válido.
    -- ==========================================================
    FUNCTION GET_VALID_ACCESS_TOKEN (
        p_shop_id NUMBER
    ) RETURN VARCHAR2
    IS

        l_access_token VARCHAR2(500);
        l_expira_em    DATE;

    BEGIN

        SELECT access_token, token_expira_em
        INTO l_access_token, l_expira_em
        FROM shopee_config
        WHERE shop_id = p_shop_id;

        -- margem de segurança de 5 minutos
        IF l_expira_em <= SYSDATE + (5/1440) THEN

            -- refresh automático
            REFRESH_TOKEN(p_shop_id);

            -- buscar novo token
            SELECT access_token
            INTO l_access_token
            FROM shopee_config
            WHERE shop_id = p_shop_id;

        END IF;

        RETURN l_access_token;

    END;

    -- ==========================================================
    -- Invalida o token da shop_id
    -- ==========================================================
    PROCEDURE LOGOUT (
        p_shop_id NUMBER
    )
    IS
    BEGIN

        DELETE FROM shopee_config
        WHERE shop_id = p_shop_id;

        COMMIT;

    END;

    -- ==========================================================
    -- Associa usuário (sempre APEX) a um shop_id
    -- ==========================================================
    PROCEDURE SET_USER_SHOP (
        p_username VARCHAR2,
        p_shop_id  NUMBER
    )
    IS
    BEGIN

        MERGE INTO SHOPEE_USER_SESSION t
        USING (
            SELECT
                UPPER(p_username) username,
                p_shop_id shop_id
            FROM dual
        ) src
        ON (t.username = src.username)

        WHEN MATCHED THEN
            UPDATE SET
                t.shop_id    = src.shop_id,
                t.updated_at = SYSDATE

        WHEN NOT MATCHED THEN
            INSERT (
                username,
                shop_id,
                created_at,
                updated_at
            )
            VALUES (
                src.username,
                src.shop_id,
                SYSDATE,
                SYSDATE
            );

    END SET_USER_SHOP;

    -- ==========================================================
    -- Retorna o shop_id vinculado a um usuário
    -- ==========================================================
    FUNCTION GET_USER_SHOP_ID (
        p_username VARCHAR2
    )
    RETURN NUMBER
    IS

        l_shop_id NUMBER;

    BEGIN

        SELECT shop_id
        INTO l_shop_id
        FROM SHOPEE_USER_SESSION
        WHERE username = UPPER(p_username);

        RETURN l_shop_id;

    EXCEPTION

        WHEN NO_DATA_FOUND THEN

            RAISE_APPLICATION_ERROR(
                -20010,
                'Usuário não possui shop vinculada: ' || p_username
            );

    END GET_USER_SHOP_ID;

    -- ==========================================================
    -- Obtem o shop_id do usuário (APEX) da sessão
    -- ==========================================================
    FUNCTION GET_CURRENT_SHOP_ID
    RETURN NUMBER
    IS

        l_username VARCHAR2(255);
        l_shop_id  NUMBER;

    BEGIN

        l_username := V('APP_USER');

        IF l_username IS NULL THEN

            RAISE_APPLICATION_ERROR(
                -20011,
                'Nenhum usuário APEX autenticado.'
            );

        END IF;


        l_shop_id := GET_USER_SHOP_ID(l_username);

        RETURN l_shop_id;

    END GET_CURRENT_SHOP_ID;

    -- ==========================================================
    -- Remove o vinculo de um usuário com um shop_id
    -- ==========================================================
    PROCEDURE CLEAR_USER_SHOP (
        p_username VARCHAR2
    )
    IS
    BEGIN

        DELETE FROM SHOPEE_USER_SESSION
        WHERE username = UPPER(p_username);

    END CLEAR_USER_SHOP;

END PKG_SHOPEE_AUTH;
/