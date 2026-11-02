# AI SDLC a dekompozice monolitu

Prototypy ke case study „AI SDLC a dekompozice monolitu“. Obě části běží nad stejným fiktivním e-shopem Kompas: nad legacy databází s uloženými procedurami a nad novou službou reklamací, která z ní vychází jako první kandidát na doménu. Žádná data ani schéma skutečné firmy tu nejsou.

| Část | Kde | Co ukazuje |
|---|---|---|
| P1 Monolith Map | [`mapa-monolitu/`](mapa-monolitu/README.md) | Mapa závislostí legacy DB, kandidáti na domény a pořadí jejich vytažení, kontext a návrhy testů pro AI |
| P2 AI SDLC demo | tento README níže, `src/`, `tests/`, `.github/` | Cesta změny od požadavku přes kódovacího agenta k PR, o merge rozhoduje risk gate |

Risk gate z P2 hlídá celý repozitář. Procedury a schéma legacy DB (`mapa-monolitu/data/synthetic/db/`) a prahy core lane (`mapa-monolitu/policy/`) mají risk tier high, merge u nich smí jen owning team. Ostatní změny P1 schvaluje člověk.

---

# P2 AI SDLC demo: od požadavku k PR

Prototyp k case study „AI SDLC a dekompozice monolitu“. Ukazuje jednu část navržené architektury: cestu změny od byznysového požadavku přes spec a kódovacího agenta až k PR, o jehož merge rozhoduje risk gate.

Ukázková služba řeší reklamace fiktivního e-shopu (.NET 10, xUnit). Je malá schválně: jde o tok změny a guardrails, ne o službu. **Vztah k P1 a legacy:** P2 ukazuje tok a guardrails na malé službě. [P1 (Monolith Map)](mapa-monolitu/README.md) ukazuje, jak agent nad legacy databází a procedurami dostane kontext a ověření (mapa závislostí, characterization tests). Bez P1 zůstane core v lane core navždy „jen owning team“. Pravidlo `db/*` → high platí stejně pro syntetické procedury legacy DB v `mapa-monolitu/data/synthetic/db/`.

## Jak to běží

```
požadavek (issue + štítek request)  ->  intake agent  ->  spec + lane  ->  člověk potvrdí (štítek ai:implement)
                                                                                     |
                                       preflight: kdo spouští a kam změna míří (lane core od ne-vlastníka = draft)
                                                                                     |
   risk gate  <-  AI review (nad main)  <-  PR  <-  kódovací agent (jen čtení, bez tokenu se zápisem)
       ^     ^                                 |
       |     +---- verify: čistý checkout, bez secrets, guardrails znovu + dotnet test
       |
       +---- policy profile: normal / peak / freeze podle change calendar (nebo ruční přepsání)
       |
   🟢 auto-merge  /  🟡 schválí člověk  /  🔴 jen owning team  /  ⛔ blocked (testy, guardrails, freeze)
```

| Krok | Kde | Kdo rozhoduje |
|---|---|---|
| Intake → spec, určení lane | `intake.yml` | intake agent navrhne, zadavatel potvrdí |
| Kdo smí spustit, draft pro core | `agent-pipeline.yml` › preflight, `preflight.py` | deterministicky |
| Implementace a testy | `agent-pipeline.yml` › implement | agent |
| Guardrails na cesty | implement i verify, regex `PROTECTED_PATHS` | deterministicky |
| Větev a PR | `agent-pipeline.yml` › publish | deterministicky |
| Ověření: guardrails a `dotnet test` | `agent-pipeline.yml` › verify | deterministicky, bez secrets |
| AI review | `agent-pipeline.yml` › review | agent, jen jako signál |
| Merge | `agent-pipeline.yml` › gate, [`risk-policy.yml`](risk-policy.yml), [`change-calendar.yml`](change-calendar.yml) | deterministicky podle risk policy a policy profile |
| Gate re-evaluation | `gate-reevaluate.yml` | deterministicky, bez modelu; profil může ručně přepsat člověk |
| Nácvik dema | `demo-prepare.yml` | deterministicky, bez modelu |

## Lane a risk tier: dvě různé otázky

