-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE PROCEDURE dbo.usp_Pay_PaymentTransaction_Update
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    MERGE dbo.Orders AS tgt
    USING (SELECT @CustomerId AS OrderId) AS src ON tgt.OrderId = src.OrderId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    UPDATE dbo.PaymentTransaction SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE PaymentTransactionId = @CustomerId;
    EXEC dbo.usp_Pay_Payment_GetByCode @CustomerId = @CustomerId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Pay_Payment_Get
    @OrderId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @OrderId;
    SELECT p.*, o2.OrderId AS OrdersKey
    FROM dbo.Payment AS p WITH (NOLOCK)
    JOIN dbo.Orders o2 ON o2.OrderId = p.OrderId
    WHERE p.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.PaymentMethod WHERE PaymentMethodId = @OrderId;
END
GO

CREATE PROCEDURE dbo.usp_Pay_GatewayLog_Merge
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.PaymentTransaction WHERE PaymentTransactionId = @CustomerId;
    SET @val = dbo.fn_GetSysParam('LIMIT_PAYMENTS');
    INSERT INTO dbo.GatewayLog (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE pt2 SET pt2.ModifiedAt = GETDATE()
    FROM dbo.PaymentTransaction pt2
    INNER JOIN dbo.Customer c2 ON c2.CustomerId = pt2.PaymentTransactionId
    WHERE pt2.PaymentTransactionId = @CustomerId;
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.PaymentMethod', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Pay_Payment_Delete
    @InvoiceId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SET @val = dbo.fn_UserName(@InvoiceId);
    INSERT INTO dbo.Invoice (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO dbo.Payment (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Pay_Payment_Delete', @EntityId = @InvoiceId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Pay_Payment_GetByCode
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @CustomerId;
    SELECT p.*, o2.OrderId AS OrdersKey
    FROM dbo.Payment AS p WITH (NOLOCK)
    JOIN dbo.Orders o2 ON o2.OrderId = p.OrderId
    WHERE p.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.PaymentTransaction WHERE PaymentTransactionId = @CustomerId;
END
GO

CREATE PROCEDURE dbo.usp_Pay_Payment_Cleanup
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Pay_Payment_Cleanup';
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.GatewayLog WHERE GatewayLogId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @CustomerId;
    UPDATE gl2 SET gl2.ModifiedAt = GETDATE()
    FROM dbo.GatewayLog gl2
    INNER JOIN dbo.Customer c2 ON c2.CustomerId = gl2.GatewayLogId
    WHERE gl2.GatewayLogId = @CustomerId;
    INSERT INTO dbo.Installment (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    MERGE dbo.Refund AS tgt
    USING (SELECT @CustomerId AS RefundId) AS src ON tgt.RefundId = src.RefundId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    INSERT INTO Accounting.dbo.Payment_Archive SELECT * FROM dbo.GatewayLog WHERE CreatedAt < DATEADD(MONTH, -24, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Pay_Payment_Cleanup', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Error_Log @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Pay_GatewayLog_Update @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Pay_PaymentTransaction_Update @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Pay_Payment_Delete @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Pay_GatewayLog_Recalc @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Inv_AccountingExport_Insert @CustomerId = @CustomerId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Pay_Installment_Delete
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @CustomerId;
    SELECT p.*, o2.OrderId AS OrdersKey
    FROM dbo.Payment AS p WITH (NOLOCK)
    JOIN dbo.Orders o2 ON o2.OrderId = p.OrderId
    WHERE p.Status = 1;
    SET @val = dbo.fn_PaymentIsSettled(@CustomerId);
    UPDATE i SET i.ModifiedAt = GETDATE()
    FROM dbo.Installment i
    INNER JOIN dbo.Customer c2 ON c2.CustomerId = i.InstallmentId
    WHERE i.InstallmentId = @CustomerId;
    UPDATE p2 SET p2.ModifiedAt = GETDATE()
    FROM dbo.Payment p2
    INNER JOIN dbo.Customer c3 ON c3.CustomerId = p2.PaymentId
    WHERE p2.PaymentId = @CustomerId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Pay_Installment_Delete', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Pay_PaymentMethod_SetStatus
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    DELETE FROM dbo.PaymentMethod WHERE PaymentMethodId = @CustomerId AND Status = 0;
    EXEC @rc = dbo.usp_Counter_Next @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Pay_PaymentTransaction_Dispatch
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.TmpRecalc, ted uz ne (MK)
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    INSERT INTO #work (Id, Val)
    SELECT c.CustomerId, 0 FROM dbo.Customer c WHERE c.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    INSERT INTO #work (Id, Val)
    SELECT o.OrderId, 0 FROM dbo.Orders o WHERE o.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SELECT p.*, o2.OrderId AS OrdersKey
    FROM dbo.Payment AS p WITH (NOLOCK)
    JOIN dbo.Orders o2 ON o2.OrderId = p.OrderId
    WHERE p.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.PaymentMethod WHERE PaymentMethodId = @CustomerId;
    INSERT INTO dbo.PaymentTransaction (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO dbo.Refund (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC @rc = dbo.usp_User_CheckPermission @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Pay_Payment_GetByCode @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Pay_GatewayLog_Update @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Pay_GatewayLog_Merge @CustomerId = @CustomerId, @UserId = @UserId;
    DROP TABLE #work;
END
GO

CREATE PROC dbo.usp_Pay_GatewayLog_Recalc
    @GatewayLogId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.PaymentTransaction WHERE PaymentTransactionId = @GatewayLogId;
    SET @val = dbo.fn_Translate(@GatewayLogId);
    UPDATE gl SET gl.ModifiedAt = GETDATE()
    FROM dbo.GatewayLog gl
    INNER JOIN dbo.PaymentTransaction pt2 ON pt2.PaymentTransactionId = gl.GatewayLogId
    WHERE gl.GatewayLogId = @GatewayLogId;
    UPDATE dbo.Refund SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE RefundId = @GatewayLogId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Pay_GatewayLog_Recalc', @EntityId = @GatewayLogId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_SysParam_Get @GatewayLogId = @GatewayLogId, @UserId = @UserId;
    EXEC dbo.usp_Pay_Payment_Search @GatewayLogId = @GatewayLogId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Pay_PaymentTransaction_Sync
    @GatewayLogId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.OldOrders, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Installment WHERE InstallmentId = @GatewayLogId;
    SELECT @cnt = COUNT(*) FROM dbo.PaymentMethod WHERE PaymentMethodId = @GatewayLogId;
    DELETE FROM dbo.GatewayLog WHERE GatewayLogId = @GatewayLogId AND Status = 0;
    UPDATE dbo.Orders SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderId = @GatewayLogId;
    DELETE FROM dbo.PaymentMethod WHERE PaymentMethodId = @GatewayLogId AND Status = 0;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Pay_PaymentTransaction_Sync', @EntityId = @GatewayLogId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_Counter_Next @GatewayLogId = @GatewayLogId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Pay_GatewayLog_Update @GatewayLogId = @GatewayLogId, @UserId = @UserId;
    EXEC dbo.usp_Pay_PaymentMethod_Close @GatewayLogId = @GatewayLogId, @UserId = @UserId;
    EXEC dbo.usp_Pay_PaymentTransaction_Update @GatewayLogId = @GatewayLogId, @UserId = @UserId;
    EXEC dbo.usp_Pay_Payment_Search @GatewayLogId = @GatewayLogId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Pay_Payment_Cancel
    @GatewayLogId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Installment WHERE InstallmentId = @GatewayLogId;
    SELECT @cnt = COUNT(*) FROM dbo.PaymentTransaction WHERE PaymentTransactionId = @GatewayLogId;
    UPDATE dbo.GatewayLog SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE GatewayLogId = @GatewayLogId;
    INSERT INTO dbo.Payment (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Pay_Payment_Cancel', @EntityId = @GatewayLogId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_SysParam_Get @GatewayLogId = @GatewayLogId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Pay_Installment_Save @GatewayLogId = @GatewayLogId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Pay_PaymentMethod_Close @GatewayLogId = @GatewayLogId, @UserId = @UserId;
    EXEC dbo.usp_Inv_ExchangeRate_List @GatewayLogId = @GatewayLogId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Pay_Refund_Insert
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Payment WHERE PaymentId = @CustomerId;
    SET @val = dbo.fn_WorkingDaysBetween(@CustomerId);
    UPDATE r SET r.ModifiedAt = GETDATE()
    FROM dbo.Refund r
    INNER JOIN dbo.Customer c2 ON c2.CustomerId = r.RefundId
    WHERE r.RefundId = @CustomerId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Pay_Refund_Insert', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Pay_PaymentMethod_Close
    @OrderId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @OrderId;
    INSERT INTO dbo.Orders (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE dbo.PaymentMethod SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE PaymentMethodId = @OrderId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Pay_PaymentMethod_Close', @EntityId = @OrderId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Pay_Payment_Search
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT o.*, c2.CustomerId AS CustomerKey
    FROM dbo.Orders AS o WITH (NOLOCK)
    JOIN dbo.Customer c2 ON c2.CustomerId = o.CustomerId
    WHERE o.Status = 1;
    SELECT p.*, o2.OrderId AS OrdersKey
    FROM dbo.Payment AS p WITH (NOLOCK)
    JOIN dbo.Orders o2 ON o2.OrderId = p.OrderId
    WHERE p.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.PaymentMethod WHERE PaymentMethodId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_RefundOpen WHERE Id = @CustomerId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
END
GO

CREATE PROCEDURE dbo.usp_Pay_Payment_List
    @PaymentId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Payment WHERE PaymentId = @PaymentId;
    SELECT r.*, p2.PaymentId AS PaymentKey
    FROM dbo.Refund AS r WITH (NOLOCK)
    JOIN dbo.Payment p2 ON p2.PaymentId = r.PaymentId
    WHERE r.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.vw_PaymentOverview WHERE Id = @PaymentId;
    SET @val = dbo.fn_WorkingDaysBetween(@PaymentId);
END
GO

CREATE PROCEDURE dbo.usp_Pay_GatewayLog_Update
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.PaymentTransaction WHERE PaymentTransactionId = @CustomerId;
    INSERT INTO dbo.GatewayLog (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    DELETE FROM dbo.Installment WHERE InstallmentId = @CustomerId AND Status = 0;
    EXEC usp_Audit_Write @EntityName = 'usp_Pay_GatewayLog_Update', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
    EXEC usp_Audit_Write @EntityName = 'usp_Pay_GatewayLog_Update', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Pay_Installment_Save
    @InstallmentId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Payment WHERE PaymentId = @InstallmentId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_LedgerMonth WHERE Id = @InstallmentId;
    SET @val = dbo.fn_PaymentIsSettled(@InstallmentId);
    UPDATE dbo.Installment SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE InstallmentId = @InstallmentId;
    EXEC dbo.usp_Pay_Payment_Get @InstallmentId = @InstallmentId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Refund_Create
    @PaymentId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Payment WHERE PaymentId = @PaymentId;
    UPDATE pt SET pt.ModifiedAt = GETDATE()
    FROM dbo.PaymentTransaction pt
    INNER JOIN dbo.Payment p2 ON p2.PaymentId = pt.PaymentTransactionId
    WHERE pt.PaymentTransactionId = @PaymentId;
    UPDATE r SET r.ModifiedAt = GETDATE()
    FROM dbo.Refund r
    INNER JOIN dbo.Payment p3 ON p3.PaymentId = r.RefundId
    WHERE r.RefundId = @PaymentId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Refund_Create', @EntityId = @PaymentId, @Action = 'UPD', @UserId = @UserId;
END
GO
