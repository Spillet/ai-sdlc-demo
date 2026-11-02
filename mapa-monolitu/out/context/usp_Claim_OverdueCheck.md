# Kontext pro AI: dbo.usp_Claim_OverdueCheck

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 42.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_OverdueCheck
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @run BIGINT, @warnDays INT, @ClaimId INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'ClaimOverdue', @RunId = @run OUTPUT;

    SELECT @warnDays = CAST(Value AS INT) FROM dbo.SysParam WHERE Name = 'CLAIM_WARN_DAYS';

    -- oznacit reklamace, kterym konci zakonna lhuta 30 dni
    UPDATE dbo.Claim SET Status = 7, ModifiedAt = GETDATE()     -- 7 = hrozi prekroceni lhuty
    WHERE Status IN (1, 2) AND dbo.fn_WorkingDaysBetween(GETDATE(), DeadlineAt) <= @warnDays;

    INSERT INTO dbo.ClaimStatusHistory (ClaimId, OldStatus, NewStatus, Note, Status, CreatedAt)
    SELECT ClaimId, 2, 7, N'Automaticky: blizi se lhuta', 1, GETDATE()
    FROM dbo.Claim WHERE Status = 7 AND ModifiedAt >= DATEADD(MINUTE, -5, GETDATE());

    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT ClaimId FROM dbo.Claim WHERE Status = 7;
    OPEN c;
    FETCH NEXT FROM c INTO @ClaimId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.usp_Claim_Notify @ClaimId = @ClaimId;
        FETCH NEXT FROM c INTO @ClaimId;
    END
    CLOSE c; DEALLOCATE c;

    EXEC dbo.usp_JobRun_End @RunId = @run;
END
```

## Závislosti podle vrstev

- calls → `fn_WorkingDaysBetween` [static] (doména cíle: sdílené)
- calls → `trg_Claim_Audit` [static] {via_trigger} (doména cíle: D:Claim)
- calls → `usp_Claim_Notify` [static] (doména cíle: D:Claim)
- calls → `usp_JobRun_End` [static] (doména cíle: sdílené)
- calls → `usp_JobRun_Start` [static] (doména cíle: sdílené)
- reads → `Claim` [static] (doména cíle: D:Claim)
- reads → `SysParam` [static] (doména cíle: D:SysParam)
- writes → `Claim` [static] (doména cíle: D:Claim)
- writes → `ClaimStatusHistory` [static] (doména cíle: D:Claim)

## Kdo ji volá

- aplikace `SQLAgent - TSQL JobStep`: 42 volání (XE rpc_completed)
- plánovač: {'schedule': 'denně 06:00', 'enabled': True, 'job': 'KOMPAS - Claim OverdueCheck', 'subsystem': 'TSQL'}

## Provoz (Query Store, 30 dní)

cpu_ms 158, logical_reads 8988, logical_writes 277, stmt_executions 84

## Schéma dotčených tabulek

```sql
-- ===== Claims =====
CREATE TABLE dbo.Claim (
    ClaimId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Claim PRIMARY KEY,
    OrderId INT NULL,
    CustomerId INT NULL,
    ServiceCenterId INT NULL,
    ClaimNumber VARCHAR(20),
    ClaimType VARCHAR(20),
    Resolution VARCHAR(30) NULL,
    DeadlineAt DATE,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
```sql
CREATE TABLE dbo.ClaimStatusHistory (
    ClaimStatusHistoryId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ClaimStatusHistory PRIMARY KEY,
    ClaimId INT NULL,
    OldStatus TINYINT,
    NewStatus TINYINT,
    Note NVARCHAR(400),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
```sql
CREATE TABLE dbo.SysParam (
    SysParamId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SysParam PRIMARY KEY,
    Name VARCHAR(100),
    Value NVARCHAR(400),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
