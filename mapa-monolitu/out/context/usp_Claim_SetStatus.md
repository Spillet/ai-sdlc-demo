# Kontext pro AI: dbo.usp_Claim_SetStatus

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 21.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_SetStatus
    @ClaimId    INT,
    @NewStatus  TINYINT,          -- 1 nova, 2 v servisu, 3 uznana-oprava, 4 uznana-vymena, 5 uznana-dobropis, 9 zamitnuta
    @Note       NVARCHAR(400) = NULL,
    @UserId     INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @OldStatus TINYINT, @OrderId INT, @PaymentId INT, @Amount DECIMAL(12,2);

    SELECT @OldStatus = Status, @OrderId = OrderId FROM dbo.Claim WHERE ClaimId = @ClaimId;
    IF @OldStatus IS NULL RETURN 1;
    IF @OldStatus IN (5, 9) AND @NewStatus <> @OldStatus
    BEGIN
        RAISERROR(N'Uzavrenou reklamaci nelze menit.', 16, 1);
        RETURN 2;
    END

    BEGIN TRAN;

    UPDATE dbo.Claim
    SET Status = @NewStatus,
        Resolution = CASE @NewStatus WHEN 3 THEN 'REPAIR' WHEN 4 THEN 'REPLACE' WHEN 5 THEN 'REFUND' WHEN 9 THEN 'REJECTED' ELSE Resolution END,
        ModifiedAt = GETDATE()
    WHERE ClaimId = @ClaimId;

    INSERT INTO dbo.ClaimStatusHistory (ClaimId, OldStatus, NewStatus, Note, Status, CreatedAt, CreatedBy)
    VALUES (@ClaimId, @OldStatus, @NewStatus, @Note, 1, GETDATE(), @UserId);

    IF @NewStatus = 4
    BEGIN
        -- vymena: odepsat kus ze skladu primo (historicky, sklad o tom nevi jinak nez triggerem)
        UPDATE sl
        SET sl.QtyOnHand = sl.QtyOnHand - ci.Qty, sl.ModifiedAt = GETDATE()
        FROM dbo.StockLevel AS sl
        JOIN dbo.OrderItem  AS oi ON oi.ProductId = sl.ProductId
        JOIN dbo.ClaimItem  AS ci ON ci.OrderItemId = oi.OrderItemId
        WHERE ci.ClaimId = @ClaimId
          AND sl.WarehouseId = 1;   -- centralni sklad natvrdo
    END

    IF @NewStatus = 5
    BEGIN
        SELECT TOP (1) @PaymentId = p.PaymentId FROM dbo.Payment AS p WHERE p.OrderId = @OrderId ORDER BY p.CreatedAt DESC;
        SELECT @Amount = SUM(ci.Qty * oi.UnitPrice)
        FROM dbo.ClaimItem AS ci JOIN dbo.OrderItem AS oi ON oi.OrderItemId = ci.OrderItemId
        WHERE ci.ClaimId = @ClaimId;
        EXEC dbo.usp_Refund_Create @PaymentId = @PaymentId, @Amount = @Amount, @Reason = N'Reklamace', @UserId = @UserId;
    END

    EXEC dbo.usp_Audit_Write @EntityName = 'Claim', @EntityId = @ClaimId, @Action = 'STATUS', @UserId = @UserId;

    COMMIT;
    RETURN 0;
END
```

## Závislosti podle vrstev

- calls → `trg_Claim_Audit` [static] {via_trigger} (doména cíle: D:Claim)
- calls → `trg_StockLevel_Movement` [static] {via_trigger} (doména cíle: D:Warehouse)
- calls → `usp_Audit_Write` [static] (doména cíle: sdílené)
- calls → `usp_Refund_Create` [static] (doména cíle: D:GatewayLog)
- reads → `Claim` [static] (doména cíle: D:Claim)
- reads → `ClaimItem` [static] (doména cíle: D:Claim)
- reads → `OrderItem` [static] (doména cíle: sdílené)
- reads → `Payment` [static] (doména cíle: sdílené)
- reads → `StockLevel` [static] (doména cíle: sdílené)
- writes → `Claim` [static] (doména cíle: D:Claim)
- writes → `ClaimStatusHistory` [static] (doména cíle: D:Claim)
- writes → `StockLevel` [static] (doména cíle: sdílené)

## Kdo ji volá

- aplikace `Konzole.exe`: 21 volání (XE rpc_completed)

## Provoz (Query Store, 30 dní)

cpu_ms 177, logical_reads 14938, logical_writes 104, stmt_executions 210

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
-- ===== Payments =====
CREATE TABLE dbo.Payment (
    PaymentId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Payment PRIMARY KEY,
    OrderId INT NULL,
    PaymentMethodId INT NULL,
    Amount DECIMAL(12,2),
    Currency CHAR(3),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
```sql
CREATE TABLE dbo.StockLevel (
    StockLevelId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_StockLevel PRIMARY KEY,
    ProductId INT NULL,
    WarehouseId INT NULL,
    QtyOnHand INT,
    QtyReserved INT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
