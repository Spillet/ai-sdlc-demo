-- =====================================================================
-- 01  Export kódu modulů a kostry tabulek  ->  <data>/db/*.sql
-- =====================================================================
-- NESPOUŠTĚNO proti reálné DB. Před použitím vyzkoušet na kopii.
-- Jen čte metadata (sys.*), nemění data. Spouštět na read-only replice.
--
-- Preferovaná cesta je SqlPackage (zachová přesný text objektů):
--   SqlPackage /Action:Extract /SourceServerName:SRV /SourceDatabaseName:DB
--              /TargetFile:db.dacpac /p:ExtractTarget=SchemaObjectType
-- Záložní cesta bez dalších nástrojů (SQL Server 2017+ kvůli STRING_AGG):
--   sqlcmd -S SRV -d DB -E -y 0 -h -1 -i 01_moduly_a_tabulky.sql -o data/real/db/01_all.sql
-- Analyzátor čte soubory po dávkách oddělených GO.

SET NOCOUNT ON;

-- a) kostra tabulek: stačí jméno a sloupce, analyzátor potřebuje vědět, co je tabulka
SELECT 'CREATE TABLE ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + ' (' +
       STRING_AGG(CAST(QUOTENAME(c.name) + ' ' + ty.name AS NVARCHAR(MAX)), ', ') WITHIN GROUP (ORDER BY c.column_id) +
       ');' + CHAR(10) + 'GO'
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
JOIN sys.columns AS c ON c.object_id = t.object_id
JOIN sys.types   AS ty ON ty.user_type_id = c.user_type_id
WHERE t.is_ms_shipped = 0
GROUP BY s.name, t.name;

-- b) definice procedur, funkcí, pohledů a triggerů (přesný uložený text)
SELECT m.definition + CHAR(10) + 'GO'
FROM sys.sql_modules AS m
JOIN sys.objects AS o ON o.object_id = m.object_id
WHERE o.is_ms_shipped = 0
  AND o.type IN ('P', 'FN', 'IF', 'TF', 'V', 'TR')
ORDER BY o.type, o.name;

-- c) kontrola: šifrované moduly (definition IS NULL) a CLR procedury analyzátor neuvidí
SELECT o.type_desc, COUNT(*) AS cnt
FROM sys.objects AS o
LEFT JOIN sys.sql_modules AS m ON m.object_id = o.object_id
WHERE o.type IN ('P', 'FN', 'IF', 'TF', 'V', 'TR', 'PC', 'FS', 'FT')
  AND (m.definition IS NULL)
GROUP BY o.type_desc;
