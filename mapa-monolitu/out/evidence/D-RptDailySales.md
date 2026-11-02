# Evidence pack: D:RptDailySales

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `fed7344328f4…`). Strojová verze: `D-RptDailySales.json` (schéma `mapa-monolitu/evidence-pack@2`).

## Core lane: **closed** (autonomy level L0)

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo udělá merge: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Owning team: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má owning team | draft-only | **ne** | owning team není určen |
| R2 doména je mezi domain candidates (ne úklid, ne malý shluk) | draft-only | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | open | **ne** | 0 z 21 (0 %) |
| R4 všechny zapisující procedury mají zelený characterization test | open | **ne** | chybí 19: usp_Rpt_Customers_RptDailySales, usp_Rpt_Dispatch, usp_Rpt_Export_Accounting, usp_Rpt_Export_Email, usp_Rpt_Export_Heureka, usp_Rpt_Export_RptDailySales … |
| R5 blokujících blind spots ≤ 0 | open | **ne** | usp_Rpt_Customers_RptDailySales, usp_Rpt_Dispatch, usp_Rpt_Export_Accounting, usp_Rpt_Export_Email, usp_Rpt_Export_Heureka, usp_Rpt_Export_RptDailySales, usp_Rpt_Export_Sales_2026, usp_Rpt_Kpi_ExportQueue, usp_Rpt_Kpi_RptDailySales, usp_Rpt_Margin_RptDailySales, usp_Rpt_Margin_Sales_2024, usp_Rpt_RptDailySales_Cleanup, usp_Rpt_RptDailySales_Export, usp_Rpt_RptDailySales_List, usp_Rpt_RptDailySales_MonthClose, usp_Rpt_RptStockSnapshot_Cleanup, usp_Rpt_RptStockSnapshot_MonthClose, usp_Rpt_Sales_2024_Cleanup, usp_Rpt_Sales_2026_MonthClose, usp_Rpt_Stock_RptDailySales, usp_Rpt_Weekly_RptDailySales |

**Co chybí k dalšímu stavu:**

- doména má owning team (owning team není určen)

## Extraction readiness score

Skóre 72.3, pořadí 5. Extraction readiness score řadí domény k vyjmutí, stav core lane neurčuje.

## Pokrytí characterization tests

Živých procedur 21: verified 0, draft 0, missing 21. Zapisujících 19, z toho bez ověřeného testu 19.

Draft = test existuje, ale nemá doložený zelený běh (`run.json`). Draft core lane neotevře.

| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |
|---|---|---|---|---|---:|
| `usp_Rpt_Customers_ExportQueue` | mrtvá | – | – | RptStockSnapshot | 0 |
| `usp_Rpt_Customers_RptDailySales` | živá | – | – | RptDailySales | 292 |
| `usp_Rpt_Dispatch` | živá | – | – | ExportQueue | 12 096 |
| `usp_Rpt_Export_Accounting` | živá | – | – | ExportQueue | 5 851 |
| `usp_Rpt_Export_Email` | živá | – | – | ExportQueue | 2 050 |
| `usp_Rpt_Export_Heureka` | živá | – | – | ExportQueue | 3 499 |
| `usp_Rpt_Export_RptDailySales` | živá | – | – | RptDailySales | 67 |
| `usp_Rpt_Export_Sales_2026` | živá | – | – | RptDailySales | 293 |
| `usp_Rpt_Export_Supplier` | mrtvá | – | – | ExportQueue | 0 |
| `usp_Rpt_Kpi_ExportQueue` | živá | – | – | – | 142 |
| `usp_Rpt_Kpi_RptDailySales` | živá | – | – | RptStockSnapshot | 3 685 |
| `usp_Rpt_Margin_RptDailySales` | živá | – | – | RptDailySales, Sales_2025, Sales_2026 | 37 301 |
| `usp_Rpt_Margin_Sales_2024` | živá | – | – | Sales_2025, Sales_2026 | 12 393 |
| `usp_Rpt_RptDailySales_Cleanup` | živá | – | – | RptCustomerKpi, RptStockSnapshot, Sales_2023 | 2 |
| `usp_Rpt_RptDailySales_Export` | živá | – | – | RptCustomerKpi, Sales_2026 | 4 032 |
| `usp_Rpt_RptDailySales_List` | živá | – | – | – | 8 068 |
| `usp_Rpt_RptDailySales_MonthClose` | živá | – | – | ExportQueue, Sales_2025, Sales_2026 | 1 008 |
| `usp_Rpt_RptStockSnapshot_Cleanup` | živá | – | – | RptStockSnapshot, Sales_2024 | 42 |
| `usp_Rpt_RptStockSnapshot_MonthClose` | živá | – | – | RptDailySales | 4 032 |
| `usp_Rpt_Sales_2024_Cleanup` | živá | – | – | Sales_2024 | 42 |
| `usp_Rpt_Sales_2026_MonthClose` | živá | – | – | ExportQueue, RptDailySales | 2 |
| `usp_Rpt_Stock_RptDailySales` | živá | – | – | RptCustomerKpi | 5 030 |
| `usp_Rpt_Weekly_RptDailySales` | živá | – | – | RptStockSnapshot | 6 894 |

