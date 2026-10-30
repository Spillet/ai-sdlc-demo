-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE PROCEDURE dbo.usp_Claim_Create
    @OrderItemId      INT,
    @Qty              INT,
    @ReasonCode       VARCHAR(20),
    @DefectText       NVARCHAR(2000),
    @UserId           INT,
    @ClaimId          INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @OrderId INT, @CustomerId INT, @PurchasedAt DATETIME2, @IsBusiness BIT,
            @OrderedQty INT, @AlreadyClaimed INT, @ClaimNumber VARCHAR(20), @Seq BIGINT,
            @Deadline DATE;

    SELECT @OrderId = o.OrderId, @CustomerId = o.CustomerId, @PurchasedAt = o.CreatedAt,
           @IsBusiness = c.IsBusiness, @OrderedQty = oi.Qty
    FROM dbo.OrderItem AS oi
    JOIN dbo.Orders    AS o ON o.OrderId = oi.OrderId
    JOIN dbo.Customer  AS c ON c.CustomerId = o.CustomerId
    WHERE oi.OrderItemId = @OrderItemId;

    IF @OrderId IS NULL
    BEGIN
        RAISERROR(N'Polozka objednavky %d neexistuje.', 16, 1, @OrderItemId);
        RETURN 1;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.ClaimReason WHERE Code = @ReasonCode)
    BEGIN
        RAISERROR(N'Neznamy duvod reklamace.', 16, 1);
        RETURN 2;
    END

    -- zakonna lhuta: spotrebitel 24 mesicu, firma 12 (viz fn_Claim_Deadline)
    SET @Deadline = dbo.fn_Claim_Deadline(@PurchasedAt, @IsBusiness);
    IF @Deadline < CAST(GETDATE() AS DATE)
    BEGIN
        RAISERROR(N'Lhuta pro reklamaci vyprsela.', 16, 1);
        RETURN 3;
    END

    SELECT @AlreadyClaimed = ISNULL(SUM(ci.Qty), 0)
    FROM dbo.ClaimItem AS ci
    JOIN dbo.Claim     AS cl ON cl.ClaimId = ci.ClaimId
    WHERE ci.OrderItemId = @OrderItemId AND cl.Status <> 9;   -- 9 = zamitnuta

    IF @AlreadyClaimed + @Qty > @OrderedQty
    BEGIN
        RAISERROR(N'Reklamovane mnozstvi prevysuje objednane.', 16, 1);
        RETURN 4;
    END

    BEGIN TRY
        BEGIN TRAN;

        EXEC dbo.usp_Counter_Next @Name = 'CLAIM', @Value = @Seq OUTPUT;
        SET @ClaimNumber = 'R' + RIGHT('000000000' + CAST(@Seq AS VARCHAR(20)), 9);

        INSERT INTO dbo.Claim (OrderId, CustomerId, ServiceCenterId, ClaimNumber, ClaimType, Status, DeadlineAt, CreatedAt)
        VALUES (@OrderId, @CustomerId, NULL, @ClaimNumber, @ReasonCode, 1,
                DATEADD(DAY, 30, CAST(GETDATE() AS DATE)), GETDATE());   -- 30 dni na vyrizeni
        SET @ClaimId = SCOPE_IDENTITY();

        INSERT INTO dbo.ClaimItem (ClaimId, OrderItemId, Qty, DefectDescription, Status, CreatedAt)
        VALUES (@ClaimId, @OrderItemId, @Qty, @DefectText, 1, GETDATE());

        INSERT INTO dbo.ClaimStatusHistory (ClaimId, OldStatus, NewStatus, Note, Status, CreatedAt)
        VALUES (@ClaimId, 0, 1, N'Zalozeno', 1, GETDATE());

        EXEC dbo.usp_Audit_Write @EntityName = 'Claim', @EntityId = @ClaimId, @Action = 'CREATE', @UserId = @UserId;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        EXEC dbo.usp_Error_Log @ProcName = 'usp_Claim_Create', @Message = @msg;
        THROW;
    END CATCH
    RETURN 0;
END
GO

