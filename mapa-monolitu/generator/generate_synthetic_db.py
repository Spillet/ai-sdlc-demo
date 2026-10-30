#!/usr/bin/env python3
"""Generátor syntetické databáze fiktivního e-shopu „Kompas“.

Vyrobí T-SQL skripty (tabulky, pohledy, procedury, funkce, triggery) a k nim
vstupy, které by v reálu přišly z jiných zdrojů:

  db/*.sql                       skripty objektů (jako export „Generate Scripts“)
  catalog/table_sizes.csv        velikosti tabulek (obdoba sys.dm_db_partition_stats)
  client/delphi_calls.csv        grep volání procedur ve zdrojácích Delphi klienta
  scheduler/sql_agent_jobs.csv   kroky SQL Agent jobů (obdoba msdb.dbo.sysjobsteps)
  runtime/*.csv                  simulovaný export Extended Events a Query Store
  _ground_truth.json             co generátor zamýšlel; analyzátor ho NEČTE,
                                 slouží jen k vyhodnocení, jak se trefil

Vše je fiktivní. Generátor je deterministický (pevné semínko), takže stejný
běh dá stejná data.

Spuštění: python3 generator/generate_synthetic_db.py [cílový adresář]
"""
import csv
import json
import math
import os
import random
import sys
from collections import defaultdict

SEED = 20261031
R = random.Random(SEED)

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "synthetic")

# --------------------------------------------------------------------------
# Tabulky: (název, FK rodiče, specifické sloupce)
# --------------------------------------------------------------------------
TABLES = {
    "Catalog": [
        ("Product", ["Brand", "Category"], ["Code VARCHAR(20)", "Name NVARCHAR(200)", "Ean VARCHAR(14)", "IsActive BIT", "Weight DECIMAL(9,3)", "CurrentPrice DECIMAL(12,2)", "StockQtyCache INT"]),
        ("Category", [], ["Name NVARCHAR(100)", "ParentCategoryId INT NULL", "SortOrder INT"]),
        ("ProductCategory", ["Product", "Category"], ["IsPrimary BIT"]),
        ("Brand", [], ["Name NVARCHAR(100)", "Country CHAR(2)"]),
        ("AttributeDef", [], ["Name NVARCHAR(100)", "DataType VARCHAR(20)"]),
        ("ProductAttribute", ["Product", "AttributeDef"], ["Value NVARCHAR(400)"]),
        ("ProductImage", ["Product"], ["Url NVARCHAR(400)", "SortOrder INT"]),
        ("ProductText", ["Product"], ["Lang CHAR(2)", "Body NVARCHAR(MAX)"]),
    ],
    "Pricing": [
        ("PriceList", [], ["Name NVARCHAR(100)", "Currency CHAR(3)", "ValidFrom DATE", "ValidTo DATE"]),
        ("PriceListItem", ["PriceList", "Product"], ["Price DECIMAL(12,2)"]),
        ("Promo", [], ["Name NVARCHAR(100)", "DiscountPct DECIMAL(5,2)", "ValidFrom DATE", "ValidTo DATE"]),
        ("PromoProduct", ["Promo", "Product"], []),
        ("Voucher", ["Promo"], ["Code VARCHAR(30)", "MaxUses INT"]),
        ("VoucherUse", ["Voucher", "Orders"], ["UsedAt DATETIME2"]),
        ("PriceHistory", ["Product"], ["OldPrice DECIMAL(12,2)", "NewPrice DECIMAL(12,2)"]),
    ],
    "Customers": [
        ("Customer", ["CustomerSegment"], ["Email NVARCHAR(200)", "Name NVARCHAR(200)", "IsBusiness BIT", "VatId VARCHAR(20) NULL"]),
        ("CustomerAddress", ["Customer"], ["Street NVARCHAR(200)", "City NVARCHAR(100)", "Zip VARCHAR(10)", "Country CHAR(2)"]),
        ("CustomerContact", ["Customer"], ["Phone VARCHAR(30)", "Kind VARCHAR(20)"]),
        ("CustomerSegment", [], ["Name NVARCHAR(100)"]),
        ("LoyaltyAccount", ["Customer"], ["Points INT"]),
        ("LoyaltyTransaction", ["LoyaltyAccount", "Orders"], ["Points INT"]),
        ("Consent", ["Customer"], ["Kind VARCHAR(30)", "GrantedAt DATETIME2"]),
    ],
    "Orders": [
        ("Orders", ["Customer"], ["OrderNumber VARCHAR(20)", "TotalAmount DECIMAL(12,2)", "Currency CHAR(3)", "IsPaid BIT", "ShippingStatus TINYINT"]),
        ("OrderItem", ["Orders", "Product"], ["Qty INT", "UnitPrice DECIMAL(12,2)", "VatRate DECIMAL(5,2)"]),
        ("OrderStatusHistory", ["Orders"], ["OldStatus TINYINT", "NewStatus TINYINT"]),
        ("Cart", ["Customer"], ["SessionKey VARCHAR(64)"]),
        ("CartItem", ["Cart", "Product"], ["Qty INT"]),
        ("OrderNote", ["Orders"], ["Body NVARCHAR(2000)"]),
        ("OrderEvent", ["Orders"], ["EventType VARCHAR(30)", "Payload NVARCHAR(MAX)"]),
    ],
    "Warehouse": [
        ("Warehouse", [], ["Code VARCHAR(10)", "Name NVARCHAR(100)"]),
        ("Location", ["Warehouse"], ["Code VARCHAR(20)"]),
        ("StockLevel", ["Product", "Warehouse"], ["QtyOnHand INT", "QtyReserved INT"]),
        ("StockMovement", ["Product", "Warehouse"], ["Qty INT", "MovementType VARCHAR(20)", "RefDocument VARCHAR(30)"]),
        ("StockReservation", ["Product", "Orders"], ["Qty INT", "ExpiresAt DATETIME2"]),
        ("InventoryCount", ["Warehouse"], ["CountDate DATE"]),
        ("InventoryCountItem", ["InventoryCount", "Product"], ["QtyCounted INT"]),
    ],
    "Purchasing": [
        ("Supplier", [], ["Name NVARCHAR(200)", "VatId VARCHAR(20)"]),
        ("SupplierProduct", ["Supplier", "Product"], ["SupplierCode VARCHAR(40)", "PurchasePrice DECIMAL(12,2)"]),
        ("PurchaseOrder", ["Supplier"], ["PoNumber VARCHAR(20)", "ExpectedAt DATE"]),
        ("PurchaseOrderItem", ["PurchaseOrder", "Product"], ["Qty INT", "Price DECIMAL(12,2)"]),
        ("GoodsReceipt", ["PurchaseOrder", "Warehouse"], ["ReceivedAt DATETIME2"]),
        ("GoodsReceiptItem", ["GoodsReceipt", "Product"], ["Qty INT"]),
    ],
    "Shipping": [
        ("Shipment", ["Orders", "Carrier"], ["TrackingNo VARCHAR(40)", "ShippedAt DATETIME2 NULL"]),
        ("ShipmentItem", ["Shipment", "OrderItem"], ["Qty INT"]),
        ("Carrier", [], ["Code VARCHAR(10)", "Name NVARCHAR(100)", "HandlerProc SYSNAME"]),
        ("CarrierService", ["Carrier"], ["Name NVARCHAR(100)"]),
        ("ShipmentTracking", ["Shipment"], ["EventCode VARCHAR(20)", "EventAt DATETIME2"]),
        ("PickupPoint", ["Carrier"], ["Code VARCHAR(20)", "City NVARCHAR(100)"]),
        ("DeliverySlot", ["Carrier"], ["SlotFrom DATETIME2", "SlotTo DATETIME2"]),
    ],
    "Payments": [
        ("Payment", ["Orders", "PaymentMethod"], ["Amount DECIMAL(12,2)", "Currency CHAR(3)"]),
        ("PaymentMethod", [], ["Code VARCHAR(20)", "Name NVARCHAR(100)"]),
        ("PaymentTransaction", ["Payment"], ["GatewayRef VARCHAR(64)", "Amount DECIMAL(12,2)"]),
        ("Refund", ["Payment"], ["Amount DECIMAL(12,2)", "Reason NVARCHAR(200)"]),
        ("GatewayLog", ["PaymentTransaction"], ["Request NVARCHAR(MAX)", "Response NVARCHAR(MAX)"]),
        ("Installment", ["Payment"], ["DueDate DATE", "Amount DECIMAL(12,2)"]),
    ],
    "Invoicing": [
        ("Invoice", ["Orders", "Customer"], ["InvoiceNumber VARCHAR(20)", "IssuedAt DATE", "TotalAmount DECIMAL(12,2)"]),
        ("InvoiceItem", ["Invoice", "Product"], ["Qty INT", "UnitPrice DECIMAL(12,2)", "VatRate DECIMAL(5,2)"]),
        ("CreditNote", ["Invoice"], ["Amount DECIMAL(12,2)"]),
        ("LedgerEntry", ["Invoice"], ["Account VARCHAR(10)", "Debit DECIMAL(14,2)", "Credit DECIMAL(14,2)"]),
        ("VatRate", [], ["Rate DECIMAL(5,2)", "ValidFrom DATE"]),
        ("AccountingExport", [], ["Period CHAR(7)", "ExportedAt DATETIME2"]),
        ("ExchangeRate", [], ["Currency CHAR(3)", "Rate DECIMAL(12,6)", "RateDate DATE"]),
    ],
    "Claims": [
        ("Claim", ["Orders", "Customer", "ServiceCenter"], ["ClaimNumber VARCHAR(20)", "ClaimType VARCHAR(20)", "Resolution VARCHAR(30) NULL", "DeadlineAt DATE"]),
        ("ClaimItem", ["Claim", "OrderItem"], ["Qty INT", "DefectDescription NVARCHAR(2000)"]),
        ("ClaimStatusHistory", ["Claim"], ["OldStatus TINYINT", "NewStatus TINYINT", "Note NVARCHAR(400)"]),
        ("ServiceCenter", [], ["Name NVARCHAR(100)", "City NVARCHAR(100)"]),
        ("ClaimDocument", ["Claim"], ["FileName NVARCHAR(200)", "StorageKey VARCHAR(100)"]),
        ("ClaimReason", [], ["Code VARCHAR(20)", "Name NVARCHAR(100)"]),
        ("ReturnRequest", ["Orders", "Customer"], ["Reason NVARCHAR(400)"]),
    ],
    "Reporting": [
        ("RptDailySales", [], ["SalesDate DATE", "Amount DECIMAL(14,2)", "OrderCount INT"]),
        ("RptStockSnapshot", ["Product", "Warehouse"], ["SnapshotDate DATE", "Qty INT"]),
        ("RptCustomerKpi", ["Customer"], ["Period CHAR(7)", "Revenue DECIMAL(14,2)"]),
        ("ExportQueue", [], ["HandlerProc SYSNAME", "Payload NVARCHAR(MAX)", "ProcessedAt DATETIME2 NULL"]),
        ("Sales_2023", ["Orders"], ["Amount DECIMAL(12,2)"]),
        ("Sales_2024", ["Orders"], ["Amount DECIMAL(12,2)"]),
        ("Sales_2025", ["Orders"], ["Amount DECIMAL(12,2)"]),
        ("Sales_2026", ["Orders"], ["Amount DECIMAL(12,2)"]),
    ],
    "Shared": [
        ("AuditLog", [], ["EntityName VARCHAR(50)", "EntityId BIGINT", "Action VARCHAR(20)", "Detail NVARCHAR(MAX)"]),
        ("SysParam", [], ["Name VARCHAR(100)", "Value NVARCHAR(400)"]),
        ("Users", [], ["Login VARCHAR(50)", "Name NVARCHAR(200)", "IsActive BIT"]),
        ("UserPermission", ["Users"], ["Permission VARCHAR(50)"]),
        ("ErrorLog", [], ["ProcName SYSNAME", "Message NVARCHAR(4000)"]),
        ("JobRun", [], ["JobName SYSNAME", "StartedAt DATETIME2", "FinishedAt DATETIME2 NULL"]),
        ("Counter", [], ["Name VARCHAR(50)", "LastValue BIGINT"]),
        ("Translation", [], ["KeyName VARCHAR(100)", "Lang CHAR(2)", "Text NVARCHAR(1000)"]),
    ],
    "Legacy": [
        ("OldOrders", ["Customer"], ["TotalAmount DECIMAL(12,2)"]),
        ("Product_bak2019", [], ["Code VARCHAR(20)", "Name NVARCHAR(200)"]),
        ("ImportProduct", [], ["RawLine NVARCHAR(MAX)"]),
        ("ImportStock", [], ["RawLine NVARCHAR(MAX)"]),
        ("ImportPrice", [], ["RawLine NVARCHAR(MAX)"]),
        ("X_Migr_Customer", [], ["OldId INT", "NewId INT"]),
        ("TmpRecalc", [], ["Payload NVARCHAR(MAX)"]),
    ],
}

