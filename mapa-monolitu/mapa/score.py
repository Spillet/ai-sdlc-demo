"""Skóre připravenosti k vyjmutí (0–100, víc = snazší vyjmout jako první).

Skóre = 100 − penalizace + bonusy. Váhy jsou ručně zvolené a vypsané
v README; jsou to předpoklady k diskusi, ne kalibrovaný model.
Každá složka je podíl 0–1, takže jde zpětně vysvětlit, odkud číslo je.
"""
import math
from collections import defaultdict

WEIGHTS = {
    "foreign_writes": 25,      # domény procedury zapisují do cizích nebo sdílených tabulek
    "inbound_writes": 15,      # do tabulek domény zapisuje někdo cizí
    "inbound_reads": 10,       # tabulky domény čte někdo cizí (bude potřeba API nebo replika)
    "foreign_reads": 10,       # doména čte cizí nebo sdílené tabulky (bude potřebovat cizí API nebo kopii dat)
    "dynamic_sql": 10,         # dynamické SQL; slepé (skládané jméno objektu) se počítá dvakrát
    "external_calls": 10,      # vstupy zvenku: klient, web, plánovač, volání z jiných domén
    "data_size": 10,           # objem dat vlastněných doménou (log škála do 10 TB)
    "bonus_readonly": 10,      # podíl čtecích procedur: levný parallel run
    "bonus_dead": 5,           # podíl mrtvého kódu: vypnout místo přepsat
}

MIN_LIVE = 5               # menší shluky se neřadí (spíš infrastruktura nebo část sousední domény)

LABELS = {
    "foreign_writes": "zápisy do cizích tabulek",
    "inbound_writes": "cizí zápisy do tabulek domény",
    "inbound_reads": "cizí čtení tabulek domény",
    "foreign_reads": "čtení cizích a sdílených tabulek",
    "dynamic_sql": "dynamické SQL",
    "external_calls": "volání zvenku",
    "data_size": "velikost dat",
    "bonus_readonly": "čtecí cesty (levné ověření)",
    "bonus_dead": "mrtvý kód k vypnutí",
}


