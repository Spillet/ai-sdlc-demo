# Balíček důkazů: D:PriceList

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `3a31a99461f1…`). Strojová verze: `D-PriceList.json` (schéma `mapa-monolitu/dukazy@1`).

## Pruh core: **zavřený**

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo sloučí: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Vlastník: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má vlastnický tým | jen draft PR | **ne** | vlastník není určen |
| R2 doména je kandidát na vyjmutí (ne úklid, ne malý shluk) | jen draft PR | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | otevřený s vlastníkem | **ne** | 0 z 17 (0 %) |
| R4 všechny zapisující procedury mají zelený charakterizační test | otevřený s vlastníkem | **ne** | chybí 12: usp_Price_PriceHistory_MonthClose, usp_Price_PriceList_Insert, usp_Price_PriceList_MonthClose, usp_Price_PriceList_Recalc, usp_Price_PriceList_SetStatus, usp_Price_Promo_Cancel … |
| R5 blokujících slepých míst ≤ 0 | otevřený s vlastníkem | **ne** | usp_Price_PriceHistory_MonthClose |

**Co chybí k dalšímu stavu:**

- doména má vlastnický tým (vlastník není určen)

## Připravenost k vyjmutí

Skóre 71.9, pořadí 7. Skóre řadí domény k vyjmutí, stav pruhu neurčuje.

## Pokrytí charakterizačními testy

Živých procedur 17: ověřeno 0, jen návrh 0, chybí 17. Zapisujících 12, z toho bez ověřeného testu 12.

Návrh = test existuje, ale nemá doložený zelený běh (`beh.json`). Návrh pruh neotevře.

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

## Slepá místa

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Price_PriceHistory_MonthClose` | jina_databaze | **ano** | zápis do DWH.dbo.PriceHistory_Archive (katalog nemá ID) |
| `usp_Price_Promo_Get` | volani_bez_schematu | ne | volá usp_SysParam_Get bez schématu (is_caller_dependent) |
| `usp_Price_Voucher_Confirm` | volani_bez_schematu | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Price_PriceHistory_MonthClose` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Price_PriceList_MonthClose` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Price_PriceList_SetStatus` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Price_Promo_Cancel` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Price_Promo_Import` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Price_Promo_Save` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Price_Voucher_Confirm` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
