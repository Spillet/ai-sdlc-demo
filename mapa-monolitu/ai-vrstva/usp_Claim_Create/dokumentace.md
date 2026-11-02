# dbo.usp_Claim_Create

> [MODEL] Vygenerováno z `out/context/usp_Claim_Create.md`. Nespuštěno. Ověřit podle bodů na konci.

## Účel

Založí reklamaci jedné položky objednávky: ověří položku, důvod, zákonnou lhůtu a množství, přidělí číslo reklamace a zapíše hlavičku, položku a první stav. [MODEL]

## Provoz

- 199 614 přímých volání z `Kompas.Web.Api`, 127 z `Konzole.exe` za 6 týdnů. Zakládání reklamací je skoro celé na webu. [ZJIŠTĚNO Z MAPY]
- Query Store: 1 671 s CPU, 2,5 mil. logických zápisů za 30 dní. [ZJIŠTĚNO Z MAPY]

## Vstupy a výstup

| Parametr | Typ | Význam |
|---|---|---|
| `@OrderItemId` | INT | reklamovaná položka objednávky |
| `@Qty` | INT | reklamované množství; kladnost se nekontroluje [MODEL] |
| `@ReasonCode` | VARCHAR(20) | kód z `ClaimReason`; uloží se do `Claim.ClaimType` |
| `@DefectText` | NVARCHAR(2000) | popis vady |
| `@UserId` | INT | autor (jen do auditu) |
| `@ClaimId` | INT OUTPUT | ID nové reklamace |

| Návratový kód | Kdy | Chyba |
|---|---|---|
| 0 | založeno | – |
| 1 | položka neexistuje | RAISERROR 16 |
| 2 | neznámý důvod | RAISERROR 16 |
| 3 | lhůta vypršela | RAISERROR 16 |
| 4 | reklamované množství > objednané (minus již reklamované, kromě zamítnutých) | RAISERROR 16 |
| výjimka | chyba při zápisu; zaloguje se přes `usp_Error_Log` a znovu vyhodí (THROW) | – |

## Byznysová pravidla

1. **Zákonná lhůta**: `fn_Claim_Deadline(datum objednávky, IsBusiness)` = 24 měsíců pro spotřebitele, 12 pro firmu. Po ní reklamaci nejde založit. [MODEL]
2. **Lhůta na vyřízení**: `Claim.DeadlineAt` = dnes + 30 dní. Pozor, jsou to **dvě různé lhůty** se stejným slovem „deadline“. [MODEL]
3. **Množství**: součet reklamovaných kusů položky (bez zamítnutých, `Status <> 9`) + nové nesmí překročit objednané. [MODEL]
4. **Číslo reklamace**: `'R'` + 9místné pořadí z `usp_Counter_Next 'CLAIM'`. [MODEL]
5. Nová reklamace má stav 1 a nemá přiřazený servis. [MODEL]

## Vedlejší efekty

- Zápisy: `Claim`, `ClaimItem`, `ClaimStatusHistory` (vše D:Claim). [ZJIŠTĚNO Z MAPY]
- Trigger `trg_Claim_Audit` zapíše do `AuditLog` (8,1 TB, sdílená infrastruktura) a k tomu ještě `usp_Audit_Write`. **Audit se zapisuje dvakrát.** [ZJIŠTĚNO Z MAPY] + [MODEL]
- `usp_Counter_Next` zamyká řádek v `Counter` uvnitř transakce: při špičce webu je to sériový bod pro všechny reklamace. [MODEL]
- Čte sdílené `Orders`, `OrderItem`, `Customer`. [ZJIŠTĚNO Z MAPY]

## Podezřelá místa

1. **Souběh.** Kontrola množství (pravidlo 3) proběhne **před** `BEGIN TRAN` a bez zámků. Dvě souběžná volání můžou obě projít a reklamovat víc kusů, než bylo objednáno. [MODEL] → [OVĚŘÍ ČLOVĚK]: dotaz na duplicity v datech:
   ```sql
   SELECT ci.OrderItemId, SUM(ci.Qty) AS claimed, MAX(oi.Qty) AS ordered
   FROM dbo.ClaimItem ci JOIN dbo.Claim cl ON cl.ClaimId = ci.ClaimId JOIN dbo.OrderItem oi ON oi.OrderItemId = ci.OrderItemId
   WHERE cl.Status <> 9 GROUP BY ci.OrderItemId HAVING SUM(ci.Qty) > MAX(oi.Qty);
   ```
2. **Lhůta od objednávky, ne od převzetí** (`fn_Claim_Deadline`, komentář „ticket 4711“). Zákonná lhůta běží od převzetí. U pozdě doručeného zboží procedura odmítne reklamaci, která je ještě v zákonné lhůtě. [MODEL] → [OVĚŘÍ ČLOVĚK]: právní výklad a datum převzetí (je v `Shipment`?).
3. `@Qty <= 0` projde. [MODEL]
4. `ClaimType` dostává kód důvodu, ne typ reklamace. Název sloupce neodpovídá obsahu. [MODEL]

## Otázky pro člověka

- Je dvojí audit záměr (trigger pro historii, procedura pro uživatele)? [OVĚŘÍ ČLOVĚK]
- Smí nová služba přidělovat čísla reklamací sama (sekvence v její DB), nebo musí zůstat jedna řada s Konzolí po dobu souběhu? [OVĚŘÍ ČLOVĚK]
