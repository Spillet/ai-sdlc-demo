# Evidence pack: D:CustomerAddress

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `fed7344328f4…`). Strojová verze: `D-CustomerAddress.json` (schéma `mapa-monolitu/evidence-pack@2`).

## Core lane: **closed** (autonomy level L0)

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo udělá merge: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Owning team: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má owning team | draft-only | **ne** | owning team není určen |
| R2 doména je mezi domain candidates (ne úklid, ne malý shluk) | draft-only | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | open | **ne** | 0 z 19 (0 %) |
| R4 všechny zapisující procedury mají zelený characterization test | open | **ne** | chybí 15: usp_Cust_CustomerAddress_Close, usp_Cust_CustomerAddress_Confirm, usp_Cust_CustomerAddress_Dispatch, usp_Cust_CustomerContact_MonthClose, usp_Cust_CustomerSegment_Close, usp_Cust_CustomerSegment_Dispatch … |
| R5 blokujících blind spots ≤ 0 | open | **ne** | usp_Cust_Customer_Nightly |

**Co chybí k dalšímu stavu:**

- doména má owning team (owning team není určen)

## Extraction readiness score

Skóre 71.9, pořadí 6. Extraction readiness score řadí domény k vyjmutí, stav core lane neurčuje.

## Pokrytí characterization tests

Živých procedur 19: verified 0, draft 0, missing 19. Zapisujících 15, z toho bez ověřeného testu 15.

Draft = test existuje, ale nemá doložený zelený běh (`run.json`). Draft core lane neotevře.

| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |
|---|---|---|---|---|---:|
| `usp_Cust_CustomerAddress_Close` | živá | – | – | CustomerAddress | 1 852 |
| `usp_Cust_CustomerAddress_Confirm` | živá | – | – | CustomerContact, LoyaltyTransaction | 2 112 |
| `usp_Cust_CustomerAddress_Dispatch` | živá | – | – | LoyaltyAccount, LoyaltyTransaction | 2 974 |
| `usp_Cust_CustomerAddress_List` | živá | – | – | – | 10 426 |
| `usp_Cust_CustomerContact_MonthClose` | živá | – | – | Consent, CustomerAddress, LoyaltyAccount | 1 008 |
| `usp_Cust_CustomerSegment_Close` | živá | – | – | CustomerSegment | 1 111 |
| `usp_Cust_CustomerSegment_Delete` | mrtvá | – | – | CustomerSegment | 0 |
| `usp_Cust_CustomerSegment_Dispatch` | živá | – | – | **Customer**, CustomerAddress | 233 |
| `usp_Cust_Customer_Approve` | živá | – | – | **Customer** | 2 842 |
| `usp_Cust_Customer_Find` | živá | – | – | – | 4 122 |
| `usp_Cust_Customer_Insert` | živá | – | – | **Customer** | 19 297 |
| `usp_Cust_Customer_Merge` | živá | – | – | **Customer** | 1 555 |
| `usp_Cust_Customer_MonthClose` | živá | – | – | Consent, CustomerAddress, LoyaltyTransaction | 42 |
| `usp_Cust_Customer_Nightly` | živá | – | – | Consent, CustomerSegment, LoyaltyTransaction, **Orders** | 1 008 |
| `usp_Cust_Customer_Rebuild` | živá | – | – | CustomerAddress, CustomerSegment | 33 813 |
| `usp_Cust_Customer_Recalc` | živá | – | – | **Customer**, CustomerSegment, **Orders** | 787 |
| `usp_Cust_Customer_Save` | živá | – | – | **Customer** | 13 802 |
| `usp_Cust_Customer_Sync` | mrtvá | – | – | **Customer**, LoyaltyAccount | 0 |
| `usp_Cust_LoyaltyAccount_Merge` | živá | – | – | LoyaltyAccount | 29 294 |
| `usp_Cust_LoyaltyTransaction_GetByCode` | živá | – | – | – | 12 778 |
| `usp_Ship_Shipment_List` | živá | – | – | – | 103 |

## Blind spots

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Cust_Customer_Nightly` | cross_database | **ano** | zápis do DWH.dbo.Customer_Archive (katalog nemá ID) |
| `usp_Cust_CustomerSegment_Dispatch` | caller_dependent | ne | volá usp_Cust_Customer_Insert bez schématu (is_caller_dependent) |
| `usp_Cust_Customer_Recalc` | caller_dependent | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Cust_CustomerAddress_Confirm` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Cust_CustomerAddress_Dispatch` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Cust_CustomerContact_MonthClose` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Cust_CustomerSegment_Dispatch` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Cust_Customer_MonthClose` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Cust_Customer_Nightly` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Cust_Customer_Rebuild` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_Shipment_List` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
