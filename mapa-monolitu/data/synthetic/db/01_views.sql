-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.
CREATE VIEW dbo.vw_ProductDetail
AS
SELECT p.*
FROM dbo.Product AS p
LEFT JOIN dbo.Brand AS b ON b.BrandId = p.BrandId
LEFT JOIN dbo.Category AS c ON c.CategoryId = p.CategoryId
LEFT JOIN dbo.ProductCategory AS pc ON pc.ProductId = p.ProductId;
GO

CREATE VIEW dbo.vw_ProductActive
AS
SELECT p.*
FROM dbo.Product AS p;
GO

CREATE VIEW dbo.vw_ProductWithPrice
AS
SELECT p.*
FROM dbo.Product AS p
LEFT JOIN dbo.PriceListItem AS pli ON pli.ProductId = p.ProductId
LEFT JOIN dbo.PriceList AS pl ON 1 = 0;
GO

CREATE VIEW dbo.vw_ActivePromo
AS
SELECT p.*
FROM dbo.Promo AS p
LEFT JOIN dbo.PromoProduct AS pp ON pp.PromoId = p.PromoId;
GO

CREATE VIEW dbo.vw_CustomerOverview
AS
SELECT c.*
FROM dbo.Customer AS c
LEFT JOIN dbo.CustomerAddress AS ca ON ca.CustomerId = c.CustomerId
LEFT JOIN dbo.CustomerSegment AS cs ON cs.CustomerSegmentId = c.CustomerSegmentId;
GO

CREATE VIEW dbo.vw_LoyaltyBalance
AS
SELECT la.*
FROM dbo.LoyaltyAccount AS la
LEFT JOIN dbo.LoyaltyTransaction AS lt ON lt.LoyaltyAccountId = la.LoyaltyAccountId;
GO

CREATE VIEW dbo.vw_OrderOverview
AS
SELECT o.*
FROM dbo.Orders AS o
LEFT JOIN dbo.Customer AS c ON c.CustomerId = o.CustomerId
LEFT JOIN dbo.OrderItem AS oi ON oi.OrderId = o.OrderId;
GO

CREATE VIEW dbo.vw_OrderOpen
AS
SELECT o.*
FROM dbo.Orders AS o
LEFT JOIN dbo.OrderStatusHistory AS osh ON osh.OrderId = o.OrderId;
GO

CREATE VIEW dbo.vw_OrderWithPayment
AS
SELECT o.*
FROM dbo.Orders AS o
LEFT JOIN dbo.Payment AS p ON p.OrderId = o.OrderId;
GO

CREATE VIEW dbo.vw_CartDetail
AS
SELECT c.*
FROM dbo.Cart AS c
LEFT JOIN dbo.CartItem AS ci ON ci.CartId = c.CartId
LEFT JOIN dbo.Product AS p ON 1 = 0;
GO

CREATE VIEW dbo.vw_StockAvailable
AS
SELECT sl.*
FROM dbo.StockLevel AS sl
LEFT JOIN dbo.StockReservation AS sr ON 1 = 0
LEFT JOIN dbo.Product AS p ON p.ProductId = sl.ProductId;
GO

CREATE VIEW dbo.vw_StockByWarehouse
AS
SELECT sl.*
FROM dbo.StockLevel AS sl
LEFT JOIN dbo.Warehouse AS w ON w.WarehouseId = sl.WarehouseId;
GO

CREATE VIEW dbo.vw_StockMovementLast30
AS
SELECT sm.*
FROM dbo.StockMovement AS sm;
GO

CREATE VIEW dbo.vw_InventoryDiff
AS
SELECT ic.*
FROM dbo.InventoryCount AS ic
LEFT JOIN dbo.InventoryCountItem AS ici ON ici.InventoryCountId = ic.InventoryCountId
LEFT JOIN dbo.StockLevel AS sl ON 1 = 0;
GO

CREATE VIEW dbo.vw_PurchaseOpen
AS
SELECT po.*
FROM dbo.PurchaseOrder AS po
LEFT JOIN dbo.PurchaseOrderItem AS poi ON poi.PurchaseOrderId = po.PurchaseOrderId
LEFT JOIN dbo.Supplier AS s ON s.SupplierId = po.SupplierId;
GO

CREATE VIEW dbo.vw_SupplierPrice
AS
SELECT sp.*
FROM dbo.SupplierProduct AS sp
LEFT JOIN dbo.Supplier AS s ON s.SupplierId = sp.SupplierId
LEFT JOIN dbo.Product AS p ON p.ProductId = sp.ProductId;
GO

