# Mapa monolitu: výsledky

Vygenerováno `analyze.py` (0.3 s). Syntetická DB fiktivního e-shopu, žádná reálná data.

## Rozsah

| Objekty | Počet |
|---|---:|
| Uložené procedury | 277 |
| Funkce | 24 |
| Triggery | 6 |
| Tabulky | 92 |
| Pohledy | 33 |
| Data celkem (fiktivní) | 27.3 TB |

## Vrstvy závislostí

Hran celkem 1997. Statický katalog (obdoba `sys.sql_expression_dependencies`) jich **nevidí 116 (5.8 %)**.

| Vrstva | Hran | Jen tato vrstva |
|---|---:|---:|
| static | 1959 | 1956 |
| dynamic | 15 | 0 |
| runtime | 36 | 21 |
| client | 4 | 4 |
| agent | 0 | 0 |

Vstupní body (procedura volaná zvenku) se v katalogu neobjeví vůbec:

| Zdroj | Procedur |
|---|---:|
| Delphi klient, grep zdrojáků | 115 |
| Plánovač, kroky SQL Agenta | 44 |
| Běh: Konzole.exe (rpc_completed) | 114 |
| Běh: SQL Agent | 41 |
| Běh: Kompas.Web.Api (o webu žádný jiný zdroj neví) | 7 |
| Běh: jiné aplikace | 1 |

### Slepá místa

- Dynamické SQL se skládaným jménem objektu: 21 procedur (usp_Product_Product_Rebuild, usp_Inv_AccountingExport_MonthClose, usp_Inv_Invoice_Sync, usp_Inv_Invoice_Update, usp_Inv_ExchangeRate_Approve, usp_Migr2019_Customer, usp_Migr2019_Product, usp_Import_Product …)
- Odkazy do jiných databází (katalog nemá ID): 13
- Volání bez schématu (`is_caller_dependent`): 17
- Volání z klienta, jehož jméno grep nezjistí: 1 ('usp_Rpt_' + cbReport.Text)
- Kroky plánovače mimo T-SQL (PowerShell): 1
- Procedury bez statického volajícího, které přesto běží: 119
  - z toho je nezná ani klient ani plánovač, ví o nich jen běh: usp_Product_ProductAttribute_Process (Kompas.Web.Api), usp_Product_Product_Dispatch (Kompas.Web.Api), usp_Product_Product_Find (Kompas.Web.Api), usp_Product_Product_Rebuild (Kompas.Web.Api), usp_Rpt_Export_Accounting (vnořené), usp_Rpt_Export_Email (vnořené)

## Stav procedur

| Stav | Počet |
|---|---:|
| mimo okno měření | 1 |
| mrtvá | 25 |
| v klientovi, nepoužitá | 1 |
| živá | 250 |

Sdílené („božské“) tabulky vyřazené ze shlukování: AuditLog (116 procedur), Orders (68 procedur), Customer (62 procedur), OrderItem (47 procedur), Product (46 procedur), JobRun (42 procedur), StockLevel (38 procedur), Shipment (26 procedur), Payment (23 procedur), Counter (21 procedur), ErrorLog (17 procedur)

Sdílené procedury (fan-in ≥ 8): usp_Audit_Write (114), usp_JobRun_Start (40), usp_JobRun_End (40), usp_Counter_Next (20), usp_Error_Log (16), usp_SysParam_Get (15), fn_WorkingDaysBetween (14), fn_UserName (12), fn_IsWorkingDay (12), fn_GetSysParam (10), fn_SplitString (9), usp_User_CheckPermission (8), fn_Translate (8), usp_Rpt_RptCustomerKpi_GetByCode (8), usp_Rpt_RptDailySales_GetByCode (8)

## Kandidáti na domény a doporučené pořadí

