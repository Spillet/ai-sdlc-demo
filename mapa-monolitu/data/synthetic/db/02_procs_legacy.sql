-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE PROC dbo.usp_Migr2019_Customer
    @ImportProductId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ImportProduct WHERE ImportProductId = @ImportProductId;
    UPDATE p SET p.ModifiedAt = GETDATE()
    FROM dbo.Product_bak2019 p
    INNER JOIN dbo.ImportProduct ip2 ON ip2.ImportProductId = p.Product_bak2019Id
    WHERE p.Product_bak2019Id = @ImportProductId;
    UPDATE dbo.StockLevel SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE StockLevelId = @ImportProductId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
END
GO

CREATE PROC dbo.usp_Migr2019_Orders
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ImportPrice WHERE ImportPriceId = @CustomerId;
    UPDATE dbo.Customer SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CustomerId = @CustomerId;
    INSERT INTO dbo.ImportProduct (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
END
GO

CREATE PROCEDURE dbo.usp_Migr2019_Product
    @ImportPriceId INT = NULL,
    @UserId INT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ImportStock WHERE ImportStockId = @ImportPriceId;
    UPDATE ip SET ip.ModifiedAt = GETDATE()
    FROM dbo.ImportPrice ip
    INNER JOIN dbo.ImportStock is2 ON is2.ImportStockId = ip.ImportPriceId
    WHERE ip.ImportPriceId = @ImportPriceId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
END
GO

CREATE PROCEDURE dbo.usp_Old_PriceCalc
    @ImportProductId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ImportProduct WHERE ImportProductId = @ImportProductId;
    UPDATE dbo.X_Migr_Customer SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE X_Migr_CustomerId = @ImportProductId;
END
GO

CREATE PROCEDURE dbo.usp_Old_OrderExport
    @TmpRecalcId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.X_Migr_Customer WHERE X_Migr_CustomerId = @TmpRecalcId;
    UPDATE dbo.TmpRecalc SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE TmpRecalcId = @TmpRecalcId;
END
GO

CREATE PROCEDURE dbo.usp_Import_Product
    @ImportPriceId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ImportStock WHERE ImportStockId = @ImportPriceId;
    UPDATE dbo.ImportPrice SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ImportPriceId = @ImportPriceId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
END
GO

CREATE PROCEDURE dbo.usp_Import_Stock
    @ImportPriceId INT = NULL,
    @UserId INT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ImportStock WHERE ImportStockId = @ImportPriceId;
    UPDATE dbo.ImportPrice SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ImportPriceId = @ImportPriceId;
    INSERT INTO dbo.StockLevel (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
END
GO

CREATE PROCEDURE dbo.usp_Import_Price
    @ImportProductId INT = NULL,
    @UserId INT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ImportProduct WHERE ImportProductId = @ImportProductId;
    MERGE dbo.TmpRecalc AS tgt
    USING (SELECT @ImportProductId AS TmpRecalcId) AS src ON tgt.TmpRecalcId = src.TmpRecalcId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
END
GO

CREATE PROCEDURE dbo.usp_Tmp_Recalc
    @OrderId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Product_bak2019 WHERE Product_bak2019Id = @OrderId;
    INSERT INTO dbo.Orders (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    DELETE FROM dbo.Product_bak2019 WHERE Product_bak2019Id = @OrderId AND Status = 0;
END
GO

CREATE PROC dbo.usp_Tmp_FixStock
    @OldOrdersId INT = NULL,
    @UserId INT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Product_bak2019 WHERE Product_bak2019Id = @OldOrdersId;
    DELETE FROM dbo.OldOrders WHERE OldOrdersId = @OldOrdersId AND Status = 0;
    MERGE dbo.Product AS tgt
    USING (SELECT @OldOrdersId AS ProductId) AS src ON tgt.ProductId = src.ProductId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
END
GO

CREATE PROC dbo.sp_Test_Order
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ImportStock WHERE ImportStockId = @CustomerId;
    UPDATE dbo.Customer SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CustomerId = @CustomerId;
    UPDATE dbo.Product_bak2019 SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE Product_bak2019Id = @CustomerId;
END
GO

CREATE PROCEDURE dbo.usp_Product_Bak_Restore
    @ImportStockId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ImportStock WHERE ImportStockId = @ImportStockId;
    UPDATE dbo.Product_bak2019 SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE Product_bak2019Id = @ImportStockId;
END
GO

CREATE PROCEDURE dbo.usp_Old_InvoicePrint
    @Product_bak2019Id INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.TmpRecalc WHERE TmpRecalcId = @Product_bak2019Id;
    MERGE dbo.Product_bak2019 AS tgt
    USING (SELECT @Product_bak2019Id AS Product_bak2019Id) AS src ON tgt.Product_bak2019Id = src.Product_bak2019Id
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
END
GO

CREATE PROCEDURE dbo.usp_Old_CustomerMerge
    @ImportStockId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    UPDATE is SET is.ModifiedAt = GETDATE()
    FROM dbo.ImportStock is
    INNER JOIN dbo.ImportStock is2 ON is2.ImportStockId = is.ImportStockId
    WHERE is.ImportStockId = @ImportStockId;
    UPDATE p SET p.ModifiedAt = GETDATE()
    FROM dbo.Product p
    INNER JOIN dbo.ImportStock is3 ON is3.ImportStockId = p.ProductId
    WHERE p.ProductId = @ImportStockId;
END
GO
