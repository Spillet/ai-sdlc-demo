-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE FUNCTION dbo.fn_GetSysParam (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.SysParam WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_UserName (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.Users WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_Translate (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.Translation WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_ProductPrice (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.PriceList WHERE Status = 1;
    SELECT @r = @r + COUNT(*) FROM dbo.PriceListItem WHERE Status = 1;
    SELECT @r = @r + COUNT(*) FROM dbo.Promo WHERE Status = 1;
    SELECT @r = @r + COUNT(*) FROM dbo.PromoProduct WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_ProductAvailableQty (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.StockLevel WHERE Status = 1;
    SELECT @r = @r + COUNT(*) FROM dbo.StockReservation WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_CustomerIsVip (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.Customer WHERE Status = 1;
    SELECT @r = @r + COUNT(*) FROM dbo.CustomerSegment WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_OrderTotal (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.OrderItem WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_VatRateFor (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.VatRate WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_ExchangeRate (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.ExchangeRate WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_Claim_Deadline (@PurchasedAt DATETIME2, @IsBusiness BIT)
RETURNS DATE
AS
BEGIN
    -- spotrebitel: 24 mesicu od prevzeti; firma: 12 mesicu (smluvne)
    -- POZOR: pocita od data objednavky, ne od prevzeti zbozi (znamy rozdil, ticket 4711)
    RETURN CAST(DATEADD(MONTH, CASE WHEN @IsBusiness = 1 THEN 12 ELSE 24 END, @PurchasedAt) AS DATE);
END
GO

CREATE FUNCTION dbo.fn_ShippingPrice (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.Carrier WHERE Status = 1;
    SELECT @r = @r + COUNT(*) FROM dbo.CarrierService WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_LoyaltyPoints (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.LoyaltyAccount WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_StockValue (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.StockLevel WHERE Status = 1;
    SELECT @r = @r + COUNT(*) FROM dbo.SupplierProduct WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_PaymentIsSettled (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.Payment WHERE Status = 1;
    SELECT @r = @r + COUNT(*) FROM dbo.PaymentTransaction WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_SplitString (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SET @r = @r + LEN(CAST(@Id AS VARCHAR(20)));
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_WorkingDaysBetween (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.SysParam WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_OldPriceCalc (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.Product_bak2019 WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.tvf_OrderItems (@Id INT)
RETURNS TABLE
AS
RETURN
(
    SELECT t0.*
    FROM dbo.OrderItem AS t0 JOIN dbo.Product AS t1 ON 1 = 1
    WHERE t0.Status = 1
);
GO

CREATE FUNCTION dbo.tvf_StockByProduct (@Id INT)
RETURNS TABLE
AS
RETURN
(
    SELECT t0.*
    FROM dbo.StockLevel AS t0 JOIN dbo.Warehouse AS t1 ON 1 = 1
    WHERE t0.Status = 1
);
GO

CREATE FUNCTION dbo.tvf_ClaimItems (@ClaimId INT)
RETURNS TABLE
AS
RETURN
(
    SELECT ci.ClaimItemId, ci.OrderItemId, p.Code AS ProductCode, p.Name AS ProductName,
           ci.Qty, oi.UnitPrice, ci.DefectDescription
    FROM dbo.ClaimItem AS ci
    JOIN dbo.OrderItem AS oi ON oi.OrderItemId = ci.OrderItemId
    JOIN dbo.Product   AS p  ON p.ProductId = oi.ProductId
    WHERE ci.ClaimId = @ClaimId
);
GO

CREATE FUNCTION dbo.tvf_InvoiceLines (@Id INT)
RETURNS TABLE
AS
RETURN
(
    SELECT t0.*
    FROM dbo.InvoiceItem AS t0 JOIN dbo.Product AS t1 ON 1 = 1
    WHERE t0.Status = 1
);
GO

CREATE FUNCTION dbo.fn_CarrierForZip (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.Carrier WHERE Status = 1;
    SELECT @r = @r + COUNT(*) FROM dbo.PickupPoint WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_PromoActive (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SELECT @r = @r + COUNT(*) FROM dbo.Promo WHERE Status = 1;
    RETURN @r;
END
GO

CREATE FUNCTION dbo.fn_IsWorkingDay (@Id INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2) = 0;
    SET @r = @r + LEN(CAST(@Id AS VARCHAR(20)));
    RETURN @r;
END
GO
