# Kontext pro AI: dbo.usp_Claim_ClaimItem_GetByCode

Doména (návrh shlukování): D:Claim. Stav: živá. Volání za 6 týdnů (XE module_end): 410.

## Kód

```sql
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
```

## Závislosti podle vrstev

- calls → `fn_IsWorkingDay` [static] (doména cíle: sdílené)
- reads → `ClaimItem` [static] (doména cíle: D:Claim)
- reads → `ClaimReason` [dynamic, runtime] {dynamic_sql} (doména cíle: D:Claim)

## Kdo ji volá

- `usp_Claim_ClaimStatusHistory_Confirm` [static]
- aplikace `Konzole.exe`: 28 volání (XE rpc_completed)

## Dynamické SQL

Tabulky z literálů: ClaimReason. Blind spot (skládané jméno): ne.

## Provoz (Query Store, 30 dní)

cpu_ms 1506, logical_reads 127981, logical_writes 0, stmt_executions 4510

## Schéma dotčených tabulek

```sql
CREATE TABLE dbo.ClaimItem (
    ClaimItemId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ClaimItem PRIMARY KEY,
    ClaimId INT NULL,
    OrderItemId INT NULL,
    Qty INT,
    DefectDescription NVARCHAR(2000),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
```sql
CREATE TABLE dbo.ClaimReason (
    ClaimReasonId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ClaimReason PRIMARY KEY,
    Code VARCHAR(20),
    Name NVARCHAR(100),
    Status TINYINT NOT NULL DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
    CreatedBy INT NULL,
    ModifiedAt DATETIME2 NULL
);
```
