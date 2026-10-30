-- =====================================================================
-- 06  Volání procedur zvenku podle aplikace (Extended Events)
--     -> <data>/runtime/xe_rpc_completed_histogram.csv
--     sloupce: object_name, client_app_name, event_count, window_from, window_to
-- =====================================================================
-- NESPOUŠTĚNO proti reálné DB. Ověřit názvy polí na cílové verzi.
-- Histogram umí seskupit jen podle jednoho pole, proto pro rozpad podle aplikace
-- event_file se vzorkováním. Nechat běžet 4–6 týdnů včetně konce měsíce.
-- Objem: rpc_completed na vytížené instanci jsou miliony událostí denně;
-- vzorkování 1:10 podle session_id a omezený soubor jsou nutnost.
CREATE EVENT SESSION [mapa_rpc] ON SERVER
ADD EVENT sqlserver.rpc_completed (
    SET collect_statement = (0)
    ACTION (sqlserver.client_app_name, sqlserver.database_name)
    WHERE sqlserver.database_name = N'NazevDB'
      AND package0.divides_by_uint64(sqlserver.session_id, 10))      -- vzorek ~10 %
ADD TARGET package0.event_file (SET filename = N'mapa_rpc.xel', max_file_size = 512, max_rollover_files = 40)
WITH (MAX_DISPATCH_LATENCY = 30 SECONDS, EVENT_RETENTION_MODE = ALLOW_MULTIPLE_EVENT_LOSS, STARTUP_STATE = ON);
-- ALTER EVENT SESSION [mapa_rpc] ON SERVER STATE = START;

-- Čtení a agregace (spouštět průběžně, výsledek ukládat, soubory se rotují):
;WITH ev AS (
    SELECT CAST(event_data AS XML) AS x
    FROM sys.fn_xe_file_target_read_file(N'mapa_rpc*.xel', NULL, NULL, NULL)
)
SELECT 'dbo.' + x.value('(event/data[@name="object_name"]/value)[1]', 'sysname')            AS object_name,
       x.value('(event/action[@name="client_app_name"]/value)[1]', 'nvarchar(256)')          AS client_app_name,
       COUNT(*) * 10                                                                         AS event_count,   -- přepočet vzorku
       MIN(x.value('(event/@timestamp)[1]', 'datetime2'))                                    AS window_from,
       MAX(x.value('(event/@timestamp)[1]', 'datetime2'))                                    AS window_to
FROM ev
GROUP BY x.value('(event/data[@name="object_name"]/value)[1]', 'sysname'),
         x.value('(event/action[@name="client_app_name"]/value)[1]', 'nvarchar(256)');
-- Poznámka: kroky SQL Agenta s T-SQL nejsou RPC, chodí jako sql_batch_completed.
-- Přidat druhou událost nebo je brát z 05_sql_agent_jobs.sql.
