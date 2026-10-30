# Mapa monolitu

Prototyp k case study „AI SDLC a dekompozice monolitu“, část B. Ukazuje první krok dekompozice databázového monolitu: **pozorovanou mapu závislostí**, ze které jde rozhodnout, co vytáhnout první, a nad kterou může AI pracovat po kouscích.

Běží na **syntetické databázi** fiktivního e-shopu „Kompas“ (MS SQL, 277 uložených procedur, 24 funkcí, 6 triggerů, 92 tabulek, 33 pohledů, fiktivních 27 TB). Žádná reálná data ani schéma skutečné firmy. Dotazy pro sběr stejných vstupů ze skutečné DB jsou v [`sql/collect/`](sql/collect).

## Proč

U monolitu, kde logika žije v uložených procedurách, jsou švy ve dvou rozhraních databáze: v **procedurách, které někdo volá zvenku** (Delphi klient, plánovač, web), a v **tabulkách**. Katalog SQL Serveru (`sys.sql_expression_dependencies`) z toho vidí jen část: nevidí dynamické SQL, volání z klienta a z jobů ani odkazy do jiných databází. Agent nebo člověk, který se spolehne jen na katalog, přehlédne právě ty hrany, na kterých migrace padá.

Mapa proto skládá čtyři vrstvy a u každé hrany si pamatuje, kdo ji viděl. Rozdíl mezi vrstvami je sám o sobě metrika.

## Jak to běží

```
T-SQL skripty ─┐
               ├─ parser ──────── statická vrstva (obdoba sys.sql_expression_dependencies + triggery)
               └─ literály ────── dynamické SQL: co jde vyčíst z řetězců, co je slepé
grep Delphi ────────────────────── klient: vstupní body, přímé SQL na tabulky
SQL Agent joby ─────────────────── plánovač: vstupní body a rozvrh
XE + Query Store (CSV) ─────────── běh: kdo volá, jak často, cíle dynamického SQL, CPU
                    │
                    ▼
     graf procedury ↔ tabulky (1 997 hran)
                    │
     ├─ živé / mrtvé / mimo okno měření / v klientovi nepoužité
     ├─ sdílené („božské“) tabulky a procedury → mimo shlukování
     ├─ label propagation + slučování podle modularity → kandidáti na domény
     ├─ skóre připravenosti k vyjmutí + doporučené pořadí
     └─ kontextové balíčky pro AI (jen první doména)
                    │
     out/map.json · out/report.md · out/context/*.md · site/index.html
```

| Krok | Kde | Poznámka |
|---|---|---|
| Syntetická DB | [`generator/generate_synthetic_db.py`](generator/generate_synthetic_db.py) | deterministický, pevné semínko; zapisuje i `_ground_truth.json`, který analyzátor nečte |
| Parser T-SQL | [`mapa/tsql.py`](mapa/tsql.py) | regex + ruční odstranění komentářů a řetězců |
| Vrstvy a graf | [`mapa/model.py`](mapa/model.py) | |
| Kandidáti na domény | [`mapa/cluster.py`](mapa/cluster.py) | |
| Skóre a pořadí | [`mapa/score.py`](mapa/score.py) | váhy v kódu i v HTML posuvnících |
| Výstupy | [`mapa/render.py`](mapa/render.py), [`mapa/template.html`](mapa/template.html) | HTML bez knihoven, data vložená do stránky |
| AI vrstva | [`ai-vrstva/`](ai-vrstva) | dokumentace, testy a kontrakt pro 3 procedury první domény |
| Sběr ze skutečné DB | [`sql/collect/`](sql/collect) | 9 dotazů + grep Delphi; nic nespuštěno proti reálné DB |

## Jak spustit

Python 3.9+, jen standardní knihovna, nic se neinstaluje.

```bash
python3 analyze.py                 # analýza data/synthetic, ~0,2 s
python3 analyze.py --regenerate    # nejdřív znovu vygenerovat syntetickou DB
python3 analyze.py --data cesta    # vlastní vstupy ve stejném formátu (viz sql/collect/)
python3 -m unittest discover tests # testy parseru na pastech regexu
open site/index.html               # mapa funguje otevřením z disku
```