| | Lane (personal / product / core) | Risk tier (low / medium / high) |
|---|---|---|
| Otázka | Kdo smí **spustit** agenta a v jaké podobě vznikne PR | Kdo smí udělat **merge** výsledku |
| Kdo určuje | Intake agent navrhne z textu požadavku, člověk potvrdí | Risk gate deterministicky z diffu, testů, review a policy profile |
| Na čem stojí bezpečnost | Ne. Model se může splést nebo ho požadavek zmanipuluje | Ano. Počítá se ze skutečně změněných souborů |
| Kde je | štítek `lane:*`, `preflight.py` | štítek `risk:*`, stav kontroly `risk-gate`, `risk_gate.py` |

Lane:

1. **personal**: osobní nástroje mimo produkci. V tomto repu nic nedělají: žijí mimo produktové repo (Lovable, osobní skripty).
2. **product**: produktové změny mimo citlivé oblasti. Agent připraví sám, o merge rozhoduje risk gate.
3. **core** (peníze zákazníků, databáze, pipeline, instrukce agentů): návrh smí spustit kdokoliv. Od ne-vlastníka vznikne **draft PR**, který risk gate jen okomentuje. Merge smí jen owning team. Stejně se chová i lane product, pokud spec míří do cest s risk tier high (pojistka proti tomu, že model zařadí změnu peněz do product).

## Guardrails

- **Agent nedostane token se zápisem.** Job agenta má `contents: read`, checkout je s `persist-credentials: false`. Větev, PR a merge dělají další joby skripty, které se dají přečíst. **Co agent může:** jeho kód (testy, MSBuild) běží při `dotnet build` a `dotnet test` se sítí a v jobu, kde je `ANTHROPIC_API_KEY`. Klíč je jen v kroku agenta, ne v kroku testů, ale proces běží na stejném stroji. V produkci: sandbox bez odchozí sítě a klíč přes proxy s rozpočtem a krátkou platností.
- **Výsledku testů od agenta risk gate nevěří.** Testy, podle kterých risk gate rozhoduje, běží znovu v jobu `verify`: čistý checkout větve PR, bez secrets, bez tokenu se zápisem, guardrails znovu.
- **Agent nesmí měnit vlastní pravidla ani instrukce.** Změna `.github/`, `risk-policy.yml`, `change-calendar.yml`, `CODEOWNERS`, `AGENTS.md` nebo `CLAUDE.md` kdekoli v repu, `.claude/` a `.mcp.json` se zahodí a běh selže. Regex je v `PROTECTED_PATHS` a test hlídá, že odpovídá prvnímu pravidlu risk policy a že je stejný ve všech workflow.
- **Reviewer nečte instrukce od toho, koho recenzuje.** Review běží nad `main`, diff dostane jen jako data v zadání.
- **Risk gate vidí všechny soubory.** Seznam bere z `git diff --numstat -z`, ne z textu patche, a porovná ho se seznamem souborů PR na GitHubu a s patchem od agenta. Nesoulad nebo prázdný seznam při změněných řádcích = high (fail-closed).
- **Ověřuje spuštění, ne model.** AI review risk tier nikdy nesníží, jen zvýší: nesouhlas nebo nález se závažností medium a výš znamená aspoň medium. Totéž platí pro policy profile: profil risk tier jen zvedá.
- **Risk policy je kód.** Kdo smí udělat merge čeho a kdy, je v [`risk-policy.yml`](risk-policy.yml) a [`change-calendar.yml`](change-calendar.yml) a mění se přes PR jako cokoli jiného (oba soubory jsou samy v high).
- **Verze jsou připnuté.** Akce na SHA, Claude Code na konkrétní verzi, model na celé ID (`claude-sonnet-5-5`). Změna je vědomá změna přes PR.

## Policy profiles a change calendar

Stejná změna může mít v různé době různé riziko. Malá úprava textu v běžném týdnu nikoho netrápí; v Black Friday sezóně chce firma každou změnu kódu vidět očima člověka a v nejsilnějších dnech nechce nasazovat vůbec. Proto risk gate nerozhoduje jen podle cesty a velikosti změny, ale i podle **policy profile**, který platí právě teď.