CREATE PROCEDURE dbo.usp_Claim_GetDetail
    @ClaimId INT,
    @UserId  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @UserId IS NOT NULL
    BEGIN
        DECLARE @allowed BIT;
        EXEC dbo.usp_User_CheckPermission @UserId = @UserId, @Permission = 'CLAIM_READ', @Allowed = @allowed OUTPUT;
        IF @allowed = 0 RETURN 5;
    END

    -- 1) hlavicka
    SELECT cl.ClaimId, cl.ClaimNumber, cl.ClaimType, cl.Status, cl.Resolution, cl.DeadlineAt, cl.CreatedAt,
           o.OrderNumber, o.CreatedAt AS OrderedAt,
           c.CustomerId, c.Name AS CustomerName, c.Email, c.IsBusiness,
           sc.Name AS ServiceCenterName, sc.City AS ServiceCenterCity,
           DATEDIFF(DAY, CAST(GETDATE() AS DATE), cl.DeadlineAt) AS DaysLeft
    FROM dbo.Claim AS cl WITH (NOLOCK)
    JOIN dbo.Orders AS o WITH (NOLOCK) ON o.OrderId = cl.OrderId
    JOIN dbo.Customer AS c WITH (NOLOCK) ON c.CustomerId = cl.CustomerId
    LEFT JOIN dbo.ServiceCenter AS sc ON sc.ServiceCenterId = cl.ServiceCenterId
    WHERE cl.ClaimId = @ClaimId;

    -- 2) polozky
    SELECT ti.ClaimItemId, ti.OrderItemId, ti.ProductCode, ti.ProductName, ti.Qty, ti.UnitPrice, ti.DefectDescription
    FROM dbo.tvf_ClaimItems(@ClaimId) AS ti
    ORDER BY ti.ClaimItemId;

    -- 3) historie stavu
    SELECT h.OldStatus, h.NewStatus, h.Note, h.CreatedAt, dbo.fn_UserName(h.CreatedBy) AS ChangedBy
    FROM dbo.ClaimStatusHistory AS h
    WHERE h.ClaimId = @ClaimId
    ORDER BY h.CreatedAt;

    -- 4) dokumenty
    SELECT d.ClaimDocumentId, d.FileName, d.StorageKey, d.CreatedAt
    FROM dbo.ClaimDocument AS d
    WHERE d.ClaimId = @ClaimId;
END
GO

CREATE PROCEDURE dbo.usp_Claim_SetStatus
    @ClaimId    INT,
    @NewStatus  TINYINT,          -- 1 nova, 2 v servisu, 3 uznana-oprava, 4 uznana-vymena, 5 uznana-dobropis, 9 zamitnuta
    @Note       NVARCHAR(400) = NULL,
    @UserId     INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @OldStatus TINYINT, @OrderId INT, @PaymentId INT, @Amount DECIMAL(12,2);

    SELECT @OldStatus = Status, @OrderId = OrderId FROM dbo.Claim WHERE ClaimId = @ClaimId;
    IF @OldStatus IS NULL RETURN 1;
    IF @OldStatus IN (5, 9) AND @NewStatus <> @OldStatus
    BEGIN
        RAISERROR(N'Uzavrenou reklamaci nelze menit.', 16, 1);
        RETURN 2;
    END

    BEGIN TRAN;

    UPDATE dbo.Claim
    SET Status = @NewStatus,
        Resolution = CASE @NewStatus WHEN 3 THEN 'REPAIR' WHEN 4 THEN 'REPLACE' WHEN 5 THEN 'REFUND' WHEN 9 THEN 'REJECTED' ELSE Resolution END,
        ModifiedAt = GETDATE()
    WHERE ClaimId = @ClaimId;

    INSERT INTO dbo.ClaimStatusHistory (ClaimId, OldStatus, NewStatus, Note, Status, CreatedAt, CreatedBy)
    VALUES (@ClaimId, @OldStatus, @NewStatus, @Note, 1, GETDATE(), @UserId);

    IF @NewStatus = 4
    BEGIN
        -- vymena: odepsat kus ze skladu primo (historicky, sklad o tom nevi jinak nez triggerem)
        UPDATE sl
        SET sl.QtyOnHand = sl.QtyOnHand - ci.Qty, sl.ModifiedAt = GETDATE()
        FROM dbo.StockLevel AS sl
        JOIN dbo.OrderItem  AS oi ON oi.ProductId = sl.ProductId
        JOIN dbo.ClaimItem  AS ci ON ci.OrderItemId = oi.OrderItemId
        WHERE ci.ClaimId = @ClaimId
          AND sl.WarehouseId = 1;   -- centralni sklad natvrdo
    END

    IF @NewStatus = 5
    BEGIN
        SELECT TOP (1) @PaymentId = p.PaymentId FROM dbo.Payment AS p WHERE p.OrderId = @OrderId ORDER BY p.CreatedAt DESC;
        SELECT @Amount = SUM(ci.Qty * oi.UnitPrice)
        FROM dbo.ClaimItem AS ci JOIN dbo.OrderItem AS oi ON oi.OrderItemId = ci.OrderItemId
        WHERE ci.ClaimId = @ClaimId;
        EXEC dbo.usp_Refund_Create @PaymentId = @PaymentId, @Amount = @Amount, @Reason = N'Reklamace', @UserId = @UserId;
    END

    EXEC dbo.usp_Audit_Write @EntityName = 'Claim', @EntityId = @ClaimId, @Action = 'STATUS', @UserId = @UserId;

    COMMIT;
    RETURN 0;
