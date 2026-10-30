# Balíček důkazů: D:Product_bak2019

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `3a31a99461f1…`). Strojová verze: `D-Product_bak2019.json` (schéma `mapa-monolitu/dukazy@1`).

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
| `sp_Test_Order` | mrtvá | – | – | **Customer**, Product_bak2019 | 0 |
| `usp_Migr2019_Customer` | mrtvá | – | – | Product_bak2019, **StockLevel** | 0 |
| `usp_Old_InvoicePrint` | mrtvá | – | – | Product_bak2019 | 0 |
| `usp_Product_Bak_Restore` | mrtvá | – | – | Product_bak2019 | 0 |
| `usp_Tmp_Recalc` | mrtvá | – | – | **Orders**, Product_bak2019 | 0 |

## Slepá místa

Žádná.

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
