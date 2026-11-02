# Kontext pro AI: dbo.usp_Claim_ClaimReason_Hourly

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 42.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_ClaimReason_Hourly
    @ClaimItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Claim_ClaimReason_Hourly';
    SELECT @cnt = COUNT(*) FROM dbo.ClaimItem WHERE ClaimItemId = @ClaimItemId;
    SELECT @cnt = COUNT(*) FROM dbo.ServiceCenter WHERE ServiceCenterId = @ClaimItemId;
    INSERT INTO dbo.ClaimStatusHistory (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.ReturnRequest', @EntityId = @ClaimItemId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @ClaimItemId = @ClaimItemId, @UserId = @UserId;
    EXEC dbo.usp_Claim_Claim_Delete @ClaimItemId = @ClaimItemId, @UserId = @UserId;
    EXEC dbo.usp_Claim_ServiceCenter_Merge @ClaimItemId = @ClaimItemId, @UserId = @UserId;
    EXEC dbo.usp_Pay_Installment_Save @ClaimItemId = @ClaimItemId, @UserId = @UserId;
END
```

## Závislosti podle vrstev

- calls → `usp_Audit_Write` [static] (doména cíle: sdílené)
- calls → `usp_Claim_Claim_Delete` [static] (doména cíle: D:Claim)
- calls → `usp_Claim_ServiceCenter_Merge` [static] (doména cíle: D:Claim)
- calls → `usp_JobRun_End` [static] (doména cíle: sdílené)
- calls → `usp_JobRun_Start` [static] (doména cíle: sdílené)
- calls → `usp_Pay_Installment_Save` [static] (doména cíle: D:GatewayLog)
- reads → `ClaimItem` [static] (doména cíle: D:Claim)
- reads → `ServiceCenter` [static] (doména cíle: D:Claim)
- writes → `ClaimStatusHistory` [static] (doména cíle: D:Claim)

## Kdo ji volá

- aplikace `SQLAgent - TSQL JobStep`: 42 volání (XE rpc_completed)
- plánovač: {'schedule': 'denně 03:30', 'enabled': True, 'job': 'KOMPAS - Claim ClaimReason Hourly', 'subsystem': 'TSQL'}

## Provoz (Query Store, 30 dní)

cpu_ms 65, logical_reads 1982, logical_writes 273, stmt_executions 462

## Schéma dotčených tabulek

```sql
CREATE TABLE dbo.ClaimItem (
    ClaimItemId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ClaimItem PRIMARY KEY,
    ClaimId INT NULL,
    OrderItemId INT NULL,
    Qty INT,
    DefectDescription NVARCHAR(2000),
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
CREATE TABLE dbo.ServiceCenter (
    ServiceCenterId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ServiceCenter PRIMARY KEY,
    Name NVARCHAR(100),
    City NVARCHAR(100),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
