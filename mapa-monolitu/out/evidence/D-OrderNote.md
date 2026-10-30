# Balíček důkazů: D:OrderNote

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `3a31a99461f1…`). Strojová verze: `D-OrderNote.json` (schéma `mapa-monolitu/dukazy@1`).

## Pruh core: **zavřený**

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo sloučí: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Vlastník: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má vlastnický tým | jen draft PR | **ne** | vlastník není určen |
| R2 doména je kandidát na vyjmutí (ne úklid, ne malý shluk) | jen draft PR | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | otevřený s vlastníkem | **ne** | 0 z 38 (0 %) |
| R4 všechny zapisující procedury mají zelený charakterizační test | otevřený s vlastníkem | **ne** | chybí 28: spSklad_Warehouse_Update, usp_Inv_Invoice_SetStatus, usp_Inv_Invoice_Update, usp_Order_Cancel, usp_Order_CartItem_Archive, usp_Order_CartItem_Cleanup … |
| R5 blokujících slepých míst ≤ 0 | otevřený s vlastníkem | **ne** | usp_Order_Export, usp_Order_OrderEvent_MonthClose, usp_Order_OrderNote_Nightly, usp_Order_OrderStatusHistory_Archive |

**Co chybí k dalšímu stavu:**

- doména má vlastnický tým (vlastník není určen)

## Připravenost k vyjmutí

Skóre 57.3, pořadí 10. Skóre řadí domény k vyjmutí, stav pruhu neurčuje.

## Pokrytí charakterizačními testy

Živých procedur 38: ověřeno 0, jen návrh 0, chybí 38. Zapisujících 28, z toho bez ověřeného testu 28.

Návrh = test existuje, ale nemá doložený zelený běh (`beh.json`). Návrh pruh neotevře.

| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |
|---|---|---|---|---|---:|
| `spSklad_Warehouse_Update` | živá | – | – | **Orders**, **Warehouse** | 1 |
| `usp_Inv_Invoice_SetStatus` | živá | – | – | Invoice | 97 |
| `usp_Inv_Invoice_Update` | živá | – | – | **ExchangeRate**, Invoice, **Orders** | 149 |
| `usp_Order_Cancel` | živá | – | – | **OrderItem**, OrderNote, **Payment** | 151 |
| `usp_Order_CartItem_Archive` | živá | – | – | Cart, CartItem, OrderStatusHistory, **StockLevel** | 2 |
| `usp_Order_CartItem_Cleanup` | živá | – | – | OrderStatusHistory | 42 |
| `usp_Order_CartItem_Merge` | živá | – | – | Cart, CartItem | 91 |
| `usp_Order_CartItem_Update` | živá | – | – | CartItem | 910 |
| `usp_Order_Cart_Get` | živá | – | – | – | 1 |
| `usp_Order_Cart_GetByCode` | živá | – | – | – | 1 504 |
| `usp_Order_Cart_GetDetail` | živá | – | – | – | 110 |
| `usp_Order_Cart_List` | živá | – | – | – | 14 417 |
| `usp_Order_Cart_Search` | živá | – | – | – | 917 |
| `usp_Order_Create` | živá | – | – | **OrderItem**, OrderStatusHistory, **Orders**, StockReservation, VoucherUse | 46 301 |
| `usp_Order_Delete` | živá | – | – | **Customer**, OrderNote, **Orders** | 785 |
| `usp_Order_Dispatch` | živá | – | – | OrderEvent, OrderStatusHistory, VoucherUse | 198 |
| `usp_Order_Export` | živá | – | – | **OrderItem**, **Orders**, **Payment** | 2 |
| `usp_Order_OrderEvent_Cancel` | živá | – | – | CartItem, **Customer**, OrderNote, **Orders** | 25 |
| `usp_Order_OrderEvent_Find` | živá | – | – | – | 130 |
| `usp_Order_OrderEvent_MonthClose` | živá | – | – | Cart, Invoice, OrderNote, **Orders** | 42 |
| `usp_Order_OrderEvent_Save` | živá | – | – | Cart, OrderEvent, **StockLevel** | 26 |
| `usp_Order_OrderEvent_Sync` | živá | – | – | CartItem, **LoyaltyTransaction**, **OrderItem** | 308 |
| `usp_Order_OrderItem_GetByCode` | živá | – | – | – | 146 |
| `usp_Order_OrderItem_Nightly` | živá | – | – | **Customer**, OrderEvent, OrderNote, OrderStatusHistory | 1 008 |
| `usp_Order_OrderNote_Check` | živá | – | – | – | 993 |
| `usp_Order_OrderNote_Insert` | živá | – | – | OrderNote | 1 715 |
| `usp_Order_OrderNote_Nightly` | živá | – | – | Cart, Invoice, **Orders** | 42 |
| `usp_Order_OrderNote_Rebuild` | v klientovi, nepoužitá | – | – | CartItem, **Orders**, StockReservation | 0 |
| `usp_Order_OrderNote_Save` | živá | – | – | OrderNote, OrderStatusHistory, VoucherUse | 4 526 |
| `usp_Order_OrderNote_SetStatus` | živá | – | – | StockReservation | 33 093 |
| `usp_Order_OrderStatusHistory_Archive` | živá | – | – | OrderEvent, OrderNote, **Orders** | 2 |
| `usp_Order_OrderStatusHistory_List` | živá | – | – | – | 1 |
| `usp_Order_OrderStatusHistory_Search` | živá | – | – | – | 324 |
| `usp_Order_Recalc` | živá | – | – | **Orders** | 187 |
| `usp_Order_Sync` | živá | – | – | **OrderItem**, **Orders**, VoucherUse | 143 |
| `usp_Order_Update` | živá | – | – | **Orders** | 205 |
| `usp_Pay_Payment_Delete` | živá | – | – | Invoice, **Payment** | 9 939 |
| `usp_Ship_Shipment_Approve` | živá | – | – | **Shipment** | 730 |

