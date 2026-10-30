-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE PROCEDURE dbo.usp_Cust_Customer_Rebuild
    @CustomerAddressId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.TmpRecalc, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.LoyaltyTransaction WHERE LoyaltyTransactionId = @CustomerAddressId;
    UPDATE dbo.CustomerAddress SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CustomerAddressId = @CustomerAddressId;
    MERGE dbo.CustomerSegment AS tgt
    USING (SELECT @CustomerAddressId AS CustomerSegmentId) AS src ON tgt.CustomerSegmentId = src.CustomerSegmentId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Cust_Customer_Rebuild', @EntityId = @CustomerAddressId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_Cust_LoyaltyTransaction_GetByCode @CustomerAddressId = @CustomerAddressId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Cust_Customer_Save @CustomerAddressId = @CustomerAddressId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Cust_LoyaltyAccount_Merge
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.OldOrders, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SET @val = dbo.fn_Translate(@CustomerId);
    UPDATE dbo.LoyaltyAccount SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE LoyaltyAccountId = @CustomerId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Cust_LoyaltyAccount_Merge', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_SysParam_Get @CustomerId = @CustomerId, @UserId = @UserId;
END
GO

CREATE PROC dbo.usp_Cust_Customer_Merge
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Invoice WHERE InvoiceId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @CustomerId;
    INSERT INTO dbo.Customer (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Cust_Customer_Find @CustomerId = @CustomerId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Cust_CustomerAddress_Close
    @CustomerAddressId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Invoice WHERE InvoiceId = @CustomerAddressId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_LoyaltyBalance WHERE Id = @CustomerAddressId;
    SET @val = dbo.fn_CustomerIsVip(@CustomerAddressId);
    UPDATE dbo.CustomerAddress SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CustomerAddressId = @CustomerAddressId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Cust_CustomerAddress_Close', @EntityId = @CustomerAddressId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_User_CheckPermission @CustomerAddressId = @CustomerAddressId, @UserId = @UserId;
END
GO

CREATE PROC dbo.usp_Cust_Customer_Recalc
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.CustomerSegment WHERE CustomerSegmentId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_LoyaltyBalance WHERE Id = @CustomerId;
    SET @val = dbo.fn_UserName(@CustomerId);
    DELETE FROM dbo.Customer WHERE CustomerId = @CustomerId AND Status = 0;
    UPDATE dbo.CustomerSegment SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CustomerSegmentId = @CustomerId;
    DELETE FROM dbo.Orders WHERE OrderId = @CustomerId AND Status = 0;
    EXEC usp_Audit_Write @EntityName = 'usp_Cust_Customer_Recalc', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_User_CheckPermission @CustomerId = @CustomerId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Cust_Customer_Find
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_CustomerOverview WHERE Id = @CustomerId;
    SET @val = dbo.fn_SplitString(@CustomerId);
END
GO

CREATE PROCEDURE dbo.usp_Cust_Customer_Insert
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT i.*, o.OrderId AS OrdersKey
    FROM dbo.Invoice AS i WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = i.OrderId
    WHERE i.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_CustomerOverview WHERE Id = @CustomerId;
    SET @val = dbo.fn_UserName(@CustomerId);
    UPDATE c SET c.ModifiedAt = GETDATE()
    FROM dbo.Customer c
    INNER JOIN dbo.Invoice i2 ON i2.InvoiceId = c.CustomerId
    WHERE c.CustomerId = @CustomerId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Cust_Customer_Insert', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Cust_CustomerAddress_List @CustomerId = @CustomerId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Cust_Customer_MonthClose
    @ConsentId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Cust_Customer_MonthClose';
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @ConsentId;
    SELECT cc.*, c2.CustomerId AS CustomerKey
    FROM dbo.CustomerContact AS cc WITH (NOLOCK)
    JOIN dbo.Customer c2 ON c2.CustomerId = cc.CustomerId
    WHERE cc.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Invoice WHERE InvoiceId = @ConsentId;
    SELECT o.*, c3.CustomerId AS CustomerKey
    FROM dbo.Orders AS o WITH (NOLOCK)
    JOIN dbo.Customer c3 ON c3.CustomerId = o.CustomerId
    WHERE o.Status = 1;
    DELETE FROM dbo.Consent WHERE ConsentId = @ConsentId AND Status = 0;
    INSERT INTO dbo.CustomerAddress (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE dbo.LoyaltyTransaction SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE LoyaltyTransactionId = @ConsentId;
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.LoyaltyTransaction', @EntityId = @ConsentId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_JobRun_End @ConsentId = @ConsentId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Cust_CustomerAddress_Close @ConsentId = @ConsentId, @UserId = @UserId;
    EXEC dbo.usp_Cust_LoyaltyTransaction_GetByCode @ConsentId = @ConsentId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Cust_CustomerSegment_Dispatch
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.LoyaltyAccount WHERE LoyaltyAccountId = @CustomerId;
    SELECT o.*, c.CustomerId AS CustomerKey
    FROM dbo.Orders AS o WITH (NOLOCK)
    JOIN dbo.Customer c ON c.CustomerId = o.CustomerId
    WHERE o.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.vw_LoyaltyBalance WHERE Id = @CustomerId;
    INSERT INTO dbo.Customer (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO dbo.CustomerAddress (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Cust_Customer_Merge @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC usp_Cust_Customer_Insert @CustomerId = @CustomerId, @UserId = @UserId;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Cust_LoyaltyTransaction_GetByCode
    @LoyaltyAccountId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.LoyaltyAccount WHERE LoyaltyAccountId = @LoyaltyAccountId;
    SELECT @cnt = COUNT(*) FROM dbo.LoyaltyTransaction WHERE LoyaltyTransactionId = @LoyaltyAccountId;
END
GO

CREATE PROCEDURE dbo.usp_Cust_CustomerSegment_Close
    @CustomerSegmentId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @CustomerSegmentId;
    SET @val = dbo.fn_LoyaltyPoints(@CustomerSegmentId);
    UPDATE dbo.CustomerSegment SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CustomerSegmentId = @CustomerSegmentId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Cust_CustomerSegment_Close', @EntityId = @CustomerSegmentId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Cust_CustomerAddress_Dispatch
    @ConsentId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT c.*, c2.CustomerId AS CustomerKey
    FROM dbo.Consent AS c WITH (NOLOCK)
    JOIN dbo.Customer c2 ON c2.CustomerId = c.CustomerId
    WHERE c.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @ConsentId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_CustomerOverview WHERE Id = @ConsentId;
    DELETE FROM dbo.LoyaltyAccount WHERE LoyaltyAccountId = @ConsentId AND Status = 0;
    UPDATE lt SET lt.ModifiedAt = GETDATE()
    FROM dbo.LoyaltyTransaction lt
    INNER JOIN dbo.Consent c4 ON c4.ConsentId = lt.LoyaltyTransactionId
    WHERE lt.LoyaltyTransactionId = @ConsentId;
    EXEC @rc = dbo.usp_Cust_Customer_Find @ConsentId = @ConsentId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Cust_Customer_Approve @ConsentId = @ConsentId, @UserId = @UserId;
    EXEC dbo.usp_Cust_CustomerAddress_Close @ConsentId = @ConsentId, @UserId = @UserId;
    EXEC dbo.usp_Cust_Customer_Insert @ConsentId = @ConsentId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Cust_CustomerContact_MonthClose
    @ConsentId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Cust_CustomerContact_MonthClose';
    INSERT INTO #work (Id, Val)
    SELECT c.CustomerId, 0 FROM dbo.Customer c WHERE c.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SELECT ca.*, c2.CustomerId AS CustomerKey
    FROM dbo.CustomerAddress AS ca WITH (NOLOCK)
    JOIN dbo.Customer c2 ON c2.CustomerId = ca.CustomerId
    WHERE ca.Status = 1;
    INSERT INTO dbo.Consent (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO dbo.CustomerAddress (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE la SET la.ModifiedAt = GETDATE()
    FROM dbo.LoyaltyAccount la
    INNER JOIN dbo.Customer c3 ON c3.CustomerId = la.LoyaltyAccountId
    WHERE la.LoyaltyAccountId = @ConsentId;
    EXEC dbo.usp_JobRun_End @ConsentId = @ConsentId, @UserId = @UserId;
    EXEC dbo.usp_Cust_Customer_Approve @ConsentId = @ConsentId, @UserId = @UserId;
    EXEC dbo.usp_Cust_LoyaltyTransaction_GetByCode @ConsentId = @ConsentId, @UserId = @UserId;
    EXEC dbo.usp_Cust_Customer_Merge @ConsentId = @ConsentId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Cust_Customer_Save @ConsentId = @ConsentId;
    IF @rc <> 0 RETURN @rc;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Cust_Customer_Sync
    @ConsentId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Consent WHERE ConsentId = @ConsentId;
    SELECT @cnt = COUNT(*) FROM dbo.CustomerContact WHERE CustomerContactId = @ConsentId;
    SELECT @cnt = COUNT(*) FROM dbo.Invoice WHERE InvoiceId = @ConsentId;
    SET @val = dbo.fn_Translate(@ConsentId);
    UPDATE c2 SET c2.ModifiedAt = GETDATE()
    FROM dbo.Customer c2
    INNER JOIN dbo.Consent c3 ON c3.ConsentId = c2.CustomerId
    WHERE c2.CustomerId = @ConsentId;
    INSERT INTO dbo.LoyaltyAccount (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Cust_Customer_Find @ConsentId = @ConsentId, @UserId = @UserId;
    EXEC dbo.usp_Cust_Customer_Save @ConsentId = @ConsentId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Cust_CustomerAddress_List
    @ConsentId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Consent WHERE ConsentId = @ConsentId;
    SELECT @cnt = COUNT(*) FROM dbo.CustomerAddress WHERE CustomerAddressId = @ConsentId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_CustomerOverview WHERE Id = @ConsentId;
END
GO

CREATE PROCEDURE dbo.usp_Cust_CustomerSegment_Delete
    @CustomerSegmentId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SET @val = dbo.fn_CustomerIsVip(@CustomerSegmentId);
    DELETE FROM dbo.CustomerSegment WHERE CustomerSegmentId = @CustomerSegmentId AND Status = 0;
END
GO

CREATE PROCEDURE dbo.usp_Cust_Customer_Approve
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    UPDATE c SET c.ModifiedAt = GETDATE()
    FROM dbo.Customer c
    INNER JOIN dbo.SysParam sp ON sp.SysParamId = c.CustomerId
    WHERE c.CustomerId = @CustomerId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Cust_Customer_Approve', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Cust_Customer_Save
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SET @val = dbo.fn_UserName(@CustomerId);
    INSERT INTO dbo.Customer (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Counter_Next @CustomerId = @CustomerId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Cust_CustomerAddress_Confirm
    @CustomerAddressId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.CustomerAddress WHERE CustomerAddressId = @CustomerAddressId;
    SELECT @cnt = COUNT(*) FROM dbo.CustomerSegment WHERE CustomerSegmentId = @CustomerAddressId;
    UPDATE dbo.CustomerContact SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CustomerContactId = @CustomerAddressId;
    INSERT INTO dbo.LoyaltyTransaction (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Cust_CustomerAddress_Confirm', @EntityId = @CustomerAddressId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_Cust_LoyaltyAccount_Merge @CustomerAddressId = @CustomerAddressId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Cust_Customer_Save @CustomerAddressId = @CustomerAddressId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Cust_Customer_Insert @CustomerAddressId = @CustomerAddressId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Cust_Customer_Merge @CustomerAddressId = @CustomerAddressId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Cust_Customer_Nightly
    @ConsentId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Cust_Customer_Nightly';
    SELECT @cnt = COUNT(*) FROM dbo.CustomerAddress WHERE CustomerAddressId = @ConsentId;
    SELECT @cnt = COUNT(*) FROM dbo.LoyaltyTransaction WHERE LoyaltyTransactionId = @ConsentId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_CustomerOverview WHERE Id = @ConsentId;
    UPDATE c SET c.ModifiedAt = GETDATE()
    FROM dbo.Consent c
    INNER JOIN dbo.CustomerAddress ca2 ON ca2.CustomerAddressId = c.ConsentId
    WHERE c.ConsentId = @ConsentId;
    UPDATE cs SET cs.ModifiedAt = GETDATE()
    FROM dbo.CustomerSegment cs
    INNER JOIN dbo.CustomerAddress ca3 ON ca3.CustomerAddressId = cs.CustomerSegmentId
    WHERE cs.CustomerSegmentId = @ConsentId;
    UPDATE lt2 SET lt2.ModifiedAt = GETDATE()
    FROM dbo.LoyaltyTransaction lt2
    INNER JOIN dbo.CustomerAddress ca4 ON ca4.CustomerAddressId = lt2.LoyaltyTransactionId
    WHERE lt2.LoyaltyTransactionId = @ConsentId;
    INSERT INTO dbo.Orders (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO DWH.dbo.Customer_Archive SELECT * FROM dbo.Consent WHERE CreatedAt < DATEADD(MONTH, -24, GETDATE());
    EXEC dbo.usp_SysParam_Get @ConsentId = @ConsentId, @UserId = @UserId;
    EXEC @rc = dbo.usp_JobRun_End @ConsentId = @ConsentId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Cust_Customer_Insert @ConsentId = @ConsentId, @UserId = @UserId;
    EXEC dbo.usp_Cust_Customer_Recalc @ConsentId = @ConsentId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Cust_LoyaltyAccount_Merge @ConsentId = @ConsentId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Cust_LoyaltyTransaction_GetByCode @ConsentId = @ConsentId;
    IF @rc <> 0 RETURN @rc;
END
GO
