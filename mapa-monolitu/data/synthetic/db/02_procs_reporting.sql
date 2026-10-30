-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE PROCEDURE dbo.usp_Rpt_RptStockSnapshot_MonthClose
    @ExportQueueId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Rpt_RptStockSnapshot_MonthClose';
    INSERT INTO #work (Id, Val)
    SELECT eq.ExportQueueId, 0 FROM dbo.ExportQueue eq WHERE eq.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    INSERT INTO #work (Id, Val)
    SELECT rss.RptStockSnapshotId, 0 FROM dbo.RptStockSnapshot rss WHERE rss.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SELECT @cnt = COUNT(*) FROM dbo.vw_RptMargin WHERE Id = @ExportQueueId;
    UPDATE dbo.RptDailySales SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE RptDailySalesId = @ExportQueueId;
    INSERT INTO Archive.dbo.RptStockSnapshot SELECT * FROM dbo.RptDailySales WHERE CreatedAt < DATEADD(MONTH, -24, GETDATE());
    EXEC dbo.usp_JobRun_End @ExportQueueId = @ExportQueueId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptCustomerKpi_GetByCode @ExportQueueId = @ExportQueueId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptDailySales_List @ExportQueueId = @ExportQueueId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptDailySales_GetByCode @ExportQueueId = @ExportQueueId, @UserId = @UserId;
    DROP TABLE #work;
END
GO