END
GO

CREATE PROCEDURE dbo.usp_Claim_Search
    @ClaimNumber VARCHAR(20) = NULL,
    @CustomerEmail NVARCHAR(200) = NULL,
    @Status TINYINT = NULL,
    @CreatedFrom DATE = NULL,
    @Top INT = 200
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'SELECT TOP (@Top) cl.ClaimId, cl.ClaimNumber, cl.Status, cl.CreatedAt, c.Name, o.OrderNumber
FROM dbo.Claim cl
JOIN dbo.Customer c ON c.CustomerId = cl.CustomerId
JOIN dbo.Orders o ON o.OrderId = cl.OrderId
WHERE 1 = 1';
    IF @ClaimNumber IS NOT NULL SET @sql += N' AND cl.ClaimNumber = @ClaimNumber';
    IF @CustomerEmail IS NOT NULL SET @sql += N' AND c.Email LIKE @CustomerEmail + ''%''';
    IF @Status IS NOT NULL SET @sql += N' AND cl.Status = @Status';
    IF @CreatedFrom IS NOT NULL SET @sql += N' AND cl.CreatedAt >= @CreatedFrom';
    SET @sql += N' ORDER BY cl.CreatedAt DESC';

    EXEC sp_executesql @sql,
        N'@Top INT, @ClaimNumber VARCHAR(20), @CustomerEmail NVARCHAR(200), @Status TINYINT, @CreatedFrom DATE',
        @Top, @ClaimNumber, @CustomerEmail, @Status, @CreatedFrom;
END
GO

CREATE PROCEDURE dbo.usp_Claim_OverdueCheck
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @run BIGINT, @warnDays INT, @ClaimId INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'ClaimOverdue', @RunId = @run OUTPUT;

    SELECT @warnDays = CAST(Value AS INT) FROM dbo.SysParam WHERE Name = 'CLAIM_WARN_DAYS';

    -- oznacit reklamace, kterym konci zakonna lhuta 30 dni
    UPDATE dbo.Claim SET Status = 7, ModifiedAt = GETDATE()     -- 7 = hrozi prekroceni lhuty
    WHERE Status IN (1, 2) AND dbo.fn_WorkingDaysBetween(GETDATE(), DeadlineAt) <= @warnDays;

    INSERT INTO dbo.ClaimStatusHistory (ClaimId, OldStatus, NewStatus, Note, Status, CreatedAt)
    SELECT ClaimId, 2, 7, N'Automaticky: blizi se lhuta', 1, GETDATE()
    FROM dbo.Claim WHERE Status = 7 AND ModifiedAt >= DATEADD(MINUTE, -5, GETDATE());

    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT ClaimId FROM dbo.Claim WHERE Status = 7;
    OPEN c;
    FETCH NEXT FROM c INTO @ClaimId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.usp_Claim_Notify @ClaimId = @ClaimId;
        FETCH NEXT FROM c INTO @ClaimId;
    END
    CLOSE c; DEALLOCATE c;

    EXEC dbo.usp_JobRun_End @RunId = @run;
END
GO

CREATE PROCEDURE dbo.usp_Claim_Notify
    @ClaimId INT
