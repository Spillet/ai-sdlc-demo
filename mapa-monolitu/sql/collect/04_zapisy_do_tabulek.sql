-- =====================================================================
-- 04  Kdo do které tabulky zapisuje (podklad pro vlastnictví dat)
--     -> <data>/catalog/proc_writes.csv
-- =====================================================================
-- NESPOUŠTĚNO proti reálné DB. sys.dm_sql_referenced_entities kompiluje
-- každý modul; u 5 000 procedur počítat s minutami a spouštět mimo špičku.
-- Procedura s chybou (neexistující objekt) vyhodí chybu 2020, proto TRY/CATCH
-- po jednotlivých procedurách.
SET NOCOUNT ON;
DECLARE @r TABLE (proc_name SYSNAME, table_name NVARCHAR(300), is_updated BIT, is_selected BIT);
DECLARE @id INT, @name NVARCHAR(300);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT object_id, QUOTENAME(OBJECT_SCHEMA_NAME(object_id)) + '.' + QUOTENAME(name) FROM sys.procedures;
OPEN c; FETCH NEXT FROM c INTO @id, @name;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        INSERT INTO @r
        SELECT @name, r.referenced_schema_name + '.' + r.referenced_entity_name, MAX(CAST(r.is_updated AS INT)), MAX(CAST(r.is_selected AS INT))
        FROM sys.dm_sql_referenced_entities(@name, 'OBJECT') AS r
        WHERE r.referenced_class = 1
        GROUP BY r.referenced_schema_name, r.referenced_entity_name;
    END TRY
    BEGIN CATCH
        INSERT INTO @r VALUES (@name, N'#CHYBA ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)), NULL, NULL);
    END CATCH
    FETCH NEXT FROM c INTO @id, @name;
END
CLOSE c; DEALLOCATE c;
SELECT * FROM @r ORDER BY proc_name, table_name;
