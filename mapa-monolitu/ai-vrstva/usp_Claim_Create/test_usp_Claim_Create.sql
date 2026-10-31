-- [MODEL] Characterization tests tSQLt pro dbo.usp_Claim_Create. NESPUŠTĚNO.
-- Zachycují SOUČASNÉ chování. Testy označené "ZACHYCUJE PODEZŘELÉ CHOVÁNÍ" mají
-- projít dnes; až se chování vědomě změní, upraví se test i kód zároveň.
-- Předpoklad: tSQLt nainstalovaný v testovací kopii DB (ne v produkci).

EXEC tSQLt.NewTestClass 'ClaimCreate';
GO

CREATE PROCEDURE ClaimCreate.[SetUp]
AS
BEGIN
    EXEC tSQLt.FakeTable 'dbo.Orders';
    EXEC tSQLt.FakeTable 'dbo.OrderItem';
    EXEC tSQLt.FakeTable 'dbo.Customer';
    EXEC tSQLt.FakeTable 'dbo.ClaimReason';
    EXEC tSQLt.FakeTable 'dbo.Claim', @Identity = 1;
    EXEC tSQLt.FakeTable 'dbo.ClaimItem', @Identity = 1;
    EXEC tSQLt.FakeTable 'dbo.ClaimStatusHistory', @Identity = 1;
    -- triggery na falešných tabulkách neběží; audit triggerem se testuje zvlášť
    EXEC tSQLt.SpyProcedure 'dbo.usp_Counter_Next', 'SET @Value = 42;';
    EXEC tSQLt.SpyProcedure 'dbo.usp_Audit_Write';
    EXEC tSQLt.SpyProcedure 'dbo.usp_Error_Log';

    INSERT INTO dbo.Customer (CustomerId, IsBusiness) VALUES (1, 0), (2, 1);
    -- objednávka spotřebitele před 3 měsíci, 2 kusy
    INSERT INTO dbo.Orders (OrderId, CustomerId, CreatedAt) VALUES (10, 1, DATEADD(MONTH, -3, GETDATE()));
    INSERT INTO dbo.OrderItem (OrderItemId, OrderId, Qty, UnitPrice) VALUES (100, 10, 2, 1000);
    -- objednávka firmy před 13 měsíci
    INSERT INTO dbo.Orders (OrderId, CustomerId, CreatedAt) VALUES (20, 2, DATEADD(MONTH, -13, GETDATE()));
    INSERT INTO dbo.OrderItem (OrderItemId, OrderId, Qty, UnitPrice) VALUES (200, 20, 1, 500);
    INSERT INTO dbo.ClaimReason (Code) VALUES ('DEFECT');
END;
GO

CREATE PROCEDURE ClaimCreate.[test happy path zapise hlavicku polozku a prvni stav]
AS
BEGIN
    DECLARE @id INT, @rc INT;
    EXEC @rc = dbo.usp_Claim_Create @OrderItemId = 100, @Qty = 1, @ReasonCode = 'DEFECT',
                                    @DefectText = N'nejde zapnout', @UserId = 7, @ClaimId = @id OUTPUT;
    EXEC tSQLt.AssertEquals 0, @rc;

    SELECT ClaimNumber, ClaimType, Status, OrderId, CustomerId,
           CASE WHEN DeadlineAt = DATEADD(DAY, 30, CAST(GETDATE() AS DATE)) THEN 1 ELSE 0 END AS Deadline30
    INTO #actual FROM dbo.Claim;
    SELECT TOP (0) * INTO #expected FROM #actual;
    INSERT INTO #expected VALUES ('R000000042', 'DEFECT', 1, 10, 1, 1);
    EXEC tSQLt.AssertEqualsTable '#expected', '#actual';

    EXEC tSQLt.AssertEquals 1, (SELECT COUNT(*) FROM dbo.ClaimItem WHERE OrderItemId = 100 AND Qty = 1);
    EXEC tSQLt.AssertEquals 1, (SELECT COUNT(*) FROM dbo.ClaimStatusHistory WHERE OldStatus = 0 AND NewStatus = 1);
    EXEC tSQLt.AssertEquals 1, (SELECT COUNT(*) FROM dbo.usp_Audit_Write_SpyProcedureLog WHERE Action = 'CREATE');
