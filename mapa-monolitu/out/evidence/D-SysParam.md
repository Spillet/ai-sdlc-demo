# Balíček důkazů: D:SysParam

Vygenerováno `analyze.py` ze snímku 2026-10-31 (platí do 2026-11-30, vstupy `3a31a99461f1…`). Strojová verze: `D-SysParam.json` (schéma `mapa-monolitu/dukazy@1`).

## Pruh core: **zavřený**

- Kdo spustí agenta: nikdo; intake odpoví, co chybí
- PR: nevzniká
- Kdo sloučí: jen vlastník ručně mimo AI pipeline (pokud existuje)
- Vlastník: neurčen

| Pravidlo | Pro stav | Splněno | Detail |
|---|---|---|---|
| R1 doména má vlastnický tým | jen draft PR | **ne** | vlastník není určen |
| R2 doména je kandidát na vyjmutí (ne úklid, ne malý shluk) | jen draft PR | **ne** | malý shluk: posoudit jako součást sousední domény |
| R3 ověřené pokrytí živých procedur ≥ 80 % | otevřený s vlastníkem | **ne** | 0 z 2 (0 %) |
| R4 všechny zapisující procedury mají zelený charakterizační test | otevřený s vlastníkem | **ne** | chybí 2: usp_AuditLog_Purge, usp_SysParam_Set |
| R5 blokujících slepých míst ≤ 0 | otevřený s vlastníkem | **ne** | usp_AuditLog_Purge |

**Co chybí k dalšímu stavu:**

- doména má vlastnický tým (vlastník není určen)
- doména je kandidát na vyjmutí (ne úklid, ne malý shluk) (malý shluk: posoudit jako součást sousední domény)

## Připravenost k vyjmutí

Skóre 66.2, mimo pořadí. Skóre řadí domény k vyjmutí, stav pruhu neurčuje.

## Pokrytí charakterizačními testy

Živých procedur 2: ověřeno 0, jen návrh 0, chybí 2. Zapisujících 2, z toho bez ověřeného testu 2.

Návrh = test existuje, ale nemá doložený zelený běh (`beh.json`). Návrh pruh neotevře.

| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |
|---|---|---|---|---|---:|
| `usp_AuditLog_Purge` | živá | – | – | **AuditLog** | 42 |
| `usp_SysParam_Set` | živá | – | – | SysParam | 6 839 |

## Slepá místa

| Objekt | Typ | Blokuje otevření | Popis |
|---|---|---|---|
| `usp_AuditLog_Purge` | jina_databaze | **ano** | zápis do Archive.dbo.AuditLog_Archive (katalog nemá ID) |
| `usp_AuditLog_Purge` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (agent) |
| `usp_SysParam_Set` | vstup_mimo_katalog | ne | vstupní bod mimo katalog (client) |

Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky.
