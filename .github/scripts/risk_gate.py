"""Brána podle rizika. Rozhodne, kdo smí PR sloučit, a rozhodnutí zdůvodní.

Použití: risk_gate.py PR ARTIFACT_DIR --verify success|failure [--base REF --head REF] [--dry-run]

Rozhoduje deterministicky z rizikové politiky a signálů (změněné soubory, velikost změny,
testy, AI review). Model tu nic nerozhoduje, jen dodává verdikt review jako jeden ze signálů.

Seznam změněných souborů bere z gitu (`git diff --numstat -z`), ne z textu patche, a porovná ho
se dvěma nezávislými zdroji: se seznamem souborů PR z GitHubu a s počtem hlaviček v patchi od agenta.
Když se zdroje neshodnou nebo brána nenajde žádný soubor, výsledek je `high` (fail-closed).
"""
import json
import os
import subprocess
import sys
from pathlib import Path

from common import REPO, ensure_label, gh, parse_json_answer, read_agent_result
from policy import classify, load_policy, max_tier

LABELS = {
    "low": ("riziko:nizke", "0e8a16", "Sloučí se automaticky po testech a review"),
    "medium": ("riziko:stredni", "fbca04", "Sloučení schvaluje člověk"),
    "high": ("riziko:vysoke", "b60205", "Měnit smí jen vlastnický tým"),
    "blocked": ("blokovano", "000000", "Neprošly testy nebo mantinely, nelze sloučit"),
}
UNRECOGNIZED = "Brána nerozpoznala změněné soubory."


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
    """Fail-closed kontrola, že brána vidí všechny změněné soubory. Vrátí seznam důvodů pro `high`."""
    problems = []
    if not changes and (patch_lines > 0 or any(count > 0 for count in other_counts.values())):
        problems.append(UNRECOGNIZED + " Seznam je prázdný, ale změna má řádky nebo soubory.")
    for source, count in other_counts.items():
        if count is not None and count != len(changes):
            problems.append(f"{UNRECOGNIZED} Git: {len(changes)} souborů, {source}: {count}.")
    return problems


def decide(policy, changes, tests_ok, review, problems=()):
    """Vrátí (úroveň, vlastníci, řádky zdůvodnění). Úroveň je nejvyšší ze všech signálů."""
    tier, owners, reasons = "low", set(), []

    for problem in problems:
        tier = "high"
        owners.add(policy["owners"]["default"])
        reasons.append(("integrita", "nesoulad", "high", problem))

    paths = [p for change in changes for p in change["paths"]]
    for change in changes:
        for path in change["paths"]:
            rule = classify(path, policy)
            tier = max_tier(tier, rule["tier"])
            owners.add(policy["owners"][rule["owner"]])
            reasons.append(("cesta", f"`{path}`", rule["tier"], rule["reason"]))

    changed_lines = sum(c["additions"] + c["deletions"] for c in changes)
    limits = policy["limits"]
    if changed_lines > limits["medium_max_changed_lines"]:
        tier = "high"
        reasons.append(("velikost", f"{changed_lines} řádků", "high", "Nad limitem pro kontrolu člověkem."))
    elif changed_lines > limits["low_max_changed_lines"]:
        tier = max_tier(tier, "medium")
        reasons.append(("velikost", f"{changed_lines} řádků", "medium", "Nad limitem pro automatické sloučení."))
    else:
        reasons.append(("velikost", f"{changed_lines} řádků", "low", "V limitu."))

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

    if review.get("verdict") != "approve":
        floor = signals["review_request_changes_min_tier"]
        tier = max_tier(tier, floor)
        reasons.append(("AI review", "nesouhlasí", floor, review.get("summary", "")))
    else:
        reasons.append(("AI review", "souhlasí", "low", review.get("summary", "")))

    serious = [f for f in review.get("findings", []) if str(f.get("severity", "")).lower() in ("high", "medium")]
    if serious:
        floor = signals["review_finding_min_tier"]
        tier = max_tier(tier, floor)
        reasons.append(("AI review", f"{len(serious)} vážných nálezů", floor,
                        "Nález se závažností medium nebo high zvedá úroveň i při souhlasu."))

    reasons.append(("testy", "prošly" if tests_ok else "NEPROŠLY", "low" if tests_ok else "blocked",
                    "Ověření v čistém jobu bez secrets: mantinely a dotnet test."))
    return tier, owners, reasons


