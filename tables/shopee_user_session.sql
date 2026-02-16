/****************************************************************************************
 * Tabela: SHOPEE_USER_SESSION
 * Descrição:
 *   Armazena a sessão de usuários APEX vinculando cada usuário ao SHOP_ID que realizou
 *   a autenticação na Shopee. Permite identificar qual loja está associada a cada usuário
 *   logado e rastrear sessões.
 *
 * Colunas:
 *   USERNAME    - VARCHAR2(255), NOT NULL
 *                 Nome do usuário APEX que realizou a autenticação. Serve como chave primária.
 *
 *   SHOP_ID     - NUMBER, NOT NULL
 *                 Identificador da loja Shopee associada ao usuário.
 *
 *   CREATED_AT  - DATE, DEFAULT SYSDATE
 *                 Data e hora de criação do registro de sessão.
 *
 *   UPDATED_AT  - DATE, DEFAULT SYSDATE
 *                 Data e hora da última atualização da sessão.
 *
 * Chaves e restrições:
 *   PRIMARY KEY (USERNAME)
 *      - Garante unicidade de cada usuário na tabela de sessão.
 *
 * Observações:
 *   - Permite que múltiplos usuários APEX estejam associados a lojas diferentes.
 *   - A coluna UPDATED_AT deve ser atualizada a cada nova ação ou login do usuário.
 *
 * Exemplo de uso:
 *   -- Obter o shop_id associado a um usuário específico
 *   SELECT SHOP_ID 
 *   FROM SHOPEE_USER_SESSION
 *   WHERE USERNAME = 'joao.silva';
 ****************************************************************************************/
 
 
  CREATE TABLE "SHOPEE_USER_SESSION" 
   (	"USERNAME" VARCHAR2(255), 
	"SHOP_ID" NUMBER NOT NULL ENABLE, 
	"CREATED_AT" DATE DEFAULT SYSDATE, 
	"UPDATED_AT" DATE DEFAULT SYSDATE, 
	 PRIMARY KEY ("USERNAME")
  USING INDEX  ENABLE
   ) ;

   COMMENT ON COLUMN "SHOPEE_USER_SESSION"."USERNAME" IS 'Nome do usuário APEX que realizou a autenticação. Chave primária da tabela.';
   COMMENT ON COLUMN "SHOPEE_USER_SESSION"."SHOP_ID" IS 'Identificador da loja Shopee associada ao usuário.';
   COMMENT ON COLUMN "SHOPEE_USER_SESSION"."CREATED_AT" IS 'Data e hora de criação do registro de sessão.';
   COMMENT ON COLUMN "SHOPEE_USER_SESSION"."UPDATED_AT" IS 'Data e hora da última atualização da sessão.';
   COMMENT ON TABLE "SHOPEE_USER_SESSION"  IS 'Vincula o usuário APEX ao SHOP_ID que realizou a autenticação na Shopee.';