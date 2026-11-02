# Evidence pack: D:CreditNote

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `fed7344328f4…`). Strojová verze: `D-CreditNote.json` (schéma `mapa-monolitu/evidence-pack@2`).

## Core lane: **closed** (autonomy level L0)

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo udělá merge: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Owning team: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má owning team | draft-only | **ne** | owning team není určen |
| R2 doména je mezi domain candidates (ne úklid, ne malý shluk) | draft-only | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | open | **ne** | 0 z 18 (0 %) |
| R4 všechny zapisující procedury mají zelený characterization test | open | **ne** | chybí 12: usp_Inv_AccountingExport_Insert, usp_Inv_AccountingExport_MonthClose, usp_Inv_CreditNote_Recalc, usp_Inv_ExchangeRate_Approve, usp_Inv_ExchangeRate_Insert, usp_Inv_Invoice_Confirm … |
| R5 blokujících blind spots ≤ 0 | open | **ne** | usp_Inv_Invoice_Hourly, usp_Inv_YearClose |

**Co chybí k dalšímu stavu:**

- doména má owning team (owning team není určen)

## Extraction readiness score

Skóre 73.0, pořadí 3. Extraction readiness score řadí domény k vyjmutí, stav core lane neurčuje.

## Pokrytí characterization tests

Živých procedur 18: verified 0, draft 0, missing 18. Zapisujících 12, z toho bez ověřeného testu 12.

Draft = test existuje, ale nemá doložený zelený běh (`run.json`). Draft core lane neotevře.

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

## Blind spots

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Inv_Invoice_Hourly` | cross_database | **ano** | zápis do Accounting.dbo.Invoice_Archive (katalog nemá ID) |
| `usp_Inv_YearClose` | cross_database | **ano** | zápis do Accounting.dbo.YearBalance (katalog nemá ID) |
| `usp_Inv_AccountingExport_MonthClose` | dynamic_sql_blind | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: LedgerEntry (jen v okně měření) |
| `usp_Inv_ExchangeRate_Approve` | dynamic_sql_blind | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: CreditNote (jen v okně měření) |
| `usp_Inv_Invoice_Sync` | dynamic_sql_blind | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: ExchangeRate (jen v okně měření) |
| `usp_Inv_AccountingExport_MonthClose` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Inv_Invoice_Confirm` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Inv_Invoice_Hourly` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Inv_Invoice_Rebuild` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Inv_Invoice_Sync` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Inv_LedgerEntry_MonthClose` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Inv_VatRate_Dispatch` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