Stránka má čtyři pohledy: **Domény a pořadí** (skóre, složky, posuvníky vah), **Graf** (procedury a tabulky obarvené podle domény, hrany podle vrstvy; klik = detail), **Slepá místa** a **Objekty** (kód každé procedury, závislosti podle vrstev, provoz).

## Výsledky na syntetických datech

**Katalog nevidí skoro polovinu vstupů.** Z 252 živých procedur nemá **119 (47 %)** žádného volajícího v katalogu. Volá je klient, plánovač, web nebo dynamické SQL. Bez dalších vrstev by vypadaly jako mrtvé. Mezi objekty samotnými je mimo katalog jen 116 z 1 997 hran (5,8 %), ale právě ty jsou nejnebezpečnější: dynamické SQL se skládaným jménem tabulky (21 procedur), dispatch procedur podle hodnoty v tabulce, zápisy triggerem do 8TB tabulky.

**Některé věci ví jen běh.** Čtyři procedury volá jen webová aplikace, o které Delphi zdrojáky ani plánovač nic nevědí. Dvě exportní procedury se volají jen přes `EXEC(@sql)` se jménem z fronty. Jeden job volá proceduru z PowerShell kroku, ne z T-SQL. Klient jedno volání skládá z textu v comboboxu (`'usp_Rpt_' + cbReport.Text`).

**Mrtvý kód.** 25 procedur se za 6 týdnů nezavolalo a nic na ně neodkazuje: kandidáti na vypnutí, ne na přepis. Roční uzávěrka se za 6 týdnů také nezavolala, ale je v plánovači, takže ji mapa označí „mimo okno měření“, ne „mrtvá“. Jednu proceduru volá klient v kódu, ale nikdo na ni neklikl: otázka pro byznys.

**Sdílené tabulky.** 11 tabulek a 15 procedur je vyřazeno ze shlukování, protože by všechno slepily: `AuditLog` (116 procedur), `Orders` (68), `Customer` (62), `OrderItem`, `Product`, `StockLevel`… Mapa u každé ukáže, kdo do ní nejvíc zapisuje. Do `Product` nejvíc zapisuje sklad (cache zásob), ne katalog.

**Doporučené pořadí** (prvních pět z 10 kandidátů; úplná tabulka v `out/report.md`):

| # | Kandidát | Skóre | Živé / mrtvé proc. | Data | Hlavní důvody |
|---:|---|---:|---|---:|---|
| 1 | Reklamace (D:Claim) | 83,2 | 21 / 1 | 0,2 TB | malá data, čte cizí Customer/Orders/OrderItem, jeden cizí zápis do skladu |
| 2 | Katalog (D:Category) | 81,6 | 25 / 0 | 0,1 TB | hodně vstupů zvenku; jádro `Product` je sdílené a zapisuje do něj hlavně sklad |
| 3 | Fakturace (D:CreditNote) | 73,0 | 18 / 4 | 0,9 TB | 3 procedury se slepým dynamickým SQL |
| 4 | Platby (D:GatewayLog) | 72,9 | 19 / 0 | 1,3 TB | velká data, hodně vstupů zvenku |
| 5 | Reporting (D:RptDailySales) | 72,3 | 21 / 2 | 0,6 TB | slepé dynamické SQL (`Sales_` + rok) |
| … | Objednávky (D:OrderNote) | 57,3 | 43 / 0 | 4,7 TB | zapisuje do cizích tabulek, hlavní zapisovatel 3 sdílených tabulek: poslední |

Pět shluků je „úklid“ (většina procedur mrtvá: vypnout a smazat) a tři jsou příliš malé na doménu (infrastruktura). Názvy shluků jsou automatické podle nejcentrálnější tabulky, lidský název doplňuju v závorce.

**Jak se analyzátor trefil.** Generátor si pamatuje, kam co zamýšlel. Proti tomu: čistota shluků 88 %, 18 shluků proti 13 zamýšleným doménám (legacy a infrastruktura se rozpadly na malé kousky, nákup se spojil se skladem). Mrtvé procedury 26 z 26, dynamické SQL 30 z 30. **Tahle čísla nic nedokazují o reálné DB**: data i analyzátor psal stejný autor, takže analyzátor zná pasti, které generátor klade. Ukazují jen, že logika vrstev funguje tak, jak je popsaná.

