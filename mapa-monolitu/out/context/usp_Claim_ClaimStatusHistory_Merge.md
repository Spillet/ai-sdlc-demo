# Kontext pro AI: dbo.usp_Claim_ClaimStatusHistory_Merge

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 1772.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_ClaimStatusHistory_Merge
    @ClaimId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Claim WHERE ClaimId = @ClaimId;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @ClaimId;
    SET @val = dbo.fn_IsWorkingDay(@ClaimId);
    MERGE dbo.ClaimStatusHistory AS tgt
    USING (SELECT @ClaimId AS ClaimStatusHistoryId) AS src ON tgt.ClaimStatusHistoryId = src.ClaimStatusHistoryId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.ClaimStatusHistory', @EntityId = @ClaimId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_Error_Log @ClaimId = @ClaimId;
    IF @rc <> 0 RETURN @rc;
END
```

## Závislosti podle vrstev

- calls → `fn_IsWorkingDay` [static] (doména cíle: sdílené)
- calls → `usp_Audit_Write` [static] (doména cíle: sdílené)
- calls → `usp_Error_Log` [static] (doména cíle: sdílené)
- reads → `Claim` [static] (doména cíle: D:Claim)
- reads → `Customer` [static] (doména cíle: sdílené)
- writes → `ClaimStatusHistory` [static] (doména cíle: D:Claim)

## Kdo ji volá

- `usp_Claim_ClaimStatusHistory_Cleanup` [static]
- `usp_Claim_Claim_Archive` [static]

## Provoz (Query Store, 30 dní)

cpu_ms 9520, logical_reads 820045, logical_writes 8739, stmt_executions 12404

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
-- ===== Customers =====
CREATE TABLE dbo.Customer (
    CustomerId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customer PRIMARY KEY,
    CustomerSegmentId INT NULL,
    Email NVARCHAR(200),
    Name NVARCHAR(200),
    IsBusiness BIT,
    VatId VARCHAR(20) NULL,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
