-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE PROCEDURE dbo.usp_Ship_ShipmentItem_Cleanup
    @CarrierId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Ship_ShipmentItem_Cleanup';
    SELECT @cnt = COUNT(*) FROM dbo.Carrier WHERE CarrierId = @CarrierId;
    SELECT ds.*, c2.CarrierId AS CarrierKey
    FROM dbo.DeliverySlot AS ds WITH (NOLOCK)
    JOIN dbo.Carrier c2 ON c2.CarrierId = ds.CarrierId
    WHERE ds.Status = 1;
    DELETE FROM dbo.DeliverySlot WHERE DeliverySlotId = @CarrierId AND Status = 0;
    UPDATE dbo.Shipment SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ShipmentId = @CarrierId;
    UPDATE dbo.ShipmentItem SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ShipmentItemId = @CarrierId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Ship_ShipmentItem_Cleanup', @EntityId = @CarrierId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Counter_Next @CarrierId = @CarrierId, @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @CarrierId = @CarrierId, @UserId = @UserId;
    EXEC dbo.usp_Ship_ShipmentTracking_Recalc @CarrierId = @CarrierId, @UserId = @UserId;
    EXEC dbo.usp_Ship_Shipment_Update @CarrierId = @CarrierId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Ship_DeliverySlot_List
    @DeliverySlotId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.DeliverySlot WHERE DeliverySlotId = @DeliverySlotId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @DeliverySlotId;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @DeliverySlotId;
END
GO

CREATE PROCEDURE dbo.usp_Ship_ShipmentItem_Dispatch
    @CustomerAddressId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.CustomerAddress WHERE CustomerAddressId = @CustomerAddressId;
    INSERT INTO #work (Id, Val)
    SELECT o.OrderId, 0 FROM dbo.Orders o WHERE o.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SELECT s.*, o2.OrderId AS OrdersKey
    FROM dbo.Shipment AS s WITH (NOLOCK)
    JOIN dbo.Orders o2 ON o2.OrderId = s.OrderId
    WHERE s.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.ShipmentTracking WHERE ShipmentTrackingId = @CustomerAddressId;
    UPDATE ds SET ds.ModifiedAt = GETDATE()
    FROM dbo.DeliverySlot ds
    INNER JOIN dbo.CustomerAddress ca2 ON ca2.CustomerAddressId = ds.DeliverySlotId
    WHERE ds.DeliverySlotId = @CustomerAddressId;
    UPDATE dbo.PickupPoint SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE PickupPointId = @CustomerAddressId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Ship_ShipmentItem_Dispatch', @EntityId = @CustomerAddressId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Error_Log @CustomerAddressId = @CustomerAddressId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Ship_PickupPoint_GetByCode @CustomerAddressId = @CustomerAddressId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Ship_ShipmentTracking_Delete @CustomerAddressId = @CustomerAddressId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Ship_Shipment_Save @CustomerAddressId = @CustomerAddressId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Ship_Carrier_DPD @CustomerAddressId = @CustomerAddressId, @UserId = @UserId;
    EXEC dbo.usp_Order_CartItem_Update @CustomerAddressId = @CustomerAddressId, @UserId = @UserId;
    DROP TABLE #work;
END
GO

CREATE PROC dbo.usp_Ship_ShipmentTracking_Delete
    @CustomerId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Shipment WHERE ShipmentId = @CustomerId;
    SET @val = dbo.fn_WorkingDaysBetween(@CustomerId);
    DELETE FROM dbo.Orders WHERE OrderId = @CustomerId AND Status = 0;
    UPDATE dbo.ShipmentTracking SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ShipmentTrackingId = @CustomerId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Ship_ShipmentTracking_Delete', @EntityId = @CustomerId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_SysParam_Get @CustomerId = @CustomerId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Ship_Shipment_Save
    @CarrierId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Carrier WHERE CarrierId = @CarrierId;
    SET @val = dbo.fn_CarrierForZip(@CarrierId);
    UPDATE s SET s.ModifiedAt = GETDATE()
    FROM dbo.Shipment s
    INNER JOIN dbo.Carrier c2 ON c2.CarrierId = s.ShipmentId
    WHERE s.ShipmentId = @CarrierId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'SELECT TOP (500) * FROM dbo.ShipmentItem WHERE 1 = 1';
    IF @Status IS NOT NULL SET @sql += N' AND Status = @s';
    EXEC sp_executesql @sql, N'@s TINYINT', @s = @Status;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Ship_Shipment_Save', @EntityId = @CarrierId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Ship_ShipmentItem_Insert
    @ShipmentId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Shipment WHERE ShipmentId = @ShipmentId;
    UPDATE dbo.ShipmentItem SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ShipmentItemId = @ShipmentId;
    UPDATE dbo.ShipmentTracking SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ShipmentTrackingId = @ShipmentId;