KEY_OVERRIDE = {"Orders": "OrderId", "Users": "UserId"}


def key(t):
    return KEY_OVERRIDE.get(t, t + "Id")


TABLE_DOMAIN = {t[0]: d for d, ts in TABLES.items() for t in ts}
TABLE_FKS = {t[0]: t[1] for ts in TABLES.values() for t in ts}

# Fiktivní velikosti (GB). Dvě obří tabulky + pár velkých, zbytek malý.
BIG = {"StockMovement": 8300, "AuditLog": 8100, "OrderItem": 1900, "ShipmentTracking": 1500,
       "Orders": 1100, "OrderStatusHistory": 900, "GatewayLog": 800, "OrderEvent": 700,
       "PriceHistory": 600, "PaymentTransaction": 500, "LedgerEntry": 450, "InvoiceItem": 380,
       "Sales_2025": 120, "Sales_2026": 90, "Sales_2024": 150, "Sales_2023": 140,
       "ClaimDocument": 60, "ClaimStatusHistory": 18}

# --------------------------------------------------------------------------
# Pohledy
# --------------------------------------------------------------------------
VIEWS = [
    ("vw_ProductDetail", "Catalog", ["Product", "Brand", "Category", "ProductCategory"]),
    ("vw_ProductActive", "Catalog", ["Product"]),
    ("vw_ProductWithPrice", "Pricing", ["Product", "PriceListItem", "PriceList"]),
    ("vw_ActivePromo", "Pricing", ["Promo", "PromoProduct"]),
    ("vw_CustomerOverview", "Customers", ["Customer", "CustomerAddress", "CustomerSegment"]),
    ("vw_LoyaltyBalance", "Customers", ["LoyaltyAccount", "LoyaltyTransaction"]),
    ("vw_OrderOverview", "Orders", ["Orders", "Customer", "OrderItem"]),
    ("vw_OrderOpen", "Orders", ["Orders", "OrderStatusHistory"]),
    ("vw_OrderWithPayment", "Orders", ["Orders", "Payment"]),
    ("vw_CartDetail", "Orders", ["Cart", "CartItem", "Product"]),
    ("vw_StockAvailable", "Warehouse", ["StockLevel", "StockReservation", "Product"]),
    ("vw_StockByWarehouse", "Warehouse", ["StockLevel", "Warehouse"]),
    ("vw_StockMovementLast30", "Warehouse", ["StockMovement"]),
    ("vw_InventoryDiff", "Warehouse", ["InventoryCount", "InventoryCountItem", "StockLevel"]),
    ("vw_PurchaseOpen", "Purchasing", ["PurchaseOrder", "PurchaseOrderItem", "Supplier"]),
    ("vw_SupplierPrice", "Purchasing", ["SupplierProduct", "Supplier", "Product"]),
    ("vw_ShipmentOverview", "Shipping", ["Shipment", "Carrier", "Orders"]),
    ("vw_ShipmentLastEvent", "Shipping", ["Shipment", "ShipmentTracking"]),
    ("vw_PaymentOverview", "Payments", ["Payment", "PaymentMethod", "PaymentTransaction"]),
    ("vw_RefundOpen", "Payments", ["Refund", "Payment"]),
    ("vw_InvoiceOverview", "Invoicing", ["Invoice", "InvoiceItem", "Customer"]),
    ("vw_LedgerMonth", "Invoicing", ["LedgerEntry", "Invoice"]),
    ("vw_ClaimOverview", "Claims", ["Claim", "ClaimItem", "ServiceCenter", "Customer"]),
    ("vw_ClaimOpen", "Claims", ["Claim", "ClaimStatusHistory"]),
    ("vw_RptSalesByDay", "Reporting", ["RptDailySales"]),
    ("vw_RptSalesAll", "Reporting", ["Sales_2023", "Sales_2024", "Sales_2025", "Sales_2026"]),
    ("vw_RptStock", "Reporting", ["RptStockSnapshot", "Product", "Warehouse"]),
    ("vw_RptMargin", "Reporting", ["OrderItem", "SupplierProduct", "Product"]),
    ("vw_UserPermissions", "Shared", ["Users", "UserPermission"]),
    ("vw_AuditLast7", "Shared", ["AuditLog"]),
    ("vw_ErrorsToday", "Shared", ["ErrorLog"]),
    ("vw_OldOrdersMigr", "Legacy", ["OldOrders", "X_Migr_Customer"]),
    ("vw_ProductBak", "Legacy", ["Product_bak2019"]),
]
VIEW_NAMES = {v[0] for v in VIEWS}

