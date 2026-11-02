# Kontext pro AI: dbo.usp_Claim_Create

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 199741.

## Kód

```sql
-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE PROCEDURE dbo.usp_Claim_Create
    @OrderItemId      INT,
    @Qty              INT,
    @ReasonCode       VARCHAR(20),
    @DefectText       NVARCHAR(2000),
    @UserId           INT,
    @ClaimId          INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @OrderId INT, @CustomerId INT, @PurchasedAt DATETIME2, @IsBusiness BIT,
            @OrderedQty INT, @AlreadyClaimed INT, @ClaimNumber VARCHAR(20), @Seq BIGINT,
            @Deadline DATE;

    SELECT @OrderId = o.OrderId, @CustomerId = o.CustomerId, @PurchasedAt = o.CreatedAt,
           @IsBusiness = c.IsBusiness, @OrderedQty = oi.Qty
    FROM dbo.OrderItem AS oi
    JOIN dbo.Orders    AS o ON o.OrderId = oi.OrderId
    JOIN dbo.Customer  AS c ON c.CustomerId = o.CustomerId
    WHERE oi.OrderItemId = @OrderItemId;

    IF @OrderId IS NULL
    BEGIN
        RAISERROR(N'Polozka objednavky %d neexistuje.', 16, 1, @OrderItemId);
        RETURN 1;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.ClaimReason WHERE Code = @ReasonCode)
    BEGIN
        RAISERROR(N'Neznamy duvod reklamace.', 16, 1);
        RETURN 2;
    END

    -- zakonna lhuta: spotrebitel 24 mesicu, firma 12 (viz fn_Claim_Deadline)
    SET @Deadline = dbo.fn_Claim_Deadline(@PurchasedAt, @IsBusiness);
    IF @Deadline < CAST(GETDATE() AS DATE)
    BEGIN
        RAISERROR(N'Lhuta pro reklamaci vyprsela.', 16, 1);
        RETURN 3;
    END

    SELECT @AlreadyClaimed = ISNULL(SUM(ci.Qty), 0)
    FROM dbo.ClaimItem AS ci
    JOIN dbo.Claim     AS cl ON cl.ClaimId = ci.ClaimId
    WHERE ci.OrderItemId = @OrderItemId AND cl.Status <> 9;   -- 9 = zamitnuta

    IF @AlreadyClaimed + @Qty > @OrderedQty
    BEGIN
        RAISERROR(N'Reklamovane mnozstvi prevysuje objednane.', 16, 1);
        RETURN 4;
    END

    BEGIN TRY
        BEGIN TRAN;

        EXEC dbo.usp_Counter_Next @Name = 'CLAIM', @Value = @Seq OUTPUT;
        SET @ClaimNumber = 'R' + RIGHT('000000000' + CAST(@Seq AS VARCHAR(20)), 9);

        INSERT INTO dbo.Claim (OrderId, CustomerId, ServiceCenterId, ClaimNumber, ClaimType, Status, DeadlineAt, CreatedAt)
        VALUES (@OrderId, @CustomerId, NULL, @ClaimNumber, @ReasonCode, 1,
                DATEADD(DAY, 30, CAST(GETDATE() AS DATE)), GETDATE());   -- 30 dni na vyrizeni
        SET @ClaimId = SCOPE_IDENTITY();

        INSERT INTO dbo.ClaimItem (ClaimId, OrderItemId, Qty, DefectDescription, Status, CreatedAt)
        VALUES (@ClaimId, @OrderItemId, @Qty, @DefectText, 1, GETDATE());

        INSERT INTO dbo.ClaimStatusHistory (ClaimId, OldStatus, NewStatus, Note, Status, CreatedAt)
        VALUES (@ClaimId, 0, 1, N'Zalozeno', 1, GETDATE());

        EXEC dbo.usp_Audit_Write @EntityName = 'Claim', @EntityId = @ClaimId, @Action = 'CREATE', @UserId = @UserId;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        EXEC dbo.usp_Error_Log @ProcName = 'usp_Claim_Create', @Message = @msg;
        THROW;
    END CATCH
    RETURN 0;
END
```

## Závislosti podle vrstev

- calls → `fn_Claim_Deadline` [static] (doména cíle: D:Claim)
- calls → `trg_Claim_Audit` [static] {via_trigger} (doména cíle: D:Claim)
- calls → `usp_Audit_Write` [static] (doména cíle: sdílené)
- calls → `usp_Counter_Next` [static] (doména cíle: sdílené)
- calls → `usp_Error_Log` [static] (doména cíle: sdílené)
- reads → `Claim` [static] (doména cíle: D:Claim)
- reads → `ClaimItem` [static] (doména cíle: D:Claim)
- reads → `ClaimReason` [static] (doména cíle: D:Claim)
- reads → `Customer` [static] (doména cíle: sdílené)
- reads → `OrderItem` [static] (doména cíle: sdílené)
- reads → `Orders` [static] (doména cíle: sdílené)
- writes → `Claim` [static] (doména cíle: D:Claim)
- writes → `ClaimItem` [static] (doména cíle: D:Claim)
- writes → `ClaimStatusHistory` [static] (doména cíle: D:Claim)

## Kdo ji volá

- aplikace `Kompas.Web.Api`: 199614 volání (XE rpc_completed)
- aplikace `Konzole.exe`: 127 volání (XE rpc_completed)

## Provoz (Query Store, 30 dní)

cpu_ms 1671133, logical_reads 39457751, logical_writes 2475685, stmt_executions 1797669

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
