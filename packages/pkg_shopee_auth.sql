create or replace PACKAGE                    PKG_SHOPEE_AUTH IS
    /**
     * @package PKG_SHOPEE_AUTH
     *
     * @author Vagner Rech
     * @since 1.0.0 (13/02/2026)
     *
     * @description
     * Camada de autenticação e segurança responsável pela integração com a API v2 da Shopee.
     *
     * Este package implementa todas as operações necessárias para autenticação OAuth,
     * geração de assinaturas criptográficas (HMAC-SHA256), gerenciamento de Access Token,
     * Refresh Token e validação automática de expiração.
     *
     * Atua como ponto central de autenticação, garantindo que todas as requisições
     * realizadas contra a API da Shopee utilizem credenciais válidas e seguras.
     *
     * @responsibilities
     * - Gerar timestamps no formato Unix Epoch
     * - Gerar assinatura (SIGN) para autenticação
     * - Gerar URL de autorização OAuth
     * - Obter Access Token inicial
     * - Renovar Access Token automaticamente
     * - Fornecer Access Token válido sob demanda
     * - Invalidar autenticação
     *
     * @dependencies
     * Database Objects:
     * - Table SHOPEE_CONFIG
     *
     * Oracle Packages:
     * - APEX_WEB_SERVICE
     * - APEX_JSON
     * - DBMS_CRYPTO
     * - UTL_I18N
     *
     * External Services:
     * - Shopee Open Platform API v2
     *
     * @security
     * Utiliza algoritmo HMAC-SHA256 para geração de assinaturas seguras.
     *
     * @architecture
     * Authentication Layer
     *
     * @usedby
     * - PKG_SHOPEE_PRODUCT
     * - PKG_SHOPEE_ORDER
     * - PKG_SHOPEE_BOOST
     * - PKG_SHOPEE_STOCK
     *
     */

    -- ==========================================================
    -- CONFIGURAÇÕES GLOBAIS DA SUA APLICAÇÃO (FIXAS)
    -- ==========================================================
    c_partner_id   CONSTANT NUMBER        := 1218643;


    /**
     * @function GET_SHOPEE_API_BASE_URL
     *
     * @description
     * Retorna a URL base da API Shopee conforme ambiente configurado.
     *
     * Pode retornar:
     * - Sandbox
     * - Produção
     *
     * @return VARCHAR2
     * URL base da API Shopee
     *
     * @example
     * v_url := PKG_SHOPEE.GET_BASE_URL;
     *
     * @since 1.0.0
     */
    FUNCTION GET_SHOPEE_API_BASE_URL RETURN VARCHAR2;



    /**
     * @function GET_TIMESTAMP
     *
     * @description
     * Retorna o timestamp atual no formato Unix Epoch Time (segundos desde 01/01/1970).
     *
     * Necessário para autenticação e geração de assinatura da API.
     *
     * @return NUMBER
     * Timestamp Unix em segundos
     *
     * @example
     * v_timestamp := PKG_SHOPEE.GET_TIMESTAMP;
     *
     * @since 1.0.0
     */
    FUNCTION GET_TIMESTAMP RETURN NUMBER;



    /**
     * @function GENERATE_PUBLIC_API_SIGN
     *
     * @description
     * Gera assinatura criptográfica (SIGN) para endpoints públicos de autenticação.
     *
     * Base utilizada:
     * partner_id + path + timestamp
     *
     * Algoritmo:
     * HMAC-SHA256
     *
     * @param p_path VARCHAR2
     * Endpoint da API
     *
     * @param p_timestamp NUMBER
     * Timestamp Unix
     *
     * @return VARCHAR2
     * Assinatura criptográfica (SIGN)
     *
     * @example
     * v_sign := PKG_SHOPEE.GENERATE_PUBLIC_API_SIGN('/api/v2/auth/token/get', v_timestamp);
     *
     * @since 1.0.0
     */
    FUNCTION GENERATE_PUBLIC_API_SIGN (
        p_path      IN VARCHAR2,
        p_timestamp IN NUMBER
    ) RETURN VARCHAR2;



    /**
     * @function GENERATE_AUTHENTICATED_API_SIGN
     *
     * @description
     * Gera assinatura criptográfica (SIGN) para endpoints protegidos da API Shopee.
     *
     * Base utilizada:
     * partner_id + path + timestamp + access_token + shop_id
     *
     * Algoritmo:
     * HMAC-SHA256
     *
     * @param p_path VARCHAR2
     * Endpoint da API
     *
     * @param p_timestamp NUMBER
     * Timestamp Unix
     *
     * @param p_access_token VARCHAR2
     * Access Token válido
     *
     * @param p_shop_id NUMBER
     * ID da loja Shopee
     *
     * @return VARCHAR2
     * Assinatura criptográfica (SIGN)
     *
     * @example
     * v_sign := PKG_SHOPEE.GENERATE_AUTHENTICATED_API_SIGN('/api/v2/product/get_item_list',
     *                               v_timestamp,
     *                               v_token,
     *                               v_shop_id);
     *
     * @since 1.0.0
     */
    FUNCTION GENERATE_AUTHENTICATED_API_SIGN (
        p_path         IN VARCHAR2,
        p_timestamp    IN NUMBER,
        p_access_token IN VARCHAR2,
        p_shop_id      IN NUMBER
    ) RETURN VARCHAR2;



    /**
     * @function GENERATE_SHOPEE_AUTH_URL
     *
     * @description
     * Gera URL de autorização OAuth da Shopee.
     *
     * O usuário deve acessar esta URL para autorizar a aplicação.
     *
     * Após autorização, a Shopee retornará um authorization code.
     *
     * @return VARCHAR2
     * URL de autorização
     *
     * @example
     * v_url := PKG_SHOPEE.GENERATE_SHOPEE_AUTH_URL;
     *
     * @since 1.0.0
     */
    FUNCTION GENERATE_SHOPEE_AUTH_URL RETURN VARCHAR2;



    /**
     * @procedure AUTH_GET_TOKEN
     *
     * @description
     * Troca o authorization code por Access Token e Refresh Token.
     *
     * Os tokens são armazenados na tabela SHOPEE_CONFIG.
     *
     * @param p_code VARCHAR2
     * Authorization code retornado pela Shopee
     *
     * @param p_shop_id NUMBER
     * ID da loja Shopee
     *
     * @example
     * PKG_SHOPEE.AUTH_GET_TOKEN(v_code, v_shop_id);
     *
     * @since 1.0.0
     */
    PROCEDURE AUTH_GET_TOKEN (
        p_code    IN VARCHAR2,
        p_shop_id IN NUMBER
    );



    /**
     * @procedure REFRESH_TOKEN
     *
     * @description
     * Atualiza o Access Token utilizando o Refresh Token armazenado.
     *
     * Atualiza automaticamente:
     * - Access Token
     * - Refresh Token
     * - Data de expiração
     *
     * @param p_shop_id NUMBER
     * ID da loja Shopee
     *
     * @example
     * PKG_SHOPEE.REFRESH_TOKEN(123456);
     *
     * @since 1.0.0
     */
    PROCEDURE REFRESH_TOKEN (
        p_shop_id IN NUMBER
    );



    /**
     * @function GET_VALID_ACCESS_TOKEN
     *
     * @description
     * Retorna um Access Token válido.
     *
     * Caso o token esteja expirado ou próximo da expiração,
     * executa automaticamente o refresh do token.
     *
     * @param p_shop_id NUMBER
     * ID da loja Shopee
     *
     * @return VARCHAR2
     * Access Token válido
     *
     * @example
     * v_token := PKG_SHOPEE.GET_VALID_ACCESS_TOKEN(123456);
     *
     * @since 1.0.0
     */
    FUNCTION GET_VALID_ACCESS_TOKEN (
        p_shop_id NUMBER
    ) RETURN VARCHAR2;



    /**
     * @procedure LOGOUT
     *
     * @description
     * Remove o Access Token e Refresh Token armazenados,
     * invalidando a autenticação da loja.
     *
     * @param p_shop_id NUMBER
     * ID da loja Shopee
     *
     * @example
     * PKG_SHOPEE.LOGOUT(123456);
     *
     * @since 1.0.0
     */
    PROCEDURE LOGOUT (
        p_shop_id NUMBER
    );

    /**
     * @procedure SET_USER_SHOP
     *
     * @description
     * Vincula ou atualiza a SHOP_ID associada a um usuário do APEX.
     *
     * Se o usuário ainda não possuir vínculo, será criado um novo registro.
     * Caso já exista, a SHOP_ID será atualizada.
     *
     * Esta procedure é chamada automaticamente após a autenticação OAuth
     * bem-sucedida com a Shopee.
     *
     * @param p_username VARCHAR2
     * Username do usuário autenticado no Oracle APEX
     *
     * @param p_shop_id NUMBER
     * ID da loja Shopee autorizada
     *
     * @example
     * PKG_SHOPEE_AUTH.SET_USER_SHOP('VAGNER', 123456);
     *
     * @since 1.0.0
     */
    PROCEDURE SET_USER_SHOP (
        p_username VARCHAR2,
        p_shop_id  NUMBER
    );



    /**
     * @function GET_USER_SHOP_ID
     *
     * @description
     * Retorna a SHOP_ID vinculada a um usuário específico do APEX.
     *
     * @param p_username VARCHAR2
     * Username do usuário APEX
     *
     * @return NUMBER
     * SHOP_ID vinculada ao usuário
     *
     * @raises -20010
     * Caso o usuário não possua shop vinculada
     *
     * @example
     * v_shop_id := PKG_SHOPEE_AUTH.GET_USER_SHOP_ID('VAGNER');
     *
     * @since 1.0.0
     */
    FUNCTION GET_USER_SHOP_ID (
        p_username VARCHAR2
    ) RETURN NUMBER;



    /**
     * @function GET_CURRENT_SHOP_ID
     *
     * @description
     * Retorna a SHOP_ID do usuário atualmente autenticado no Oracle APEX.
     *
     * Esta função utiliza a variável global:
     *
     *     V('APP_USER')
     *
     * para identificar o usuário logado.
     *
     * @return NUMBER
     * SHOP_ID ativa do usuário atual
     *
     * @raises -20011
     * Caso não exista shop vinculada ao usuário atual
     *
     * @example
     * v_shop_id := PKG_SHOPEE_AUTH.GET_CURRENT_SHOP_ID;
     *
     * @since 1.0.0
     */
    FUNCTION GET_CURRENT_SHOP_ID
    RETURN NUMBER;



    /**
     * @procedure CLEAR_USER_SHOP
     *
     * @description
     * Remove o vínculo entre um usuário APEX e sua SHOP_ID.
     *
     * Usado quando o usuário faz logout da Shopee ou revoga autorização.
     *
     * @param p_username VARCHAR2
     * Username do usuário APEX
     *
     * @example
     * PKG_SHOPEE_AUTH.CLEAR_USER_SHOP('VAGNER');
     *
     * @since 1.0.0
     */
    PROCEDURE CLEAR_USER_SHOP (
        p_username VARCHAR2
    );

END PKG_SHOPEE_AUTH;
/