# --------------------------------------------------------------------------
# Konfigurace domén: kolik procedur, jak „špinavé“ jsou
# --------------------------------------------------------------------------
DOMAINS = {
    #             prefix         n  p_fw  foreign_write_pool                         foreign_read_pool                                p_dyn  call_out_domains
    "Catalog":   ("usp_Product", 24, 0.10, ["PriceHistory", "StockLevel"],             ["StockLevel", "PriceListItem", "SupplierProduct"], 0.08, ["Pricing"]),
    "Pricing":   ("usp_Price",   20, 0.30, ["Product"],                                ["Product", "Customer", "OrderItem"],               0.10, ["Catalog"]),
    "Customers": ("usp_Cust",    20, 0.12, ["Orders"],                                 ["Orders", "Invoice"],                              0.05, []),
    "Orders":    ("usp_Order",   32, 0.45, ["StockLevel", "StockReservation", "Payment", "Customer", "LoyaltyTransaction", "VoucherUse", "Invoice"],
                                                                                        ["Product", "Customer", "PriceListItem", "StockLevel", "Promo", "Voucher"], 0.12, ["Pricing", "Warehouse", "Payments", "Shipping", "Customers"]),
    "Warehouse": ("spSklad",     28, 0.35, ["Orders", "Product", "PurchaseOrder"],    ["Orders", "OrderItem", "Product", "PurchaseOrderItem"], 0.15, ["Orders", "Purchasing"]),
    "Purchasing":("usp_Po",      16, 0.30, ["StockLevel", "Product"],                 ["Product", "StockLevel"],                          0.06, ["Warehouse"]),
    "Shipping":  ("usp_Ship",    20, 0.25, ["Orders"],                                 ["Orders", "OrderItem", "Customer", "CustomerAddress"], 0.10, ["Orders"]),
    "Payments":  ("usp_Pay",     18, 0.30, ["Orders", "Invoice"],                      ["Orders", "Customer"],                             0.06, ["Invoicing"]),
    "Invoicing": ("usp_Inv",     20, 0.25, ["Orders", "Payment"],                      ["Orders", "OrderItem", "Payment", "Customer", "Product"], 0.12, ["Payments"]),
    "Claims":    ("usp_Claim",   13, 0.04, ["StockLevel"],                             ["Orders", "OrderItem", "Product", "Customer"],     0.04, ["Payments"]),
    "Reporting": ("usp_Rpt",     20, 0.03, [],                                          ["Orders", "OrderItem", "Product", "Customer", "StockLevel", "Payment", "Invoice", "Shipment"], 0.30, []),
}

VERBS_READ = ["Get", "GetDetail", "List", "Search", "GetByCode", "Find", "Overview", "Check"]
VERBS_WRITE = ["Save", "Insert", "Update", "SetStatus", "Delete", "Recalc", "Merge", "Import", "Close", "Approve"]
VERBS_PROC = ["Process", "Confirm", "Cancel", "Sync", "Rebuild", "Dispatch"]
VERBS_BATCH = ["Nightly", "Hourly", "Cleanup", "Archive", "Export", "MonthClose"]

# --------------------------------------------------------------------------
# Datové struktury
# --------------------------------------------------------------------------
modules = {}          # name -> dict(spec)
order = []            # pořadí vzniku


def new_module(name, domain, kind, typ="P"):
    assert name not in modules, name
    m = dict(name=name, domain=domain, kind=kind, type=typ, reads=set(), writes=set(), calls=[],
             calls_noschema=set(), funcs=set(), dyn=None, dyn_tables_literal=set(), dyn_tables_runtime=set(),
             dyn_procs_runtime=set(), crossdb=[], entry=set(), dead=False, text=None, temp=False,
             stale_comment=None, string_trap=None, freq=None, yearly=False, client_unused=False)
    modules[name] = m
    order.append(name)
    return m


def own_tables(d):
    return [t[0] for t in TABLES[d]]


# --------------------------------------------------------------------------
# Sdílená infrastruktura (budoucí „božské“ procedury)
# --------------------------------------------------------------------------
INFRA = [
    ("usp_Audit_Write", ["AuditLog"], [], "write"),
    ("usp_Error_Log", ["ErrorLog"], [], "write"),
    ("usp_SysParam_Get", [], ["SysParam"], "read"),
    ("usp_Counter_Next", ["Counter"], ["Counter"], "write"),
    ("usp_JobRun_Start", ["JobRun"], [], "write"),
    ("usp_JobRun_End", ["JobRun"], ["JobRun"], "write"),
    ("usp_User_CheckPermission", [], ["Users", "UserPermission"], "read"),
    ("usp_Translation_Get", [], ["Translation"], "read"),
    ("usp_User_Get", [], ["Users"], "read"),
    ("usp_User_Save", ["Users", "UserPermission"], ["Users"], "write"),
    ("usp_SysParam_Set", ["SysParam"], [], "write"),
    ("usp_AuditLog_Purge", ["AuditLog"], ["SysParam"], "batch"),
]
for name, w, r, kind in INFRA:
    m = new_module(name, "Shared", kind)
    m["writes"].update(w)
    m["reads"].update(r)
modules["usp_AuditLog_Purge"]["crossdb"].append(("Archive", "AuditLog_Archive"))
modules["usp_AuditLog_Purge"]["freq"] = "denně 02:00"

FUNCS = [
    ("fn_GetSysParam", "Shared", ["SysParam"]),
    ("fn_UserName", "Shared", ["Users"]),
    ("fn_Translate", "Shared", ["Translation"]),
    ("fn_ProductPrice", "Pricing", ["PriceListItem", "PriceList", "Promo", "PromoProduct"]),
    ("fn_ProductAvailableQty", "Warehouse", ["StockLevel", "StockReservation"]),
    ("fn_CustomerIsVip", "Customers", ["Customer", "CustomerSegment"]),
    ("fn_OrderTotal", "Orders", ["OrderItem"]),
    ("fn_VatRateFor", "Invoicing", ["VatRate"]),
    ("fn_ExchangeRate", "Invoicing", ["ExchangeRate"]),
    ("fn_Claim_Deadline", "Claims", []),
    ("fn_ShippingPrice", "Shipping", ["CarrierService", "Carrier"]),
    ("fn_LoyaltyPoints", "Customers", ["LoyaltyAccount"]),
    ("fn_StockValue", "Warehouse", ["StockLevel", "SupplierProduct"]),
    ("fn_PaymentIsSettled", "Payments", ["Payment", "PaymentTransaction"]),
    ("fn_SplitString", "Shared", []),
    ("fn_WorkingDaysBetween", "Shared", ["SysParam"]),
    ("fn_OldPriceCalc", "Legacy", ["Product_bak2019"]),
    ("tvf_OrderItems", "Orders", ["OrderItem", "Product"]),
    ("tvf_StockByProduct", "Warehouse", ["StockLevel", "Warehouse"]),
    ("tvf_ClaimItems", "Claims", ["ClaimItem", "OrderItem", "Product"]),
    ("tvf_InvoiceLines", "Invoicing", ["InvoiceItem", "Product"]),
    ("fn_CarrierForZip", "Shipping", ["PickupPoint", "Carrier"]),
    ("fn_PromoActive", "Pricing", ["Promo"]),
    ("fn_IsWorkingDay", "Shared", []),
]
for name, d, reads in FUNCS:
    m = new_module(name, d, "func", "IF" if name.startswith("tvf_") else "FN")
    m["reads"].update(reads)
FUNCS_BY_DOMAIN = defaultdict(list)
for name, d, _ in FUNCS:
    FUNCS_BY_DOMAIN[d].append(name)

# --------------------------------------------------------------------------
# Ručně napsané procedury domény Reklamace (ukázka pro AI vrstvu)
# --------------------------------------------------------------------------
SHOWCASE = {}

SHOWCASE["usp_Claim_Create"] = dict(kind="write", reads={"Orders", "OrderItem", "Customer", "Claim", "ClaimReason"},
    writes={"Claim", "ClaimItem", "ClaimStatusHistory"}, calls=["usp_Counter_Next", "usp_Audit_Write", "usp_Error_Log"],
    funcs={"fn_Claim_Deadline"}, entry={"client", "web"}, text=r"""CREATE PROCEDURE dbo.usp_Claim_Create
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
END""")

SHOWCASE["usp_Claim_GetDetail"] = dict(kind="read", reads={"Claim", "ClaimItem", "ClaimStatusHistory", "ServiceCenter", "Customer", "Orders", "ClaimDocument", "OrderItem", "Product"},
    writes=set(), calls=["usp_User_CheckPermission"], funcs={"fn_UserName", "tvf_ClaimItems"}, entry={"client", "web"}, text=r"""CREATE PROCEDURE dbo.usp_Claim_GetDetail
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
END""")

SHOWCASE["usp_Claim_SetStatus"] = dict(kind="write", reads={"Claim", "ClaimItem", "OrderItem", "Payment"},
    writes={"Claim", "ClaimStatusHistory", "StockLevel"}, calls=["usp_Refund_Create", "usp_Audit_Write"],
    funcs=set(), entry={"client"}, text=r"""CREATE PROCEDURE dbo.usp_Claim_SetStatus
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
END""")

SHOWCASE["usp_Claim_Search"] = dict(kind="read", reads=set(), writes=set(), calls=[], funcs=set(), entry={"client"},
    dyn={"type": "literal"}, dyn_tables_literal={"Claim", "Customer", "Orders"}, text=r"""CREATE PROCEDURE dbo.usp_Claim_Search
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
END""")

