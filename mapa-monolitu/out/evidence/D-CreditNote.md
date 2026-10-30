# Balíček důkazů: D:CreditNote

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `3a31a99461f1…`). Strojová verze: `D-CreditNote.json` (schéma `mapa-monolitu/dukazy@1`).

## Pruh core: **zavřený**

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo sloučí: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Vlastník: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má vlastnický tým | jen draft PR | **ne** | vlastník není určen |
| R2 doména je kandidát na vyjmutí (ne úklid, ne malý shluk) | jen draft PR | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | otevřený s vlastníkem | **ne** | 0 z 18 (0 %) |
| R4 všechny zapisující procedury mají zelený charakterizační test | otevřený s vlastníkem | **ne** | chybí 12: usp_Inv_AccountingExport_Insert, usp_Inv_AccountingExport_MonthClose, usp_Inv_CreditNote_Recalc, usp_Inv_ExchangeRate_Approve, usp_Inv_ExchangeRate_Insert, usp_Inv_Invoice_Confirm … |
| R5 blokujících slepých míst ≤ 0 | otevřený s vlastníkem | **ne** | usp_Inv_Invoice_Hourly, usp_Inv_YearClose |

**Co chybí k dalšímu stavu:**

- doména má vlastnický tým (vlastník není určen)

## Připravenost k vyjmutí

Skóre 73.0, pořadí 3. Skóre řadí domény k vyjmutí, stav pruhu neurčuje.

## Pokrytí charakterizačními testy

Živých procedur 18: ověřeno 0, jen návrh 0, chybí 18. Zapisujících 12, z toho bez ověřeného testu 12.

Návrh = test existuje, ale nemá doložený zelený běh (`beh.json`). Návrh pruh neotevře.

| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |
|---|---|---|---|---|---:|
| `usp_Inv_AccountingExport_Insert` | živá | – | – | AccountingExport, InvoiceItem | 58 |
| `usp_Inv_AccountingExport_List` | živá | – | – | – | 9 167 |
| `usp_Inv_AccountingExport_MonthClose` | živá | – | – | InvoiceItem, LedgerEntry, VatRate | 42 |
| `usp_Inv_CreditNote_Recalc` | živá | – | – | CreditNote | 13 657 |
| `usp_Inv_ExchangeRate_Approve` | živá | – | – | CreditNote, ExchangeRate | 12 701 |
| `usp_Inv_ExchangeRate_Insert` | živá | – | – | ExchangeRate | 298 |
| `usp_Inv_ExchangeRate_List` | živá | – | – | – | 5 065 |
| `usp_Inv_Invoice_Check` | živá | – | – | – | 99 |
| `usp_Inv_Invoice_Confirm` | živá | – | – | CreditNote, LedgerEntry | 69 |
| `usp_Inv_Invoice_Get` | živá | – | – | – | 2 852 |
| `usp_Inv_Invoice_GetDetail` | živá | – | – | – | 469 |
| `usp_Inv_Invoice_Hourly` | živá | – | – | CreditNote | 4 032 |
| `usp_Inv_Invoice_Rebuild` | živá | – | – | AccountingExport, ExchangeRate | 22 |
| `usp_Inv_Invoice_Sync` | živá | – | – | ExchangeRate, **Invoice**, InvoiceItem | 23 085 |
| `usp_Inv_LedgerEntry_Find` | živá | – | – | – | 14 493 |
| `usp_Inv_LedgerEntry_MonthClose` | živá | – | – | ExchangeRate, **Invoice** | 1 008 |
| `usp_Inv_LedgerEntry_Rebuild` | mrtvá | – | – | **Invoice**, LedgerEntry | 0 |
| `usp_Inv_VatRate_Dispatch` | živá | – | – | CreditNote, VatRate | 312 |
| `usp_Inv_YearClose` | mimo okno měření | – | – | AccountingExport, LedgerEntry | 0 |

## Slepá místa

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Inv_Invoice_Hourly` | jina_databaze | **ano** | zápis do Accounting.dbo.Invoice_Archive (katalog nemá ID) |
| `usp_Inv_YearClose` | jina_databaze | **ano** | zápis do Accounting.dbo.YearBalance (katalog nemá ID) |
| `usp_Inv_AccountingExport_MonthClose` | dynamicke_sql_slepe | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: LedgerEntry (jen v okně měření) |
| `usp_Inv_ExchangeRate_Approve` | dynamicke_sql_slepe | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: CreditNote (jen v okně měření) |
| `usp_Inv_Invoice_Sync` | dynamicke_sql_slepe | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: ExchangeRate (jen v okně měření) |
| `usp_Inv_AccountingExport_MonthClose` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Inv_Invoice_Confirm` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Inv_Invoice_Hourly` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Inv_Invoice_Rebuild` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Inv_Invoice_Sync` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Inv_LedgerEntry_MonthClose` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Inv_VatRate_Dispatch` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
