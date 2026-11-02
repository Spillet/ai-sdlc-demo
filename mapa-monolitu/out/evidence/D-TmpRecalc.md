# Evidence pack: D:TmpRecalc

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `fed7344328f4…`). Strojová verze: `D-TmpRecalc.json` (schéma `mapa-monolitu/evidence-pack@2`).

## Core lane: **closed** (autonomy level L0)

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo udělá merge: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Owning team: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má owning team | draft-only | **ne** | owning team není určen |
| R2 doména je mezi domain candidates (ne úklid, ne malý shluk) | draft-only | **ne** | úklid: většina procedur je mrtvá, vypnout místo měnit |
| R3 ověřené pokrytí živých procedur ≥ 80 % | open | **ne** | 0 z 0 (0 %) |
| R4 všechny zapisující procedury mají zelený characterization test | open | ano | ano |
| R5 blokujících blind spots ≤ 0 | open | ano | žádné |

**Co chybí k dalšímu stavu:**

- doména má owning team (owning team není určen)
- doména je mezi domain candidates (ne úklid, ne malý shluk) (úklid: většina procedur je mrtvá, vypnout místo měnit)

## Extraction readiness score

Skóre 100.0, mimo pořadí. Extraction readiness score řadí domény k vyjmutí, stav core lane neurčuje.

## Pokrytí characterization tests

Živých procedur 0: verified 0, draft 0, missing 0. Zapisujících 0, z toho bez ověřeného testu 0.

Draft = test existuje, ale nemá doložený zelený běh (`run.json`). Draft core lane neotevře.

| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |
|---|---|---|---|---|---:|
| `usp_Import_Price` | mrtvá | – | – | TmpRecalc | 0 |
| `usp_Old_OrderExport` | mrtvá | – | – | TmpRecalc | 0 |

## Blind spots

Žádná.

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
