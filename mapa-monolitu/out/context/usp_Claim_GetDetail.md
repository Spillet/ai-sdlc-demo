# Kontext pro AI: dbo.usp_Claim_GetDetail

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 84948.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_GetDetail
    @ClaimId INT,
    @UserId  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @UserId IS NOT NULL
    BEGIN
        DECLARE @allowed BIT;
        EXEC dbo.usp_User_CheckPermission @UserId = @UserId, @Permission = 'CLAIM_READ', @Allowed = @allowed OUTPUT;
        IF @allowed = 0 RETURN 5;
    END

    -- 1) hlavicka
    SELECT cl.ClaimId, cl.ClaimNumber, cl.ClaimType, cl.Status, cl.Resolution, cl.DeadlineAt, cl.CreatedAt,
           o.OrderNumber, o.CreatedAt AS OrderedAt,
           c.CustomerId, c.Name AS CustomerName, c.Email, c.IsBusiness,
           sc.Name AS ServiceCenterName, sc.City AS ServiceCenterCity,
           DATEDIFF(DAY, CAST(GETDATE() AS DATE), cl.DeadlineAt) AS DaysLeft
    FROM dbo.Claim AS cl WITH (NOLOCK)
    JOIN dbo.Orders AS o WITH (NOLOCK) ON o.OrderId = cl.OrderId
    JOIN dbo.Customer AS c WITH (NOLOCK) ON c.CustomerId = cl.CustomerId
    LEFT JOIN dbo.ServiceCenter AS sc ON sc.ServiceCenterId = cl.ServiceCenterId
    WHERE cl.ClaimId = @ClaimId;

    -- 2) polozky
    SELECT ti.ClaimItemId, ti.OrderItemId, ti.ProductCode, ti.ProductName, ti.Qty, ti.UnitPrice, ti.DefectDescription
    FROM dbo.tvf_ClaimItems(@ClaimId) AS ti
    ORDER BY ti.ClaimItemId;

    -- 3) historie stavu
    SELECT h.OldStatus, h.NewStatus, h.Note, h.CreatedAt, dbo.fn_UserName(h.CreatedBy) AS ChangedBy
    FROM dbo.ClaimStatusHistory AS h
    WHERE h.ClaimId = @ClaimId
    ORDER BY h.CreatedAt;

    -- 4) dokumenty
    SELECT d.ClaimDocumentId, d.FileName, d.StorageKey, d.CreatedAt
    FROM dbo.ClaimDocument AS d
    WHERE d.ClaimId = @ClaimId;
END
```

## Závislosti podle vrstev

- calls → `fn_UserName` [static] (doména cíle: sdílené)
- calls → `tvf_ClaimItems` [static] (doména cíle: D:Claim)
- calls → `usp_User_CheckPermission` [static] (doména cíle: sdílené)
- reads → `Claim` [static] (doména cíle: D:Claim)
- reads → `ClaimDocument` [static] (doména cíle: D:Claim)
- reads → `ClaimStatusHistory` [static] (doména cíle: D:Claim)
- reads → `Customer` [static] (doména cíle: sdílené)
- reads → `Orders` [static] (doména cíle: sdílené)
- reads → `ServiceCenter` [static] (doména cíle: D:Claim)

## Kdo ji volá

- aplikace `Kompas.Web.Api`: 57225 volání (XE rpc_completed)
- aplikace `Konzole.exe`: 27723 volání (XE rpc_completed)

## Provoz (Query Store, 30 dní)

cpu_ms 1123008, logical_reads 36892973, logical_writes 0, stmt_executions 169896

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
