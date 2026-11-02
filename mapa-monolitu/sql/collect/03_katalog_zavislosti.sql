-- =====================================================================
-- 03  Statický katalog závislostí (pro porovnání s parserem)
--     -> <data>/catalog/sql_expression_dependencies.csv
-- =====================================================================
-- NESPOUŠTĚNO proti reálné DB. Analyzátor tenhle soubor zatím nečte; slouží
-- ke kontrole, kde se regex parser a katalog SQL Serveru rozcházejí.
-- Blind spots katalogu: dynamické SQL, cross-DB (referenced_id NULL),
-- volání bez schématu (is_caller_dependent = 1), dočasné tabulky.
SET NOCOUNT ON;
SELECT OBJECT_SCHEMA_NAME(d.referencing_id) AS referencing_schema,
       OBJECT_NAME(d.referencing_id)        AS referencing_name,
       o.type                               AS referencing_type,
       d.referenced_server_name, d.referenced_database_name,
       d.referenced_schema_name, d.referenced_entity_name,
       ro.type                              AS referenced_type,
       d.is_caller_dependent, d.is_ambiguous,
       CASE WHEN d.referenced_id IS NULL THEN 1 ELSE 0 END AS is_unresolved
FROM sys.sql_expression_dependencies AS d
JOIN sys.objects AS o ON o.object_id = d.referencing_id
LEFT JOIN sys.objects AS ro ON ro.object_id = d.referenced_id
WHERE d.referencing_class = 1;
