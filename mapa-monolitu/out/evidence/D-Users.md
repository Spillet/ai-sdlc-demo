# Evidence pack: D:Users

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `fed7344328f4…`). Strojová verze: `D-Users.json` (schéma `mapa-monolitu/evidence-pack@2`).

## Core lane: **closed** (autonomy level L0)

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo udělá merge: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Owning team: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má owning team | draft-only | **ne** | owning team není určen |
| R2 doména je mezi domain candidates (ne úklid, ne malý shluk) | draft-only | **ne** | malý shluk: posoudit jako součást sousední domény |
| R3 ověřené pokrytí živých procedur ≥ 80 % | open | **ne** | 0 z 2 (0 %) |
| R4 všechny zapisující procedury mají zelený characterization test | open | **ne** | chybí 1: usp_User_Save |
| R5 blokujících blind spots ≤ 0 | open | ano | žádné |

**Co chybí k dalšímu stavu:**

- doména má owning team (owning team není určen)
- doména je mezi domain candidates (ne úklid, ne malý shluk) (malý shluk: posoudit jako součást sousední domény)

## Extraction readiness score

Skóre 87.6, mimo pořadí. Extraction readiness score řadí domény k vyjmutí, stav core lane neurčuje.

## Pokrytí characterization tests

Živých procedur 2: verified 0, draft 0, missing 2. Zapisujících 1, z toho bez ověřeného testu 1.

Draft = test existuje, ale nemá doložený zelený běh (`run.json`). Draft core lane neotevře.

| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |
|---|---|---|---|---|---:|
| `usp_User_Get` | živá | – | – | – | 45 |
| `usp_User_Save` | živá | – | – | UserPermission, Users | 9 290 |

## Blind spots

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_User_Get` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |
| `usp_User_Save` | entry_outside_catalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