SHOWCASE["usp_Claim_OverdueCheck"] = dict(kind="batch", reads={"Claim", "SysParam"}, writes={"Claim", "ClaimStatusHistory"},
    calls=["usp_JobRun_Start", "usp_JobRun_End", "usp_Claim_Notify"], funcs={"fn_WorkingDaysBetween"}, entry={"agent"}, freq="denně 06:00",
    text=r"""CREATE PROCEDURE dbo.usp_Claim_OverdueCheck
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @run BIGINT, @warnDays INT, @ClaimId INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'ClaimOverdue', @RunId = @run OUTPUT;

    SELECT @warnDays = CAST(Value AS INT) FROM dbo.SysParam WHERE Name = 'CLAIM_WARN_DAYS';

    -- oznacit reklamace, kterym konci zakonna lhuta 30 dni
    UPDATE dbo.Claim SET Status = 7, ModifiedAt = GETDATE()     -- 7 = hrozi prekroceni lhuty
    WHERE Status IN (1, 2) AND dbo.fn_WorkingDaysBetween(GETDATE(), DeadlineAt) <= @warnDays;

    INSERT INTO dbo.ClaimStatusHistory (ClaimId, OldStatus, NewStatus, Note, Status, CreatedAt)
    SELECT ClaimId, 2, 7, N'Automaticky: blizi se lhuta', 1, GETDATE()
    FROM dbo.Claim WHERE Status = 7 AND ModifiedAt >= DATEADD(MINUTE, -5, GETDATE());

    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT ClaimId FROM dbo.Claim WHERE Status = 7;
    OPEN c;
    FETCH NEXT FROM c INTO @ClaimId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.usp_Claim_Notify @ClaimId = @ClaimId;
        FETCH NEXT FROM c INTO @ClaimId;
    END
    CLOSE c; DEALLOCATE c;

    EXEC dbo.usp_JobRun_End @RunId = @run;
END""")

SHOWCASE["usp_Claim_Notify"] = dict(kind="write", reads={"Claim", "Customer", "Translation"}, writes={"ExportQueue"},
    calls=[], funcs={"fn_Translate"}, entry=set(), text=r"""CREATE PROCEDURE dbo.usp_Claim_Notify
    @ClaimId INT
AS
BEGIN
    SET NOCOUNT ON;
    -- e-mail neposilame z DB, jen zaradime do fronty pro exportni sluzbu
    INSERT INTO dbo.ExportQueue (HandlerProc, Payload, Status, CreatedAt)
    SELECT 'usp_Rpt_Export_Email',
           (SELECT c.Email, cl.ClaimNumber, dbo.fn_Translate('CLAIM_OVERDUE', 'cs') AS Body
            FROM dbo.Claim cl JOIN dbo.Customer c ON c.CustomerId = cl.CustomerId
            WHERE cl.ClaimId = @ClaimId FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           1, GETDATE();
END""")

SHOWCASE["fn_Claim_Deadline"] = dict(kind="func", text=r"""CREATE FUNCTION dbo.fn_Claim_Deadline (@PurchasedAt DATETIME2, @IsBusiness BIT)
RETURNS DATE
AS
BEGIN
    -- spotrebitel: 24 mesicu od prevzeti; firma: 12 mesicu (smluvne)
    -- POZOR: pocita od data objednavky, ne od prevzeti zbozi (znamy rozdil, ticket 4711)
    RETURN CAST(DATEADD(MONTH, CASE WHEN @IsBusiness = 1 THEN 12 ELSE 24 END, @PurchasedAt) AS DATE);
END""")

SHOWCASE["tvf_ClaimItems"] = dict(kind="func", text=r"""CREATE FUNCTION dbo.tvf_ClaimItems (@ClaimId INT)
RETURNS TABLE
AS
RETURN
(
    SELECT ci.ClaimItemId, ci.OrderItemId, p.Code AS ProductCode, p.Name AS ProductName,
           ci.Qty, oi.UnitPrice, ci.DefectDescription
    FROM dbo.ClaimItem AS ci
    JOIN dbo.OrderItem AS oi ON oi.OrderItemId = ci.OrderItemId
    JOIN dbo.Product   AS p  ON p.ProductId = oi.ProductId
    WHERE ci.ClaimId = @ClaimId
);""")

for name, spec in SHOWCASE.items():
    if name in modules:
        m = modules[name]
    else:
        m = new_module(name, "Claims", spec["kind"])
    m["text"] = spec["text"]
    for k in ("reads", "writes", "funcs", "entry", "dyn_tables_literal"):
        if k in spec:
            m[k] = set(spec[k])
    if "calls" in spec:
        m["calls"] = list(spec["calls"])
    if "dyn" in spec:
        m["dyn"] = spec["dyn"]
    if "freq" in spec:
        m["freq"] = spec["freq"]
    m["showcase"] = True

# --------------------------------------------------------------------------
# Generované procedury domén
# --------------------------------------------------------------------------
INFRA_CALLS = ["usp_Audit_Write", "usp_Error_Log", "usp_SysParam_Get", "usp_Counter_Next", "usp_User_CheckPermission"]


def pick(seq, k=1):
    seq = list(seq)
    k = min(k, len(seq))
    return R.sample(seq, k)


def short_obj(t):
    return t.replace("Orders", "Order")


for dom, (prefix, n, p_fw, fw_pool, fr_pool, p_dyn, out_doms) in DOMAINS.items():
    own = own_tables(dom)
    kinds = (["read"] * 9 + ["write"] * 8 + ["process"] * 4 + ["batch"] * 3)
    if dom == "Reporting":
        kinds = ["report"] * 10 + ["batch"] * 6 + ["read"] * 3
    made = 0
    tries = 0
    while made < n and tries < 1000:
        tries += 1
        kind = R.choice(kinds)
        # hlavní entita domény (první tabulka) je nejčastější cíl, jako v reálném monolitu
        t = own[0] if R.random() < 0.3 else R.choice(own)
        if kind == "read":
            verb = R.choice(VERBS_READ)
        elif kind in ("write",):
            verb = R.choice(VERBS_WRITE)
        elif kind == "process":
            verb = R.choice(VERBS_PROC)
        elif kind == "report":
            verb = R.choice(["Sales", "Margin", "Stock", "Customers", "Kpi", "Daily", "Weekly", "Export"])
        else:
            verb = R.choice(VERBS_BATCH)
        sep = "_" if not prefix.startswith("spSklad") else "_"
        name = "%s%s%s_%s" % (prefix, sep, short_obj(t), verb) if kind != "report" else "%s_%s_%s" % (prefix, verb, short_obj(t))
        if prefix == "usp_Order" and t in ("Orders",):
            name = "usp_Order_%s" % verb
        if name in modules:
            continue
        m = new_module(name, dom, kind)
        made += 1
        # vlastní tabulky
        parents = [p for p in TABLE_FKS.get(t, []) if p in own]
        if kind in ("read", "report"):
            m["reads"].add(t)
            m["reads"].update(pick(parents, R.randint(0, len(parents))))
            if R.random() < 0.5:
                m["reads"].update(pick(own, 1))
        elif kind == "write":
            m["writes"].add(t)
            m["reads"].update(pick(parents, R.randint(0, len(parents))))
            if R.random() < 0.4:
                m["writes"].update(pick(own, 1))
        elif kind == "process":
            m["writes"].update(pick(own, 2))
            m["reads"].update(pick(own, 2))
        else:  # batch
            m["writes"].update(pick(own, R.randint(1, 3)))
            m["reads"].update(pick(own, 2))
        if kind == "report":
            m["reads"].update(pick(fr_pool, R.randint(2, 4)))
            m["writes"].update(pick([x for x in own if x.startswith("Rpt")], R.randint(0, 1)))
        # cizí čtení
        if fr_pool and R.random() < 0.55:
            m["reads"].update(pick(fr_pool, R.randint(1, 2)))
        # cizí zápisy
        if kind in ("write", "process", "batch") and fw_pool and R.random() < p_fw:
            m["writes"].update(pick(fw_pool, 1))
        # pohledy
        if R.random() < 0.25:
            vs = [v[0] for v in VIEWS if v[1] == dom or (v[1] in out_doms and R.random() < 0.3)]
            if vs:
                m["reads"].add(R.choice(vs))
        # funkce
        if R.random() < 0.35:
            fpool = FUNCS_BY_DOMAIN.get(dom, []) + FUNCS_BY_DOMAIN["Shared"]
            if fpool:
                m["funcs"].add(R.choice(fpool))
        # infrastruktura
        if m["writes"] and R.random() < 0.6:
            m["calls"].append("usp_Audit_Write")
        if R.random() < 0.25:
            m["calls"].append(R.choice(INFRA_CALLS))
        if kind == "batch":
            m["calls"] += ["usp_JobRun_Start", "usp_JobRun_End"]
            m["freq"] = R.choice(["denně 01:00", "denně 03:30", "každou hodinu", "každých 15 min", "1. den v měsíci 04:00"])
            if R.random() < 0.25:
                m["crossdb"].append((R.choice(["Archive", "Accounting", "DWH"]), t + "_Archive" if R.random() < 0.6 else t))
        if kind in ("process", "batch") and R.random() < 0.3:
            m["temp"] = True
        # dynamické SQL
        if R.random() < p_dyn:
            if dom == "Reporting" and R.random() < 0.6:
                m["dyn"] = {"type": "table_concat", "prefix": "Sales_", "runtime": ["Sales_2025", "Sales_2026"]}
                m["dyn_tables_literal"].add("Orders")
                m["dyn_tables_runtime"].update(["Sales_2025", "Sales_2026"])
            elif R.random() < 0.5:
                m["dyn"] = {"type": "literal"}
                lit = R.choice(own)
                m["dyn_tables_literal"].add(lit)
                m["dyn_tables_runtime"].add(lit)
            else:
                tgt = R.choice(own)
                m["dyn"] = {"type": "table_param", "runtime": [tgt]}
                m["dyn_tables_runtime"].add(tgt)
        # pasti pro naivní regex
        if R.random() < 0.08:
            m["stale_comment"] = R.choice(["OldOrders", "Product_bak2019", "TmpRecalc"])
        if R.random() < 0.08:
            m["string_trap"] = R.choice(own)

