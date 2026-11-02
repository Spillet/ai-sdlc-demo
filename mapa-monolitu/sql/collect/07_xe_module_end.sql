-- =====================================================================
-- 07  Kolikrát se modul spustil vůbec (i vnořeně)  ->  <data>/runtime/xe_module_end_histogram.csv
--     sloupce: object_name, object_type, event_count, window_from, window_to
-- =====================================================================
-- NESPOUŠTĚNO proti reálné DB. Histogram neukládá jednotlivé události,
-- takže jde nechat běžet týdny. Nula za 6 týdnů = kandidát na vypnutí,
-- ne důkaz (roční uzávěrky, ruční zásahy).
CREATE EVENT SESSION [mapa_module_end] ON SERVER
ADD EVENT sqlserver.module_end (
    WHERE sqlserver.database_name = N'NazevDB' AND object_type = 'P ')   -- 'P ' s mezerou; ověřit na verzi
ADD TARGET package0.histogram (
    SET filtering_event_name = N'sqlserver.module_end', source = N'object_name', source_type = 0, slots = 16384)
WITH (MAX_DISPATCH_LATENCY = 30 SECONDS, STARTUP_STATE = ON);
-- ALTER EVENT SESSION [mapa_module_end] ON SERVER STATE = START;

-- Čtení histogramu (snímek ukládat pravidelně; restart instance ho vynuluje):
SELECT 'dbo.' + slot.value('(value)[1]', 'sysname') AS object_name,
       'P' AS object_type,
       slot.value('(@count)[1]', 'bigint')        AS event_count,
       CAST(NULL AS DATETIME2) AS window_from, SYSUTCDATETIME() AS window_to
FROM (
    SELECT CAST(t.target_data AS XML) AS td
    FROM sys.dm_xe_session_targets AS t
    JOIN sys.dm_xe_sessions AS s ON s.address = t.event_session_address
    WHERE s.name = N'mapa_module_end' AND t.target_name = N'histogram'
) AS h
CROSS APPLY h.td.nodes('/HistogramTarget/Slot') AS x(slot);
