#!/usr/bin/env python3
"""Mapa monolitu: analyzátor závislostí T-SQL monolitu.

  python3 analyze.py                      analýza syntetické DB v data/synthetic
  python3 analyze.py --data cesta         analýza vlastních vstupů (formát viz sql/collect/)
  python3 analyze.py --regenerate         nejdřív znovu vygenerovat syntetickou DB

Výstupy:
  out/map.json        celý graf, domény, skóre (vstup pro HTML i pro MCP server)
  out/report.md       textový souhrn výsledků
  out/context/*.md    kontextové balíčky pro AI vrstvu (první doporučená doména)
  out/evidence/       balíček důkazů a stav pruhu core ke každé doméně (kontrakt pro bránu v P2)
  site/index.html     statická mapa, funguje otevřením z disku

Jen standardní knihovna, Python 3.9+.
"""
import argparse
import glob
import json
import os
import subprocess
import sys
import time
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from mapa.model import Monolith, LAYERS          # noqa: E402
from mapa.cluster import cluster                 # noqa: E402
from mapa.score import score_domains, WEIGHTS, LABELS   # noqa: E402
from mapa import render                          # noqa: E402
from mapa import evidence, sensitivity           # noqa: E402


def layer_stats(mono):
    """Kolik hran vidí která vrstva a kolik jich statický katalog nevidí."""
    by_layer = Counter()
    only = Counter()
    total = 0
    not_static = 0
    for e in mono.edges.values():
        if e["type"] == "trigger_on":
            continue
        total += 1
        for l in e["layers"]:
            by_layer[l] += 1
        if "static" not in e["layers"] or "via_trigger" in e["flags"]:
            not_static += 1
        if len(e["layers"]) == 1:
            only[next(iter(e["layers"]))] += 1
    # hrany vstupních bodů (klient/plánovač/web -> procedura) jako samostatná kategorie
    entry_edges = Counter()
    for p, refs in mono.entry_refs.items():
        for r in refs:
            entry_edges[r] += 1
    for p, ent in mono.entries.items():
        for k in ent:
            if not k.startswith("_"):
                entry_edges["runtime:" + k] += 1
    return dict(total=total, by_layer=dict(by_layer), only=dict(only), not_in_catalog=not_static,
                not_in_catalog_pct=round(100.0 * not_static / max(1, total), 1), entry_edges=dict(entry_edges))


def evaluate(mono, status, cl, truth_path):
    """Porovnání s pravdou generátoru. Analyzátor ji nepoužívá, jen se tu měří."""
    if not os.path.exists(truth_path):
        return None
    with open(truth_path, encoding="utf-8") as f:
        truth = json.load(f)
    td = dict(truth["domains"])
    td.update(truth["table_domains"])
    dom = cl["domain_of"]
    # čistota shluků: podíl uzlů, které patří do většinové pravé domény shluku
    by_cluster = defaultdict(list)
    for n, d in dom.items():
        if n in td:
            by_cluster[d].append(td[n])
    correct = sum(Counter(v).most_common(1)[0][1] for v in by_cluster.values())
    total = sum(len(v) for v in by_cluster.values())
    majority = {d: Counter(v).most_common(1)[0][0] for d, v in by_cluster.items()}
    # rozštěpení: do kolika shluků se pravá doména rozpadla (počítá jen shluky, kde je většinou)
    split = defaultdict(set)
    for d, m in majority.items():
        split[m].add(d)
    dead_true = set(truth["dead"])
    dead_found = {p for p, s in status.items() if s in ("mrtvá", "v klientovi, nepoužitá") and mono.kind(p) == "P"}
    yearly_ok = all(status.get(p) == "mimo okno měření" for p in truth["yearly"])
    dyn_true = set(truth["dynamic"])
    dyn_found = {n for n, o in mono.objects.items() if o.get("dynamic")}
    return dict(
        purity=round(correct / max(1, total), 3), clusters=len(by_cluster), true_domains=len(set(td.values())),
        majority=majority, split={k: sorted(v) for k, v in split.items()},
        absorbed=sorted(set(td.values()) - set(majority.values())),
        dead_true=len(dead_true), dead_found=len(dead_found),
        dead_tp=len(dead_true & dead_found), dead_fp=sorted(dead_found - dead_true), dead_fn=sorted(dead_true - dead_found),
        yearly_detected=yearly_ok,
        dyn_true=len(dyn_true), dyn_found=len(dyn_found), dyn_missed=sorted(dyn_true - dyn_found),
        dyn_false=sorted(dyn_found - dyn_true),
        client_unused_true=truth["client_unused"],
    )


