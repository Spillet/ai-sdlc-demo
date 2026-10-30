# Kontext pro AI: dbo.usp_Claim_Notify

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 36.

## Kód

```sql
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
```

## Závislosti podle vrstev

- calls → `fn_Translate` [static] (doména cíle: sdílené)
- reads → `Claim` [static] (doména cíle: D:Claim)
- reads → `Customer` [static] (doména cíle: sdílené)
- writes → `ExportQueue` [static] (doména cíle: D:RptDailySales)

## Kdo ji volá

- `usp_Claim_OverdueCheck` [static]

## Provoz (Query Store, 30 dní)

cpu_ms 153, logical_reads 17925, logical_writes 42, stmt_executions 432

## Schéma dotčených tabulek

```sql
-- ===== Claims =====
CREATE TABLE dbo.Claim (
    ClaimId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Claim PRIMARY KEY,
    OrderId INT NULL,
    CustomerId INT NULL,
    ServiceCenterId INT NULL,
    ClaimNumber VARCHAR(20),
    ClaimType VARCHAR(20),
    Resolution VARCHAR(30) NULL,
    DeadlineAt DATE,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
```sql
-- ===== Customers =====
CREATE TABLE dbo.Customer (
    CustomerId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customer PRIMARY KEY,
    CustomerSegmentId INT NULL,
    Email NVARCHAR(200),
    Name NVARCHAR(200),
    IsBusiness BIT,
    VatId VARCHAR(20) NULL,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
```sql
CREATE TABLE dbo.ExportQueue (
    ExportQueueId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ExportQueue PRIMARY KEY,
    HandlerProc SYSNAME,
    Payload NVARCHAR(MAX),
    ProcessedAt DATETIME2 NULL,
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