# Výjimečné případy: roční uzávěrka a mrtvé „migrace“
m = new_module("usp_Inv_YearClose", "Invoicing", "batch")
m["writes"].update(["LedgerEntry", "AccountingExport"]); m["reads"].update(["Invoice", "LedgerEntry", "VatRate"])
m["calls"] += ["usp_JobRun_Start", "usp_JobRun_End", "usp_Audit_Write"]
m["crossdb"].append(("Accounting", "YearBalance"))
m["freq"] = "ročně 2. 1. 01:00"; m["yearly"] = True

m = new_module("usp_Rpt_Dispatch", "Reporting", "batch")
m["reads"].add("ExportQueue"); m["writes"].add("ExportQueue")
m["dyn"] = {"type": "proc_dispatch"}
m["freq"] = "každých 5 min"
m["calls"] += ["usp_JobRun_Start", "usp_JobRun_End"]

for nm in ("usp_Rpt_Export_Email", "usp_Rpt_Export_Heureka", "usp_Rpt_Export_Accounting", "usp_Rpt_Export_Supplier"):
    m = new_module(nm, "Reporting", "export")
    m["reads"].update(["ExportQueue"] + pick(["Orders", "Product", "Invoice", "Customer", "SupplierProduct", "PriceListItem"], 2))
    m["writes"].add("ExportQueue")
    modules["usp_Rpt_Dispatch"]["dyn_procs_runtime"].add(nm)
    if nm == "usp_Rpt_Export_Supplier":
        modules["usp_Rpt_Dispatch"]["dyn_procs_runtime"].discard(nm)   # handler už ve frontě není: mrtvá

# Doprava: dispatch podle dopravce (HandlerProc v tabulce Carrier)
m = new_module("usp_Ship_SendToCarrier", "Shipping", "process")
m["reads"].update(["Shipment", "Carrier"]); m["writes"].add("ShipmentTracking")
m["dyn"] = {"type": "proc_dispatch"}
for nm in ("usp_Ship_Carrier_PPL", "usp_Ship_Carrier_DPD", "usp_Ship_Carrier_Zasilkovna", "usp_Ship_Carrier_CeskaPosta", "usp_Ship_Carrier_GLS_old"):
    mm = new_module(nm, "Shipping", "write")
    mm["reads"].update(["Shipment", "ShipmentItem", "CustomerAddress"]); mm["writes"].update(["Shipment", "ShipmentTracking"])
    if not nm.endswith("_old"):
        m["dyn_procs_runtime"].add(nm)

LEGACY_PROCS = ["usp_Migr2019_Customer", "usp_Migr2019_Orders", "usp_Migr2019_Product", "usp_Old_PriceCalc",
                "usp_Old_OrderExport", "usp_Import_Product", "usp_Import_Stock", "usp_Import_Price",
                "usp_Tmp_Recalc", "usp_Tmp_FixStock", "sp_Test_Order", "usp_Product_Bak_Restore",
                "usp_Old_InvoicePrint", "usp_Old_CustomerMerge"]
for nm in LEGACY_PROCS:
    m = new_module(nm, "Legacy", R.choice(["write", "batch", "read"]))
    leg = own_tables("Legacy")
    m["reads"].update(pick(leg, 1))
    m["writes"].update(pick(leg, 1))
    if R.random() < 0.6:
        m["writes"].add(R.choice(["Product", "Customer", "Orders", "StockLevel"]))
    if R.random() < 0.3:
        m["dyn"] = {"type": "table_param", "runtime": []}
    m["dead"] = True
# Import procedury stále živé přes plánovač (jen Import_Stock), ostatní mrtvé
modules["usp_Import_Stock"]["dead"] = False
modules["usp_Import_Stock"]["kind"] = "batch"
modules["usp_Import_Stock"]["freq"] = "každou hodinu"

# --------------------------------------------------------------------------
# Volání mezi procedurami (statická vrstva)
# --------------------------------------------------------------------------
by_domain = defaultdict(list)
for nm in order:
    by_domain[modules[nm]["domain"]].append(nm)

rank = {nm: i for i, nm in enumerate(order)}

for dom, (prefix, n, p_fw, fw_pool, fr_pool, p_dyn, out_doms) in DOMAINS.items():
    procs = [x for x in by_domain[dom] if modules[x]["type"] == "P" and not modules[x].get("showcase")]
    leaf = [x for x in procs if modules[x]["kind"] in ("read", "write")]
    for nm in procs:
        m = modules[nm]
        if m["kind"] in ("process", "batch"):
            for c in pick([x for x in leaf if x != nm], R.randint(2, 4)):
                m["calls"].append(c)
            if out_doms and R.random() < 0.7:
                od = R.choice(out_doms)
                targets = [x for x in by_domain[od] if modules[x]["type"] == "P" and modules[x]["kind"] in ("read", "write") and not modules[x].get("showcase")]
                if targets:
                    m["calls"].append(R.choice(targets))
        elif m["kind"] == "write" and R.random() < 0.25 and leaf:
            c = R.choice(leaf)
            if c != nm and modules[c]["kind"] == "read":
                m["calls"].append(c)

# Refund create (cíl showcase volání) – vyrobit, pokud chybí
if "usp_Refund_Create" not in modules:
    m = new_module("usp_Refund_Create", "Payments", "write")
    m["writes"].update(["Refund", "PaymentTransaction"]); m["reads"].update(["Payment"])
    m["calls"] += ["usp_Audit_Write"]
    by_domain["Payments"].append("usp_Refund_Create")

# Orders: klíčový „Order_Create“ jako křižovatka
if "usp_Order_Create" not in modules:
    m = new_module("usp_Order_Create", "Orders", "process")
    m["writes"].update(["Orders", "OrderItem", "OrderStatusHistory", "StockReservation", "VoucherUse"])
    m["reads"].update(["Cart", "CartItem", "Customer", "Product", "Voucher"])
    m["funcs"].update(["fn_ProductPrice", "fn_ProductAvailableQty", "fn_OrderTotal"])
    for od in ("Warehouse", "Payments", "Pricing", "Customers"):
        tg = [x for x in by_domain[od] if modules[x]["type"] == "P" and modules[x]["kind"] in ("read", "write")]
        m["calls"].append(R.choice(tg))
    m["calls"] += ["usp_Counter_Next", "usp_Audit_Write"]
    m["entry"].update(["client", "web"])
    m["calls_noschema"].add(m["calls"][0])   # EXEC bez schématu
    by_domain["Orders"].append("usp_Order_Create")

# Pár volání bez schématu (caller-dependent) napříč
for nm in order:
    m = modules[nm]
    if m["calls"] and R.random() < 0.08:
        m["calls_noschema"].add(R.choice(m["calls"]))

# --------------------------------------------------------------------------
# Triggery (skryté zápisy)
# --------------------------------------------------------------------------
TRIGGERS = [
    ("trg_StockLevel_Movement", "StockLevel", ["StockMovement"], "Warehouse"),
    ("trg_Orders_Audit", "Orders", ["AuditLog"], "Orders"),
    ("trg_Product_PriceHistory", "Product", ["PriceHistory"], "Catalog"),
    ("trg_Payment_OrderPaid", "Payment", ["Orders"], "Payments"),
    ("trg_Claim_Audit", "Claim", ["AuditLog"], "Claims"),
    ("trg_Customer_Audit", "Customer", ["AuditLog"], "Customers"),
]
for nm, on, writes, d in TRIGGERS:
    m = new_module(nm, d, "trigger", "TR")
    m["on"] = on
    m["writes"].update(writes)
    if on == "Product":
        m["reads"].add("Product")

# --------------------------------------------------------------------------
# Vstupní body: klient, plánovač, web; mrtvé procedury
# --------------------------------------------------------------------------
called = defaultdict(set)
for nm in order:
    for c in modules[nm]["calls"]:
        called[c].add(nm)
    for c in modules[nm]["dyn_procs_runtime"]:
        called[c].add(nm)

for nm in order:
    m = modules[nm]
    if m["type"] != "P" or m.get("showcase") or m["dead"]:
        continue
    if m["kind"] in ("batch",) or m.get("freq"):
        m["entry"].add("agent")
        continue
    if m["kind"] in ("export",):
        continue
    if nm in called:
        if R.random() < 0.3 and m["kind"] in ("read", "write"):
            m["entry"].add("client")
        continue
    # bez volajícího: buď klient, web, nebo mrtvá
    roll = R.random()
    if m["domain"] == "Shared":
        m["entry"].add("client")
    elif roll < 0.11:
        m["dead"] = True
    elif roll < 0.18 and m["domain"] in ("Orders", "Catalog", "Pricing", "Customers", "Claims"):
        m["entry"].add("web")
    else:
        m["entry"].add("client")
        if R.random() < 0.06:
            m["client_unused"] = True    # volání v kódu klienta je, ale za 6 týdnů nikdo neklikl

