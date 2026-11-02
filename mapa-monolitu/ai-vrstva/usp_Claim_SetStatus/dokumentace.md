# dbo.usp_Claim_SetStatus

> [MODEL] Vygenerováno z `out/context/usp_Claim_SetStatus.md`. Nespuštěno. Ověřit podle bodů na konci.

## Účel

Změní stav reklamace, zapíše historii a podle nového stavu provede důsledek: u výměny odepíše kus ze skladu, u dobropisu založí refundaci. [MODEL]

## Provoz

Jen Delphi klient (`Konzole.exe`), 21 volání za 6 týdnů v syntetických datech. [ZJIŠTĚNO Z MAPY] Malý provoz, ale nejhorší hrany domény.

## Stavy (z komentáře a kódu)

| Stav | Význam | Důsledek v proceduře |
|---:|---|---|
| 1 | nová | – |
| 2 | v servisu | – |
| 3 | uznaná, oprava | `Resolution = 'REPAIR'` |
| 4 | uznaná, výměna | `Resolution = 'REPLACE'` + **odpis ze skladu** |
| 5 | uznaná, dobropis | `Resolution = 'REFUND'` + **`usp_Refund_Create`** |
| 7 | hrozí překročení lhůty | nastavuje jen `usp_Claim_OverdueCheck`; v komentáři procedury chybí [MODEL] |
| 9 | zamítnutá | `Resolution = 'REJECTED'` |

Ze stavu 5 a 9 už nejde přejít jinam (kód 2). Jiné přechody se nekontrolují: jde třeba z 1 rovnou na 5. [MODEL] → [OVĚŘÍ ČLOVĚK]: jaký je skutečný stavový automat?

## Návratové kódy

`0` OK, `1` reklamace neexistuje, `2` uzavřenou reklamaci nelze měnit (RAISERROR). Chyba uvnitř transakce: `XACT_ABORT ON` ji celou vrátí, ale chybí `TRY/CATCH`, takže se nezaloguje do `ErrorLog` jako v `usp_Claim_Create`. [MODEL]

## Vedlejší efekty a hrany mimo doménu

| Co | Kam | Vrstva | Vlastník |
|---|---|---|---|
| UPDATE | `StockLevel` (sklad 1 natvrdo) | statická | **sdílená**, hlavně D:Warehouse |
| trigger | `trg_StockLevel_Movement` → INSERT `StockMovement` (8,3 TB) | statická přes trigger | D:Warehouse |
| EXEC | `usp_Refund_Create` | statická | D:GatewayLog (platby) |
| EXEC | `usp_Audit_Write` | statická | infrastruktura |
| trigger | `trg_Claim_Audit` → `AuditLog` | statická přes trigger | infrastruktura |

[ZJIŠTĚNO Z MAPY] Tyto tři cizí hrany (sklad, pohyby skladu, platby) jsou v jedné transakci. Po vytažení reklamací do služby už jedna transakce nebude. Každou hranu je potřeba nahradit voláním vlastníka dat nebo událostí.

## Podezřelá místa

1. **Sklad natvrdo `WarehouseId = 1`.** Výměna vždy odepisuje z centrálního skladu, i když se vyměňuje jinde. [MODEL] → [OVĚŘÍ ČLOVĚK]
2. **Reklamace přímo mění sklad.** Sklad se o výměně dozví jen z triggeru, bez rezervace a kontroly dostupnosti: `QtyOnHand` může jít do záporu. [MODEL]
3. **Refundace bez platby.** Když k objednávce není `Payment`, `@PaymentId` je `NULL` a `usp_Refund_Create` se zavolá s `NULL`. Co pak udělá, z tohoto kontextu nevím. [MODEL] → [OVĚŘÍ ČLOVĚK]
4. **Částka refundace** = `Qty × UnitPrice` z objednávky. Nepočítá slevy, voucher ani dopravu. [MODEL] → [OVĚŘÍ ČLOVĚK]: byznysové pravidlo
5. Opakované volání se stavem 4 odepíše sklad znovu. Chybí idempotence. [MODEL]

## Návrh pro novou službu (k diskusi, ne rozhodnutí)

- Reklamace zapíše jen svůj stav a do outboxu vydá `ClaimResolved { ClaimId, Resolution, Items[] }`. [MODEL]
- Sklad událost zpracuje sám (z kterého skladu, rezervace, pohyb). Platby založí refundaci podle svých pravidel. [MODEL]
- Během souběhu staré a nové cesty: procedura zůstává, nová služba ji volá jako adaptér, dokud sklad a platby událost neumí (strangler na úrovni procedury). [MODEL]
- [OVĚŘÍ ČLOVĚK] Je přijatelné, že odpis skladu a refundace proběhnou asynchronně (sekundy), a ne v jedné transakci se změnou stavu?
