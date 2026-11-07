# Mapa monolitu (Monolith Map)

Prototyp k case study „AI SDLC a dekompozice monolitu“, část B (snímek 17 prezentace). Část A, cesta změny od požadavku k PR s risk gate, je popsaná v [README v kořeni repa](../README.md). Ukazuje první krok dekompozice databázového monolitu: **pozorovanou mapu závislostí**, ze které jde rozhodnout, co vytáhnout první, a nad kterou může AI pracovat po kouscích.

Běží na **syntetické databázi** fiktivního e-shopu „Kompas“ (MS SQL, 277 uložených procedur, 24 funkcí, 6 triggerů, 92 tabulek, 33 pohledů, fiktivních 27 TB). Žádná reálná data ani schéma skutečné firmy. Dotazy pro sběr stejných vstupů ze skutečné DB jsou v [`sql/collect/`](sql/collect).

## Proč

U monolitu, kde logika žije v uložených procedurách, jsou švy ve dvou rozhraních databáze: v **procedurách, které někdo volá zvenku** (Delphi klient, plánovač, web), a v **tabulkách**. Katalog SQL Serveru (`sys.sql_expression_dependencies`) z toho vidí jen část: nevidí dynamické SQL, volání z klienta a z jobů ani odkazy do jiných databází. Agent nebo člověk, který se spolehne jen na katalog, přehlédne právě ty hrany, na kterých migrace padá.

Mapa proto skládá čtyři vrstvy a u každé hrany si pamatuje, kdo ji viděl. Rozdíl mezi vrstvami je sám o sobě metrika.

## Jak to běží

```
T-SQL skripty ─┐
               ├─ parser ──────── statická vrstva (obdoba sys.sql_expression_dependencies + triggery)
               └─ literály ────── dynamické SQL: co jde vyčíst z řetězců, co je blind spot
grep Delphi ────────────────────── klient: vstupní body, přímé SQL na tabulky
SQL Agent joby ─────────────────── plánovač: vstupní body a rozvrh
XE + Query Store (CSV) ─────────── běh: kdo volá, jak často, cíle dynamického SQL, CPU
                    │
                    ▼
     graf procedury ↔ tabulky (1 997 hran)
                    │
     ├─ živé / mrtvé / mimo okno měření / v klientovi nepoužité
     ├─ sdílené („božské“) tabulky a procedury → mimo shlukování
     ├─ label propagation + slučování podle modularity → domain candidates
     ├─ extraction readiness score + doporučené pořadí + citlivost na váhy
     ├─ evidence pack a stav core lane ke každé doméně (+ owning teams a prahy z policy/core-lane.json)
     └─ context packs pro AI (jen první doména)
                    │
     out/map.json · out/report.md · out/evidence/ · out/context/*.md · site/index.html
```

| Krok | Kde | Poznámka |
|---|---|---|
| Syntetická DB | [`generator/generate_synthetic_db.py`](generator/generate_synthetic_db.py) | deterministický, pevné semínko; zapisuje i `_ground_truth.json`, který analyzátor nečte |
| Parser T-SQL | [`mapa/tsql.py`](mapa/tsql.py) | regex + ruční odstranění komentářů a řetězců |
| Vrstvy a graf | [`mapa/model.py`](mapa/model.py) | |
| Domain candidates | [`mapa/cluster.py`](mapa/cluster.py) | |
| Skóre a pořadí | [`mapa/score.py`](mapa/score.py) | váhy v kódu i v HTML posuvnících |
| Citlivost vah | [`mapa/sensitivity.py`](mapa/sensitivity.py) | ±20 % po jedné váze, náhodné kombinace, bod zvratu |
| Evidence pack a core lane | [`mapa/evidence.py`](mapa/evidence.py), [`policy/core-lane.json`](policy/core-lane.json) | kontrakt pro risk gate z části A, viz „Vazba na risk gate“ |
| Výstupy | [`mapa/render.py`](mapa/render.py), [`mapa/template.html`](mapa/template.html) | HTML bez knihoven, data vložená do stránky |
| AI vrstva | [`ai-vrstva/`](ai-vrstva) | dokumentace, testy a kontrakt pro 3 procedury první domény |
| Sběr ze skutečné DB | [`sql/collect/`](sql/collect) | 9 dotazů + grep Delphi; nic nespuštěno proti reálné DB |

## Jak spustit

Python 3.9+, jen standardní knihovna, nic se neinstaluje.