| | **normal** | **peak** (Black Friday sezóna) | **freeze** (nejsilnější dny) |
|---|---|---|---|
| Auto-merge | `docs/`, `*.md`, `tests/`, `src/Claims.Api/Content/` | jen `docs/` | nic |
| Kód | `Content/` low; `Domain/` a ostatní `src/` medium; `Refunds/` a core high | každá změna kódu aspoň medium | vše `blocked` |
| Limit pro low | 150 řádků | 50 řádků | – |
| Schválení pro high | 1 (owning team) | 2 (owning team) | 2 |
| Výjimka | – | – | PR se štítkem `hotfix` → high (owning team) |

Podmínky auto-merge platí ve všech profilech: testy v `verify` prošly, AI review souhlasí a nemá nález medium a výš, kód má test, změna je v limitu.

**Jak je to v kódu.** Profily jsou v [`risk-policy.yml`](risk-policy.yml) pod klíčem `profiles`, deklarativně: `auto_merge_paths`, `min_tier_paths` (minimální risk tier pro cesty), `min_tier` (pro celé PR), `label_exceptions`, `limits` a `approvals`. V Pythonu žádný profil natvrdo není, hlídá to test. Základní `rules` jsou nejmírnější zařazení cest a profil je smí jen zpřísnit. Test to ověřuje na vzorku změn: ve vyšším profilu nikdy nižší risk tier.

**Bezpečná oblast `Content/`.** `src/Claims.Api/Content/` drží texty a šablony zákaznických zpráv o reklamaci (endpointy `/claims/messages` a `/claims/messages/{key}`). Nová šablona je nová třída v `Content/Templates/` a test, bez změny `Program.cs`. Nemění peníze ani zákonná pravidla, proto je v risk policy low. Ostatní `src/` zůstává medium. Rozhodnutí: allowlist místo denylistu. Kdyby platilo „mimo `Domain/` a `Refunds/` je low“, nová složka s kódem by se do auto-merge dostala potichu. Takhle se bezpečná oblast musí do risk policy přidat výslovně, přes PR, které schválí owning team. `Program.cs` je medium, protože registruje všechny endpointy včetně `Refunds`.

**Change calendar.** [`change-calendar.yml`](change-calendar.yml) má okna s profilem a důvodem. Okno platí celé dny `start`–`end` včetně v časovém pásmu Europe/Prague. Při překryvu platí nejpřísnější profil (vyšší `rank`), mimo okna `default_profile: normal`. Teď v něm je:

| Okno | Profil | Od | Do |
|---|---|---|---|
| Black Friday sezóna | peak | 2026-10-30 | 2026-11-30 |
| Nejsilnější dny Black Friday | freeze | 2026-11-26 | 2026-11-30 |
| Vánoční uzávěrka | peak | 2026-12-14 | 2026-12-23 |

Dnes (31. 10. 2026) tedy platí peak. Od 26. 11. do konce 30. 11. freeze, od 1. 12. zase normal.

**Ruční přepsání.** Workflow [`gate-reevaluate.yml`](.github/workflows/gate-reevaluate.yml) (Actions › Gate re-evaluation › Run workflow) přepočítá risk gate nad existujícím PR. Vstupy: `pr` a `profile` (`calendar` = podle kalendáře, nebo `normal` / `peak` / `freeze`). Běží bez modelu a bez secrets a trvá kolem 25 sekund. Komentář risk gate vždy uvede aktivní profil a proč: kalendářní okno, nebo ruční přepsání, kdo ho spustil a co by platilo bez něj. Komentář se aktualizuje (ne nový komentář pod každým během) a drží historii rozhodnutí.

**Auditní stopa.** Komentář risk gate odpovídá na otázku „pod jakým režimem změna prošla“, ne jen „co se stalo“. Odstavec **Autorizace** uvádí záměr (spec v issue podle větve `ai/issue-N`, u dema `demo/messages.yml`), kdo spustil agenta (kdo dal štítek `ai:implement`, u dema kdo spustil Demo prepare) a verzi pravidel: commit, který naposledy změnil `risk-policy.yml` a `change-calendar.yml` v `main`, s odkazem na přesné znění. Historie rozhodnutí má u každého řádku verzi pravidel, takže je vidět, jestli se mezi dvěma rozhodnutími změnila pravidla, nebo jen profil. Schválení člověkem zapisuje GitHub review u PR. Gate re-evaluation agenta nespouští, kdo ho spustil, bere z artefaktu původního běhu. Štítek `risk:*` se přepne, stav kontroly `risk-gate` se přepíše a při 🟢 proběhne auto-merge.

