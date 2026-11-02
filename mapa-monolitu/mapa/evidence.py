"""Evidence pack ke každé doméně a stav core lane.

Core lane = změny v uložených procedurách a tabulkách monolitu. Kdo smí
spustit agenta a kdo smí udělat merge, neurčuje model ani skóre, ale důkaz:
owning team domény, ověřené characterization tests a blind spots mapy.

Tři stavy (pořadí od nejpřísnějšího):
  closed      agent pro core v doméně neběží; chybí owning team nebo doména není kandidát
  draft-only  kdokoli zadá záměr, agent založí draft PR; merge může udělat jen vlastník,
              který PR převezme (stejné jako dnes „jen vlastník“)
  open        kdokoli zadá záměr, PR jde do review; merge drží zelené
              characterization tests dotčených procedur a schválení vlastníka

Formát je kontrakt pro risk gate v P2 (popis v README, sekce „Vazba na P2“).
Žádné časové razítko běhu: stejné vstupy = stejné soubory.

Formát @2 (31. 10. 2026): anglické názvy polí a hodnot podle slovníku termínů,
stavy closed / draft-only / open s autonomy level L0–L2, sdílené objekty "shared", záznam běhu testu run.json.
"""
import datetime
import glob
import hashlib
import json
import os
import re

SCHEMA = "mapa-monolitu/evidence-pack@2"
STATES = ("closed", "draft-only", "open")
STATE_LABEL = {s: s for s in STATES}
# Stav core lane -> autonomy level v P2 (L0 čtení, L1 draft-only, L2 merge s důkazem).
# L3 (úzký auto-merge) z mapy nevzniká: potřebuje historii change failure rate z P2.
AUTONOMY_LEVEL = {"closed": "L0", "draft-only": "L1", "open": "L2"}
SHARED = "shared"
TEST_KINDS = ("golden_master", "tsqlt")


# ------------------------------------------------------------------ vstupy