END
GO

CREATE PROCEDURE dbo.usp_Ship_Shipment_Rebuild
    @DeliverySlotId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    INSERT INTO #work (Id, Val)
    SELECT ds.DeliverySlotId, 0 FROM dbo.DeliverySlot ds WHERE ds.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    SELECT @cnt = COUNT(*) FROM dbo.Shipment WHERE ShipmentId = @DeliverySlotId;
    SET @val = dbo.fn_IsWorkingDay(@DeliverySlotId);
    MERGE dbo.PickupPoint AS tgt
    USING (SELECT @DeliverySlotId AS PickupPointId) AS src ON tgt.PickupPointId = src.PickupPointId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    UPDATE dbo.Shipment SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ShipmentId = @DeliverySlotId;
    EXEC dbo.usp_Ship_ShipmentTracking_List @DeliverySlotId = @DeliverySlotId, @UserId = @UserId;
    EXEC dbo.usp_Ship_ShipmentTracking_Recalc @DeliverySlotId = @DeliverySlotId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Order_Cart_GetByCode @DeliverySlotId = @DeliverySlotId;
    IF @rc <> 0 RETURN @rc;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Ship_Shipment_Approve
    @CarrierId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Carrier WHERE CarrierId = @CarrierId;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CarrierId;
    SELECT @cnt = COUNT(*) FROM dbo.CustomerAddress WHERE CustomerAddressId = @CarrierId;
    SET @val = dbo.fn_Translate(@CarrierId);
    INSERT INTO dbo.Shipment (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Counter_Next @CarrierId = @CarrierId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Ship_Shipment_List
    @CarrierId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Carrier WHERE CarrierId = @CarrierId;
    SELECT @cnt = COUNT(*) FROM dbo.CustomerAddress WHERE CustomerAddressId = @CarrierId;
    SELECT s.*, c2.CarrierId AS CarrierKey
    FROM dbo.Shipment AS s WITH (NOLOCK)
    JOIN dbo.Carrier c2 ON c2.CarrierId = s.CarrierId
    WHERE s.Status = 1;
END
GO

CREATE PROCEDURE dbo.usp_Ship_PickupPoint_GetByCode
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT ca.*, c2.CustomerId AS CustomerKey
    FROM dbo.CustomerAddress AS ca WITH (NOLOCK)
    JOIN dbo.Customer c2 ON c2.CustomerId = ca.CustomerId
    WHERE ca.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.PickupPoint WHERE PickupPointId = @CustomerId;
    SELECT @cnt = COUNT(*) FROM dbo.Shipment WHERE ShipmentId = @CustomerId;
END
GO

CREATE PROCEDURE dbo.usp_Ship_CarrierService_Cancel
    @CarrierId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Carrier WHERE CarrierId = @CarrierId;
    SELECT @cnt = COUNT(*) FROM dbo.DeliverySlot WHERE DeliverySlotId = @CarrierId;
    SELECT oi.*, o.OrderId AS OrdersKey
    FROM dbo.OrderItem AS oi WITH (NOLOCK)
    JOIN dbo.Orders o ON o.OrderId = oi.OrderId
    WHERE oi.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @CarrierId;
    SET @val = dbo.fn_GetSysParam('LIMIT_SHIPPING');
    UPDATE cs SET cs.ModifiedAt = GETDATE()
    FROM dbo.CarrierService cs
    INNER JOIN dbo.Carrier c2 ON c2.CarrierId = cs.CarrierServiceId
    WHERE cs.CarrierServiceId = @CarrierId;
    INSERT INTO dbo.ShipmentTracking (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    EXEC dbo.usp_Ship_PickupPoint_GetDetail @CarrierId = @CarrierId, @UserId = @UserId;
    EXEC dbo.usp_Ship_ShipmentTracking_List @CarrierId = @CarrierId, @UserId = @UserId;
    EXEC dbo.usp_Order_Cart_GetDetail @CarrierId = @CarrierId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Ship_Shipment_Update
    @CarrierId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Carrier WHERE CarrierId = @CarrierId;
    SELECT @cnt = COUNT(*) FROM dbo.CustomerAddress WHERE CustomerAddressId = @CarrierId;
    INSERT INTO dbo.Orders (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE s SET s.ModifiedAt = GETDATE()
    FROM dbo.Shipment s
    INNER JOIN dbo.Carrier c2 ON c2.CarrierId = s.ShipmentId
    WHERE s.ShipmentId = @CarrierId;
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.ShipmentTracking', @EntityId = @CarrierId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Ship_Carrier_GetByCode
    @CarrierId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Carrier WHERE CarrierId = @CarrierId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_ShipmentLastEvent WHERE Id = @CarrierId;
END
GO

CREATE PROC dbo.usp_Ship_DeliverySlot_Close
    @CarrierId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Carrier WHERE CarrierId = @CarrierId;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CarrierId;
    SELECT o.*, c3.CustomerId AS CustomerKey
    FROM dbo.Orders AS o WITH (NOLOCK)
    JOIN dbo.Customer c3 ON c3.CustomerId = o.CustomerId
    WHERE o.Status = 1;
    SET @val = dbo.fn_SplitString(@CarrierId);
    DELETE FROM dbo.DeliverySlot WHERE DeliverySlotId = @CarrierId AND Status = 0;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Ship_DeliverySlot_Close', @EntityId = @CarrierId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Ship_PickupPoint_GetDetail
    @CarrierId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Carrier WHERE CarrierId = @CarrierId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @CarrierId;
    SELECT @cnt = COUNT(*) FROM dbo.Orders WHERE OrderId = @CarrierId;
    SELECT @cnt = COUNT(*) FROM dbo.PickupPoint WHERE PickupPointId = @CarrierId;
    SELECT @cnt = COUNT(*) FROM dbo.Shipment WHERE ShipmentId = @CarrierId;
END
GO

CREATE PROCEDURE dbo.usp_Ship_ShipmentTracking_List
    @CustomerId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CustomerId;
    SELECT ca.*, c2.CustomerId AS CustomerKey
    FROM dbo.CustomerAddress AS ca WITH (NOLOCK)
    JOIN dbo.Customer c2 ON c2.CustomerId = ca.CustomerId
    WHERE ca.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.ShipmentTracking WHERE ShipmentTrackingId = @CustomerId;
    SET @val = dbo.fn_GetSysParam('LIMIT_SHIPPING');
    EXEC dbo.usp_Error_Log @CustomerId = @CustomerId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Ship_Shipment_Insert
    @CarrierId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Carrier WHERE CarrierId = @CarrierId;
    SELECT @cnt = COUNT(*) FROM dbo.OrderItem WHERE OrderItemId = @CarrierId;
    UPDATE dbo.CarrierService SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CarrierServiceId = @CarrierId;
    UPDATE s SET s.ModifiedAt = GETDATE()
    FROM dbo.Shipment s
    INNER JOIN dbo.Carrier c2 ON c2.CarrierId = s.ShipmentId
    WHERE s.ShipmentId = @CarrierId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Ship_Shipment_Insert', @EntityId = @CarrierId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_Counter_Next @CarrierId = @CarrierId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Ship_DeliverySlot_Cleanup
    @CarrierId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Ship_DeliverySlot_Cleanup';
    SELECT @cnt = COUNT(*) FROM dbo.Carrier WHERE CarrierId = @CarrierId;
    SELECT @cnt = COUNT(*) FROM dbo.Customer WHERE CustomerId = @CarrierId;
    SELECT @cnt = COUNT(*) FROM dbo.vw_ShipmentLastEvent WHERE Id = @CarrierId;
    SET @val = dbo.fn_CarrierForZip(@CarrierId);
    UPDATE ds SET ds.ModifiedAt = GETDATE()
    FROM dbo.DeliverySlot ds
    INNER JOIN dbo.Carrier c3 ON c3.CarrierId = ds.DeliverySlotId
    WHERE ds.DeliverySlotId = @CarrierId;
    MERGE dbo.ShipmentItem AS tgt
    USING (SELECT @CarrierId AS ShipmentItemId) AS src ON tgt.ShipmentItemId = src.ShipmentItemId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_Audit_Write @EntityName = N'Update dbo.CarrierService', @EntityId = @CarrierId, @Action = 'UPD', @UserId = @UserId;
    EXEC @rc = dbo.usp_JobRun_End @CarrierId = @CarrierId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Ship_Carrier_Zasilkovna @CarrierId = @CarrierId, @UserId = @UserId;
    EXEC dbo.usp_Ship_Shipment_Update @CarrierId = @CarrierId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Ship_PickupPoint_GetDetail @CarrierId = @CarrierId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Ship_PickupPoint_GetByCode @CarrierId = @CarrierId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Order_Delete @CarrierId = @CarrierId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROC dbo.usp_Ship_Shipment_Nightly
    @DeliverySlotId INT = NULL,
    @UserId INT = NULL,
    @TableName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #work (Id INT PRIMARY KEY, Val DECIMAL(12,2));
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    EXEC dbo.usp_JobRun_Start @JobName = 'usp_Ship_Shipment_Nightly';
    INSERT INTO #work (Id, Val)
    SELECT ds.DeliverySlotId, 0 FROM dbo.DeliverySlot ds WHERE ds.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    INSERT INTO #work (Id, Val)
    SELECT st.ShipmentTrackingId, 0 FROM dbo.ShipmentTracking st WHERE st.ModifiedAt >= DATEADD(DAY, -1, GETDATE());
    UPDATE dbo.Shipment SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ShipmentId = @DeliverySlotId;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE dbo.' + QUOTENAME(@TableName) + N' SET ModifiedAt = GETDATE() WHERE Status = 0';
    EXEC (@sql);
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Ship_Shipment_Nightly', @EntityId = @DeliverySlotId, @Action = 'UPD', @UserId = @UserId;
    EXEC dbo.usp_JobRun_End @DeliverySlotId = @DeliverySlotId, @UserId = @UserId;
    EXEC dbo.usp_Ship_Shipment_Insert @DeliverySlotId = @DeliverySlotId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Ship_ShipmentTracking_Recalc @DeliverySlotId = @DeliverySlotId;
    IF @rc <> 0 RETURN @rc;
    EXEC dbo.usp_Ship_ShipmentTracking_List @DeliverySlotId = @DeliverySlotId, @UserId = @UserId;
    EXEC @rc = dbo.usp_Order_Recalc @DeliverySlotId = @DeliverySlotId;
    IF @rc <> 0 RETURN @rc;
    DROP TABLE #work;
END
GO

CREATE PROCEDURE dbo.usp_Ship_ShipmentTracking_Recalc
    @CarrierServiceId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- 2019: puvodne se cetlo z dbo.Product_bak2019, ted uz ne (MK)
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Shipment WHERE ShipmentId = @CarrierServiceId;
    UPDATE dbo.CarrierService SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CarrierServiceId = @CarrierServiceId;
    UPDATE dbo.ShipmentTracking SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ShipmentTrackingId = @CarrierServiceId;
    EXEC dbo.usp_Audit_Write @EntityName = 'usp_Ship_ShipmentTracking_Recalc', @EntityId = @CarrierServiceId, @Action = 'UPD', @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Ship_SendToCarrier
    @CarrierId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Carrier WHERE CarrierId = @CarrierId;
    SELECT s.*, c2.CarrierId AS CarrierKey
    FROM dbo.Shipment AS s WITH (NOLOCK)
    JOIN dbo.Carrier c2 ON c2.CarrierId = s.CarrierId
    WHERE s.Status = 1;
    UPDATE dbo.ShipmentTracking SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE ShipmentTrackingId = @CarrierId;
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @handler SYSNAME;
    SELECT TOP (1) @handler = HandlerProc FROM dbo.Carrier WHERE Status = 1;
    SET @sql = N'EXEC dbo.' + QUOTENAME(@handler) + N' @CarrierId = ' + CAST(ISNULL(@CarrierId, 0) AS NVARCHAR(20));
    EXEC (@sql);
    EXEC dbo.usp_Ship_ShipmentItem_Insert @CarrierId = @CarrierId, @UserId = @UserId;
    EXEC dbo.usp_Ship_Carrier_DPD @CarrierId = @CarrierId, @UserId = @UserId;
    EXEC dbo.usp_Ship_Shipment_Insert @CarrierId = @CarrierId, @UserId = @UserId;
    EXEC dbo.usp_Ship_Shipment_Save @CarrierId = @CarrierId, @UserId = @UserId;
END
GO

CREATE PROC dbo.usp_Ship_Carrier_PPL
    @CustomerAddressId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.CustomerAddress WHERE CustomerAddressId = @CustomerAddressId;
    SELECT si.*, s.ShipmentId AS ShipmentKey
    FROM dbo.ShipmentItem AS si WITH (NOLOCK)
    JOIN dbo.Shipment s ON s.ShipmentId = si.ShipmentId
    WHERE si.Status = 1;
    INSERT INTO dbo.Shipment (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    UPDATE st SET st.ModifiedAt = GETDATE()
    FROM dbo.ShipmentTracking st
    INNER JOIN dbo.CustomerAddress ca2 ON ca2.CustomerAddressId = st.ShipmentTrackingId
    WHERE st.ShipmentTrackingId = @CustomerAddressId;
    EXEC @rc = dbo.usp_Ship_PickupPoint_GetByCode @CustomerAddressId = @CustomerAddressId;
    IF @rc <> 0 RETURN @rc;
END
GO

CREATE PROCEDURE dbo.usp_Ship_Carrier_DPD
    @CustomerAddressId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.CustomerAddress WHERE CustomerAddressId = @CustomerAddressId;
    SELECT si.*, s.ShipmentId AS ShipmentKey
    FROM dbo.ShipmentItem AS si WITH (NOLOCK)
    JOIN dbo.Shipment s ON s.ShipmentId = si.ShipmentId
    WHERE si.Status = 1;
    UPDATE s2 SET s2.ModifiedAt = GETDATE()
    FROM dbo.Shipment s2
    INNER JOIN dbo.CustomerAddress ca2 ON ca2.CustomerAddressId = s2.ShipmentId
    WHERE s2.ShipmentId = @CustomerAddressId;
    DELETE FROM dbo.ShipmentTracking WHERE ShipmentTrackingId = @CustomerAddressId AND Status = 0;
END
GO

CREATE PROCEDURE dbo.usp_Ship_Carrier_Zasilkovna
    @CustomerAddressId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.CustomerAddress WHERE CustomerAddressId = @CustomerAddressId;
    SELECT @cnt = COUNT(*) FROM dbo.Shipment WHERE ShipmentId = @CustomerAddressId;
    SELECT si.*, s2.ShipmentId AS ShipmentKey
    FROM dbo.ShipmentItem AS si WITH (NOLOCK)
    JOIN dbo.Shipment s2 ON s2.ShipmentId = si.ShipmentId
    WHERE si.Status = 1;
    DELETE FROM dbo.Shipment WHERE ShipmentId = @CustomerAddressId AND Status = 0;
    MERGE dbo.ShipmentTracking AS tgt
    USING (SELECT @CustomerAddressId AS ShipmentTrackingId) AS src ON tgt.ShipmentTrackingId = src.ShipmentTrackingId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    EXEC dbo.usp_Ship_PickupPoint_GetByCode @CustomerAddressId = @CustomerAddressId, @UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_Ship_Carrier_CeskaPosta
    @CustomerAddressId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.CustomerAddress WHERE CustomerAddressId = @CustomerAddressId;
    SELECT si.*, s.ShipmentId AS ShipmentKey
    FROM dbo.ShipmentItem AS si WITH (NOLOCK)
    JOIN dbo.Shipment s ON s.ShipmentId = si.ShipmentId
    WHERE si.Status = 1;
    MERGE dbo.Shipment AS tgt
    USING (SELECT @CustomerAddressId AS ShipmentId) AS src ON tgt.ShipmentId = src.ShipmentId
    WHEN MATCHED THEN UPDATE SET tgt.ModifiedAt = GETDATE()
    WHEN NOT MATCHED THEN INSERT (Status, CreatedAt) VALUES (1, GETDATE());
    DELETE FROM dbo.ShipmentTracking WHERE ShipmentTrackingId = @CustomerAddressId AND Status = 0;
END
GO

CREATE PROCEDURE dbo.usp_Ship_Carrier_GLS_old
    @CustomerAddressId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.CustomerAddress WHERE CustomerAddressId = @CustomerAddressId;
    SELECT @cnt = COUNT(*) FROM dbo.ShipmentItem WHERE ShipmentItemId = @CustomerAddressId;
    UPDATE s SET s.ModifiedAt = GETDATE()
    FROM dbo.Shipment s
    INNER JOIN dbo.CustomerAddress ca2 ON ca2.CustomerAddressId = s.ShipmentId
    WHERE s.ShipmentId = @CustomerAddressId;
    INSERT INTO dbo.ShipmentTracking (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
END
GO
