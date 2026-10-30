# Kontext pro AI: dbo.usp_Claim_Claim_Get

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 2923.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_Claim_Get
    @ClaimId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT c.*, sc.ServiceCenterId AS ServiceCenterKey
    FROM dbo.Claim AS c WITH (NOLOCK)
    JOIN dbo.ServiceCenter sc ON sc.ServiceCenterId = c.ServiceCenterId
    WHERE c.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @ClaimId;
    SELECT @cnt = COUNT(*) FROM dbo.ServiceCenter WHERE ServiceCenterId = @ClaimId;
    SET @val = dbo.fn_GetSysParam('LIMIT_CLAIMS');
    EXEC usp_Audit_Write @EntityName = 'usp_Claim_Claim_Get', @EntityId = @ClaimId, @Action = 'UPD', @UserId = @UserId;
END
```

## Závislosti podle vrstev

- calls → `fn_GetSysParam` [static] (doména cíle: sdílené)
- calls → `usp_Audit_Write` [static] {caller_dependent} (doména cíle: sdílené)
- reads → `Claim` [static] (doména cíle: D:Claim)
- reads → `Product` [static] (doména cíle: sdílené)
- reads → `ServiceCenter` [static] (doména cíle: D:Claim)

## Kdo ji volá

- `usp_Claim_Claim_Archive` [static]

## Provoz (Query Store, 30 dní)

cpu_ms 4312, logical_reads 337468, logical_writes 0, stmt_executions 35076

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
-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

-- ===== Catalog =====
CREATE TABLE dbo.Product (
    ProductId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Product PRIMARY KEY,
    BrandId INT NULL,
    CategoryId INT NULL,
    Code VARCHAR(20),
    Name NVARCHAR(200),
    Ean VARCHAR(14),
    IsActive BIT,
    Weight DECIMAL(9,3),
    CurrentPrice DECIMAL(12,2),
    StockQtyCache INT,
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
