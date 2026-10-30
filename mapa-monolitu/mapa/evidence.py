"""Balíček důkazů ke každé doméně a stav pruhu core.

Pruh core = změny v uložených procedurách a tabulkách monolitu. Kdo smí
spustit agenta a kdo smí sloučit, neurčuje model ani skóre, ale důkaz:
vlastník domény, ověřené charakterizační testy a slepá místa mapy.

Tři stavy (pořadí od nejpřísnějšího):
  zavreny               agent pro core v doméně neběží; chybí vlastník nebo doména není kandidát
  jen_draft_pr          kdokoli zadá záměr, agent založí draft PR; sloučit ho může jen vlastník,
                        který PR převezme (stejné jako dnes „jen vlastník“)
  otevreny_s_vlastnikem kdokoli zadá záměr, PR jde do review; sloučení drží zelené
                        charakterizační testy dotčených procedur a schválení vlastníka

Formát je kontrakt pro bránu v P2 (popis v README, sekce „Vazba na P2“).
Žádné časové razítko běhu: stejné vstupy = stejné soubory.
"""
import datetime
import glob
import hashlib
import json
import os
import re

SCHEMA = "mapa-monolitu/dukazy@1"
STATES = ("zavreny", "jen_draft_pr", "otevreny_s_vlastnikem")
STATE_LABEL = {
    "zavreny": "zavřený",
    "jen_draft_pr": "jen draft PR",
    "otevreny_s_vlastnikem": "otevřený s vlastníkem",
}
TEST_KINDS = ("golden_master", "tsqlt")


# ------------------------------------------------------------------ vstupy

