-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE PROCEDURE dbo.usp_Product_Product_Merge
    @ProductId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.TmpRecalc, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @ProductId;
    SELECT @cnt = COUNT(*) FROM dbo.SupplierProduct WHERE SupplierProductId = @ProductId;
    INSERT INTO dbo.Product (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
END
GO

CREATE PROCEDURE dbo.usp_Product_ProductAttribute_Approve
    @PriceListItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.OldOrders, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.PriceListItem WHERE PriceListItemId = @PriceListItemId;
    SELECT @cnt = COUNT(*) FROM dbo.SupplierProduct WHERE SupplierProductId = @PriceListItemId;
    INSERT INTO dbo.ProductAttribute (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE dbo.ProductImage SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ProductImageId = @PriceListItemId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Product_ProductAttribute_Approve', @EntityId = @PriceListItemId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Product_Brand_List
    @BrandId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Brand WHERE BrandId = @BrandId;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @BrandId;
END
GO

CREATE PROCEDURE dbo.usp_Product_Brand_Insert
    @BrandId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.OldOrders, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.PriceListItem WHERE PriceListItemId = @BrandId;
    SET @val = dbo.fn_WorkingDaysBetween(@BrandId);
    INSERT INTO dbo.Brand (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC usp_Audit_Write @EntityName = 'usp_Product_Brand_Insert', @EntityId = @BrandId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Product_Category_Nightly
    @CategoryId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Product_Category_Nightly';
    SELECT @cnt = COUNT(*) FROM dbo.ProductAttribute WHERE ProductAttributeId = @CategoryId;
    INSERT INTO dbo.Category (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO dbo.ProductCategory (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO dbo.ProductText (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Product_Category_Nightly', @EntityId = @CategoryId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @CategoryId = @CategoryId, @UserId = @UserId;
    EXEC dbo.usp_Product_AttributeDef_Check @CategoryId = @CategoryId, @UserId = @UserId;
    EXEC dbo.usp_Product_Brand_List @CategoryId = @CategoryId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Product_Product_Check
    @BrandId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Brand WHERE BrandId = @BrandId;
    SELECT @cnt = COUNT(*) FROM dbo.Category WHERE CategoryId = @BrandId;
    SELECT p.*, b2.BrandId AS BrandKey
    FROM dbo.Product AS p WITH (NOLOCK)
    JOIN dbo.Brand b2 ON b2.BrandId = p.BrandId
    WHERE p.Status = 1;
    SET @val = dbo.fn_WorkingDaysBetween(@BrandId);
END
GO

CREATE PROCEDURE dbo.usp_Product_Product_Rebuild
    @BrandId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    INSERT INTO #work (Id, Val)
    SELECT pli.PriceListItemId, 0 FROM dbo.PriceListItem pli WHERE pli.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    INSERT INTO #work (Id, Val)
    SELECT pc.ProductCategoryId, 0 FROM dbo.ProductCategory pc WHERE pc.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SELECT @cnt = COUNT(*) FROM dbo.ProductImage WHERE ProductImageId = @BrandId;
    SELECT @cnt = COUNT(*) FROM dbo.SupplierProduct WHERE SupplierProductId = @BrandId;
    UPDATE dbo.Brand SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE BrandId = @BrandId;
    INSERT INTO dbo.ProductText (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO dbo.StockLevel (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Product_Product_Rebuild', @EntityId = @BrandId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Counter_Next @BrandId = @BrandId, @UserId = @UserId;
    EXEC dbo.usp_Product_ProductImage_GetByCode @BrandId = @BrandId, @UserId = @UserId;
    EXEC dbo.usp_Product_AttributeDef_Check @BrandId = @BrandId, @UserId = @UserId;
    EXEC dbo.usp_Product_Brand_Insert @BrandId = @BrandId, @UserId = @UserId;
    EXEC dbo.usp_Product_Category_Update @BrandId = @BrandId, @UserId = @UserId;
    EXEC dbo.usp_Price_Promo_GetDetail @BrandId = @BrandId, @UserId = @UserId;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Product_Product_Find
    @ProductId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @ProductId;
    SELECT @cnt = COUNT(*) FROM dbo.ProductAttribute WHERE ProductAttributeId = @ProductId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_ProductDetail WHERE Id = @ProductId;
    SET @val = dbo.fn_UserName(@ProductId);
END
GO

CREATE PROC dbo.usp_Product_Product_Dispatch
    @AttributeDefId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Brand WHERE BrandId = @AttributeDefId;
    INSERT INTO #work (Id, Val)
    SELECT pli.PriceListItemId, 0 FROM dbo.PriceListItem pli WHERE pli.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    INSERT INTO #work (Id, Val)
    SELECT sp.SupplierProductId, 0 FROM dbo.SupplierProduct sp WHERE sp.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    MERGE dbo.AttributeDef AS tgt
    USING (SELECT @AttributeDefId AS AttributeDefId) AS src ON tgt.AttributeDefId = src.AttributeDefId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    MERGE dbo.ProductCategory AS tgt
    USING (SELECT @AttributeDefId AS ProductCategoryId) AS src ON tgt.ProductCategoryId = src.ProductCategoryId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Product_Product_Dispatch', @EntityId = @AttributeDefId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Product_Product_Check @AttributeDefId = @AttributeDefId, @UserId = @UserId;
    EXEC @rc = usp_Product_Brand_GetByCode @AttributeDefId = @AttributeDefId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Product_ProductAttribute_Approve @AttributeDefId = @AttributeDefId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Product_ProductImage_GetByCode @AttributeDefId = @AttributeDefId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Price_PriceListItem_List @AttributeDefId = @AttributeDefId;
    IF @rc <> 0 RETURN @rc;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Product_Product_Cancel
    @AttributeDefId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    INSERT INTO #work (Id, Val)
    SELECT b.BrandId, 0 FROM dbo.Brand b WHERE b.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SELECT @cnt = COUNT(*) FROM dbo.Category WHERE CategoryId = @AttributeDefId;
    SELECT @cnt = COUNT(*) FROM dbo.PriceListItem WHERE PriceListItemId = @AttributeDefId;
    SELECT @cnt = COUNT(*) FROM dbo.SupplierProduct WHERE SupplierProductId = @AttributeDefId;
    UPDATE dbo.AttributeDef SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE AttributeDefId = @AttributeDefId;
    INSERT INTO dbo.ProductText (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Product_Product_Cancel', @EntityId = @AttributeDefId, @Action = 'UPD', @UserId = @UserId;
    EXEC usp_Product_Brand_List @AttributeDefId = @AttributeDefId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Product_ProductImage_GetByCode @AttributeDefId = @AttributeDefId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Price_Promo_GetDetail @AttributeDefId = @AttributeDefId;
    IF @rc <> 0 RETURN @rc;
    DROP TABLE #work;
END
GO

CREATE PROC dbo.usp_Product_Product_Import
    @CategoryId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Category WHERE CategoryId = @CategoryId;
    SELECT @cnt = COUNT(*) FROM dbo.PriceListItem WHERE PriceListItemId = @CategoryId;
    SELECT @cnt = COUNT(*) FROM dbo.SupplierProduct WHERE SupplierProductId = @CategoryId;
    INSERT INTO dbo.Product (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
END
GO

CREATE PROCEDURE dbo.usp_Product_AttributeDef_Check
    @AttributeDefId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.AttributeDef WHERE AttributeDefId = @AttributeDefId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @AttributeDefId;
    SET @val = dbo.fn_UserName(@AttributeDefId);
END
GO

CREATE PROCEDURE dbo.usp_Product_Brand_GetByCode
    @AttributeDefId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.AttributeDef WHERE AttributeDefId = @AttributeDefId;
    SELECT @cnt = COUNT(*) FROM dbo.Brand WHERE BrandId = @AttributeDefId;
    SET @val = dbo.fn_SplitString(@AttributeDefId);
END
GO

CREATE PROC dbo.usp_Product_Category_Update
    @CategoryId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.vw_ProductActive WHERE Id = @CategoryId;
    SET @val = dbo.fn_WorkingDaysBetween(@CategoryId);
    UPDATE dbo.Category SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CategoryId = @CategoryId;
END
GO

CREATE PROCEDURE dbo.usp_Product_Brand_Cleanup
    @CategoryId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Product_Brand_Cleanup';
    SELECT @cnt = COUNT(*) FROM dbo.ProductAttribute WHERE ProductAttributeId = @CategoryId;
    SELECT @cnt = COUNT(*) FROM dbo.SupplierProduct WHERE SupplierProductId = @CategoryId;
    UPDATE c SET c.ModifiedAt = GETDATE()
    FROM dbo.Category c
    INNER JOIN dbo.Category c2 ON c2.CategoryId = c.CategoryId
    WHERE c.CategoryId = @CategoryId;
    UPDATE dbo.ProductCategory SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ProductCategoryId = @CategoryId;
    UPDATE pi SET pi.ModifiedAt = GETDATE()
    FROM dbo.ProductImage pi
    INNER JOIN dbo.Category c3 ON c3.CategoryId = pi.ProductImageId
    WHERE pi.ProductImageId = @CategoryId;
    EXEC dbo.usp_JobRun_End @CategoryId = @CategoryId, @UserId = @UserId;
    EXEC dbo.usp_Product_Brand_List @CategoryId = @CategoryId, @UserId = @UserId;
    EXEC dbo.usp_Product_ProductImage_GetByCode @CategoryId = @CategoryId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Product_Product_GetByCode @CategoryId = @CategoryId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Product_Product_Merge @CategoryId = @CategoryId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Price_PriceHistory_GetDetail @CategoryId = @CategoryId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Product_ProductImage_GetByCode
    @CategoryId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Category WHERE CategoryId = @CategoryId;
    SELECT @cnt = COUNT(*) FROM dbo.ProductImage WHERE ProductImageId = @CategoryId;
    SELECT @cnt = COUNT(*) FROM dbo.StockLevel WHERE StockLevelId = @CategoryId;
END
GO

CREATE PROCEDURE dbo.usp_Product_Product_Confirm
    @AttributeDefId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.AttributeDef WHERE AttributeDefId = @AttributeDefId;
    SELECT @cnt = COUNT(*) FROM dbo.Brand WHERE BrandId = @AttributeDefId;
    SET @val = dbo.fn_UserName(@AttributeDefId);
    UPDATE dbo.Product SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ProductId = @AttributeDefId;
    DELETE FROM dbo.ProductText WHERE ProductTextId = @AttributeDefId AND Status = 0;
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.Product', @EntityId = @AttributeDefId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Product_Product_Import @AttributeDefId = @AttributeDefId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Product_Product_GetByCode @AttributeDefId = @AttributeDefId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Product_AttributeDef_Check @AttributeDefId = @AttributeDefId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Product_Category_Update @AttributeDefId = @AttributeDefId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Price_PriceListItem_List @AttributeDefId = @AttributeDefId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Product_ProductAttribute_Cleanup
    @AttributeDefId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Product_ProductAttribute_Cleanup';
    SELECT @cnt = COUNT(*) FROM dbo.AttributeDef WHERE AttributeDefId = @AttributeDefId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @AttributeDefId;
    SELECT sl.*, p2.ProductId AS ProductKey
    FROM dbo.StockLevel AS sl WITH (NOLOCK)
    JOIN dbo.Product p2 ON p2.ProductId = sl.ProductId
    WHERE sl.Status = 1;
    UPDATE dbo.ProductImage SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ProductImageId = @AttributeDefId;
    UPDATE pt SET pt.ModifiedAt = GETDATE()
    FROM dbo.ProductText pt
    INNER JOIN dbo.AttributeDef ad2 ON ad2.AttributeDefId = pt.ProductTextId
    WHERE pt.ProductTextId = @AttributeDefId;
    INSERT INTO Archive.dbo.ProductAttribute_Archive SELECT * FROM dbo.ProductImage WHERE CreatedAt < DATEADD(MONTH, -24, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Product_ProductAttribute_Cleanup', @EntityId = @AttributeDefId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_JobRun_End @AttributeDefId = @AttributeDefId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Product_Brand_GetByCode @AttributeDefId = @AttributeDefId, @UserId = @UserId;
    EXEC dbo.usp_Product_Product_GetByCode @AttributeDefId = @AttributeDefId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Product_Product_GetByCode
    @PriceListItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT pli.*, p.ProductId AS ProductKey
    FROM dbo.PriceListItem AS pli WITH (NOLOCK)
    JOIN dbo.Product p ON p.ProductId = pli.ProductId
    WHERE pli.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @PriceListItemId;
    SELECT sl.*, p3.ProductId AS ProductKey
    FROM dbo.StockLevel AS sl WITH (NOLOCK)
    JOIN dbo.Product p3 ON p3.ProductId = sl.ProductId
    WHERE sl.Status = 1;
END
GO

CREATE PROCEDURE dbo.usp_Product_Product_Search
    @BrandId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.TmpRecalc, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Brand WHERE BrandId = @BrandId;
    SELECT @cnt = COUNT(*) FROM dbo.Category WHERE CategoryId = @BrandId;
    SELECT @cnt = COUNT(*) FROM dbo.PriceListItem WHERE PriceListItemId = @BrandId;
    SELECT p.*, b2.BrandId AS BrandKey
    FROM dbo.Product AS p WITH (NOLOCK)
    JOIN dbo.Brand b2 ON b2.BrandId = p.BrandId
    WHERE p.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.SupplierProduct WHERE SupplierProductId = @BrandId;
END
GO

CREATE PROCEDURE dbo.usp_Product_AttributeDef_Overview
    @AttributeDefId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.AttributeDef WHERE AttributeDefId = @AttributeDefId;
    SELECT @cnt = COUNT(*) FROM dbo.SupplierProduct WHERE SupplierProductId = @AttributeDefId;
    EXEC @rc = dbo.usp_SysParam_Get @AttributeDefId = @AttributeDefId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Product_ProductAttribute_Process
    @AttributeDefId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.AttributeDef WHERE AttributeDefId = @AttributeDefId;
    SELECT @cnt = COUNT(*) FROM dbo.Category WHERE CategoryId = @AttributeDefId;
    UPDATE c2 SET c2.ModifiedAt = GETDATE()
    FROM dbo.Category c2
    INNER JOIN dbo.AttributeDef ad2 ON ad2.AttributeDefId = c2.CategoryId
    WHERE c2.CategoryId = @AttributeDefId;
    UPDATE pi SET pi.ModifiedAt = GETDATE()
    FROM dbo.ProductImage pi
    INNER JOIN dbo.AttributeDef ad3 ON ad3.AttributeDefId = pi.ProductImageId
    WHERE pi.ProductImageId = @AttributeDefId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Product_ProductAttribute_Process', @EntityId = @AttributeDefId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_Product_ProductAttribute_Approve @AttributeDefId = @AttributeDefId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Product_AttributeDef_Overview @AttributeDefId = @AttributeDefId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Product_Brand_Insert @AttributeDefId = @AttributeDefId, @UserId = @UserId;
    EXEC dbo.usp_Product_Brand_GetByCode @AttributeDefId = @AttributeDefId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Product_AttributeDef_Process
    @BrandId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ProductText WHERE ProductTextId = @BrandId;
    SET @val = dbo.fn_GetSysParam('LIMIT_CATALOG');
    MERGE dbo.Brand AS tgt
    USING (SELECT @BrandId AS BrandId) AS src ON tgt.BrandId = src.BrandId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    INSERT INTO dbo.Product (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Product_AttributeDef_Process', @EntityId = @BrandId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Product_Product_Check @BrandId = @BrandId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Product_Brand_Insert @BrandId = @BrandId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Product_ProductImage_GetByCode @BrandId = @BrandId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Price_PriceHistory_GetDetail @BrandId = @BrandId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Product_ProductCategory_GetByCode
    @ProductCategoryId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ProductCategory WHERE ProductCategoryId = @ProductCategoryId;
END
GO