| # | Kandidát | Skóre | Procedury (živé/mrtvé) | Tabulky | Data | Proč |
|---:|---|---:|---|---:|---:|---|
| 1 | D:Claim | 83.2 | 22 (21/1) | 7 | 0.20 TB | velikost dat -6 b. (0.2 TB); čtení cizích a sdílených tabulek -4 b. (Customer, OrderItem, Orders); volání zvenku -4 b.; čtecí cesty (levné ověření) +2 b. |
| 2 | D:Category | 81.6 | 25 (25/0) | 8 | 0.13 TB | volání zvenku -6 b.; velikost dat -5 b. (0.1 TB); zápisy do cizích tabulek -4 b. (Product, StockLevel); čtecí cesty (levné ověření) +5 b. |
| 3 | D:CreditNote | 73.0 | 22 (18/4) | 6 | 0.87 TB | dynamické SQL -10 b. (0 z literálu, 3 slepé); velikost dat -7 b. (0.9 TB); volání zvenku -6 b.; čtecí cesty (levné ověření) +3 b. |
| 4 | D:GatewayLog | 72.9 | 19 (19/0) | 5 | 1.33 TB | velikost dat -8 b. (1.3 TB); volání zvenku -8 b.; čtení cizích a sdílených tabulek -6 b. (Payment, Customer, Orders); čtecí cesty (levné ověření) +2 b. |
| 5 | D:RptDailySales | 72.3 | 23 (21/2) | 8 | 0.60 TB | dynamické SQL -10 b. (1 z literálu, 4 slepé); velikost dat -7 b. (0.6 TB); volání zvenku -6 b.; čtecí cesty (levné ověření) +1 b. |
| 6 | D:CustomerAddress | 71.9 | 24 (22/2) | 7 | 0.11 TB | zápisy do cizích tabulek -8 b. (Customer, Orders, AuditLog); cizí čtení tabulek domény -6 b.; velikost dat -5 b. (0.1 TB); čtecí cesty (levné ověření) +2 b.; hlavní zapisovatel sdílené tabulky Customer |
| 7 | D:PriceList | 71.9 | 22 (19/3) | 4 | 0.70 TB | zápisy do cizích tabulek -10 b. (Product, VoucherUse, PriceListItem); velikost dat -7 b. (0.7 TB); čtení cizích a sdílených tabulek -6 b. (OrderItem, Customer, Product); čtecí cesty (levné ověření) +3 b. |
| 8 | D:Warehouse | 69.5 | 50 (44/6) | 15 | 8.58 TB | velikost dat -10 b. (8.6 TB); zápisy do cizích tabulek -7 b. (StockLevel, Product, StockReservation); čtení cizích a sdílených tabulek -5 b. (StockLevel, Product, OrderItem); čtecí cesty (levné ověření) +3 b.; hlavní zapisovatel sdílené tabulky Product, StockLevel |
| 9 | D:ShipmentTracking | 64.7 | 26 (24/2) | 7 | 1.63 TB | zápisy do cizích tabulek -9 b. (Shipment, Orders); dynamické SQL -9 b. (1 z literálu, 3 slepé); velikost dat -8 b. (1.6 TB); čtecí cesty (levné ověření) +2 b.; hlavní zapisovatel sdílené tabulky Shipment |
| 10 | D:OrderNote | 57.3 | 43 (43/0) | 12 | 4.74 TB | zápisy do cizích tabulek -11 b. (Orders, OrderItem, Payment); velikost dat -9 b. (4.7 TB); cizí čtení tabulek domény -6 b.; čtecí cesty (levné ověření) +2 b.; hlavní zapisovatel sdílené tabulky OrderItem, Orders, Payment |
| malý | D:SysParam | 66.2 | 2 (2/0) | 1 | 0.02 TB | méně než 5 živých procedur: spíš součást sousední domény nebo infrastruktury, posoudit ručně; zápisy do cizích tabulek -12 b. (AuditLog); cizí čtení tabulek domény -8 b.; volání zvenku -7 b. |
| malý | D:Users | 87.6 | 2 (2/0) | 2 | 0.02 TB | méně než 5 živých procedur: spíš součást sousední domény nebo infrastruktury, posoudit ručně; cizí čtení tabulek domény -8 b.; volání zvenku -7 b.; velikost dat -3 b. (0.0 TB); čtecí cesty (levné ověření) +5 b. |
| malý | D:Translation | 97.2 | 1 (1/0) | 1 | 0.00 TB | méně než 5 živých procedur: spíš součást sousední domény nebo infrastruktury, posoudit ručně; volání zvenku -7 b.; cizí čtení tabulek domény -5 b.; čtecí cesty (levné ověření) +10 b. |
| úklid | D:Product_bak2019 | 100.0 | 6 (0/6) | 1 | 0.03 TB | většina procedur je mrtvá: vypnout a smazat, nepřepisovat; velikost dat -4 b. (0.0 TB); mrtvý kód k vypnutí +5 b. |
| úklid | D:TmpRecalc | 100.0 | 2 (0/2) | 1 | 0.09 TB | většina procedur je mrtvá: vypnout a smazat, nepřepisovat; velikost dat -5 b. (0.1 TB); mrtvý kód k vypnutí +5 b. |
| úklid | D:ImportProduct | 100.0 | 1 (0/1) | 1 | 0.02 TB | většina procedur je mrtvá: vypnout a smazat, nepřepisovat; velikost dat -3 b. (0.0 TB); mrtvý kód k vypnutí +5 b. |
| úklid | D:OldOrders | 100.0 | 1 (0/1) | 1 | 0.08 TB | většina procedur je mrtvá: vypnout a smazat, nepřepisovat; velikost dat -5 b. (0.1 TB); mrtvý kód k vypnutí +5 b. |
| úklid | D:X_Migr_Customer | 100.0 | 1 (0/1) | 1 | 0.06 TB | většina procedur je mrtvá: vypnout a smazat, nepřepisovat; velikost dat -4 b. (0.1 TB); mrtvý kód k vypnutí +5 b. |

## Jak se analyzátor trefil (proti pravdě generátoru)

- Čistota shluků: **88 %** uzlů leží ve shluku, jehož většinová pravá doména je jejich doména.
- Shluků 18, pravých domén 13. Rozštěpené domény: Legacy → 5, Shared → 3.
- Domény, které shlukování spojilo s jinou (nemají vlastní shluk): Purchasing.
- Mrtvé procedury: nalezeno 26 z 26, falešně označeno 0 .
- Roční job mimo okno měření rozpoznán: ano.
- Dynamické SQL: nalezeno 30 z 30, falešně 0.

Pravá doména je to, co generátor zamýšlel. U skutečné DB žádná pravda není, tam čistotu nahrazuje kontrola architektem.

## Váhy skóre

| Složka | Váha |
|---|---:|
| zápisy do cizích tabulek | −25 |
| cizí zápisy do tabulek domény | −15 |
| cizí čtení tabulek domény | −10 |
| čtení cizích a sdílených tabulek | −10 |
| dynamické SQL | −10 |
| volání zvenku | −10 |
| velikost dat | −10 |
| čtecí cesty (levné ověření) | +10 |
| mrtvý kód k vypnutí | +5 |
