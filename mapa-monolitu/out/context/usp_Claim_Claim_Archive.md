# Kontext pro AI: dbo.usp_Claim_Claim_Archive

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 4032.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_Claim_Archive
    @ClaimId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Claim_Claim_Archive';
    SELECT c.*, o.OrderId AS OrdersKey
    FROM dbo.Claim AS c WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = c.OrderId
    WHERE c.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.ClaimDocument WHERE ClaimDocumentId = @ClaimId;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @ClaimId;
    SELECT o2.*, c3.CustomerId AS CustomerKey
    FROM dbo.Orders AS o2 WITH (NOLOCK)
    JOIN dbo.Customer c3 ON c3.CustomerId = o2.CustomerId
    WHERE o2.Status = 1;
    INSERT INTO dbo.ReturnRequest (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.Claim', @EntityId = @ClaimId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_Claim_Delete @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Claim_ClaimStatusHistory_Merge @ClaimId = @ClaimId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Claim_Claim_Get @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_Claim_Overview @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Pay_PaymentMethod_SetStatus @ClaimId = @ClaimId, @UserId = @UserId;
END
```

## Závislosti podle vrstev

- calls → `usp_Audit_Write` [static] (doména cíle: sdílené)
- calls → `usp_Claim_ClaimStatusHistory_Merge` [static] (doména cíle: D:Claim)
- calls → `usp_Claim_Claim_Delete` [static] (doména cíle: D:Claim)
- calls → `usp_Claim_Claim_Get` [static] (doména cíle: D:Claim)
- calls → `usp_Claim_Claim_Overview` [static] (doména cíle: D:Claim)
- calls → `usp_JobRun_End` [static] (doména cíle: sdílené)
- calls → `usp_JobRun_Start` [static] (doména cíle: sdílené)
- calls → `usp_Pay_PaymentMethod_SetStatus` [static] (doména cíle: D:GatewayLog)
- reads → `Claim` [static] (doména cíle: D:Claim)
- reads → `ClaimDocument` [static] (doména cíle: D:Claim)
- reads → `Customer` [static] (doména cíle: sdílené)
- reads → `Orders` [static] (doména cíle: sdílené)
- writes → `ReturnRequest` [static] (doména cíle: D:Claim)

## Kdo ji volá

- aplikace `SQLAgent - TSQL JobStep`: 4032 volání (XE rpc_completed)
- plánovač: {'schedule': 'každých 15 min', 'enabled': True, 'job': 'KOMPAS - Claim Claim Archive', 'subsystem': 'TSQL'}

## Provoz (Query Store, 30 dní)

cpu_ms 39118, logical_reads 3931352, logical_writes 6077, stmt_executions 36288

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
