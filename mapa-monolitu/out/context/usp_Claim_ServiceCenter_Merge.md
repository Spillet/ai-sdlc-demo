# Kontext pro AI: dbo.usp_Claim_ServiceCenter_Merge

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 1498.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_ServiceCenter_Merge
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @CustomerId;
    DELETE FROM dbo.ServiceCenter WHERE ServiceCenterId = @CustomerId AND Status = 0;
END
```

## Závislosti podle vrstev

- reads → `Customer` [static] (doména cíle: sdílené)
- reads → `OrderItem` [static] (doména cíle: sdílené)
- reads → `ServiceCenter` [static] (doména cíle: D:Claim)
- writes → `ServiceCenter` [static] (doména cíle: D:Claim)

## Kdo ji volá

- `usp_Claim_ClaimReason_Hourly` [static]
- `usp_Claim_ClaimStatusHistory_Confirm` [static]
- aplikace `Konzole.exe`: 641 volání (XE rpc_completed)

## Provoz (Query Store, 30 dní)

cpu_ms 17933, logical_reads 919440, logical_writes 10325, stmt_executions 4494

## Schéma dotčených tabulek

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
CREATE TABLE dbo.OrderItem (
    OrderItemId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrderItem PRIMARY KEY,
    OrderId INT NULL,
    ProductId INT NULL,
    Qty INT,
    UnitPrice DECIMAL(12,2),
    VatRate DECIMAL(5,2),
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