```bash
python3 analyze.py                 # analýza data/synthetic, ~0,2 s
python3 analyze.py --regenerate    # nejdřív znovu vygenerovat syntetickou DB
python3 analyze.py --data cesta    # vlastní vstupy ve stejném formátu (viz sql/collect/)
python3 -m unittest discover -s tests # testy parseru, pravidel core lane, risk gate a citlivosti (40 testů)
open site/index.html               # mapa funguje otevřením z disku
```

Stránka má pět pohledů: **Domény a pořadí** (skóre, složky, posuvníky vah), **Core lane** (stav lane, autonomy level, pokrytí testy, co chybí, citlivost pořadí), **Graf** (procedury a tabulky obarvené podle domény, hrany podle vrstvy; klik = detail), **Blind spots** a **Objekty** (kód každé procedury, závislosti podle vrstev, provoz).

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
| 3 | Fakturace (D:CreditNote) | 73,0 | 18 / 4 | 0,9 TB | 3 procedury s dynamickým SQL jako blind spot |
| 4 | Platby (D:GatewayLog) | 72,9 | 19 / 0 | 1,3 TB | velká data, hodně vstupů zvenku |
| 5 | Reporting (D:RptDailySales) | 72,3 | 21 / 2 | 0,6 TB | dynamické SQL jako blind spot (`Sales_` + rok) |
| … | Objednávky (D:OrderNote) | 57,3 | 43 / 0 | 4,7 TB | zapisuje do cizích tabulek, hlavní zapisovatel 3 sdílených tabulek: poslední |

**Je Reklamace před Katalogem jen náhodou vah?** Rozdíl je 1,6 bodu. Analýza citlivosti (`out/report.md`, sekce „Citlivost“) říká: při změně kterékoli jedné váhy o ±20 % zůstává pořadí 1. a 2. místa stejné a ve 2 000 náhodných kombinacích všech vah v pásmu ±20 % je Reklamace první ve 100 %. Prohodit by je musela změna jedné váhy o víc než polovinu: bonus za čtecí cesty +66 % nebo penalizace za volání zvenku −78 %. Poctivý závěr má ale tři části:

1. **Na vahách pořadí 1–2 nevisí, na definici složek ano.** Citlivost zkouší jen váhy. Jak se měří „volání zvenku“ nebo kde je práh sdílené tabulky, netestuje. A data jsou syntetická. Rozdíl 1,6 bodu proto neberu jako důkaz, že Reklamace je lepší, jen že žádná rozumná změna vah to neotočí.
2. **Místa 3–7 jsou fakticky remíza.** Fakturace, Platby, Reporting, Adresy a Ceníky mají skóre 71,9–73,0 a při ±20 % se mezi sebou přeskupují v rozsahu 3.–7. (Reporting až 8.). Pořadí v tomhle pásmu nic neříká, rozhodnou jiná kritéria.
3. **Mezi Reklamací a Katalogem nerozhodlo skóre.** Rozhodla věc, kterou skóre nevidí: jádro katalogu `Product` je sdílená tabulka a nejvíc do ní zapisuje sklad, takže Katalog nejde vytáhnout bez rozhodnutí o vlastnictví `Product`. Reklamace takovou překážku nemají a jde o stejnou doménu jako ukázková služba reklamací v části A. Skóre slouží jako filtr („tyhle dvě jsou nejlepší kandidáti“), ne jako rozhodčí.

Pět shluků je „úklid“ (většina procedur mrtvá: vypnout a smazat) a tři jsou příliš malé na doménu (infrastruktura). Názvy shluků jsou automatické podle nejcentrálnější tabulky, lidský název doplňuju v závorce.

**Jak se analyzátor trefil.** Generátor si pamatuje, kam co zamýšlel. Proti tomu: čistota shluků 88 %, 18 shluků proti 13 zamýšleným doménám (legacy a infrastruktura se rozpadly na malé kousky, nákup se spojil se skladem). Mrtvé procedury 26 z 26, dynamické SQL 30 z 30. **Tahle čísla nic nedokazují o reálné DB**: data i analyzátor psal stejný autor, takže analyzátor zná pasti, které generátor klade. Ukazují jen, že logika vrstev funguje tak, jak je popsaná.

**AI vrstva** na reklamacích: [`ai-vrstva/README.md`](ai-vrstva/README.md). Model z context packu našel souběh při kontrole množství, lhůtu počítanou od objednávky místo od převzetí a přímý odpis skladu s natvrdo daným skladem. Všechno označené k ověření člověkem.

## Vazba na risk gate: lane core otevírá důkaz

