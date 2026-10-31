"""Risk gate. Rozhodne, kdo smí udělat merge PR, a rozhodnutí zdůvodní.

Použití:
  risk_gate.py PR ARTIFACT_DIR --verify success|failure [--base REF --head REF] [--trigger NAME] [--dry-run]
  risk_gate.py PR ARTIFACT_DIR --from-input [--profile normal|peak|freeze|calendar] [--actor LOGIN] ...

Rozhoduje deterministicky z risk policy, aktivního policy profile a signálů (změněné soubory,
velikost změny, testy, AI review). Model tu nic nerozhoduje, jen dodává verdikt review jako signál.

Policy profile určuje change calendar (change-calendar.yml), nebo ruční přepsání `--profile`
z workflow gate-reevaluate.yml. Profil risk tier jen zvedá, nikdy nesnižuje.

Seznam změněných souborů bere z gitu (`git diff --numstat -z`), ne z textu patche, a porovná ho
se dvěma nezávislými zdroji: se seznamem souborů PR z GitHubu a s počtem hlaviček v patchi.
Když se zdroje neshodnou nebo risk gate nenajde žádný soubor, výsledek je `high` (fail-closed).

`--from-input` (gate re-evaluation): verdikt review, patch a výsledek ověření bere z artefaktu
`gate-input-pr-N` posledního běhu risk gate. Když se větev PR od té doby změnila, výsledek je
`blocked` a je potřeba pustit pipeline znovu.

Komentář odpovídá na otázku auditora „pod jakým režimem změna prošla“: záměr (spec v issue podle
větve PR), kdo spustil agenta (`--requested-by`), verze pravidel (commit, který naposledy změnil
`risk-policy.yml` a `change-calendar.yml` v checkoutu `main`), profil a historie rozhodnutí.
"""
import base64
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from common import REPO, ensure_label, gh, parse_json_answer, read_agent_result
from policy import TIERS, classify, load_calendar, load_policy, matches, max_tier, resolve_profile

LABELS = {
    "low": ("risk:low", "0e8a16", "Auto-merge po testech a AI review"),
    "medium": ("risk:medium", "fbca04", "Merge schvaluje člověk"),
    "high": ("risk:high", "b60205", "Merge jen owning team"),
    "blocked": ("blocked", "000000", "Neprošly testy nebo guardrails, nebo freeze; merge nelze"),
}
ICONS = {"low": "🟢", "medium": "🟡", "high": "🔴", "blocked": "⛔"}
UNRECOGNIZED = "Risk gate nerozpoznala změněné soubory."
MARKER = "<!-- risk-gate -->"
HISTORY = re.compile(r"<!-- risk-gate-history: ([A-Za-z0-9+/=]*) -->")
INPUT_FILE = "gate-input.json"
RULE_FILES = ("risk-policy.yml", "change-calendar.yml")
AGENT_BRANCH = re.compile(r"ai/issue-(\d+)")


def parse_numstat_z(text):
    """Výstup `git diff --numstat -z -M`. Vrátí seznam změn {paths, additions, deletions, binary}.

    Běžný záznam: `A<TAB>D<TAB>cesta<NUL>`. Přejmenování: `A<TAB>D<TAB><NUL>stará<NUL>nová<NUL>`.
    Binární soubor má místo čísel `-`. Cesty jsou bez uvozovek a escapování (díky `-z`).
    """
    parts = text.split("\0")
    changes, i = [], 0
    while i < len(parts):
        head = parts[i]
        i += 1
        if not head.strip():
            continue
        added, deleted, path = head.split("\t", 2)
        if path == "":
            paths = [parts[i], parts[i + 1]]
            i += 2
        else:
            paths = [path]
        binary = added == "-" or deleted == "-"
        changes.append({
            "paths": paths,
            "additions": 0 if binary else int(added),
            "deletions": 0 if binary else int(deleted),
            "binary": binary,
        })
    return changes


def count_patch(text):
    """Počet souborů (hlaviček `diff --git`) a změněných řádků v unified diffu."""
    files = lines = 0
    for line in text.splitlines():
        if line.startswith("diff --git "):
            files += 1
        elif line.startswith(("+", "-")) and not line.startswith(("+++", "---")):
            lines += 1
    return files, lines


