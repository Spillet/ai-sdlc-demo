# dbo.usp_Claim_GetDetail

> [MODEL] Vygenerováno z `out/context/usp_Claim_GetDetail.md`. Nespuštěno. Ověřit podle bodů na konci.

## Účel

Vrátí detail jedné reklamace pro obrazovku operátora i zákaznický web: hlavičku, položky, historii stavů a přiložené dokumenty. [MODEL]

## Provoz

- 84 948 spuštění za 6 týdnů. 57 225 přímých volání z `Kompas.Web.Api`, 27 723 z `Konzole.exe`. [ZJIŠTĚNO Z MAPY]
- Web je hlavní spotřebitel, přestože o něm Delphi zdrojáky ani plánovač nevědí. Kontrakt se musí navrhovat pro web. [ZJIŠTĚNO Z MAPY]
- Query Store: 1 123 s CPU a 36,9 mil. logických čtení za 30 dní, žádné zápisy. Čistě čtecí cesta. [ZJIŠTĚNO Z MAPY]

## Vstupy

| Parametr | Typ | Význam |
|---|---|---|
| `@ClaimId` | INT | povinný |
| `@UserId` | INT NULL | když je vyplněný, kontroluje se oprávnění `CLAIM_READ`; web ho zřejmě neposílá [MODEL] → [OVĚŘÍ ČLOVĚK] |

## Výstupy: 4 result sety

1. **Hlavička** (0–1 řádek): reklamace, číslo objednávky, zákazník, servis, `DaysLeft` = dny do `DeadlineAt`.
2. **Položky** z `tvf_ClaimItems`: produkt (kód, název), množství, jednotková cena z objednávky, popis vady.
3. **Historie stavů** seřazená podle času, `ChangedBy` přes `fn_UserName`.
4. **Dokumenty**: jméno souboru a klíč v úložišti.

Návratové kódy: `0` (implicitně) nebo `5`, když uživatel nemá oprávnění. **Při kódu 5 nevrací žádný result set.** Klient musí kód číst, jinak uvidí prázdnou obrazovku místo chyby. [MODEL]

## Byznysová pravidla

- `DaysLeft` počítá kalendářní dny do `DeadlineAt` (30denní lhůta na vyřízení nastavená při založení). Záporné číslo = po lhůtě. [MODEL]
- Servis je volitelný (`LEFT JOIN`); u nové reklamace je `NULL`. [MODEL]

## Závislosti

| Objekt | Operace | Vlastník podle mapy |
|---|---|---|
| Claim, ClaimStatusHistory, ClaimDocument, ServiceCenter | čtení | D:Claim |
| Orders, Customer | čtení | **sdílené** (Orders zapisuje hlavně D:OrderNote, Customer D:CustomerAddress) |
| OrderItem, Product (přes `tvf_ClaimItems`) | čtení | **sdílené** |
| `usp_User_CheckPermission`, `fn_UserName` | volání | sdílená infrastruktura |

[ZJIŠTĚNO Z MAPY] Nová služba bude potřebovat data objednávky, zákazníka a produktu od jiných domén. Buď přes jejich API, nebo přes čtecí kopii (CDC/události). Tohle je hlavní práce, ne přepis SELECTů.

## Podezřelá místa

1. `WITH (NOLOCK)` na Claim, Orders a Customer: dirty reads. Nová služba je mít nebude, takže golden master může v době zápisů hlásit rozdíly, které nejsou chybou. Porovnávat jen ustálené reklamace. [MODEL]
2. `DaysLeft` závisí na `GETDATE()`. Golden master musí tento sloupec porovnávat relativně, nebo ho vynechat. [MODEL]
3. Pořadí položek je podle `ClaimItemId`, pořadí dokumentů není definované (chybí `ORDER BY`). Porovnávat dokumenty jako množinu. [MODEL]

## Otázky pro člověka

- Posílá web `@UserId`? Pokud ne, web obchází kontrolu oprávnění a nová služba to musí řešit jinde (token zákazníka). [OVĚŘÍ ČLOVĚK]
- Vidí zákazník na webu interní poznámky z historie stavů (`Note`)? [OVĚŘÍ ČLOVĚK]
