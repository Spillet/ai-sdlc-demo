-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE PROCEDURE dbo.usp_Price_Promo_Get
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Promo WHERE PromoId = @CustomerId;
    SELECT pp.*, p2.PromoId AS PromoKey
    FROM dbo.PromoProduct AS pp WITH (NOLOCK)
    JOIN dbo.Promo p2 ON p2.PromoId = pp.PromoId
    WHERE pp.Status = 1;
    EXEC @rc = usp_SysParam_Get @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Price_Promo_Import
    @OrderItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @OrderItemId;
    MERGE dbo.Promo AS tgt
    USING (SELECT @OrderItemId AS PromoId) AS src ON tgt.PromoId = src.PromoId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_SysParam_Get @OrderItemId = @OrderItemId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Price_PriceHistory_GetDetail @OrderItemId = @OrderItemId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Price_Voucher_Confirm
    @OrderItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT oi.*, p.ProductId AS ProductKey
    FROM dbo.OrderItem AS oi WITH (NOLOCK)
    JOIN dbo.Product p ON p.ProductId = oi.ProductId
    WHERE oi.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.Promo WHERE PromoId = @OrderItemId;
    SELECT v.*, p4.PromoId AS PromoKey
    FROM dbo.Voucher AS v WITH (NOLOCK)
    JOIN dbo.Promo p4 ON p4.PromoId = v.PromoId
    WHERE v.Status = 1;
    MERGE dbo.PriceHistory AS tgt
    USING (SELECT @OrderItemId AS PriceHistoryId) AS src ON tgt.PriceHistoryId = src.PriceHistoryId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    UPDATE vu SET vu.ModifiedAt = GETDATE()
    FROM dbo.VoucherUse vu
    INNER JOIN dbo.OrderItem oi2 ON oi2.OrderItemId = vu.VoucherUseId
    WHERE vu.VoucherUseId = @OrderItemId;
    EXEC usp_Audit_Write @EntityName = 'usp_Price_Voucher_Confirm', @EntityId = @OrderItemId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Price_VoucherUse_Approve @OrderItemId = @OrderItemId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Price_PriceList_Recalc @OrderItemId = @OrderItemId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Price_Promo_GetDetail
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Promo WHERE PromoId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.VoucherUse WHERE VoucherUseId = @CustomerId;
    SET @val = dbo.fn_SplitString(@CustomerId);
END
GO

CREATE PROCEDURE dbo.usp_Price_Voucher_Merge
    @PromoId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Promo WHERE PromoId = @PromoId;
    UPDATE dbo.Voucher SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE VoucherId = @PromoId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Price_Voucher_Merge', @EntityId = @PromoId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Price_PriceList_Search
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.PriceList WHERE PriceListId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Voucher WHERE VoucherId = @CustomerId;
END
GO