def integrity(changes, other_counts, patch_lines):
    """Fail-closed kontrola, že risk gate vidí všechny změněné soubory. Vrátí seznam důvodů pro `high`."""
    problems = []
    if not changes and (patch_lines > 0 or any(count > 0 for count in other_counts.values() if count is not None)):
        problems.append(UNRECOGNIZED + " Seznam je prázdný, ale změna má řádky nebo soubory.")
    for source, count in other_counts.items():
        if count is not None and count != len(changes):
            problems.append(f"{UNRECOGNIZED} Git: {len(changes)} souborů, {source}: {count}.")
    return problems


def profile_of(policy, name=None):
    name = name or policy["default_profile"]
    return name, policy["profiles"][name]


def decide(policy, changes, tests_ok, review, problems=(), profile=None, labels=()):
    """Vrátí (risk tier, vlastníci, řádky zdůvodnění). Risk tier je nejvyšší ze všech signálů.

    `profile` je název policy profile (výchozí `default_profile`), `labels` štítky PR.
    """
    name, prof = profile_of(policy, profile)
    tier, owners, reasons = "low", set(), []

    for problem in problems:
        tier = "high"
        owners.add(policy["owners"]["default"])
        reasons.append(("integrita", "nesoulad", "high", problem))

    paths = [p for change in changes for p in change["paths"]]
    for path in paths:
        rule = classify(path, policy)
        tier = max_tier(tier, rule["tier"])
        owners.add(policy["owners"][rule["owner"]])
        reasons.append(("cesta", f"`{path}`", rule["tier"], rule["reason"]))
        # Profil cestu jen zvedne; do komentáře jde jeden řádek s nejsilnějším důvodem.
        floor, why = rule["tier"], ""
        if rule["tier"] == "low" and not matches(path, prof["auto_merge_paths"]):
            floor, why = max_tier(floor, prof["outside_auto_merge_tier"]), f"Mimo auto-merge cesty profilu `{name}`."
        for extra in prof.get("min_tier_paths") or []:
            level = TIERS.index(extra["tier"])
            if matches(path, extra["paths"]) and level > TIERS.index(rule["tier"]) and level >= TIERS.index(floor):
                floor, why = extra["tier"], extra["reason"]
        if why:
            tier = max_tier(tier, floor)
            reasons.append(("profil", f"`{path}`", floor, why))

    changed_lines = sum(c["additions"] + c["deletions"] for c in changes)
    limits = prof.get("limits") or policy["limits"]
    if changed_lines > limits["medium_max_changed_lines"]:
        tier = max_tier(tier, "high")
        reasons.append(("velikost", f"{changed_lines} řádků", "high", "Nad limitem pro kontrolu člověkem."))
    elif changed_lines > limits["low_max_changed_lines"]:
        tier = max_tier(tier, "medium")
        reasons.append(("velikost", f"{changed_lines} řádků", "medium",
                        f"Nad limitem pro auto-merge v profilu `{name}` ({limits['low_max_changed_lines']} řádků)."))
    else:
        reasons.append(("velikost", f"{changed_lines} řádků", "low",
                        f"V limitu profilu `{name}` ({limits['low_max_changed_lines']} řádků)."))

    signals = policy["signals"]
    touches_src = any(p.startswith("src/") for p in paths)
    touches_tests = any(p.startswith("tests/") for p in paths)
    if signals["require_tests_for_src"] and touches_src and not touches_tests:
        tier = max_tier(tier, "medium")
        reasons.append(("testy", "kód bez nového testu", "medium", "Změna chování bez testu."))

    removed_test_lines = sum(c["deletions"] for c in changes if any(p.startswith("tests/") for p in c["paths"]))
    if removed_test_lines:
        floor = signals["removed_test_lines_min_tier"]
        tier = max_tier(tier, floor)
        reasons.append(("testy", f"odebráno {removed_test_lines} řádků testů", floor,
                        "Úprava nebo odebrání testu může oslabit ochranu. Kontroluje člověk."))

    prepared = bool(review.get("prepared"))
    approved = review.get("verdict") == "approve" and (not prepared or signals.get("accept_prepared_review", False))
    source = " (připravené, bez modelu)" if prepared else ""
    if not approved:
        floor = signals["review_request_changes_min_tier"]
        tier = max_tier(tier, floor)
        reasons.append(("AI review", f"nesouhlasí{source}", floor, review.get("summary", "")))
    else:
        reasons.append(("AI review", f"souhlasí{source}", "low", review.get("summary", "")))

    serious = [f for f in review.get("findings", []) if str(f.get("severity", "")).lower() in ("high", "medium")]
    if serious:
        floor = signals["review_finding_min_tier"]
        tier = max_tier(tier, floor)
        reasons.append(("AI review", f"{len(serious)} vážných nálezů", floor,
                        "Nález se závažností medium nebo high zvedá risk tier i při souhlasu."))

    floor, why = prof.get("min_tier"), prof.get("min_tier_reason", "")
    for exception in prof.get("label_exceptions") or []:
        if exception["label"] in labels:
            floor, why = exception["min_tier"], f"Štítek `{exception['label']}`: {exception['reason']}"
            owners.add(policy["owners"]["default"])
            break
    if floor:
        tier = max_tier(tier, floor)
        reasons.append(("profil", f"`{name}`", floor, why))

    reasons.append(("testy", "prošly" if tests_ok else "NEPROŠLY", "low" if tests_ok else "blocked",
                    "Ověření v čistém jobu bez secrets: guardrails a dotnet test."))
    return tier, owners, reasons


