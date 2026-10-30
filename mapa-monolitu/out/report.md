# Mapa monolitu: výsledky

Vygenerováno `analyze.py` (0.1 s). Syntetická DB fiktivního e-shopu, žádná reálná data.

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

## Citlivost pořadí na váhy (±20 %)

Váhy jsou ruční předpoklad. Tady je, jak moc na nich pořadí visí. Výchozí pořadí: 1. D:Claim, 2. D:Category, 3. D:CreditNote, 4. D:GatewayLog, 5. D:RptDailySales.

### Jedna váha po druhé

| Váha | Změna | 1. místo | 2. místo | Rozdíl 1–2 (b.) | Změněných pozic | Top 3 beze změny |
|---|---:|---|---|---:|---:|---|
| zápisy do cizích tabulek | -20 % | D:Claim | D:Category | 1.49 | 5 | **ne** |
| zápisy do cizích tabulek | +20 % | D:Claim | D:Category | 1.72 | 2 | ano |
| cizí zápisy do tabulek domény | -20 % | D:Claim | D:Category | 1.48 | 0 | ano |
| cizí zápisy do tabulek domény | +20 % | D:Claim | D:Category | 1.74 | 2 | ano |
| cizí čtení tabulek domény | -20 % | D:Claim | D:Category | 1.26 | 5 | **ne** |
| cizí čtení tabulek domény | +20 % | D:Claim | D:Category | 1.96 | 2 | ano |
| čtení cizích a sdílených tabulek | -20 % | D:Claim | D:Category | 1.67 | 2 | ano |
| čtení cizích a sdílených tabulek | +20 % | D:Claim | D:Category | 1.55 | 0 | ano |
| dynamické SQL | -20 % | D:Claim | D:Category | 1.70 | 2 | ano |
| dynamické SQL | +20 % | D:Claim | D:Category | 1.52 | 5 | **ne** |
| volání zvenku | -20 % | D:Claim | D:Category | 1.20 | 4 | **ne** |
| volání zvenku | +20 % | D:Claim | D:Category | 2.02 | 0 | ano |
| velikost dat | -20 % | D:Claim | D:Category | 1.70 | 2 | ano |
| velikost dat | +20 % | D:Claim | D:Category | 1.52 | 0 | ano |
| čtecí cesty (levné ověření) | -20 % | D:Claim | D:Category | 2.09 | 2 | **ne** |
| čtecí cesty (levné ověření) | +20 % | D:Claim | D:Category | 1.13 | 2 | ano |
| mrtvý kód k vypnutí | -20 % | D:Claim | D:Category | 1.57 | 2 | **ne** |
| mrtvý kód k vypnutí | +20 % | D:Claim | D:Category | 1.66 | 0 | ano |

### Všechny váhy najednou, náhodně v pásmu ±20 % (2000 kombinací, semínko 7)

| Doména | Podíl běhů na 1. místě | Rozsah pořadí |
|---|---:|---|
| D:Claim | 100.0 % | 1.–1. |
| D:Category | 0.0 % | 2.–2. |
| D:CreditNote | 0.0 % | 3.–7. |
| D:GatewayLog | 0.0 % | 3.–7. |
| D:RptDailySales | 0.0 % | 3.–8. |
| D:CustomerAddress | 0.0 % | 3.–7. |
| D:PriceList | 0.0 % | 3.–7. |
| D:Warehouse | 0.0 % | 6.–8. |
| D:ShipmentTracking | 0.0 % | 9.–9. |
| D:OrderNote | 0.0 % | 10.–10. |

D:Claim je před D:Category v 100.0 % kombinací.

### Bod zvratu mezi 1. a 2. místem

Rozdíl D:Claim − D:Category je 1.61 b. O kolik by se musela změnit jediná váha, aby se pořadí prohodilo:

| Váha | Potřebná změna |
|---|---:|
| čtecí cesty (levné ověření) | +66 % |
| volání zvenku | -78 % |
| cizí čtení tabulek domény | -92 % |
| cizí zápisy do tabulek domény | -256 % (váha by byla záporná) |
| zápisy do cizích tabulek | -280 % (váha by byla záporná) |
| dynamické SQL | +350 % |
| velikost dat | +350 % |
| čtení cizích a sdílených tabulek | +537 % |
| mrtvý kód k vypnutí | -716 % (váha by byla záporná) |

## Pruh core po doménách

Stav určují pravidla v `mapa/evidence.py` a vstup `politika/pruh-core.json` (vlastníci, prahy), ne skóre. Podrobnosti a co chybí: `out/evidence/<doména>.md`, pro bránu `out/evidence/<doména>.json` a `index.json`.