**AI vrstva** na reklamacích: [`ai-vrstva/README.md`](ai-vrstva/README.md). Model z kontextového balíčku našel souběh při kontrole množství, lhůtu počítanou od objednávky místo od převzetí a přímý odpis skladu s natvrdo daným skladem. Všechno označené k ověření člověkem.

## Skóre připravenosti

Skóre = 100 − penalizace + bonusy. Každá složka je podíl 0–1 krát váha, takže jde zpětně vysvětlit, odkud číslo je.

| Složka | Váha | Měří |
|---|---:|---|
| zápisy do cizích tabulek | −25 | podíl zápisů procedur domény do tabulek jiné domény nebo sdílených |
| cizí zápisy do tabulek domény | −15 | kdo další mění data domény |
| cizí čtení tabulek domény | −10 | kdo bude potřebovat API nebo repliku |
| čtení cizích a sdílených tabulek | −10 | co bude doména potřebovat od ostatních |
| dynamické SQL | −10 | slepé (skládané jméno objektu) se počítá dvakrát |
| volání zvenku | −10 | klient, web, plánovač, jiné domény |
| velikost dat | −10 | log škála do 10 TB |
| čtecí cesty | +10 | podíl procedur bez zápisu: levný parallel run |
| mrtvý kód | +5 | vypnout je levnější než přepsat |

Váhy jsou můj předpoklad, ne kalibrovaný model. Ve stránce jdou posuvníky změnit a pořadí se přepočítá. Diskuse o vahách s architekty je cennější než číslo samotné.

## Co nefunguje nebo je zjednodušené

- **Parser je regex, ne T-SQL parser.** Odstraňuje komentáře a řetězce a rozumí aliasům v `UPDATE … FROM`, ale nerozumí CTE, synonymům, `OPENQUERY`, vnořeným dynamickým dotazům ani `EXEC` s proměnnou jako jménem procedury mimo běžné vzory. Pro reálnou DB bych ho nahradil ScriptDom (`Microsoft.SqlServer.TransactSql.ScriptDom`, oficiální parser T-SQL v .NET) a porovnal s katalogem (`sql/collect/03`, `04`).
- **Syntetická data.** Kód procedur je generovaný ze šablon a místy nedává byznysový smysl (parametr se jménem jedné tabulky filtruje jinou). Ručně psaných je jen 8 objektů reklamací. Rozložení potíží (kolik dynamického SQL, kolik mrtvého kódu) jsem zvolil já, ne realita.
- **Runtime vrstva je simulovaná.** CSV mají tvar, jaký by vrátily dotazy v `sql/collect/`, ale čísla vymyslel generátor. Skutečný sběr potřebuje 4–6 týdnů včetně konce měsíce a pozor na objem událostí. Nejméně ověřený je sběr cílů dynamického SQL přes `tsql_stack` (`08_xe_dynamicke_sql.sql`).
- **Shlukování není doménový model.** Label propagation a modularita najdou, co spolu sdílí tabulky. Nevědí nic o byznysových schopnostech, vlastnictví týmů ani o tom, že „reklamace“ a „vratky“ jsou možná dvě domény. Výstup je návrh pro event storming, ne jeho náhrada.
- **Sdílené tabulky se vyřazují prahem** (≥ 8 % živých procedur, fan-in procedury ≥ 8). Práh je ruční; na jiné DB vyjde jinak.
- **Skóre nezná změnovost ani byznysovou hodnotu.** Chybí historie změn procedur (v syntetické DB žádná není) a plán byznysu. V reálu by vstupovala změnovost z gitu nebo DDL auditu.
- **Mrtvý kód v okně 6 týdnů** je kandidát, ne důkaz. Ruční zásahy a výjimečné procesy okno nezachytí.
- **HTML jsem neověřil v prohlížeči.** JavaScript prošel kontrolou syntaxe a během nad stubem DOM (všechny pohledy se vykreslí bez chyby), vizuální podoba grafu je neověřená.
- **AI vrstva**: výstupy modelu nejsou spuštěné; tSQLt testy jsou kostry, kontrakt se nekompiloval.

