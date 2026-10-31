# Evidence pack: D:Warehouse

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `fed7344328f4…`). Strojová verze: `D-Warehouse.json` (schéma `mapa-monolitu/evidence-pack@2`).

## Core lane: **closed** (autonomy level L0)

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo udělá merge: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Owning team: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má owning team | draft-only | **ne** | owning team není určen |
| R2 doména je mezi domain candidates (ne úklid, ne malý shluk) | draft-only | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | open | **ne** | 0 z 41 (0 %) |
| R4 všechny zapisující procedury mají zelený characterization test | open | **ne** | chybí 27: spSklad_InventoryCount_Cancel, spSklad_InventoryCount_Merge, spSklad_InventoryCount_Nightly, spSklad_StockLevel_Close, spSklad_StockLevel_Delete, spSklad_StockLevel_Save … |
| R5 blokujících blind spots ≤ 0 | open | **ne** | usp_Import_Stock |

**Co chybí k dalšímu stavu:**

- doména má owning team (owning team není určen)

## Extraction readiness score

Skóre 69.5, pořadí 8. Extraction readiness score řadí domény k vyjmutí, stav core lane neurčuje.

## Pokrytí characterization tests

Živých procedur 41: verified 0, draft 0, missing 41. Zapisujících 27, z toho bez ověřeného testu 27.

Draft = test existuje, ale nemá doložený zelený běh (`run.json`). Draft core lane neotevře.

| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |
|---|---|---|---|---|---:|
| `spSklad_InventoryCount_Cancel` | živá | – | – | **StockLevel**, **StockReservation** | 19 428 |
| `spSklad_InventoryCount_Check` | živá | – | – | – | 27 383 |
| `spSklad_InventoryCount_Merge` | živá | – | – | InventoryCount | 4 029 |
| `spSklad_InventoryCount_Nightly` | živá | – | – | InventoryCountItem, Location, **Product** | 2 |
| `spSklad_Location_Get` | živá | – | – | – | 45 123 |
| `spSklad_Location_Update` | mrtvá | – | – | Location | 0 |
| `spSklad_StockLevel_Close` | živá | – | – | **StockLevel** | 8 152 |
| `spSklad_StockLevel_Delete` | živá | – | – | Location, **StockLevel** | 899 |
| `spSklad_StockLevel_Get` | živá | – | – | – | 1 |
| `spSklad_StockLevel_GetByCode` | živá | – | – | – | 1 |
| `spSklad_StockLevel_List` | živá | – | – | – | 18 271 |
| `spSklad_StockLevel_Overview` | živá | – | – | – | 566 |
| `spSklad_StockLevel_Save` | živá | – | – | **Product**, **StockLevel** | 3 653 |
| `spSklad_StockLevel_Update` | živá | – | – | **StockLevel** | 6 177 |
| `spSklad_StockMovement_Update` | živá | – | – | StockMovement | 32 530 |
| `spSklad_StockReservation_Export` | živá | – | – | PurchaseOrder, StockMovement | 4 032 |
| `spSklad_Warehouse_Approve` | živá | – | – | StockMovement, Warehouse | 8 923 |
| `spSklad_Warehouse_Cancel` | mrtvá | – | – | **Orders**, **StockLevel**, Warehouse | 0 |
| `spSklad_Warehouse_Check` | živá | – | – | – | 2 741 |
| `spSklad_Warehouse_Delete` | živá | – | – | StockMovement, Warehouse | 3 217 |
| `spSklad_Warehouse_Export` | živá | – | – | InventoryCountItem, Location, **Product** | 2 |
| `spSklad_Warehouse_GetByCode` | živá | – | – | – | 715 |
| `spSklad_Warehouse_Import` | živá | – | – | PurchaseOrder, Warehouse | 14 622 |
| `spSklad_Warehouse_Overview` | živá | – | – | – | 1 |
| `spSklad_Warehouse_Process` | mrtvá | – | – | PurchaseOrder, **StockLevel**, **StockReservation** | 0 |
| `spSklad_Warehouse_Save` | živá | – | – | Warehouse | 6 974 |
| `spSklad_Warehouse_SetStatus` | živá | – | – | InventoryCountItem, Warehouse | 27 941 |
| `usp_Import_Product` | mrtvá | – | – | ImportPrice | 0 |
| `usp_Import_Stock` | živá | – | – | ImportPrice, **StockLevel** | 1 008 |
| `usp_Migr2019_Product` | mrtvá | – | – | ImportPrice | 0 |
| `usp_Old_CustomerMerge` | mrtvá | – | – | ImportStock, **Product** | 0 |
| `usp_Po_GoodsReceiptItem_Close` | živá | – | – | GoodsReceiptItem | 2 669 |
| `usp_Po_GoodsReceipt_Get` | živá | – | – | – | 197 |
| `usp_Po_GoodsReceipt_GetDetail` | živá | – | – | – | 9 369 |
| `usp_Po_GoodsReceipt_Sync` | živá | – | – | **Product**, PurchaseOrder, SupplierProduct | 26 501 |
| `usp_Po_PurchaseOrderItem_Delete` | živá | – | – | **Product**, PurchaseOrderItem, Supplier | 2 820 |
| `usp_Po_PurchaseOrderItem_Insert` | živá | – | – | **Product**, PurchaseOrderItem | 4 064 |
| `usp_Po_PurchaseOrder_List` | živá | – | – | – | 8 031 |
| `usp_Po_SupplierProduct_Delete` | živá | – | – | GoodsReceipt, **Product**, SupplierProduct | 23 461 |
| `usp_Po_SupplierProduct_GetDetail` | živá | – | – | – | 15 146 |
| `usp_Po_Supplier_Cancel` | živá | – | – | PurchaseOrder, **StockLevel**, SupplierProduct | 317 |
| `usp_Po_Supplier_Close` | živá | – | – | Supplier, SupplierProduct | 31 058 |
| `usp_Po_Supplier_Dispatch` | živá | – | – | PurchaseOrder, Supplier | 2 178 |
| `usp_Po_Supplier_GetDetail` | živá | – | – | – | 17 973 |
| `usp_Po_Supplier_Hourly` | živá | – | – | PurchaseOrder, **StockLevel**, SupplierProduct | 4 032 |
| `usp_Po_Supplier_Recalc` | živá | – | – | Supplier | 758 |
| `usp_Po_Supplier_SetStatus` | živá | – | – | PurchaseOrderItem, Supplier | 18 212 |

## Blind spots

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Import_Stock` | dynamic_sql_blind | **ano** | jméno objektu se skládá za běhu a běh žádný cíl nezachytil |
| `spSklad_Warehouse_Delete` | caller_dependent | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `spSklad_Warehouse_SetStatus` | dynamic_sql_literal | ne | dynamické SQL, cíle jdou vyčíst z literálů |
| `spSklad_InventoryCount_Cancel` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `spSklad_InventoryCount_Check` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `spSklad_InventoryCount_Nightly` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `spSklad_StockLevel_Close` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `spSklad_StockLevel_Delete` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `spSklad_StockReservation_Export` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `spSklad_Warehouse_Approve` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `spSklad_Warehouse_Delete` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `spSklad_Warehouse_Export` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `spSklad_Warehouse_SetStatus` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Import_Stock` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Po_GoodsReceipt_Get` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Po_GoodsReceipt_GetDetail` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Po_GoodsReceipt_Sync` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Po_Supplier_Cancel` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Po_Supplier_Close` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Po_Supplier_Dispatch` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Po_Supplier_Hourly` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Po_Supplier_SetStatus` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
