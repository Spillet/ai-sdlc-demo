# Kontext pro AI: dbo.usp_Claim_Claim_Delete

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 4081.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_Claim_Delete
    @ClaimId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ServiceCenter WHERE ServiceCenterId = @ClaimId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_ClaimOverview WHERE Id = @ClaimId;
    SET @val = dbo.fn_GetSysParam('LIMIT_CLAIMS');
    UPDATE c SET c.ModifiedAt = GETDATE()
    FROM dbo.Claim c
    INNER JOIN dbo.ServiceCenter sc2 ON sc2.ServiceCenterId = c.ClaimId
    WHERE c.ClaimId = @ClaimId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Claim_Claim_Delete', @EntityId = @ClaimId, @Action = 'UPD', @UserId = @UserId;
END
```

## Závislosti podle vrstev

- calls → `fn_GetSysParam` [static] (doména cíle: sdílené)
- calls → `trg_Claim_Audit` [static] {via_trigger} (doména cíle: D:Claim)
- calls → `usp_Audit_Write` [static] (doména cíle: sdílené)
- reads → `Claim` [static] (doména cíle: D:Claim)
- reads → `ServiceCenter` [static] (doména cíle: D:Claim)
- reads → `vw_ClaimOverview` [static] (doména cíle: sdílené)
- writes → `Claim` [static] (doména cíle: D:Claim)

## Kdo ji volá

- `usp_Claim_ClaimReason_Hourly` [static]
- `usp_Claim_ClaimStatusHistory_Cleanup` [static]
- `usp_Claim_ClaimStatusHistory_Confirm` [static]
- `usp_Claim_Claim_Archive` [static]

## Provoz (Query Store, 30 dní)

cpu_ms 6064, logical_reads 469069, logical_writes 5652, stmt_executions 48972

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
