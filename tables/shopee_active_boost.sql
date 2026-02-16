/****************************************************************************************
 * Tabela: SHOPEE_ACTIVE_BOOST
 * Descrição:
 *   Armazena informações sobre os produtos que estão com boost ativo em uma loja na Shopee.
 *   Cada registro representa um item específico de uma loja que participa do boost, incluindo
 *   o tempo de término da promoção e a última atualização do registro.
 *
 * Colunas:
 *   SHOP_ID      - NUMBER, NOT NULL
 *                  Identificador único da loja.
 *
 *   ITEM_ID      - NUMBER, NOT NULL
 *                  Identificador único do item na loja.
 *
 *   END_TIME     - DATE, NULL
 *                  Data e hora em que o boost do item termina.
 *
 *   UPDATED_AT   - DATE, DEFAULT SYSDATE
 *                  Data e hora da última atualização do registro.
 *
 * Chaves e restrições:
 *   PK_SHOPEE_ACTIVE_BOOST
 *      - PRIMARY KEY composta por (SHOP_ID, ITEM_ID)
 *      - Garante que não existam duplicatas do mesmo item para a mesma loja.
 *
 * Observações:
 *   - A tabela pode ser utilizada para consultas rápidas de itens com boost ativo.
 *   - É recomendável indexar adicionalmente colunas frequentemente usadas em filtros, 
 *     caso necessário.
 *
 * Exemplo de uso:
 *   -- Selecionar todos os itens com boost ativo em uma loja específica
 *   SELECT *
 *   FROM SHOPEE_ACTIVE_BOOST
 *   WHERE SHOP_ID = 12345
 *     AND END_TIME > SYSDATE;
 ****************************************************************************************/

  CREATE TABLE "SHOPEE_ACTIVE_BOOST" 
   (	"SHOP_ID" NUMBER NOT NULL ENABLE, 
	"ITEM_ID" NUMBER NOT NULL ENABLE, 
	"END_TIME" DATE, 
	"UPDATED_AT" DATE DEFAULT SYSDATE, 
	 CONSTRAINT "PK_SHOPEE_ACTIVE_BOOST" PRIMARY KEY ("SHOP_ID", "ITEM_ID")
  USING INDEX  ENABLE
   ) ;

   COMMENT ON COLUMN "SHOPEE_ACTIVE_BOOST"."SHOP_ID" IS 'Identificador único da loja.';
   COMMENT ON COLUMN "SHOPEE_ACTIVE_BOOST"."ITEM_ID" IS 'Identificador único do item na loja.';
   COMMENT ON COLUMN "SHOPEE_ACTIVE_BOOST"."END_TIME" IS 'Data e hora em que o boost do item termina.';
   COMMENT ON COLUMN "SHOPEE_ACTIVE_BOOST"."UPDATED_AT" IS 'Data e hora da última atualização do registro.';
   COMMENT ON TABLE "SHOPEE_ACTIVE_BOOST"  IS 'Armazena informações sobre os produtos que estão com boost ativo em uma loja na Shopee. Cada registro representa um item específico de uma loja, incluindo o tempo de término do boost e a última atualização.';