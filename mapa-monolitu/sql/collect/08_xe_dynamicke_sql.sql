-- =====================================================================
-- 08  Cíle dynamického SQL za běhu  ->  <data>/runtime/xe_dynamic_sql.csv
--     sloupce: parent_object, statement_sample, event_count
-- =====================================================================
-- NESPOUŠTĚNO proti reálné DB. Nejméně ověřená část sběru.
-- Dynamické SQL z sp_executesql / EXEC(@sql) nemá object_id volající procedury.
-- Rodiče jde dohledat přes akci tsql_frame/tsql_stack: rámec obsahuje sql_handle
-- a offsety; sys.dm_exec_sql_text(handle).objectid vrátí proceduru, dokud je plán
-- v cache. Proto zpracovávat průběžně, ne po týdnu.
-- Spouštět krátce (hodiny) a jen pro procedury, které textová vrstva označila
-- jako dynamické (seznam z analyzátoru), jinak je objem neúnosný.
CREATE EVENT SESSION [mapa_dynsql] ON SERVER
ADD EVENT sqlserver.sp_statement_completed (
    SET collect_statement = (1)
    ACTION (sqlserver.tsql_stack)
    WHERE sqlserver.database_name = N'NazevDB'
      AND object_type = 'ADHOC'                                     -- dynamická dávka; ověřit hodnotu na verzi
      AND package0.divides_by_uint64(sqlserver.session_id, 20))
ADD TARGET package0.event_file (SET filename = N'mapa_dynsql.xel', max_file_size = 256, max_rollover_files = 10)
WITH (MAX_DISPATCH_LATENCY = 30 SECONDS, EVENT_RETENTION_MODE = ALLOW_MULTIPLE_EVENT_LOSS);

;WITH ev AS (
    SELECT CAST(event_data AS XML) AS x
    FROM sys.fn_xe_file_target_read_file(N'mapa_dynsql*.xel', NULL, NULL, NULL)
), fr AS (
    SELECT x.value('(event/data[@name="statement"]/value)[1]', 'nvarchar(4000)') AS stmt,
           -- předposlední rámec zásobníku = modul, který dynamické SQL spustil
           CONVERT(VARBINARY(64), f.value('@handle', 'varchar(130)'), 1) AS handle
    FROM ev
    CROSS APPLY ev.x.nodes('event/action[@name="tsql_stack"]/value/frames/frame[@level="1"]') AS s(f)
)
SELECT 'dbo.' + OBJECT_NAME(t.objectid, t.dbid) AS parent_object,
       LEFT(fr.stmt, 400)                       AS statement_sample,
       COUNT(*) * 20                            AS event_count
FROM fr
OUTER APPLY sys.dm_exec_sql_text(fr.handle) AS t
GROUP BY OBJECT_NAME(t.objectid, t.dbid), LEFT(fr.stmt, 400);
