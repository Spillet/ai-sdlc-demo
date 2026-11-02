# Kontext pro AI: dbo.usp_Claim_Claim_Insert

Doména (návrh shlukování): D:Claim. Stav: mrtvá. Volání za 6 týdnů (XE module_end): 0.

## Kód

```sql
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
```

## Závislosti podle vrstev

- calls → `fn_IsWorkingDay` [static] (doména cíle: sdílené)
- calls → `trg_Claim_Audit` [static] {via_trigger} (doména cíle: D:Claim)
- calls → `usp_Audit_Write` [static] (doména cíle: sdílené)
- writes → `Claim` [static] (doména cíle: D:Claim)

## Kdo ji volá


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
