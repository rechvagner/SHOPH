create or replace PACKAGE PKG_SHOPEE_BOOST IS

    /**
     * @package PKG_SHOPEE_BOOST
     *
     * @author Vagner Rech
     * @since 1.0.0 (15/02/2026)
     *
     * @description
     * Motor de automação de Boost de produtos da Shopee.
     *
     * Este package é responsável por gerenciar toda a lógica de boost automático,
     * incluindo:
     *
     * - Execução automática de boost respeitando limite da Shopee
     * - Gerenciamento de fila de boost
     * - Execução de boost agendado
     * - Execução de boost recorrente
     * - Execução de boost forçado (priority override)
     * - Fallback automático usando produtos padrão
     * - Validação de boost ativo antes de executar novo boost
     *
     * O motor é projetado para execução automatizada via DBMS_SCHEDULER,
     * podendo operar continuamente sem intervenção manual.
     *
     * @architecture
     * Boost Automation Layer
     *
     * @dependencies
     * Database Objects:
     * - SHOPEE_BOOST_QUEUE
     * - SHOPEE_BOOST_DEFAULT
     * - SHOPEE_ACTIVE_BOOST
     *
     * Internal Packages:
     * - PKG_SHOPEE_AUTH
     *
     * External Services:
     * - Shopee Open Platform API v2
     *
     * @usedby
     * - Oracle APEX UI
     * - DBMS_SCHEDULER Jobs
     *
     */


    /**
     * @procedure PROCESS_QUEUE
     *
     * @description
     * Processa a fila de boost da Shopee para uma determinada loja.
     *
     * Esta procedure executa o motor principal de boost, realizando:
     *
     * 1. Consulta os boosts atualmente ativos na Shopee
     * 2. Calcula quantos slots de boost estão disponíveis
     * 3. Busca os próximos itens elegíveis da fila, respeitando prioridade:
     *
     *    PRIORITY_TYPE order:
     *
     *    FORCED     → maior prioridade
     *    SCHEDULED
     *    RECURRING
     *    QUEUE
     *    DEFAULT    → menor prioridade
     *
     * 4. Ignora itens que já possuem boost ativo
     * 5. Executa boost nos itens elegíveis
     * 6. Atualiza status da fila
     *
     * Esta procedure é segura para execução recorrente via DBMS_SCHEDULER.
     *
     * @param p_shop_id NUMBER
     * ID da loja Shopee que terá a fila processada
     *
     * @example
     * PKG_SHOPEE_BOOST.PROCESS_QUEUE(123456);
     *
     * @since 1.0.0
     */
    PROCEDURE PROCESS_QUEUE (
        p_shop_id NUMBER
    );



    /**
     * @procedure FORCE_BOOST
     *
     * @description
     * Insere um item na fila com prioridade máxima (FORCED),
     * garantindo que ele será o próximo boost executado.
     *
     * Este método é utilizado pelo botão "Forçar Boost" na interface APEX.
     *
     * O item inserido:
     *
     * - STATUS = PENDING
     * - PRIORITY_TYPE = FORCED
     * - PRIORITY = 1
     * - SCHEDULED_AT = SYSDATE
     *
     * O motor PROCESS_QUEUE sempre prioriza itens FORCED antes de todos os outros.
     *
     * @param p_shop_id NUMBER
     * ID da loja Shopee
     *
     * @param p_item_id NUMBER
     * ID do produto Shopee que será boosted
     *
     * @example
     * PKG_SHOPEE_BOOST.FORCE_BOOST(
     *     p_shop_id => 123456,
     *     p_item_id => 987654321
     * );
     *
     * @since 1.0.0
     */
    PROCEDURE FORCE_BOOST (
        p_shop_id NUMBER,
        p_item_id NUMBER
    );

    /**
     * Verifica se a automação de boost está habilitada
     * para a shop ativa.
     *
     * @return BOOLEAN
     *         TRUE  - boost habilitado
     *         FALSE - boost desabilitado
     */
    FUNCTION IS_BOOST_ENABLED (
        p_shop_id IN NUMBER
    )
    RETURN BOOLEAN;

    /**
     * @function GET_ACTIVE_BOOST_COUNT
     *
     * @description
     * Retorna a quantidade de boosts atualmente ativos
     * para uma determinada loja Shopee.
     *
     * Um boost é considerado ativo quando:
     *
     *     END_TIME > SYSDATE
     *
     * Esta função é utilizada pelo motor de boost para calcular
     * quantos novos boosts podem ser executados, respeitando
     * o limite máximo de 5 boosts simultâneos da Shopee.
     *
     * @param p_shop_id NUMBER
     * ID da loja Shopee
     *
     * @return NUMBER
     * Quantidade de boosts ativos no momento
     *
     * @example
     * v_count := PKG_SHOPEE_BOOST.GET_ACTIVE_BOOST_COUNT(123456);
     *
     * @since 1.0.0
     */
    FUNCTION GET_ACTIVE_BOOST_COUNT (
        p_shop_id NUMBER
    )
    RETURN NUMBER;

    /**
     * Executa o ciclo automático de Boost para todas as shops
     * cadastradas na tabela SHOPEE_USER_SESSION.
     *
     * Fluxo:
     * 1. Percorre todas as shops vinculadas a usuários.
     * 2. Verifica se o boost automático está habilitado.
     * 3. (Futuro) Sincroniza boosts ativos via API.
     * 4. (Futuro) Calcula slots disponíveis.
     * 5. (Futuro) Executa novos boosts.
     *
     * Esta procedure é projetada para execução via
     * DBMS_SCHEDULER e não depende de sessão APEX.
     *
     * @raises
     *   Não propaga exceções individuais por shop.
     *   Erros são tratados internamente para não interromper
     *   o processamento das demais shops.
     */
    PROCEDURE RUN_BOOST_CYCLE;

    /**
     * @procedure SYNC_ACTIVE_BOOSTS
     *
     * @description
     * Sincroniza os boosts ativos da Shopee com a tabela local SHOPEE_ACTIVE_BOOST.
     *
     * Esta procedure consulta a API:
     *
     *    /api/v2/product/get_boosted_list
     *
     * e atualiza a tabela local para refletir exatamente o estado atual da Shopee.
     *
     * Comportamento:
     *
     * 1. Busca lista de itens com boost ativo via API
     * 2. Insere novos boosts que ainda não existem localmente
     * 3. Atualiza END_TIME dos boosts existentes
     * 4. Remove boosts que não estão mais ativos
     *
     * Isso garante que boosts feitos manualmente pelo usuário também sejam reconhecidos.
     *
     * @param p_shop_id NUMBER
     *        ID da loja Shopee
     *
     * @example
     * PKG_SHOPEE_BOOST.SYNC_ACTIVE_BOOSTS(123456);
     *
     * @since 1.0.0
     */
    PROCEDURE SYNC_ACTIVE_BOOSTS (
        p_shop_id NUMBER
    );


END PKG_SHOPEE_BOOST;
/