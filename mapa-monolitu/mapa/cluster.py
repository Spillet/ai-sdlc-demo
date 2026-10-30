"""Kandidáti na domény: label propagation nad grafem procedury–tabulky.

Postup:
1. Ze shlukování vyřadit „sdílené“ uzly: tabulky, na které sahá velký podíl
   procedur (AuditLog, Product…), a procedury s velkým fan-in (Audit_Write…).
   Jinak by všechno spadlo do jednoho shluku přes ně.
2. Mrtvé procedury do shlukování nepouštět (zkreslují hranice) a přiřadit je
   až dodatečně podle sousedů.
3. Vážený graf: zápis 3, volání 2, čtení 1. Pohledy se rozbalí na tabulky.
4. Label propagation (Raghavan a kol. 2007), deterministicky: pevné semínko,
   remízy se řeší abecedně.
5. Shluky bez tabulky nebo s méně než 3 uzly se připojí k nejsilnějšímu sousedovi.

Výsledek je návrh pro architekta, ne doménový model.
"""
import random
from collections import Counter, defaultdict

W_WRITE, W_CALL, W_READ = 3.0, 2.0, 1.0


def build_graph(mono, status):
    """Neorientovaný vážený graf mezi moduly a tabulkami."""
    g = defaultdict(lambda: defaultdict(float))
    for e in mono.edges.values():
        s, d, t = e["src"], e["dst"], e["type"]
        if s.startswith("[") or mono.kind(s) == "V":
            continue
        if t in ("reads", "writes"):
            targets = [d]
            w = W_WRITE if t == "writes" else W_READ
            if mono.kind(d) == "V":
                targets = mono.view_tables(d)
                w = w * 0.5
            for x in targets:
                g[s][x] += w
                g[x][s] += w
        elif t == "calls":
            w = W_CALL
            g[s][d] += w
            g[d][s] += w
        elif t == "trigger_on":
            g[s][d] += W_WRITE
            g[d][s] += W_WRITE
    return g


def find_shared(mono, status, table_share=0.08, fanin=8):
    live = [p for p in mono.modules(("P", "FN")) if status.get(p) != "mrtvá"]
    n_live = max(1, len(live))
    touch = defaultdict(set)
    for e in mono.edges.values():
        if e["type"] in ("reads", "writes") and mono.kind(e["dst"]) == "U" and mono.kind(e["src"]) in ("P", "FN"):
            if status.get(e["src"]) != "mrtvá":
                touch[e["dst"]].add(e["src"])
    shared_tables = {t: len(ps) for t, ps in touch.items() if len(ps) / n_live >= table_share}
    callers = defaultdict(set)
    for e in mono.edges.values():
        if e["type"] == "calls" and mono.kind(e["dst"]) in ("P", "FN") and "via_trigger" not in e["flags"]:
            callers[e["dst"]].add(e["src"])
    shared_procs = {p: len(c) for p, c in callers.items() if len(c) >= fanin}
    infra_tables = set()
    # tabulky, do kterých zapisuje sdílená procedura (AuditLog, ErrorLog, Counter…), jsou infrastruktura
    for e in mono.edges.values():
        if e["type"] == "writes" and e["src"] in shared_procs and mono.kind(e["dst"]) == "U":
            shared_tables.setdefault(e["dst"], len(touch.get(e["dst"], ())) + len(callers.get(e["src"], ())))
            infra_tables.add(e["dst"])
    mono.infra_tables = infra_tables
    return shared_tables, shared_procs


def label_propagation(g, nodes, seed=7, max_iter=60):
    rnd = random.Random(seed)
    labels = {n: n for n in sorted(nodes)}
    order = sorted(nodes)
    for it in range(max_iter):
        rnd.shuffle(order)
        changed = 0
        for n in order:
            votes = defaultdict(float)
            for nb, w in g[n].items():
                if nb in labels:
                    votes[labels[nb]] += w
            if not votes:
                continue
            best = max(votes.values())
            cands = sorted(l for l, v in votes.items() if v == best)
            new = labels[n] if labels[n] in cands else cands[0]
            if new != labels[n]:
                labels[n] = new
                changed += 1
        if not changed:
            return labels, it + 1
    return labels, max_iter