| Doména | Pruh core | Vlastník | Ověřeno / návrh / živé | Zapisující bez ověření | Blokující slepá místa | Co chybí k dalšímu stavu |
|---|---|---|---|---:|---|---|
| D:Claim (Reklamace) | **jen draft PR** | Poprodej (fiktivní) | 0 / 3 / 18 | 13 | – | ověřené pokrytí živých procedur ≥ 80 % (0 z 18 (0 %)); všechny zapisující procedury mají zelený charakterizační test (chybí 13: usp_Claim_ClaimReason_Cleanup, usp_Claim_ClaimReason_Hourly, usp_Claim_ClaimStatusHistory_Cleanup, usp_Claim_ClaimStatusHistory_Confirm, usp_Claim_ClaimStatusHistory_Delete, usp_Claim_ClaimStatusHistory_Merge …) |
| D:Category (Katalog) | **jen draft PR** | Katalog a obsah (fiktivní) | 0 / 0 / 25 | 13 | usp_Product_ProductAttribute_Cleanup | ověřené pokrytí živých procedur ≥ 80 % (0 z 25 (0 %)); všechny zapisující procedury mají zelený charakterizační test (chybí 13: usp_Product_AttributeDef_Process, usp_Product_Brand_Cleanup, usp_Product_Brand_Insert, usp_Product_Category_Nightly, usp_Product_Category_Update, usp_Product_ProductAttribute_Approve …); blokujících slepých míst ≤ 0 (usp_Product_ProductAttribute_Cleanup) |
| D:CreditNote | **zavřený** | – | 0 / 0 / 18 | 12 | usp_Inv_Invoice_Hourly, usp_Inv_YearClose | doména má vlastnický tým (vlastník není určen) |
| D:GatewayLog | **zavřený** | – | 0 / 0 / 18 | 15 | usp_Pay_Payment_Cleanup | doména má vlastnický tým (vlastník není určen) |
| D:RptDailySales | **zavřený** | – | 0 / 0 / 21 | 19 | usp_Rpt_Customers_RptDailySales, usp_Rpt_Dispatch, usp_Rpt_Export_Accounting, usp_Rpt_Export_Email, usp_Rpt_Export_Heureka … (21) | doména má vlastnický tým (vlastník není určen) |
| D:CustomerAddress | **zavřený** | – | 0 / 0 / 19 | 15 | usp_Cust_Customer_Nightly | doména má vlastnický tým (vlastník není určen) |
| D:PriceList | **zavřený** | – | 0 / 0 / 17 | 12 | usp_Price_PriceHistory_MonthClose | doména má vlastnický tým (vlastník není určen) |
| D:Warehouse | **zavřený** | – | 0 / 0 / 41 | 27 | usp_Import_Stock | doména má vlastnický tým (vlastník není určen) |
| D:ShipmentTracking | **zavřený** | – | 0 / 0 / 23 | 19 | – | doména má vlastnický tým (vlastník není určen) |
| D:OrderNote | **zavřený** | – | 0 / 0 / 38 | 28 | usp_Order_Export, usp_Order_OrderEvent_MonthClose, usp_Order_OrderNote_Nightly, usp_Order_OrderStatusHistory_Archive | doména má vlastnický tým (vlastník není určen) |
| D:SysParam | **zavřený** | – | 0 / 0 / 2 | 2 | usp_AuditLog_Purge | doména má vlastnický tým (vlastník není určen); doména je kandidát na vyjmutí (ne úklid, ne malý shluk) (malý shluk: posoudit jako součást sousední domény) |
| D:Users | **zavřený** | – | 0 / 0 / 2 | 1 | – | doména má vlastnický tým (vlastník není určen); doména je kandidát na vyjmutí (ne úklid, ne malý shluk) (malý shluk: posoudit jako součást sousední domény) |
| D:Translation | **zavřený** | – | 0 / 0 / 1 | 0 | – | doména má vlastnický tým (vlastník není určen); doména je kandidát na vyjmutí (ne úklid, ne malý shluk) (malý shluk: posoudit jako součást sousední domény) |
| D:Product_bak2019 | **zavřený** | – | 0 / 0 / 0 | 0 | – | doména má vlastnický tým (vlastník není určen); doména je kandidát na vyjmutí (ne úklid, ne malý shluk) (úklid: většina procedur je mrtvá, vypnout místo měnit) |
| D:TmpRecalc | **zavřený** | – | 0 / 0 / 0 | 0 | – | doména má vlastnický tým (vlastník není určen); doména je kandidát na vyjmutí (ne úklid, ne malý shluk) (úklid: většina procedur je mrtvá, vypnout místo měnit) |
| D:ImportProduct | **zavřený** | – | 0 / 0 / 0 | 0 | – | doména má vlastnický tým (vlastník není určen); doména je kandidát na vyjmutí (ne úklid, ne malý shluk) (úklid: většina procedur je mrtvá, vypnout místo měnit) |
| D:OldOrders | **zavřený** | – | 0 / 0 / 0 | 0 | – | doména má vlastnický tým (vlastník není určen); doména je kandidát na vyjmutí (ne úklid, ne malý shluk) (úklid: většina procedur je mrtvá, vypnout místo měnit) |
| D:X_Migr_Customer | **zavřený** | – | 0 / 0 / 0 | 0 | – | doména má vlastnický tým (vlastník není určen); doména je kandidát na vyjmutí (ne úklid, ne malý shluk) (úklid: většina procedur je mrtvá, vypnout místo měnit) |
