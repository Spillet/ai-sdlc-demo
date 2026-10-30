"""Výstupy: JSON mapy, textový report, kontextové balíčky pro AI a statické HTML."""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))


def build_payload(mono, status, cl, domains, summary):
    dom = cl["domain_of"]
    nodes = []
    for n, o in sorted(mono.objects.items()):
        k = o["type"]
        ent = mono.entries.get(n, {})
        nodes.append(dict(
            id=n, type=k, domain=dom.get(n, "sdílené" if (n in cl["shared_tables"] or n in cl["shared_procs"]) else None),
            shared=n in cl["shared_tables"] or n in cl["shared_procs"],
            status=status.get(n), size_gb=mono.sizes.get(n), file=o.get("file"),
            runtime_calls=mono.runtime_calls.get(n), qs=mono.qs.get(n),
            entries={k2: v for k2, v in ent.items() if not k2.startswith("_")},
            apps={k2[5:]: v for k2, v in ent.items() if k2.startswith("_app:")},
            declared_entries=sorted(mono.entry_refs.get(n, ())),
            schedule=mono.schedule.get(n),
            dynamic=o.get("dynamic"), on_table=o.get("on_table"),
            late=n in cl["late"],
            text=o["text"] if k in ("P", "FN", "TR", "V") else None,
        ))
    edges = [dict(src=e["src"], dst=e["dst"], type=e["type"], layers=sorted(e["layers"]), flags=sorted(e["flags"]),
                  count=e["count"] or None) for e in mono.edges.values()]
    edges.sort(key=lambda e: (e["src"], e["dst"], e["type"]))
    return dict(generated_by="mapa-monolitu analyze.py", summary=summary, domains=domains, nodes=nodes, edges=edges)


