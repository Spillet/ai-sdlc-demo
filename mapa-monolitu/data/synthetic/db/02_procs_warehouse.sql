-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE PROCEDURE dbo.spSklad_StockLevel_Close
    @StockLevelId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT * FROM dbo.tvf_StockByProduct(@StockLevelId);
    INSERT INTO dbo.StockLevel (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'spSklad_StockLevel_Close', @EntityId = @StockLevelId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.spSklad_Warehouse_Overview
    @OrderItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.TmpRecalc, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.Warehouse WHERE WarehouseId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_StockMovementLast30 WHERE Id = @OrderItemId;
END
GO

CREATE PROCEDURE dbo.spSklad_StockLevel_Get
    @StockLevelId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @StockLevelId;
    SELECT @cnt = COUNT(*) FROM dbo.StockMovement WHERE StockMovementId = @StockLevelId;
    EXEC @rc = dbo.usp_SysParam_Get @StockLevelId = @StockLevelId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.spSklad_StockLevel_GetByCode
    @OrderId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @OrderId;
    SELECT @cnt = COUNT(*) FROM dbo.PurchaseOrderItem WHERE PurchaseOrderItemId = @OrderId;
    SELECT sl.*, w.WarehouseId AS WarehouseKey
    FROM dbo.StockLevel AS sl WITH (NOLOCK)
    JOIN dbo.Warehouse w ON w.WarehouseId = sl.WarehouseId
    WHERE sl.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Warehouse WHERE WarehouseId = @OrderId;
    SET @val = dbo.fn_Translate(@OrderId);
    EXEC @rc = dbo.usp_Counter_Next @OrderId = @OrderId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.spSklad_InventoryCount_Merge
    @InventoryCountId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @InventoryCountId;
    SELECT @cnt = COUNT(*) FROM dbo.Warehouse WHERE WarehouseId = @InventoryCountId;
    SET @val = dbo.fn_SplitString(@InventoryCountId);
    UPDATE ic SET ic.ModifiedAt = GETDATE()
    FROM dbo.InventoryCount ic
    INNER JOIN dbo.OrderItem oi2 ON oi2.OrderItemId = ic.InventoryCountId
    WHERE ic.InventoryCountId = @InventoryCountId;
END
GO

CREATE PROCEDURE dbo.spSklad_StockLevel_List
    @OrderId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @OrderId;
    SELECT sl.*, w.WarehouseId AS WarehouseKey
    FROM dbo.StockLevel AS sl WITH (NOLOCK)
    JOIN dbo.Warehouse w ON w.WarehouseId = sl.WarehouseId
    WHERE sl.Status = 1;
    SELECT sr.*, o2.OrderId AS OrdersKey
    FROM dbo.StockReservation AS sr WITH (NOLOCK)
    JOIN dbo.Orders o2 ON o2.OrderId = sr.OrderId
    WHERE sr.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Warehouse WHERE WarehouseId = @OrderId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_PurchaseOpen WHERE Id = @OrderId;
    SET @val = dbo.fn_UserName(@OrderId);
END
GO

CREATE PROCEDURE dbo.spSklad_StockLevel_Save
    @ProductId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Warehouse WHERE WarehouseId = @ProductId;
    INSERT INTO dbo.Product (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE dbo.StockLevel SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE StockLevelId = @ProductId;
END
GO

CREATE PROCEDURE dbo.spSklad_Warehouse_Check
    @WarehouseId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Warehouse WHERE WarehouseId = @WarehouseId;
END
GO

CREATE PROCEDURE dbo.spSklad_StockLevel_Update
    @StockLevelId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Warehouse WHERE WarehouseId = @StockLevelId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_CartDetail WHERE Id = @StockLevelId;
    UPDATE dbo.StockLevel SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE StockLevelId = @StockLevelId;
    EXEC dbo.usp_Error_Log @StockLevelId = @StockLevelId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.spSklad_Warehouse_Approve
    @StockMovementId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    MERGE dbo.StockMovement AS tgt
    USING (SELECT @StockMovementId AS StockMovementId) AS src ON tgt.StockMovementId = src.StockMovementId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    DELETE FROM dbo.Warehouse WHERE WarehouseId = @StockMovementId AND Status = 0;
    EXEC dbo.usp_Audit_Write @EntityName = 'spSklad_Warehouse_Approve', @EntityId = @StockMovementId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.spSklad_StockReservation_Export
    @LocationId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'spSklad_StockReservation_Export';
    SELECT @cnt = COUNT(*) FROM dbo.Location WHERE LocationId = @LocationId;
    SELECT @cnt = COUNT(*) FROM dbo.StockMovement WHERE StockMovementId = @LocationId;
    SET @val = dbo.fn_GetSysParam('LIMIT_WAREHOUSE');
    UPDATE dbo.PurchaseOrder SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE PurchaseOrderId = @LocationId;
    UPDATE sm2 SET sm2.ModifiedAt = GETDATE()
    FROM dbo.StockMovement sm2
    INNER JOIN dbo.Location l2 ON l2.LocationId = sm2.StockMovementId
    WHERE sm2.StockMovementId = @LocationId;
    EXEC dbo.usp_Audit_Write @EntityName = 'spSklad_StockReservation_Export', @EntityId = @LocationId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @LocationId = @LocationId, @UserId = @UserId;
    EXEC dbo.spSklad_Warehouse_Check @LocationId = @LocationId, @UserId = @UserId;
    EXEC dbo.spSklad_InventoryCount_Merge @LocationId = @LocationId, @UserId = @UserId;
    EXEC dbo.spSklad_StockLevel_Save @LocationId = @LocationId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Order_OrderNote_Save @LocationId = @LocationId;
    IF @rc <> 0 RETURN @rc;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.spSklad_Location_Update
    @LocationId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @LocationId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @LocationId;
    SET @val = dbo.fn_WorkingDaysBetween(@LocationId);
    UPDATE dbo.Location SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE LocationId = @LocationId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
    EXEC dbo.usp_Audit_Write @EntityName = 'spSklad_Location_Update', @EntityId = @LocationId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.spSklad_Warehouse_Delete
    @StockMovementId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.OldOrders, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.vw_StockAvailable WHERE Id = @StockMovementId;
    SET @val = dbo.fn_StockValue(@StockMovementId);
    UPDATE sm SET sm.ModifiedAt = GETDATE()
    FROM dbo.StockMovement sm
    INNER JOIN dbo.vw_StockAvailable sa2 ON sa2.Id = sm.StockMovementId
    WHERE sm.StockMovementId = @StockMovementId;
    UPDATE dbo.Warehouse SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE WarehouseId = @StockMovementId;
    EXEC usp_Audit_Write @EntityName = 'spSklad_Warehouse_Delete', @EntityId = @StockMovementId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.spSklad_Warehouse_Export
    @InventoryCountItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'spSklad_Warehouse_Export';
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @InventoryCountItemId;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @InventoryCountItemId;
    SELECT @cnt = COUNT(*) FROM dbo.StockReservation WHERE StockReservationId = @InventoryCountItemId;
    SET @val = dbo.fn_WorkingDaysBetween(@InventoryCountItemId);
    INSERT INTO dbo.InventoryCountItem (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO dbo.Location (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE dbo.Product SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ProductId = @InventoryCountItemId;
    EXEC dbo.usp_Audit_Write @EntityName = 'spSklad_Warehouse_Export', @EntityId = @InventoryCountItemId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @InventoryCountItemId = @InventoryCountItemId, @UserId = @UserId;
    EXEC dbo.spSklad_Warehouse_Overview @InventoryCountItemId = @InventoryCountItemId, @UserId = @UserId;
    EXEC dbo.spSklad_StockLevel_Get @InventoryCountItemId = @InventoryCountItemId, @UserId = @UserId;
    EXEC dbo.spSklad_StockLevel_Overview @InventoryCountItemId = @InventoryCountItemId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Order_OrderEvent_Find @InventoryCountItemId = @InventoryCountItemId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.spSklad_InventoryCount_Check
    @InventoryCountId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.InventoryCount WHERE InventoryCountId = @InventoryCountId;
END
GO

CREATE PROCEDURE dbo.spSklad_StockLevel_Delete
    @LocationId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.PurchaseOrderItem WHERE PurchaseOrderItemId = @LocationId;
    SELECT @cnt = COUNT(*) FROM dbo.Warehouse WHERE WarehouseId = @LocationId;
    UPDATE l SET l.ModifiedAt = GETDATE()
    FROM dbo.Location l
    INNER JOIN dbo.PurchaseOrderItem poi2 ON poi2.PurchaseOrderItemId = l.LocationId
    WHERE l.LocationId = @LocationId;
    UPDATE sl SET sl.ModifiedAt = GETDATE()
    FROM dbo.StockLevel sl
    INNER JOIN dbo.PurchaseOrderItem poi3 ON poi3.PurchaseOrderItemId = sl.StockLevelId
    WHERE sl.StockLevelId = @LocationId;
    EXEC dbo.usp_Audit_Write @EntityName = 'spSklad_StockLevel_Delete', @EntityId = @LocationId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.spSklad_Warehouse_Import
    @PurchaseOrderId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    UPDATE dbo.PurchaseOrder SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE PurchaseOrderId = @PurchaseOrderId;
    INSERT INTO dbo.Warehouse (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'spSklad_Warehouse_Import', @EntityId = @PurchaseOrderId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_User_CheckPermission @PurchaseOrderId = @PurchaseOrderId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.spSklad_Warehouse_Cancel
    @InventoryCountItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT ici.*, p.ProductId AS ProductKey
    FROM dbo.InventoryCountItem AS ici WITH (NOLOCK)
    JOIN dbo.Product p ON p.ProductId = ici.ProductId
    WHERE ici.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @InventoryCountItemId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @InventoryCountItemId;
    SELECT * FROM dbo.tvf_StockByProduct(@InventoryCountItemId);
    DELETE FROM dbo.Orders WHERE OrderId = @InventoryCountItemId AND Status = 0;
    UPDATE sl SET sl.ModifiedAt = GETDATE()
    FROM dbo.StockLevel sl
    INNER JOIN dbo.InventoryCountItem ici2 ON ici2.InventoryCountItemId = sl.StockLevelId
    WHERE sl.StockLevelId = @InventoryCountItemId;
    UPDATE dbo.Warehouse SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE WarehouseId = @InventoryCountItemId;
    EXEC dbo.usp_Audit_Write @EntityName = 'spSklad_Warehouse_Cancel', @EntityId = @InventoryCountItemId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Counter_Next @InventoryCountItemId = @InventoryCountItemId, @UserId = @UserId;
    EXEC dbo.spSklad_Warehouse_GetByCode @InventoryCountItemId = @InventoryCountItemId, @UserId = @UserId;
    EXEC dbo.spSklad_StockLevel_GetByCode @InventoryCountItemId = @InventoryCountItemId, @UserId = @UserId;
    EXEC dbo.usp_Order_OrderNote_SetStatus @InventoryCountItemId = @InventoryCountItemId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.spSklad_StockLevel_Overview
    @OrderId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @OrderId;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @OrderId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_StockAvailable WHERE Id = @OrderId;
    SET @val = dbo.fn_StockValue(@OrderId);
    EXEC dbo.usp_Counter_Next @OrderId = @OrderId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.spSklad_Warehouse_Process
    @LocationId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Location WHERE LocationId = @LocationId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @LocationId;
    MERGE dbo.PurchaseOrder AS tgt
    USING (SELECT @LocationId AS PurchaseOrderId) AS src ON tgt.PurchaseOrderId = src.PurchaseOrderId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    MERGE dbo.StockLevel AS tgt
    USING (SELECT @LocationId AS StockLevelId) AS src ON tgt.StockLevelId = src.StockLevelId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    UPDATE dbo.StockReservation SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE StockReservationId = @LocationId;
    EXEC dbo.usp_Counter_Next @LocationId = @LocationId, @UserId = @UserId;
    EXEC @rc = dbo.spSklad_Location_Update @LocationId = @LocationId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.spSklad_Warehouse_Import @LocationId = @LocationId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Po_Supplier_Recalc @LocationId = @LocationId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.spSklad_Warehouse_SetStatus
    @InventoryCountItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @InventoryCountItemId;
    SELECT @cnt = COUNT(*) FROM dbo.PurchaseOrderItem WHERE PurchaseOrderItemId = @InventoryCountItemId;
    SET @val = dbo.fn_IsWorkingDay(@InventoryCountItemId);
    UPDATE dbo.InventoryCountItem SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE InventoryCountItemId = @InventoryCountItemId;
    MERGE dbo.Warehouse AS tgt
    USING (SELECT @InventoryCountItemId AS WarehouseId) AS src ON tgt.WarehouseId = src.WarehouseId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'SELECT TOP (500) * FROM dbo.StockReservation WHERE 1 = 1';
    IF @Status IS NOT NULL SET @sql += N' AND Status = @s';
    EXEC sp_executesql @sql, N'@s TINYINT', @s = @Status;
    EXEC dbo.usp_Audit_Write @EntityName = 'spSklad_Warehouse_SetStatus', @EntityId = @InventoryCountItemId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_Error_Log @InventoryCountItemId = @InventoryCountItemId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.spSklad_Location_Get @InventoryCountItemId = @InventoryCountItemId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.spSklad_Warehouse_Update
    @OrderItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_StockAvailable WHERE Id = @OrderItemId;
    SET @val = dbo.fn_SplitString(@OrderItemId);
    UPDATE dbo.Orders SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderId = @OrderItemId;
    UPDATE dbo.Warehouse SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE WarehouseId = @OrderItemId;
    EXEC dbo.usp_Audit_Write @EntityName = 'spSklad_Warehouse_Update', @EntityId = @OrderItemId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.spSklad_StockMovement_Update
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
    SELECT @cnt = COUNT(*) FROM dbo.vw_StockMovementLast30 WHERE Id = @ProductId;
    SET @val = dbo.fn_ProductAvailableQty(@ProductId);
    UPDATE dbo.StockMovement SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE StockMovementId = @ProductId;
    EXEC dbo.spSklad_StockLevel_List @ProductId = @ProductId, @UserId = @UserId;
END
GO

CREATE PROC dbo.spSklad_Location_Get
    @InventoryCountId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.InventoryCount WHERE InventoryCountId = @InventoryCountId;
    SELECT @cnt = COUNT(*) FROM dbo.Location WHERE LocationId = @InventoryCountId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @InventoryCountId;
END
GO

CREATE PROCEDURE dbo.spSklad_Warehouse_Save
    @WarehouseId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    UPDATE dbo.Warehouse SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE WarehouseId = @WarehouseId;
    EXEC dbo.usp_Audit_Write @EntityName = 'spSklad_Warehouse_Save', @EntityId = @WarehouseId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.spSklad_InventoryCount_Nightly
    @InventoryCountId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'spSklad_InventoryCount_Nightly';
    SELECT @cnt = COUNT(*) FROM dbo.InventoryCount WHERE InventoryCountId = @InventoryCountId;
    INSERT INTO #work (Id, Val)
    SELECT p.ProductId, 0 FROM dbo.Product p WHERE p.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    UPDATE ici SET ici.ModifiedAt = GETDATE()
    FROM dbo.InventoryCountItem ici
    INNER JOIN dbo.InventoryCount ic2 ON ic2.InventoryCountId = ici.InventoryCountItemId
    WHERE ici.InventoryCountItemId = @InventoryCountId;
    INSERT INTO dbo.Location (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE dbo.Product SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ProductId = @InventoryCountId;
    EXEC dbo.usp_Audit_Write @EntityName = 'spSklad_InventoryCount_Nightly', @EntityId = @InventoryCountId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @InventoryCountId = @InventoryCountId, @UserId = @UserId;
    EXEC dbo.spSklad_StockLevel_Overview @InventoryCountId = @InventoryCountId, @UserId = @UserId;
    EXEC dbo.spSklad_Warehouse_Save @InventoryCountId = @InventoryCountId, @UserId = @UserId;
    EXEC dbo.spSklad_StockLevel_GetByCode @InventoryCountId = @InventoryCountId, @UserId = @UserId;
    EXEC dbo.usp_Order_Cart_GetByCode @InventoryCountId = @InventoryCountId, @UserId = @UserId;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.spSklad_InventoryCount_Cancel
    @InventoryCountItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.InventoryCountItem WHERE InventoryCountItemId = @InventoryCountItemId;
    SELECT oi.*, o.OrderId AS OrdersKey
    FROM dbo.OrderItem AS oi WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = oi.OrderId
    WHERE oi.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @InventoryCountItemId;
    SELECT @cnt = COUNT(*) FROM dbo.StockMovement WHERE StockMovementId = @InventoryCountItemId;
    SET @val = dbo.fn_IsWorkingDay(@InventoryCountItemId);
    DELETE FROM dbo.StockLevel WHERE StockLevelId = @InventoryCountItemId AND Status = 0;
    INSERT INTO dbo.StockReservation (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC @rc = dbo.spSklad_StockLevel_Update @InventoryCountItemId = @InventoryCountItemId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.spSklad_Location_Get @InventoryCountItemId = @InventoryCountItemId, @UserId = @UserId;
    EXEC dbo.usp_Order_Cart_List @InventoryCountItemId = @InventoryCountItemId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.spSklad_Warehouse_GetByCode
    @OrderItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.PurchaseOrderItem WHERE PurchaseOrderItemId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.Warehouse WHERE WarehouseId = @OrderItemId;
END
GO