def cluster(mono, status):
    shared_tables, shared_procs = find_shared(mono, status)
    g = build_graph(mono, status)
    nodes = set()
    for n in g:
        k = mono.kind(n)
        if n in shared_tables or n in shared_procs:
            continue
        if k in ("P", "FN", "TR") and status.get(n) == "mrtvá":
            continue
        if k in ("P", "FN", "TR", "U"):
            nodes.add(n)
    sub = {n: {m: g[n][m] for m in sorted(g[n]) if m in nodes} for n in sorted(nodes)}
    labels, iters = label_propagation(sub, nodes)

    def groups():
        gr = defaultdict(set)
        for n, l in labels.items():
            gr[l].add(n)
        return gr

    # sloučit shluky bez tabulky nebo příliš malé
    for _ in range(10):
        merged = False
        for l, members in sorted(groups().items(), key=lambda kv: (len(kv[1]), kv[0])):
            has_table = any(mono.kind(m) == "U" for m in members)
            if has_table and len(members) >= 3:
                continue
            ext = defaultdict(float)
            for m in members:
                for nb, w in sub[m].items():
                    if labels[nb] != l:
                        ext[labels[nb]] += w
            if not ext:
                continue
            target = max(sorted(ext), key=lambda k: ext[k])
            for m in members:
                labels[m] = target
            merged = True
            break
        if not merged:
            break

    # agregace shluků podle modularity (krok jako v CNM/Louvain): slučovat dvojici
    # s největším přírůstkem modularity, dokud je přírůstek kladný
    merges = modularity_merge(sub, labels)

    # dodatečné přiřazení vyřazených uzlů (mrtvé, sdílené procedury, osiřelé)
    def attach(n):
        votes = defaultdict(float)
        for nb, w in g[n].items():
            if nb in labels:
                votes[labels[nb]] += w
        return max(sorted(votes), key=lambda k: votes[k]) if votes else None

    assigned_late = {}
    for n in sorted(g):
        if n in labels or mono.kind(n) not in ("P", "FN", "TR", "U"):
            continue
        if n in shared_tables or n in shared_procs:
            continue
        l = attach(n)
        if l:
            assigned_late[n] = l
    labels.update(assigned_late)

    # pojmenování: tabulka s největší vahou hran uvnitř shluku (nejvíc „centrální“)
    gr = groups()
    names = {}
    for l, members in gr.items():
        tw = Counter()
        for m in sorted(members):
            if mono.kind(m) != "U":
                continue
            tw[m] += sum(g[m][nb] for nb in sorted(g[m]) if labels.get(nb) == l) + 0.001
        names[l] = max(sorted(tw), key=lambda k: tw[k]) if tw else sorted(members)[0]
    # unikátní lidská jména
    domain_of = {}
    used = Counter()
    label_name = {}
    for l in sorted(gr, key=lambda x: (-len(gr[x]), x)):
        base = "D:" + names[l]
        used[base] += 1
        label_name[l] = base if used[base] == 1 else "%s#%d" % (base, used[base])
    for n, l in labels.items():
        domain_of[n] = label_name[l]
    return dict(domain_of=domain_of, shared_tables=shared_tables, shared_procs=shared_procs, iterations=iters,
                late=set(assigned_late), graph=g, merges=merges, modularity=round(modularity(sub, labels), 3))


def modularity(g, labels):
    m2 = sum(w for n in g for w in g[n].values())
    if not m2:
        return 0.0
    inner = defaultdict(float)
    deg = defaultdict(float)
    for n in g:
        l = labels[n]
        for nb, w in g[n].items():
            deg[l] += w
            if labels[nb] == l:
                inner[l] += w
    return sum(inner[l] / m2 - (deg[l] / m2) ** 2 for l in deg)


def modularity_merge(g, labels):
    m2 = sum(w for n in g for w in g[n].values())
    merges = 0
    while True:
        deg = defaultdict(float)
        between = defaultdict(float)
        for n in g:
            a = labels[n]
            for nb, w in g[n].items():
                deg[a] += w
                b = labels[nb]
                if a < b:
                    between[(a, b)] += w
        best, pair = 0.0, None
        for (a, b), w in sorted(between.items()):
            dq = 2 * (w / m2 - (deg[a] / m2) * (deg[b] / m2))
            if dq > best + 1e-12:
                best, pair = dq, (a, b)
        if not pair:
            return merges
        a, b = pair
        for n in labels:
            if labels[n] == b:
                labels[n] = a
        merges += 1