def report_md(data):
    s = data["summary"]
    L = ["# Mapa monolitu: výsledky", "",
         "Vygenerováno `analyze.py` (%.1f s). Syntetická DB fiktivního e-shopu, žádná reálná data." % s["elapsed_s"], "",
         "## Rozsah", "",
         "| Objekty | Počet |", "|---|---:|",
         "| Uložené procedury | %d |" % s["procedures"], "| Funkce | %d |" % s["functions"],
         "| Triggery | %d |" % s["triggers"], "| Tabulky | %d |" % s["tables"], "| Pohledy | %d |" % s["views"],
         "| Data celkem (fiktivní) | %.1f TB |" % (s["total_size_gb"] / 1000), "",
         "## Vrstvy závislostí", "",
         "Hran celkem %d. Statický katalog (obdoba `sys.sql_expression_dependencies`) jich **nevidí %d (%.1f %%)**." %
         (s["layers"]["total"], s["layers"]["not_in_catalog"], s["layers"]["not_in_catalog_pct"]), "",
         "| Vrstva | Hran | Jen tato vrstva |", "|---|---:|---:|"]
    for l in ("static", "dynamic", "runtime", "client", "agent"):
        L.append("| %s | %d | %d |" % (l, s["layers"]["by_layer"].get(l, 0), s["layers"]["only"].get(l, 0)))
    ee = s["layers"]["entry_edges"]
    L += ["", "Vstupní body (procedura volaná zvenku) se v katalogu neobjeví vůbec:", "",
          "| Zdroj | Procedur |", "|---|---:|",
          "| Delphi klient, grep zdrojáků | %d |" % ee.get("client", 0),
          "| Plánovač, kroky SQL Agenta | %d |" % ee.get("agent", 0),
          "| Běh: Konzole.exe (rpc_completed) | %d |" % ee.get("runtime:client", 0),
          "| Běh: SQL Agent | %d |" % ee.get("runtime:agent", 0),
          "| Běh: Kompas.Web.Api (o webu žádný jiný zdroj neví) | %d |" % ee.get("runtime:web", 0),
          "| Běh: jiné aplikace | %d |" % ee.get("runtime:other", 0), "",
          "### Slepá místa", ""]
    b = s["blind"]
    L.append("- Dynamické SQL se skládaným jménem objektu: %d procedur (%s)" % (
        len(b.get("dynamic_blind", [])), ", ".join(x["obj"] for x in b.get("dynamic_blind", [])[:8]) + (" …" if len(b.get("dynamic_blind", [])) > 8 else "")))
    L.append("- Odkazy do jiných databází (katalog nemá ID): %d" % len(b.get("cross_db", [])))
    L.append("- Volání bez schématu (`is_caller_dependent`): %d" % len(b.get("caller_dependent", [])))
    L.append("- Volání z klienta, jehož jméno grep nezjistí: %d (%s)" % (
        len(b.get("client_unresolved", [])), "; ".join(x["expression"] for x in b.get("client_unresolved", []))))
    L.append("- Kroky plánovače mimo T-SQL (PowerShell): %d" % len(b.get("agent_non_tsql", [])))
    L.append("- Procedury bez statického volajícího, které přesto běží: %d" % len(s["static_dead_but_alive"]))
    only_rt = [x for x in s["static_dead_but_alive"] if x["seen_by"] == ["jen běh"]]
    if only_rt:
        L.append("  - z toho je nezná ani klient ani plánovač, ví o nich jen běh: " +
                 ", ".join("%s (%s)" % (x["proc"], ", ".join(x["apps"]) or "vnořené") for x in only_rt[:10]))
    L += ["", "## Stav procedur", "", "| Stav | Počet |", "|---|---:|"]
    for k, v in sorted(s["status"].items()):
        L.append("| %s | %d |" % (k, v))
    L += ["", "Sdílené („božské“) tabulky vyřazené ze shlukování: " +
          ", ".join("%s (%d procedur)" % kv for kv in sorted(s["shared_tables"].items(), key=lambda kv: -kv[1])),
          "", "Sdílené procedury (fan-in ≥ 8): " + ", ".join("%s (%d)" % kv for kv in sorted(s["shared_procs"].items(), key=lambda kv: -kv[1])),
          "", "## Kandidáti na domény a doporučené pořadí", "",
          "| # | Kandidát | Skóre | Procedury (živé/mrtvé) | Tabulky | Data | Proč |", "|---:|---|---:|---|---:|---:|---|"]
    for d in data["domains"]:
        L.append("| %s | %s | %.1f | %d (%d/%d) | %d | %.2f TB | %s |" % (
            d["order"] or ("úklid" if d["cleanup_only"] else "malý"), d["domain"], d["score"], d["n_procs"], d["n_live"], d["n_dead"], d["n_tables"],
            d["size_gb"] / 1000, "; ".join(d["why"])))
    ev = s.get("evaluation")
    if ev:
        L += ["", "## Jak se analyzátor trefil (proti pravdě generátoru)", "",
              "- Čistota shluků: **%.0f %%** uzlů leží ve shluku, jehož většinová pravá doména je jejich doména." % (100 * ev["purity"]),
              "- Shluků %d, pravých domén %d. Rozštěpené domény: %s." % (
                  ev["clusters"], ev["true_domains"],
                  ", ".join("%s → %d" % (k, len(v)) for k, v in sorted(ev["split"].items()) if len(v) > 1) or "žádné"),
              "- Domény, které shlukování spojilo s jinou (nemají vlastní shluk): %s." % (", ".join(ev["absorbed"]) or "žádné"),
              "- Mrtvé procedury: nalezeno %d z %d, falešně označeno %d %s." % (
                  ev["dead_tp"], ev["dead_true"], len(ev["dead_fp"]), "(" + ", ".join(ev["dead_fp"]) + ")" if ev["dead_fp"] else ""),
              "- Roční job mimo okno měření rozpoznán: %s." % ("ano" if ev["yearly_detected"] else "ne"),
              "- Dynamické SQL: nalezeno %d z %d, falešně %d." % (ev["dyn_found"] - len(ev["dyn_false"]), ev["dyn_true"], len(ev["dyn_false"])),
              "", "Pravá doména je to, co generátor zamýšlel. U skutečné DB žádná pravda není, tam čistotu nahrazuje kontrola architektem."]
    L += ["", "## Váhy skóre", "", "| Složka | Váha |", "|---|---:|"]
    for k, v in s["weights"].items():
        L.append("| %s | %s%d |" % (s["weight_labels"][k], "+" if k.startswith("bonus") else "−", v))
    if data.get("sensitivity"):
        from mapa.sensitivity import report_md as sens_md
        L += ["", sens_md(data["sensitivity"], s["weight_labels"]).rstrip()]
    if data.get("lanes"):
        L += ["", "## Pruh core po doménách", "",
              "Stav určují pravidla v `mapa/evidence.py` a vstup `politika/pruh-core.json` (vlastníci, prahy), ne skóre. "
              "Podrobnosti a co chybí: `out/evidence/<doména>.md`, pro bránu `out/evidence/<doména>.json` a `index.json`.", "",
              "| Doména | Pruh core | Vlastník | Ověřeno / návrh / živé | Zapisující bez ověření | Blokující slepá místa | Co chybí k dalšímu stavu |",
              "|---|---|---|---|---:|---|---|"]
        for r in data["lanes"]:
            L.append("| %s | **%s** | %s | %d / %d / %d | %d | %s | %s |" % (
                r["domain"] + (" (%s)" % r["nazev"] if r["nazev"] else ""), r["popis"], r["vlastnik"] or "–",
                r["overeno"], r["navrh"], r["zive"], r["zapisujici_neoverene"],
                (", ".join(r["blokujici"][:5]) + (" … (%d)" % len(r["blokujici"]) if len(r["blokujici"]) > 5 else "")) or "–",
                "; ".join(r["chybi"]) or "–"))
    return "\n".join(L) + "\n"


