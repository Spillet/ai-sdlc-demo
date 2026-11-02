-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE PROCEDURE dbo.usp_Inv_ExchangeRate_List
    @ExchangeRateId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.OldOrders, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ExchangeRate WHERE ExchangeRateId = @ExchangeRateId;
    SET @val = dbo.fn_Translate(@ExchangeRateId);
END
GO

CREATE PROCEDURE dbo.usp_Inv_Invoice_GetDetail
    @InvoiceId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Invoice WHERE InvoiceId = @InvoiceId;
    SELECT le.*, i2.InvoiceId AS InvoiceKey
    FROM dbo.LedgerEntry AS le WITH (NOLOCK)
    JOIN dbo.Invoice i2 ON i2.InvoiceId = le.InvoiceId
    WHERE le.Status = 1;
END
GO

CREATE PROCEDURE dbo.usp_Inv_LedgerEntry_MonthClose
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Inv_LedgerEntry_MonthClose';
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.ExchangeRate WHERE ExchangeRateId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.LedgerEntry WHERE LedgerEntryId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_LedgerMonth WHERE Id = @CustomerId;
    UPDATE dbo.ExchangeRate SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ExchangeRateId = @CustomerId;
    UPDATE dbo.Invoice SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE InvoiceId = @CustomerId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Inv_LedgerEntry_MonthClose', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Error_Log @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC @rc = dbo.usp_JobRun_End @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Inv_ExchangeRate_List @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Inv_Invoice_GetDetail @CustomerId = @CustomerId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Inv_Invoice_Confirm
    @AccountingExportId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.AccountingExport WHERE AccountingExportId = @AccountingExportId;
    SELECT @cnt = COUNT(*) FROM dbo.LedgerEntry WHERE LedgerEntryId = @AccountingExportId;
    UPDATE cn SET cn.ModifiedAt = GETDATE()
    FROM dbo.CreditNote cn
    INNER JOIN dbo.AccountingExport ae2 ON ae2.AccountingExportId = cn.CreditNoteId
    WHERE cn.CreditNoteId = @AccountingExportId;
    DELETE FROM dbo.LedgerEntry WHERE LedgerEntryId = @AccountingExportId AND Status = 0;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Inv_Invoice_Confirm', @EntityId = @AccountingExportId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Inv_Invoice_Get @AccountingExportId = @AccountingExportId, @UserId = @UserId;
    EXEC dbo.usp_Inv_AccountingExport_Insert @AccountingExportId = @AccountingExportId, @UserId = @UserId;
    EXEC dbo.usp_Inv_CreditNote_Recalc @AccountingExportId = @AccountingExportId, @UserId = @UserId;
    EXEC dbo.usp_Inv_LedgerEntry_Find @AccountingExportId = @AccountingExportId, @UserId = @UserId;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Inv_AccountingExport_MonthClose
    @InvoiceItemId INT = NULL,
    @UserId INT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Inv_AccountingExport_MonthClose';
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @InvoiceItemId;
    SELECT @cnt = COUNT(*) FROM dbo.Payment WHERE PaymentId = @InvoiceItemId;
    INSERT INTO dbo.InvoiceItem (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    MERGE dbo.VatRate AS tgt
    USING (SELECT @InvoiceItemId AS VatRateId) AS src ON tgt.VatRateId = src.VatRateId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
    EXEC dbo.usp_JobRun_End @InvoiceItemId = @InvoiceItemId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Inv_Invoice_Get @InvoiceItemId = @InvoiceItemId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Inv_CreditNote_Recalc @InvoiceItemId = @InvoiceItemId, @UserId = @UserId;
    EXEC dbo.usp_Pay_GatewayLog_Recalc @InvoiceItemId = @InvoiceItemId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Inv_Invoice_Sync
    @InvoiceId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.LedgerEntry WHERE LedgerEntryId = @InvoiceId;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @InvoiceId;
    SELECT @cnt = COUNT(*) FROM dbo.Payment WHERE PaymentId = @InvoiceId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_InvoiceOverview WHERE Id = @InvoiceId;
    UPDATE i SET i.ModifiedAt = GETDATE()
    FROM dbo.Invoice i
    INNER JOIN dbo.InvoiceItem ii ON ii.InvoiceItemId = i.InvoiceId
    WHERE i.InvoiceId = @InvoiceId;
    UPDATE dbo.InvoiceItem SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE InvoiceItemId = @InvoiceId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.Invoice', @EntityId = @InvoiceId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Counter_Next @InvoiceId = @InvoiceId, @UserId = @UserId;
    EXEC dbo.usp_Inv_CreditNote_Recalc @InvoiceId = @InvoiceId, @UserId = @UserId;
    EXEC dbo.usp_Inv_ExchangeRate_Approve @InvoiceId = @InvoiceId, @UserId = @UserId;
    EXEC dbo.usp_Inv_LedgerEntry_Find @InvoiceId = @InvoiceId, @UserId = @UserId;
    EXEC dbo.usp_Inv_AccountingExport_List @InvoiceId = @InvoiceId, @UserId = @UserId;
    EXEC dbo.usp_Pay_GatewayLog_Recalc @InvoiceId = @InvoiceId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Inv_AccountingExport_Insert
    @AccountingExportId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    INSERT INTO dbo.AccountingExport (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE dbo.InvoiceItem SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE InvoiceItemId = @AccountingExportId;
END
GO

CREATE PROCEDURE dbo.usp_Inv_CreditNote_Recalc
    @CreditNoteId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Invoice WHERE InvoiceId = @CreditNoteId;
    DELETE FROM dbo.CreditNote WHERE CreditNoteId = @CreditNoteId AND Status = 0;
END
GO

CREATE PROCEDURE dbo.usp_Inv_ExchangeRate_Insert
    @ExchangeRateId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    UPDATE dbo.ExchangeRate SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ExchangeRateId = @ExchangeRateId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Inv_ExchangeRate_Insert', @EntityId = @ExchangeRateId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Inv_Invoice_Rebuild
    @AccountingExportId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @AccountingExportId;
    SET @val = dbo.fn_SplitString(@AccountingExportId);
    INSERT INTO dbo.AccountingExport (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE dbo.ExchangeRate SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ExchangeRateId = @AccountingExportId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Inv_Invoice_Rebuild', @EntityId = @AccountingExportId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Error_Log @AccountingExportId = @AccountingExportId, @UserId = @UserId;
    EXEC dbo.usp_Inv_LedgerEntry_Find @AccountingExportId = @AccountingExportId, @UserId = @UserId;
    EXEC dbo.usp_Inv_Invoice_Get @AccountingExportId = @AccountingExportId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Inv_Invoice_Check
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Invoice WHERE InvoiceId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @CustomerId;
END
GO

CREATE PROCEDURE dbo.usp_Inv_Invoice_Update
    @InvoiceId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.OldOrders, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @InvoiceId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @InvoiceId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_PaymentOverview WHERE Id = @InvoiceId;
    SET @val = dbo.fn_SplitString(@InvoiceId);
    UPDATE dbo.Invoice SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE InvoiceId = @InvoiceId;
    UPDATE dbo.Orders SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE OrderId = @InvoiceId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Inv_Invoice_Update', @EntityId = @InvoiceId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Inv_Invoice_Get
    @InvoiceId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT i.*, o.OrderId AS OrdersKey
    FROM dbo.Invoice AS i WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = i.OrderId
    WHERE i.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @InvoiceId;
    EXEC dbo.usp_Error_Log @InvoiceId = @InvoiceId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Inv_ExchangeRate_Approve
    @ExchangeRateId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.vw_InvoiceOverview WHERE Id = @ExchangeRateId;
    SET @val = dbo.fn_IsWorkingDay(@ExchangeRateId);
    INSERT INTO dbo.ExchangeRate (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Inv_ExchangeRate_Approve', @EntityId = @ExchangeRateId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Inv_LedgerEntry_Find
    @InvoiceId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT i.*, o.OrderId AS OrdersKey
    FROM dbo.Invoice AS i WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = i.OrderId
    WHERE i.Status = 1;
    SELECT le.*, i2.InvoiceId AS InvoiceKey
    FROM dbo.LedgerEntry AS le WITH (NOLOCK)
    JOIN dbo.Invoice i2 ON i2.InvoiceId = le.InvoiceId
    WHERE le.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @InvoiceId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @InvoiceId;
END
GO

CREATE PROCEDURE dbo.usp_Inv_Invoice_SetStatus
    @InvoiceId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    INSERT INTO dbo.Invoice (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Inv_Invoice_SetStatus', @EntityId = @InvoiceId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Error_Log @InvoiceId = @InvoiceId, @UserId = @UserId;
    EXEC dbo.usp_Inv_AccountingExport_List @InvoiceId = @InvoiceId, @UserId = @UserId;
END
GO

CREATE PROC dbo.usp_Inv_VatRate_Dispatch
    @AccountingExportId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.AccountingExport WHERE AccountingExportId = @AccountingExportId;
    SELECT @cnt = COUNT(*) FROM dbo.CreditNote WHERE CreditNoteId = @AccountingExportId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_LedgerMonth WHERE Id = @AccountingExportId;
    INSERT INTO dbo.CreditNote (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE vr SET vr.ModifiedAt = GETDATE()
    FROM dbo.VatRate vr
    INNER JOIN dbo.AccountingExport ae2 ON ae2.AccountingExportId = vr.VatRateId
    WHERE vr.VatRateId = @AccountingExportId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Inv_VatRate_Dispatch', @EntityId = @AccountingExportId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Inv_Invoice_Check @AccountingExportId = @AccountingExportId, @UserId = @UserId;
    EXEC dbo.usp_Inv_Invoice_SetStatus @AccountingExportId = @AccountingExportId, @UserId = @UserId;
    EXEC dbo.usp_Inv_ExchangeRate_Insert @AccountingExportId = @AccountingExportId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Inv_Invoice_Update @AccountingExportId = @AccountingExportId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Pay_Payment_Search @AccountingExportId = @AccountingExportId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Inv_Invoice_Hourly
    @CreditNoteId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Inv_Invoice_Hourly';
    SELECT @cnt = COUNT(*) FROM dbo.ExchangeRate WHERE ExchangeRateId = @CreditNoteId;
    SELECT i.*, o.OrderId AS OrdersKey
    FROM dbo.Invoice AS i WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = i.OrderId
    WHERE i.Status = 1;
    SELECT oi.*, o2.OrderId AS OrdersKey
    FROM dbo.OrderItem AS oi WITH (NOLOCK)
    JOIN dbo.Orders o2 ON o2.OrderId = oi.OrderId
    WHERE oi.Status = 1;
    INSERT INTO #work (Id, Val)
    SELECT o3.OrderId, 0 FROM dbo.Orders o3 WHERE o3.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SET @val = dbo.fn_GetSysParam('LIMIT_INVOICING');
    UPDATE dbo.CreditNote SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CreditNoteId = @CreditNoteId;
    INSERT INTO Accounting.dbo.Invoice_Archive SELECT * FROM dbo.CreditNote WHERE CreatedAt < DATEADD(MONTH, -24, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Inv_Invoice_Hourly', @EntityId = @CreditNoteId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @CreditNoteId = @CreditNoteId, @UserId = @UserId;
    EXEC dbo.usp_Inv_ExchangeRate_List @CreditNoteId = @CreditNoteId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Inv_Invoice_Get @CreditNoteId = @CreditNoteId;
    IF @rc <> 0 RETURN @rc;
    EXEC @rc = dbo.usp_Pay_Payment_Search @CreditNoteId = @CreditNoteId;
    IF @rc <> 0 RETURN @rc;
    DROP TABLE #work;
END
GO

CREATE PROC dbo.usp_Inv_AccountingExport_List
    @AccountingExportId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.OldOrders, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.AccountingExport WHERE AccountingExportId = @AccountingExportId;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @AccountingExportId;
    SET @val = dbo.fn_WorkingDaysBetween(@AccountingExportId);
END
GO

CREATE PROCEDURE dbo.usp_Inv_LedgerEntry_Rebuild
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.InvoiceItem WHERE InvoiceItemId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.VatRate WHERE VatRateId = @CustomerId;
    UPDATE dbo.Invoice SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE InvoiceId = @CustomerId;
    MERGE dbo.LedgerEntry AS tgt
    USING (SELECT @CustomerId AS LedgerEntryId) AS src ON tgt.LedgerEntryId = src.LedgerEntryId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_Inv_CreditNote_Recalc @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Inv_LedgerEntry_Find @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Inv_AccountingExport_Insert @CustomerId = @CustomerId, @UserId = @UserId;
    EXEC dbo.usp_Inv_ExchangeRate_Approve @CustomerId = @CustomerId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Inv_YearClose
    @AccountingExportId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Inv_YearClose';
    SELECT @cnt = COUNT(*) FROM dbo.Invoice WHERE InvoiceId = @AccountingExportId;
    SELECT le.*, i2.InvoiceId AS InvoiceKey
    FROM dbo.LedgerEntry AS le WITH (NOLOCK)
    JOIN dbo.Invoice i2 ON i2.InvoiceId = le.InvoiceId
    WHERE le.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.VatRate WHERE VatRateId = @AccountingExportId;
    INSERT INTO dbo.AccountingExport (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE le2 SET le2.ModifiedAt = GETDATE()
    FROM dbo.LedgerEntry le2
    INNER JOIN dbo.Invoice i3 ON i3.InvoiceId = le2.LedgerEntryId
    WHERE le2.LedgerEntryId = @AccountingExportId;
    INSERT INTO Accounting.dbo.YearBalance SELECT * FROM dbo.AccountingExport WHERE CreatedAt < DATEADD(MONTH, -24, GETDATE());
    EXEC @rc = dbo.usp_JobRun_End @AccountingExportId = @AccountingExportId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Inv_YearClose', @EntityId = @AccountingExportId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Inv_AccountingExport_Insert @AccountingExportId = @AccountingExportId, @UserId = @UserId;
    EXEC dbo.usp_Inv_ExchangeRate_Insert @AccountingExportId = @AccountingExportId, @UserId = @UserId;
    EXEC dbo.usp_Inv_CreditNote_Recalc @AccountingExportId = @AccountingExportId, @UserId = @UserId;
    EXEC dbo.usp_Pay_Payment_Search @AccountingExportId = @AccountingExportId, @UserId = @UserId;
END
GO
