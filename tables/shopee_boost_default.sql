/****************************************************************************************
 * Tabela: SHOPEE_BOOST_DEFAULT
 * Descrição:
 *   Armazena os produtos que serão utilizados como boost **padrão** para lojas na Shopee
 *   quando não houver nenhum boost agendado previamente. 
 *   Esta tabela funciona como **última prioridade**, garantindo que sempre haja um item 
 *   definido para boost mesmo sem agendamento.
 *
 * Colunas:
 *   ID        - NUMBER, NOT NULL, GENERATED ALWAYS AS IDENTITY
 *               Identificador único do registro, gerado automaticamente.
 *
 *   SHOP_ID   - NUMBER, NOT NULL
 *               Identificador da loja que possui o item.
 *
 *   ITEM_ID   - NUMBER, NOT NULL
 *               Identificador do item dentro da loja.
 *
 *   PRIORITY  - NUMBER, DEFAULT 100
 *               Define a prioridade do boost. Como esta é a tabela de fallback, 
 *               os valores normalmente são os mais baixos na lógica de seleção.
 *
 *   ACTIVE    - CHAR(1), DEFAULT 'Y'
 *               Indica se o boost está ativo ('Y') ou não ('N').
 *
 *   CREATED_AT - DATE, DEFAULT SYSDATE
 *               Data e hora de criação do registro.
 *
 * Chaves e restrições:
 *   PRIMARY KEY (ID)
 *      - Garante unicidade de cada registro na tabela.
 *
 * Observações:
 *   - Esta tabela é consultada **apenas quando não existem boosts agendados**. 
 *   - Recomenda-se consultar por SHOP_ID e ITEM_ID para verificar quais produtos serão usados como fallback.
 *
 * Exemplo de uso:
 *   -- Obter os produtos padrão ativos para boost de uma loja específica
 *   SELECT * 
 *   FROM SHOPEE_BOOST_DEFAULT
 *   WHERE SHOP_ID = 12345
 *     AND ACTIVE = 'Y';
 ****************************************************************************************/
 
  CREATE TABLE "SHOPEE_BOOST_DEFAULT" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"SHOP_ID" NUMBER NOT NULL ENABLE, 
	"ITEM_ID" NUMBER NOT NULL ENABLE, 
	"PRIORITY" NUMBER DEFAULT 100, 
	"ACTIVE" CHAR(1) DEFAULT 'Y', 
	"CREATED_AT" DATE DEFAULT SYSDATE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) ;

   COMMENT ON COLUMN "SHOPEE_BOOST_DEFAULT"."ID" IS 'Identificador único do registro. Gerado automaticamente pelo banco (IDENTITY).';
   COMMENT ON COLUMN "SHOPEE_BOOST_DEFAULT"."SHOP_ID" IS 'Identificador da loja que possui o item.';
   COMMENT ON COLUMN "SHOPEE_BOOST_DEFAULT"."ITEM_ID" IS 'Identificador do item dentro da loja.';
   COMMENT ON COLUMN "SHOPEE_BOOST_DEFAULT"."PRIORITY" IS 'Prioridade do boost. Como tabela de fallback, os valores normalmente são os mais baixos.';
   COMMENT ON COLUMN "SHOPEE_BOOST_DEFAULT"."ACTIVE" IS 'Indica se o boost está ativo (''Y'') ou inativo (''N''). Padrão ''Y''.';
   COMMENT ON COLUMN "SHOPEE_BOOST_DEFAULT"."CREATED_AT" IS 'Data e hora de criação do registro. Padrão SYSDATE.';
   COMMENT ON TABLE "SHOPEE_BOOST_DEFAULT"  IS 'Define os produtos padrão de boost para lojas Shopee quando não houver nenhum boost agendado. Funciona como fallback de última prioridade.';