def _table_ddl(mono, t):
    o = mono.objects.get(t)
    return o["text"].split("\nGO")[0] if o else ""


def context_packs(mono, status, cl, domain, out_dir):
    """Kontextový balíček pro model: kód procedury + vše, co mapa ví o okolí.

    Tohle je vstup AI vrstvy. Model nedostává celou DB, jen řez kolem procedury.
    """
    os.makedirs(out_dir, exist_ok=True)
    dom = cl["domain_of"]
    procs = sorted(n for n, d in dom.items() if d == domain["domain"] and mono.kind(n) == "P")
    for p in procs:
        o = mono.objects[p]
        outs = mono.out_edges(p)
        ins = mono.in_edges(p)
        tables = sorted({e["dst"] for e in outs if e["type"] in ("reads", "writes")})
        L = ["# Kontext pro AI: dbo.%s" % p, "",
             "Doména (návrh shlukování): %s. Stav: %s. Volání za 6 týdnů (XE module_end): %s." % (
                 domain["domain"], status.get(p), mono.runtime_calls.get(p, 0)), "",
             "## Kód", "", "```sql", o["text"], "```", "", "## Závislosti podle vrstev", ""]
        for e in sorted(outs, key=lambda e: (e["type"], e["dst"])):
            L.append("- %s → `%s` [%s]%s (doména cíle: %s)" % (
                e["type"], e["dst"], ", ".join(sorted(e["layers"])),
                " {" + ", ".join(sorted(e["flags"])) + "}" if e["flags"] else "", dom.get(e["dst"], "sdílené")))
        L += ["", "## Kdo ji volá", ""]
        for e in sorted(ins, key=lambda e: e["src"]):
            if e["type"] == "calls":
                L.append("- `%s` [%s]" % (e["src"], ", ".join(sorted(e["layers"]))))
        ent = mono.entries.get(p, {})
        for k, v in sorted(ent.items()):
            if k.startswith("_app:"):
                L.append("- aplikace `%s`: %d volání (XE rpc_completed)" % (k[5:], v))
        if mono.schedule.get(p):
            L.append("- plánovač: %s" % mono.schedule[p])
        if o.get("dynamic"):
            L += ["", "## Dynamické SQL", "", "Tabulky z literálů: %s. Slepé (skládané jméno): %s." % (
                ", ".join(t for t, _ in o["dynamic"]["tables"]) or "žádné", "ano" if o["dynamic"]["blind"] else "ne")]
        qs = mono.qs.get(p)
        if qs:
            L += ["", "## Provoz (Query Store, 30 dní)", "", ", ".join("%s %s" % kv for kv in sorted(qs.items()))]
        L += ["", "## Schéma dotčených tabulek", ""]
        for t in tables:
            if mono.kind(t) == "U":
                L += ["```sql", _table_ddl(mono, t), "```"]
        with open(os.path.join(out_dir, p + ".md"), "w", encoding="utf-8") as f:
            f.write("\n".join(L) + "\n")


def html(data):
    with open(os.path.join(HERE, "template.html"), encoding="utf-8") as f:
        tpl = f.read()
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    payload = payload.replace("</", "<\\/")
    return tpl.replace("/*__DATA__*/null", payload)
