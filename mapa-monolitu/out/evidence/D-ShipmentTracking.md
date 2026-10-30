# Balíček důkazů: D:ShipmentTracking

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `3a31a99461f1…`). Strojová verze: `D-ShipmentTracking.json` (schéma `mapa-monolitu/dukazy@1`).

## Pruh core: **zavřený**

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo sloučí: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Vlastník: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má vlastnický tým | jen draft PR | **ne** | vlastník není určen |
| R2 doména je kandidát na vyjmutí (ne úklid, ne malý shluk) | jen draft PR | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | otevřený s vlastníkem | **ne** | 0 z 23 (0 %) |
| R4 všechny zapisující procedury mají zelený charakterizační test | otevřený s vlastníkem | **ne** | chybí 19: usp_Ship_CarrierService_Cancel, usp_Ship_Carrier_CeskaPosta, usp_Ship_Carrier_DPD, usp_Ship_Carrier_GLS_old, usp_Ship_Carrier_PPL, usp_Ship_Carrier_Zasilkovna … |
| R5 blokujících slepých míst ≤ 0 | otevřený s vlastníkem | ano | žádné |

**Co chybí k dalšímu stavu:**

- doména má vlastnický tým (vlastník není určen)

## Připravenost k vyjmutí

Skóre 64.7, pořadí 9. Skóre řadí domény k vyjmutí, stav pruhu neurčuje.

## Pokrytí charakterizačními testy

Živých procedur 23: ověřeno 0, jen návrh 0, chybí 23. Zapisujících 19, z toho bez ověřeného testu 19.

Návrh = test existuje, ale nemá doložený zelený běh (`beh.json`). Návrh pruh neotevře.

| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |
|---|---|---|---|---|---:|
| `usp_Ship_CarrierService_Cancel` | živá | – | – | CarrierService, ShipmentTracking | 123 |
| `usp_Ship_Carrier_CeskaPosta` | živá | – | – | **Shipment**, ShipmentTracking | 4 928 |
| `usp_Ship_Carrier_DPD` | živá | – | – | **Shipment**, ShipmentTracking | 1 178 |
| `usp_Ship_Carrier_GLS_old` | živá | – | – | **Shipment**, ShipmentTracking | 170 |
| `usp_Ship_Carrier_GetByCode` | mrtvá | – | – | – | 0 |
| `usp_Ship_Carrier_PPL` | živá | – | – | **Shipment**, ShipmentTracking | 539 |
| `usp_Ship_Carrier_Zasilkovna` | živá | – | – | **Shipment**, ShipmentTracking | 180 |
| `usp_Ship_DeliverySlot_Cleanup` | živá | – | – | DeliverySlot, ShipmentItem | 42 |
| `usp_Ship_DeliverySlot_Close` | živá | – | – | DeliverySlot | 9 152 |
| `usp_Ship_DeliverySlot_List` | živá | – | – | – | 22 |
| `usp_Ship_PickupPoint_GetByCode` | živá | – | – | – | 1 558 |
| `usp_Ship_PickupPoint_GetDetail` | živá | – | – | – | 38 373 |
| `usp_Ship_SendToCarrier` | živá | – | – | ShipmentTracking | 447 |
| `usp_Ship_ShipmentItem_Cleanup` | živá | – | – | DeliverySlot, **Shipment**, ShipmentItem | 42 |
| `usp_Ship_ShipmentItem_Dispatch` | živá | – | – | DeliverySlot, PickupPoint | 1 236 |
| `usp_Ship_ShipmentItem_Insert` | živá | – | – | ShipmentItem, ShipmentTracking | 292 |
| `usp_Ship_ShipmentTracking_Delete` | živá | – | – | **Orders**, ShipmentItem, ShipmentTracking | 887 |
| `usp_Ship_ShipmentTracking_List` | živá | – | – | – | 1 067 |
| `usp_Ship_ShipmentTracking_Recalc` | živá | – | – | CarrierService, ShipmentTracking | 1 219 |
| `usp_Ship_Shipment_Insert` | živá | – | – | CarrierService, **Shipment** | 177 |
| `usp_Ship_Shipment_Nightly` | živá | – | – | **Shipment**, ShipmentTracking | 42 |
| `usp_Ship_Shipment_Rebuild` | živá | – | – | PickupPoint, **Shipment** | 1 494 |
| `usp_Ship_Shipment_Save` | živá | – | – | **Shipment** | 1 060 |
| `usp_Ship_Shipment_Update` | živá | – | – | **Orders**, **Shipment** | 48 |

## Slepá místa

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Ship_SendToCarrier` | dynamicke_sql_slepe | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: usp_Ship_Carrier_CeskaPosta, usp_Ship_Carrier_DPD, usp_Ship_Carrier_PPL, usp_Ship_Carrier_Zasilkovna (jen v okně měření) |
| `usp_Ship_ShipmentTracking_Delete` | dynamicke_sql_slepe | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: ShipmentItem (jen v okně měření) |
| `usp_Ship_Shipment_Nightly` | dynamicke_sql_slepe | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: ShipmentTracking (jen v okně měření) |
| `usp_Ship_Shipment_Save` | dynamicke_sql_z_literalu | ne | dynamické SQL, cíle jdou vyčíst z literálů |
| `usp_Ship_CarrierService_Cancel` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_Carrier_CeskaPosta` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_Carrier_GLS_old` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_Carrier_PPL` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_DeliverySlot_Cleanup` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Ship_DeliverySlot_Close` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_DeliverySlot_List` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_SendToCarrier` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_ShipmentItem_Cleanup` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Ship_ShipmentItem_Dispatch` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_Shipment_Nightly` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Ship_Shipment_Rebuild` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
