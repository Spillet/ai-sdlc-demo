# Kontext pro AI: dbo.usp_Claim_ClaimStatusHistory_Delete

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 1022.

## Kód

```sql
CREATE PROCEDURE dbo.usp_Claim_ClaimStatusHistory_Delete
    @ClaimDocumentId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT oi.*, o.OrderId AS OrdersKey
    FROM dbo.OrderItem AS oi WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = oi.OrderId
    WHERE oi.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @ClaimDocumentId;
    UPDATE cd SET cd.ModifiedAt = GETDATE()
    FROM dbo.ClaimDocument cd
    INNER JOIN dbo.OrderItem oi2 ON oi2.OrderItemId = cd.ClaimDocumentId
    WHERE cd.ClaimDocumentId = @ClaimDocumentId;
    UPDATE dbo.ClaimStatusHistory SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ClaimStatusHistoryId = @ClaimDocumentId;
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.ClaimStatusHistory', @EntityId = @ClaimDocumentId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Error_Log @ClaimDocumentId = @ClaimDocumentId, @UserId = @UserId;
END
```

## Závislosti podle vrstev

- calls → `usp_Audit_Write` [static] (doména cíle: sdílené)
- calls → `usp_Error_Log` [static] (doména cíle: sdílené)
- reads → `ClaimDocument` [static] (doména cíle: D:Claim)
- reads → `OrderItem` [static] (doména cíle: sdílené)
- reads → `Orders` [static] (doména cíle: sdílené)
- writes → `ClaimDocument` [static] (doména cíle: D:Claim)
- writes → `ClaimStatusHistory` [static] (doména cíle: D:Claim)

## Kdo ji volá

- `usp_Claim_ClaimReason_Cleanup` [static]
- `usp_Claim_ClaimStatusHistory_Cleanup` [static]
- `usp_Claim_ClaimStatusHistory_Confirm` [static]

## Provoz (Query Store, 30 dní)

cpu_ms 11695, logical_reads 819448, logical_writes 8620, stmt_executions 6132

## Schéma dotčených tabulek

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
