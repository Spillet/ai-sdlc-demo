# Evidence pack: D:Category (Katalog)

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `fed7344328f4…`). Strojová verze: `D-Category.json` (schéma `mapa-monolitu/evidence-pack@2`).

## Core lane: **draft-only** (autonomy level L1)

- Kdo spustí agenta: kdokoli (záměr a akceptační kritéria)
- PR: vždy draft; risk gate jen okomentuje dopad a chybějící důkazy
- Kdo udělá merge: vlastník po převzetí PR; první úkol agenta je doplnit characterization tests
- Owning team: Katalog a obsah (fiktivní)

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má owning team | draft-only | ano | Katalog a obsah (fiktivní) |
| R2 doména je mezi domain candidates (ne úklid, ne malý shluk) | draft-only | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | open | **ne** | 0 z 25 (0 %) |
| R4 všechny zapisující procedury mají zelený characterization test | open | **ne** | chybí 13: usp_Product_AttributeDef_Process, usp_Product_Brand_Cleanup, usp_Product_Brand_Insert, usp_Product_Category_Nightly, usp_Product_Category_Update, usp_Product_ProductAttribute_Approve … |
| R5 blokujících blind spots ≤ 0 | open | **ne** | usp_Product_ProductAttribute_Cleanup |

**Co chybí k dalšímu stavu:**

- ověřené pokrytí živých procedur ≥ 80 % (0 z 25 (0 %))
- všechny zapisující procedury mají zelený characterization test (chybí 13: usp_Product_AttributeDef_Process, usp_Product_Brand_Cleanup, usp_Product_Brand_Insert, usp_Product_Category_Nightly, usp_Product_Category_Update, usp_Product_ProductAttribute_Approve …)
- blokujících blind spots ≤ 0 (usp_Product_ProductAttribute_Cleanup)

## Extraction readiness score

Skóre 81.6, pořadí 2. Extraction readiness score řadí domény k vyjmutí, stav core lane neurčuje.

## Pokrytí characterization tests

Živých procedur 25: verified 0, draft 0, missing 25. Zapisujících 13, z toho bez ověřeného testu 13.

Draft = test existuje, ale nemá doložený zelený běh (`run.json`). Draft core lane neotevře.

| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |
|---|---|---|---|---|---:|
| `usp_Price_PriceListItem_List` | živá | – | – | – | 216 869 |
| `usp_Price_Promo_GetDetail` | živá | – | – | – | 131 968 |
| `usp_Product_AttributeDef_Check` | živá | – | – | – | 110 771 |
| `usp_Product_AttributeDef_Overview` | živá | – | – | – | 327 622 |
| `usp_Product_AttributeDef_Process` | živá | – | – | Brand, **Product** | 51 |
| `usp_Product_Brand_Cleanup` | živá | – | – | Category, ProductCategory, ProductImage | 2 |
| `usp_Product_Brand_GetByCode` | živá | – | – | – | 672 868 |
| `usp_Product_Brand_Insert` | živá | – | – | Brand | 357 665 |
| `usp_Product_Brand_List` | živá | – | – | – | 3 170 |
| `usp_Product_Category_Nightly` | živá | – | – | Category, ProductCategory, ProductText | 2 |
| `usp_Product_Category_Update` | živá | – | – | Category | 61 524 |
| `usp_Product_ProductAttribute_Approve` | živá | – | – | ProductAttribute, ProductImage | 558 652 |
| `usp_Product_ProductAttribute_Cleanup` | živá | – | – | ProductImage, ProductText | 2 |
| `usp_Product_ProductAttribute_Process` | živá | – | – | Category, ProductImage | 371 144 |
| `usp_Product_ProductCategory_GetByCode` | živá | – | – | – | 29 102 |
| `usp_Product_ProductImage_GetByCode` | živá | – | – | – | 545 702 |
| `usp_Product_Product_Cancel` | živá | – | – | AttributeDef, ProductText | 3 959 |
| `usp_Product_Product_Check` | živá | – | – | – | 292 754 |
| `usp_Product_Product_Confirm` | živá | – | – | **Product**, ProductText | 260 |
| `usp_Product_Product_Dispatch` | živá | – | – | AttributeDef, ProductCategory | 535 083 |
| `usp_Product_Product_Find` | živá | – | – | – | 389 172 |
| `usp_Product_Product_GetByCode` | živá | – | – | – | 8 707 |
| `usp_Product_Product_Import` | živá | – | – | **Product** | 7 992 |
| `usp_Product_Product_Rebuild` | živá | – | – | Brand, Category, ProductText, **StockLevel** | 181 616 |
| `usp_Product_Product_Search` | živá | – | – | – | 177 |

## Blind spots

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Product_ProductAttribute_Cleanup` | cross_database | **ano** | zápis do Archive.dbo.ProductAttribute_Archive (katalog nemá ID) |
| `usp_Product_Brand_Insert` | caller_dependent | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Product_Product_Cancel` | caller_dependent | ne | volá usp_Product_Brand_List bez schématu (is_caller_dependent) |
| `usp_Product_Product_Dispatch` | caller_dependent | ne | volá usp_Product_Brand_GetByCode bez schématu (is_caller_dependent) |
| `usp_Product_Product_Rebuild` | dynamic_sql_blind | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: Category (jen v okně měření) |
| `usp_Product_AttributeDef_Process` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Product_Brand_Cleanup` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Product_Category_Nightly` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Product_ProductAttribute_Cleanup` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Product_ProductCategory_GetByCode` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Product_Product_Cancel` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Product_Product_Confirm` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Product_ProductAttribute_Process` | runtime_only | ne | volajícího zná jen běh (Kompas.Web.Api); klient ani plánovač o něm neví |
| `usp_Product_Product_Dispatch` | runtime_only | ne | volajícího zná jen běh (Kompas.Web.Api); klient ani plánovač o něm neví |
| `usp_Product_Product_Find` | runtime_only | ne | volajícího zná jen běh (Kompas.Web.Api); klient ani plánovač o něm neví |
| `usp_Product_Product_Rebuild` | runtime_only | ne | volajícího zná jen běh (Kompas.Web.Api); klient ani plánovač o něm neví |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