def load_policy(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def scan_tests(ai_dir):
    """Charakterizační testy podle souborů v ai-vrstva/<procedura>/.

    golden_master*.sql = golden master (čtecí cesta, parallel run)
    test_*.sql         = tSQLt (zápisová cesta)
    beh.json           = doložený běh: {"tsqlt": {"vysledek": "zelene", "datum": ..., "prostredi": ...}, ...}

    Test bez doloženého zeleného běhu je jen návrh. Hlavička „NESPUŠTĚNO“
    nic neověřuje, rozhoduje beh.json.
    """
    out = {}
    if not os.path.isdir(ai_dir):
        return out
    for d in sorted(os.listdir(ai_dir)):
        p = os.path.join(ai_dir, d)
        if not os.path.isdir(p):
            continue
        runs = {}
        bp = os.path.join(p, "beh.json")
        if os.path.exists(bp):
            with open(bp, encoding="utf-8") as f:
                runs = json.load(f)
        found = {}
        for kind, pattern in (("golden_master", "golden_master*.sql"), ("tsqlt", "test_*.sql")):
            files = sorted(glob.glob(os.path.join(p, pattern)))
            if not files:
                continue
            run = runs.get(kind) or {}
            res = run.get("vysledek")
            found[kind] = dict(
                soubory=[os.path.relpath(x, os.path.dirname(ai_dir)) for x in files],
                stav="zelene" if res == "zelene" else "cervene" if res == "cervene" else "navrh",
                beh={k: run[k] for k in ("datum", "prostredi", "commit") if k in run} or None,
            )
        if found:
            out[d] = found
    return out


def inputs_hash(data_dir, extra=()):
    """SHA-256 přes vstupy analýzy: verze snímku, kterou brána porovná."""
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


# ------------------------------------------------------------------ slepá místa

def blind_spots(mono, procs):
    """Slepá místa mapy u procedur domény. blokujici=True drží pruh zavřený pro otevření."""
    procs = set(procs)
    out = []
    blind_dyn = {b["obj"] for b in mono.blind.get("dynamic_blind", [])}
    for p in sorted(procs):
        o = mono.objects.get(p, {})
        if p in blind_dyn:
            seen = sorted({e["dst"] for e in mono.out_edges(p) if "runtime" in e["layers"] and "dynamic_sql" in e["flags"]})
            out.append(dict(
                objekt=p, typ="dynamicke_sql_slepe", blokujici=not seen,
                popis=("jméno objektu se skládá za běhu; cíle viděné za běhu: %s (jen v okně měření)" % ", ".join(seen))
                if seen else "jméno objektu se skládá za běhu a běh žádný cíl nezachytil"))
        elif o.get("dynamic"):
            out.append(dict(objekt=p, typ="dynamicke_sql_z_literalu", blokujici=False,
                            popis="dynamické SQL, cíle jdou vyčíst z literálů"))
    for b in mono.blind.get("cross_db", []):
        if b["obj"] in procs:
            out.append(dict(objekt=b["obj"], typ="jina_databaze", blokujici=b["op"] == "write",
                            popis="%s do %s (katalog nemá ID)" % ("zápis" if b["op"] == "write" else "čtení", b["ref"])))
    for b in mono.blind.get("client_unresolved", []):
        prefixes = re.findall(r"'([^']+)'", b["expression"])
        hit = sorted(p for p in procs if any(p.startswith(x) for x in prefixes))
        for p in hit:
            out.append(dict(objekt=p, typ="klient_sklada_jmeno", blokujici=True,
                            popis="klient skládá jméno procedury (%s, %s:%s); nevíme, které z nich volá" % (
                                b["expression"], b["file"], b["line"])))
    for b in mono.blind.get("agent_non_tsql", []):
        if b["proc"] in procs:
            out.append(dict(objekt=b["proc"], typ="planovac_mimo_tsql", blokujici=False,
                            popis="job %s volá proceduru z kroku %s" % (b["job"], b["subsystem"])))
    for b in mono.blind.get("caller_dependent", []):
        if b["obj"] in procs:
            out.append(dict(objekt=b["obj"], typ="volani_bez_schematu", blokujici=False,
                            popis="volá %s bez schématu (is_caller_dependent)" % b["ref"]))
    for x in mono.static_only_dead():
        if x["proc"] in procs:
            only_rt = x["seen_by"] == ["jen běh"]
            out.append(dict(objekt=x["proc"], typ="jen_za_behu" if only_rt else "vstup_mimo_katalog", blokujici=False,
                            popis=("volajícího zná jen běh (%s); klient ani plánovač o něm neví" % (", ".join(x["apps"]) or "vnořené volání"))
                            if only_rt else "vstupní bod mimo katalog (%s)" % ", ".join(x["seen_by"])))
    return sorted(out, key=lambda b: (not b["blokujici"], b["typ"], b["objekt"]))


# ------------------------------------------------------------------ pravidla

def lane_state(fakta, prahy):
    """Čistá funkce: fakta o doméně -> (stav, pravidla, co chybí k dalšímu stavu).

    fakta: vlastnik (dict|None), kandidat (bool), duvod_nekandidat (str|None), zive (int),
           overene (int), zapisujici_neoverene (list), blokujici (list)
    """
    min_cov = prahy.get("min_overene_pokryti", 0.8)
    max_blind = prahy.get("max_blokujicich_slepych_mist", 0)
    cov = fakta["overene"] / fakta["zive"] if fakta["zive"] else 0.0
    rules = [
        dict(id="R1", pravidlo="doména má vlastnický tým", splneno=bool(fakta["vlastnik"]),
             pro="jen_draft_pr", detail=(fakta["vlastnik"] or {}).get("tym") or "vlastník není určen"),
        dict(id="R2", pravidlo="doména je kandidát na vyjmutí (ne úklid, ne malý shluk)", splneno=fakta["kandidat"],
             pro="jen_draft_pr", detail=fakta.get("duvod_nekandidat") or "ano"),
        dict(id="R3", pravidlo="ověřené pokrytí živých procedur ≥ %d %%" % round(100 * min_cov),
             splneno=fakta["zive"] > 0 and cov >= min_cov, pro="otevreny_s_vlastnikem",
             detail="%d z %d (%d %%)" % (fakta["overene"], fakta["zive"], round(100 * cov))),
        dict(id="R4", pravidlo="všechny zapisující procedury mají zelený charakterizační test",
             splneno=not fakta["zapisujici_neoverene"] if prahy.get("vsechny_zapisujici_overene", True) else True,
             pro="otevreny_s_vlastnikem",
             detail="chybí %d: %s" % (len(fakta["zapisujici_neoverene"]), ", ".join(fakta["zapisujici_neoverene"][:6]) +
                                     (" …" if len(fakta["zapisujici_neoverene"]) > 6 else ""))
             if fakta["zapisujici_neoverene"] else "ano"),
        dict(id="R5", pravidlo="blokujících slepých míst ≤ %d" % max_blind,
             splneno=len(fakta["blokujici"]) <= max_blind, pro="otevreny_s_vlastnikem",
             detail=", ".join(fakta["blokujici"]) or "žádné"),
    ]
    base = all(r["splneno"] for r in rules if r["pro"] == "jen_draft_pr")
    full = base and all(r["splneno"] for r in rules if r["pro"] == "otevreny_s_vlastnikem")
    state = "otevreny_s_vlastnikem" if full else "jen_draft_pr" if base else "zavreny"
    nxt = {"zavreny": "jen_draft_pr", "jen_draft_pr": "otevreny_s_vlastnikem"}.get(state)
    missing = [r["pravidlo"] + " (" + r["detail"] + ")" for r in rules
               if not r["splneno"] and r["pro"] == nxt]
    return state, rules, missing


GATE = {
    "zavreny": dict(kdo_spusti_agenta="nikdo; intake odpoví, co chybí",
                    pr="nevzniká", kdo_slouci="jen vlastník ručně mimo AI pipeline (pokud existuje)"),
    "jen_draft_pr": dict(kdo_spusti_agenta="kdokoli (záměr a akceptační kritéria)",
                         pr="vždy draft; brána jen okomentuje dopad a chybějící důkazy",
                         kdo_slouci="vlastník po převzetí PR; první úkol agenta je doplnit charakterizační testy"),
    "otevreny_s_vlastnikem": dict(kdo_spusti_agenta="kdokoli (záměr a akceptační kritéria)",
                                  pr="ready for review",
                                  kdo_slouci="vlastník, a jen když jsou zelené charakterizační testy všech dotčených procedur"),
}


# ------------------------------------------------------------------ balíček

def build(mono, status, cl, domains, tests, policy, snapshot_hash):
    """Vrátí (balíčky podle domény, index pro bránu)."""
    dom = cl["domain_of"]
    owners = policy.get("vlastnici", {})
    prahy = policy.get("prahy", {})
    snap_date = policy.get("datum_snimku")
    valid_to = None
    if snap_date:
        valid_to = (datetime.date.fromisoformat(snap_date) +
                    datetime.timedelta(days=int(policy.get("platnost_dni", 30)))).isoformat()
    snimek = dict(datum=snap_date, platne_do=valid_to, vstupy_sha256=snapshot_hash, verze_politiky=policy.get("verze"))
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
            char = {k: dict(stav=t[k]["stav"], soubory=t[k]["soubory"], beh=t[k]["beh"]) if k in t else None for k in TEST_KINDS}
            verified = any(v and v["stav"] == "zelene" for v in char.values())
            drafted = any(v for v in char.values())
            proc_rows.append(dict(
                nazev=p, stav=status.get(p), zapisuje=writes, zapisuje_cizi=foreign,
                volani_6_tydnu=mono.runtime_calls.get(p, 0),
                charakterizace=char,
                pokryti="overeno" if verified else "navrh" if drafted else "chybi",
            ))
        live_rows = [r for r in proc_rows if r["nazev"] in live]
        blind = blind_spots(mono, live)
        blocking = sorted({b["objekt"] for b in blind if b["blokujici"]})
        cand = not d["cleanup_only"] and not d["too_small"]
        fakta = dict(
            vlastnik=owners.get(name), kandidat=cand,
            duvod_nekandidat=None if cand else ("úklid: většina procedur je mrtvá, vypnout místo měnit" if d["cleanup_only"]
                                                else "malý shluk: posoudit jako součást sousední domény"),
            zive=len(live_rows), overene=sum(1 for r in live_rows if r["pokryti"] == "overeno"),
            zapisujici_neoverene=sorted(r["nazev"] for r in live_rows if r["zapisuje"] and r["pokryti"] != "overeno"),
            blokujici=blocking,
        )
        state, rules, missing = lane_state(fakta, prahy)
        n_live = max(1, len(live_rows))
        packs[name] = dict(
            schema=SCHEMA, domena=name, nazev=(owners.get(name) or {}).get("nazev"), snimek=snimek,
            pruh_core=dict(stav=state, popis=STATE_LABEL[state], brana=GATE[state], pravidla=rules, chybi_k_dalsimu_stavu=missing),
            vlastnik=owners.get(name),
            pripravenost=dict(skore=d["score"], poradi=d["order"] or None, slozky=d["components"], prispevky=d["contrib"],
                              poznamka="skóre řadí domény k vyjmutí, stav pruhu neurčuje"),
            pokryti=dict(
                zive_procedury=len(live_rows),
                overeno=fakta["overene"],
                navrh=sum(1 for r in live_rows if r["pokryti"] == "navrh"),
                chybi=sum(1 for r in live_rows if r["pokryti"] == "chybi"),
                overene_pokryti=round(fakta["overene"] / n_live, 3),
                zapisujici=sum(1 for r in live_rows if r["zapisuje"]),
                zapisujici_neoverene=fakta["zapisujici_neoverene"],
            ),
            slepa_mista=blind,
            procedury=proc_rows,
            tabulky=sorted(d["tables"]),
            objekty=[n for n in members if mono.kind(n) in ("P", "FN", "TR", "U", "V")] + sorted(d.get("own_shared", [])),
        )
    index = dict(
        schema=SCHEMA, snimek=snimek,
        domeny={k: dict(stav=v["pruh_core"]["stav"], soubor=slug(k) + ".json", vlastnik=(v["vlastnik"] or {}).get("github_tym"))
                for k, v in sorted(packs.items())},
        objekty=_object_index(packs, cl),
        vychozi_stav="zavreny",
        pravidla_brany=[
            "objekt, který v indexu není, nebo index starší než snimek.platne_do -> zavreny (fail-closed)",
            "sdílená tabulka nebo procedura (domena 'sdílené') -> zavreny, mění se jen přes architektonické review",
            "PR přes víc domén -> nejpřísnější stav z dotčených domén",
            "procedura bez zeleného charakterizačního testu -> nejvýš jen_draft_pr, i když je doména otevřená",
        ],
    )
    return packs, index


def _object_index(packs, cl):
    idx = {}
    for name, p in packs.items():
        for o in p["objekty"]:
            idx.setdefault(o, name)
    for t in cl["shared_tables"]:
        idx[t] = "sdílené"
    for t in cl["shared_procs"]:
        idx[t] = "sdílené"
    return dict(sorted(idx.items()))


def gate_decision(index, packs, changed_objects, today=None):
    """Referenční rozhodnutí brány nad indexem (P2 ho má implementovat samo; tady pro testy a ukázku)."""
    today = today or index["snimek"]["datum"]
    vt = index["snimek"].get("platne_do")
    if not vt or today > vt:
        return "zavreny", ["snímek mapy je starší než platnost (%s)" % vt]
    order = {s: i for i, s in enumerate(STATES)}
    worst = "otevreny_s_vlastnikem"
    why = []
    for o in changed_objects:
        d = index["objekty"].get(o)
        if d is None or d == "sdílené":
            st = "zavreny"
            why.append("%s: %s" % (o, "neznámý objekt" if d is None else "sdílený objekt"))
        else:
            st = index["domeny"][d]["stav"]
            row = next((r for r in packs[d]["procedury"] if r["nazev"] == o), None)
            if st == "otevreny_s_vlastnikem" and row is not None and row["pokryti"] != "overeno":
                st = "jen_draft_pr"
                why.append("%s: bez zeleného charakterizačního testu" % o)
            else:
                why.append("%s: doména %s je %s" % (o, d, STATE_LABEL[st]))
        if order[st] < order[worst]:
            worst = st
    return worst, why


# ------------------------------------------------------------------ zápis

def evidence_md(p):
    lc = p["pruh_core"]
    pk = p["pokryti"]
    title = p["domena"] + (" (%s)" % p["nazev"] if p.get("nazev") else "")
    L = ["# Balíček důkazů: %s" % title, "",
         "Vygenerováno `analyze.py` ze snímku %s (platí do %s, vstupy `%s…`). Strojová verze: `%s.json` (schéma `%s`)." % (
             p["snimek"]["datum"], p["snimek"]["platne_do"], p["snimek"]["vstupy_sha256"][:12], slug(p["domena"]), p["schema"]), "",
         "## Pruh core: **%s**" % lc["popis"], "",
         "- Kdo spustí agenta: %s" % lc["brana"]["kdo_spusti_agenta"],
         "- PR: %s" % lc["brana"]["pr"],
         "- Kdo sloučí: %s" % lc["brana"]["kdo_slouci"],
         "- Vlastník: %s" % ((p["vlastnik"] or {}).get("tym") or "neurčen"), "",
         "| Pravidlo | Pro stav | Splněno | Detail |", "|---|---|---|---|"]
    for r in lc["pravidla"]:
        L.append("| %s %s | %s | %s | %s |" % (r["id"], r["pravidlo"], STATE_LABEL[r["pro"]], "ano" if r["splneno"] else "**ne**", r["detail"]))
    if lc["chybi_k_dalsimu_stavu"]:
        L += ["", "**Co chybí k dalšímu stavu:**", ""] + ["- " + x for x in lc["chybi_k_dalsimu_stavu"]]
    pr = p["pripravenost"]
    L += ["", "## Připravenost k vyjmutí", "",
          "Skóre %.1f%s. %s." % (pr["skore"], ", pořadí %d" % pr["poradi"] if pr["poradi"] else ", mimo pořadí", pr["poznamka"].capitalize()), "",
          "## Pokrytí charakterizačními testy", "",
          "Živých procedur %d: ověřeno %d, jen návrh %d, chybí %d. Zapisujících %d, z toho bez ověřeného testu %d." % (
              pk["zive_procedury"], pk["overeno"], pk["navrh"], pk["chybi"], pk["zapisujici"], len(pk["zapisujici_neoverene"])), "",
          "Návrh = test existuje, ale nemá doložený zelený běh (`beh.json`). Návrh pruh neotevře.", "",
          "| Procedura | Stav | Golden master | tSQLt | Zapisuje | Volání / 6 týdnů |", "|---|---|---|---|---|---:|"]
    for r in p["procedury"]:
        c = r["charakterizace"]
        L.append("| `%s` | %s | %s | %s | %s | %s |" % (
            r["nazev"], r["stav"], c["golden_master"]["stav"] if c["golden_master"] else "–",
            c["tsqlt"]["stav"] if c["tsqlt"] else "–",
            ", ".join(("**%s**" % t) if t in r["zapisuje_cizi"] else t for t in r["zapisuje"]) or "–",
            "{:,}".format(r["volani_6_tydnu"]).replace(",", " ")))
    L += ["", "## Slepá místa", ""]
    if p["slepa_mista"]:
        L += ["| Objekt | Typ | Blokuje otevření | Popis |", "|---|---|---|---|"]
        for b in p["slepa_mista"]:
            L.append("| `%s` | %s | %s | %s |" % (b["objekt"], b["typ"], "**ano**" if b["blokujici"] else "ne", b["popis"]))
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
            domain=d["domain"], nazev=p.get("nazev"), stav=p["pruh_core"]["stav"], popis=p["pruh_core"]["popis"],
            vlastnik=(p["vlastnik"] or {}).get("tym"), skore=d["score"], poradi=d["order"] or None,
            zive=p["pokryti"]["zive_procedury"], overeno=p["pokryti"]["overeno"], navrh=p["pokryti"]["navrh"],
            zapisujici=p["pokryti"]["zapisujici"], zapisujici_neoverene=len(p["pokryti"]["zapisujici_neoverene"]),
            blokujici=sorted({b["objekt"] for b in p["slepa_mista"] if b["blokujici"]}),
            slepa=len(p["slepa_mista"]), pravidla=p["pruh_core"]["pravidla"], chybi=p["pruh_core"]["chybi_k_dalsimu_stavu"],
            soubor="out/evidence/" + slug(d["domain"]) + ".md",
        ))
    return rows
