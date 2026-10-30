# AI SDLC demo: od požadavku k PR

Prototyp k case study „AI SDLC a dekompozice monolitu“. Ukazuje jednu část navržené architektury: cestu změny od byznysového požadavku přes specifikaci a kódovacího agenta až k PR, které projde ověřením a branou podle rizika.

**Stav: rozpracováno.** Zatím je tu ukázková doménová služba (reklamace, fiktivní e-shop) a CI, které ji staví a testuje.

## Co tu bude

| Krok | Kde | Stav |
|---|---|---|
| Vstupní portál: požadavek, doptání, specifikace, pruh podle cíle změny | Lovable | plán |
| Kódovací agent: issue → větev → PR | GitHub Actions | plán |
| Ověření: build, testy, AI review | GitHub Actions | CI hotové |
| Brána podle rizika: automaticky / člověk / jen vlastnický tým | GitHub Actions | plán |
| Náhled změny pro zadavatele | Vercel | plán |

## Struktura

- `src/Claims.Api` – minimální API v .NET 10, doménová pravidla v `Domain/`
- `tests/Claims.Tests` – xUnit testy
- `.github/workflows` – CI a později agentní workflow