def load_policy(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def scan_tests(ai_dir):
    """Characterization tests podle souborů v ai-vrstva/<procedura>/.

    golden_master*.sql = golden master (čtecí cesta, parallel run)
    test_*.sql         = tSQLt (zápisová cesta)
    run.json           = doložený běh: {"tsqlt": {"result": "green", "date": ..., "environment": ...}, ...}

    Test bez doloženého zeleného běhu je jen draft. Hlavička „NESPUŠTĚNO“
    nic neověřuje, rozhoduje run.json.
    """
    out = {}
    if not os.path.isdir(ai_dir):
        return out
    for d in sorted(os.listdir(ai_dir)):
        p = os.path.join(ai_dir, d)
        if not os.path.isdir(p):
            continue
        runs = {}
        bp = os.path.join(p, "run.json")
        if os.path.exists(bp):
            with open(bp, encoding="utf-8") as f:
                runs = json.load(f)
        found = {}
        for kind, pattern in (("golden_master", "golden_master*.sql"), ("tsqlt", "test_*.sql")):
            files = sorted(glob.glob(os.path.join(p, pattern)))
            if not files:
                continue
            run = runs.get(kind) or {}
            res = run.get("result")
            found[kind] = dict(
                files=[os.path.relpath(x, os.path.dirname(ai_dir)) for x in files],
                status="green" if res == "green" else "red" if res == "red" else "draft",
                run={k: run[k] for k in ("date", "environment", "commit") if k in run} or None,
            )
        if found:
            out[d] = found
    return out


def inputs_hash(data_dir, extra=()):
    """SHA-256 přes vstupy analýzy: verze snímku, kterou risk gate porovná."""
    h = hashlib.sha256()
    files = sorted(glob.glob(os.path.join(data_dir, "**", "*.*"), recursive=True))
    files = [f for f in files if not os.path.basename(f).startswith("_")] + list(extra)
    for f in files:
        if not os.path.isfile(f):
            continue
        h.update(os.path.relpath(f, data_dir).replace(os.sep, "/").encode("utf-8"))
        with open(f, "rb") as fh:
            h.update(fh.read())
    return h.hexdigest()


def slug(domain):
    return re.sub(r"[^A-Za-z0-9_-]+", "-", domain).strip("-")


# ------------------------------------------------------------------ blind spots

def blind_spots(mono, procs):
    """Blind spots mapy u procedur domény. blocking=True drží core lane zavřený pro otevření."""
    procs = set(procs)
    out = []
    blind_dyn = {b["obj"] for b in mono.blind.get("dynamic_blind", [])}
    for p in sorted(procs):
        o = mono.objects.get(p, {})
        if p in blind_dyn:
            seen = sorted({e["dst"] for e in mono.out_edges(p) if "runtime" in e["layers"] and "dynamic_sql" in e["flags"]})
            out.append(dict(
                object=p, type="dynamic_sql_blind", blocking=not seen,
                description=("jméno objektu se skládá za běhu; cíle viděné za běhu: %s (jen v okně měření)" % ", ".join(seen))
                if seen else "jméno objektu se skládá za běhu a běh žádný cíl nezachytil"))
        elif o.get("dynamic"):
            out.append(dict(object=p, type="dynamic_sql_literal", blocking=False,
                            description="dynamické SQL, cíle jdou vyčíst z literálů"))
    for b in mono.blind.get("cross_db", []):
        if b["obj"] in procs:
            out.append(dict(object=b["obj"], type="cross_database", blocking=b["op"] == "write",
                            description="%s do %s (katalog nemá ID)" % ("zápis" if b["op"] == "write" else "čtení", b["ref"])))
    for b in mono.blind.get("client_unresolved", []):
        prefixes = re.findall(r"'([^']+)'", b["expression"])
        hit = sorted(p for p in procs if any(p.startswith(x) for x in prefixes))
        for p in hit:
            out.append(dict(object=p, type="client_composed_name", blocking=True,
                            description="klient skládá jméno procedury (%s, %s:%s); nevíme, které z nich volá" % (
                                b["expression"], b["file"], b["line"])))
    for b in mono.blind.get("agent_non_tsql", []):
        if b["proc"] in procs:
            out.append(dict(object=b["proc"], type="scheduler_non_tsql", blocking=False,
                            description="job %s volá proceduru z kroku %s" % (b["job"], b["subsystem"])))
    for b in mono.blind.get("caller_dependent", []):
        if b["obj"] in procs:
            out.append(dict(object=b["obj"], type="caller_dependent", blocking=False,
                            description="volá %s bez schématu (is_caller_dependent)" % b["ref"]))
    for x in mono.static_only_dead():
        if x["proc"] in procs:
            only_rt = x["seen_by"] == ["jen běh"]
            out.append(dict(object=x["proc"], type="runtime_only" if only_rt else "entry_outside_catalog", blocking=False,
                            description=("volajícího zná jen běh (%s); klient ani plánovač o něm neví" % (", ".join(x["apps"]) or "vnořené volání"))
                            if only_rt else "vstupní bod mimo katalog (%s)" % ", ".join(x["seen_by"])))
    return sorted(out, key=lambda b: (not b["blocking"], b["type"], b["object"]))


# ------------------------------------------------------------------ pravidla

def lane_state(facts, thresholds):
    """Čistá funkce: fakta o doméně -> (stav, pravidla, co chybí k dalšímu stavu).

    facts: owner (dict|None), candidate (bool), not_candidate_reason (str|None), live (int),
           verified (int), writers_unverified (list), blocking (list)
    """
    min_cov = thresholds.get("min_verified_coverage", 0.8)
    max_blind = thresholds.get("max_blocking_blind_spots", 0)
    cov = facts["verified"] / facts["live"] if facts["live"] else 0.0
    wu = facts["writers_unverified"]
    rules = [
        dict(id="R1", rule="doména má owning team", met=bool(facts["owner"]),
             applies_to="draft-only", detail=(facts["owner"] or {}).get("team") or "owning team není určen"),
        dict(id="R2", rule="doména je mezi domain candidates (ne úklid, ne malý shluk)", met=facts["candidate"],
             applies_to="draft-only", detail=facts.get("not_candidate_reason") or "ano"),
        dict(id="R3", rule="ověřené pokrytí živých procedur ≥ %d %%" % round(100 * min_cov),
             met=facts["live"] > 0 and cov >= min_cov, applies_to="open",
             detail="%d z %d (%d %%)" % (facts["verified"], facts["live"], round(100 * cov))),
        dict(id="R4", rule="všechny zapisující procedury mají zelený characterization test",
             met=not wu if thresholds.get("all_writers_verified", True) else True,
             applies_to="open",
             detail="chybí %d: %s" % (len(wu), ", ".join(wu[:6]) + (" …" if len(wu) > 6 else "")) if wu else "ano"),
        dict(id="R5", rule="blokujících blind spots ≤ %d" % max_blind,
             met=len(facts["blocking"]) <= max_blind, applies_to="open",
             detail=", ".join(facts["blocking"]) or "žádné"),
    ]
    base = all(r["met"] for r in rules if r["applies_to"] == "draft-only")
    full = base and all(r["met"] for r in rules if r["applies_to"] == "open")
    state = "open" if full else "draft-only" if base else "closed"
    nxt = {"closed": "draft-only", "draft-only": "open"}.get(state)
    missing = [r["rule"] + " (" + r["detail"] + ")" for r in rules
               if not r["met"] and r["applies_to"] == nxt]
    return state, rules, missing


GATE = {
    "closed": dict(who_runs_agent="nikdo; intake odpoví, co chybí",
                   pr="nevzniká", who_merges="jen vlastník ručně mimo AI pipeline (pokud existuje)"),
    "draft-only": dict(who_runs_agent="kdokoli (záměr a akceptační kritéria)",
                       pr="vždy draft; risk gate jen okomentuje dopad a chybějící důkazy",
                       who_merges="vlastník po převzetí PR; první úkol agenta je doplnit characterization tests"),
    "open": dict(who_runs_agent="kdokoli (záměr a akceptační kritéria)",
                 pr="ready for review",
                 who_merges="vlastník, a merge jen se zelenými characterization tests všech dotčených procedur"),
}


# ------------------------------------------------------------------ evidence pack

def build(mono, status, cl, domains, tests, policy, snapshot_hash):
    """Vrátí (evidence packs podle domény, index pro risk gate)."""
    dom = cl["domain_of"]
    owners = policy.get("owners", {})
    thresholds = policy.get("thresholds", {})
    snap_date = policy.get("snapshot_date")
    valid_to = None
    if snap_date:
        valid_to = (datetime.date.fromisoformat(snap_date) +
                    datetime.timedelta(days=int(policy.get("validity_days", 30)))).isoformat()
    snapshot = dict(date=snap_date, valid_until=valid_to, inputs_sha256=snapshot_hash, policy_version=policy.get("version"))
    packs = {}
    for d in domains:
        name = d["domain"]
        members = sorted(n for n, x in dom.items() if x == name)
        procs = [n for n in members if mono.kind(n) == "P"]
        live = [p for p in procs if status.get(p) != "mrtvá"]
        proc_rows = []
        for p in procs:
            writes = sorted({e["dst"] for e in mono.out_edges(p) if e["type"] == "writes" and mono.kind(e["dst"]) != "V"})
            foreign = sorted(t for t in writes if dom.get(t) != name)
            t = tests.get(p, {})
            char = {k: dict(status=t[k]["status"], files=t[k]["files"], run=t[k]["run"]) if k in t else None for k in TEST_KINDS}
            verified = any(v and v["status"] == "green" for v in char.values())
            drafted = any(v for v in char.values())
            proc_rows.append(dict(
                name=p, status=status.get(p), writes=writes, writes_foreign=foreign,
                calls_6_weeks=mono.runtime_calls.get(p, 0),
                characterization=char,
                coverage="verified" if verified else "draft" if drafted else "missing",
            ))
        live_rows = [r for r in proc_rows if r["name"] in live]
        blind = blind_spots(mono, live)
        blocking = sorted({b["object"] for b in blind if b["blocking"]})
        cand = not d["cleanup_only"] and not d["too_small"]
        facts = dict(
            owner=owners.get(name), candidate=cand,
            not_candidate_reason=None if cand else ("úklid: většina procedur je mrtvá, vypnout místo měnit" if d["cleanup_only"]
                                                    else "malý shluk: posoudit jako součást sousední domény"),
            live=len(live_rows), verified=sum(1 for r in live_rows if r["coverage"] == "verified"),
            writers_unverified=sorted(r["name"] for r in live_rows if r["writes"] and r["coverage"] != "verified"),
            blocking=blocking,
        )
        state, rules, missing = lane_state(facts, thresholds)
        n_live = max(1, len(live_rows))
        packs[name] = dict(
            schema=SCHEMA, domain=name, name=(owners.get(name) or {}).get("name"), snapshot=snapshot,
            core_lane=dict(state=state, label=STATE_LABEL[state], autonomy_level=AUTONOMY_LEVEL[state], gate=GATE[state], rules=rules, missing_for_next_state=missing),
            owner=owners.get(name),
            readiness=dict(score=d["score"], rank=d["order"] or None, components=d["components"], contributions=d["contrib"],
                           note="extraction readiness score řadí domény k vyjmutí, stav core lane neurčuje"),
            coverage=dict(
                live_procedures=len(live_rows),
                verified=facts["verified"],
                draft=sum(1 for r in live_rows if r["coverage"] == "draft"),
                missing=sum(1 for r in live_rows if r["coverage"] == "missing"),
                verified_ratio=round(facts["verified"] / n_live, 3),
                writing=sum(1 for r in live_rows if r["writes"]),
                writing_unverified=facts["writers_unverified"],
            ),
            blind_spots=blind,
            procedures=proc_rows,
            tables=sorted(d["tables"]),
            objects=[n for n in members if mono.kind(n) in ("P", "FN", "TR", "U", "V")] + sorted(d.get("own_shared", [])),
        )
    index = dict(
        schema=SCHEMA, snapshot=snapshot,
        domains={k: dict(state=v["core_lane"]["state"], autonomy_level=v["core_lane"]["autonomy_level"], file=slug(k) + ".json", owner=(v["owner"] or {}).get("github_team"))
                 for k, v in sorted(packs.items())},
        objects=_object_index(packs, cl),
        default_state="closed",
        gate_rules=[
            "objekt, který v indexu není, nebo index po snapshot.valid_until -> closed (fail-closed)",
            "sdílená tabulka nebo procedura (doména 'shared') -> closed, mění se jen přes architektonické review",
            "PR přes víc domén -> nejpřísnější stav z dotčených domén",
            "procedura bez zeleného characterization testu -> nejvýš draft-only, i když je doména open",
        ],
    )
    return packs, index


def _object_index(packs, cl):
    idx = {}
    for name, p in packs.items():
        for o in p["objects"]:
            idx.setdefault(o, name)
    for t in cl["shared_tables"]:
        idx[t] = SHARED
    for t in cl["shared_procs"]:
        idx[t] = SHARED
    return dict(sorted(idx.items()))


def gate_decision(index, packs, changed_objects, today=None):
    """Referenční rozhodnutí risk gate nad indexem (P2 ho má implementovat samo; tady pro testy a ukázku)."""
    today = today or index["snapshot"]["date"]
    vt = index["snapshot"].get("valid_until")
    if not vt or today > vt:
        return "closed", ["snímek mapy je starší než platnost (%s)" % vt]
    order = {s: i for i, s in enumerate(STATES)}
    worst = "open"
    why = []
    for o in changed_objects:
        d = index["objects"].get(o)
        if d is None or d == SHARED:
            st = "closed"
            why.append("%s: %s" % (o, "neznámý objekt" if d is None else "sdílený objekt"))
        else:
            st = index["domains"][d]["state"]
            row = next((r for r in packs[d]["procedures"] if r["name"] == o), None)
            if st == "open" and row is not None and row["coverage"] != "verified":
                st = "draft-only"
                why.append("%s: bez zeleného characterization testu" % o)
            else:
                why.append("%s: doména %s je %s" % (o, d, STATE_LABEL[st]))
        if order[st] < order[worst]:
            worst = st
    return worst, why


# ------------------------------------------------------------------ zápis

def evidence_md(p):
    lc = p["core_lane"]
    cv = p["coverage"]
    title = p["domain"] + (" (%s)" % p["name"] if p.get("name") else "")
    L = ["# Evidence pack: %s" % title, "",
         "Vygenerováno `analyze.py` ze snímku %s (platí do %s, vstupy `%s…`). Strojová verze: `%s.json` (schéma `%s`)." % (
             p["snapshot"]["date"], p["snapshot"]["valid_until"], p["snapshot"]["inputs_sha256"][:12], slug(p["domain"]), p["schema"]), "",
         "## Core lane: **%s** (autonomy level %s)" % (lc["label"], lc["autonomy_level"]), "",
         "- Kdo spustí agenta: %s" % lc["gate"]["who_runs_agent"],
         "- PR: %s" % lc["gate"]["pr"],
         "- Kdo udělá merge: %s" % lc["gate"]["who_merges"],
         "- Owning team: %s" % ((p["owner"] or {}).get("team") or "neurčen"), "",
         "| Pravidlo | Pro stav | Splněno | Detail |", "|---|---|---|---|"]
    for r in lc["rules"]:
        L.append("| %s %s | %s | %s | %s |" % (r["id"], r["rule"], STATE_LABEL[r["applies_to"]], "ano" if r["met"] else "**ne**", r["detail"]))
    if lc["missing_for_next_state"]:
        L += ["", "**Co chybí k dalšímu stavu:**", ""] + ["- " + x for x in lc["missing_for_next_state"]]
    rd = p["readiness"]
    L += ["", "## Extraction readiness score", "",
          "Skóre %.1f%s. %s." % (rd["score"], ", pořadí %d" % rd["rank"] if rd["rank"] else ", mimo pořadí", rd["note"][0].upper() + rd["note"][1:]), "",
          "## Pokrytí characterization tests", "",
          "Živých procedur %d: verified %d, draft %d, missing %d. Zapisujících %d, z toho bez ověřeného testu %d." % (
              cv["live_procedures"], cv["verified"], cv["draft"], cv["missing"], cv["writing"], len(cv["writing_unverified"])), "",
          "Draft = test existuje, ale nemá doložený zelený běh (`run.json`). Draft core lane neotevře.", "",
          "| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |", "|---|---|---|---|---|---:|"]
    for r in p["procedures"]:
        c = r["characterization"]
        L.append("| `%s` | %s | %s | %s | %s | %s |" % (
            r["name"], r["status"], c["golden_master"]["status"] if c["golden_master"] else "–",
            c["tsqlt"]["status"] if c["tsqlt"] else "–",
            ", ".join(("**%s**" % t) if t in r["writes_foreign"] else t for t in r["writes"]) or "–",
            "{:,}".format(r["calls_6_weeks"]).replace(",", " ")))
    L += ["", "## Blind spots", ""]
    if p["blind_spots"]:
        L += ["| Objekt | Typ | Blokuje otevření | Popis |", "|---|---|---|---|"]
        for b in p["blind_spots"]:
            L.append("| `%s` | %s | %s | %s |" % (b["object"], b["type"], "**ano**" if b["blocking"] else "ne", b["description"]))
    else:
        L.append("Žádná.")
    L += ["", "Tučně v tabulce procedur = zápis do tabulky jiné domény nebo sdílené tabulky."]
    return "\n".join(L) + "\n"


def write(packs, index, out_dir):
    import shutil
    shutil.rmtree(out_dir, ignore_errors=True)
    os.makedirs(out_dir)
    for name, p in packs.items():
        s = slug(name)
        with open(os.path.join(out_dir, s + ".json"), "w", encoding="utf-8") as f:
            json.dump(p, f, ensure_ascii=False, indent=1, sort_keys=True)
            f.write("\n")
        with open(os.path.join(out_dir, s + ".md"), "w", encoding="utf-8") as f:
            f.write(evidence_md(p))
    with open(os.path.join(out_dir, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")


def lane_summary(packs, domains):
    """Kompaktní řádky pro HTML a report, ve stejném pořadí jako domény."""
    rows = []
    for d in domains:
        p = packs[d["domain"]]
        rows.append(dict(
            domain=d["domain"], name=p.get("name"), state=p["core_lane"]["state"], label=p["core_lane"]["label"],
            autonomy_level=p["core_lane"]["autonomy_level"],
            owner=(p["owner"] or {}).get("team"), score=d["score"], rank=d["order"] or None,
            live=p["coverage"]["live_procedures"], verified=p["coverage"]["verified"], draft=p["coverage"]["draft"],
            writing=p["coverage"]["writing"], writing_unverified=len(p["coverage"]["writing_unverified"]),
            blocking=sorted({b["object"] for b in p["blind_spots"] if b["blocking"]}),
            blind_spots=len(p["blind_spots"]), rules=p["core_lane"]["rules"], missing=p["core_lane"]["missing_for_next_state"],
            file="out/evidence/" + slug(d["domain"]) + ".md",
        ))
    return rows