AS
BEGIN
    SET NOCOUNT ON;
    -- e-mail neposilame z DB, jen zaradime do fronty pro exportni sluzbu
    INSERT INTO dbo.ExportQueue (HandlerProc, Payload, Status, CreatedAt)
    SELECT 'usp_Rpt_Export_Email',
           (SELECT c.Email, cl.ClaimNumber, dbo.fn_Translate('CLAIM_OVERDUE', 'cs') AS Body
            FROM dbo.Claim cl JOIN dbo.Customer c ON c.CustomerId = cl.CustomerId
            WHERE cl.ClaimId = @ClaimId FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           1, GETDATE();
END
GO

CREATE PROCEDURE dbo.usp_Claim_ServiceCenter_Merge
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @CustomerId;
    DELETE FROM dbo.ServiceCenter WHERE ServiceCenterId = @CustomerId AND Status = 0;
END
GO

CREATE PROCEDURE dbo.usp_Claim_Claim_Delete
    @ClaimId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ServiceCenter WHERE ServiceCenterId = @ClaimId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_ClaimOverview WHERE Id = @ClaimId;
    SET @val = dbo.fn_GetSysParam('LIMIT_CLAIMS');
    UPDATE c SET c.ModifiedAt = GETDATE()
    FROM dbo.Claim c
    INNER JOIN dbo.ServiceCenter sc2 ON sc2.ServiceCenterId = c.ClaimId
    WHERE c.ClaimId = @ClaimId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Claim_Claim_Delete', @EntityId = @ClaimId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Claim_Claim_Overview
    @ClaimId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT c.*, c2.CustomerId AS CustomerKey
    FROM dbo.Claim AS c WITH (NOLOCK)
    JOIN dbo.Customer c2 ON c2.CustomerId = c.CustomerId
    WHERE c.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @ClaimId;
    SELECT @cnt = COUNT(*) FROM dbo.ServiceCenter WHERE ServiceCenterId = @ClaimId;
    SELECT * FROM dbo.tvf_ClaimItems(@ClaimId);
END
GO

CREATE PROCEDURE dbo.usp_Claim_ClaimItem_GetByCode
    @ClaimItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ClaimItem WHERE ClaimItemId = @ClaimItemId;
    SET @val = dbo.fn_IsWorkingDay(@ClaimItemId);
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'SELECT TOP (500) * FROM dbo.ClaimReason WHERE 1 = 1';
    SET @sql += N' ORDER BY CreatedAt DESC';
    EXEC sp_executesql @sql, N'@s TINYINT', @s = 1;
END
GO

CREATE PROCEDURE dbo.usp_Claim_ClaimStatusHistory_Merge
    @ClaimId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Claim WHERE ClaimId = @ClaimId;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @ClaimId;
    SET @val = dbo.fn_IsWorkingDay(@ClaimId);
    MERGE dbo.ClaimStatusHistory AS tgt
    USING (SELECT @ClaimId AS ClaimStatusHistoryId) AS src ON tgt.ClaimStatusHistoryId = src.ClaimStatusHistoryId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.ClaimStatusHistory', @EntityId = @ClaimId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_Error_Log @ClaimId = @ClaimId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Claim_ClaimStatusHistory_Cleanup
    @ClaimId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Claim_ClaimStatusHistory_Cleanup';
    SELECT @cnt = COUNT(*) FROM dbo.ClaimDocument WHERE ClaimDocumentId = @ClaimId;
    SELECT @cnt = COUNT(*) FROM dbo.ReturnRequest WHERE ReturnRequestId = @ClaimId;
    SELECT * FROM dbo.tvf_ClaimItems(@ClaimId);
    UPDATE dbo.Claim SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ClaimId = @ClaimId;
    INSERT INTO dbo.ClaimItem (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    MERGE dbo.ReturnRequest AS tgt
    USING (SELECT @ClaimId AS ReturnRequestId) AS src ON tgt.ReturnRequestId = src.ReturnRequestId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Claim_ClaimStatusHistory_Cleanup', @EntityId = @ClaimId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_Claim_Delete @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_Claim_Overview @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_ClaimStatusHistory_Delete @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_ClaimStatusHistory_Merge @ClaimId = @ClaimId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Claim_ClaimStatusHistory_Confirm
    @ClaimItemId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.ClaimReason WHERE ClaimReasonId = @ClaimItemId;
    SELECT @cnt = COUNT(*) FROM dbo.ReturnRequest WHERE ReturnRequestId = @ClaimItemId;
    SET @val = dbo.fn_UserName(@ClaimItemId);
    UPDATE dbo.ClaimItem SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ClaimItemId = @ClaimItemId;
    UPDATE dbo.ClaimStatusHistory SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ClaimStatusHistoryId = @ClaimItemId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Claim_ClaimStatusHistory_Confirm', @EntityId = @ClaimItemId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_Claim_ClaimStatusHistory_Delete @ClaimItemId = @ClaimItemId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Claim_Claim_Delete @ClaimItemId = @ClaimItemId, @UserId = @UserId;
    EXEC dbo.usp_Claim_ClaimItem_GetByCode @ClaimItemId = @ClaimItemId, @UserId = @UserId;
    EXEC dbo.usp_Claim_ServiceCenter_Merge @ClaimItemId = @ClaimItemId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Pay_GatewayLog_Update @ClaimItemId = @ClaimItemId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Claim_Claim_Archive
    @ClaimId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Claim_Claim_Archive';
    SELECT c.*, o.OrderId AS OrdersKey
    FROM dbo.Claim AS c WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = c.OrderId
    WHERE c.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.ClaimDocument WHERE ClaimDocumentId = @ClaimId;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @ClaimId;
    SELECT o2.*, c3.CustomerId AS CustomerKey
    FROM dbo.Orders AS o2 WITH (NOLOCK)
    JOIN dbo.Customer c3 ON c3.CustomerId = o2.CustomerId
    WHERE o2.Status = 1;
    INSERT INTO dbo.ReturnRequest (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.Claim', @EntityId = @ClaimId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_Claim_Delete @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Claim_ClaimStatusHistory_Merge @ClaimId = @ClaimId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Claim_Claim_Get @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_Claim_Overview @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Pay_PaymentMethod_SetStatus @ClaimId = @ClaimId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Claim_Claim_Insert
    @ClaimId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.OldOrders, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SET @val = dbo.fn_IsWorkingDay(@ClaimId);
    UPDATE dbo.Claim SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ClaimId = @ClaimId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Claim_Claim_Insert', @EntityId = @ClaimId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Claim_ClaimStatusHistory_Delete
    @ClaimDocumentId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT oi.*, o.OrderId AS OrdersKey
    FROM dbo.OrderItem AS oi WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = oi.OrderId
    WHERE oi.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @ClaimDocumentId;
    UPDATE cd SET cd.ModifiedAt = GETDATE()
    FROM dbo.ClaimDocument cd
    INNER JOIN dbo.OrderItem oi2 ON oi2.OrderItemId = cd.ClaimDocumentId
    WHERE cd.ClaimDocumentId = @ClaimDocumentId;
    UPDATE dbo.ClaimStatusHistory SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ClaimStatusHistoryId = @ClaimDocumentId;
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.ClaimStatusHistory', @EntityId = @ClaimDocumentId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Error_Log @ClaimDocumentId = @ClaimDocumentId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Claim_ClaimReason_Hourly
    @ClaimItemId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Claim_ClaimReason_Hourly';
    SELECT @cnt = COUNT(*) FROM dbo.ClaimItem WHERE ClaimItemId = @ClaimItemId;
    SELECT @cnt = COUNT(*) FROM dbo.ServiceCenter WHERE ServiceCenterId = @ClaimItemId;
    INSERT INTO dbo.ClaimStatusHistory (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.ReturnRequest', @EntityId = @ClaimItemId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @ClaimItemId = @ClaimItemId, @UserId = @UserId;
    EXEC dbo.usp_Claim_Claim_Delete @ClaimItemId = @ClaimItemId, @UserId = @UserId;
    EXEC dbo.usp_Claim_ServiceCenter_Merge @ClaimItemId = @ClaimItemId, @UserId = @UserId;
    EXEC dbo.usp_Pay_Installment_Save @ClaimItemId = @ClaimItemId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Claim_ClaimReason_Cleanup
    @ClaimId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Claim_ClaimReason_Cleanup';
    SELECT @cnt = COUNT(*) FROM dbo.Claim WHERE ClaimId = @ClaimId;
    SELECT csh.*, c2.ClaimId AS ClaimKey
    FROM dbo.ClaimStatusHistory AS csh WITH (NOLOCK)
    JOIN dbo.Claim c2 ON c2.ClaimId = csh.ClaimId
    WHERE csh.Status = 1;
    DELETE FROM dbo.ClaimDocument WHERE ClaimDocumentId = @ClaimId AND Status = 0;
    MERGE dbo.ReturnRequest AS tgt
    USING (SELECT @ClaimId AS ReturnRequestId) AS src ON tgt.ReturnRequestId = src.ReturnRequestId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Claim_ClaimReason_Cleanup', @EntityId = @ClaimId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_ClaimStatusHistory_Delete @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Claim_Claim_Overview @ClaimId = @ClaimId, @UserId = @UserId;
    EXEC dbo.usp_Pay_Refund_Insert @ClaimId = @ClaimId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Claim_Claim_Get
    @ClaimId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT c.*, sc.ServiceCenterId AS ServiceCenterKey
    FROM dbo.Claim AS c WITH (NOLOCK)
    JOIN dbo.ServiceCenter sc ON sc.ServiceCenterId = c.ServiceCenterId
    WHERE c.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Product WHERE ProductId = @ClaimId;
    SELECT @cnt = COUNT(*) FROM dbo.ServiceCenter WHERE ServiceCenterId = @ClaimId;
    SET @val = dbo.fn_GetSysParam('LIMIT_CLAIMS');
    EXEC usp_Audit_Write @EntityName = 'usp_Claim_Claim_Get', @EntityId = @ClaimId, @Action = 'UPD', @UserId = @UserId;
END
GO
