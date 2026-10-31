# Pravidla pro AI agenty v tomto repozitáři

Služba řeší reklamace fiktivního e-shopu. API v .NET 10 (minimal API), testy v xUnit.

## Jak pracovat

- Před změnou si přečti dotčený kód a jeho testy.
- Každá změna chování má test. Nový kód bez testu risk gate nepustí do auto-merge.
- Ověř se: `dotnet test tests/Claims.Tests/Claims.Tests.csproj`. Neodevzdávej změnu, která neprojde.
- Drž změnu malou a jen v rozsahu spec. Žádné refaktoringy navíc.
- Texty pro zákazníky česky, kód, názvy a komentáře podle okolního kódu.

## Kam nesahat

- `.github/`, `risk-policy.yml`, `change-calendar.yml`, `CODEOWNERS`: pipeline a guardrails. Změnu tu pipeline zamítne.
- `AGENTS.md`, `CLAUDE.md` (kdekoli v repu), `.claude/`, `.mcp.json`: instrukce a nastavení agentů. Změnu tu pipeline zamítne.
- `src/Claims.Api/Refunds/` a testy `tests/*Refund*`: peníze zákazníků. Změnu tu můžeš navrhnout, merge smí jen owning team.
- Úprava nebo odebrání existujícího testu a změna `*.csproj` vždy jde ke kontrole člověku.
- `src/Claims.Api/Content/`: texty a šablony zákaznických zpráv. Nová šablona = nová třída v `Content/Templates/` a test; v policy profile normal jde malá změna do auto-merge.

## Doména

- Lhůta na vyřízení reklamace: 30 dní od přijetí (`Domain/ClaimPolicy.cs`).
- Záruka pro spotřebitele: 24 měsíců od nákupu.
- Vracení peněz: `Refunds/RefundCalculator.cs`, sleva nejvýš 50 % ceny.
