# Balíček důkazů: D:X_Migr_Customer

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `3a31a99461f1…`). Strojová verze: `D-X_Migr_Customer.json` (schéma `mapa-monolitu/dukazy@1`).

## Pruh core: **zavřený**

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo sloučí: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Vlastník: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má vlastnický tým | jen draft PR | **ne** | vlastník není určen |
| R2 doména je kandidát na vyjmutí (ne úklid, ne malý shluk) | jen draft PR | **ne** | úklid: většina procedur je mrtvá, vypnout místo měnit |
| R3 ověřené pokrytí živých procedur ≥ 80 % | otevřený s vlastníkem | **ne** | 0 z 0 (0 %) |
| R4 všechny zapisující procedury mají zelený charakterizační test | otevřený s vlastníkem | ano | ano |
| R5 blokujících slepých míst ≤ 0 | otevřený s vlastníkem | ano | žádné |

**Co chybí k dalšímu stavu:**

- doména má vlastnický tým (vlastník není určen)
- doména je kandidát na vyjmutí (ne úklid, ne malý shluk) (úklid: většina procedur je mrtvá, vypnout místo měnit)

## Připravenost k vyjmutí

Skóre 100.0, mimo pořadí. Skóre řadí domény k vyjmutí, stav pruhu neurčuje.

## Pokrytí charakterizačními testy

Živých procedur 0: ověřeno 0, jen návrh 0, chybí 0. Zapisujících 0, z toho bez ověřeného testu 0.

Návrh = test existuje, ale nemá doložený zelený běh (`beh.json`). Návrh pruh neotevře.

| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |
|---|---|---|---|---|---:|
| `usp_Old_PriceCalc` | mrtvá | – | – | X_Migr_Customer | 0 |

## Slepá místa

Žádná.

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