END;
GO

CREATE PROCEDURE ClaimCreate.[test neexistujici polozka vrati 1]
AS
BEGIN
    DECLARE @id INT;
    EXEC tSQLt.ExpectException @ExpectedMessagePattern = '%neexistuje%';
    EXEC dbo.usp_Claim_Create 999, 1, 'DEFECT', N'x', 7, @id OUTPUT;
END;
GO

CREATE PROCEDURE ClaimCreate.[test neznamy duvod vrati 2]
AS
BEGIN
    DECLARE @id INT;
    EXEC tSQLt.ExpectException @ExpectedMessagePattern = '%duvod%';
    EXEC dbo.usp_Claim_Create 100, 1, 'XXX', N'x', 7, @id OUTPUT;
END;
GO

CREATE PROCEDURE ClaimCreate.[test firma po 12 mesicich nemuze reklamovat]
AS
BEGIN
    DECLARE @id INT;
    EXEC tSQLt.ExpectException @ExpectedMessagePattern = '%Lhuta%';
    EXEC dbo.usp_Claim_Create 200, 1, 'DEFECT', N'x', 7, @id OUTPUT;
END;
GO

CREATE PROCEDURE ClaimCreate.[test mnozstvi nad objednane vrati 4 a zamitnute se nepocitaji]
AS
BEGIN
    DECLARE @id INT;
    -- už reklamovaný 1 kus (aktivní) + 1 kus zamítnutý (stav 9)
    INSERT INTO dbo.Claim (ClaimId, Status) VALUES (1, 1), (2, 9);
    INSERT INTO dbo.ClaimItem (ClaimId, OrderItemId, Qty) VALUES (1, 100, 1), (2, 100, 1);
    -- 1 další kus projde (1 + 1 = 2 = objednáno), 2 kusy ne
    EXEC tSQLt.ExpectException @ExpectedMessagePattern = '%prevysuje%';
    EXEC dbo.usp_Claim_Create 100, 2, 'DEFECT', N'x', 7, @id OUTPUT;
END;
GO

CREATE PROCEDURE ClaimCreate.[test ZACHYCUJE PODEZRELE CHOVANI nulove mnozstvi projde]
AS
BEGIN
    DECLARE @id INT, @rc INT;
    EXEC @rc = dbo.usp_Claim_Create 100, 0, 'DEFECT', N'x', 7, @id OUTPUT;
    EXEC tSQLt.AssertEquals 0, @rc;     -- dnes projde; nová služba má vrátit 400
END;
GO

CREATE PROCEDURE ClaimCreate.[test ZACHYCUJE PODEZRELE CHOVANI lhuta od data objednavky]
AS
BEGIN
    -- spotřebitel, objednáno před 25 měsíci, doručeno (podle Shipment) před 23 měsíci:
    -- zákonně ještě v lhůtě, procedura dnes odmítne. [OVĚŘÍ ČLOVĚK] právní výklad.
    DECLARE @id INT;
    INSERT INTO dbo.Orders (OrderId, CustomerId, CreatedAt) VALUES (30, 1, DATEADD(MONTH, -25, GETDATE()));
    INSERT INTO dbo.OrderItem (OrderItemId, OrderId, Qty, UnitPrice) VALUES (300, 30, 1, 100);
    EXEC tSQLt.ExpectException @ExpectedMessagePattern = '%Lhuta%';
    EXEC dbo.usp_Claim_Create 300, 1, 'DEFECT', N'x', 7, @id OUTPUT;
END;
GO

-- Co tSQLt nepokryje [MODEL]:
--  - souběh dvou volání (kontrola množství mimo transakci): potřebuje test se dvěma
--    spojeními, např. z .NET testu proti kopii DB; viz dokumentace, bod 1
--  - dvojí audit (trigger + procedura): FakeTable triggery vypíná
-- EXEC tSQLt.Run 'ClaimCreate';
