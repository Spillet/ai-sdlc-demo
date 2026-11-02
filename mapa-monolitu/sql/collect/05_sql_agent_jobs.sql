-- =====================================================================
-- 05  Kroky SQL Agent jobů  ->  <data>/scheduler/sql_agent_jobs.csv
--     sloupce: job_name, step_id, step_name, subsystem, database_name, command, schedule, enabled
-- =====================================================================
-- NESPOUŠTĚNO proti reálné DB. Čte msdb. Rozvrh je zjednodušený popis;
-- pro přesný výpočet použít msdb.dbo.sysschedules podrobně.
-- Pozor: kroky typu PowerShell, CmdExec nebo SSIS volají procedury také,
-- analyzátor je hledá v textu příkazu, SSIS balíčky ale nevidí.
SET NOCOUNT ON;
SELECT j.name AS job_name, s.step_id, s.step_name, s.subsystem, s.database_name,
       REPLACE(REPLACE(s.command, CHAR(13), ' '), CHAR(10), ' ') AS command,
       ISNULL(STUFF((
           SELECT '; ' + CASE sc.freq_type
                    WHEN 4  THEN 'denně'
                    WHEN 8  THEN 'týdně'
                    WHEN 16 THEN 'měsíčně (den ' + CAST(sc.freq_interval AS VARCHAR(3)) + ')'
                    WHEN 32 THEN 'měsíčně relativně'
                    WHEN 64 THEN 'při startu agenta'
                    WHEN 1  THEN 'jednou'
                    ELSE 'jiné' END
                  + CASE WHEN sc.freq_subday_type = 4 THEN ' každých ' + CAST(sc.freq_subday_interval AS VARCHAR(5)) + ' min'
                         WHEN sc.freq_subday_type = 8 THEN ' každých ' + CAST(sc.freq_subday_interval AS VARCHAR(5)) + ' h'
                         ELSE ' ' + STUFF(STUFF(RIGHT('000000' + CAST(sc.active_start_time AS VARCHAR(6)), 6), 5, 0, ':'), 3, 0, ':') END
           FROM msdb.dbo.sysjobschedules AS js
           JOIN msdb.dbo.sysschedules AS sc ON sc.schedule_id = js.schedule_id
           WHERE js.job_id = j.job_id AND sc.enabled = 1
           FOR XML PATH('')), 1, 2, ''), 'bez rozvrhu') AS schedule,
       CAST(j.enabled AS INT) AS enabled
FROM msdb.dbo.sysjobs AS j
JOIN msdb.dbo.sysjobsteps AS s ON s.job_id = j.job_id
ORDER BY j.name, s.step_id;
