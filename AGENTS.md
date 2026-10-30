# Pravidla pro AI agenty v tomto repozitáři

Služba řeší reklamace fiktivního e-shopu. API v .NET 10 (minimal API), testy v xUnit.

## Jak pracovat

- Před změnou si přečti dotčený kód a jeho testy.
- Každá změna chování má test. Nový kód bez testu brána neschválí automaticky.
- Ověř se: `dotnet test tests/Claims.Tests/Claims.Tests.csproj`. Neodevzdávej změnu, která neprojde.
- Drž změnu malou a jen v rozsahu specifikace. Žádné refaktoringy navíc.
- Texty pro zákazníky česky, kód, názvy a komentáře podle okolního kódu.

## Kam nesahat

- `.github/`, `risk-policy.yml`, `AGENTS.md`, `CODEOWNERS`: pipeline a mantinely. Změnu tu pipeline zamítne.
- `src/Claims.Api/Refunds/`: peníze zákazníků. Změnu tu můžeš navrhnout, sloučit ji smí jen vlastnický tým.

## Doména

- Lhůta na vyřízení reklamace: 30 dní od přijetí (`Domain/ClaimPolicy.cs`).
- Záruka pro spotřebitele: 24 měsíců od nákupu.
- Vracení peněz: `Refunds/RefundCalculator.cs`, sleva nejvýš 50 % ceny.