def main():
    ap = argparse.ArgumentParser(description="Mapa monolitu")
    ap.add_argument("--data", default=os.path.join(HERE, "data", "synthetic"))
    ap.add_argument("--out", default=os.path.join(HERE, "out"))
    ap.add_argument("--site", default=os.path.join(HERE, "site", "index.html"))
    ap.add_argument("--policy", default=os.path.join(HERE, "politika", "pruh-core.json"))
    ap.add_argument("--tests", default=os.path.join(HERE, "ai-vrstva"),
                    help="složka s charakterizačními testy po procedurách (<procedura>/golden_master*.sql, test_*.sql, beh.json)")
    ap.add_argument("--regenerate", action="store_true")
    a = ap.parse_args()
    t0 = time.time()
    if a.regenerate or not os.path.exists(os.path.join(a.data, "db")):
        subprocess.check_call([sys.executable, os.path.join(HERE, "generator", "generate_synthetic_db.py"), a.data])

    mono = Monolith(a.data).load()
    mono.index()
    status = mono.liveness()
    cl = cluster(mono, status)
    domains, shared_owner = score_domains(mono, status, cl)
    stats = layer_stats(mono)
    ev = evaluate(mono, status, cl, os.path.join(a.data, "_ground_truth.json"))
    static_dead = mono.static_only_dead()
    elapsed = round(time.time() - t0, 2)

    counts = Counter(o["type"] for o in mono.objects.values())
    summary = dict(
        procedures=counts["P"], functions=counts["FN"], triggers=counts["TR"], tables=counts["U"], views=counts["V"],
        status=dict(Counter(status[p] for p in mono.modules(("P",)))),
        layers=stats, shared_tables=cl["shared_tables"], shared_procs=cl["shared_procs"],
        shared_owner=shared_owner, lpa_iterations=cl["iterations"], elapsed_s=elapsed,
        blind={k: v for k, v in mono.blind.items()}, static_dead_but_alive=static_dead,
        weights=WEIGHTS, weight_labels=LABELS, evaluation=ev,
        total_size_gb=round(sum(mono.sizes.values()), 1),
        live_procs=sum(1 for p in mono.modules(("P",)) if status[p] != "mrtvá"),
        modularity=cl["modularity"], merges=cl["merges"],
    )
    sens = sensitivity.analyze(domains, WEIGHTS)
    policy = evidence.load_policy(a.policy)
    tests = evidence.scan_tests(a.tests)
    packs, ev_index = evidence.build(mono, status, cl, domains, tests, policy,
                                     evidence.inputs_hash(a.data, extra=[a.policy] + sorted(
                                         glob.glob(os.path.join(a.tests, "*", "beh.json")))))
    os.makedirs(a.out, exist_ok=True)
    data = render.build_payload(mono, status, cl, domains, summary)
    data["lanes"] = evidence.lane_summary(packs, domains)
    data["sensitivity"] = sens
    evidence.write(packs, ev_index, os.path.join(a.out, "evidence"))
    with open(os.path.join(a.out, "map.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=True)
    with open(os.path.join(a.out, "report.md"), "w", encoding="utf-8") as f:
        f.write(render.report_md(data))
    first = next((d for d in domains if d["order"] == 1), None)
    import shutil
    shutil.rmtree(os.path.join(a.out, "context"), ignore_errors=True)
    if first:
        render.context_packs(mono, status, cl, first, os.path.join(a.out, "context"))
    os.makedirs(os.path.dirname(a.site), exist_ok=True)
    with open(a.site, "w", encoding="utf-8") as f:
        f.write(render.html(data))

    # krátký výpis do konzole
    print("Mapa monolitu: %d procedur, %d funkcí, %d triggerů, %d tabulek, %d pohledů (%.1f s)" %
          (summary["procedures"], summary["functions"], summary["triggers"], summary["tables"], summary["views"], elapsed))
    live_p = [p for p in mono.modules(("P",)) if status[p] != "mrtvá"]
    print("Hrany mezi objekty: %d, z toho %d (%.1f %%) mimo statický katalog" % (stats["total"], stats["not_in_catalog"], stats["not_in_catalog_pct"]))
    print("Živé procedury bez statického volajícího (vstupní body z klienta, plánovače, webu nebo dynamického SQL): %d z %d" % (len(static_dead), len(live_p)))
    print("Stav procedur: " + ", ".join("%s %d" % kv for kv in sorted(summary["status"].items())))
    print("Sdílené tabulky: " + ", ".join(sorted(cl["shared_tables"])))
    print("\nPořadí  Doména                    Skóre  Proc(živé/mrtvé)  Tabulky  Data GB")
    for d in domains:
        print("%5s   %-24s %6.1f  %4d (%d/%d)        %3d   %8.1f   %s" % (
            d["order"] or ("úklid" if d["cleanup_only"] else "malý"), d["domain"], d["score"], d["n_procs"], d["n_live"], d["n_dead"], d["n_tables"],
            d["size_gb"], "; ".join(d["why"][:2])))
    print("\nPruh core: " + ", ".join("%s %s" % (r["domain"], r["popis"]) for r in data["lanes"] if r["stav"] != "zavreny") +
          "; ostatní zavřené (%d)" % sum(1 for r in data["lanes"] if r["stav"] == "zavreny"))
    mc = sens["nahodne"]
    print("Citlivost vah ±%d %%: %s před %s v %.0f %% kombinací" % (
        100 * sens["delta"], sens["zakladni_poradi"][0], sens["zakladni_poradi"][1], 100 * mc["p_prvni_pred_druhym"]))
    if ev:
        print("\nVyhodnocení proti pravdě generátoru: čistota shluků %.0f %%, %d shluků / %d pravých domén; "
              "mrtvé %d/%d nalezeno, falešně %d; dynamické SQL %d/%d" % (
                  100 * ev["purity"], ev["clusters"], ev["true_domains"], ev["dead_tp"], ev["dead_true"],
                  len(ev["dead_fp"]), ev["dyn_found"] - len(ev["dyn_false"]), ev["dyn_true"]))
    print("\nVýstupy: %s (včetně evidence/), %s" % (os.path.relpath(a.out, HERE), os.path.relpath(a.site, HERE)))


if __name__ == "__main__":
    main()
