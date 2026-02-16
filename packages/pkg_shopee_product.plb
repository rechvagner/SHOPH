create or replace PACKAGE BODY PKG_SHOPEE_PRODUCT IS


    PROCEDURE BOOST_ITEMS (
        p_shop_id        IN  NUMBER,
        p_item_id_list   IN  SYS.ODCINUMBERLIST,
        p_success_list   OUT SYS.ODCINUMBERLIST,
        p_failure_list   OUT SYS.ODCIVARCHAR2LIST
    )
    IS

        v_path VARCHAR2(500) := '/api/v2/product/boost_item';

        v_access_token VARCHAR2(500);

        v_timestamp NUMBER := PKG_SHOPEE_AUTH.GET_TIMESTAMP;

        v_url VARCHAR2(4000);

        v_response CLOB;

        v_body CLOB;

        v_json_list VARCHAR2(4000);

    BEGIN

        ------------------------------------------------------------
        -- 1 Validar parâmetros
        ------------------------------------------------------------

        IF p_shop_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'SHOP_ID cannot be null');
        END IF;

        IF p_item_id_list.COUNT = 0 THEN
            RETURN;
        END IF;

        ------------------------------------------------------------
        -- 2 Obter access token válido
        ------------------------------------------------------------

        v_access_token :=
            PKG_SHOPEE_AUTH.GET_VALID_ACCESS_TOKEN(p_shop_id);

        IF v_access_token IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20003,
                'Access token not found for shop_id ' || p_shop_id
            );
        END IF;


        ------------------------------------------------------------
        -- 3 montar lista JSON
        ------------------------------------------------------------

        FOR i IN 1..p_item_id_list.COUNT LOOP

            IF i > 1 THEN
                v_json_list := v_json_list || ',';
            END IF;

            v_json_list := v_json_list || p_item_id_list(i);

        END LOOP;


        ------------------------------------------------------------
        -- 4 Montar URL autenticada
        ------------------------------------------------------------

        v_url :=
            PKG_SHOPEE_AUTH.GET_SHOPEE_API_BASE_URL ||
            v_path ||
            '?access_token=' || v_access_token ||
            '&shop_id=' || p_shop_id ||
            '&partner_id=' || PKG_SHOPEE_AUTH.c_partner_id ||
            '&timestamp=' || v_timestamp ||
            '&sign=' ||
            PKG_SHOPEE_AUTH.GENERATE_AUTHENTICATED_API_SIGN(
                p_shop_id      => p_shop_id,
                p_path         => v_path,
                p_timestamp    => v_timestamp,
                p_access_token => v_access_token
            );


        ------------------------------------------------------------
        -- 5 Montar BODY JSON
        ------------------------------------------------------------

        v_body :=
            '{ "item_id_list": [' || v_json_list || '] }';


        ------------------------------------------------------------
        -- 6 Chamada REST POST
        ------------------------------------------------------------

        APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE;

        APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).NAME := 'Content-Type';
        APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).VALUE := 'application/json';

        v_response :=
            APEX_WEB_SERVICE.MAKE_REST_REQUEST(
                p_url         => v_url,
                p_http_method => 'POST',
                p_body        => v_body
            );


        ------------------------------------------------------------
        -- 7 Log temporário
        ------------------------------------------------------------

        DBMS_OUTPUT.PUT_LINE('PKG_SHOPEE_PRODUCT.BOOST_ITEMS  RESPONSE:');
        DBMS_OUTPUT.PUT_LINE(v_response);


        ------------------------------------------------------------
        -- 8 Validar resposta da Shopee
        ------------------------------------------------------------

        IF v_response IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20010,
                'Empty response from Shopee API'
            );
        END IF;

        apex_json.parse(v_response);
        
        IF apex_json.get_varchar2('error') IS NOT NULL THEN
            RAISE_APPLICATION_ERROR(
                -20011,
                'Shopee API error ' || apex_json.get_varchar2('error') || ': ' || apex_json.get_varchar2('message')
            );
        END IF;

        ------------------------------------------------------------
        -- Lista de sucesso
        ------------------------------------------------------------

        p_success_list := SYS.ODCINUMBERLIST();

        FOR i IN 1 .. apex_json.get_count('response.success_list.item_id_list')
        LOOP
            p_success_list.EXTEND;
            p_success_list(p_success_list.COUNT) :=
                apex_json.get_number(
                    p_path => 'response.success_list.item_id_list[%d]',
                    p0     => i
                );
        END LOOP;

        ------------------------------------------------------------
        -- Lista de falhas (item_id + motivo concatenado)
        ------------------------------------------------------------

        p_failure_list := SYS.ODCIVARCHAR2LIST();

        FOR i IN 1 .. apex_json.get_count('response.failure_list')
        LOOP
            p_failure_list.EXTEND;
            p_failure_list(p_failure_list.COUNT) :=
                apex_json.get_number(
                    p_path => 'response.failure_list[%d].item_id',
                    p0     => i
                )
                || '|'
                ||
                apex_json.get_varchar2(
                    p_path => 'response.failure_list[%d].failed_reason',
                    p0     => i
                );
        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN

            RAISE_APPLICATION_ERROR(
                -20020,
                'BOOST_ITEM failed: ' || SQLERRM
            );

    END BOOST_ITEMS;


    FUNCTION GET_ITEM_BOOSTED_LIST (
        p_shop_id NUMBER
    )
    RETURN CLOB
    IS

        v_path VARCHAR2(500) := '/api/v2/product/get_boosted_list';

        v_access_token VARCHAR2(500);

        v_timestamp NUMBER := PKG_SHOPEE_AUTH.GET_TIMESTAMP;

        v_url VARCHAR2(2000);

        v_response CLOB;

    BEGIN

        ------------------------------------------------------------------
        -- 1 Obter access token válido
        ------------------------------------------------------------------

        v_access_token :=
            PKG_SHOPEE_AUTH.GET_VALID_ACCESS_TOKEN(
                p_shop_id => p_shop_id
            );   

        IF v_access_token IS NULL THEN

            RAISE_APPLICATION_ERROR(
                -20003,
                'Access token not found for shop_id ' || p_shop_id
            );

        END IF;

        ------------------------------------------------------------------
        -- 2 Montar URL
        ------------------------------------------------------------------

        v_url :=
            PKG_SHOPEE_AUTH.GET_SHOPEE_API_BASE_URL ||
            v_path ||
            '?access_token=' || v_access_token ||
            '&shop_id=' || p_shop_id ||
            '&partner_id=' || PKG_SHOPEE_AUTH.c_partner_id ||
            '&timestamp=' || v_timestamp ||
            '&sign=' || PKG_SHOPEE_AUTH.GENERATE_AUTHENTICATED_API_SIGN(
                p_shop_id => p_shop_id,
                p_path    => v_path,
                p_timestamp => v_timestamp,
                p_access_token => v_access_token
            );

        ------------------------------------------------------------------
        -- 3 Chamada REST
        ------------------------------------------------------------------

        v_response :=
            APEX_WEB_SERVICE.MAKE_REST_REQUEST(
                p_url         => v_url,
                p_http_method => 'GET'
            );
        
        DBMS_OUTPUT.PUT_LINE('PKG_SHOPEE_PRODUCT.GET_ITEM_BOOSTED_LIST response:');
        DBMS_OUTPUT.PUT_LINE(v_response);

        RETURN v_response;

    END GET_ITEM_BOOSTED_LIST;
 

END PKG_SHOPEE_PRODUCT;
/