-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE TRIGGER dbo.trg_StockLevel_Movement ON dbo.StockLevel
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.StockMovement (ProductId, WarehouseId, Qty, MovementType, Status, CreatedAt)
    SELECT i.ProductId, i.WarehouseId, i.QtyOnHand - d.QtyOnHand, 'ADJ', 1, GETDATE()
    FROM inserted i JOIN deleted d ON d.StockLevelId = i.StockLevelId
    WHERE i.QtyOnHand <> d.QtyOnHand;
END
GO

CREATE TRIGGER dbo.trg_Orders_Audit ON dbo.Orders
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLog (EntityName, EntityId, Action, Status, CreatedAt)
    SELECT 'Orders', i.OrderId, 'TRG', 1, GETDATE() FROM inserted i;
END
GO

CREATE TRIGGER dbo.trg_Product_PriceHistory ON dbo.Product
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.PriceHistory (ProductId, OldPrice, NewPrice, Status, CreatedAt)
    SELECT i.ProductId, d.CurrentPrice, i.CurrentPrice, 1, GETDATE()
    FROM inserted i JOIN deleted d ON d.ProductId = i.ProductId WHERE i.CurrentPrice <> d.CurrentPrice;
END
GO

CREATE TRIGGER dbo.trg_Payment_OrderPaid ON dbo.Payment
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE o SET o.IsPaid = 1 FROM dbo.Orders o JOIN inserted i ON i.OrderId = o.OrderId WHERE i.Status = 3;
END
GO

CREATE TRIGGER dbo.trg_Claim_Audit ON dbo.Claim
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLog (EntityName, EntityId, Action, Status, CreatedAt)
    SELECT 'Claim', i.ClaimId, 'TRG', 1, GETDATE() FROM inserted i;
END
GO

CREATE TRIGGER dbo.trg_Customer_Audit ON dbo.Customer
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLog (EntityName, EntityId, Action, Status, CreatedAt)
    SELECT 'Customer', i.CustomerId, 'TRG', 1, GETDATE() FROM inserted i;
END
GO
