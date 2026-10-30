# Balíček důkazů: D:Claim (Reklamace)

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `3a31a99461f1…`). Strojová verze: `D-Claim.json` (schéma `mapa-monolitu/dukazy@1`).

## Pruh core: **jen draft PR**

- Kdo spustí agenta: kdokoli (záměr a akceptační kritéria)
- PR: vždy draft; brána jen okomentuje dopad a chybějící důkazy
- Kdo sloučí: vlastník po převzetí PR; první úkol agenta je doplnit charakterizační testy
- Vlastník: Poprodej (fiktivní)

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má vlastnický tým | jen draft PR | ano | Poprodej (fiktivní) |
| R2 doména je kandidát na vyjmutí (ne úklid, ne malý shluk) | jen draft PR | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | otevřený s vlastníkem | **ne** | 0 z 18 (0 %) |
| R4 všechny zapisující procedury mají zelený charakterizační test | otevřený s vlastníkem | **ne** | chybí 13: usp_Claim_ClaimReason_Cleanup, usp_Claim_ClaimReason_Hourly, usp_Claim_ClaimStatusHistory_Cleanup, usp_Claim_ClaimStatusHistory_Confirm, usp_Claim_ClaimStatusHistory_Delete, usp_Claim_ClaimStatusHistory_Merge … |
| R5 blokujících slepých míst ≤ 0 | otevřený s vlastníkem | ano | žádné |

**Co chybí k dalšímu stavu:**

- ověřené pokrytí živých procedur ≥ 80 % (0 z 18 (0 %))
- všechny zapisující procedury mají zelený charakterizační test (chybí 13: usp_Claim_ClaimReason_Cleanup, usp_Claim_ClaimReason_Hourly, usp_Claim_ClaimStatusHistory_Cleanup, usp_Claim_ClaimStatusHistory_Confirm, usp_Claim_ClaimStatusHistory_Delete, usp_Claim_ClaimStatusHistory_Merge …)

## Připravenost k vyjmutí

Skóre 83.2, pořadí 1. Skóre řadí domény k vyjmutí, stav pruhu neurčuje.

## Pokrytí charakterizačními testy

Živých procedur 18: ověřeno 0, jen návrh 3, chybí 15. Zapisujících 13, z toho bez ověřeného testu 13.

Návrh = test existuje, ale nemá doložený zelený běh (`beh.json`). Návrh pruh neotevře.

| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |
|---|---|---|---|---|---:|
| `usp_Claim_ClaimItem_GetByCode` | živá | – | – | – | 410 |
| `usp_Claim_ClaimReason_Cleanup` | živá | – | – | ClaimDocument, ReturnRequest | 42 |
| `usp_Claim_ClaimReason_Hourly` | živá | – | – | ClaimStatusHistory | 42 |
| `usp_Claim_ClaimStatusHistory_Cleanup` | živá | – | – | Claim, ClaimItem, ReturnRequest | 42 |
| `usp_Claim_ClaimStatusHistory_Confirm` | živá | – | – | ClaimItem, ClaimStatusHistory | 1 064 |
| `usp_Claim_ClaimStatusHistory_Delete` | živá | – | – | ClaimDocument, ClaimStatusHistory | 1 022 |
| `usp_Claim_ClaimStatusHistory_Merge` | živá | – | – | ClaimStatusHistory | 1 772 |
| `usp_Claim_Claim_Archive` | živá | – | – | ReturnRequest | 4 032 |
| `usp_Claim_Claim_Delete` | živá | – | – | Claim | 4 081 |
| `usp_Claim_Claim_Get` | živá | – | – | – | 2 923 |
| `usp_Claim_Claim_Insert` | mrtvá | – | – | Claim | 0 |
| `usp_Claim_Claim_Overview` | živá | – | – | – | 1 515 |
| `usp_Claim_Create` | živá | – | navrh | Claim, ClaimItem, ClaimStatusHistory | 199 741 |
| `usp_Claim_GetDetail` | živá | navrh | – | – | 84 948 |
| `usp_Claim_Notify` | živá | – | – | **ExportQueue** | 36 |
| `usp_Claim_OverdueCheck` | živá | – | – | Claim, ClaimStatusHistory | 42 |
| `usp_Claim_Search` | živá | – | – | – | 13 848 |
| `usp_Claim_ServiceCenter_Merge` | živá | – | – | ServiceCenter | 1 498 |
| `usp_Claim_SetStatus` | živá | – | navrh | Claim, ClaimStatusHistory, **StockLevel** | 21 |

## Slepá místa

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Claim_ClaimItem_GetByCode` | dynamicke_sql_z_literalu | ne | dynamické SQL, cíle jdou vyčíst z literálů |
| `usp_Claim_Search` | dynamicke_sql_z_literalu | ne | dynamické SQL, cíle jdou vyčíst z literálů |
| `usp_Claim_Claim_Get` | volani_bez_schematu | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Claim_ClaimReason_Cleanup` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Claim_ClaimReason_Hourly` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Claim_ClaimStatusHistory_Cleanup` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Claim_ClaimStatusHistory_Confirm` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Claim_Claim_Archive` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Claim_Create` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Claim_GetDetail` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Claim_OverdueCheck` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Claim_Search` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Claim_SetStatus` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
