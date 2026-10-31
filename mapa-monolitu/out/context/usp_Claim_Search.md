# Kontext pro AI: dbo.usp_Claim_Search

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 13848.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_Search
    @ClaimNumber VARCHAR(20) = NULL,
    @CustomerEmail NVARCHAR(200) = NULL,
    @Status TINYINT = NULL,
    @CreatedFrom DATE = NULL,
    @Top INT = 200
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT TOP (@Top) cl.ClaimId, cl.ClaimNumber, cl.Status, cl.CreatedAt, c.Name, o.OrderNumber
FROM dbo.Claim cl
JOIN dbo.Customer c ON c.CustomerId = cl.CustomerId
JOIN dbo.Orders o ON o.OrderId = cl.OrderId
WHERE 1 = 1';
    IF @ClaimNumber IS NOT NULL SET @sql += N' AND cl.ClaimNumber = @ClaimNumber';
    IF @CustomerEmail IS NOT NULL SET @sql += N' AND c.Email LIKE @CustomerEmail + ''%''';
    IF @Status IS NOT NULL SET @sql += N' AND cl.Status = @Status';
    IF @CreatedFrom IS NOT NULL SET @sql += N' AND cl.CreatedAt >= @CreatedFrom';
    SET @sql += N' ORDER BY cl.CreatedAt DESC';

    EXEC sp_executesql @sql,
        N'@Top INT, @ClaimNumber VARCHAR(20), @CustomerEmail NVARCHAR(200), @Status TINYINT, @CreatedFrom DATE',
        @Top, @ClaimNumber, @CustomerEmail, @Status, @CreatedFrom;
END
```

## Závislosti podle vrstev

- reads → `Claim` [dynamic, runtime] {dynamic_sql} (doména cíle: D:Claim)
- reads → `Customer` [dynamic, runtime] {dynamic_sql} (doména cíle: sdílené)
- reads → `Orders` [dynamic, runtime] {dynamic_sql} (doména cíle: sdílené)

## Kdo ji volá

- aplikace `Konzole.exe`: 13848 volání (XE rpc_completed)

## Dynamické SQL

Tabulky z literálů: Claim, Customer, Orders. Blind spot (skládané jméno): ne.

## Provoz (Query Store, 30 dní)

cpu_ms 15654, logical_reads 1086304, logical_writes 0, stmt_executions 138480

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
-- ===== Orders =====
CREATE TABLE dbo.Orders (
    OrderId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId INT NULL,
    OrderNumber VARCHAR(20),
    TotalAmount DECIMAL(12,2),
    Currency CHAR(3),
    IsPaid BIT,
    ShippingStatus TINYINT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