## Blind spots

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Rpt_Customers_RptDailySales` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Dispatch` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Export_Accounting` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Export_Email` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Export_Heureka` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Export_RptDailySales` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Export_Sales_2026` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Kpi_ExportQueue` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Kpi_RptDailySales` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Margin_RptDailySales` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Margin_Sales_2024` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_RptDailySales_Cleanup` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_RptDailySales_Export` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_RptDailySales_List` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_RptDailySales_MonthClose` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_RptStockSnapshot_Cleanup` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_RptStockSnapshot_MonthClose` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Sales_2024_Cleanup` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Sales_2026_MonthClose` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Stock_RptDailySales` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Weekly_RptDailySales` | client_composed_name | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_RptDailySales_Export` | cross_database | **ano** | zápis do Accounting.dbo.RptDailySales (katalog nemá ID) |
| `usp_Rpt_RptStockSnapshot_MonthClose` | cross_database | **ano** | zápis do Archive.dbo.RptStockSnapshot (katalog nemá ID) |
| `usp_Rpt_Kpi_RptDailySales` | caller_dependent | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Rpt_Dispatch` | dynamic_sql_blind | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: usp_Rpt_Export_Accounting, usp_Rpt_Export_Email, usp_Rpt_Export_Heureka (jen v okně měření) |
| `usp_Rpt_Margin_RptDailySales` | dynamic_sql_blind | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: Orders, Sales_2025, Sales_2026 (jen v okně měření) |
| `usp_Rpt_Margin_Sales_2024` | dynamic_sql_blind | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: Orders, Sales_2025, Sales_2026 (jen v okně měření) |
| `usp_Rpt_RptDailySales_MonthClose` | dynamic_sql_blind | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: Orders, Sales_2025, Sales_2026 (jen v okně měření) |
| `usp_Rpt_Customers_RptDailySales` | dynamic_sql_literal | ne | dynamické SQL, cíle jdou vyčíst z literálů |
| `usp_Rpt_Customers_RptDailySales` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Dispatch` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_Export_Heureka` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_Export_RptDailySales` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Export_Sales_2026` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Kpi_ExportQueue` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Kpi_RptDailySales` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Margin_RptDailySales` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Margin_Sales_2024` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_RptDailySales_Cleanup` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_RptDailySales_Export` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_RptDailySales_MonthClose` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_RptStockSnapshot_Cleanup` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_RptStockSnapshot_MonthClose` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_Sales_2024_Cleanup` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_Sales_2026_MonthClose` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_Stock_RptDailySales` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Weekly_RptDailySales` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Export_Accounting` | runtime_only | ne | volajícího zná jen běh (vnořené volání); klient ani plánovač o něm neví |
| `usp_Rpt_Export_Email` | runtime_only | ne | volajícího zná jen běh (vnořené volání); klient ani plánovač o něm neví |
| `usp_Rpt_Export_Heureka` | scheduler_non_tsql | ne | job KOMPAS - Feed Heureka volá proceduru z kroku PowerShell |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