## Jak by to škálovalo na 5 000 procedur (výpočet od boku)

| Co | Syntetická DB | Odhad pro 5 000 SP, ~1 000 tabulek a pohledů | Úzké hrdlo |
|---|---|---|---|
| Parsování a graf | 0,2 s, 2 000 hran | reálné procedury jsou 5–20× delší: desítky sekund, 50–100 tis. hran | nic |
| Shlukování | 9 iterací LPA, 15 slučování | O(hrany × iterace), sekundy; slučování O(shluky²) s ~500 výchozími shluky jednotky minut | nic |
| HTML | 0,7 MB, 400 uzlů | 30–60 MB s kódem, 6 000 uzlů je nečitelných | pohled po doménách, kód načítat zvlášť |
| `dm_sql_referenced_entities` | – | 5 000 kompilací, minuty až desítky minut mimo špičku | provoz DB |
| Sběr běhu (XE, Query Store) | simulováno | **4–6 týdnů kalendářně**, včetně uzávěrky měsíce | čas |
| AI dokumentace | 3 procedury | balíček 2–8 tis. tokenů na vstupu, 3–5 tis. na výstupu → ~40 mil. vstupních + 20 mil. výstupních tokenů pro všech 5 000. Při předpokladu 3 USD / 15 USD za milion tokenů zhruba 400–500 USD (ceník ověřit) | nic |
| Kontrola člověkem | – | 30 min dokumentace + 1 h test na proceduru → pro pilotní doménu (~150 SP) ~30 člověkodní seniora; pro všech 5 000 ~900 člověkodní | **lidé** |

Závěr: výpočet ani model nejsou drahé. Drahý je kalendář sběru za běhu a čas lidí, kteří výstup ověří. Proto mapa nejdřív škrtá (mrtvý kód, úklidové shluky) a řadí, aby se kontrola soustředila na jednu doménu po druhé.

## Návrh: read-only MCP server nad mapou

MCP server (Model Context Protocol, standardní rozhraní, přes které agent volá nástroje) by agentům v IDE i v pipeline zpřístupnil `out/map.json`. Jen čtení, žádné spojení do databáze.

| Nástroj | Vrací | Kdy ho agent volá |
|---|---|---|
| `find_object(query)` | objekty podle jména nebo domény | orientace |
| `get_object(name)` | kód, stav, doména, provoz, deklarované vstupy | než začne procedurou měnit |
| `dependencies(name, direction, layers, depth)` | volající a volané po vrstvách, tranzitivně | dopad změny |
| `table_writers(table)` | kdo do tabulky zapisuje, z jaké domény, jakou vrstvou | vlastnictví dat |
| `domain(name)` | hranice, skóre, složky, cizí hrany | plánování vlny |
| `blind_spots(name)` | dynamické SQL, cross-DB, volání jen za běhu | upozornění „tohle katalog nevidí“ |
| `context_pack(name)` | stejný balíček jako `out/context/*.md` | vstup pro dokumentaci a testy |

Pravidla: snímek s datem a verzí vstupů (agent ví, jak stará data čte); žádné spojení do DB a žádná produkční data, jen metadata a kód; kód procedur je interní know-how, server běží jen uvnitř firmy; každé volání se loguje. V pipeline z části A by stejný server dal deterministické bráně signál: „PR mění proceduru, která zapisuje do tabulky jiné domény“ → vyšší rizikový pruh. Implementace je ~200 řádků nad `map.json`; v prototypu není, protože by potřebovala instalaci MCP SDK.

## Struktura

- `analyze.py` – vstupní bod
- `mapa/` – parser, graf, shlukování, skóre, výstupy, HTML šablona
- `generator/` – generátor syntetické DB
- `data/synthetic/` – vygenerované vstupy (`db/` T-SQL, `catalog/`, `client/`, `scheduler/`, `runtime/`)
- `out/` – `map.json`, `report.md`, `context/` (kontextové balíčky pro AI)
- `site/index.html` – statická mapa
- `ai-vrstva/` – prompt a výstupy modelu pro 3 procedury reklamací
- `sql/collect/` – sběr vstupů ze skutečné MS SQL (neověřeno na reálné DB)
- `tests/` – testy parseru