# Mrtvé jsou i ty, jejichž všichni volající jsou mrtví (spočítá se v pravdě)
def alive_closure():
    alive = set()
    frontier = [nm for nm in order if modules[nm]["type"] == "P" and not modules[nm]["dead"] and
                (modules[nm]["entry"] - ({"client"} if modules[nm]["client_unused"] else set()))]
    while frontier:
        x = frontier.pop()
        if x in alive:
            continue
        alive.add(x)
        m = modules[x]
        for c in list(m["calls"]) + list(m["dyn_procs_runtime"]) + list(m["funcs"]):
            if c in modules and c not in alive and not modules[c]["dead"]:
                frontier.append(c)
    # triggery žijí, když někdo zapisuje do tabulky
    for nm in order:
        if modules[nm]["type"] == "TR":
            on = modules[nm]["on"]
            if any(on in modules[a]["writes"] for a in alive):
                alive.add(nm)
    return alive

ALIVE = alive_closure()

# --------------------------------------------------------------------------
# Generování T-SQL textu
# --------------------------------------------------------------------------
def cols_of(t):
    for ts in TABLES.values():
        for name, fks, cols in ts:
            if name == t:
                return fks, cols
    return [], []


def param_for(m):
    t = next(iter(sorted(m["writes"] | m["reads"])), None) or "Entity"
    if t in VIEW_NAMES:
        return "Id"
    return key(t) if t in TABLE_DOMAIN else "Id"


def alias(t, used):
    a = "".join(ch for ch in t if ch.isupper()).lower() or t[:2].lower()
    base = a
    i = 2
    while a in used:
        a = base + str(i)
        i += 1
    used.add(a)
    return a


def emit_proc(m):
    if m.get("text"):
        return m["text"]
    p = param_for(m)
    L = []
    typ = "PROCEDURE" if R.random() < 0.85 else "PROC"
    L.append("CREATE %s dbo.%s" % (typ, m["name"]))
    params = ["    @%s INT = NULL" % p, "    @UserId INT = NULL"]
    if m["kind"] in ("write", "process"):
        params.append("    @Status TINYINT = NULL")
    if m["dyn"] and m["dyn"]["type"] == "table_concat":
        params.append("    @Year INT = NULL")
    if m["dyn"] and m["dyn"]["type"] == "table_param":
        params.append("    @TableName SYSNAME = NULL")
    L.append(",\n".join(params))
    L.append("AS")
    L.append("BEGIN")
    L.append("    SET NOCOUNT ON;")
    if m["stale_comment"]:
        L.append("    -- 2019: puvodne se cetlo z dbo.%s, ted uz ne (MK)" % m["stale_comment"])
    if m["temp"]:
        L.append("    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));")
    L.append("    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;")
    used = set()
    reads = sorted(m["reads"])
    writes = sorted(m["writes"])
    # čtení
    for t in reads:
        if t in writes and R.random() < 0.5:
            continue
        a = alias(t, used)
        fks, _ = cols_of(t)
        join_p = [f for f in fks if f in m["reads"] and f != t]
        if join_p and R.random() < 0.7:
            pt = join_p[0]
            b = alias(pt, used)
            L.append("    SELECT %s.*, %s.%s AS %sKey\n    FROM dbo.%s AS %s WITH (NOLOCK)\n    JOIN dbo.%s %s ON %s.%s = %s.%s\n    WHERE %s.Status = 1;" %
                     (a, b, key(pt), pt, t, a, pt, b, b, key(pt), a, key(pt), a))
        elif m["temp"] and R.random() < 0.5:
            L.append("    INSERT INTO #work (Id, Val)\n    SELECT %s.%s, 0 FROM dbo.%s %s WHERE %s.ModifiedAt >= DATEADD(DAY, -1, GETDATE());" %
                     (a, key(t) if t in TABLE_DOMAIN else "Id", t, a, a))
        else:
            kc = key(t) if t in TABLE_DOMAIN else "Id"
            L.append("    SELECT @cnt = COUNT(*) FROM dbo.%s WHERE %s = @%s;" % (t, kc, p))
    # funkce
    for f in sorted(m["funcs"]):
        if f.startswith("tvf_"):
            L.append("    SELECT * FROM dbo.%s(@%s);" % (f, p))
        else:
            L.append("    SET @val = dbo.%s(@%s);" % (f, p) if "Param" not in f else "    SET @val = dbo.%s('LIMIT_%s');" % (f, m["domain"].upper()))
    # zápisy
    for t in writes:
        kc = key(t)
        style = R.random()
        if style < 0.35:
            L.append("    UPDATE dbo.%s SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE %s = @%s;" % (t, kc, p))
        elif style < 0.55:
            a = alias(t, used)
            src = reads[0] if reads else "SysParam"
            b = alias(src, used)
            src_key = key(src) if src in TABLE_DOMAIN else "Id"
            L.append("    UPDATE %s SET %s.ModifiedAt = GETDATE()\n    FROM dbo.%s %s\n    INNER JOIN dbo.%s %s ON %s.%s = %s.%s\n    WHERE %s.%s = @%s;" %
                     (a, a, t, a, src, b, b, src_key, a, kc, a, kc, p))
        elif style < 0.8:
            L.append("    INSERT INTO dbo.%s (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);" % t)
        elif style < 0.9:
            L.append("    DELETE FROM dbo.%s WHERE %s = @%s AND Status = 0;" % (t, kc, p))
        else:
            L.append("    MERGE dbo.%s AS tgt\n    USING (SELECT @%s AS %s) AS src ON tgt.%s = src.%s\n    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()\n    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());" %
                     (t, p, kc, kc, kc))
    # cross-db
    for db, tbl in m["crossdb"]:
        src = writes[0] if writes else (reads[0] if reads else "AuditLog")
        L.append("    INSERT INTO %s.dbo.%s SELECT * FROM dbo.%s WHERE CreatedAt < DATEADD(MONTH, -24, GETDATE());" % (db, tbl, src))
    # dynamické SQL
    d = m["dyn"]
    if d:
        L.append("    DECLARE @sql NVARCHAR(MAX);")
        if d["type"] == "literal":
            t = sorted(m["dyn_tables_literal"])[0]
            L.append("    SET @sql = N'SELECT TOP (500) * FROM dbo.%s WHERE 1 = 1';" % t)
            L.append("    IF @Status IS NOT NULL SET @sql += N' AND Status = @s';" if m["kind"] in ("write", "process") else "    SET @sql += N' ORDER BY CreatedAt DESC';")
            L.append("    EXEC sp_executesql @sql, N'@s TINYINT', @s = %s;" % ("@Status" if m["kind"] in ("write", "process") else "1"))
        elif d["type"] == "table_concat":
            L.append("    SET @Year = ISNULL(@Year, YEAR(GETDATE()));")
            L.append("    SET @sql = N'INSERT INTO dbo.%s' + CAST(@Year AS NVARCHAR(4)) + N' (OrderId, Amount, Status, CreatedAt) '\n           + N'SELECT o.OrderId, o.TotalAmount, 1, GETDATE() FROM dbo.Orders o WHERE YEAR(o.CreatedAt) = @y';" % d["prefix"])
            L.append("    EXEC sp_executesql @sql, N'@y INT', @y = @Year;")
        elif d["type"] == "table_param":
            L.append("    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';")
            L.append("    EXEC (@sql);")
        elif d["type"] == "proc_dispatch":
            src = "ExportQueue" if m["domain"] == "Reporting" else "Carrier"
            L.append("    DECLARE @handler SYSNAME;")
            L.append("    SELECT TOP (1) @handler = HandlerProc FROM dbo.%s WHERE Status = 1;" % src)
            L.append("    SET @sql = N'EXEC dbo.' + QUOTENAME(@handler) + N' @%s = ' + CAST(ISNULL(@%s, 0) AS NVARCHAR(20));" % (p, p))
            L.append("    EXEC (@sql);")
    # volání
    for c in m["calls"]:
        if c not in modules:
            continue
        schema = "" if c in m["calls_noschema"] else "dbo."
        if c == "usp_Audit_Write":
            msg = ("N'Update dbo.%s'" % m["string_trap"]) if m["string_trap"] else "'%s'" % m["name"]
            L.append("    EXEC %s%s @EntityName = %s, @EntityId = @%s, @Action = 'UPD', @UserId = @UserId;" % (schema, c, msg, p))
        elif c == "usp_JobRun_Start":
            L.insert(L.index("    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;") + 1, "    EXEC %s%s @JobName = '%s';" % (schema, c, m["name"]))
        elif R.random() < 0.3:
            L.append("    EXEC @rc = %s%s @%s = @%s;" % (schema, c, p, p))
            L.append("    IF @rc <> 0 RETURN @rc;")
        else:
            L.append("    EXEC %s%s @%s = @%s, @UserId = @UserId;" % (schema, c, p, p))
    if m["temp"]:
        L.append("    DROP TABLE #work;")
    L.append("END")
    return "\n".join(L)


