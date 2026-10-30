# Balíček důkazů: D:RptDailySales

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `3a31a99461f1…`). Strojová verze: `D-RptDailySales.json` (schéma `mapa-monolitu/dukazy@1`).

## Pruh core: **zavřený**

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo sloučí: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Vlastník: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má vlastnický tým | jen draft PR | **ne** | vlastník není určen |
| R2 doména je kandidát na vyjmutí (ne úklid, ne malý shluk) | jen draft PR | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | otevřený s vlastníkem | **ne** | 0 z 21 (0 %) |
| R4 všechny zapisující procedury mají zelený charakterizační test | otevřený s vlastníkem | **ne** | chybí 19: usp_Rpt_Customers_RptDailySales, usp_Rpt_Dispatch, usp_Rpt_Export_Accounting, usp_Rpt_Export_Email, usp_Rpt_Export_Heureka, usp_Rpt_Export_RptDailySales … |
| R5 blokujících slepých míst ≤ 0 | otevřený s vlastníkem | **ne** | usp_Rpt_Customers_RptDailySales, usp_Rpt_Dispatch, usp_Rpt_Export_Accounting, usp_Rpt_Export_Email, usp_Rpt_Export_Heureka, usp_Rpt_Export_RptDailySales, usp_Rpt_Export_Sales_2026, usp_Rpt_Kpi_ExportQueue, usp_Rpt_Kpi_RptDailySales, usp_Rpt_Margin_RptDailySales, usp_Rpt_Margin_Sales_2024, usp_Rpt_RptDailySales_Cleanup, usp_Rpt_RptDailySales_Export, usp_Rpt_RptDailySales_List, usp_Rpt_RptDailySales_MonthClose, usp_Rpt_RptStockSnapshot_Cleanup, usp_Rpt_RptStockSnapshot_MonthClose, usp_Rpt_Sales_2024_Cleanup, usp_Rpt_Sales_2026_MonthClose, usp_Rpt_Stock_RptDailySales, usp_Rpt_Weekly_RptDailySales |

**Co chybí k dalšímu stavu:**

- doména má vlastnický tým (vlastník není určen)

## Připravenost k vyjmutí

Skóre 72.3, pořadí 5. Skóre řadí domény k vyjmutí, stav pruhu neurčuje.

## Pokrytí charakterizačními testy

Živých procedur 21: ověřeno 0, jen návrh 0, chybí 21. Zapisujících 19, z toho bez ověřeného testu 19.

Návrh = test existuje, ale nemá doložený zelený běh (`beh.json`). Návrh pruh neotevře.

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

## Slepá místa

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Rpt_RptDailySales_Export` | jina_databaze | **ano** | zápis do Accounting.dbo.RptDailySales (katalog nemá ID) |
| `usp_Rpt_RptStockSnapshot_MonthClose` | jina_databaze | **ano** | zápis do Archive.dbo.RptStockSnapshot (katalog nemá ID) |
| `usp_Rpt_Customers_RptDailySales` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Dispatch` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Export_Accounting` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Export_Email` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Export_Heureka` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Export_RptDailySales` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Export_Sales_2026` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Kpi_ExportQueue` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Kpi_RptDailySales` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Margin_RptDailySales` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Margin_Sales_2024` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_RptDailySales_Cleanup` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_RptDailySales_Export` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_RptDailySales_List` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_RptDailySales_MonthClose` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_RptStockSnapshot_Cleanup` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_RptStockSnapshot_MonthClose` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Sales_2024_Cleanup` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Sales_2026_MonthClose` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Stock_RptDailySales` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Weekly_RptDailySales` | klient_sklada_jmeno | **ano** | klient skládá jméno procedury ('usp_Rpt_' + cbReport.Text, src\Konzole\Reporty\uReportRunner.pas:211); nevíme, které z nich volá |
| `usp_Rpt_Dispatch` | dynamicke_sql_slepe | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: usp_Rpt_Export_Accounting, usp_Rpt_Export_Email, usp_Rpt_Export_Heureka (jen v okně měření) |
| `usp_Rpt_Margin_RptDailySales` | dynamicke_sql_slepe | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: Orders, Sales_2025, Sales_2026 (jen v okně měření) |
| `usp_Rpt_Margin_Sales_2024` | dynamicke_sql_slepe | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: Orders, Sales_2025, Sales_2026 (jen v okně měření) |
| `usp_Rpt_RptDailySales_MonthClose` | dynamicke_sql_slepe | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: Orders, Sales_2025, Sales_2026 (jen v okně měření) |
| `usp_Rpt_Customers_RptDailySales` | dynamicke_sql_z_literalu | ne | dynamické SQL, cíle jdou vyčíst z literálů |
| `usp_Rpt_Export_Accounting` | jen_za_behu | ne | volajícího zná jen běh (vnořené volání); klient ani plánovač o něm neví |
| `usp_Rpt_Export_Email` | jen_za_behu | ne | volajícího zná jen běh (vnořené volání); klient ani plánovač o něm neví |
| `usp_Rpt_Export_Heureka` | planovac_mimo_tsql | ne | job KOMPAS - Feed Heureka volá proceduru z kroku PowerShell |
| `usp_Rpt_Kpi_RptDailySales` | volani_bez_schematu | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Rpt_Customers_RptDailySales` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Dispatch` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_Export_Heureka` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_Export_RptDailySales` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Export_Sales_2026` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Kpi_ExportQueue` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Kpi_RptDailySales` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Margin_RptDailySales` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Margin_Sales_2024` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_RptDailySales_Cleanup` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_RptDailySales_Export` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_RptDailySales_MonthClose` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_RptStockSnapshot_Cleanup` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_RptStockSnapshot_MonthClose` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_Sales_2024_Cleanup` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_Sales_2026_MonthClose` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Rpt_Stock_RptDailySales` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Rpt_Weekly_RptDailySales` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