CREATE PROC dbo.usp_Rpt_Sales_2024_Cleanup
    @RptDailySalesId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Rpt_Sales_2024_Cleanup';
    SELECT @cnt = COUNT(*) FROM dbo.RptDailySales WHERE RptDailySalesId = @RptDailySalesId;
    SELECT @cnt = COUNT(*) FROM dbo.Sales_2023 WHERE Sales_2023Id = @RptDailySalesId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_RptStock WHERE Id = @RptDailySalesId;
    SET @val = dbo.fn_SplitString(@RptDailySalesId);
    MERGE dbo.Sales_2024 AS tgt
    USING (SELECT @RptDailySalesId AS Sales_2024Id) AS src ON tgt.Sales_2024Id = src.Sales_2024Id
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC @rc = dbo.usp_JobRun_End @RptDailySalesId = @RptDailySalesId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Rpt_RptCustomerKpi_GetByCode @RptDailySalesId = @RptDailySalesId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptDailySales_List @RptDailySalesId = @RptDailySalesId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptDailySales_GetByCode @RptDailySalesId = @RptDailySalesId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Export_RptDailySales
    @InvoiceId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Invoice WHERE InvoiceId = @InvoiceId;
    SELECT oi.*, o.OrderId AS OrdersKey
    FROM dbo.OrderItem AS oi WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = oi.OrderId
    WHERE oi.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @InvoiceId;
    SELECT @cnt = COUNT(*) FROM dbo.RptDailySales WHERE RptDailySalesId = @InvoiceId;
    SELECT @cnt = COUNT(*) FROM dbo.Shipment WHERE ShipmentId = @InvoiceId;
    INSERT INTO dbo.RptDailySales (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Rpt_Export_RptDailySales', @EntityId = @InvoiceId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Sales_2026_MonthClose
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Rpt_Sales_2026_MonthClose';
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    INSERT INTO #work (Id, Val)
    SELECT s.Sales_2023Id, 0 FROM dbo.Sales_2023 s WHERE s.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SELECT @cnt = COUNT(*) FROM dbo.vw_RptSalesAll WHERE Id = @CustomerId;
    UPDATE dbo.ExportQueue SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ExportQueueId = @CustomerId;
    INSERT INTO dbo.RptDailySales (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC @rc = dbo.usp_JobRun_End @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Rpt_RptDailySales_GetByCode @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptDailySales_List @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptCustomerKpi_GetByCode @CustomerId = @CustomerId, @UserId = @UserId;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Kpi_RptDailySales
    @PaymentId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Payment WHERE PaymentId = @PaymentId;
    SELECT @cnt = COUNT(*) FROM dbo.RptDailySales WHERE RptDailySalesId = @PaymentId;
    SELECT @cnt = COUNT(*) FROM dbo.Sales_2025 WHERE Sales_2025Id = @PaymentId;
    SELECT @cnt = COUNT(*) FROM dbo.Shipment WHERE ShipmentId = @PaymentId;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @PaymentId;
    INSERT INTO dbo.RptStockSnapshot (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC usp_Audit_Write @EntityName = 'usp_Rpt_Kpi_RptDailySales', @EntityId = @PaymentId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Customers_RptDailySales
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT oi.*, o.OrderId AS OrdersKey
    FROM dbo.OrderItem AS oi WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = oi.OrderId
    WHERE oi.Status = 1;
    SELECT o2.*, c2.CustomerId AS CustomerKey
    FROM dbo.Orders AS o2 WITH (NOLOCK)
    JOIN dbo.Customer c2 ON c2.CustomerId = o2.CustomerId
    WHERE o2.Status = 1;
    SELECT s.*, o3.OrderId AS OrdersKey
    FROM dbo.Sales_2023 AS s WITH (NOLOCK)
    JOIN dbo.Orders o3 ON o3.OrderId = s.OrderId
    WHERE s.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.vw_RptSalesByDay WHERE Id = @CustomerId;
    UPDATE rds SET rds.ModifiedAt = GETDATE()
    FROM dbo.RptDailySales rds
    INNER JOIN dbo.Customer c3 ON c3.CustomerId = rds.RptDailySalesId
    WHERE rds.RptDailySalesId = @CustomerId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'SELECT TOP (500) * FROM dbo.Sales_2025 WHERE 1 = 1';
    SET @sql += N' ORDER BY CreatedAt DESC';
    EXEC sp_executesql @sql, N'@s TINYINT', @s = 1;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Margin_Sales_2024
    @PaymentId INT = NULL,
    @UserId INT = NULL,
    @Year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Payment WHERE PaymentId = @PaymentId;
    SELECT @cnt = COUNT(*) FROM dbo.RptDailySales WHERE RptDailySalesId = @PaymentId;
    SELECT @cnt = COUNT(*) FROM dbo.Sales_2024 WHERE Sales_2024Id = @PaymentId;
    SELECT @cnt = COUNT(*) FROM dbo.Shipment WHERE ShipmentId = @PaymentId;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @PaymentId;
    DECLARE @sql NVARCHAR(MAX);
    SET @Year = ISNULL(@Year, YEAR(GETDATE()));
    SET @sql = N'INSERT INTO dbo.Sales_' + CAST(@Year AS NVARCHAR(4)) + N' (OrderId, Amount, Status, CreatedAt) '
           + N'SELECT o.OrderId, o.TotalAmount, 1, GETDATE() FROM dbo.Orders o WHERE YEAR(o.CreatedAt) = @y';
    EXEC sp_executesql @sql, N'@y INT', @y = @Year;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Export_Sales_2026
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT oi.*, p.ProductId AS ProductKey
    FROM dbo.OrderItem AS oi WITH (NOLOCK)
    JOIN dbo.Product p ON p.ProductId = oi.ProductId
    WHERE oi.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Payment WHERE PaymentId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Sales_2026 WHERE Sales_2026Id = @CustomerId;
    DELETE FROM dbo.RptDailySales WHERE RptDailySalesId = @CustomerId AND Status = 0;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Rpt_Export_Sales_2026', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_RptDailySales_List
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.OldOrders, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.RptDailySales WHERE RptDailySalesId = @CustomerId;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Weekly_RptDailySales
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT oi.*, o.OrderId AS OrdersKey
    FROM dbo.OrderItem AS oi WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = oi.OrderId
    WHERE oi.Status = 1;
    SELECT o2.*, c2.CustomerId AS CustomerKey
    FROM dbo.Orders AS o2 WITH (NOLOCK)
    JOIN dbo.Customer c2 ON c2.CustomerId = o2.CustomerId
    WHERE o2.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Payment WHERE PaymentId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.RptDailySales WHERE RptDailySalesId = @CustomerId;
    UPDATE dbo.RptStockSnapshot SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE RptStockSnapshotId = @CustomerId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Rpt_Weekly_RptDailySales', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Kpi_ExportQueue
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.ExportQueue WHERE ExportQueueId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Payment WHERE PaymentId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Shipment WHERE ShipmentId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @CustomerId;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Stock_RptDailySales
    @OrderItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.TmpRecalc, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT oi.*, p.ProductId AS ProductKey
    FROM dbo.OrderItem AS oi WITH (NOLOCK)
    JOIN dbo.Product p ON p.ProductId = oi.ProductId
    WHERE oi.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Payment WHERE PaymentId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.RptDailySales WHERE RptDailySalesId = @OrderItemId;
    INSERT INTO dbo.RptCustomerKpi (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Rpt_Stock_RptDailySales', @EntityId = @OrderItemId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_RptStockSnapshot_Cleanup
    @RptStockSnapshotId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Rpt_RptStockSnapshot_Cleanup';
    INSERT INTO #work (Id, Val)
    SELECT s.Sales_2023Id, 0 FROM dbo.Sales_2023 s WHERE s.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    INSERT INTO #work (Id, Val)
    SELECT s2.Sales_2026Id, 0 FROM dbo.Sales_2026 s2 WHERE s2.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    INSERT INTO #work (Id, Val)
    SELECT sl.StockLevelId, 0 FROM dbo.StockLevel sl WHERE sl.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    DELETE FROM dbo.RptStockSnapshot WHERE RptStockSnapshotId = @RptStockSnapshotId AND Status = 0;
    INSERT INTO dbo.Sales_2024 (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Rpt_RptStockSnapshot_Cleanup', @EntityId = @RptStockSnapshotId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @RptStockSnapshotId = @RptStockSnapshotId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptDailySales_List @RptStockSnapshotId = @RptStockSnapshotId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptCustomerKpi_GetByCode @RptStockSnapshotId = @RptStockSnapshotId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptDailySales_GetByCode @RptStockSnapshotId = @RptStockSnapshotId, @UserId = @UserId;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_RptDailySales_Export
    @ExportQueueId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Rpt_RptDailySales_Export';
    SELECT @cnt = COUNT(*) FROM dbo.ExportQueue WHERE ExportQueueId = @ExportQueueId;
    INSERT INTO #work (Id, Val)
    SELECT s.Sales_2024Id, 0 FROM dbo.Sales_2024 s WHERE s.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SET @val = dbo.fn_UserName(@ExportQueueId);
    UPDATE rck SET rck.ModifiedAt = GETDATE()
    FROM dbo.RptCustomerKpi rck
    INNER JOIN dbo.ExportQueue eq2 ON eq2.ExportQueueId = rck.RptCustomerKpiId
    WHERE rck.RptCustomerKpiId = @ExportQueueId;
    INSERT INTO dbo.Sales_2026 (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO Accounting.dbo.RptDailySales SELECT * FROM dbo.RptCustomerKpi WHERE CreatedAt < DATEADD(MONTH, -24, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Rpt_RptDailySales_Export', @EntityId = @ExportQueueId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @ExportQueueId = @ExportQueueId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptCustomerKpi_GetByCode @ExportQueueId = @ExportQueueId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptDailySales_GetByCode @ExportQueueId = @ExportQueueId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptDailySales_List @ExportQueueId = @ExportQueueId, @UserId = @UserId;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Margin_RptDailySales
    @InvoiceId INT = NULL,
    @UserId INT = NULL,
    @Year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Invoice WHERE InvoiceId = @InvoiceId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @InvoiceId;
    SELECT @cnt = COUNT(*) FROM dbo.Shipment WHERE ShipmentId = @InvoiceId;
    INSERT INTO dbo.RptDailySales (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    DECLARE @sql NVARCHAR(MAX);
    SET @Year = ISNULL(@Year, YEAR(GETDATE()));
    SET @sql = N'INSERT INTO dbo.Sales_' + CAST(@Year AS NVARCHAR(4)) + N' (OrderId, Amount, Status, CreatedAt) '
           + N'SELECT o.OrderId, o.TotalAmount, 1, GETDATE() FROM dbo.Orders o WHERE YEAR(o.CreatedAt) = @y';
    EXEC sp_executesql @sql, N'@y INT', @y = @Year;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_RptDailySales_MonthClose
    @ExportQueueId INT = NULL,
    @UserId INT = NULL,
    @Year INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Rpt_RptDailySales_MonthClose';
    SELECT @cnt = COUNT(*) FROM dbo.RptDailySales WHERE RptDailySalesId = @ExportQueueId;
    SELECT @cnt = COUNT(*) FROM dbo.Sales_2024 WHERE Sales_2024Id = @ExportQueueId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_RptSalesAll WHERE Id = @ExportQueueId;
    MERGE dbo.ExportQueue AS tgt
    USING (SELECT @ExportQueueId AS ExportQueueId) AS src ON tgt.ExportQueueId = src.ExportQueueId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    DECLARE @sql NVARCHAR(MAX);
    SET @Year = ISNULL(@Year, YEAR(GETDATE()));
    SET @sql = N'INSERT INTO dbo.Sales_' + CAST(@Year AS NVARCHAR(4)) + N' (OrderId, Amount, Status, CreatedAt) '
           + N'SELECT o.OrderId, o.TotalAmount, 1, GETDATE() FROM dbo.Orders o WHERE YEAR(o.CreatedAt) = @y';
    EXEC sp_executesql @sql, N'@y INT', @y = @Year;
    EXEC dbo.usp_JobRun_End @ExportQueueId = @ExportQueueId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptDailySales_GetByCode @ExportQueueId = @ExportQueueId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptDailySales_List @ExportQueueId = @ExportQueueId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptCustomerKpi_GetByCode @ExportQueueId = @ExportQueueId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_RptCustomerKpi_GetByCode
    @OrderItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.RptCustomerKpi WHERE RptCustomerKpiId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.Shipment WHERE ShipmentId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_RptSalesAll WHERE Id = @OrderItemId;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_RptDailySales_GetByCode
    @OrderItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT oi.*, o.OrderId AS OrdersKey
    FROM dbo.OrderItem AS oi WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = oi.OrderId
    WHERE oi.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.RptDailySales WHERE RptDailySalesId = @OrderItemId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'SELECT TOP (500) * FROM dbo.Sales_2023 WHERE 1 = 1';
    SET @sql += N' ORDER BY CreatedAt DESC';
    EXEC sp_executesql @sql, N'@s TINYINT', @s = 1;
    EXEC dbo.usp_SysParam_Get @OrderItemId = @OrderItemId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Customers_ExportQueue
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.ExportQueue WHERE ExportQueueId = @CustomerId;
    SELECT i.*, c2.CustomerId AS CustomerKey
    FROM dbo.Invoice AS i WITH (NOLOCK)
    JOIN dbo.Customer c2 ON c2.CustomerId = i.CustomerId
    WHERE i.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Shipment WHERE ShipmentId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_RptStock WHERE Id = @CustomerId;
    INSERT INTO dbo.RptStockSnapshot (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Rpt_Customers_ExportQueue', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_RptDailySales_Cleanup
    @RptCustomerKpiId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Rpt_RptDailySales_Cleanup';
    INSERT INTO #work (Id, Val)
    SELECT rds.RptDailySalesId, 0 FROM dbo.RptDailySales rds WHERE rds.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    DELETE FROM dbo.RptCustomerKpi WHERE RptCustomerKpiId = @RptCustomerKpiId AND Status = 0;
    DELETE FROM dbo.RptStockSnapshot WHERE RptStockSnapshotId = @RptCustomerKpiId AND Status = 0;
    UPDATE s SET s.ModifiedAt = GETDATE()
    FROM dbo.Sales_2023 s
    INNER JOIN dbo.RptDailySales rds2 ON rds2.RptDailySalesId = s.Sales_2023Id
    WHERE s.Sales_2023Id = @RptCustomerKpiId;
    EXEC @rc = dbo.usp_JobRun_End @RptCustomerKpiId = @RptCustomerKpiId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Rpt_RptDailySales_GetByCode @RptCustomerKpiId = @RptCustomerKpiId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptDailySales_List @RptCustomerKpiId = @RptCustomerKpiId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptCustomerKpi_GetByCode @RptCustomerKpiId = @RptCustomerKpiId, @UserId = @UserId;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Dispatch
    @ExportQueueId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Rpt_Dispatch';
    UPDATE dbo.ExportQueue SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ExportQueueId = @ExportQueueId;
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @handler SYSNAME;
    SELECT TOP (1) @handler = HandlerProc FROM dbo.ExportQueue WHERE Status = 1;
    SET @sql = N'EXEC dbo.' + QUOTENAME(@handler) + N' @ExportQueueId = ' + CAST(ISNULL(@ExportQueueId, 0) AS NVARCHAR(20));
    EXEC (@sql);
    EXEC dbo.usp_JobRun_End @ExportQueueId = @ExportQueueId, @UserId = @UserId;
    EXEC dbo.usp_Rpt_RptCustomerKpi_GetByCode @ExportQueueId = @ExportQueueId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Rpt_RptDailySales_GetByCode @ExportQueueId = @ExportQueueId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROC dbo.usp_Rpt_Export_Email
    @ExportQueueId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ExportQueue WHERE ExportQueueId = @ExportQueueId;
    SELECT @cnt = COUNT(*) FROM dbo.PriceListItem WHERE PriceListItemId = @ExportQueueId;
    SELECT @cnt = COUNT(*) FROM dbo.SupplierProduct WHERE SupplierProductId = @ExportQueueId;
    UPDATE eq2 SET eq2.ModifiedAt = GETDATE()
    FROM dbo.ExportQueue eq2
    INNER JOIN dbo.ExportQueue eq3 ON eq3.ExportQueueId = eq2.ExportQueueId
    WHERE eq2.ExportQueueId = @ExportQueueId;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Export_Heureka
    @ExportQueueId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ExportQueue WHERE ExportQueueId = @ExportQueueId;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @ExportQueueId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @ExportQueueId;
    MERGE dbo.ExportQueue AS tgt
    USING (SELECT @ExportQueueId AS ExportQueueId) AS src ON tgt.ExportQueueId = src.ExportQueueId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Export_Accounting
    @ExportQueueId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ExportQueue WHERE ExportQueueId = @ExportQueueId;
    SELECT i.*, o.OrderId AS OrdersKey
    FROM dbo.Invoice AS i WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = i.OrderId
    WHERE i.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @ExportQueueId;
    UPDATE dbo.ExportQueue SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ExportQueueId = @ExportQueueId;
END
GO

CREATE PROCEDURE dbo.usp_Rpt_Export_Supplier
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @CustomerId;
    INSERT INTO dbo.ExportQueue (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
END
GO
