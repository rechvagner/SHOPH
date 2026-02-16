/****************************************************************************************
 * Tabela: SHOPEE_AUTH_LOG
 * Descrição:
 *   Armazena o histórico de autenticações realizadas nas lojas da Shopee.
 *   Cada registro representa um evento de autorização, incluindo o código retornado
 *   no fluxo OAuth, a loja associada e a data de criação do log.
 *
 * Colunas:
 *   ID          - NUMBER, NOT NULL, GENERATED ALWAYS AS IDENTITY
 *                 Identificador único do registro. Garante unicidade automática.
 *
 *   CODE        - VARCHAR2(500), NULL
 *                 Código retornado no processo de autenticação OAuth.
 *
 *   SHOP_ID     - VARCHAR2(100), NULL
 *                 Identificador da loja que realizou a autenticação.
 *
 *   CREATED_AT  - DATE, DEFAULT SYSDATE
 *                 Data e hora de criação do registro.
 *
 * Chaves e restrições:
 *   PRIMARY KEY (ID)
 *      - Garante unicidade de cada registro no log.
 *
 * Observações:
 *   - A tabela pode ser usada para auditoria e rastreamento de fluxos de autorização.
 *   - É recomendável consultar a tabela por `SHOP_ID` ou `CREATED_AT` para análises de histórico.
 *
 * Exemplo de uso:
 *   -- Obter os últimos códigos de autenticação de uma loja específica
 *   SELECT * 
 *   FROM SHOPEE_AUTH_LOG
 *   WHERE SHOP_ID = '12345'
 *   ORDER BY CREATED_AT DESC;
 ****************************************************************************************/
  
  CREATE TABLE "SHOPEE_AUTH_LOG" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"CODE" VARCHAR2(500), 
	"SHOP_ID" VARCHAR2(100), 
	"CREATED_AT" DATE DEFAULT SYSDATE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) ;

   COMMENT ON COLUMN "SHOPEE_AUTH_LOG"."ID" IS 'Identificador único do registro. Gerado automaticamente pelo banco (IDENTITY).';
   COMMENT ON COLUMN "SHOPEE_AUTH_LOG"."CODE" IS 'Código retornado no fluxo de autenticação OAuth.';
   COMMENT ON COLUMN "SHOPEE_AUTH_LOG"."SHOP_ID" IS 'Identificador da loja que realizou a autenticação.';
   COMMENT ON COLUMN "SHOPEE_AUTH_LOG"."CREATED_AT" IS 'Data e hora de criação do registro (padrão SYSDATE).';
   COMMENT ON TABLE "SHOPEE_AUTH_LOG"  IS 'Armazena o histórico de autenticações realizadas nas lojas da Shopee. Cada registro contém o código OAuth, a loja e a data de criação.';