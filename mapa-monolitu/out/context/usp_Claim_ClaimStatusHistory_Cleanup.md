# Kontext pro AI: dbo.usp_Claim_ClaimStatusHistory_Cleanup

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 42.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_ClaimStatusHistory_Cleanup
    @ClaimId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Claim_ClaimStatusHistory_Cleanup';
    SELECT @cnt = COUNT(*) FROM dbo.ClaimDocument WHERE ClaimDocumentId = @ClaimId;
    SELECT @cnt = COUNT(*) FROM dbo.ReturnRequest WHERE ReturnRequestId = @ClaimId;
    SELECT * FROM dbo.tvf_ClaimItems(@ClaimId);
    UPDATE dbo.Claim SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ClaimId = @ClaimId;
    INSERT INTO dbo.ClaimItem (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    MERGE dbo.ReturnRequest AS tgt
    USING (SELECT @ClaimId AS ReturnRequestId) AS src ON tgt.ReturnRequestId = src.ReturnRequestId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Claim_ClaimStatusHistory_Cleanup', @EntityId = @ClaimId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_Claim_Delete @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_Claim_Overview @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_ClaimStatusHistory_Delete @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_ClaimStatusHistory_Merge @ClaimId = @ClaimId, @UserId = @UserId;
END
```

## Závislosti podle vrstev

- calls → `trg_Claim_Audit` [static] {via_trigger} (doména cíle: D:Claim)
- calls → `tvf_ClaimItems` [static] (doména cíle: D:Claim)
- calls → `usp_Audit_Write` [static] (doména cíle: sdílené)
- calls → `usp_Claim_ClaimStatusHistory_Delete` [static] (doména cíle: D:Claim)
- calls → `usp_Claim_ClaimStatusHistory_Merge` [static] (doména cíle: D:Claim)
- calls → `usp_Claim_Claim_Delete` [static] (doména cíle: D:Claim)
- calls → `usp_Claim_Claim_Overview` [static] (doména cíle: D:Claim)
- calls → `usp_JobRun_End` [static] (doména cíle: sdílené)
- calls → `usp_JobRun_Start` [static] (doména cíle: sdílené)
- reads → `ClaimDocument` [static] (doména cíle: D:Claim)
- reads → `ReturnRequest` [static] (doména cíle: D:Claim)
- writes → `Claim` [static] (doména cíle: D:Claim)
- writes → `ClaimItem` [static] (doména cíle: D:Claim)
- writes → `ReturnRequest` [static] (doména cíle: D:Claim)

## Kdo ji volá

- aplikace `SQLAgent - TSQL JobStep`: 42 volání (XE rpc_completed)
- plánovač: {'schedule': 'denně 03:30', 'enabled': True, 'job': 'KOMPAS - Claim ClaimStatusHistory Cleanup', 'subsystem': 'TSQL'}

## Provoz (Query Store, 30 dní)

cpu_ms 170, logical_reads 17030, logical_writes 607, stmt_executions 168

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
CREATE TABLE dbo.ClaimDocument (
    ClaimDocumentId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ClaimDocument PRIMARY KEY,
    ClaimId INT NULL,
    FileName NVARCHAR(200),
    StorageKey VARCHAR(100),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
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
CREATE TABLE dbo.ReturnRequest (
    ReturnRequestId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ReturnRequest PRIMARY KEY,
    OrderId INT NULL,
    CustomerId INT NULL,
    Reason NVARCHAR(400),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
