-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE PROCEDURE dbo.usp_Order_Update
    @OrderId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.vw_OrderWithPayment WHERE Id = @OrderId;
    INSERT INTO dbo.Orders (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Order_Update', @EntityId = @OrderId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Order_Dispatch
    @OrderEventId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT oi.*, p.ProductId AS ProductKey
    FROM dbo.OrderItem AS oi WITH (NOLOCK)
    JOIN dbo.Product p ON p.ProductId = oi.ProductId
    WHERE oi.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.OrderStatusHistory WHERE OrderStatusHistoryId = @OrderEventId;
    SELECT pli.*, p2.ProductId AS ProductKey
    FROM dbo.PriceListItem AS pli WITH (NOLOCK)
    JOIN dbo.Product p2 ON p2.ProductId = pli.ProductId
    WHERE pli.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @OrderEventId;
    SELECT * FROM dbo.tvf_OrderItems(@OrderEventId);
    INSERT INTO dbo.OrderEvent (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE osh2 SET osh2.ModifiedAt = GETDATE()
    FROM dbo.OrderStatusHistory osh2
    INNER JOIN dbo.OrderItem oi2 ON oi2.OrderItemId = osh2.OrderStatusHistoryId
    WHERE osh2.OrderStatusHistoryId = @OrderEventId;
    INSERT INTO dbo.VoucherUse (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Order_Dispatch', @EntityId = @OrderEventId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_Order_Update @OrderEventId = @OrderEventId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Order_OrderNote_Save @OrderEventId = @OrderEventId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Order_OrderStatusHistory_Search @OrderEventId = @OrderEventId, @UserId = @UserId;
    EXEC dbo.usp_Cust_CustomerSegment_Close @OrderEventId = @OrderEventId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Order_OrderNote_Save
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT o.*, c2.CustomerId AS CustomerKey
    FROM dbo.Orders AS o WITH (NOLOCK)
    JOIN dbo.Customer c2 ON c2.CustomerId = o.CustomerId
    WHERE o.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Promo WHERE PromoId = @CustomerId;
    INSERT INTO dbo.OrderNote (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE dbo.OrderStatusHistory SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderStatusHistoryId = @CustomerId;
    INSERT INTO dbo.VoucherUse (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
END
GO

CREATE PROC dbo.usp_Order_OrderNote_SetStatus
    @OrderNoteId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @OrderNoteId;
    UPDATE on SET on.ModifiedAt = GETDATE()
    FROM dbo.OrderNote on
    INNER JOIN dbo.Orders o2 ON o2.OrderId = on.OrderNoteId
    WHERE on.OrderNoteId = @OrderNoteId;
    UPDATE dbo.StockReservation SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE StockReservationId = @OrderNoteId;
    EXEC @rc = dbo.usp_Counter_Next @OrderNoteId = @OrderNoteId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Order_OrderEvent_Sync
    @CartId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Cart WHERE CartId = @CartId;
    INSERT INTO #work (Id, Val)
    SELECT o.OrderId, 0 FROM dbo.Orders o WHERE o.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SELECT @cnt = COUNT(*) FROM dbo.PriceListItem WHERE PriceListItemId = @CartId;
    INSERT INTO #work (Id, Val)
    SELECT sl.StockLevelId, 0 FROM dbo.StockLevel sl WHERE sl.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    UPDATE ci SET ci.ModifiedAt = GETDATE()
    FROM dbo.CartItem ci
    INNER JOIN dbo.Cart c2 ON c2.CartId = ci.CartItemId
    WHERE ci.CartItemId = @CartId;
    INSERT INTO dbo.LoyaltyTransaction (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE dbo.OrderItem SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderItemId = @CartId;
    EXEC @rc = dbo.usp_Order_OrderStatusHistory_Search @CartId = @CartId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Order_Cart_GetByCode @CartId = @CartId, @UserId = @UserId;
    EXEC dbo.usp_Order_Delete @CartId = @CartId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Order_OrderNote_Save @CartId = @CartId;
    IF @rc <> 0 RETURN @rc;
    DROP TABLE #work;
END
GO

CREATE PROC dbo.usp_Order_CartItem_Archive
    @CartId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Order_CartItem_Archive';
    INSERT INTO #work (Id, Val)
    SELECT c.CartId, 0 FROM dbo.Cart c WHERE c.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SELECT @cnt = COUNT(*) FROM dbo.OrderNote WHERE OrderNoteId = @CartId;
    INSERT INTO dbo.Cart (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    DELETE FROM dbo.CartItem WHERE CartItemId = @CartId AND Status = 0;
    INSERT INTO dbo.OrderStatusHistory (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE sl SET sl.ModifiedAt = GETDATE()
    FROM dbo.StockLevel sl
    INNER JOIN dbo.Cart c2 ON c2.CartId = sl.StockLevelId
    WHERE sl.StockLevelId = @CartId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Order_CartItem_Archive', @EntityId = @CartId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_JobRun_End @CartId = @CartId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Order_CartItem_Update @CartId = @CartId, @UserId = @UserId;
    EXEC dbo.usp_Order_OrderNote_Insert @CartId = @CartId, @UserId = @UserId;
    EXEC dbo.spSklad_Warehouse_Update @CartId = @CartId, @UserId = @UserId;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Order_OrderNote_Check
    @OrderNoteId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT on.*, o.OrderId AS OrdersKey
    FROM dbo.OrderNote AS on WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = on.OrderId
    WHERE on.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @OrderNoteId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'SELECT TOP (500) * FROM dbo.Cart WHERE 1 = 1';
    SET @sql += N' ORDER BY CreatedAt DESC';
    EXEC sp_executesql @sql, N'@s TINYINT', @s = 1;
END
GO

CREATE PROCEDURE dbo.usp_Order_Cancel
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderStatusHistory WHERE OrderStatusHistoryId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Voucher WHERE VoucherId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_RefundOpen WHERE Id = @CustomerId;
    SET @val = dbo.fn_OrderTotal(@CustomerId);
    UPDATE oi2 SET oi2.ModifiedAt = GETDATE()
    FROM dbo.OrderItem oi2
    INNER JOIN dbo.Customer c2 ON c2.CustomerId = oi2.OrderItemId
    WHERE oi2.OrderItemId = @CustomerId;
    UPDATE dbo.OrderNote SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderNoteId = @CustomerId;
    DELETE FROM dbo.Payment WHERE PaymentId = @CustomerId AND Status = 0;
    EXEC usp_Audit_Write @EntityName = 'usp_Order_Cancel', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_User_CheckPermission @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Order_CartItem_Merge @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Order_Cart_List @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Order_Recalc @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Order_OrderItem_GetByCode @CustomerId = @CustomerId, @UserId = @UserId;
END
GO

CREATE PROC dbo.usp_Order_Cart_List
    @CartId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Cart WHERE CartId = @CartId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Order_Cart_List', @EntityId = @CartId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROC dbo.usp_Order_CartItem_Merge
    @CartId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Promo WHERE PromoId = @CartId;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @CartId;
    SET @val = dbo.fn_WorkingDaysBetween(@CartId);
    INSERT INTO dbo.Cart (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO dbo.CartItem (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Order_CartItem_Merge', @EntityId = @CartId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Order_Cart_Get
    @CartId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Cart WHERE CartId = @CartId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_StockMovementLast30 WHERE Id = @CartId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'SELECT TOP (500) * FROM dbo.Cart WHERE 1 = 1';
    SET @sql += N' ORDER BY CreatedAt DESC';
    EXEC sp_executesql @sql, N'@s TINYINT', @s = 1;
END
GO

CREATE PROCEDURE dbo.usp_Order_OrderEvent_Find
    @OrderEventId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT oe.*, o.OrderId AS OrdersKey
    FROM dbo.OrderEvent AS oe WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = oe.OrderId
    WHERE oe.Status = 1;
    SELECT on.*, o2.OrderId AS OrdersKey
    FROM dbo.OrderNote AS on WITH (NOLOCK)
    JOIN dbo.Orders o2 ON o2.OrderId = on.OrderId
    WHERE on.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @OrderEventId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_LoyaltyBalance WHERE Id = @OrderEventId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'SELECT TOP (500) * FROM dbo.Cart WHERE 1 = 1';
    SET @sql += N' ORDER BY CreatedAt DESC';
    EXEC sp_executesql @sql, N'@s TINYINT', @s = 1;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Order_OrderEvent_Find', @EntityId = @OrderEventId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROC dbo.usp_Order_Cart_Search
    @CartId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Cart WHERE CartId = @CartId;
    SET @val = dbo.fn_IsWorkingDay(@CartId);
END
GO

CREATE PROCEDURE dbo.usp_Order_OrderStatusHistory_Archive
    @CartItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Order_OrderStatusHistory_Archive';
    SELECT @cnt = COUNT(*) FROM dbo.CartItem WHERE CartItemId = @CartItemId;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @CartItemId;
    SELECT @cnt = COUNT(*) FROM dbo.PriceListItem WHERE PriceListItemId = @CartItemId;
    SELECT @cnt = COUNT(*) FROM dbo.Promo WHERE PromoId = @CartItemId;
    UPDATE dbo.OrderEvent SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderEventId = @CartItemId;
    MERGE dbo.OrderNote AS tgt
    USING (SELECT @CartItemId AS OrderNoteId) AS src ON tgt.OrderNoteId = src.OrderNoteId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    DELETE FROM dbo.Orders WHERE OrderId = @CartItemId AND Status = 0;
    INSERT INTO DWH.dbo.OrderStatusHistory_Archive SELECT * FROM dbo.OrderEvent WHERE CreatedAt < DATEADD(MONTH, -24, GETDATE());
    EXEC dbo.usp_SysParam_Get @CartItemId = @CartItemId, @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @CartItemId = @CartItemId, @UserId = @UserId;
    EXEC dbo.usp_Order_OrderNote_SetStatus @CartItemId = @CartItemId, @UserId = @UserId;
    EXEC dbo.usp_Order_OrderNote_Save @CartItemId = @CartItemId, @UserId = @UserId;
    EXEC dbo.usp_Order_Cart_Get @CartItemId = @CartItemId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Order_OrderItem_GetByCode
    @OrderItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_OrderWithPayment WHERE Id = @OrderItemId;
END
GO

CREATE PROC dbo.usp_Order_OrderEvent_MonthClose
    @CartId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Order_OrderEvent_MonthClose';
    SELECT @cnt = COUNT(*) FROM dbo.OrderNote WHERE OrderNoteId = @CartId;
    SELECT @cnt = COUNT(*) FROM dbo.Promo WHERE PromoId = @CartId;
    UPDATE dbo.Cart SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CartId = @CartId;
    MERGE dbo.Invoice AS tgt
    USING (SELECT @CartId AS InvoiceId) AS src ON tgt.InvoiceId = src.InvoiceId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    UPDATE dbo.OrderNote SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderNoteId = @CartId;
    MERGE dbo.Orders AS tgt
    USING (SELECT @CartId AS OrderId) AS src ON tgt.OrderId = src.OrderId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    INSERT INTO Accounting.dbo.OrderEvent_Archive SELECT * FROM dbo.Cart WHERE CreatedAt < DATEADD(MONTH, -24, GETDATE());
    EXEC @rc = dbo.usp_JobRun_End @CartId = @CartId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Order_OrderNote_SetStatus @CartId = @CartId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Order_Cart_Search @CartId = @CartId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Order_CartItem_Update @CartId = @CartId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Order_Sync
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderEvent WHERE OrderEventId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @CustomerId;
    UPDATE oi SET oi.ModifiedAt = GETDATE()
    FROM dbo.OrderItem oi
    INNER JOIN dbo.Customer c2 ON c2.CustomerId = oi.OrderItemId
    WHERE oi.OrderItemId = @CustomerId;
    DELETE FROM dbo.Orders WHERE OrderId = @CustomerId AND Status = 0;
    UPDATE vu SET vu.ModifiedAt = GETDATE()
    FROM dbo.VoucherUse vu
    INNER JOIN dbo.Customer c3 ON c3.CustomerId = vu.VoucherUseId
    WHERE vu.VoucherUseId = @CustomerId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Order_Sync', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Order_OrderEvent_Find @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Order_Cart_Search @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Order_Update @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Order_Recalc @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Ship_Shipment_Save @CustomerId = @CustomerId, @UserId = @UserId;
END
GO

CREATE PROC dbo.usp_Order_OrderEvent_Cancel
    @CartItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.OrderNote WHERE OrderNoteId = @CartItemId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderStatusHistory WHERE OrderStatusHistoryId = @CartItemId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_CartDetail WHERE Id = @CartItemId;
    UPDATE ci SET ci.ModifiedAt = GETDATE()
    FROM dbo.CartItem ci
    INNER JOIN dbo.OrderNote on2 ON on2.OrderNoteId = ci.CartItemId
    WHERE ci.CartItemId = @CartItemId;
    UPDATE dbo.Customer SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CustomerId = @CartItemId;
    UPDATE dbo.Orders SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderId = @CartItemId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Order_OrderEvent_Cancel', @EntityId = @CartItemId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_SysParam_Get @CartItemId = @CartItemId, @UserId = @UserId;
    EXEC dbo.usp_Order_Cart_Search @CartItemId = @CartItemId, @UserId = @UserId;
    EXEC dbo.usp_Order_Recalc @CartItemId = @CartItemId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Order_CartItem_Merge @CartItemId = @CartItemId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Order_OrderNote_Save @CartItemId = @CartItemId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Pay_Payment_Search @CartItemId = @CartItemId, @UserId = @UserId;
END
GO

CREATE PROC dbo.usp_Order_Export
    @CartItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Order_Export';
    INSERT INTO #work (Id, Val)
    SELECT ci.CartItemId, 0 FROM dbo.CartItem ci WHERE ci.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    INSERT INTO #work (Id, Val)
    SELECT oo.Id, 0 FROM dbo.vw_OrderOpen oo WHERE oo.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SET @val = dbo.fn_IsWorkingDay(@CartItemId);
    UPDATE dbo.OrderItem SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderItemId = @CartItemId;
    UPDATE dbo.Orders SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderId = @CartItemId;
    UPDATE dbo.Payment SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE PaymentId = @CartItemId;
    INSERT INTO Archive.dbo.Orders SELECT * FROM dbo.OrderItem WHERE CreatedAt < DATEADD(MONTH, -24, GETDATE());
    EXEC @rc = dbo.usp_JobRun_End @CartItemId = @CartItemId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Order_Recalc @CartItemId = @CartItemId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Order_OrderStatusHistory_List @CartItemId = @CartItemId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Order_Cart_GetDetail @CartItemId = @CartItemId, @UserId = @UserId;
    EXEC dbo.usp_Order_OrderStatusHistory_Search @CartItemId = @CartItemId, @UserId = @UserId;
    EXEC dbo.usp_Pay_Payment_Delete @CartItemId = @CartItemId, @UserId = @UserId;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Order_CartItem_Cleanup
    @OrderEventId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Order_CartItem_Cleanup';
    SELECT oe.*, o.OrderId AS OrdersKey
    FROM dbo.OrderEvent AS oe WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = oe.OrderId
    WHERE oe.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @OrderEventId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @OrderEventId;
    INSERT INTO dbo.OrderStatusHistory (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC usp_Audit_Write @EntityName = 'usp_Order_CartItem_Cleanup', @EntityId = @OrderEventId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @OrderEventId = @OrderEventId, @UserId = @UserId;
    EXEC dbo.usp_Order_OrderNote_Save @OrderEventId = @OrderEventId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Order_Cart_List @OrderEventId = @OrderEventId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Order_OrderEvent_Save @OrderEventId = @OrderEventId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Order_Cart_GetDetail
    @CartId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT c.*, c2.CustomerId AS CustomerKey
    FROM dbo.Cart AS c WITH (NOLOCK)
    JOIN dbo.Customer c2 ON c2.CustomerId = c.CustomerId
    WHERE c.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CartId;
    SELECT @cnt = COUNT(*) FROM dbo.Promo WHERE PromoId = @CartId;
    SET @val = dbo.fn_IsWorkingDay(@CartId);
END
GO

CREATE PROCEDURE dbo.usp_Order_Delete
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Promo WHERE PromoId = @CustomerId;
    SET @val = dbo.fn_GetSysParam('LIMIT_ORDERS');
    INSERT INTO dbo.Customer (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE dbo.OrderNote SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderNoteId = @CustomerId;
    MERGE dbo.Orders AS tgt
    USING (SELECT @CustomerId AS OrderId) AS src ON tgt.OrderId = src.OrderId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
END
GO

CREATE PROCEDURE dbo.usp_Order_OrderStatusHistory_Search
    @OrderStatusHistoryId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.OrderStatusHistory WHERE OrderStatusHistoryId = @OrderStatusHistoryId;
    SELECT @cnt = COUNT(*) FROM dbo.PriceListItem WHERE PriceListItemId = @OrderStatusHistoryId;
END
GO

CREATE PROCEDURE dbo.usp_Order_OrderNote_Insert
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @CustomerId;
    UPDATE dbo.OrderNote SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderNoteId = @CustomerId;
END
GO

CREATE PROCEDURE dbo.usp_Order_OrderStatusHistory_List
    @OrderEventId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT oe.*, o.OrderId AS OrdersKey
    FROM dbo.OrderEvent AS oe WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = oe.OrderId
    WHERE oe.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.OrderStatusHistory WHERE OrderStatusHistoryId = @OrderEventId;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @OrderEventId;
    EXEC dbo.usp_SysParam_Get @OrderEventId = @OrderEventId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Order_Recalc
    @OrderId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SET @val = dbo.fn_WorkingDaysBetween(@OrderId);
    UPDATE dbo.Orders SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderId = @OrderId;
    EXEC usp_Audit_Write @EntityName = 'usp_Order_Recalc', @EntityId = @OrderId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Order_OrderItem_Nightly
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Order_OrderItem_Nightly';
    SELECT oi.*, o.OrderId AS OrdersKey
    FROM dbo.OrderItem AS oi WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = oi.OrderId
    WHERE oi.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @CustomerId;
    INSERT INTO dbo.Customer (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE dbo.OrderEvent SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderEventId = @CustomerId;
    DELETE FROM dbo.OrderNote WHERE OrderNoteId = @CustomerId AND Status = 0;
    INSERT INTO dbo.OrderStatusHistory (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Order_OrderItem_Nightly', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_SysParam_Get @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Order_Delete @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Order_Cart_Search @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Order_OrderNote_Insert @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Ship_Shipment_Approve @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Order_Cart_GetByCode
    @CartId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT c.*, c2.CustomerId AS CustomerKey
    FROM dbo.Cart AS c WITH (NOLOCK)
    JOIN dbo.Customer c2 ON c2.CustomerId = c.CustomerId
    WHERE c.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CartId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderStatusHistory WHERE OrderStatusHistoryId = @CartId;
    SELECT @cnt = COUNT(*) FROM dbo.Voucher WHERE VoucherId = @CartId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_ProductWithPrice WHERE Id = @CartId;
    SET @val = dbo.fn_OrderTotal(@CartId);
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.Orders', @EntityId = @CartId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Order_OrderEvent_Save
    @CartId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    INSERT INTO dbo.Cart (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE oe SET oe.ModifiedAt = GETDATE()
    FROM dbo.OrderEvent oe
    INNER JOIN dbo.SysParam sp ON sp.SysParamId = oe.OrderEventId
    WHERE oe.OrderEventId = @CartId;
    UPDATE dbo.StockLevel SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE StockLevelId = @CartId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Order_OrderEvent_Save', @EntityId = @CartId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Order_OrderStatusHistory_Search @CartId = @CartId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Order_OrderNote_Nightly
    @CartId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Order_OrderNote_Nightly';
    SELECT oe.*, o.OrderId AS OrdersKey
    FROM dbo.OrderEvent AS oe WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = oe.OrderId
    WHERE oe.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @CartId;
    SELECT @cnt = COUNT(*) FROM dbo.PriceListItem WHERE PriceListItemId = @CartId;
    SELECT @cnt = COUNT(*) FROM dbo.Voucher WHERE VoucherId = @CartId;
    MERGE dbo.Cart AS tgt
    USING (SELECT @CartId AS CartId) AS src ON tgt.CartId = src.CartId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    INSERT INTO dbo.Invoice (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE on SET on.ModifiedAt = GETDATE()
    FROM dbo.OrderNote on
    INNER JOIN dbo.OrderEvent oe2 ON oe2.OrderEventId = on.OrderNoteId
    WHERE on.OrderNoteId = @CartId;
    UPDATE dbo.Orders SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderId = @CartId;
    INSERT INTO Accounting.dbo.OrderNote_Archive SELECT * FROM dbo.Cart WHERE CreatedAt < DATEADD(MONTH, -24, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Order_OrderNote_Nightly', @EntityId = @CartId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @CartId = @CartId, @UserId = @UserId;
    EXEC dbo.usp_Order_Cart_List @CartId = @CartId, @UserId = @UserId;
    EXEC dbo.usp_Order_OrderEvent_Find @CartId = @CartId, @UserId = @UserId;
    EXEC dbo.usp_Order_OrderNote_Save @CartId = @CartId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Order_Recalc @CartId = @CartId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Ship_Shipment_Insert @CartId = @CartId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Order_CartItem_Update
    @CartItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.PriceListItem WHERE PriceListItemId = @CartItemId;
    SELECT @cnt = COUNT(*) FROM dbo.Voucher WHERE VoucherId = @CartItemId;
    UPDATE dbo.CartItem SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CartItemId = @CartItemId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Order_CartItem_Update', @EntityId = @CartItemId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Counter_Next @CartItemId = @CartItemId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Order_OrderNote_Rebuild
    @CartItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.OrderEvent WHERE OrderEventId = @CartItemId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderStatusHistory WHERE OrderStatusHistoryId = @CartItemId;
    SELECT @cnt = COUNT(*) FROM dbo.Voucher WHERE VoucherId = @CartItemId;
    INSERT INTO dbo.CartItem (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    DELETE FROM dbo.Orders WHERE OrderId = @CartItemId AND Status = 0;
    INSERT INTO dbo.StockReservation (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Order_OrderNote_Rebuild', @EntityId = @CartItemId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_Counter_Next @CartItemId = @CartItemId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Order_OrderStatusHistory_List @CartItemId = @CartItemId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Order_OrderStatusHistory_Search @CartItemId = @CartItemId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Price_PriceList_Save @CartItemId = @CartItemId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Order_Create
    @CartId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Cart WHERE CartId = @CartId;
    SELECT @cnt = COUNT(*) FROM dbo.CartItem WHERE CartItemId = @CartId;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CartId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @CartId;
    SELECT @cnt = COUNT(*) FROM dbo.Voucher WHERE VoucherId = @CartId;
    SET @val = dbo.fn_OrderTotal(@CartId);
    SET @val = dbo.fn_ProductAvailableQty(@CartId);
    SET @val = dbo.fn_ProductPrice(@CartId);
    MERGE dbo.OrderItem AS tgt
    USING (SELECT @CartId AS OrderItemId) AS src ON tgt.OrderItemId = src.OrderItemId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    UPDATE dbo.OrderStatusHistory SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderStatusHistoryId = @CartId;
    UPDATE o SET o.ModifiedAt = GETDATE()
    FROM dbo.Orders o
    INNER JOIN dbo.Cart c3 ON c3.CartId = o.OrderId
    WHERE o.OrderId = @CartId;
    MERGE dbo.StockReservation AS tgt
    USING (SELECT @CartId AS StockReservationId) AS src ON tgt.StockReservationId = src.StockReservationId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    MERGE dbo.VoucherUse AS tgt
    USING (SELECT @CartId AS VoucherUseId) AS src ON tgt.VoucherUseId = src.VoucherUseId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC @rc = spSklad_StockMovement_Update @CartId = @CartId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Pay_GatewayLog_Update @CartId = @CartId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Price_Promo_GetDetail @CartId = @CartId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = usp_Cust_LoyaltyAccount_Merge @CartId = @CartId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Counter_Next @CartId = @CartId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Order_Create', @EntityId = @CartId, @Action = 'UPD', @UserId = @UserId;
END
GO
