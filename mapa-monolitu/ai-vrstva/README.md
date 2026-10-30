# AI vrstva na prvním kandidátovi: Reklamace (D:Claim)

Analyzátor doporučil jako první doménu reklamace (skóre 83,2, viz `out/report.md`). Na třech jejích procedurách ukazuju, co z mapy udělá model a co po něm musí udělat člověk.

| Procedura | Proč právě ona | Co AI vyrobila |
|---|---|---|
| `usp_Claim_GetDetail` | čtecí cesta, 85 tis. volání za 6 týdnů, z toho 2/3 z webu | dokumentace, golden master pro parallel run, kontrakt `GET /claims/{id}` |
| `usp_Claim_Create` | hlavní zápis, zákonná lhůta, volá ho web i klient | dokumentace, tSQLt testy, kontrakt `POST /claims` |
| `usp_Claim_SetStatus` | nejhorší hrana domény: zapisuje přímo do skladu a volá platby | dokumentace, tSQLt testy, kontrakt + návrh událostí místo cizích zápisů |

## Jak to vzniklo

1. `analyze.py` vyrobí pro každou proceduru domény kontextový balíček `out/context/<procedura>.md`: kód, závislosti podle vrstev, kdo ji volá a jak často, Query Store, schéma dotčených tabulek. Model nevidí celou databázi, jen tenhle řez.
2. Model dostal balíček a prompt z [`prompt.md`](prompt.md). Jedna procedura = jedno volání, bez nástrojů a bez přístupu k DB.
3. Výstup jsem uložil beze změn obsahu, jen do souborů. Kde model něco tvrdí, je to v textu označené.

Výstupy vygeneroval Claude Opus 5.5 při stavbě prototypu 31. 10. 2026. V repu nejsou volání API, protože prototyp nemá běžet s klíčem. V produkci by krok 2 dělal agent v pipeline nad read-only MCP serverem mapy (viz hlavní README).

## Značky

- **[MODEL]**: vygenerováno modelem z kontextového balíčku. Nespuštěno, neověřeno.
- **[OVĚŘÍ ČLOVĚK]**: rozhodnutí nebo fakt, který model z kódu poznat nemůže (byznysové pravidlo, správnost hypotézy, zákon).
- **[ZJIŠTĚNO Z MAPY]**: fakt z analyzátoru (počty volání, vrstvy, zápisy). Spolehlivý jen tolik, kolik jsou spolehlivé vstupy.

## Co z toho platí a co ne

- **Dokumentace** je nejužitečnější a nejméně riziková část. Model dobře přečte, co procedura dělá, a najde podezřelá místa. Tři nálezy níže jsou typ věcí, které se v legacy kódu hledají týdny: hledání z dokumentace pořád musí potvrdit někdo, kdo zná byznys.
- **Testy tSQLt** nebyly spuštěny. Na syntetické DB nejsou data a tSQLt framework v repu není. Jsou to kostry, které zachycují *současné* chování včetně chyb. Charakterizační test nemá říkat, co je správně, ale co se děje teď.
- **Kontrakty .NET** jsou návrh tvaru API a událostí, ne implementace. Rozhodnutí, jestli reklamace smí dál přímo odepisovat sklad, je architektonické a patří člověku.
- Ekvivalenci staré a nové cesty **nedokazuje model**, ale běh: golden master a parallel run na kopii produkčních volání.

## Hlavní nálezy modelu (k ověření)

1. `usp_Claim_Create` kontroluje reklamované množství **mimo transakci**. Dvě souběžná volání (web + operátor) můžou reklamovat víc kusů, než bylo objednáno. [MODEL] → [OVĚŘÍ ČLOVĚK]: stává se to v datech?
2. `fn_Claim_Deadline` počítá lhůtu od data objednávky, ne od převzetí zboží; komentář odkazuje na ticket 4711. U zboží doručeného později zkracuje zákonnou lhůtu. [MODEL] → [OVĚŘÍ ČLOVĚK]: právní výklad.
3. `usp_Claim_SetStatus` při výměně odepisuje kus přímo z `StockLevel` ve skladu s natvrdo daným `WarehouseId = 1`. Tím přes trigger `trg_StockLevel_Movement` zapisuje i do 8,3TB `StockMovement`. Tohle je hrana, kvůli které doména nemá skóre 90+. [ZJIŠTĚNO Z MAPY] + [MODEL]

Soubory: [`usp_Claim_GetDetail/`](usp_Claim_GetDetail), [`usp_Claim_Create/`](usp_Claim_Create), [`usp_Claim_SetStatus/`](usp_Claim_SetStatus), [`kontrakt/ClaimsContracts.cs`](kontrakt/ClaimsContracts.cs).
