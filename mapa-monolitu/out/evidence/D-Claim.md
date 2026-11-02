# Evidence pack: D:Claim (Reklamace)

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `fed7344328f4…`). Strojová verze: `D-Claim.json` (schéma `mapa-monolitu/evidence-pack@2`).

## Core lane: **draft-only** (autonomy level L1)

- Kdo spustí agenta: kdokoli (záměr a akceptační kritéria)
- PR: vždy draft; risk gate jen okomentuje dopad a chybějící důkazy
- Kdo udělá merge: vlastník po převzetí PR; první úkol agenta je doplnit characterization tests
- Owning team: Poprodej (fiktivní)

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má owning team | draft-only | ano | Poprodej (fiktivní) |
| R2 doména je mezi domain candidates (ne úklid, ne malý shluk) | draft-only | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | open | **ne** | 0 z 18 (0 %) |
| R4 všechny zapisující procedury mají zelený characterization test | open | **ne** | chybí 13: usp_Claim_ClaimReason_Cleanup, usp_Claim_ClaimReason_Hourly, usp_Claim_ClaimStatusHistory_Cleanup, usp_Claim_ClaimStatusHistory_Confirm, usp_Claim_ClaimStatusHistory_Delete, usp_Claim_ClaimStatusHistory_Merge … |
| R5 blokujících blind spots ≤ 0 | open | ano | žádné |

**Co chybí k dalšímu stavu:**

- ověřené pokrytí živých procedur ≥ 80 % (0 z 18 (0 %))
- všechny zapisující procedury mají zelený characterization test (chybí 13: usp_Claim_ClaimReason_Cleanup, usp_Claim_ClaimReason_Hourly, usp_Claim_ClaimStatusHistory_Cleanup, usp_Claim_ClaimStatusHistory_Confirm, usp_Claim_ClaimStatusHistory_Delete, usp_Claim_ClaimStatusHistory_Merge …)

## Extraction readiness score

Skóre 83.2, pořadí 1. Extraction readiness score řadí domény k vyjmutí, stav core lane neurčuje.

## Pokrytí characterization tests

Živých procedur 18: verified 0, draft 3, missing 15. Zapisujících 13, z toho bez ověřeného testu 13.

Draft = test existuje, ale nemá doložený zelený běh (`run.json`). Draft core lane neotevře.

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
| `usp_Claim_Create` | živá | – | draft | Claim, ClaimItem, ClaimStatusHistory | 199 741 |
| `usp_Claim_GetDetail` | živá | draft | – | – | 84 948 |
| `usp_Claim_Notify` | živá | – | – | **ExportQueue** | 36 |
| `usp_Claim_OverdueCheck` | živá | – | – | Claim, ClaimStatusHistory | 42 |
| `usp_Claim_Search` | živá | – | – | – | 13 848 |
| `usp_Claim_ServiceCenter_Merge` | živá | – | – | ServiceCenter | 1 498 |
| `usp_Claim_SetStatus` | živá | – | draft | Claim, ClaimStatusHistory, **StockLevel** | 21 |

## Blind spots

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Claim_Claim_Get` | caller_dependent | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Claim_ClaimItem_GetByCode` | dynamic_sql_literal | ne | dynamické SQL, cíle jdou vyčíst z literálů |
| `usp_Claim_Search` | dynamic_sql_literal | ne | dynamické SQL, cíle jdou vyčíst z literálů |
| `usp_Claim_ClaimReason_Cleanup` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Claim_ClaimReason_Hourly` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Claim_ClaimStatusHistory_Cleanup` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Claim_ClaimStatusHistory_Confirm` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Claim_Claim_Archive` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Claim_Create` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Claim_GetDetail` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Claim_OverdueCheck` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Claim_Search` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Claim_SetStatus` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