def emit_func(m):
    if m.get("text"):
        return m["text"]
    reads = sorted(m["reads"])
    if m["name"].startswith("tvf_"):
        sel = " JOIN ".join("dbo.%s AS t%d" % (t, i) if i == 0 else "dbo.%s AS t%d ON 1 = 1" % (t, i) for i, t in enumerate(reads))
        return ("CREATE FUNCTION dbo.%s (@Id INT)\nRETURNS TABLE\nAS\nRETURN\n(\n    SELECT t0.*\n    FROM %s\n    WHERE t0.Status = 1\n);" % (m["name"], sel))
    body = []
    for t in reads:
        body.append("    SELECT @r = @r + COUNT(*) FROM dbo.%s WHERE Status = 1;" % t)
    if not body:
        body.append("    SET @r = @r + LEN(CAST(@Id AS VARCHAR(20)));")
    return ("CREATE FUNCTION dbo.%s (@Id INT)\nRETURNS DECIMAL(12,2)\nAS\nBEGIN\n    DECLARE @r DECIMAL(12,2) = 0;\n%s\n    RETURN @r;\nEND" % (m["name"], "\n".join(body)))


def emit_trigger(m):
    w = sorted(m["writes"])[0]
    if w == "AuditLog":
        body = "    INSERT INTO dbo.AuditLog (EntityName, EntityId, Action, Status, CreatedAt)\n    SELECT '%s', i.%s, 'TRG', 1, GETDATE() FROM inserted i;" % (m["on"], key(m["on"]))
    elif w == "StockMovement":
        body = ("    INSERT INTO dbo.StockMovement (ProductId, WarehouseId, Qty, MovementType, Status, CreatedAt)\n"
                "    SELECT i.ProductId, i.WarehouseId, i.QtyOnHand - d.QtyOnHand, 'ADJ', 1, GETDATE()\n"
                "    FROM inserted i JOIN deleted d ON d.StockLevelId = i.StockLevelId\n    WHERE i.QtyOnHand <> d.QtyOnHand;")
    elif w == "Orders":
        body = "    UPDATE o SET o.IsPaid = 1 FROM dbo.Orders o JOIN inserted i ON i.OrderId = o.OrderId WHERE i.Status = 3;"
    else:
        body = ("    INSERT INTO dbo.%s (ProductId, OldPrice, NewPrice, Status, CreatedAt)\n"
                "    SELECT i.ProductId, d.CurrentPrice, i.CurrentPrice, 1, GETDATE()\n"
                "    FROM inserted i JOIN deleted d ON d.ProductId = i.ProductId WHERE i.CurrentPrice <> d.CurrentPrice;") % w
    return "CREATE TRIGGER dbo.%s ON dbo.%s\nAFTER INSERT, UPDATE\nAS\nBEGIN\n    SET NOCOUNT ON;\n%s\nEND" % (m["name"], m["on"], body)


def emit_table(name, fks, cols):
    lines = ["    %s INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_%s PRIMARY KEY" % (key(name), name)]
    for f in fks:
        lines.append("    %s INT NULL" % key(f))
    for c in cols:
        lines.append("    %s" % c)
    lines += ["    Status TINYINT NOT NULL DEFAULT (1)", "    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME())",
              "    CreatedBy INT NULL", "    ModifiedAt DATETIME2 NULL"]
    s = "CREATE TABLE dbo.%s (\n%s\n);" % (name, ",\n".join(lines))
    for f in fks:
        if f in TABLE_DOMAIN:
            s += "\nGO\nALTER TABLE dbo.%s ADD CONSTRAINT FK_%s_%s FOREIGN KEY (%s) REFERENCES dbo.%s (%s);" % (name, name, f, key(f), f, key(f))
    return s


def emit_view(name, tables):
    used = set()
    parts = []
    first = tables[0]
    a0 = alias(first, used)
    sql = "CREATE VIEW dbo.%s\nAS\nSELECT %s.*\nFROM dbo.%s AS %s" % (name, a0, first, a0)
    for t in tables[1:]:
        a = alias(t, used)
        fks, _ = cols_of(first)
        if t in fks:
            sql += "\nLEFT JOIN dbo.%s AS %s ON %s.%s = %s.%s" % (t, a, a, key(t), a0, key(t))
        else:
            sql += "\nLEFT JOIN dbo.%s AS %s ON %s.%s = %s.%s" % (t, a, a, key(first), a0, key(first)) if first in TABLE_FKS.get(t, []) else "\nLEFT JOIN dbo.%s AS %s ON 1 = 0" % (t, a)
    if name == "vw_RptSalesAll":
        sql = "CREATE VIEW dbo.vw_RptSalesAll\nAS\n" + "\nUNION ALL\n".join("SELECT OrderId, Amount, CreatedAt FROM dbo.%s" % t for t in tables)
    return sql + ";"


# --------------------------------------------------------------------------
# Zápis souborů
# --------------------------------------------------------------------------
def ensure(p):
    os.makedirs(p, exist_ok=True)


for sub in ("db", "catalog", "client", "scheduler", "runtime"):
    ensure(os.path.join(OUT, sub))

HEADER = "-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed %d).\n-- Žádná reálná data ani schéma skutečné firmy.\n" % SEED

with open(os.path.join(OUT, "db", "00_tables.sql"), "w", encoding="utf-8") as f:
    f.write(HEADER)
    for d, ts in TABLES.items():
        f.write("\n-- ===== %s =====\n" % d)
        for name, fks, cols in ts:
            f.write(emit_table(name, fks, cols) + "\nGO\n\n")

with open(os.path.join(OUT, "db", "01_views.sql"), "w", encoding="utf-8") as f:
    f.write(HEADER)
    for name, d, tables in VIEWS:
        f.write(emit_view(name, tables) + "\nGO\n\n")

# Procedury do souborů po „historických“ skupinách (export tak často vypadá)
files = defaultdict(list)
for nm in order:
    m = modules[nm]
    if m["type"] == "P":
        files["02_procs_%s.sql" % m["domain"].lower()].append(emit_proc(m))
    elif m["type"] in ("FN", "IF"):
        files["03_functions.sql"].append(emit_func(m))
    elif m["type"] == "TR":
        files["04_triggers.sql"].append(emit_trigger(m))
for fn, chunks in files.items():
    with open(os.path.join(OUT, "db", fn), "w", encoding="utf-8") as f:
        f.write(HEADER)
        for c in chunks:
            f.write("\n" + c + "\nGO\n")

