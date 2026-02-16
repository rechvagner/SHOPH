/****************************************************************************************
 * Tabela: SHOPEE_BOOST_QUEUE
 * Descrição:
 *   Armazena os produtos agendados para boost nas lojas Shopee, funcionando como uma
 *   fila de execução. Cada registro contém informações sobre o item, status da execução,
 *   prioridade, agendamento, tentativas de retry e mensagens de erro caso ocorram falhas.
 *
 * Colunas:
 *   ID            - NUMBER, NOT NULL, GENERATED ALWAYS AS IDENTITY
 *                   Identificador único do registro, gerado automaticamente.
 *
 *   SHOP_ID       - NUMBER, NOT NULL
 *                   Identificador da loja que possui o item.
 *
 *   ITEM_ID       - NUMBER, NOT NULL
 *                   Identificador do item dentro da loja.
 *
 *   STATUS        - VARCHAR2(20), DEFAULT 'PENDING'
 *                   Status da execução do boost (ex.: PENDING, EXECUTED, FAILED).
 *
 *   PRIORITY_TYPE - VARCHAR2(20), DEFAULT 'QUEUE'
 *                   Tipo de prioridade (ex.: QUEUE para agendamento padrão, DEFAULT para fallback).
 *
 *   PRIORITY      - NUMBER, DEFAULT 100
 *                   Define a prioridade do boost na fila. Valores menores indicam maior prioridade.
 *
 *   SCHEDULED_AT  - DATE, DEFAULT SYSDATE
 *                   Data e hora em que o boost está agendado para execução.
 *
 *   EXECUTED_AT   - DATE, NULL
 *                   Data e hora em que o boost foi efetivamente executado.
 *
 *   SKIP_COUNT    - NUMBER, DEFAULT 0
 *                   Número de vezes que o boost foi pulado devido a conflitos ou falhas.
 *
 *   ERROR_MESSAGE - VARCHAR2(4000), NULL
 *                   Mensagem de erro retornada na execução do boost, se houver.
 *
 *   CREATED_AT    - DATE, DEFAULT SYSDATE
 *                   Data e hora de criação do registro.
 *
 *   NEXT_RETRY_AT - DATE, NULL
 *                   Data e hora do próximo retry, caso a execução falhe.
 *
 *   RETRY_COUNT   - NUMBER, DEFAULT 0
 *                   Contador de tentativas de execução do boost.
 *
 * Chaves e restrições:
 *   PRIMARY KEY (ID)
 *      - Garante unicidade de cada registro na tabela.
 *
 * Observações:
 *   - Esta tabela é consultada e processada pelo mecanismo de execução de boost.
 *   - Recomenda-se ordenar por PRIORITY e SCHEDULED_AT para determinar a sequência de execução.
 *
 * Exemplo de uso:
 *   -- Obter todos os boosts pendentes para uma loja específica
 *   SELECT * 
 *   FROM SHOPEE_BOOST_QUEUE
 *   WHERE SHOP_ID = 12345
 *     AND STATUS = 'PENDING'
 *   ORDER BY PRIORITY ASC, SCHEDULED_AT ASC;
 ****************************************************************************************/


  CREATE TABLE "SHOPEE_BOOST_QUEUE" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"SHOP_ID" NUMBER NOT NULL ENABLE, 
	"ITEM_ID" NUMBER NOT NULL ENABLE, 
	"STATUS" VARCHAR2(20) DEFAULT 'PENDING', 
	"PRIORITY_TYPE" VARCHAR2(20) DEFAULT 'QUEUE', 
	"PRIORITY" NUMBER DEFAULT 100, 
	"SCHEDULED_AT" DATE DEFAULT SYSDATE, 
	"EXECUTED_AT" DATE, 
	"SKIP_COUNT" NUMBER DEFAULT 0, 
	"ERROR_MESSAGE" VARCHAR2(4000), 
	"CREATED_AT" DATE DEFAULT SYSDATE, 
	"NEXT_RETRY_AT" DATE, 
	"RETRY_COUNT" NUMBER DEFAULT 0, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) ;

   COMMENT ON COLUMN "SHOPEE_BOOST_QUEUE"."ID" IS 'Identificador único do registro. Gerado automaticamente pelo banco (IDENTITY).';
   COMMENT ON COLUMN "SHOPEE_BOOST_QUEUE"."SHOP_ID" IS 'Identificador da loja que possui o item.';
   COMMENT ON COLUMN "SHOPEE_BOOST_QUEUE"."ITEM_ID" IS 'Identificador do item dentro da loja.';
   COMMENT ON COLUMN "SHOPEE_BOOST_QUEUE"."STATUS" IS 'Status da execução do boost (ex.: PENDING, EXECUTED, FAILED).';
   COMMENT ON COLUMN "SHOPEE_BOOST_QUEUE"."PRIORITY_TYPE" IS 'Tipo de prioridade do boost (ex.: QUEUE para agendamento padrão, DEFAULT para fallback).';
   COMMENT ON COLUMN "SHOPEE_BOOST_QUEUE"."PRIORITY" IS 'Prioridade do boost na fila. Valores menores indicam maior prioridade.';
   COMMENT ON COLUMN "SHOPEE_BOOST_QUEUE"."SCHEDULED_AT" IS 'Data e hora agendada para execução do boost.';
   COMMENT ON COLUMN "SHOPEE_BOOST_QUEUE"."EXECUTED_AT" IS 'Data e hora em que o boost foi executado.';
   COMMENT ON COLUMN "SHOPEE_BOOST_QUEUE"."SKIP_COUNT" IS 'Número de vezes que o boost foi pulado devido a conflitos ou falhas.';
   COMMENT ON COLUMN "SHOPEE_BOOST_QUEUE"."ERROR_MESSAGE" IS 'Mensagem de erro retornada na execução do boost, se houver.';
   COMMENT ON COLUMN "SHOPEE_BOOST_QUEUE"."CREATED_AT" IS 'Data e hora de criação do registro. Padrão SYSDATE.';
   COMMENT ON COLUMN "SHOPEE_BOOST_QUEUE"."NEXT_RETRY_AT" IS 'Data e hora do próximo retry, caso a execução falhe.';
   COMMENT ON COLUMN "SHOPEE_BOOST_QUEUE"."RETRY_COUNT" IS 'Contador de tentativas de execução do boost.';
   COMMENT ON TABLE "SHOPEE_BOOST_QUEUE"  IS 'Fila de produtos agendados para boost na Shopee. Contém status, agendamento, tentativas de retry e mensagens de erro.';