CREATE PROC dbo.usp_Price_PriceList_SetStatus
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @CustomerId;
    SET @val = dbo.fn_IsWorkingDay(@CustomerId);
    UPDATE dbo.PriceList SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE PriceListId = @CustomerId;
    UPDATE p SET p.ModifiedAt = GETDATE()
    FROM dbo.Promo p
    INNER JOIN dbo.Customer c2 ON c2.CustomerId = p.PromoId
    WHERE p.PromoId = @CustomerId;
    EXEC @rc = dbo.usp_Error_Log @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Price_PriceList_MonthClose
    @ProductId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.OldOrders, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Price_PriceList_MonthClose';
    SELECT @cnt = COUNT(*) FROM dbo.Promo WHERE PromoId = @ProductId;
    SELECT @cnt = COUNT(*) FROM dbo.Voucher WHERE VoucherId = @ProductId;
    INSERT INTO dbo.Product (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO dbo.Promo (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Price_PriceList_MonthClose', @EntityId = @ProductId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @ProductId = @ProductId, @UserId = @UserId;
    EXEC dbo.usp_Price_PriceHistory_Overview @ProductId = @ProductId, @UserId = @UserId;
    EXEC dbo.usp_Price_Promo_Get @ProductId = @ProductId, @UserId = @UserId;
    EXEC dbo.usp_Price_Voucher_Merge @ProductId = @ProductId, @UserId = @UserId;
    EXEC dbo.usp_Product_Product_Search @ProductId = @ProductId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Price_PriceListItem_List
    @PriceListId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.PriceList WHERE PriceListId = @PriceListId;
    SELECT pli.*, pl2.PriceListId AS PriceListKey
    FROM dbo.PriceListItem AS pli WITH (NOLOCK)
    JOIN dbo.PriceList pl2 ON pl2.PriceListId = pli.PriceListId
    WHERE pli.Status = 1;
END
GO

CREATE PROC dbo.usp_Price_Voucher_Cancel
    @PriceListId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.PriceListItem WHERE PriceListItemId = @PriceListId;
    SELECT @cnt = COUNT(*) FROM dbo.VoucherUse WHERE VoucherUseId = @PriceListId;
    UPDATE dbo.PriceList SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE PriceListId = @PriceListId;
    UPDATE p SET p.ModifiedAt = GETDATE()
    FROM dbo.Promo p
    INNER JOIN dbo.PriceListItem pli2 ON pli2.PriceListItemId = p.PromoId
    WHERE p.PromoId = @PriceListId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Price_Voucher_Cancel', @EntityId = @PriceListId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Price_PriceList_Overview @PriceListId = @PriceListId, @UserId = @UserId;
    EXEC dbo.usp_Price_PriceHistory_GetDetail @PriceListId = @PriceListId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Price_Promo_Get @PriceListId = @PriceListId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Price_PriceList_Recalc @PriceListId = @PriceListId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Product_Brand_Insert @PriceListId = @PriceListId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Price_PriceList_Overview
    @PriceListId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.PriceList WHERE PriceListId = @PriceListId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @PriceListId;
END
GO

CREATE PROC dbo.usp_Price_PriceList_Save
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_ProductWithPrice WHERE Id = @CustomerId;
    DELETE FROM dbo.PriceList WHERE PriceListId = @CustomerId AND Status = 0;
    UPDATE dbo.Product SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ProductId = @CustomerId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Price_PriceList_Save', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Price_PriceList_Insert
    @OrderItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @OrderItemId;
    SET @val = dbo.fn_UserName(@OrderItemId);
    MERGE dbo.PriceList AS tgt
    USING (SELECT @OrderItemId AS PriceListId) AS src ON tgt.PriceListId = src.PriceListId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Price_PriceList_Insert', @EntityId = @OrderItemId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Error_Log @OrderItemId = @OrderItemId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Price_Promo_Cancel
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    INSERT INTO #work (Id, Val)
    SELECT c.CustomerId, 0 FROM dbo.Customer c WHERE c.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SELECT pli.*, pl.PriceListId AS PriceListKey
    FROM dbo.PriceListItem AS pli WITH (NOLOCK)
    JOIN dbo.PriceList pl ON pl.PriceListId = pli.PriceListId
    WHERE pli.Status = 1;
    INSERT INTO #work (Id, Val)
    SELECT p.ProductId, 0 FROM dbo.Product p WHERE p.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SELECT @cnt = COUNT(*) FROM dbo.vw_ProductWithPrice WHERE Id = @CustomerId;
    DELETE FROM dbo.PriceList WHERE PriceListId = @CustomerId AND Status = 0;
    INSERT INTO dbo.PriceListItem (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE p2 SET p2.ModifiedAt = GETDATE()
    FROM dbo.Product p2
    INNER JOIN dbo.Customer c2 ON c2.CustomerId = p2.ProductId
    WHERE p2.ProductId = @CustomerId;
    EXEC @rc = dbo.usp_Price_Promo_Get @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Price_VoucherUse_Approve @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Price_PriceList_Search @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Price_PriceList_Insert @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Product_Category_Update @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Price_PriceHistory_Overview
    @OrderItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.PriceHistory WHERE PriceHistoryId = @OrderItemId;
END
GO

CREATE PROCEDURE dbo.usp_Price_PriceHistory_MonthClose
    @OrderItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Price_PriceHistory_MonthClose';
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @OrderItemId;
    SELECT @cnt = COUNT(*) FROM dbo.PromoProduct WHERE PromoProductId = @OrderItemId;
    UPDATE dbo.PriceHistory SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE PriceHistoryId = @OrderItemId;
    UPDATE p SET p.ModifiedAt = GETDATE()
    FROM dbo.Promo p
    INNER JOIN dbo.OrderItem oi2 ON oi2.OrderItemId = p.PromoId
    WHERE p.PromoId = @OrderItemId;
    INSERT INTO DWH.dbo.PriceHistory_Archive SELECT * FROM dbo.PriceHistory WHERE CreatedAt < DATEADD(MONTH, -24, GETDATE());
    EXEC dbo.usp_JobRun_End @OrderItemId = @OrderItemId, @UserId = @UserId;
    EXEC dbo.usp_Price_PriceList_Search @OrderItemId = @OrderItemId, @UserId = @UserId;
    EXEC dbo.usp_Price_Promo_Get @OrderItemId = @OrderItemId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Price_Voucher_Merge @OrderItemId = @OrderItemId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Product_Brand_Insert @OrderItemId = @OrderItemId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Price_PriceList_Recalc
    @PriceListId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    UPDATE dbo.PriceList SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE PriceListId = @PriceListId;
    INSERT INTO dbo.Product (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
END
GO

CREATE PROCEDURE dbo.usp_Price_Promo_Save
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @CustomerId;
    SET @val = dbo.fn_ProductPrice(@CustomerId);
    UPDATE dbo.Promo SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE PromoId = @CustomerId;
    EXEC dbo.usp_Counter_Next @CustomerId = @CustomerId, @UserId = @UserId;
END
GO

CREATE PROC dbo.usp_Price_PriceHistory_GetDetail
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.TmpRecalc, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.PriceHistory WHERE PriceHistoryId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.PromoProduct WHERE PromoProductId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_ProductActive WHERE Id = @CustomerId;
    EXEC dbo.usp_SysParam_Get @CustomerId = @CustomerId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Price_VoucherUse_Approve
    @PriceListId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Voucher WHERE VoucherId = @PriceListId;
    SET @val = dbo.fn_WorkingDaysBetween(@PriceListId);
    INSERT INTO dbo.PriceList (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE dbo.VoucherUse SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE VoucherUseId = @PriceListId;
    EXEC dbo.usp_Price_PriceList_Overview @PriceListId = @PriceListId, @UserId = @UserId;
END
GO
