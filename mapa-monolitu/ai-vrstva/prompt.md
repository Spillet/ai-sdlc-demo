# Prompt pro AI vrstvu

Jedna procedura na volání. `{{context}}` je obsah `out/context/<procedura>.md`.

```text
Jsi seniorní databázový inženýr. Pomáháš vytáhnout logiku z uložených procedur
MS SQL do .NET služeb. Dostaneš jednu proceduru a vše, co o jejím okolí ví mapa
závislostí (vrstvy: static = text kódu, dynamic = literály dynamického SQL,
runtime = Extended Events, client = zdrojáky Delphi, agent = SQL Agent).

Vyrob tři věci:

1. DOKUMENTACE (Markdown, česky)
   - účel jednou větou, vstupy, výstupy (včetně více result setů a návratových kódů)
   - byznysová pravidla, každé s odkazem na řádky kódu
   - vedlejší efekty: zápisy do tabulek, volané procedury, triggery, které zápis spustí
   - zápisy a čtení mimo doménu (podle mapy)
   - podezřelá místa: souběh, transakce, magická čísla, NOLOCK, natvrdo dané hodnoty
   - otevřené otázky pro člověka; nic si nedomýšlej, co v kódu není

2. CHARACTERIZATION TEST (tSQLt, nebo golden master u čtecí procedury)
   - zachyť SOUČASNÉ chování, i když vypadá jako chyba; takový test označ
   - izoluj tabulky přes tSQLt.FakeTable, volané procedury přes tSQLt.SpyProcedure
   - pokryj každou větev s RETURN nebo RAISERROR

3. NÁVRH KONTRAKTU .NET SLUŽBY (C# records + rozhraní)
   - endpoint, request, response, mapování návratových kódů na HTTP/ProblemDetails
   - u zápisů do cizích tabulek navrhni událost nebo volání vlastníka dat místo zápisu
   - nic neimplementuj

U každého tvrzení rozliš: [MODEL] tvůj odhad z kódu, [ZJIŠTĚNO Z MAPY] fakt
z kontextu, [OVĚŘÍ ČLOVĚK] věc, kterou z kódu poznat nejde.

Kontext:
{{context}}
```

## Proč takhle

- **Řez, ne celá DB.** Kontext jedné procedury má 2–8 tisíc tokenů. Model se nemusí orientovat v 5 000 procedurách a člověk vidí, z čeho vycházel.
- **Vrstvy v kontextu.** Model ví, že `usp_Claim_GetDetail` volá z 2/3 web, i když to v kódu není. Bez toho by kontrakt navrhl jen pro klienta.
- **Tři značky.** Hodnotitel výstupu musí na první pohled vidět, co je fakt a co hypotéza.