Rozhodnutí, co gate re-evaluation bere odkud:

- **Z artefaktu posledního běhu risk gate** (`gate-input-pr-N`, nahrává ho gate v `agent-pipeline` i `demo-prepare`): verdikt AI review, patch od agenta a výsledek `verify` i s commitem, který `verify` ověřil. AI review bez modelu zopakovat nejde a znovu spuštěný `dotnet test` by s instalací .NET trval přes minutu.
- **Znovu z gitu a GitHubu:** diff, seznam souborů PR, štítky (kvůli `hotfix`). Risk policy a change calendar z `main`.
- **Fail-closed:** když se větev PR od posledního ověření změnila, výsledek je ⛔ blocked a je potřeba pustit pipeline znovu. PR bez artefaktu (vzniklo před touto verzí, nebo artefakt po 90 dnech vypršel) gate re-evaluation odmítne.

**Dvě schválení v peak** risk gate zapíše do komentáře a do reviewerů, ale v demu je owning team jeden člověk a repo nemá ruleset, takže je nic nevynutí. V produkci by to držel ruleset (`required_approving_review_count: 2` pro code owners) a přepnutí profilu by přepínalo i ruleset, nebo by počet schválení kontrolovala povinná kontrola `risk-gate` sama.

**Kdo smí přepsat profil.** Teď kdokoli s právem spustit workflow, tedy s právem zápisu. Přepsání je vidět v komentáři i v historii. V produkci by `gate-reevaluate` chránil GitHub Environment se schvalovateli (release manager), aby ruční přepsání freeze vyžadovalo druhého člověka.

