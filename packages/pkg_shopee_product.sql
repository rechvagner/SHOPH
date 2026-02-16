create or replace PACKAGE PKG_SHOPEE_PRODUCT IS

    /**
     * @package PKG_SHOPEE_PRODUCT
     *
     * @author Vagner Rech
     * @since 1.0.0 (16/02/2026)
     *
     * @description
     * Package responsável por operações relacionadas a produtos Shopee.
     *
     * Inclui:
     *
     * - Execução de Boost de produto
     * - Consulta de produtos com boost ativo
     *
     * Todas as operações utilizam Shopee Open Platform API v2.
     *
     */


    /**
     * @procedure BOOST_ITEMS
     *
     * @description
     * Executa boost em múltiplos produtos em uma única chamada à API da Shopee.
     *
     * Esta procedure envia uma lista de item_ids para o endpoint
     * /api/v2/product/boost_item e retorna separadamente os itens que tiveram
     * boost realizado com sucesso e os que falharam.
     *
     * A Shopee permite boost em lote, respeitando o limite de slots disponíveis.
     *
     * IMPORTANTE:
     * - Esta procedure NÃO controla slots disponíveis. O chamador deve garantir isso.
     * - Esta procedure NÃO faz retry automático.
     * - Esta procedure NÃO altera tabelas locais.
     * - Apenas executa a chamada API e retorna o resultado.
     *
     * @param p_shop_id IN NUMBER
     * ID da loja na Shopee.
     *
     * @param p_item_id_list IN SYS.ODCINUMBERLIST
     * Lista de item_ids que devem receber boost.
     *
     * @param p_success_list OUT SYS.ODCINUMBERLIST
     * Lista de item_ids que receberam boost com sucesso.
     *
     * Sempre inicializada.
     * Pode retornar vazia se nenhum item teve sucesso.
     *
     * Exemplo de retorno:
     * SYS.ODCINUMBERLIST(111, 222)
     *
     * @param p_failure_list OUT SYS.ODCIVARCHAR2LIST
     * Lista de falhas no formato:
     *
     * item_id|failed_reason
     *
     * Exemplo:
     * SYS.ODCIVARCHAR2LIST(
     *     '333|can not boost item repeatedly',
     *     '444|item not found'
     * )
     *
     * Pode retornar vazia se não houver falhas.
     *
     * @raises -20001
     * SHOP_ID cannot be null
     *
     * @raises -20003
     * Access token not found
     *
     * @raises -20010
     * Empty response from Shopee API
     *
     * @raises -20011
     * Shopee API error returned
     *
     * @raises -20020
     * Unexpected internal error during execution
     *
     * @example
     *
     * DECLARE
     *     v_success SYS.ODCINUMBERLIST;
     *     v_failure SYS.ODCIVARCHAR2LIST;
     * BEGIN
     *
     *     PKG_SHOPEE_PRODUCT.BOOST_ITEMS(
     *         p_shop_id        => 123456,
     *         p_item_id_list   => SYS.ODCINUMBERLIST(111,222,333),
     *         p_success_list   => v_success,
     *         p_failure_list   => v_failure
     *     );
     *
     *     DBMS_OUTPUT.PUT_LINE('SUCCESS COUNT: ' || v_success.COUNT);
     *     DBMS_OUTPUT.PUT_LINE('FAIL COUNT: ' || v_failure.COUNT);
     *
     * END;
     *
     * @example expected response Shopee
     *
     * {
     *   "error": "",
     *   "message": "",
     *   "response": {
     *     "success_list": {
     *       "item_id_list": [111, 222]
     *     },
     *     "failure_list": [
     *       {
     *         "item_id": 333,
     *         "failed_reason": "can not boost item repeatedly"
     *       }
     *     ]
     *   }
     * }
     *
     * @author
     * Vagner Rech
     *
     * @since 1.0
     *
     * @version 2.0
     * Updated to support success_list and failure_list output parameters.
     *
     */
    PROCEDURE BOOST_ITEMS (
        p_shop_id        IN  NUMBER,
        p_item_id_list   IN  SYS.ODCINUMBERLIST,
        p_success_list   OUT SYS.ODCINUMBERLIST,
        p_failure_list   OUT SYS.ODCIVARCHAR2LIST
    );


    /**
     * @function GET_ITEM_BOOSTED_LIST
     *
     * @description
     * Consulta lista de itens com boost ativo na Shopee.
     *
     * @param p_shop_id NUMBER
     *
     * @return CLOB JSON response da API Shopee
     *
     */
    FUNCTION GET_ITEM_BOOSTED_LIST (
        p_shop_id NUMBER
    )
    RETURN CLOB;


END PKG_SHOPEE_PRODUCT;
/