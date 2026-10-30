# AI SDLC demo: od požadavku k PR

Prototyp k case study „AI SDLC a dekompozice monolitu“. Ukazuje jednu část navržené architektury: cestu změny od byznysového požadavku přes specifikaci a kódovacího agenta až k PR, o jehož sloučení rozhoduje brána podle rizika.

Ukázková služba řeší reklamace fiktivního e-shopu (.NET 10, xUnit). Je malá schválně: jde o tok změny, ne o službu.

## Jak to běží

```
požadavek (issue)  ->  Intake agent  ->  specifikace + pruh  ->  člověk potvrdí (štítek ai:implement)
                                                                         |
   brána podle rizika  <-  AI review  <-  PR  <-  testy  <-  kódovací agent
          |
   🟢 sloučí se sama  /  🟡 schválí člověk  /  🔴 jen vlastnický tým  /  ⛔ neprošly testy
```

| Krok | Kde | Kdo rozhoduje |
|---|---|---|
| Specifikace z požadavku, určení pruhu | `intake.yml` | agent navrhne, zadavatel potvrdí |
| Implementace a testy | `agent-pipeline.yml` › implement | agent |
| Ověření: `dotnet test` | `agent-pipeline.yml` › implement | deterministicky |
| Větev a PR | `agent-pipeline.yml` › publish | deterministicky |
| AI review | `agent-pipeline.yml` › review | agent, jen jako signál |
| Sloučení | `agent-pipeline.yml` › gate, [`risk-policy.yml`](risk-policy.yml) | deterministicky podle politiky |

## Tři pruhy podle cíle změny

1. **Osobní nástroje** mimo produkci: volně.
2. **Produktové změny** mimo citlivé oblasti: agent připraví sám, sloučení řídí brána.
3. **Core** (peníze zákazníků, pipeline, pravidla): agenta smí spustit jen vlastnický tým.

## Mantinely

- **Agent nemá právo zapisovat.** Běží v jobu s oprávněním jen ke čtení. Větev, PR a sloučení dělají další joby skripty, které se dají přečíst.
- **Agent nesmí měnit vlastní pravidla.** Změna `.github/`, `risk-policy.yml`, `AGENTS.md` nebo `CODEOWNERS` se zahodí a běh selže.
- **Ověřuje spuštění, ne model.** O tom, jestli změna funguje, rozhodují testy. AI review je jen jeden ze signálů a sloučení nikdy neschválí samo.
- **Politika je kód.** Kdo smí co sloučit, je v [`risk-policy.yml`](risk-policy.yml) a mění se přes PR jako cokoli jiného.

## Co nefunguje nebo je zjednodušené

- Agent běží na běžném runneru GitHubu se síťovým přístupem. V produkci by běžel v sandboxu bez odchozí sítě, protože požadavek je nedůvěryhodný vstup (prompt injection).
- Sloučení dělá skript s `GITHUB_TOKEN`. Ve firmě by to byla ochrana větve a povinné kontroly.
- Push s `GITHUB_TOKEN` nespouští další workflow, proto testy běží uvnitř pipeline, ne v samostatném CI na PR.
- Riziko se určuje podle cest a velikosti změny. Chybí historie incidentů a závislosti mezi službami.

## Struktura

- `src/Claims.Api` – API v .NET 10; `Domain/` zákonná pravidla, `Refunds/` peníze (citlivá oblast)
- `tests/Claims.Tests` – xUnit testy
- `.github/workflows` – CI, intake a agentní pipeline
- `.github/scripts` – prompty, popis PR a brána podle rizika (Python, jen standardní knihovna + PyYAML)
- `AGENTS.md` – pravidla pro agenty, `risk-policy.yml` – riziková politika, `CODEOWNERS` – vlastnictví
