-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE PROCEDURE dbo.usp_Po_SupplierProduct_GetDetail
    @SupplierId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Supplier WHERE SupplierId = @SupplierId;
    SELECT @cnt = COUNT(*) FROM dbo.SupplierProduct WHERE SupplierProductId = @SupplierId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_StockByWarehouse WHERE Id = @SupplierId;
    EXEC @rc = dbo.usp_Error_Log @SupplierId = @SupplierId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Po_Supplier_GetDetail
    @ProductId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @ProductId;
    SELECT @cnt = COUNT(*) FROM dbo.Supplier WHERE SupplierId = @ProductId;
    EXEC dbo.usp_User_CheckPermission @ProductId = @ProductId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Po_Supplier_Close
    @SupplierId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.vw_SupplierPrice WHERE Id = @SupplierId;
    UPDATE dbo.Supplier SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE SupplierId = @SupplierId;
    DELETE FROM dbo.SupplierProduct WHERE SupplierProductId = @SupplierId AND Status = 0;
    EXEC @rc = dbo.usp_Po_Supplier_GetDetail @SupplierId = @SupplierId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Po_Supplier_Recalc
    @ProductId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @ProductId;
    UPDATE s SET s.ModifiedAt = GETDATE()
    FROM dbo.Supplier s
    INNER JOIN dbo.Product p2 ON p2.ProductId = s.SupplierId
    WHERE s.SupplierId = @ProductId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Po_Supplier_Recalc', @EntityId = @ProductId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Po_GoodsReceiptItem_Close
    @GoodsReceiptItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @GoodsReceiptItemId;
    INSERT INTO dbo.GoodsReceiptItem (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_User_CheckPermission @GoodsReceiptItemId = @GoodsReceiptItemId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Po_Supplier_Hourly
    @GoodsReceiptItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Po_Supplier_Hourly';
    SELECT gri.*, p.ProductId AS ProductKey
    FROM dbo.GoodsReceiptItem AS gri WITH (NOLOCK)
    JOIN dbo.Product p ON p.ProductId = gri.ProductId
    WHERE gri.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @GoodsReceiptItemId;
    SELECT sl.*, p3.ProductId AS ProductKey
    FROM dbo.StockLevel AS sl WITH (NOLOCK)
    JOIN dbo.Product p3 ON p3.ProductId = sl.ProductId
    WHERE sl.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Supplier WHERE SupplierId = @GoodsReceiptItemId;
    SET @val = dbo.fn_IsWorkingDay(@GoodsReceiptItemId);
    UPDATE dbo.PurchaseOrder SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE PurchaseOrderId = @GoodsReceiptItemId;
    UPDATE dbo.StockLevel SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE StockLevelId = @GoodsReceiptItemId;
    UPDATE sp SET sp.ModifiedAt = GETDATE()
    FROM dbo.SupplierProduct sp
    INNER JOIN dbo.GoodsReceiptItem gri2 ON gri2.GoodsReceiptItemId = sp.SupplierProductId
    WHERE sp.SupplierProductId = @GoodsReceiptItemId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Po_Supplier_Hourly', @EntityId = @GoodsReceiptItemId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @GoodsReceiptItemId = @GoodsReceiptItemId, @UserId = @UserId;
    EXEC dbo.usp_Po_SupplierProduct_GetDetail @GoodsReceiptItemId = @GoodsReceiptItemId, @UserId = @UserId;
    EXEC dbo.usp_Po_GoodsReceiptItem_Close @GoodsReceiptItemId = @GoodsReceiptItemId, @UserId = @UserId;
    EXEC dbo.usp_Po_PurchaseOrderItem_Insert @GoodsReceiptItemId = @GoodsReceiptItemId, @UserId = @UserId;
    EXEC dbo.usp_Po_PurchaseOrderItem_Delete @GoodsReceiptItemId = @GoodsReceiptItemId, @UserId = @UserId;
    EXEC @rc = dbo.spSklad_InventoryCount_Merge @GoodsReceiptItemId = @GoodsReceiptItemId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Po_PurchaseOrder_List
    @ProductId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @ProductId;
    SELECT po.*, s.SupplierId AS SupplierKey
    FROM dbo.PurchaseOrder AS po WITH (NOLOCK)
    JOIN dbo.Supplier s ON s.SupplierId = po.SupplierId
    WHERE po.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Supplier WHERE SupplierId = @ProductId;
END
GO

CREATE PROCEDURE dbo.usp_Po_PurchaseOrderItem_Insert
    @ProductId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.PurchaseOrder WHERE PurchaseOrderId = @ProductId;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @ProductId;
    INSERT INTO dbo.Product (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    MERGE dbo.PurchaseOrderItem AS tgt
    USING (SELECT @ProductId AS PurchaseOrderItemId) AS src ON tgt.PurchaseOrderItemId = src.PurchaseOrderItemId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Po_PurchaseOrderItem_Insert', @EntityId = @ProductId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Counter_Next @ProductId = @ProductId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Po_Supplier_Dispatch
    @ProductId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @ProductId;
    SELECT sl.*, p2.ProductId AS ProductKey
    FROM dbo.StockLevel AS sl WITH (NOLOCK)
    JOIN dbo.Product p2 ON p2.ProductId = sl.ProductId
    WHERE sl.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Supplier WHERE SupplierId = @ProductId;
    SELECT sp.*, s2.SupplierId AS SupplierKey
    FROM dbo.SupplierProduct AS sp WITH (NOLOCK)
    JOIN dbo.Supplier s2 ON s2.SupplierId = sp.SupplierId
    WHERE sp.Status = 1;
    SET @val = dbo.fn_Translate(@ProductId);
    UPDATE dbo.PurchaseOrder SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE PurchaseOrderId = @ProductId;
    UPDATE dbo.Supplier SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE SupplierId = @ProductId;
    EXEC dbo.usp_Counter_Next @ProductId = @ProductId, @UserId = @UserId;
    EXEC dbo.usp_Po_SupplierProduct_Delete @ProductId = @ProductId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Po_Supplier_GetDetail @ProductId = @ProductId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Po_PurchaseOrderItem_Insert @ProductId = @ProductId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Po_Supplier_Recalc @ProductId = @ProductId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.spSklad_Warehouse_GetByCode @ProductId = @ProductId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Po_Supplier_SetStatus
    @PurchaseOrderItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SET @val = dbo.fn_GetSysParam('LIMIT_PURCHASING');
    INSERT INTO dbo.PurchaseOrderItem (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE s SET s.ModifiedAt = GETDATE()
    FROM dbo.Supplier s
    INNER JOIN dbo.SysParam sp ON sp.SysParamId = s.SupplierId
    WHERE s.SupplierId = @PurchaseOrderItemId;
    EXEC dbo.usp_Error_Log @PurchaseOrderItemId = @PurchaseOrderItemId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Po_GoodsReceipt_Get
    @GoodsReceiptId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT gr.*, po.PurchaseOrderId AS PurchaseOrderKey
    FROM dbo.GoodsReceipt AS gr WITH (NOLOCK)
    JOIN dbo.PurchaseOrder po ON po.PurchaseOrderId = gr.PurchaseOrderId
    WHERE gr.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.PurchaseOrder WHERE PurchaseOrderId = @GoodsReceiptId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Po_GoodsReceipt_Get', @EntityId = @GoodsReceiptId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROC dbo.usp_Po_Supplier_Cancel
    @ProductId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.OldOrders, ted uz ne (MK)
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    INSERT INTO #work (Id, Val)
    SELECT p.ProductId, 0 FROM dbo.Product p WHERE p.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SELECT @cnt = COUNT(*) FROM dbo.PurchaseOrder WHERE PurchaseOrderId = @ProductId;
    SELECT poi.*, po2.PurchaseOrderId AS PurchaseOrderKey
    FROM dbo.PurchaseOrderItem AS poi WITH (NOLOCK)
    JOIN dbo.PurchaseOrder po2 ON po2.PurchaseOrderId = poi.PurchaseOrderId
    WHERE poi.Status = 1;
    INSERT INTO #work (Id, Val)
    SELECT sl.StockLevelId, 0 FROM dbo.StockLevel sl WHERE sl.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    MERGE dbo.PurchaseOrder AS tgt
    USING (SELECT @ProductId AS PurchaseOrderId) AS src ON tgt.PurchaseOrderId = src.PurchaseOrderId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    MERGE dbo.StockLevel AS tgt
    USING (SELECT @ProductId AS StockLevelId) AS src ON tgt.StockLevelId = src.StockLevelId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    MERGE dbo.SupplierProduct AS tgt
    USING (SELECT @ProductId AS SupplierProductId) AS src ON tgt.SupplierProductId = src.SupplierProductId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_Po_GoodsReceiptItem_Close @ProductId = @ProductId, @UserId = @UserId;
    EXEC dbo.usp_Po_PurchaseOrderItem_Delete @ProductId = @ProductId, @UserId = @UserId;
    EXEC dbo.spSklad_Location_Get @ProductId = @ProductId, @UserId = @UserId;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Po_GoodsReceipt_Sync
    @ProductId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @ProductId;
    SELECT poi.*, p2.ProductId AS ProductKey
    FROM dbo.PurchaseOrderItem AS poi WITH (NOLOCK)
    JOIN dbo.Product p2 ON p2.ProductId = poi.ProductId
    WHERE poi.Status = 1;
    SELECT sl.*, p3.ProductId AS ProductKey
    FROM dbo.StockLevel AS sl WITH (NOLOCK)
    JOIN dbo.Product p3 ON p3.ProductId = sl.ProductId
    WHERE sl.Status = 1;
    INSERT INTO dbo.Product (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    MERGE dbo.PurchaseOrder AS tgt
    USING (SELECT @ProductId AS PurchaseOrderId) AS src ON tgt.PurchaseOrderId = src.PurchaseOrderId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    UPDATE dbo.SupplierProduct SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE SupplierProductId = @ProductId;
    EXEC @rc = dbo.usp_Po_SupplierProduct_Delete @ProductId = @ProductId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Po_SupplierProduct_GetDetail @ProductId = @ProductId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Po_PurchaseOrder_List @ProductId = @ProductId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.spSklad_Warehouse_Import @ProductId = @ProductId, @UserId = @UserId;
END
GO

CREATE PROC dbo.usp_Po_SupplierProduct_Delete
    @GoodsReceiptId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @GoodsReceiptId;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @GoodsReceiptId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_SupplierPrice WHERE Id = @GoodsReceiptId;
    INSERT INTO dbo.GoodsReceipt (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    MERGE dbo.Product AS tgt
    USING (SELECT @GoodsReceiptId AS ProductId) AS src ON tgt.ProductId = src.ProductId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    UPDATE dbo.SupplierProduct SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE SupplierProductId = @GoodsReceiptId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Po_SupplierProduct_Delete', @EntityId = @GoodsReceiptId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROC dbo.usp_Po_PurchaseOrderItem_Delete
    @ProductId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SET @val = dbo.fn_WorkingDaysBetween(@ProductId);
    INSERT INTO dbo.Product (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO dbo.PurchaseOrderItem (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE s SET s.ModifiedAt = GETDATE()
    FROM dbo.Supplier s
    INNER JOIN dbo.SysParam sp ON sp.SysParamId = s.SupplierId
    WHERE s.SupplierId = @ProductId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Po_PurchaseOrderItem_Delete', @EntityId = @ProductId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Po_GoodsReceipt_GetDetail
    @GoodsReceiptId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.GoodsReceipt WHERE GoodsReceiptId = @GoodsReceiptId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @GoodsReceiptId;
    SELECT @cnt = COUNT(*) FROM dbo.PurchaseOrder WHERE PurchaseOrderId = @GoodsReceiptId;
END
GO