Ukázka AI SDLC ([README v kořeni repa](../README.md)) dnes v lane core vytvoří od někoho mimo owning team jen draft PR a merge smí jen owning team. Zadání ale chce vývoj „demokratizovaný napříč firmou, zejména v core systémech“. Mapa dává cestu dál: **v lane core může záměr zadat kdokoli, agent založí PR, ale o tom, jestli PR jde do merge, rozhoduje důkaz z mapy, ne model ani skóre.** Risk gate má číst z evidence packu stav core lane domény a podle něj určit autonomy level L0–L3 (úrovně ze snímku 6 prezentace; napojení zatím chybí, viz níže). Core lane se otevírá doménu po doméně, jak přibývají ověřené characterization tests.

| Stav core lane | Autonomy level | Kdy | Kdo spustí agenta | PR | Kdo udělá merge |
|---|---|---|---|---|---|
| **closed** | L0 (čtení) | doména nemá owning team (R1), nebo shluk není mezi domain candidates, protože je úklidový nebo malý (R2) | nikdo; intake odpoví, co chybí | nevzniká | jen vlastník ručně mimo AI pipeline |
| **draft-only** | L1 | R1 a R2 platí, ale chybí ověření | kdokoli | vždy draft; risk gate jen okomentuje dopad a chybějící důkazy | vlastník po převzetí; první úkol agenta je dopsat characterization tests |
| **open** | L2 (merge s důkazem) | navíc ověřené pokrytí živých procedur ≥ 80 % (R3), všechny zapisující procedury mají zelený test (R4), žádný blokující blind spot (R5) | kdokoli | jde do review | vlastník, a jen se zelenými characterization tests dotčených procedur |

L3 (úzký auto-merge) z mapy nevzniká. Potřebuje historii change failure rate AI změn v doméně, kterou má pipeline z části A, ne mapa.

„Ověřený“ test znamená doložený zelený běh: soubor `ai-vrstva/<procedura>/run.json` s výsledkem `"result": "green"`. Návrh testu od modelu core lane neotevře. Blokující blind spot je dynamické SQL se skládaným jménem, u kterého běh nezachytil žádný cíl, zápis do jiné databáze a procedura, jejíž jméno skládá klient (`'usp_Rpt_' + cbReport.Text` blokuje celý Reporting). Owning teams a prahy určují lidé v [`policy/core-lane.json`](policy/core-lane.json), ne analyzátor.

**Stav na syntetických datech:** Reklamace a Katalog jsou draft-only, tedy L1 (mají owning team, ale 0 ověřených testů: tři testy v `ai-vrstva/` jsou jen draft). Ostatních 16 shluků je closed (L0), protože nemají owning team. Žádná doména není open. To je správně: dokud testy nikdo nespustil, nemá kdo říct, že změna procedury nic nerozbila. Aby se core lane u Reklamací otevřel, potřebuje zelený test aspoň 15 z 18 živých procedur (práh 80 %) a mezi nimi všech 13 zapisujících.

### Kontrakt pro risk gate (`mapa-monolitu/evidence-pack@2`)

Risk gate z části A zatím nic z toho nečte. Napojení přijde později, formát je připravený tak, aby stačilo číst dva soubory:

- `out/evidence/index.json`: `snapshot` (`date`, `valid_until`, `inputs_sha256`, `policy_version`), `domains` (`state`, `autonomy_level`, `file` a `owner` jako GitHub tým pro každou doménu), `objects` (jméno procedury, funkce, triggeru, tabulky nebo pohledu → doména, sdílené objekty → `"shared"`), `default_state: "closed"` a `gate_rules`.
- `out/evidence/<doména>.json`: `core_lane` (`state`, `autonomy_level`, `rules` s `met` a `detail`, `missing_for_next_state`, `gate`), `owner`, `readiness` (extraction readiness score a složky, jen informativně), `coverage`, `blind_spots` (s příznakem `blocking`), `procedures` (pro každou: `coverage` = `verified` / `draft` / `missing`, testy a jejich běh, zápisy do cizích tabulek), `tables`, `objects`.
- Vedle každého `.json` je `.md` pro člověka (stejný obsah, tabulky).

Jak má risk gate rozhodnout (referenční implementace `gate_decision` v [`mapa/evidence.py`](mapa/evidence.py), pokrytá testy):