def outcome(tier, tests_ok, draft):
    """(rozhodnutí, štítek, stav kontroly) pro výslednou úroveň."""
    if not tests_ok:
        return "zablokováno, neprošly testy nebo mantinely", "blocked", "failure"
    if draft:
        return "jen návrh (draft): pruh 3 spustil ne-vlastník, rozhodne vlastnický tým", tier, "failure"
    if tier == "low":
        return "sloučeno automaticky", "low", "success"
    if tier == "medium":
        return "čeká na schválení člověkem", "medium", "failure"
    return "jen vlastnický tým", "high", "failure"


def load_review(out):
    agent = read_agent_result(out / "review.json")
    try:
        return parse_json_answer(agent.get("result", ""))
    except (ValueError, TypeError):
        return {"verdict": "request_changes", "summary": "Review se nepodařilo načíst, brána ho bere jako nesouhlas.",
                "findings": []}


def render(tier, decision, reasons, review):
    icons = {"low": "🟢", "medium": "🟡", "high": "🔴", "blocked": "⛔"}
    rows = "\n".join(f"| {kind} | {what} | {icons[t]} {t} | {why} |" for kind, what, t, why in reasons)
    findings = "\n".join(
        f"- **{f.get('severity', '?')}** `{f.get('file', '')}`: {f.get('issue', '')}" for f in review.get("findings", [])
    ) or "- bez nálezů"
    return f"""## Brána podle rizika: {icons.get(tier, '')} {decision}

| Signál | Hodnota | Úroveň | Proč |
|---|---|---|---|
{rows}

Výsledná úroveň je nejvyšší ze všech signálů. Pravidla jsou v [`risk-policy.yml`](../blob/main/risk-policy.yml).

<details><summary>AI review: {review.get('verdict', '?')}</summary>

{review.get('summary', '')}

{findings}
</details>
"""


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def git_numstat(base, head):
    result = subprocess.run(["git", "diff", "--numstat", "-z", "-M", f"{base}...{head}"],
                            capture_output=True, check=True)
    return result.stdout.decode("utf-8", errors="surrogateescape")


def main():
    pr, out = sys.argv[1], Path(sys.argv[2])
    dry_run = "--dry-run" in sys.argv
    tests_ok = arg("--verify") == "success"
    policy = load_policy()

    changes = parse_numstat_z(git_numstat(arg("--base", "origin/main"), arg("--head", "HEAD")))
    patch_path = out / "change.patch"
    patch_files, patch_lines = count_patch(patch_path.read_text(errors="replace")) if patch_path.exists() else (None, 0)
    counts = {"patch od agenta": patch_files}
    head_sha, draft = None, False
    if not dry_run:
        info = json.loads(gh("pr", "view", pr, "--repo", REPO, "--json", "files,headRefOid,isDraft"))
        counts["soubory PR na GitHubu"] = len(info.get("files") or [])
        head_sha, draft = info["headRefOid"], info["isDraft"]

    review = load_review(out)
    tier, owners, reasons = decide(policy, changes, tests_ok, review, integrity(changes, counts, patch_lines))
    decision, label, state = outcome(tier, tests_ok, draft)

    comment = render(label if label == "blocked" else tier, decision, reasons, review)
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        Path(summary_file).write_text(comment, encoding="utf-8")
    if dry_run:
        print(comment)
        return

    gh("pr", "comment", pr, "--repo", REPO, "--body-file", "-", input_text=comment)
    name, color, description = LABELS[label]
    ensure_label(name, color, description)
    gh("pr", "edit", pr, "--repo", REPO, "--add-label", name)
    # Výsledek jako stav kontroly `risk-gate` na commitu. Ruleset na `main` ho může vyžadovat (viz README).
    gh("api", f"repos/{REPO}/statuses/{head_sha}", "-f", f"state={state}", "-f", "context=risk-gate",
       "-f", f"description={tier}: {decision}"[:140], check=False)

    if label == "low" and not draft:
        gh("pr", "merge", pr, "--repo", REPO, "--squash", "--delete-branch")
    elif label in ("medium", "high"):
        reviewers = ",".join(sorted(owners))
        gh("pr", "edit", pr, "--repo", REPO, "--add-reviewer", reviewers, check=False)


if __name__ == "__main__":
    main()
