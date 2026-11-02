-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

-- ===== Catalog =====
CREATE TABLE dbo.Product (
    ProductId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Product PRIMARY KEY,
    BrandId INT NULL,
    CategoryId INT NULL,
    Code VARCHAR(20),
    Name NVARCHAR(200),
    Ean VARCHAR(14),
    IsActive BIT,
    Weight DECIMAL(9,3),
    CurrentPrice DECIMAL(12,2),
    StockQtyCache INT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.Product ADD CONSTRAINT FK_Product_Brand FOREIGN KEY (BrandId) REFERENCES dbo.Brand (BrandId);
GO
ALTER TABLE dbo.Product ADD CONSTRAINT FK_Product_Category FOREIGN KEY (CategoryId) REFERENCES dbo.Category (CategoryId);
GO

CREATE TABLE dbo.Category (
    CategoryId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Category PRIMARY KEY,
    Name NVARCHAR(100),
    ParentCategoryId INT NULL,
    SortOrder INT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.ProductCategory (
    ProductCategoryId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProductCategory PRIMARY KEY,
    ProductId INT NULL,
    CategoryId INT NULL,
    IsPrimary BIT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.ProductCategory ADD CONSTRAINT FK_ProductCategory_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO
ALTER TABLE dbo.ProductCategory ADD CONSTRAINT FK_ProductCategory_Category FOREIGN KEY (CategoryId) REFERENCES dbo.Category (CategoryId);
GO

CREATE TABLE dbo.Brand (
    BrandId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Brand PRIMARY KEY,
    Name NVARCHAR(100),
    Country CHAR(2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.AttributeDef (
    AttributeDefId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AttributeDef PRIMARY KEY,
    Name NVARCHAR(100),
    DataType VARCHAR(20),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.ProductAttribute (
    ProductAttributeId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProductAttribute PRIMARY KEY,
    ProductId INT NULL,
    AttributeDefId INT NULL,
    Value NVARCHAR(400),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.ProductAttribute ADD CONSTRAINT FK_ProductAttribute_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO
ALTER TABLE dbo.ProductAttribute ADD CONSTRAINT FK_ProductAttribute_AttributeDef FOREIGN KEY (AttributeDefId) REFERENCES dbo.AttributeDef (AttributeDefId);
GO

CREATE TABLE dbo.ProductImage (
    ProductImageId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProductImage PRIMARY KEY,
    ProductId INT NULL,
    Url NVARCHAR(400),
    SortOrder INT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.ProductImage ADD CONSTRAINT FK_ProductImage_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO

CREATE TABLE dbo.ProductText (
    ProductTextId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProductText PRIMARY KEY,
    ProductId INT NULL,
    Lang CHAR(2),
    Body NVARCHAR(MAX),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.ProductText ADD CONSTRAINT FK_ProductText_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO


-- ===== Pricing =====
CREATE TABLE dbo.PriceList (
    PriceListId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PriceList PRIMARY KEY,
    Name NVARCHAR(100),
    Currency CHAR(3),
    ValidFrom DATE,
    ValidTo DATE,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.PriceListItem (
    PriceListItemId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PriceListItem PRIMARY KEY,
    PriceListId INT NULL,
    ProductId INT NULL,
    Price DECIMAL(12,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.PriceListItem ADD CONSTRAINT FK_PriceListItem_PriceList FOREIGN KEY (PriceListId) REFERENCES dbo.PriceList (PriceListId);
GO
ALTER TABLE dbo.PriceListItem ADD CONSTRAINT FK_PriceListItem_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO

CREATE TABLE dbo.Promo (
    PromoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Promo PRIMARY KEY,
    Name NVARCHAR(100),
    DiscountPct DECIMAL(5,2),
    ValidFrom DATE,
    ValidTo DATE,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.PromoProduct (
    PromoProductId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PromoProduct PRIMARY KEY,
    PromoId INT NULL,
    ProductId INT NULL,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.PromoProduct ADD CONSTRAINT FK_PromoProduct_Promo FOREIGN KEY (PromoId) REFERENCES dbo.Promo (PromoId);
GO
ALTER TABLE dbo.PromoProduct ADD CONSTRAINT FK_PromoProduct_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO

CREATE TABLE dbo.Voucher (
    VoucherId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Voucher PRIMARY KEY,
    PromoId INT NULL,
    Code VARCHAR(30),
    MaxUses INT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.Voucher ADD CONSTRAINT FK_Voucher_Promo FOREIGN KEY (PromoId) REFERENCES dbo.Promo (PromoId);
GO

CREATE TABLE dbo.VoucherUse (
    VoucherUseId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VoucherUse PRIMARY KEY,
    VoucherId INT NULL,
    OrderId INT NULL,
    UsedAt DATETIME2,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.VoucherUse ADD CONSTRAINT FK_VoucherUse_Voucher FOREIGN KEY (VoucherId) REFERENCES dbo.Voucher (VoucherId);
GO
ALTER TABLE dbo.VoucherUse ADD CONSTRAINT FK_VoucherUse_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO

CREATE TABLE dbo.PriceHistory (
    PriceHistoryId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PriceHistory PRIMARY KEY,
    ProductId INT NULL,
    OldPrice DECIMAL(12,2),
    NewPrice DECIMAL(12,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.PriceHistory ADD CONSTRAINT FK_PriceHistory_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO


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
GO
ALTER TABLE dbo.Customer ADD CONSTRAINT FK_Customer_CustomerSegment FOREIGN KEY (CustomerSegmentId) REFERENCES dbo.CustomerSegment (CustomerSegmentId);
GO

CREATE TABLE dbo.CustomerAddress (
    CustomerAddressId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CustomerAddress PRIMARY KEY,
    CustomerId INT NULL,
    Street NVARCHAR(200),
    City NVARCHAR(100),
    Zip VARCHAR(10),
    Country CHAR(2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.CustomerAddress ADD CONSTRAINT FK_CustomerAddress_Customer FOREIGN KEY (CustomerId) REFERENCES dbo.Customer (CustomerId);
GO

CREATE TABLE dbo.CustomerContact (
    CustomerContactId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CustomerContact PRIMARY KEY,
    CustomerId INT NULL,
    Phone VARCHAR(30),
    Kind VARCHAR(20),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.CustomerContact ADD CONSTRAINT FK_CustomerContact_Customer FOREIGN KEY (CustomerId) REFERENCES dbo.Customer (CustomerId);
GO

CREATE TABLE dbo.CustomerSegment (
    CustomerSegmentId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CustomerSegment PRIMARY KEY,
    Name NVARCHAR(100),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.LoyaltyAccount (
    LoyaltyAccountId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_LoyaltyAccount PRIMARY KEY,
    CustomerId INT NULL,
    Points INT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.LoyaltyAccount ADD CONSTRAINT FK_LoyaltyAccount_Customer FOREIGN KEY (CustomerId) REFERENCES dbo.Customer (CustomerId);
GO

CREATE TABLE dbo.LoyaltyTransaction (
    LoyaltyTransactionId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_LoyaltyTransaction PRIMARY KEY,
    LoyaltyAccountId INT NULL,
    OrderId INT NULL,
    Points INT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.LoyaltyTransaction ADD CONSTRAINT FK_LoyaltyTransaction_LoyaltyAccount FOREIGN KEY (LoyaltyAccountId) REFERENCES dbo.LoyaltyAccount (LoyaltyAccountId);
GO
ALTER TABLE dbo.LoyaltyTransaction ADD CONSTRAINT FK_LoyaltyTransaction_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO

CREATE TABLE dbo.Consent (
    ConsentId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Consent PRIMARY KEY,
    CustomerId INT NULL,
    Kind VARCHAR(30),
    GrantedAt DATETIME2,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.Consent ADD CONSTRAINT FK_Consent_Customer FOREIGN KEY (CustomerId) REFERENCES dbo.Customer (CustomerId);
GO


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
GO
ALTER TABLE dbo.Orders ADD CONSTRAINT FK_Orders_Customer FOREIGN KEY (CustomerId) REFERENCES dbo.Customer (CustomerId);
GO

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
GO
ALTER TABLE dbo.OrderItem ADD CONSTRAINT FK_OrderItem_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO
ALTER TABLE dbo.OrderItem ADD CONSTRAINT FK_OrderItem_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO

CREATE TABLE dbo.OrderStatusHistory (
    OrderStatusHistoryId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrderStatusHistory PRIMARY KEY,
    OrderId INT NULL,
    OldStatus TINYINT,
    NewStatus TINYINT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.OrderStatusHistory ADD CONSTRAINT FK_OrderStatusHistory_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO

CREATE TABLE dbo.Cart (
    CartId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Cart PRIMARY KEY,
    CustomerId INT NULL,
    SessionKey VARCHAR(64),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.Cart ADD CONSTRAINT FK_Cart_Customer FOREIGN KEY (CustomerId) REFERENCES dbo.Customer (CustomerId);
GO

CREATE TABLE dbo.CartItem (
    CartItemId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CartItem PRIMARY KEY,
    CartId INT NULL,
    ProductId INT NULL,
    Qty INT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.CartItem ADD CONSTRAINT FK_CartItem_Cart FOREIGN KEY (CartId) REFERENCES dbo.Cart (CartId);
GO
ALTER TABLE dbo.CartItem ADD CONSTRAINT FK_CartItem_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO

CREATE TABLE dbo.OrderNote (
    OrderNoteId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrderNote PRIMARY KEY,
    OrderId INT NULL,
    Body NVARCHAR(2000),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.OrderNote ADD CONSTRAINT FK_OrderNote_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO

CREATE TABLE dbo.OrderEvent (
    OrderEventId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrderEvent PRIMARY KEY,
    OrderId INT NULL,
    EventType VARCHAR(30),
    Payload NVARCHAR(MAX),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.OrderEvent ADD CONSTRAINT FK_OrderEvent_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO


-- ===== Warehouse =====
CREATE TABLE dbo.Warehouse (
    WarehouseId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Warehouse PRIMARY KEY,
    Code VARCHAR(10),
    Name NVARCHAR(100),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.Location (
    LocationId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Location PRIMARY KEY,
    WarehouseId INT NULL,
    Code VARCHAR(20),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.Location ADD CONSTRAINT FK_Location_Warehouse FOREIGN KEY (WarehouseId) REFERENCES dbo.Warehouse (WarehouseId);
GO

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
GO
ALTER TABLE dbo.StockLevel ADD CONSTRAINT FK_StockLevel_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO
ALTER TABLE dbo.StockLevel ADD CONSTRAINT FK_StockLevel_Warehouse FOREIGN KEY (WarehouseId) REFERENCES dbo.Warehouse (WarehouseId);
GO

CREATE TABLE dbo.StockMovement (
    StockMovementId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_StockMovement PRIMARY KEY,
    ProductId INT NULL,
    WarehouseId INT NULL,
    Qty INT,
    MovementType VARCHAR(20),
    RefDocument VARCHAR(30),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.StockMovement ADD CONSTRAINT FK_StockMovement_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO
ALTER TABLE dbo.StockMovement ADD CONSTRAINT FK_StockMovement_Warehouse FOREIGN KEY (WarehouseId) REFERENCES dbo.Warehouse (WarehouseId);
GO

CREATE TABLE dbo.StockReservation (
    StockReservationId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_StockReservation PRIMARY KEY,
    ProductId INT NULL,
    OrderId INT NULL,
    Qty INT,
    ExpiresAt DATETIME2,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.StockReservation ADD CONSTRAINT FK_StockReservation_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO
ALTER TABLE dbo.StockReservation ADD CONSTRAINT FK_StockReservation_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO

CREATE TABLE dbo.InventoryCount (
    InventoryCountId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_InventoryCount PRIMARY KEY,
    WarehouseId INT NULL,
    CountDate DATE,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.InventoryCount ADD CONSTRAINT FK_InventoryCount_Warehouse FOREIGN KEY (WarehouseId) REFERENCES dbo.Warehouse (WarehouseId);
GO

CREATE TABLE dbo.InventoryCountItem (
    InventoryCountItemId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_InventoryCountItem PRIMARY KEY,
    InventoryCountId INT NULL,
    ProductId INT NULL,
    QtyCounted INT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.InventoryCountItem ADD CONSTRAINT FK_InventoryCountItem_InventoryCount FOREIGN KEY (InventoryCountId) REFERENCES dbo.InventoryCount (InventoryCountId);
GO
ALTER TABLE dbo.InventoryCountItem ADD CONSTRAINT FK_InventoryCountItem_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO


-- ===== Purchasing =====
CREATE TABLE dbo.Supplier (
    SupplierId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Supplier PRIMARY KEY,
    Name NVARCHAR(200),
    VatId VARCHAR(20),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.SupplierProduct (
    SupplierProductId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SupplierProduct PRIMARY KEY,
    SupplierId INT NULL,
    ProductId INT NULL,
    SupplierCode VARCHAR(40),
    PurchasePrice DECIMAL(12,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.SupplierProduct ADD CONSTRAINT FK_SupplierProduct_Supplier FOREIGN KEY (SupplierId) REFERENCES dbo.Supplier (SupplierId);
GO
ALTER TABLE dbo.SupplierProduct ADD CONSTRAINT FK_SupplierProduct_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO

CREATE TABLE dbo.PurchaseOrder (
    PurchaseOrderId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PurchaseOrder PRIMARY KEY,
    SupplierId INT NULL,
    PoNumber VARCHAR(20),
    ExpectedAt DATE,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.PurchaseOrder ADD CONSTRAINT FK_PurchaseOrder_Supplier FOREIGN KEY (SupplierId) REFERENCES dbo.Supplier (SupplierId);
GO

CREATE TABLE dbo.PurchaseOrderItem (
    PurchaseOrderItemId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PurchaseOrderItem PRIMARY KEY,
    PurchaseOrderId INT NULL,
    ProductId INT NULL,
    Qty INT,
    Price DECIMAL(12,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.PurchaseOrderItem ADD CONSTRAINT FK_PurchaseOrderItem_PurchaseOrder FOREIGN KEY (PurchaseOrderId) REFERENCES dbo.PurchaseOrder (PurchaseOrderId);
GO
ALTER TABLE dbo.PurchaseOrderItem ADD CONSTRAINT FK_PurchaseOrderItem_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO

CREATE TABLE dbo.GoodsReceipt (
    GoodsReceiptId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_GoodsReceipt PRIMARY KEY,
    PurchaseOrderId INT NULL,
    WarehouseId INT NULL,
    ReceivedAt DATETIME2,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.GoodsReceipt ADD CONSTRAINT FK_GoodsReceipt_PurchaseOrder FOREIGN KEY (PurchaseOrderId) REFERENCES dbo.PurchaseOrder (PurchaseOrderId);
GO
ALTER TABLE dbo.GoodsReceipt ADD CONSTRAINT FK_GoodsReceipt_Warehouse FOREIGN KEY (WarehouseId) REFERENCES dbo.Warehouse (WarehouseId);
GO

CREATE TABLE dbo.GoodsReceiptItem (
    GoodsReceiptItemId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_GoodsReceiptItem PRIMARY KEY,
    GoodsReceiptId INT NULL,
    ProductId INT NULL,
    Qty INT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.GoodsReceiptItem ADD CONSTRAINT FK_GoodsReceiptItem_GoodsReceipt FOREIGN KEY (GoodsReceiptId) REFERENCES dbo.GoodsReceipt (GoodsReceiptId);
GO
ALTER TABLE dbo.GoodsReceiptItem ADD CONSTRAINT FK_GoodsReceiptItem_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO


-- ===== Shipping =====
CREATE TABLE dbo.Shipment (
    ShipmentId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Shipment PRIMARY KEY,
    OrderId INT NULL,
    CarrierId INT NULL,
    TrackingNo VARCHAR(40),
    ShippedAt DATETIME2 NULL,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.Shipment ADD CONSTRAINT FK_Shipment_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO
ALTER TABLE dbo.Shipment ADD CONSTRAINT FK_Shipment_Carrier FOREIGN KEY (CarrierId) REFERENCES dbo.Carrier (CarrierId);
GO

CREATE TABLE dbo.ShipmentItem (
    ShipmentItemId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ShipmentItem PRIMARY KEY,
    ShipmentId INT NULL,
    OrderItemId INT NULL,
    Qty INT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.ShipmentItem ADD CONSTRAINT FK_ShipmentItem_Shipment FOREIGN KEY (ShipmentId) REFERENCES dbo.Shipment (ShipmentId);
GO
ALTER TABLE dbo.ShipmentItem ADD CONSTRAINT FK_ShipmentItem_OrderItem FOREIGN KEY (OrderItemId) REFERENCES dbo.OrderItem (OrderItemId);
GO

CREATE TABLE dbo.Carrier (
    CarrierId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Carrier PRIMARY KEY,
    Code VARCHAR(10),
    Name NVARCHAR(100),
    HandlerProc SYSNAME,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.CarrierService (
    CarrierServiceId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CarrierService PRIMARY KEY,
    CarrierId INT NULL,
    Name NVARCHAR(100),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.CarrierService ADD CONSTRAINT FK_CarrierService_Carrier FOREIGN KEY (CarrierId) REFERENCES dbo.Carrier (CarrierId);
GO

CREATE TABLE dbo.ShipmentTracking (
    ShipmentTrackingId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ShipmentTracking PRIMARY KEY,
    ShipmentId INT NULL,
    EventCode VARCHAR(20),
    EventAt DATETIME2,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.ShipmentTracking ADD CONSTRAINT FK_ShipmentTracking_Shipment FOREIGN KEY (ShipmentId) REFERENCES dbo.Shipment (ShipmentId);
GO

CREATE TABLE dbo.PickupPoint (
    PickupPointId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PickupPoint PRIMARY KEY,
    CarrierId INT NULL,
    Code VARCHAR(20),
    City NVARCHAR(100),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.PickupPoint ADD CONSTRAINT FK_PickupPoint_Carrier FOREIGN KEY (CarrierId) REFERENCES dbo.Carrier (CarrierId);
GO

CREATE TABLE dbo.DeliverySlot (
    DeliverySlotId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DeliverySlot PRIMARY KEY,
    CarrierId INT NULL,
    SlotFrom DATETIME2,
    SlotTo DATETIME2,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.DeliverySlot ADD CONSTRAINT FK_DeliverySlot_Carrier FOREIGN KEY (CarrierId) REFERENCES dbo.Carrier (CarrierId);
GO


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
GO
ALTER TABLE dbo.Payment ADD CONSTRAINT FK_Payment_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO
ALTER TABLE dbo.Payment ADD CONSTRAINT FK_Payment_PaymentMethod FOREIGN KEY (PaymentMethodId) REFERENCES dbo.PaymentMethod (PaymentMethodId);
GO

CREATE TABLE dbo.PaymentMethod (
    PaymentMethodId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PaymentMethod PRIMARY KEY,
    Code VARCHAR(20),
    Name NVARCHAR(100),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.PaymentTransaction (
    PaymentTransactionId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PaymentTransaction PRIMARY KEY,
    PaymentId INT NULL,
    GatewayRef VARCHAR(64),
    Amount DECIMAL(12,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.PaymentTransaction ADD CONSTRAINT FK_PaymentTransaction_Payment FOREIGN KEY (PaymentId) REFERENCES dbo.Payment (PaymentId);
GO

CREATE TABLE dbo.Refund (
    RefundId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Refund PRIMARY KEY,
    PaymentId INT NULL,
    Amount DECIMAL(12,2),
    Reason NVARCHAR(200),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.Refund ADD CONSTRAINT FK_Refund_Payment FOREIGN KEY (PaymentId) REFERENCES dbo.Payment (PaymentId);
GO

CREATE TABLE dbo.GatewayLog (
    GatewayLogId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_GatewayLog PRIMARY KEY,
    PaymentTransactionId INT NULL,
    Request NVARCHAR(MAX),
    Response NVARCHAR(MAX),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.GatewayLog ADD CONSTRAINT FK_GatewayLog_PaymentTransaction FOREIGN KEY (PaymentTransactionId) REFERENCES dbo.PaymentTransaction (PaymentTransactionId);
GO

CREATE TABLE dbo.Installment (
    InstallmentId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Installment PRIMARY KEY,
    PaymentId INT NULL,
    DueDate DATE,
    Amount DECIMAL(12,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.Installment ADD CONSTRAINT FK_Installment_Payment FOREIGN KEY (PaymentId) REFERENCES dbo.Payment (PaymentId);
GO


-- ===== Invoicing =====
CREATE TABLE dbo.Invoice (
    InvoiceId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Invoice PRIMARY KEY,
    OrderId INT NULL,
    CustomerId INT NULL,
    InvoiceNumber VARCHAR(20),
    IssuedAt DATE,
    TotalAmount DECIMAL(12,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.Invoice ADD CONSTRAINT FK_Invoice_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO
ALTER TABLE dbo.Invoice ADD CONSTRAINT FK_Invoice_Customer FOREIGN KEY (CustomerId) REFERENCES dbo.Customer (CustomerId);
GO

CREATE TABLE dbo.InvoiceItem (
    InvoiceItemId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_InvoiceItem PRIMARY KEY,
    InvoiceId INT NULL,
    ProductId INT NULL,
    Qty INT,
    UnitPrice DECIMAL(12,2),
    VatRate DECIMAL(5,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.InvoiceItem ADD CONSTRAINT FK_InvoiceItem_Invoice FOREIGN KEY (InvoiceId) REFERENCES dbo.Invoice (InvoiceId);
GO
ALTER TABLE dbo.InvoiceItem ADD CONSTRAINT FK_InvoiceItem_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO

CREATE TABLE dbo.CreditNote (
    CreditNoteId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CreditNote PRIMARY KEY,
    InvoiceId INT NULL,
    Amount DECIMAL(12,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.CreditNote ADD CONSTRAINT FK_CreditNote_Invoice FOREIGN KEY (InvoiceId) REFERENCES dbo.Invoice (InvoiceId);
GO

CREATE TABLE dbo.LedgerEntry (
    LedgerEntryId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_LedgerEntry PRIMARY KEY,
    InvoiceId INT NULL,
    Account VARCHAR(10),
    Debit DECIMAL(14,2),
    Credit DECIMAL(14,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.LedgerEntry ADD CONSTRAINT FK_LedgerEntry_Invoice FOREIGN KEY (InvoiceId) REFERENCES dbo.Invoice (InvoiceId);
GO

CREATE TABLE dbo.VatRate (
    VatRateId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VatRate PRIMARY KEY,
    Rate DECIMAL(5,2),
    ValidFrom DATE,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.AccountingExport (
    AccountingExportId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AccountingExport PRIMARY KEY,
    Period CHAR(7),
    ExportedAt DATETIME2,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.ExchangeRate (
    ExchangeRateId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ExchangeRate PRIMARY KEY,
    Currency CHAR(3),
    Rate DECIMAL(12,6),
    RateDate DATE,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO


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
GO
ALTER TABLE dbo.Claim ADD CONSTRAINT FK_Claim_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO
ALTER TABLE dbo.Claim ADD CONSTRAINT FK_Claim_Customer FOREIGN KEY (CustomerId) REFERENCES dbo.Customer (CustomerId);
GO
ALTER TABLE dbo.Claim ADD CONSTRAINT FK_Claim_ServiceCenter FOREIGN KEY (ServiceCenterId) REFERENCES dbo.ServiceCenter (ServiceCenterId);
GO

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
GO
ALTER TABLE dbo.ClaimItem ADD CONSTRAINT FK_ClaimItem_Claim FOREIGN KEY (ClaimId) REFERENCES dbo.Claim (ClaimId);
GO
ALTER TABLE dbo.ClaimItem ADD CONSTRAINT FK_ClaimItem_OrderItem FOREIGN KEY (OrderItemId) REFERENCES dbo.OrderItem (OrderItemId);
GO

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
GO
ALTER TABLE dbo.ClaimStatusHistory ADD CONSTRAINT FK_ClaimStatusHistory_Claim FOREIGN KEY (ClaimId) REFERENCES dbo.Claim (ClaimId);
GO

CREATE TABLE dbo.ServiceCenter (
    ServiceCenterId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ServiceCenter PRIMARY KEY,
    Name NVARCHAR(100),
    City NVARCHAR(100),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

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
GO
ALTER TABLE dbo.ClaimDocument ADD CONSTRAINT FK_ClaimDocument_Claim FOREIGN KEY (ClaimId) REFERENCES dbo.Claim (ClaimId);
GO

CREATE TABLE dbo.ClaimReason (
    ClaimReasonId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ClaimReason PRIMARY KEY,
    Code VARCHAR(20),
    Name NVARCHAR(100),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

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
GO
ALTER TABLE dbo.ReturnRequest ADD CONSTRAINT FK_ReturnRequest_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO
ALTER TABLE dbo.ReturnRequest ADD CONSTRAINT FK_ReturnRequest_Customer FOREIGN KEY (CustomerId) REFERENCES dbo.Customer (CustomerId);
GO


-- ===== Reporting =====
CREATE TABLE dbo.RptDailySales (
    RptDailySalesId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RptDailySales PRIMARY KEY,
    SalesDate DATE,
    Amount DECIMAL(14,2),
    OrderCount INT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.RptStockSnapshot (
    RptStockSnapshotId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RptStockSnapshot PRIMARY KEY,
    ProductId INT NULL,
    WarehouseId INT NULL,
    SnapshotDate DATE,
    Qty INT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.RptStockSnapshot ADD CONSTRAINT FK_RptStockSnapshot_Product FOREIGN KEY (ProductId) REFERENCES dbo.Product (ProductId);
GO
ALTER TABLE dbo.RptStockSnapshot ADD CONSTRAINT FK_RptStockSnapshot_Warehouse FOREIGN KEY (WarehouseId) REFERENCES dbo.Warehouse (WarehouseId);
GO

CREATE TABLE dbo.RptCustomerKpi (
    RptCustomerKpiId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RptCustomerKpi PRIMARY KEY,
    CustomerId INT NULL,
    Period CHAR(7),
    Revenue DECIMAL(14,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.RptCustomerKpi ADD CONSTRAINT FK_RptCustomerKpi_Customer FOREIGN KEY (CustomerId) REFERENCES dbo.Customer (CustomerId);
GO

CREATE TABLE dbo.ExportQueue (
    ExportQueueId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ExportQueue PRIMARY KEY,
    HandlerProc SYSNAME,
    Payload NVARCHAR(MAX),
    ProcessedAt DATETIME2 NULL,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.Sales_2023 (
    Sales_2023Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Sales_2023 PRIMARY KEY,
    OrderId INT NULL,
    Amount DECIMAL(12,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.Sales_2023 ADD CONSTRAINT FK_Sales_2023_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO

CREATE TABLE dbo.Sales_2024 (
    Sales_2024Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Sales_2024 PRIMARY KEY,
    OrderId INT NULL,
    Amount DECIMAL(12,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.Sales_2024 ADD CONSTRAINT FK_Sales_2024_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO

CREATE TABLE dbo.Sales_2025 (
    Sales_2025Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Sales_2025 PRIMARY KEY,
    OrderId INT NULL,
    Amount DECIMAL(12,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.Sales_2025 ADD CONSTRAINT FK_Sales_2025_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO

CREATE TABLE dbo.Sales_2026 (
    Sales_2026Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Sales_2026 PRIMARY KEY,
    OrderId INT NULL,
    Amount DECIMAL(12,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.Sales_2026 ADD CONSTRAINT FK_Sales_2026_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders (OrderId);
GO


-- ===== Shared =====
CREATE TABLE dbo.AuditLog (
    AuditLogId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AuditLog PRIMARY KEY,
    EntityName VARCHAR(50),
    EntityId BIGINT,
    Action VARCHAR(20),
    Detail NVARCHAR(MAX),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.SysParam (
    SysParamId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SysParam PRIMARY KEY,
    Name VARCHAR(100),
    Value NVARCHAR(400),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.Users (
    UserId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
    Login VARCHAR(50),
    Name NVARCHAR(200),
    IsActive BIT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.UserPermission (
    UserPermissionId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserPermission PRIMARY KEY,
    UserId INT NULL,
    Permission VARCHAR(50),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.UserPermission ADD CONSTRAINT FK_UserPermission_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId);
GO

CREATE TABLE dbo.ErrorLog (
    ErrorLogId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ErrorLog PRIMARY KEY,
    ProcName SYSNAME,
    Message NVARCHAR(4000),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.JobRun (
    JobRunId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_JobRun PRIMARY KEY,
    JobName SYSNAME,
    StartedAt DATETIME2,
    FinishedAt DATETIME2 NULL,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.Counter (
    CounterId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Counter PRIMARY KEY,
    Name VARCHAR(50),
    LastValue BIGINT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.Translation (
    TranslationId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Translation PRIMARY KEY,
    KeyName VARCHAR(100),
    Lang CHAR(2),
    Text NVARCHAR(1000),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO


-- ===== Legacy =====
CREATE TABLE dbo.OldOrders (
    OldOrdersId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OldOrders PRIMARY KEY,
    CustomerId INT NULL,
    TotalAmount DECIMAL(12,2),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO
ALTER TABLE dbo.OldOrders ADD CONSTRAINT FK_OldOrders_Customer FOREIGN KEY (CustomerId) REFERENCES dbo.Customer (CustomerId);
GO

CREATE TABLE dbo.Product_bak2019 (
    Product_bak2019Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Product_bak2019 PRIMARY KEY,
    Code VARCHAR(20),
    Name NVARCHAR(200),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.ImportProduct (
    ImportProductId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ImportProduct PRIMARY KEY,
    RawLine NVARCHAR(MAX),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.ImportStock (
    ImportStockId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ImportStock PRIMARY KEY,
    RawLine NVARCHAR(MAX),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.ImportPrice (
    ImportPriceId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ImportPrice PRIMARY KEY,
    RawLine NVARCHAR(MAX),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.X_Migr_Customer (
    X_Migr_CustomerId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_X_Migr_Customer PRIMARY KEY,
    OldId INT,
    NewId INT,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

CREATE TABLE dbo.TmpRecalc (
    TmpRecalcId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TmpRecalc PRIMARY KEY,
    Payload NVARCHAR(MAX),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
GO

