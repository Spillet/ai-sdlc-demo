-- [MODEL] Characterization tests tSQLt pro dbo.usp_Claim_SetStatus. NESPUŠTĚNO.
-- Zachycují SOUČASNÉ chování včetně cizích zápisů. Právě tyhle testy musí po
-- vytažení služby spadnout vědomě: cizí zápis se nahradí událostí.

EXEC tSQLt.NewTestClass 'ClaimSetStatus';
GO

CREATE PROCEDURE ClaimSetStatus.[SetUp]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.Claim';
    EXEC tSQLt.FakeTable 'dbo.ClaimItem';
    EXEC tSQLt.FakeTable 'dbo.ClaimStatusHistory', @Identity = 1;
    EXEC tSQLt.FakeTable 'dbo.OrderItem';
    EXEC tSQLt.FakeTable 'dbo.StockLevel';
    EXEC tSQLt.FakeTable 'dbo.Payment';
    EXEC tSQLt.SpyProcedure 'dbo.usp_Refund_Create';
    EXEC tSQLt.SpyProcedure 'dbo.usp_Audit_Write';

    INSERT INTO dbo.Claim (ClaimId, OrderId, Status) VALUES (1, 10, 2);
    INSERT INTO dbo.OrderItem (OrderItemId, OrderId, ProductId, Qty, UnitPrice) VALUES (100, 10, 555, 2, 1000);
    INSERT INTO dbo.ClaimItem (ClaimId, OrderItemId, Qty) VALUES (1, 100, 1);
    INSERT INTO dbo.StockLevel (StockLevelId, ProductId, WarehouseId, QtyOnHand) VALUES (1, 555, 1, 10), (2, 555, 2, 10);
    INSERT INTO dbo.Payment (PaymentId, OrderId, CreatedAt) VALUES (77, 10, '2026-09-01');
END;
GO

CREATE PROCEDURE ClaimSetStatus.[test zmena stavu zapise historii a audit]
AS
BEGIN
    EXEC dbo.usp_Claim_SetStatus @ClaimId = 1, @NewStatus = 3, @Note = N'oprava', @UserId = 7;
    EXEC tSQLt.AssertEquals 3, (SELECT Status FROM dbo.Claim WHERE ClaimId = 1);
    EXEC tSQLt.AssertEqualsString 'REPAIR', (SELECT Resolution FROM dbo.Claim WHERE ClaimId = 1);
    EXEC tSQLt.AssertEquals 1, (SELECT COUNT(*) FROM dbo.ClaimStatusHistory WHERE OldStatus = 2 AND NewStatus = 3 AND CreatedBy = 7);
    EXEC tSQLt.AssertEquals 1, (SELECT COUNT(*) FROM dbo.usp_Audit_Write_SpyProcedureLog);
END;
GO

CREATE PROCEDURE ClaimSetStatus.[test ZACHYCUJE CIZI ZAPIS vymena odepise sklad 1 natvrdo]
AS
BEGIN
    EXEC dbo.usp_Claim_SetStatus 1, 4, NULL, 7;
    EXEC tSQLt.AssertEquals 9,  (SELECT QtyOnHand FROM dbo.StockLevel WHERE WarehouseId = 1);
    EXEC tSQLt.AssertEquals 10, (SELECT QtyOnHand FROM dbo.StockLevel WHERE WarehouseId = 2);   -- jiný sklad se nemění
END;
GO

CREATE PROCEDURE ClaimSetStatus.[test ZACHYCUJE PODEZRELE CHOVANI opakovana vymena odepise znovu]
AS
BEGIN
    EXEC dbo.usp_Claim_SetStatus 1, 4, NULL, 7;
    EXEC dbo.usp_Claim_SetStatus 1, 4, NULL, 7;
    EXEC tSQLt.AssertEquals 8, (SELECT QtyOnHand FROM dbo.StockLevel WHERE WarehouseId = 1);
END;
GO

CREATE PROCEDURE ClaimSetStatus.[test ZACHYCUJE CIZI ZAPIS dobropis zavola refundaci s castkou z objednavky]
AS
BEGIN
    EXEC dbo.usp_Claim_SetStatus 1, 5, NULL, 7;
    SELECT PaymentId, Amount INTO #actual FROM dbo.usp_Refund_Create_SpyProcedureLog;
    SELECT TOP (0) * INTO #expected FROM #actual;
    INSERT INTO #expected VALUES (77, 1000.00);
    EXEC tSQLt.AssertEqualsTable '#expected', '#actual';
END;
GO

CREATE PROCEDURE ClaimSetStatus.[test ZACHYCUJE PODEZRELE CHOVANI dobropis bez platby vola refundaci s NULL]
AS
BEGIN
    DELETE FROM dbo.Payment;
    EXEC dbo.usp_Claim_SetStatus 1, 5, NULL, 7;
    EXEC tSQLt.AssertEquals 1, (SELECT COUNT(*) FROM dbo.usp_Refund_Create_SpyProcedureLog WHERE PaymentId IS NULL);
END;
GO

CREATE PROCEDURE ClaimSetStatus.[test uzavrenou reklamaci nejde zmenit]
AS
BEGIN
    UPDATE dbo.Claim SET Status = 9 WHERE ClaimId = 1;
    EXEC tSQLt.ExpectException @ExpectedMessagePattern = '%Uzavrenou%';
    EXEC dbo.usp_Claim_SetStatus 1, 3, NULL, 7;
END;
GO

CREATE PROCEDURE ClaimSetStatus.[test neexistujici reklamace vrati 1 bez zapisu]
AS
BEGIN
    DECLARE @rc INT;
    EXEC @rc = dbo.usp_Claim_SetStatus 999, 3, NULL, 7;
    EXEC tSQLt.AssertEquals 1, @rc;
    EXEC tSQLt.AssertEmptyTable 'dbo.ClaimStatusHistory';
END;
GO

-- Co tSQLt nepokryje [MODEL]:
--  - zápis do StockMovement přes trg_StockLevel_Movement (FakeTable vypíná triggery);
--    ověřit integračním testem na kopii DB
-- EXEC tSQLt.Run 'ClaimSetStatus';
