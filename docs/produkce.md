# Návrh nastavení pro produkci

Ukázka běží v soukromém repu na plánu bez ochrany větví, takže rozhodnutí risk gate tu nikdo nevynucuje. Štítek `risk:*` a stav kontroly `risk-gate` jsou doporučení a kdo má právo zápisu, může PR sloučit ručně, i ve freeze. V produkci by rozhodnutí brány drželo nastavení repozitáře, ne skript. Tento dokument popisuje, co by se nastavilo a co v ukázce chybí.

## Vynucení rozhodnutí brány

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

## Počet schválení podle profilu

V profilu `peak` a `freeze` brána pro high požaduje dvě schválení. Zapíše je do komentáře a do reviewerů, ale v ukázce je owning team jeden člověk a repo nemá ruleset, takže je nic nevynutí. V produkci by přepnutí profilu přepínalo i ruleset (`required_approving_review_count: 2` pro code owners), nebo by počet schválení kontrolovala povinná kontrola `risk-gate` sama.

## Další rozdíly proti ukázce

- **Sandbox agenta.** Agent i kód, který napíše (testy, MSBuild targety), dnes běží na běžném runneru se sítí. V produkci izolované prostředí bez odchozí sítě a klíč k modelu přes proxy s rozpočtem a krátkou platností.
- **Přepočet při změně kalendáře.** Když okno peak skončí, otevřená PR dál ukazují 🟡, dokud někdo nespustí `gate-reevaluate`. V produkci by to dělal plánovaný běh nad otevřenými PR.
- **Hodinová okna.** Kalendář je po celých dnech v Europe/Prague. Okno typu „freeze od pátku 18:00“ by potřebovalo rozšířit formát.
- **Připravené review.** `accept_prepared_review` v `risk-policy.yml` je v ukázce `true`, aby šlo opakovat demo bez modelu. V produkci `false`.
- **Specifikace beze změny.** Pipeline bere specifikaci jen z komentáře intake agenta. Chybí otisk (hash) specifikace a kontrola, že se po potvrzení nezměnila.
- **Ruční úpravy na větvi agenta.** Opakovaný běh agenta přepíše větev `ai/issue-N` (`git push --force`), ruční úpravy člověka na ní se ztratí.
