# Balíček důkazů: D:CustomerAddress

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `3a31a99461f1…`). Strojová verze: `D-CustomerAddress.json` (schéma `mapa-monolitu/dukazy@1`).

## Pruh core: **zavřený**

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo sloučí: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Vlastník: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má vlastnický tým | jen draft PR | **ne** | vlastník není určen |
| R2 doména je kandidát na vyjmutí (ne úklid, ne malý shluk) | jen draft PR | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | otevřený s vlastníkem | **ne** | 0 z 19 (0 %) |
| R4 všechny zapisující procedury mají zelený charakterizační test | otevřený s vlastníkem | **ne** | chybí 15: usp_Cust_CustomerAddress_Close, usp_Cust_CustomerAddress_Confirm, usp_Cust_CustomerAddress_Dispatch, usp_Cust_CustomerContact_MonthClose, usp_Cust_CustomerSegment_Close, usp_Cust_CustomerSegment_Dispatch … |
| R5 blokujících slepých míst ≤ 0 | otevřený s vlastníkem | **ne** | usp_Cust_Customer_Nightly |

**Co chybí k dalšímu stavu:**

- doména má vlastnický tým (vlastník není určen)

## Připravenost k vyjmutí

Skóre 71.9, pořadí 6. Skóre řadí domény k vyjmutí, stav pruhu neurčuje.

## Pokrytí charakterizačními testy

Živých procedur 19: ověřeno 0, jen návrh 0, chybí 19. Zapisujících 15, z toho bez ověřeného testu 15.

Návrh = test existuje, ale nemá doložený zelený běh (`beh.json`). Návrh pruh neotevře.

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

## Slepá místa

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Cust_Customer_Nightly` | jina_databaze | **ano** | zápis do DWH.dbo.Customer_Archive (katalog nemá ID) |
| `usp_Cust_CustomerSegment_Dispatch` | volani_bez_schematu | ne | volá usp_Cust_Customer_Insert bez schématu (is_caller_dependent) |
| `usp_Cust_Customer_Recalc` | volani_bez_schematu | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Cust_CustomerAddress_Confirm` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Cust_CustomerAddress_Dispatch` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Cust_CustomerContact_MonthClose` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Cust_CustomerSegment_Dispatch` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Cust_Customer_MonthClose` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Cust_Customer_Nightly` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Cust_Customer_Rebuild` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_Shipment_List` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