CREATE VIEW dbo.vw_ShipmentOverview
AS
SELECT s.*
FROM dbo.Shipment AS s
LEFT JOIN dbo.Carrier AS c ON c.CarrierId = s.CarrierId
LEFT JOIN dbo.Orders AS o ON o.OrderId = s.OrderId;
GO

CREATE VIEW dbo.vw_ShipmentLastEvent
AS
SELECT s.*
FROM dbo.Shipment AS s
LEFT JOIN dbo.ShipmentTracking AS st ON st.ShipmentId = s.ShipmentId;
GO

CREATE VIEW dbo.vw_PaymentOverview
AS
SELECT p.*
FROM dbo.Payment AS p
LEFT JOIN dbo.PaymentMethod AS pm ON pm.PaymentMethodId = p.PaymentMethodId
LEFT JOIN dbo.PaymentTransaction AS pt ON pt.PaymentId = p.PaymentId;
GO

CREATE VIEW dbo.vw_RefundOpen
AS
SELECT r.*
FROM dbo.Refund AS r
LEFT JOIN dbo.Payment AS p ON p.PaymentId = r.PaymentId;
GO

CREATE VIEW dbo.vw_InvoiceOverview
AS
SELECT i.*
FROM dbo.Invoice AS i
LEFT JOIN dbo.InvoiceItem AS ii ON ii.InvoiceId = i.InvoiceId
LEFT JOIN dbo.Customer AS c ON c.CustomerId = i.CustomerId;
GO

CREATE VIEW dbo.vw_LedgerMonth
AS
SELECT le.*
FROM dbo.LedgerEntry AS le
LEFT JOIN dbo.Invoice AS i ON i.InvoiceId = le.InvoiceId;
GO

CREATE VIEW dbo.vw_ClaimOverview
AS
SELECT c.*
FROM dbo.Claim AS c
LEFT JOIN dbo.ClaimItem AS ci ON ci.ClaimId = c.ClaimId
LEFT JOIN dbo.ServiceCenter AS sc ON sc.ServiceCenterId = c.ServiceCenterId
LEFT JOIN dbo.Customer AS c2 ON c2.CustomerId = c.CustomerId;
GO

CREATE VIEW dbo.vw_ClaimOpen
AS
SELECT c.*
FROM dbo.Claim AS c
LEFT JOIN dbo.ClaimStatusHistory AS csh ON csh.ClaimId = c.ClaimId;
GO

CREATE VIEW dbo.vw_RptSalesByDay
AS
SELECT rds.*
FROM dbo.RptDailySales AS rds;
GO

CREATE VIEW dbo.vw_RptSalesAll
AS
SELECT OrderId, Amount, CreatedAt FROM dbo.Sales_2023
UNION ALL
SELECT OrderId, Amount, CreatedAt FROM dbo.Sales_2024
UNION ALL
SELECT OrderId, Amount, CreatedAt FROM dbo.Sales_2025
UNION ALL
SELECT OrderId, Amount, CreatedAt FROM dbo.Sales_2026;
GO

CREATE VIEW dbo.vw_RptStock
AS
SELECT rss.*
FROM dbo.RptStockSnapshot AS rss
LEFT JOIN dbo.Product AS p ON p.ProductId = rss.ProductId
LEFT JOIN dbo.Warehouse AS w ON w.WarehouseId = rss.WarehouseId;
GO

CREATE VIEW dbo.vw_RptMargin
AS
SELECT oi.*
FROM dbo.OrderItem AS oi
LEFT JOIN dbo.SupplierProduct AS sp ON 1 = 0
LEFT JOIN dbo.Product AS p ON p.ProductId = oi.ProductId;
GO

CREATE VIEW dbo.vw_UserPermissions
AS
SELECT u.*
FROM dbo.Users AS u
LEFT JOIN dbo.UserPermission AS up ON up.UserId = u.UserId;
GO

CREATE VIEW dbo.vw_AuditLast7
AS
SELECT al.*
FROM dbo.AuditLog AS al;
GO

CREATE VIEW dbo.vw_ErrorsToday
AS
SELECT el.*
FROM dbo.ErrorLog AS el;
GO

CREATE VIEW dbo.vw_OldOrdersMigr
AS
SELECT oo.*
FROM dbo.OldOrders AS oo
LEFT JOIN dbo.X_Migr_Customer AS xmc ON 1 = 0;
GO

CREATE VIEW dbo.vw_ProductBak
AS
SELECT p.*
FROM dbo.Product_bak2019 AS p;
GO