def outcome(tier, tests_ok, draft, profile="", approvals=None):
    """(rozhodnutí, štítek, stav kontroly) pro výsledný risk tier."""
    approvals = approvals or {}
    if not tests_ok:
        return "blocked: neprošly testy nebo guardrails", "blocked", "failure"
    if tier == "blocked":
        return f"blocked: profil `{profile}`, merge teď nelze", "blocked", "failure"
    if draft:
        return "jen draft: lane core spustil ne-vlastník, rozhodne owning team", tier, "failure"
    if tier == "low":
        return "auto-merge", "low", "success"
    if tier == "medium":
        return f"čeká na schválení člověkem ({approvals.get('medium', 1)}×)", "medium", "failure"
    return f"merge jen owning team ({approvals.get('high', 1)}× schválení)", "high", "failure"


def load_review(out):
    agent = read_agent_result(out / "review.json")
    try:
        review = parse_json_answer(agent.get("result", ""))
    except (ValueError, TypeError):
        return {"verdict": "request_changes", "summary": "Review se nepodařilo načíst, risk gate ho bere jako nesouhlas.",
                "findings": []}
    # Připravené review (demo-prepare.yml) se pozná podle obalu od workflow, ne podle textu odpovědi:
    # obal píše skript, obsah `result` by u skutečného review psal model.
    review["prepared"] = agent.get("prepared_by") == "demo-prepare"
    return review


def prague_now():
    from zoneinfo import ZoneInfo

    return datetime.now(timezone.utc).astimezone(ZoneInfo("Europe/Prague")).strftime("%Y-%m-%d %H:%M")


def rules_version(root="."):
    """{soubor pravidel: commit, který ho naposledy změnil}. Risk gate běží z checkoutu `main`,
    takže je to verze pravidel, podle které rozhodla. Bez gitu nebo historie `None` (komentář ukáže `?`).
    """
    versions = {}
    for name in RULE_FILES:
        result = subprocess.run(["git", "log", "-1", "--format=%H", "--", name], cwd=root,
                                capture_output=True, text=True, check=False)
        versions[name] = (result.stdout.strip() or None) if result.returncode == 0 else None
    return versions


def intent_of(head_ref):
    """Odkud změna přišla, podle větve PR. Větve zakládá pipeline; agent nemá token se zápisem."""
    match = AGENT_BRANCH.fullmatch(head_ref or "")
    if match:
        return f"spec v issue #{match.group(1)}"
    if (head_ref or "").startswith("demo/"):
        return "připravená změna z [`demo/messages.yml`](../blob/main/demo/messages.yml) (demo-prepare, bez issue)"
    return f"neznámý zdroj (větev `{head_ref or '?'}`)"


def short(sha):
    return sha[:7] if sha else "?"


def encode_history(entries):
    return base64.b64encode(json.dumps(entries, ensure_ascii=False).encode("utf-8")).decode("ascii")


def decode_history(body):
    match = HISTORY.search(body or "")
    if not match:
        return []
    try:
        return json.loads(base64.b64decode(match.group(1)).decode("utf-8"))
    except (ValueError, TypeError):
        return []


def render_authorization(authz):
    """Odstavec „Autorizace“: záměr, kdo spustil agenta, verze pravidel a kde je schválení člověkem."""
    if not authz:
        return ""
    rules = ", ".join(
        f"[`{name}@{short(sha)}`](../blob/{sha}/{name})" if sha else f"`{name}@?`"
        for name, sha in authz.get("rules", {}).items()
    )
    who = f"@{authz['requested_by']}" if authz.get("requested_by") else "neuvedeno (běh před touto verzí)"
    return (f"\n\n**Autorizace:** záměr: {authz.get('intent', '?')} · agenta spustil {who} "
            f"(`{authz.get('trigger', '?')}`) · pravidla z `main`: {rules} · "
            "schválení člověkem zapisuje review u tohoto PR.")


