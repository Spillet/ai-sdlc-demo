"""Citlivost pořadí domén na váhy skóre.

Skóre je lineární ve vahách (score = 100 − Σ w·složka + Σ bonus), takže stačí
přepočítat uložené složky. Tři pohledy:
  1. jedna váha po druhé ±delta (ostatní beze změny),
  2. náhodné kombinace všech vah v pásmu ±delta (rovnoměrně, pevné semínko),
  3. bod zvratu: o kolik procent by se musela změnit jedna váha, aby se prohodilo první a druhé místo.
"""
import random

from mapa.score import WEIGHTS


def rescore(d, weights):
    s = 100.0
    for k, w in weights.items():
        v = d["components"].get(k, 0.0)
        s += (w * v) if k.startswith("bonus") else -(w * v)
    return max(0.0, min(100.0, s))


def ranking(domains, weights):
    """Pořadí kandidátů (bez úklidu a malých shluků) podle přepočteného skóre."""
    cand = [d for d in domains if not d["cleanup_only"] and not d["too_small"]]
    return [d["domain"] for d in sorted(cand, key=lambda d: (-rescore(d, weights), d["domain"]))]


def one_at_a_time(domains, weights=None, delta=0.2):
    weights = dict(weights or WEIGHTS)
    base = ranking(domains, weights)
    rows = []
    for k in weights:
        for sign in (-1, +1):
            w = dict(weights)
            w[k] = weights[k] * (1 + sign * delta)
            r = ranking(domains, w)
            by = {d["domain"]: d for d in domains}
            rows.append(dict(
                vaha=k, zmena=sign * delta, prvni=r[0], druhy=r[1],
                rozdil_1_2=round(rescore(by[r[0]], w) - rescore(by[r[1]], w), 2),
                zmeny_poradi=sum(1 for i, x in enumerate(r) if base[i] != x),
                top3_stejne=r[:3] == base[:3],
            ))
    return base, rows


def monte_carlo(domains, weights=None, delta=0.2, n=2000, seed=7):
    weights = dict(weights or WEIGHTS)
    rnd = random.Random(seed)
    base = ranking(domains, weights)
    first = {}
    pos = {d: [] for d in base}
    pair_ok = 0
    for _ in range(n):
        w = {k: v * (1 + rnd.uniform(-delta, delta)) for k, v in weights.items()}
        r = ranking(domains, w)
        first[r[0]] = first.get(r[0], 0) + 1
        for i, d in enumerate(r):
            pos[d].append(i + 1)
        if r.index(base[0]) < r.index(base[1]):
            pair_ok += 1
    return dict(
        n=n, delta=delta, seed=seed,
        prvni=dict(sorted(((k, round(v / n, 3)) for k, v in first.items()), key=lambda kv: -kv[1])),
        rozsah_poradi={d: [min(v), max(v)] for d, v in pos.items()},
        p_prvni_pred_druhym=round(pair_ok / n, 3),
    )


def break_even(domains, a, b, weights=None):
    """Pro každou váhu: relativní změna (např. -0.35), při které b dorovná a. None = nikdy (změna jde špatným směrem)."""
    weights = dict(weights or WEIGHTS)
    by = {d["domain"]: d for d in domains}
    da, db = by[a], by[b]
    gap = rescore(da, weights) - rescore(db, weights)
    out = {}
    for k, w in weights.items():
        sign = 1 if k.startswith("bonus") else -1
        # d(gap)/dw_k = sign * (c_a − c_b)
        slope = sign * (da["components"].get(k, 0.0) - db["components"].get(k, 0.0))
        if abs(slope) < 1e-12 or w == 0:
            out[k] = None
            continue
        dw = -gap / slope            # o kolik bodů váhy, aby gap = 0
        out[k] = round(dw / w, 3)
    return round(gap, 2), out


def analyze(domains, weights=None, delta=0.2, n=2000, seed=7):
    weights = dict(weights or WEIGHTS)
    base, oat = one_at_a_time(domains, weights, delta)
    mc = monte_carlo(domains, weights, delta, n, seed)
    gap, be = break_even(domains, base[0], base[1], weights)
    return dict(delta=delta, zakladni_poradi=base, jedna_vaha=oat, nahodne=mc,
                bod_zvratu=dict(prvni=base[0], druhy=base[1], rozdil=gap, relativni_zmena_vahy=be))


def report_md(sens, labels):
    base = sens["zakladni_poradi"]
    mc = sens["nahodne"]
    bz = sens["bod_zvratu"]
    pct = int(round(100 * sens["delta"]))
    L = ["## Citlivost pořadí na váhy (±%d %%)" % pct, "",
         "Váhy jsou ruční předpoklad. Tady je, jak moc na nich pořadí visí. Výchozí pořadí: %s." % ", ".join(
             "%d. %s" % (i + 1, d) for i, d in enumerate(base[:5])), "",
         "### Jedna váha po druhé", "",
         "| Váha | Změna | 1. místo | 2. místo | Rozdíl 1–2 (b.) | Změněných pozic | Top 3 beze změny |",
         "|---|---:|---|---|---:|---:|---|"]
    for r in sens["jedna_vaha"]:
        L.append("| %s | %+d %% | %s | %s | %.2f | %d | %s |" % (
            labels[r["vaha"]], round(100 * r["zmena"]), r["prvni"], r["druhy"], r["rozdil_1_2"], r["zmeny_poradi"],
            "ano" if r["top3_stejne"] else "**ne**"))
    L += ["", "### Všechny váhy najednou, náhodně v pásmu ±%d %% (%d kombinací, semínko %d)" % (pct, mc["n"], mc["seed"]), "",
          "| Doména | Podíl běhů na 1. místě | Rozsah pořadí |", "|---|---:|---|"]
    for d in base:
        L.append("| %s | %.1f %% | %d.–%d. |" % (d, 100 * mc["prvni"].get(d, 0), mc["rozsah_poradi"][d][0], mc["rozsah_poradi"][d][1]))
    L += ["", "%s je před %s v %.1f %% kombinací." % (base[0], base[1], 100 * mc["p_prvni_pred_druhym"]), "",
          "### Bod zvratu mezi 1. a 2. místem", "",
          "Rozdíl %s − %s je %.2f b. O kolik by se musela změnit jediná váha, aby se pořadí prohodilo:" % (
              bz["prvni"], bz["druhy"], bz["rozdil"]), "",
          "| Váha | Potřebná změna |", "|---|---:|"]
    for k, v in sorted(bz["relativni_zmena_vahy"].items(), key=lambda kv: (kv[1] is None, abs(kv[1] or 0))):
        L.append("| %s | %s |" % (labels[k], "nikdy (stejná složka u obou)" if v is None else
                                  ("%+d %%" % round(100 * v)) + (" (váha by byla záporná)" if v < -1 else "")))
    return "\n".join(L) + "\n"
