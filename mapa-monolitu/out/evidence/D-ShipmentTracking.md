# Evidence pack: D:ShipmentTracking

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `fed7344328f4…`). Strojová verze: `D-ShipmentTracking.json` (schéma `mapa-monolitu/evidence-pack@2`).

## Core lane: **closed** (autonomy level L0)

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo udělá merge: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Owning team: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má owning team | draft-only | **ne** | owning team není určen |
| R2 doména je mezi domain candidates (ne úklid, ne malý shluk) | draft-only | ano | ano |
| R3 ověřené pokrytí živých procedur ≥ 80 % | open | **ne** | 0 z 23 (0 %) |
| R4 všechny zapisující procedury mají zelený characterization test | open | **ne** | chybí 19: usp_Ship_CarrierService_Cancel, usp_Ship_Carrier_CeskaPosta, usp_Ship_Carrier_DPD, usp_Ship_Carrier_GLS_old, usp_Ship_Carrier_PPL, usp_Ship_Carrier_Zasilkovna … |
| R5 blokujících blind spots ≤ 0 | open | ano | žádné |

**Co chybí k dalšímu stavu:**

- doména má owning team (owning team není určen)

## Extraction readiness score

Skóre 64.7, pořadí 9. Extraction readiness score řadí domény k vyjmutí, stav core lane neurčuje.

## Pokrytí characterization tests

Živých procedur 23: verified 0, draft 0, missing 23. Zapisujících 19, z toho bez ověřeného testu 19.

Draft = test existuje, ale nemá doložený zelený běh (`run.json`). Draft core lane neotevře.

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

## Blind spots

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_Ship_SendToCarrier` | dynamic_sql_blind | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: usp_Ship_Carrier_CeskaPosta, usp_Ship_Carrier_DPD, usp_Ship_Carrier_PPL, usp_Ship_Carrier_Zasilkovna (jen v okně měření) |
| `usp_Ship_ShipmentTracking_Delete` | dynamic_sql_blind | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: ShipmentItem (jen v okně měření) |
| `usp_Ship_Shipment_Nightly` | dynamic_sql_blind | ne | jméno objektu se skládá za běhu; cíle viděné za běhu: ShipmentTracking (jen v okně měření) |
| `usp_Ship_Shipment_Save` | dynamic_sql_literal | ne | dynamické SQL, cíle jdou vyčíst z literálů |
| `usp_Ship_CarrierService_Cancel` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_Carrier_CeskaPosta` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_Carrier_GLS_old` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_Carrier_PPL` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_DeliverySlot_Cleanup` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Ship_DeliverySlot_Close` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_DeliverySlot_List` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_SendToCarrier` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_ShipmentItem_Cleanup` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Ship_ShipmentItem_Dispatch` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_Ship_Shipment_Nightly` | entry_outside_catalog | ne | vstupní bod mimo katalog (agent) |
| `usp_Ship_Shipment_Rebuild` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