def render(tier, decision, reasons, review, profile, approvals=None, owners=(), history=(), authz=None):
    rows ="\n".join(f"| {kind} | {what} | {ICONS[t]} {t} | {why} |" for kind, what, t, why in reasons)
    findings = "\n".join(
        f"- **{f.get('severity', '?')}** `{f.get('file', '')}`: {f.get('issue', '')}" for f in review.get("findings", [])
    ) or "- bez nálezů"
    approvals = approvals or {}
    need = ""
    if tier in ("medium", "high"):
        count = approvals.get(tier, 1)
        who = "owning team" if tier == "high" else "člověk s právem merge"
        people = ", ".join(f"@{o}" for o in sorted(owners)) or "?"
        need = f"\n\n**Potřebná schválení:** {count} ({who}; code owners: {people})."
        if count > 1:
            need += (" V demu je owning team jeden člověk a repo nemá ruleset, takže druhé schválení"
                     " GitHub nevynutí. V produkci ho drží ruleset (viz README).")
    past = ""
    if history:
        # Starší záznamy historie verzi pravidel nemají.
        lines = "\n".join(f"| {h['when']} | {h['trigger']} | `{h['profile']}` ({h['source']}) | "
                          f"{' / '.join(short(s) for s in h['rules'].values()) if h.get('rules') else '–'} | "
                          f"{ICONS.get(h['tier'], '')} {h['decision']} |" for h in history)
        past = ("\n<details open><summary>Historie rozhodnutí</summary>\n\n"
                "| Kdy | Spustil | Profil | Pravidla (policy / kalendář) | Rozhodnutí |\n|---|---|---|---|---|\n"
                f"{lines}\n</details>\n")
    return f"""{MARKER}
## Risk gate: {ICONS.get(tier, '')} {decision}

**Policy profile:** `{profile['name']}` – {profile['reason']}.{need}{render_authorization(authz)}

| Signál | Hodnota | Risk tier | Proč |
|---|---|---|---|
{rows}

Výsledný risk tier je nejvyšší ze všech signálů. Pravidla a profily jsou v [`risk-policy.yml`](../blob/main/risk-policy.yml), okna v [`change-calendar.yml`](../blob/main/change-calendar.yml).
{past}
<details><summary>AI review: {review.get('verdict', '?')}{' (připravené, bez modelu)' if review.get('prepared') else ''}</summary>

{review.get('summary', '')}

{findings}
</details>
<!-- risk-gate-history: {encode_history(list(history))} -->
"""


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def git_numstat(base, head):
    result = subprocess.run(["git", "diff", "--numstat", "-z", "-M", f"{base}...{head}"],
                            capture_output=True, check=True)
    return result.stdout.decode("utf-8", errors="surrogateescape")


def find_gate_comment(pr):
    """(id, text) posledního komentáře risk gate od pipeline, nebo (None, "")."""
    ids = gh("api", f"repos/{REPO}/issues/{pr}/comments", "--paginate", "--jq",
             '.[] | select(.user.login == "github-actions[bot]") | select(.body | contains("<!-- risk-gate -->")) | .id',
             check=False).split()
    if not ids:
        return None, ""
    return ids[-1], gh("api", f"repos/{REPO}/issues/comments/{ids[-1]}", "--jq", ".body", check=False)


