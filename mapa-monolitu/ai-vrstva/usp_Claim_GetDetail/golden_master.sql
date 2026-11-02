-- [MODEL] Golden master pro usp_Claim_GetDetail. NESPUŠTĚNO.
-- Čtecí procedura: místo tSQLt nahrát odpovědi staré cesty na kopii produkčních dat
-- a porovnat je s novou .NET službou (parallel run). Model navrhl postup, člověk ověří
-- výběr vzorku a pravidla porovnání.
--
-- 1) Vzorek: reklamace, které se za posledních 30 dní nezměnily (kvůli NOLOCK a GETDATE),
--    rozvrstvené podle stavu, aby byl pokrytý každý stav i reklamace bez servisu a bez dokumentů.
-- 2) Pro každou zavolat proceduru, result sety uložit jako JSON.
-- 3) Stejná ClaimId poslat na GET /claims/{id} nové služby, porovnat normalizovaný JSON.

SET NOCOUNT ON;

IF OBJECT_ID('gm.ClaimDetail') IS NULL
BEGIN
    EXEC('CREATE SCHEMA gm');
    CREATE TABLE gm.ClaimDetail (
        ClaimId     INT          NOT NULL,
        ResultSet   TINYINT      NOT NULL,      -- 1 hlavička, 2 položky, 3 historie, 4 dokumenty
        Payload     NVARCHAR(MAX) NOT NULL,     -- JSON řádků result setu
        CapturedAt  DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_gm_ClaimDetail PRIMARY KEY (ClaimId, ResultSet)
    );
END

DECLARE @sample TABLE (ClaimId INT PRIMARY KEY);
INSERT INTO @sample (ClaimId)
SELECT ClaimId FROM (
    SELECT cl.ClaimId,
           ROW_NUMBER() OVER (PARTITION BY cl.Status, CASE WHEN cl.ServiceCenterId IS NULL THEN 0 ELSE 1 END
                              ORDER BY CHECKSUM(cl.ClaimId)) AS rn
    FROM dbo.Claim AS cl
    WHERE ISNULL(cl.ModifiedAt, cl.CreatedAt) < DATEADD(DAY, -30, SYSUTCDATETIME())
) AS x
WHERE rn <= 50;                                  -- 50 na kombinaci stav × servis

-- Více result setů nejde zachytit přes INSERT ... EXEC (bere jen jeden tvar).
-- Proto se každý result set sestaví stejnými dotazy jako v proceduře.
-- [OVĚŘÍ ČLOVĚK] Tohle je slabé místo návrhu: kopie dotazů se může od procedury odchýlit.
-- Robustnější varianta je zachytit výstup procedury mimo SQL (malý .NET/PowerShell
-- harness přes SqlDataReader.NextResult()) a uložit ho jako JSON. Doporučuji ji.

INSERT INTO gm.ClaimDetail (ClaimId, ResultSet, Payload)
SELECT s.ClaimId, 1,
       (SELECT cl.ClaimId, cl.ClaimNumber, cl.ClaimType, cl.Status, cl.Resolution, cl.DeadlineAt, cl.CreatedAt,
               o.OrderNumber, c.CustomerId, c.Name AS CustomerName, sc.Name AS ServiceCenterName
               -- DaysLeft vynechán: závisí na GETDATE()
        FROM dbo.Claim cl
        JOIN dbo.Orders o ON o.OrderId = cl.OrderId
        JOIN dbo.Customer c ON c.CustomerId = cl.CustomerId
        LEFT JOIN dbo.ServiceCenter sc ON sc.ServiceCenterId = cl.ServiceCenterId
        WHERE cl.ClaimId = s.ClaimId FOR JSON PATH)
FROM @sample AS s;

INSERT INTO gm.ClaimDetail (ClaimId, ResultSet, Payload)
SELECT s.ClaimId, 2, ISNULL((SELECT * FROM dbo.tvf_ClaimItems(s.ClaimId) ORDER BY ClaimItemId FOR JSON PATH), '[]')
FROM @sample AS s;

INSERT INTO gm.ClaimDetail (ClaimId, ResultSet, Payload)
SELECT s.ClaimId, 3, ISNULL((SELECT h.OldStatus, h.NewStatus, h.Note, h.CreatedAt, dbo.fn_UserName(h.CreatedBy) AS ChangedBy
                             FROM dbo.ClaimStatusHistory h WHERE h.ClaimId = s.ClaimId ORDER BY h.CreatedAt FOR JSON PATH), '[]')
FROM @sample AS s;

INSERT INTO gm.ClaimDetail (ClaimId, ResultSet, Payload)
SELECT s.ClaimId, 4, ISNULL((SELECT d.ClaimDocumentId, d.FileName, d.StorageKey
                             FROM dbo.ClaimDocument d WHERE d.ClaimId = s.ClaimId
                             ORDER BY d.ClaimDocumentId FOR JSON PATH), '[]')   -- procedura pořadí nedefinuje: porovnávat jako množinu
FROM @sample AS s;

-- Pravidla porovnání s novou službou [MODEL]:
--  - DaysLeft přepočítat ze DeadlineAt v okamžiku porovnání, nesrovnávat přímo
--  - datumy v UTC, desetinná čísla na 2 místa
--  - dokumenty jako množina podle ClaimDocumentId
--  - kód 5 (bez oprávnění) = HTTP 403 a prázdné tělo
-- Metrika pro rozhodnutí o přepnutí webu: 0 rozdílů na vzorku + 14 dní stínového provozu
-- se shodou > 99,9 % na živém provozu. [OVĚŘÍ ČLOVĚK] práh shody.