def score_domains(mono, status, cl):
    dom = cl["domain_of"]
    shared_t = cl["shared_tables"]
    members = defaultdict(list)
    for n, d in dom.items():
        members[d].append(n)

    def owner(t):
        return dom.get(t)

    # vlastník sdílené tabulky = doména, která do ní nejvíc zapisuje (jen informativně)
    shared_owner = {}
    for t in shared_t:
        cnt = defaultdict(int)
        if t in getattr(mono, "infra_tables", ()):
            shared_owner[t] = "infrastruktura"
            continue
        for e in mono.in_edges(t):
            if e["type"] == "writes" and e["src"] in dom and status.get(e["src"]) != "mrtvá" and mono.kind(e["src"]) != "TR":
                cnt[dom[e["src"]]] += 1
        shared_owner[t] = max(sorted(cnt), key=lambda k: cnt[k]) if cnt else None

    results = []
    for d, ms in members.items():
        procs = [m for m in ms if mono.kind(m) in ("P", "FN", "TR")]
        own_shared = sorted(t for t, o in shared_owner.items() if o == d)
        tables = [m for m in ms if mono.kind(m) == "U"] + own_shared
        if not procs:
            continue
        live = [p for p in procs if status.get(p) != "mrtvá"]
        dead = [p for p in procs if status.get(p) == "mrtvá"]
        w_total = w_foreign = 0
        r_total = r_foreign = 0
        foreign_read_targets = defaultdict(int)
        foreign_targets = defaultdict(int)
        readonly = 0
        dyn_lit = dyn_blind = 0
        blind_names = {b["obj"] for b in mono.blind.get("dynamic_blind", [])}
        ext_in = 0
        ext_detail = defaultdict(int)
        for p in live:
            writes = [e for e in mono.out_edges(p) if e["type"] == "writes"]
            if mono.kind(p) == "P" and not writes:
                readonly += 1
            for e in writes:
                tgt = e["dst"]
                if mono.kind(tgt) == "V":
                    continue
                w_total += 1
                if owner(tgt) != d:
                    w_foreign += 1
                    foreign_targets[tgt] += 1
            for e in mono.out_edges(p):
                if e["type"] != "reads":
                    continue
                tg = [e["dst"]] if mono.kind(e["dst"]) == "U" else mono.view_tables(e["dst"])
                for t in tg:
                    r_total += 1
                    if owner(t) != d:
                        r_foreign += 1
                        foreign_read_targets[t] += 1
            o = mono.objects[p]
            if o.get("dynamic"):
                if p in blind_names:
                    dyn_blind += 1
                else:
                    dyn_lit += 1
            ent = mono.entries.get(p, {})
            srcs = {k for k in ent if not k.startswith("_")} | set(mono.entry_refs.get(p, ()))
            for s in srcs:
                ext_detail[s] += 1
            if srcs:
                ext_in += 1
            for e in mono.in_edges(p):
                if e["type"] == "calls" and dom.get(e["src"]) not in (d, None) and status.get(e["src"]) != "mrtvá" \
                        and "via_trigger" not in e["flags"]:
                    ext_in += 1
                    ext_detail["jiné domény"] += 1
        in_w = in_w_foreign = in_r = in_r_foreign = 0
        inbound_from = defaultdict(int)
        for t in tables:
            for e in mono.in_edges(t):
                src = e["src"]
                if status.get(src) == "mrtvá":
                    continue
                if src.startswith("["):
                    sd = "Delphi klient (přímý SQL)"
                else:
                    sd = dom.get(src) or "sdílené"
                if e["type"] == "writes":
                    in_w += 1
                    if sd != d:
                        in_w_foreign += 1
                        inbound_from[sd] += 1
                elif e["type"] == "reads" and mono.kind(src) != "V":
                    in_r += 1
                    if sd != d:
                        in_r_foreign += 1
        size_gb = sum(mono.sizes.get(t, 0) for t in tables)
        n_live = max(1, len(live))
        comp = {
            "foreign_writes": (w_foreign / w_total) if w_total else 0.0,
            "inbound_writes": (in_w_foreign / in_w) if in_w else 0.0,
            "inbound_reads": (in_r_foreign / in_r) if in_r else 0.0,
            "foreign_reads": (r_foreign / r_total) if r_total else 0.0,
            "dynamic_sql": min(1.0, (dyn_lit + 2 * dyn_blind) / n_live * 3),
            "external_calls": min(1.0, ext_in / n_live / 1.5),
            "data_size": min(1.0, math.log10(1 + size_gb) / math.log10(1 + 10000)),
            "bonus_readonly": readonly / n_live,
            "bonus_dead": len(dead) / max(1, len(procs)),
        }
        score = 100.0
        contrib = {}
        for k, v in comp.items():
            c = WEIGHTS[k] * v
            if k.startswith("bonus"):
                contrib[k] = +c
                score += c
            else:
                contrib[k] = -c
                score -= c
        score = max(0.0, min(100.0, score))
        cpu = sum(mono.qs.get(p, {}).get("cpu_ms", 0) for p in live)
        results.append(dict(
            domain=d, score=round(score, 1), components={k: round(v, 3) for k, v in comp.items()},
            contrib={k: round(v, 1) for k, v in contrib.items()},
            own_shared=own_shared, n_procs=len(procs), n_live=len(live), n_dead=len(dead), n_tables=len(tables), tables=sorted(tables),
            size_gb=round(size_gb, 1), readonly=readonly, dyn_literal=dyn_lit, dyn_blind=dyn_blind,
            foreign_write_targets=dict(sorted(foreign_targets.items(), key=lambda kv: -kv[1])),
            foreign_read_targets=dict(sorted(foreign_read_targets.items(), key=lambda kv: -kv[1])[:8]),
            inbound_writers=dict(sorted(inbound_from.items(), key=lambda kv: -kv[1])),
            external=dict(ext_detail), cpu_ms=cpu, dead_share=round(len(dead) / max(1, len(procs)), 2),
        ))
    # úklidové shluky (většina mrtvá) dát stranou: vypnout, nepřepisovat
    for r in results:
        r["cleanup_only"] = r["dead_share"] >= 0.6
        r["too_small"] = not r["cleanup_only"] and r["n_live"] < MIN_LIVE
        r["why"] = explain(r)
    ordered = sorted([r for r in results if not r["cleanup_only"] and not r["too_small"]], key=lambda r: (-r["score"], r["domain"]))
    for i, r in enumerate(ordered, 1):
        r["order"] = i
    for r in results:
        if r["cleanup_only"] or r["too_small"]:
            r["order"] = 0
    return sorted(results, key=lambda r: (r["order"] == 0, r["cleanup_only"], r["order"], -r["n_procs"])), shared_owner


def explain(r):
    """Tři největší penalizace a největší bonus, česky."""
    pens = sorted(((k, v) for k, v in r["contrib"].items() if v < 0), key=lambda kv: kv[1])[:3]
    out = []
    for k, v in pens:
        if v > -1.5:
            continue
        detail = ""
        if k == "foreign_writes" and r["foreign_write_targets"]:
            detail = " (%s)" % ", ".join(list(r["foreign_write_targets"])[:3])
        elif k == "foreign_reads" and r["foreign_read_targets"]:
            detail = " (%s)" % ", ".join(list(r["foreign_read_targets"])[:3])
        elif k == "inbound_writes" and r["inbound_writers"]:
            detail = " (od %s)" % ", ".join(str(x) for x in list(r["inbound_writers"])[:3])
        elif k == "data_size":
            detail = " (%.1f TB)" % (r["size_gb"] / 1000.0)
        elif k == "dynamic_sql":
            detail = " (%d z literálu, %d slepé)" % (r["dyn_literal"], r["dyn_blind"])
        out.append("%s %.0f b.%s" % (LABELS[k], v, detail))
    bon = sorted(((k, v) for k, v in r["contrib"].items() if v > 0), key=lambda kv: -kv[1])
    for k, v in bon[:1]:
        if v >= 1:
            out.append("%s +%.0f b." % (LABELS[k], v))
    if r.get("cleanup_only"):
        out.insert(0, "většina procedur je mrtvá: vypnout a smazat, nepřepisovat")
    elif r.get("too_small"):
        out.insert(0, "méně než %d živých procedur: spíš součást sousední domény nebo infrastruktury, posoudit ručně" % MIN_LIVE)
    if r.get("own_shared"):
        out.append("hlavní zapisovatel sdílené tabulky %s" % ", ".join(r["own_shared"]))
    return out
