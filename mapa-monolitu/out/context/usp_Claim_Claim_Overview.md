# Kontext pro AI: dbo.usp_Claim_Claim_Overview

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 1515.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_Claim_Overview
    @ClaimId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT c.*, c2.CustomerId AS CustomerKey
    FROM dbo.Claim AS c WITH (NOLOCK)
    JOIN dbo.Customer c2 ON c2.CustomerId = c.CustomerId
    WHERE c.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @ClaimId;
    SELECT @cnt = COUNT(*) FROM dbo.ServiceCenter WHERE ServiceCenterId = @ClaimId;
    SELECT * FROM dbo.tvf_ClaimItems(@ClaimId);
END
```

## Závislosti podle vrstev

- calls → `tvf_ClaimItems` [static] (doména cíle: D:Claim)
- reads → `Claim` [static] (doména cíle: D:Claim)
- reads → `Customer` [static] (doména cíle: sdílené)
- reads → `ServiceCenter` [static] (doména cíle: D:Claim)

## Kdo ji volá

- `usp_Claim_ClaimReason_Cleanup` [static]
- `usp_Claim_ClaimStatusHistory_Cleanup` [static]
- `usp_Claim_Claim_Archive` [static]

## Provoz (Query Store, 30 dní)

cpu_ms 8841, logical_reads 931058, logical_writes 0, stmt_executions 7575

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