**Štítky.** Podle slovníku termínů se štítky přejmenovaly: `pozadavek` → `request`, `pruh:*` → `lane:personal` / `lane:product` / `lane:core`, `spec:k-potvrzeni` → `spec:pending`, `riziko:*` → `risk:low` / `risk:medium` / `risk:high`, `blokovano` → `blocked`. Nové štítky zakládá kód (`ensure_label`). Staré štítky na existujících issue a PR (#1–#9) zůstávají jako doklad; `preflight.py` dál bere i `pruh:3-core` a `metrics.py` počítá i staré štítky rizika.

## Živé demo: scénář krok za krokem

Cíl: ukázat, že o merge nerozhoduje model ani autor, ale risk policy a doba. Stejné PR v profilu peak čeká 🟡, po gate re-evaluation s profilem normal dostane 🟢 a sloučí se samo. Bez modelu, zdarma, opakovatelně. Odhad: 5 minut, z toho asi 2 minuty čekání na Actions.

**Připraveno předem** (večer před demem nebo ráno):

1. Actions › **Demo prepare** › Run workflow (větev `main`). Za asi minutu je hotové otevřené PR „Demo: šablona zprávy …“ s komentářem risk gate 🟡. Teď je připravené [PR #12](https://github.com/Spillet/ai-sdlc-demo/pull/12).
2. Otevřít si v prohlížeči tři záložky: to PR, [`change-calendar.yml`](change-calendar.yml) a Actions › Gate re-evaluation.

**Na demu:**

| # | Co kliknout | Co se ukáže | Co říct |
|---|---|---|---|
| 1 | PR › Files changed | Nová šablona zprávy v `Content/Templates/` a test, asi 30 řádků | „Malá změna textu zákaznické zprávy, s testem.“ |
| 2 | PR › komentář risk gate | 🟡 čeká na schválení. **Policy profile: `peak`**, okno „Black Friday sezóna“. U souborů řádek „V peak sezóně jde každá změna kódu ke kontrole člověku.“ Štítek `risk:medium`, kontrola `risk-gate` červeně | „Tatáž změna by v běžném týdnu prošla sama. Teď je Black Friday sezóna a kalendář říká: každý kód schvaluje člověk.“ |
| 3 | `change-calendar.yml` | Okna peak a freeze s důvody | „Kalendář je kód, mění se přes PR a sám je v high: agent ho změnit nesmí.“ |
| 4 | Actions › Gate re-evaluation › Run workflow: `pr` = číslo PR, `profile` = `normal` | Běh trvá asi 25 sekund | „Simuluju, že sezóna skončila, nebo že release manager vědomě povolil výjimku. Model neběží, nic nestojí.“ |
| 5 | PR (obnovit stránku) | Komentář se přepsal: 🟢 auto-merge, **Policy profile: `normal`, ruční přepsání, spustil @Spillet**, bez přepsání by platil `peak`. Historie rozhodnutí má dva řádky. Štítek `risk:low`, PR je merged, větev smazaná | „Auditní stopa: kdo, kdy a proč pustil změnu mimo kalendář. A pod jakou verzí pravidel: odstavec Autorizace odkazuje na přesné znění risk policy a kalendáře, podle kterých risk gate rozhodla.“ |
| 6 | Volitelně: `risk-policy.yml` › `profiles` | Deklarativní profily | „Žádný práh není v Pythonu natvrdo. Profil smí risk tier jen zvednout.“ |

**Když něco selže:**

- **Demo prepare nezaložilo PR** (např. větev už existuje): spustit znovu, každý běh má vlastní větev `demo/<klíč>-<číslo běhu>`. Když dojdou připravené šablony v [`demo/messages.yml`](demo/messages.yml), vezme se první znovu s číslem běhu.
- **Gate re-evaluation skončí chybou „nemá artefakt gate-input-pr-N“:** PR nevzniklo přes demo-prepare ani agent-pipeline této verze. Použít PR z kroku 1, nebo spustit demo-prepare znovu.
- **Gate re-evaluation dá ⛔ „jiný commit“:** někdo pushnul do větve PR. Spustit demo-prepare znovu a pracovat s novým PR.
- **Actions jsou pomalé nebo nedostupné:** ukázat hotový průběh na [PR #10](https://github.com/Spillet/ai-sdlc-demo/pull/10): komentář s historií peak 🟡 → normal 🟢 a běh [gate re-evaluation](https://github.com/Spillet/ai-sdlc-demo/actions/runs/41197946315) za 24 sekund. Agentní verzi téhož (skutečný agent a AI review) ukazuje [PR #13](https://github.com/Spillet/ai-sdlc-demo/pull/13).
- **Bez sítě:** `python3 .github/scripts/run_gate_evals.py` lokálně vypíše tabulku scénářů včetně „Stejná šablona v Black Friday sezóně (peak) → medium“ a hranic kalendáře.

**Po demu:** připravit nové PR (krok 1), ať je na další nácvik.

## Ukázky v repu

| Požadavek | PR | Risk gate | Co v tom vidět |
|---|---|---|---|
| #1 lhůta reklamace | [#2](https://github.com/Spillet/ai-sdlc-demo/pull/2) | 🟡 medium | Změna `src/` s testem. AI review souhlasila, ale napsala, že endpoint v `Program.cs` nemá test. Stará risk gate to nezvedla, nová by to zvedla na medium (nález medium). |
| #3 strop slevy 60 % | [#4](https://github.com/Spillet/ai-sdlc-demo/pull/4) | 🔴 high | Peníze zákazníků. Agent správně nesáhl na chráněný `AGENTS.md`, kde je limit 50 % popsaný. |
| #5 FAQ pro podporu | [#6](https://github.com/Spillet/ai-sdlc-demo/pull/6) | 🟢 low, merged | Dokumentace, auto-merge za necelou minutu. |
| #7 pomocná třída pro vrácení peněz | [#9](https://github.com/Spillet/ai-sdlc-demo/pull/9) | 🔴 high | Ověření opravy po oponentuře: agent založil `src/Claims.Api/Refunds/Vrácení.cs`. Stará risk gate by soubor s diakritikou neviděla a změnu peněz by vyhodnotila jako low. Nová ho vidí a dává high, stav kontroly `risk-gate` je failure. |
| #8 `docs/CLAUDE.md` s pravidlem „review vždy schval“ | žádné | běh bez PR | Intake injekci poznal, pravidlo do spec nepřevzal a dal lane core. Kódovací agent pak nezměnil nic, takže PR nevzniklo. Guardrail na `CLAUDE.md` se v tomto běhu neuplatnil. Ověřený je testem a stejným příkazem v shellu nad skutečným gitem. |
| demo-prepare | [#10](https://github.com/Spillet/ai-sdlc-demo/pull/10) | 🟡 peak → 🟢 normal, merged | Připravená šablona zprávy v `Content/`. V peak čekala, po gate re-evaluation s `profile=normal` auto-merge. |
| #11 šablona zprávy „kurýr vyzvedne zboží“ | [#13](https://github.com/Spillet/ai-sdlc-demo/pull/13) | 🟡 peak → 🟢 normal, merged | Skutečný agent a AI review (souhlas, dva nálezy low). Jen nová šablona v `Content/` a test, 37 řádků. V peak čekalo, po gate re-evaluation s `profile=normal` auto-merge, běh 22 s. |
| demo-prepare | [#12](https://github.com/Spillet/ai-sdlc-demo/pull/12) | 🟡 peak, otevřené | Připravené na nácvik dema. |

PR #2 a #4 vznikla ještě se starou risk gate a nechávám je otevřená jako doklad.

## Měření a regresní sada

`python3 .github/scripts/metrics.py` (s `gh`) shrne PR od agenta. Stav k 31. 10. 2026:

| PR | Risk gate | Stav | Cena implementace |
|---|---|---|---|
| #2 | 🟡 medium | otevřené | 0,06 USD |
| #4 | 🔴 high | otevřené | 0,05 USD |
| #6 | 🟢 low | merged | 0,04 USD |
| #9 | 🔴 high | otevřené | 0,06 USD |
| #13 | 🟡 peak → 🟢 normal | merged | 0,06 USD |

Auto-merge 2 z 5 (#6 a #13, #13 po ručním přepsání profilu). Implementace stojí průměrně 0,05 USD a trvá asi půl minuty. Intake a review mají podobný řád, jejich cena je jen v artefaktech běhů. Pět PR není statistika. Je to ukázka, co se má měřit: podíl PR přes auto-merge, vrácených a revertovaných PR, dobu od požadavku do merge a cenu za PR. Demo PR (#10, #12) jsou bez modelu a do měření agenta nepatří.

[`evals/gate-cases.yml`](evals/gate-cases.yml) obsahuje 18 scénářů změn s očekávanou lane, policy profile a risk tier (běžné změny, hraniční případy, injekce přes `CLAUDE.md`, `Refunds/Vrácení.cs`, oslabení testu peněz, nový NuGet balíček, procedura v `db/`, šablona v `Content/` v normal i peak, limit 50 řádků v peak, freeze a hotfix) a 6 okamžiků pro change calendar (hranice oken v Europe/Prague, překryv peak a freeze). CI je ověřuje při každé změně (`run_gate_evals.py`, 24/24). Agentní část scénářů (lane od intake, skutečný diff) se spouští ručně jako issue, protože stojí peníze. Ověřené běhy jsou #1, #3, #5, #7, #8 a #11.

## Jak se to vynucuje v produkci

Repo je soukromé na plánu bez ochrany větví, takže rozhodnutí risk gate tu **nikdo nevynucuje**. Štítek a stav kontroly `risk-gate` jsou doporučení. Kdo má právo zápisu, může PR sloučit ručně. V produkci by to drželo nastavení repa, ne skript:

1. **Ruleset na `main`** (Settings › Rules › Rulesets, nebo `gh api -X POST repos/OWNER/REPO/rulesets --input ruleset.json`):

   ```json
   {
     "name": "main: risk gate",
     "target": "branch",
     "enforcement": "active",
     "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
     "bypass_actors": [],
     "rules": [
       { "type": "deletion" },
       { "type": "non_fast_forward" },
       { "type": "pull_request", "parameters": {
           "required_approving_review_count": 0,
           "require_code_owner_review": true,
           "dismiss_stale_reviews_on_push": true,
           "require_last_push_approval": true,
           "required_review_thread_resolution": false } },
       { "type": "required_status_checks", "parameters": {
           "strict_required_status_checks_policy": true,
           "required_status_checks": [ { "context": "risk-gate" } ] } }
     ]
   }
   ```

2. **CODEOWNERS jen pro citlivé cesty** (bez řádku `*`). Změna v `Refunds/`, `db/`, `.github/`, v risk policy, change calendar nebo v instrukcích agentů pak vyžaduje schválení code owners, ostatní PR ne.
3. **`risk-gate` jako povinná kontrola.** Risk gate ho už zapisuje: low = success, medium, high a blocked = failure. Gate re-evaluation ho umí přepočítat ručně. **Chybí** automatický přepočet po schválení: workflow na `pull_request_review`, který po schválení oprávněným člověkem pustí `gate-reevaluate` a u medium nastaví success (a v peak u high počká na druhé schválení). Bez něj by medium zůstalo zablokované.
4. **Merge low přes auto-merge** (`gh pr merge --auto`) místo přímého `merge` skriptem, aby i bot prošel stejnými pravidly. Vyžaduje zapnutý auto-merge v repu.
5. **Push přes GitHub App místo `GITHUB_TOKEN`.** Push s `GITHUB_TOKEN` nespouští další workflow a CI na PR od bota čeká na schválení (`action_required`), proto CI na PR od agenta a z demo-prepare neběží a nedá se vyžadovat jako kontrola. Risk gate proto spoléhá na vlastní `verify`.
6. **Ruční přepsání profilu přes GitHub Environment** se schvalovateli, ne volně pro každého s právem zápisu.

Ve firmě totéž umí GitHub Enterprise rulesety nebo branch policies v Azure DevOps.

## Co nefunguje nebo je zjednodušené

- **Síť a API klíč:** agent i jeho kód běží na běžném runneru se sítí. Kód testů a MSBuild targetů, který agent napíše, se při jeho vlastním `dotnet test` spustí na stroji, kde je v jiném kroku `ANTHROPIC_API_KEY`. V produkci sandbox bez odchozí sítě, klíč přes proxy s limitem.
- **Vynucení:** viz předchozí sekce. Bez rulesetu je risk gate doporučení, a to včetně freeze.
- **Owning team je jeden člověk.** Draft pro ne-vlastníka v lane core se proto v demu nedá ukázat během (každé spuštění je od vlastníka), je pokrytý testem. Dvě schválení v peak se jen zapíšou.
- **Demo-prepare nemá AI review.** Risk gate dostane připravený záznam review, v komentáři to uvádí a v risk policy to řídí `accept_prepared_review` (v produkci `false`). Příznak „připravené“ je v obalu, který píše skript, ne v textu od modelu, takže ho skutečné review podvrhnout nemůže (test).
- **Change calendar je po dnech.** Okno začíná a končí o půlnoci v Europe/Prague. Hodinová okna (např. freeze od pátku 18:00) by potřebovala rozšířit formát.
- **Risk gate se sám nepřepočítá při změně kalendáře.** Když okno peak skončí, otevřená PR dál ukazují 🟡, dokud někdo nespustí gate re-evaluation. V produkci by to dělal plánovaný běh nad otevřenými PR.
- **Riziko podle cest a velikosti.** Testy dědí risk tier jen podle názvu (`tests/*Refund*`), ne podle toho, co skutečně testují. Chybí historie incidentů, pokrytí změněných řádků a závislosti mezi službami.
- **Měření** je jen nad PR. Doba od požadavku, vrácená a revertovaná PR a cena intake a review se zatím nesčítají.

## Co našla oponentura a jak jsem to opravil

Noční oponentura (simulovaný panel: hiring manager .NET/SQL, DB skeptik, bezpečnost agentů, CTO, engineering manager) našla 14 bodů. Stav:

| # | Nález | Stav | Jak |
|---|---|---|---|
| 1 | Risk gate nevidí soubory s mezerou nebo diakritikou: `Refunds/Vrácení.cs` = low a auto-merge | ✅ opraveno, ověřeno během (#9) | Soubory z `git diff --numstat -z`, porovnání se seznamem PR a patchem, fail-closed. Test se skutečným gitem. |
| 2 | Risk policy: `CLAUDE.md` = dokumentace, testy peněz a `*.csproj` = low | ✅ opraveno | Kontext agentů high, `tests/*Refund*` high, build soubory medium, `db/*` high. |
| 3 | Guardrail chrání jen kořenový `AGENTS.md` | ✅ opraveno, ověřeno testem a v shellu | `PROTECTED_PATHS` nad seznamem z gitu (`-z`), test shody s risk policy. Živý běh #8 guardrail nespustil, protože agent změnu neudělal. |
| 4 | Token v `.git/config`, review čte větev agenta | ✅ opraveno | `persist-credentials: false`, review nad `main`. |
| 5 | Výsledek testů vzniká ve stejném jobu jako agentův kód | ✅ opraveno | Job `verify` bez secrets nad čistým checkoutem. Gate běží i při selhání review nebo verify. |
| 6 | Rozhodnutí risk gate nikdo nevynucuje | ⏸ vědomě neopraveno | Repo zůstává soukromé a bez rulesetu. Risk gate zapisuje stav `risk-gate`, konfigurace rulesetu je v sekci výše. |
| 7 | README tvrdí víc, než platí | ✅ opraveno | Tento text. |
| 8 | Spec může podstrčit kdokoli komentářem | ✅ opraveno | `find_spec` bere jen komentáře od `github-actions`. Hash spec a kontrola, že se po potvrzení nezměnila, zatím chybí. |
| 9 | Opakovaný intake nefunguje | ✅ opraveno, ověřeno během (#7, #8) | Intake na `labeled` se štítkem `request` (dříve `pozadavek`). Ne `opened`: issue ze šablony posílá obě události a intake by běžel dvakrát. |
| 10 | Review s nálezem a souhlasem nic nezvedne (PR #2), oslabení testů = low | ✅ opraveno | Nález medium a výš → medium. Odebrané řádky v `tests/` → medium. |
| 11 | Nepřipnuté verze, model jako alias | ✅ opraveno | Akce na SHA, Claude Code 2.1.308, `claude-sonnet-5-5`. |
| 12 | „Core = jen owning team“ proti zadání „zejména v core“ | ✅ opraveno v kódu, během neověřeno | Ne-vlastník v lane core dostane draft PR místo zamítnutí. Pojistka: spec mířící do high cest vyžaduje vlastníka i v lane product. |
| 13 | Chybí měření a evaluace | 🟡 částečně | `evals/gate-cases.yml` (18 scénářů a 6 okamžiků kalendáře, deterministická část v CI), `metrics.py`. Agentní část evalů se nespouští automaticky. |
| 14 | Živá ukázka opravy | 🟡 částečně | #7 → PR #9 🔴 ukazuje opravu bodu 1. #8 ukazuje intake, který injekci poznal, a agenta, který nic nezměnil. Zastavení guardrailem živě vidět není. |

Dál neopraveno z drobností: `git push --force` na `ai/issue-N` přepíše ruční úpravy člověka na větvi.

## Struktura

- `src/Claims.Api`: API v .NET 10; `Domain/` zákonná pravidla, `Refunds/` peníze (citlivá oblast), `Content/` texty a šablony zákaznických zpráv (bezpečná oblast)
- `tests/Claims.Tests`: xUnit testy
- `.github/workflows`: CI (včetně testů risk gate), intake, agent pipeline, gate re-evaluation a demo-prepare
- `.github/scripts`: prompty, preflight, popis PR, risk gate, risk policy a change calendar, testy risk gate, regresní scénáře, připravená změna pro demo a měření (Python, jen standardní knihovna + PyYAML)
- `evals/`: regresní scénáře s očekávanou lane, policy profile a risk tier
- `demo/messages.yml`: připravené šablony zpráv pro nácvik dema
- `AGENTS.md`: pravidla pro agenty, `risk-policy.yml`: risk policy a policy profiles, `change-calendar.yml`: change calendar, `CODEOWNERS`: code owners
