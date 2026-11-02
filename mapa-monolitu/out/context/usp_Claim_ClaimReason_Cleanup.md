# Kontext pro AI: dbo.usp_Claim_ClaimReason_Cleanup

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 42.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_ClaimReason_Cleanup
    @ClaimId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Claim_ClaimReason_Cleanup';
    SELECT @cnt = COUNT(*) FROM dbo.Claim WHERE ClaimId = @ClaimId;
    SELECT csh.*, c2.ClaimId AS ClaimKey
    FROM dbo.ClaimStatusHistory AS csh WITH (NOLOCK)
    JOIN dbo.Claim c2 ON c2.ClaimId = csh.ClaimId
    WHERE csh.Status = 1;
    DELETE FROM dbo.ClaimDocument WHERE ClaimDocumentId = @ClaimId AND Status = 0;
    MERGE dbo.ReturnRequest AS tgt
    USING (SELECT @ClaimId AS ReturnRequestId) AS src ON tgt.ReturnRequestId = src.ReturnRequestId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Claim_ClaimReason_Cleanup', @EntityId = @ClaimId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_ClaimStatusHistory_Delete @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_Claim_Overview @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Pay_Refund_Insert @ClaimId = @ClaimId, @UserId = @UserId;
END
```

## Závislosti podle vrstev

- calls → `usp_Audit_Write` [static] (doména cíle: sdílené)
- calls → `usp_Claim_ClaimStatusHistory_Delete` [static] (doména cíle: D:Claim)
- calls → `usp_Claim_Claim_Overview` [static] (doména cíle: D:Claim)
- calls → `usp_JobRun_End` [static] (doména cíle: sdílené)
- calls → `usp_JobRun_Start` [static] (doména cíle: sdílené)
- calls → `usp_Pay_Refund_Insert` [static] (doména cíle: D:GatewayLog)
- reads → `Claim` [static] (doména cíle: D:Claim)
- reads → `ClaimDocument` [static] (doména cíle: D:Claim)
- reads → `ClaimStatusHistory` [static] (doména cíle: D:Claim)
- writes → `ClaimDocument` [static] (doména cíle: D:Claim)
- writes → `ReturnRequest` [static] (doména cíle: D:Claim)

## Kdo ji volá

- aplikace `SQLAgent - TSQL JobStep`: 42 volání (XE rpc_completed)
- plánovač: {'schedule': 'denně 01:00', 'enabled': True, 'job': 'KOMPAS - Claim ClaimReason Cleanup', 'subsystem': 'TSQL'}

## Provoz (Query Store, 30 dní)

cpu_ms 63, logical_reads 7351, logical_writes 161, stmt_executions 378

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