1. Z diffu PR zjistí změněné objekty (v pipeline z části A by to byla složka `db/` s jedním souborem na objekt).
2. Objekt, který v indexu není, sdílený objekt, nebo index po `valid_until` → **closed** (fail-closed).
3. Jinak stav domény z indexu. PR přes víc domén dostane nejpřísnější stav.
4. Procedura bez zeleného testu sníží výsledek na **draft-only** i v open doméně.
5. Výsledek se mapuje na pipeline z části A takto: closed = preflight zastaví běh s vysvětlením (L0), draft-only = `gh pr create --draft` a risk gate nepustí merge (L1), open = běžná risk gate pro risk tier high (code owners review a povinné testy, L2).

Výstupy nemají časové razítko běhu, takže stejné vstupy dají bajtově stejné soubory a risk gate může ověřit `inputs_sha256`. Snímek má platnost 30 dní: mapa nad starými daty z Query Store nesmí otevírat core lane.

## Extraction readiness score

Skóre = 100 − penalizace + bonusy. Každá složka je podíl 0–1 krát váha, takže jde zpětně vysvětlit, odkud číslo je.

| Složka | Váha | Měří |
|---|---:|---|
| zápisy do cizích tabulek | −25 | podíl zápisů procedur domény do tabulek jiné domény nebo sdílených |
| cizí zápisy do tabulek domény | −15 | kdo další mění data domény |
| cizí čtení tabulek domény | −10 | kdo bude potřebovat API nebo repliku |
| čtení cizích a sdílených tabulek | −10 | co bude doména potřebovat od ostatních |
| dynamické SQL | −10 | blind spot (skládané jméno objektu) se počítá dvakrát |
| volání zvenku | −10 | klient, web, plánovač, jiné domény |
| velikost dat | −10 | log škála do 10 TB |
| čtecí cesty | +10 | podíl procedur bez zápisu: levný parallel run |
| mrtvý kód | +5 | vypnout je levnější než přepsat |

Váhy jsou můj předpoklad, ne kalibrovaný model. Ve stránce jdou posuvníky změnit a pořadí se přepočítá. Diskuse o vahách s architekty je cennější než číslo samotné. Jak moc na vahách pořadí visí, ukazuje sekce citlivosti v `out/report.md` a v pohledu „Core lane“ (shrnutí výše u výsledků).

## Co nefunguje nebo je zjednodušené

