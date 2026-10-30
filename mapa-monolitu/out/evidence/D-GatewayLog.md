# Balíček důkazů: D:GatewayLog

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `3a31a99461f1…`). Strojová verze: `D-GatewayLog.json` (schéma `mapa-monolitu/dukazy@1`).

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
| R4 všechny zapisující procedury mají zelený charakterizační test | otevřený s vlastníkem | **ne** | chybí 15: usp_Pay_GatewayLog_Merge, usp_Pay_GatewayLog_Recalc, usp_Pay_GatewayLog_Update, usp_Pay_Installment_Delete, usp_Pay_Installment_Save, usp_Pay_PaymentMethod_Close … |
| R5 blokujících slepých míst ≤ 0 | otevřený s vlastníkem | **ne** | usp_Pay_Payment_Cleanup |

**Co chybí k dalšímu stavu:**

- doména má vlastnický tým (vlastník není určen)

## Připravenost k vyjmutí

Skóre 72.9, pořadí 4. Skóre řadí domény k vyjmutí, stav pruhu neurčuje.

## Pokrytí charakterizačními testy

Živých procedur 18: ověřeno 0, jen návrh 0, chybí 18. Zapisujících 15, z toho bez ověřeného testu 15.

Návrh = test existuje, ale nemá doložený zelený běh (`beh.json`). Návrh pruh neotevře.

| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |
|---|---|---|---|---|---:|
| `usp_Pay_GatewayLog_Merge` | živá | – | – | GatewayLog, PaymentTransaction | 20 304 |
| `usp_Pay_GatewayLog_Recalc` | živá | – | – | GatewayLog, Refund | 16 390 |
| `usp_Pay_GatewayLog_Update` | živá | – | – | GatewayLog, Installment | 35 518 |
| `usp_Pay_Installment_Delete` | živá | – | – | Installment, **Payment** | 2 842 |
| `usp_Pay_Installment_Save` | živá | – | – | Installment | 101 |
| `usp_Pay_PaymentMethod_Close` | živá | – | – | **Orders**, PaymentMethod | 2 014 |
| `usp_Pay_PaymentMethod_SetStatus` | živá | – | – | PaymentMethod | 1 386 |
| `usp_Pay_PaymentTransaction_Dispatch` | živá | – | – | PaymentTransaction, Refund | 1 421 |
| `usp_Pay_PaymentTransaction_Sync` | živá | – | – | GatewayLog, **Orders**, PaymentMethod | 4 130 |
| `usp_Pay_PaymentTransaction_Update` | živá | – | – | **Orders**, PaymentTransaction | 7 696 |
| `usp_Pay_Payment_Cancel` | živá | – | – | GatewayLog, **Payment** | 260 |
| `usp_Pay_Payment_Cleanup` | živá | – | – | GatewayLog, Installment, Refund | 42 |
| `usp_Pay_Payment_Get` | živá | – | – | – | 259 |
| `usp_Pay_Payment_GetByCode` | živá | – | – | – | 5 585 |
| `usp_Pay_Payment_List` | živá | – | – | – | 8 307 |
| `usp_Pay_Payment_Search` | živá | – | – | PaymentMethod | 17 925 |
| `usp_Pay_Refund_Insert` | živá | – | – | Refund | 22 |
| `usp_Refund_Create` | živá | – | – | PaymentTransaction, Refund | 19 |

## Slepá místa

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Pay_Payment_Cleanup` | jina_databaze | **ano** | zápis do Accounting.dbo.Payment_Archive (katalog nemá ID) |
| `usp_Pay_Payment_Search` | dynamicke_sql_slepe | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: PaymentMethod (jen v okně měření) |
| `usp_Pay_GatewayLog_Update` | volani_bez_schematu | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Pay_GatewayLog_Update` | volani_bez_schematu | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Pay_Installment_Delete` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Pay_PaymentTransaction_Dispatch` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Pay_PaymentTransaction_Sync` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Pay_Payment_Cancel` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Pay_Payment_Cleanup` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Pay_Payment_List` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