## Slepá místa

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Order_Export` | jina_databaze | **ano** | zápis do Archive.dbo.Orders (katalog nemá ID) |
| `usp_Order_OrderEvent_MonthClose` | jina_databaze | **ano** | zápis do Accounting.dbo.OrderEvent_Archive (katalog nemá ID) |
| `usp_Order_OrderNote_Nightly` | jina_databaze | **ano** | zápis do Accounting.dbo.OrderNote_Archive (katalog nemá ID) |
| `usp_Order_OrderStatusHistory_Archive` | jina_databaze | **ano** | zápis do DWH.dbo.OrderStatusHistory_Archive (katalog nemá ID) |
| `usp_Inv_Invoice_Update` | dynamicke_sql_slepe | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: ExchangeRate (jen v okně měření) |
| `usp_Order_OrderEvent_Cancel` | dynamicke_sql_slepe | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: OrderNote (jen v okně měření) |
| `usp_Order_Cart_Get` | dynamicke_sql_z_literalu | ne | dynamické SQL, cíle jdou vyčíst z literálů |
| `usp_Order_OrderEvent_Find` | dynamicke_sql_z_literalu | ne | dynamické SQL, cíle jdou vyčíst z literálů |
| `usp_Order_OrderNote_Check` | dynamicke_sql_z_literalu | ne | dynamické SQL, cíle jdou vyčíst z literálů |
| `usp_Order_Cancel` | volani_bez_schematu | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Order_CartItem_Cleanup` | volani_bez_schematu | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Order_Create` | volani_bez_schematu | ne | volá spSklad_StockMovement_Update bez schématu (is_caller_dependent) |
| `usp_Order_Create` | volani_bez_schematu | ne | volá usp_Cust_LoyaltyAccount_Merge bez schématu (is_caller_dependent) |
| `usp_Order_Recalc` | volani_bez_schematu | ne | volá usp_Audit_Write bez schématu (is_caller_dependent) |
| `usp_Order_Cancel` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Order_CartItem_Archive` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Order_CartItem_Cleanup` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Order_Create` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Order_Dispatch` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Order_Export` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Order_OrderEvent_Cancel` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Order_OrderEvent_MonthClose` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Order_OrderEvent_Sync` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Order_OrderItem_Nightly` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Order_OrderNote_Check` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Order_OrderNote_Nightly` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Order_OrderStatusHistory_Archive` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Order_Sync` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