# Velikosti tabulek
with open(os.path.join(OUT, "catalog", "table_sizes.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["schema_name", "table_name", "row_count", "reserved_gb"])
    total = 0
    for d, ts in TABLES.items():
        for name, _, _ in ts:
            gb = BIG.get(name, round(R.uniform(0.2, 40) if d != "Legacy" else R.uniform(0.5, 90), 1))
            rows = int(gb * R.uniform(2.5e6, 6e6))
            total += gb
            w.writerow(["dbo", name, rows, gb])

# Delphi klient: výsledek grepu nad zdrojáky
UNITS = {"Catalog": "Katalog\\uProdukt", "Pricing": "Ceny\\uCenik", "Customers": "Zakaznici\\uZakaznik",
         "Orders": "Objednavky\\uObjednavka", "Warehouse": "Sklad\\uSklad", "Purchasing": "Nakup\\uNakup",
         "Shipping": "Doprava\\uZasilka", "Payments": "Platby\\uPlatba", "Invoicing": "Fakturace\\uFaktura",
         "Claims": "Reklamace\\uReklamace", "Reporting": "Reporty\\uReport", "Shared": "Spolecne\\uSpolecne", "Legacy": "Stare\\uStare"}
with open(os.path.join(OUT, "client", "delphi_calls.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["source_file", "line", "component", "proc_name", "expression"])
    for nm in order:
        m = modules[nm]
        if "client" in m["entry"]:
            unit = UNITS[m["domain"]] + R.choice(["Detail", "Seznam", "Edit", "Akce"]) + ".pas"
            comp = R.choice(["TADOStoredProc.ProcedureName", "TADOStoredProc.ProcedureName", "TADOQuery.SQL", "TADOCommand.CommandText"])
            nm_out = nm if comp == "TADOStoredProc.ProcedureName" or R.random() < 0.5 else "dbo." + nm
            expr = "'%s'" % nm_out if comp == "TADOStoredProc.ProcedureName" else "'EXEC %s :p1, :p2'" % nm_out
            w.writerow(["src\\Konzole\\" + unit, R.randint(80, 2400), comp, nm_out, expr])
    # klient skládá jméno reportu za běhu: grep jméno nezjistí
    w.writerow(["src\\Konzole\\Reporty\\uReportRunner.pas", 211, "TADOStoredProc.ProcedureName", "", "'usp_Rpt_' + cbReport.Text"])
    # klient sahá přímo do tabulek
    for t, ln in (("Product", 340), ("StockLevel", 1022), ("Customer", 518), ("SysParam", 77)):
        w.writerow(["src\\Konzole\\Spolecne\\uPrimySql.pas", ln, "TADOQuery.SQL", "", "'SELECT * FROM %s WHERE ...'" % t])

# Klientské volání reportů skládaných z cbReport.Text: které to jsou (pravda pro runtime)
client_dynamic_reports = [nm for nm in by_domain["Reporting"] if modules[nm]["kind"] == "report"][:5]
for nm in client_dynamic_reports:
    modules[nm]["entry"].add("client_dynamic")
    modules[nm]["dead"] = False
ALIVE = alive_closure() | set(client_dynamic_reports)
for nm in client_dynamic_reports:
    ALIVE |= set(c for c in modules[nm]["calls"])

# Plánovač
with open(os.path.join(OUT, "scheduler", "sql_agent_jobs.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["job_name", "step_id", "step_name", "subsystem", "database_name", "command", "schedule", "enabled"])
    for nm in order:
        m = modules[nm]
        if "agent" in m["entry"]:
            job = "KOMPAS - " + nm.replace("usp_", "").replace("_", " ")
            cmd = "EXEC dbo.%s" % nm if R.random() < 0.8 else "SET DEADLOCK_PRIORITY LOW;\nEXEC %s;" % nm
            w.writerow([job, 1, "run", "TSQL", "Kompas", cmd, m["freq"] or "denně 02:00", 1])
    # vypnutý job na mrtvou proceduru a job s PowerShellem (jméno procedury není v T-SQL kroku)
    w.writerow(["KOMPAS - Old Order Export", 1, "run", "TSQL", "Kompas", "EXEC dbo.usp_Old_OrderExport", "denně 05:00", 0])
    w.writerow(["KOMPAS - Feed Heureka", 1, "ps", "PowerShell", "", "Invoke-Sqlcmd -Query \"EXEC dbo.usp_Rpt_Export_Heureka\" -ServerInstance KOMPAS-SQL01", "každou hodinu", 1])

# --------------------------------------------------------------------------
# Runtime: XE + Query Store (6 týdnů)
# --------------------------------------------------------------------------
WINDOW = ("2026-09-14", "2026-10-25")
FREQ_PER_6W = {"každých 5 min": 12096, "každých 15 min": 4032, "každou hodinu": 1008, "denně 01:00": 42, "denně 02:00": 42,
               "denně 03:30": 42, "denně 06:00": 42, "denně 02:00 ": 42, "1. den v měsíci 04:00": 2, "ročně 2. 1. 01:00": 0}

rpc = defaultdict(lambda: defaultdict(int))   # proc -> app -> count
for nm in order:
    m = modules[nm]
    if nm not in ALIVE or m["type"] != "P":
        continue
    if "client" in m["entry"] and not m["client_unused"]:
        rpc[nm]["Konzole.exe"] += int(math.exp(R.uniform(3, 11)))
    if "client_dynamic" in m["entry"]:
        rpc[nm]["Konzole.exe"] += int(math.exp(R.uniform(2, 6)))
    if "web" in m["entry"]:
        rpc[nm]["Kompas.Web.Api"] += int(math.exp(R.uniform(10, 14)))
    if "agent" in m["entry"]:
        n6 = FREQ_PER_6W.get(m["freq"] or "denně 02:00", 42)
        if n6:
            rpc[nm]["SQLAgent - TSQL JobStep"] += n6
# PowerShell job volá Heureka export (plánovač o něm v T-SQL krocích neví)
rpc["usp_Rpt_Export_Heureka"][".Net SqlClient Data Provider (Invoke-Sqlcmd)"] += 1008

# vnořená volání: propagace počtů dolů po grafu (pravda včetně dynamických)
total_calls = defaultdict(int)
for nm, apps in rpc.items():
    total_calls[nm] += sum(apps.values())


def callees(nm):
    m = modules[nm]
    return [c for c in m["calls"] if c in modules] + sorted(m["dyn_procs_runtime"])


# topologicky: opakovaně, graf je DAG podle konstrukce (pojistka max hloubka)
indeg = defaultdict(int)
for nm in order:
    for c in callees(nm):
        indeg[c] += 1
queue = [nm for nm in order if indeg[nm] == 0]
topo = []
while queue:
    x = queue.pop(0)
    topo.append(x)
    for c in callees(x):
        indeg[c] -= 1
        if indeg[c] == 0:
            queue.append(c)
for nm in topo:
    if nm not in ALIVE:
        continue
    cnt = total_calls[nm]
    m = modules[nm]
    disp = sorted(m["dyn_procs_runtime"])
    for c in m["calls"]:
        if c in modules:
            total_calls[c] += max(1, int(cnt * R.uniform(0.3, 1.0)))
    for c in disp:
        total_calls[c] += max(1, int(cnt / max(1, len(disp)) * R.uniform(0.5, 1.5)))

with open(os.path.join(OUT, "runtime", "xe_rpc_completed_histogram.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["object_name", "client_app_name", "event_count", "window_from", "window_to"])
    for nm in sorted(rpc):
        for app, c in sorted(rpc[nm].items()):
            if c:
                w.writerow(["dbo." + nm, app, c, WINDOW[0], WINDOW[1]])

with open(os.path.join(OUT, "runtime", "xe_module_end_histogram.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["object_name", "object_type", "event_count", "window_from", "window_to"])
    for nm in order:
        if nm in ALIVE and total_calls[nm] > 0 and modules[nm]["type"] == "P":
            w.writerow(["dbo." + nm, "P", total_calls[nm], WINDOW[0], WINDOW[1]])

# Dynamické SQL zachycené za běhu (XE sp_statement_completed + tsql_stack -> nadřazený modul)
with open(os.path.join(OUT, "runtime", "xe_dynamic_sql.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["parent_object", "statement_sample", "event_count"])
    for nm in order:
        m = modules[nm]
        if not m["dyn"] or nm not in ALIVE or total_calls[nm] == 0:
            continue
        for t in sorted(m["dyn_tables_runtime"] | m["dyn_tables_literal"]):
            if m["dyn"]["type"] == "table_concat" and t == "Orders":
                continue
            if m["dyn"]["type"] == "table_concat":
                stmt = "INSERT INTO dbo.%s (OrderId, Amount, Status, CreatedAt) SELECT o.OrderId, o.TotalAmount, 1, GETDATE() FROM dbo.Orders o WHERE YEAR(o.CreatedAt) = @y" % t
            elif m["dyn"]["type"] == "table_param":
                stmt = "UPDATE dbo.[%s] SET ModifiedAt = GETDATE() WHERE Status = 0" % t
            else:
                stmt = "SELECT TOP (500) * FROM dbo.%s WHERE 1 = 1 ..." % t
            w.writerow(["dbo." + nm, stmt, max(1, int(total_calls[nm] * R.uniform(0.2, 1.0)))])
        for c in sorted(m["dyn_procs_runtime"]):
            w.writerow(["dbo." + nm, "EXEC dbo.[%s] @Id = ..." % c, max(1, total_calls[c])])

# Query Store: provozní váha
with open(os.path.join(OUT, "runtime", "query_store_proc_stats.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["object_name", "stmt_executions", "cpu_ms", "logical_reads", "logical_writes"])
    for nm in order:
        m = modules[nm]
        if nm not in ALIVE or total_calls[nm] == 0 or m["type"] != "P":
            continue
        n = total_calls[nm]
        stmts = n * R.randint(2, 12)
        heavy = 1.0
        for t in m["reads"] | m["writes"]:
            heavy += BIG.get(t, 0) / 1500.0
        cpu = int(n * R.uniform(0.3, 6) * heavy)
        reads = int(cpu * R.uniform(20, 120))
        writes = int(n * len(m["writes"]) * R.uniform(1, 8))
        w.writerow(["dbo." + nm, stmts, cpu, reads, writes])

# --------------------------------------------------------------------------
# Pravda pro vyhodnocení (analyzátor ji nečte)
# --------------------------------------------------------------------------
truth = {
    "seed": SEED,
    "window": WINDOW,
    "domains": {nm: modules[nm]["domain"] for nm in order},
    "table_domains": TABLE_DOMAIN,
    "dead": sorted(nm for nm in order if modules[nm]["type"] == "P" and nm not in ALIVE),
    "yearly": sorted(nm for nm in order if modules[nm]["yearly"]),
    "dynamic": {nm: modules[nm]["dyn"]["type"] for nm in order if modules[nm]["dyn"]},
    "client_unused": sorted(nm for nm in order if modules[nm]["client_unused"]),
    "web_only": sorted(nm for nm in order if modules[nm]["entry"] == {"web"}),
    "counts": {
        "procedures": sum(1 for m in modules.values() if m["type"] == "P"),
        "functions": sum(1 for m in modules.values() if m["type"] in ("FN", "IF")),
        "triggers": sum(1 for m in modules.values() if m["type"] == "TR"),
        "tables": len(TABLE_DOMAIN),
        "views": len(VIEWS),
    },
}
with open(os.path.join(OUT, "_ground_truth.json"), "w", encoding="utf-8") as f:
    json.dump(truth, f, ensure_ascii=False, indent=1, sort_keys=True)

c = truth["counts"]
print("Syntetická DB: %d procedur, %d funkcí, %d triggerů, %d tabulek, %d pohledů -> %s" %
      (c["procedures"], c["functions"], c["triggers"], c["tables"], c["views"], OUT))
print("Mrtvé procedury (pravda): %d, dynamické SQL: %d" % (len(truth["dead"]), len(truth["dynamic"])))