def main():
    pr, out = sys.argv[1], Path(sys.argv[2])
    dry_run = "--dry-run" in sys.argv
    from_input = "--from-input" in sys.argv
    trigger = arg("--trigger", "gate-reevaluate" if from_input else "agent-pipeline")
    policy, calendar = load_policy(), load_calendar()
    profile = resolve_profile(policy, calendar, override=arg("--profile"), actor=arg("--actor"))
    prof = policy["profiles"][profile["name"]]
    print(f"Policy profile: {profile['name']} ({profile['reason']})")

    changes = parse_numstat_z(git_numstat(arg("--base", "origin/main"), arg("--head", "HEAD")))
    patch_path = out / "change.patch"
    patch_files, patch_lines = count_patch(patch_path.read_text(errors="replace")) if patch_path.exists() else (None, 0)
    counts = {"patch": patch_files}
    head_sha, draft, labels, state = None, False, [], "OPEN"
    head_ref = arg("--head", "").removeprefix("origin/")
    if not dry_run:
        info = json.loads(gh("pr", "view", pr, "--repo", REPO, "--json",
                             "files,headRefName,headRefOid,isDraft,labels,state"))
        counts["soubory PR na GitHubu"] = len(info.get("files") or [])
        head_sha, draft, state, head_ref = info["headRefOid"], info["isDraft"], info["state"], info["headRefName"]
        labels = [label["name"] for label in info.get("labels") or []]
        if state != "OPEN":
            raise SystemExit(f"PR #{pr} není otevřené ({state}), risk gate nemá co rozhodnout.")

    stale = False
    if from_input:
        recorded = json.loads((out / INPUT_FILE).read_text(encoding="utf-8"))
        verify = recorded.get("verify")
        stale = head_sha is not None and recorded.get("head_sha") != head_sha
        # Kdo spustil agenta, se zapsalo při původním běhu; gate re-evaluation agenta nespouští.
        requested_by, source_trigger = recorded.get("requested_by"), recorded.get("trigger")
    else:
        verify = arg("--verify")
        requested_by, source_trigger = arg("--requested-by"), trigger
    tests_ok = verify == "success" and not stale

    review = load_review(out)
    tier, owners, reasons = decide(policy, changes, tests_ok, review, integrity(changes, counts, patch_lines),
                                   profile["name"], labels)
    if stale:
        reasons.insert(0, ("ověření", "jiný commit", "blocked",
                           "Větev PR se od posledního ověření změnila. Pusť pipeline znovu."))
    approvals = prof.get("approvals") or {}
    decision, label, status = outcome(tier, tests_ok, draft, profile["name"], approvals)
    shown = "blocked" if label == "blocked" else tier

    if not from_input and head_sha:
        # Vstup pro gate re-evaluation: workflow ho nahraje jako artefakt gate-input-pr-N.
        (out / INPUT_FILE).write_text(json.dumps({
            "pr": pr, "head_sha": head_sha, "verify": verify, "trigger": trigger,
            "requested_by": requested_by, "run_id": os.environ.get("GITHUB_RUN_ID"),
        }), encoding="utf-8")

    authz = {"intent": intent_of(head_ref), "requested_by": requested_by, "trigger": source_trigger or "?",
             "rules": rules_version()}
    comment_id, old_body = (None, "") if dry_run else find_gate_comment(pr)
    entry = {"when": prague_now(), "trigger": trigger + (f" (@{arg('--actor')})" if arg("--actor") else ""),
             "profile": profile["name"], "source": profile["source"], "tier": shown, "decision": decision,
             "rules": authz["rules"]}
    history = decode_history(old_body) + [entry]
    comment = render(shown, decision, reasons, review, profile, approvals, owners, history, authz)
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        Path(summary_file).write_text(comment, encoding="utf-8")
    if dry_run:
        print(comment)
        return

    payload = json.dumps({"body": comment}, ensure_ascii=False)
    if comment_id:
        gh("api", "-X", "PATCH", f"repos/{REPO}/issues/comments/{comment_id}", "--input", "-", input_text=payload)
    else:
        gh("api", "-X", "POST", f"repos/{REPO}/issues/{pr}/comments", "--input", "-", input_text=payload)

    name, color, description = LABELS[label]
    ensure_label(name, color, description)
    stale_labels = [LABELS[t][0] for t in LABELS if LABELS[t][0] != name and LABELS[t][0] in labels]
    edit = ["pr", "edit", pr, "--repo", REPO, "--add-label", name]
    if stale_labels:
        edit += ["--remove-label", ",".join(stale_labels)]
    gh(*edit)
    # Výsledek jako stav kontroly `risk-gate` na commitu. Ruleset na `main` ho může vyžadovat (viz README).
    gh("api", f"repos/{REPO}/statuses/{head_sha}", "-f", f"state={status}", "-f", "context=risk-gate",
       "-f", f"description={profile['name']}: {tier}: {decision}"[:140], check=False)

    if label == "low" and not draft:
        gh("pr", "merge", pr, "--repo", REPO, "--squash", "--delete-branch")
        print(f"PR #{pr}: auto-merge hotový.")
    elif label in ("medium", "high"):
        gh("pr", "edit", pr, "--repo", REPO, "--add-reviewer", ",".join(sorted(owners)), check=False)
    print(f"PR #{pr}: {profile['name']} -> {shown}: {decision}")


if __name__ == "__main__":
    main()
