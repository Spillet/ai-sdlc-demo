# Balíček důkazů: D:Category (Katalog)

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `3a31a99461f1…`). Strojová verze: `D-Category.json` (schéma `mapa-monolitu/dukazy@1`).

## Pruh core: **jen draft PR**

- Kdo spustí agenta: kdokoli (záměr a akceptační kritéria)
- PR: vždy draft; brána jen okomentuje dopad a chybějící důkazy
- Kdo sloučí: vlastník po převzetí PR; první úkol agenta je doplnit charakterizační testy
- Vlastník: Katalog a obsah (fiktivní)

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má vlastnický tým | jen draft PR | ano | Katalog a obsah (fiktivní) |
| R2 doména je kandidát na vyjmutí (ne úklid, ne malý shluk) | jen draft PR | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | otevřený s vlastníkem | **ne** | 0 z 25 (0 %) |
| R4 všechny zapisující procedury mají zelený charakterizační test | otevřený s vlastníkem | **ne** | chybí 13: usp_Product_AttributeDef_Process, usp_Product_Brand_Cleanup, usp_Product_Brand_Insert, usp_Product_Category_Nightly, usp_Product_Category_Update, usp_Product_ProductAttribute_Approve … |
| R5 blokujících slepých míst ≤ 0 | otevřený s vlastníkem | **ne** | usp_Product_ProductAttribute_Cleanup |

**Co chybí k dalšímu stavu:**

- ověřené pokrytí živých procedur ≥ 80 % (0 z 25 (0 %))
- všechny zapisující procedury mají zelený charakterizační test (chybí 13: usp_Product_AttributeDef_Process, usp_Product_Brand_Cleanup, usp_Product_Brand_Insert, usp_Product_Category_Nightly, usp_Product_Category_Update, usp_Product_ProductAttribute_Approve …)
- blokujících slepých míst ≤ 0 (usp_Product_ProductAttribute_Cleanup)

## Připravenost k vyjmutí

Skóre 81.6, pořadí 2. Skóre řadí domény k vyjmutí, stav pruhu neurčuje.

## Pokrytí charakterizačními testy

Živých procedur 25: ověřeno 0, jen návrh 0, chybí 25. Zapisujících 13, z toho bez ověřeného testu 13.

Návrh = test existuje, ale nemá doložený zelený běh (`beh.json`). Návrh pruh neotevře.

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

## Slepá místa

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Product_ProductAttribute_Cleanup` | jina_databaze | **ano** | zápis do Archive.dbo.ProductAttribute_Archive (katalog nemá ID) |
| `usp_Product_Product_Rebuild` | dynamicke_sql_slepe | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: Category (jen v okně měření) |
| `usp_Product_ProductAttribute_Process` | jen_za_behu | ne | volajícího zná jen běh (Kompas.Web.Api); klient ani plánovač o něm neví |
| `usp_Product_Product_Dispatch` | jen_za_behu | ne | volajícího zná jen běh (Kompas.Web.Api); klient ani plánovač o něm neví |
| `usp_Product_Product_Find` | jen_za_behu | ne | volajícího zná jen běh (Kompas.Web.Api); klient ani plánovač o něm neví |
| `usp_Product_Product_Rebuild` | jen_za_behu | ne | volajícího zná jen běh (Kompas.Web.Api); klient ani plánovač o něm neví |
| `usp_Product_Brand_Insert` | volani_bez_schematu | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Product_Product_Cancel` | volani_bez_schematu | ne | volá usp_Product_Brand_List bez schématu (is_caller_dependent) |
| `usp_Product_Product_Dispatch` | volani_bez_schematu | ne | volá usp_Product_Brand_GetByCode bez schématu (is_caller_dependent) |
| `usp_Product_AttributeDef_Process` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Product_Brand_Cleanup` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Product_Category_Nightly` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Product_ProductAttribute_Cleanup` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Product_ProductCategory_GetByCode` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Product_Product_Cancel` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Product_Product_Confirm` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
