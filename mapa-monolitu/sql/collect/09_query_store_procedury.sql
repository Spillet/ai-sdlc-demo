-- =====================================================================
-- 09  Provozní váha procedur z Query Store  ->  <data>/runtime/query_store_proc_stats.csv
--     sloupce: object_name, stmt_executions, cpu_ms, logical_reads, logical_writes
-- =====================================================================
-- NESPOUŠTĚNO proti reálné DB. Počty jsou spuštění PŘÍKAZŮ uvnitř procedury,
-- ne volání procedury. Query Store vidí jen primární repliku (do SQL 2025).
SET NOCOUNT ON;
SELECT 'dbo.' + OBJECT_NAME(q.object_id)                       AS object_name,
       SUM(rs.count_executions)                                AS stmt_executions,
       CAST(SUM(rs.avg_cpu_time * rs.count_executions) / 1000.0 AS BIGINT)        AS cpu_ms,
       CAST(SUM(rs.avg_logical_io_reads * rs.count_executions) AS BIGINT)         AS logical_reads,
       CAST(SUM(rs.avg_logical_io_writes * rs.count_executions) AS BIGINT)        AS logical_writes
FROM sys.query_store_runtime_stats AS rs
JOIN sys.query_store_runtime_stats_interval AS i ON i.runtime_stats_interval_id = rs.runtime_stats_interval_id
JOIN sys.query_store_plan  AS p ON p.plan_id  = rs.plan_id
JOIN sys.query_store_query AS q ON q.query_id = p.query_id
WHERE q.object_id <> 0
  AND i.start_time >= DATEADD(DAY, -30, SYSUTCDATETIME())
GROUP BY q.object_id
ORDER BY cpu_ms DESC;
