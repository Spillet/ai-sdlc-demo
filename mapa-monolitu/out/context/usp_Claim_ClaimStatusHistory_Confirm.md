# Kontext pro AI: dbo.usp_Claim_ClaimStatusHistory_Confirm

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 1064.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_ClaimStatusHistory_Confirm
    @ClaimItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ClaimReason WHERE ClaimReasonId = @ClaimItemId;
    SELECT @cnt = COUNT(*) FROM dbo.ReturnRequest WHERE ReturnRequestId = @ClaimItemId;
    SET @val = dbo.fn_UserName(@ClaimItemId);
    UPDATE dbo.ClaimItem SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ClaimItemId = @ClaimItemId;
    UPDATE dbo.ClaimStatusHistory SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ClaimStatusHistoryId = @ClaimItemId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Claim_ClaimStatusHistory_Confirm', @EntityId = @ClaimItemId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_Claim_ClaimStatusHistory_Delete @ClaimItemId = @ClaimItemId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Claim_Claim_Delete @ClaimItemId = @ClaimItemId, @UserId = @UserId;
    EXEC dbo.usp_Claim_ClaimItem_GetByCode @ClaimItemId = @ClaimItemId, @UserId = @UserId;
    EXEC dbo.usp_Claim_ServiceCenter_Merge @ClaimItemId = @ClaimItemId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Pay_GatewayLog_Update @ClaimItemId = @ClaimItemId;
    IF @rc <> 0 RETURN @rc;
END
```

## Závislosti podle vrstev

- calls → `fn_UserName` [static] (doména cíle: sdílené)
- calls → `usp_Audit_Write` [static] (doména cíle: sdílené)
- calls → `usp_Claim_ClaimItem_GetByCode` [static] (doména cíle: D:Claim)
- calls → `usp_Claim_ClaimStatusHistory_Delete` [static] (doména cíle: D:Claim)
- calls → `usp_Claim_Claim_Delete` [static] (doména cíle: D:Claim)
- calls → `usp_Claim_ServiceCenter_Merge` [static] (doména cíle: D:Claim)
- calls → `usp_Pay_GatewayLog_Update` [static] (doména cíle: D:GatewayLog)
- reads → `ClaimReason` [static] (doména cíle: D:Claim)
- reads → `ReturnRequest` [static] (doména cíle: D:Claim)
- writes → `ClaimItem` [static] (doména cíle: D:Claim)
- writes → `ClaimStatusHistory` [static] (doména cíle: D:Claim)

## Kdo ji volá

- aplikace `Konzole.exe`: 1064 volání (XE rpc_completed)

## Provoz (Query Store, 30 dní)

cpu_ms 3258, logical_reads 67638, logical_writes 13827, stmt_executions 5320

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
CREATE TABLE dbo.ClaimReason (
    ClaimReasonId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ClaimReason PRIMARY KEY,
    Code VARCHAR(20),
    Name NVARCHAR(100),
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
