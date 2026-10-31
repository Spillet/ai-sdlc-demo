# Evidence pack: D:PriceList

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `fed7344328f4…`). Strojová verze: `D-PriceList.json` (schéma `mapa-monolitu/evidence-pack@2`).

## Core lane: **closed** (autonomy level L0)

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo udělá merge: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Owning team: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má owning team | draft-only | **ne** | owning team není určen |
| R2 doména je mezi domain candidates (ne úklid, ne malý shluk) | draft-only | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | open | **ne** | 0 z 17 (0 %) |
| R4 všechny zapisující procedury mají zelený characterization test | open | **ne** | chybí 12: usp_Price_PriceHistory_MonthClose, usp_Price_PriceList_Insert, usp_Price_PriceList_MonthClose, usp_Price_PriceList_Recalc, usp_Price_PriceList_SetStatus, usp_Price_Promo_Cancel … |
| R5 blokujících blind spots ≤ 0 | open | **ne** | usp_Price_PriceHistory_MonthClose |

**Co chybí k dalšímu stavu:**

- doména má owning team (owning team není určen)

## Extraction readiness score

Skóre 71.9, pořadí 7. Extraction readiness score řadí domény k vyjmutí, stav core lane neurčuje.

## Pokrytí characterization tests

Živých procedur 17: verified 0, draft 0, missing 17. Zapisujících 12, z toho bez ověřeného testu 12.

Draft = test existuje, ale nemá doložený zelený běh (`run.json`). Draft core lane neotevře.

| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |
|---|---|---|---|---|---:|
| `usp_Price_PriceHistory_GetDetail` | živá | – | – | – | 10 714 |
| `usp_Price_PriceHistory_MonthClose` | živá | – | – | PriceHistory, Promo | 42 |
| `usp_Price_PriceHistory_Overview` | živá | – | – | – | 22 |
| `usp_Price_PriceList_Insert` | živá | – | – | PriceList | 990 |
| `usp_Price_PriceList_MonthClose` | živá | – | – | **Product**, Promo | 42 |
| `usp_Price_PriceList_Overview` | živá | – | – | – | 1 292 |
| `usp_Price_PriceList_Recalc` | živá | – | – | PriceList, **Product** | 1 817 |
| `usp_Price_PriceList_Save` | mrtvá | – | – | PriceList, **Product** | 0 |
| `usp_Price_PriceList_Search` | živá | – | – | – | 1 509 |
| `usp_Price_PriceList_SetStatus` | živá | – | – | PriceList, Promo | 4 173 |
| `usp_Price_Promo_Cancel` | živá | – | – | PriceList, **PriceListItem**, **Product** | 2 277 |
| `usp_Price_Promo_Get` | živá | – | – | – | 1 726 |
| `usp_Price_Promo_Import` | živá | – | – | Promo | 141 |
| `usp_Price_Promo_Save` | živá | – | – | Promo | 39 589 |
| `usp_Price_VoucherUse_Approve` | živá | – | – | PriceList, **VoucherUse** | 1 689 |
| `usp_Price_Voucher_Cancel` | mrtvá | – | – | PriceList, Promo | 0 |
| `usp_Price_Voucher_Confirm` | živá | – | – | PriceHistory, **VoucherUse** | 933 |
| `usp_Price_Voucher_Merge` | živá | – | – | **Voucher** | 95 |
| `usp_Product_Product_Merge` | živá | – | – | **Product** | 8 524 |

## Blind spots

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Price_PriceHistory_MonthClose` | cross_database | **ano** | zápis do DWH.dbo.PriceHistory_Archive (katalog nemá ID) |
| `usp_Price_Promo_Get` | caller_dependent | ne | volá usp_SysParam_Get bez schématu (is_caller_dependent) |
| `usp_Price_Voucher_Confirm` | caller_dependent | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Price_PriceHistory_MonthClose` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Price_PriceList_MonthClose` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Price_PriceList_SetStatus` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Price_Promo_Cancel` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Price_Promo_Import` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Price_Promo_Save` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Price_Voucher_Confirm` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