- **Parser je regex, ne T-SQL parser.** Odstraňuje komentáře a řetězce a rozumí aliasům v `UPDATE … FROM`, ale nerozumí CTE, synonymům, `OPENQUERY`, vnořeným dynamickým dotazům ani `EXEC` s proměnnou jako jménem procedury mimo běžné vzory. Pro reálnou DB bych ho nahradil ScriptDom (`Microsoft.SqlServer.TransactSql.ScriptDom`, oficiální parser T-SQL v .NET) a porovnal s katalogem (`sql/collect/03`, `04`).
- **Syntetická data.** Kód procedur je generovaný ze šablon a místy nedává byznysový smysl (parametr se jménem jedné tabulky filtruje jinou). Ručně psaných je jen 8 objektů reklamací. Rozložení potíží (kolik dynamického SQL, kolik mrtvého kódu) jsem zvolil já, ne realita.
- **Runtime vrstva je simulovaná.** CSV mají tvar, jaký by vrátily dotazy v `sql/collect/`, ale čísla vymyslel generátor. Skutečný sběr potřebuje 4–6 týdnů včetně konce měsíce a pozor na objem událostí. Nejméně ověřený je sběr cílů dynamického SQL přes `tsql_stack` (`08_xe_dynamicke_sql.sql`).
- **Shlukování není doménový model.** Label propagation a modularita najdou, co spolu sdílí tabulky. Nevědí nic o byznysových schopnostech, vlastnictví týmů ani o tom, že „reklamace“ a „vratky“ jsou možná dvě domény. Výstup je návrh pro event storming, ne jeho náhrada.
- **Sdílené tabulky se vyřazují prahem** (≥ 8 % živých procedur, fan-in procedury ≥ 8). Práh je ruční; na jiné DB vyjde jinak.
- **Citlivost testuje jen váhy, ne definice složek.** Pásmo ±20 % je moje volba. Jiný práh sdílené tabulky nebo jiná normalizace „volání zvenku“ by mohly pořadí změnit víc než váhy; to analýza nezkouší.
- **Core lane stojí na vstupech, které jsem vymyslel.** Owning teams dvou domén v `policy/core-lane.json` jsou fiktivní a prahy (80 %, všechny zapisující procedury, nula blokujících blind spots) jsou návrh k diskusi s architekty a vlastníky, ne ověřená hodnota.
- **Pokrytí testy se pozná podle souborů, ne podle běhu.** Analyzátor nic nespouští. Věří `run.json`, který by v reálu měla zapsat CI po běhu tSQLt nebo golden masteru proti kopii DB. Ručně zapsaný `run.json` by core lane otevřel; v produkci by ho musela podepsat pipeline, ne člověk ani agent.
- **Pokrytí počítá procedury, ne cesty v nich.** Jeden zelený test na proceduru se počítá jako `verified`, i když procedura má deset větví. Kvalitu testů musí posoudit vlastník.
- **Risk gate z části A kontrakt zatím nečte.** `gate_decision` je referenční implementace v Pythonu s testy, napojení do `risk_gate.py` není hotové.
- **Skóre nezná změnovost ani byznysovou hodnotu.** Chybí historie změn procedur (v syntetické DB žádná není) a plán byznysu. V reálu by vstupovala změnovost z gitu nebo DDL auditu.
- **Mrtvý kód v okně 6 týdnů** je kandidát, ne důkaz. Ruční zásahy a výjimečné procesy okno nezachytí.
- **HTML je ověřené v prohlížeči jen na GitHub Pages** (7. 11. 2026, <https://spillet.github.io/ai-sdlc-demo/mapa/>): všech pět pohledů se vykreslí bez chyb v konzoli, funguje detail uzlu v grafu i v pohledu Objekty. Jiné prohlížeče a velikosti obrazovky ověřené nejsou.
- **AI vrstva**: výstupy modelu nejsou spuštěné; tSQLt testy jsou kostry, kontrakt se nekompiloval. Proto mají v evidence pack stav `draft` a žádnou doménu neotevírají.

## Jak by to škálovalo na 5 000 procedur (back-of-envelope)

| Co | Syntetická DB | Odhad pro 5 000 SP, ~1 000 tabulek a pohledů | Úzké hrdlo |
|---|---|---|---|
| Parsování a graf | 0,2 s, 2 000 hran | reálné procedury jsou 5–20× delší: desítky sekund, 50–100 tis. hran | nic |
| Shlukování | 9 iterací LPA, 15 slučování | O(hrany × iterace), sekundy; slučování O(shluky²) s ~500 výchozími shluky jednotky minut | nic |
| HTML | 0,7 MB, 400 uzlů | 30–60 MB s kódem, 6 000 uzlů je nečitelných | pohled po doménách, kód načítat zvlášť |
| `dm_sql_referenced_entities` | – | 5 000 kompilací, minuty až desítky minut mimo špičku | provoz DB |
| Sběr běhu (XE, Query Store) | simulováno | **4–6 týdnů kalendářně**, včetně uzávěrky měsíce | čas |
| AI dokumentace | 3 procedury | context pack 2–8 tis. tokenů na vstupu, 3–5 tis. na výstupu → ~40 mil. vstupních + 20 mil. výstupních tokenů pro všech 5 000. Při předpokladu 3 USD / 15 USD za milion tokenů zhruba 400–500 USD (ceník ověřit) | nic |
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
| `context_pack(name)` | stejný context pack jako `out/context/*.md` | vstup pro dokumentaci a testy |
| `evidence(domain)` | evidence pack a stav core lane (`out/evidence/*.json`) | než agent založí PR v core |

Pravidla: snímek s datem a verzí vstupů (agent ví, jak stará data čte); žádné spojení do DB a žádná produkční data, jen metadata a kód; kód procedur je interní know-how, server běží jen uvnitř firmy; každé volání se loguje. V pipeline z části A by stejný server dal deterministické risk gate signál: „PR mění proceduru, která zapisuje do tabulky jiné domény“ → vyšší risk tier. Implementace je ~200 řádků nad `map.json`; v prototypu není, protože by potřebovala instalaci MCP SDK.

## Struktura

- `analyze.py` – vstupní bod
- `mapa/` – parser, graf, shlukování, skóre, výstupy, HTML šablona
- `generator/` – generátor syntetické DB
- `data/synthetic/` – vygenerované vstupy (`db/` T-SQL, `catalog/`, `client/`, `scheduler/`, `runtime/`)
- `out/` – `map.json`, `report.md`, `context/` (context packs pro AI), `evidence/` (evidence packs a stav core lane, `index.json` pro risk gate)
- `policy/` – owning teams domén a prahy pro core lane (vstup od lidí)
- `site/index.html` – statická mapa
- `ai-vrstva/` – prompt a výstupy modelu pro 3 procedury reklamací
- `sql/collect/` – sběr vstupů ze skutečné MS SQL (neověřeno na reálné DB)
- `tests/` – testy parseru, pravidel core lane, referenční risk gate a citlivosti
