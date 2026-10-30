"""Brána podle rizika. Rozhodne, kdo smí PR sloučit, a rozhodnutí zdůvodní.

Použití: risk_gate.py PR ARTIFACT_DIR [--dry-run]

Rozhoduje deterministicky z rizikové politiky a signálů (změněné cesty, velikost změny,
testy, verdikt AI review). Model tu nic nerozhoduje, jen dodává verdikt review jako jeden ze signálů.
"""
import fnmatch
import os
import re
import sys
from pathlib import Path

import yaml

from common import REPO, ensure_label, gh, parse_json_answer, read_agent_result

TIERS = ["low", "medium", "high"]
LABELS = {
    "low": ("riziko:nizke", "0e8a16", "Sloučí se automaticky po testech a review"),
    "medium": ("riziko:stredni", "fbca04", "Sloučení schvaluje člověk"),
    "high": ("riziko:vysoke", "b60205", "Měnit smí jen vlastnický tým"),
    "blocked": ("blokovano", "000000", "Neprošly testy, nelze sloučit"),
}


def max_tier(*tiers):
    return max(tiers, key=TIERS.index)


def parse_patch(text):
    """Změněné soubory a počet změněných řádků z unified diffu."""
    files, lines = [], 0
    for line in text.splitlines():
        match = re.match(r"^diff --git a/(\S+) b/(\S+)", line)
        if match:
            files.append(match.group(2))
        elif line.startswith(("+", "-")) and not line.startswith(("+++", "---")):
            lines += 1
    return files, lines


def classify(path, policy):
    for rule in policy["rules"]:
        if any(fnmatch.fnmatch(path, pattern) for pattern in rule["paths"]):
            return rule
    return {"tier": policy["default_tier"], "owner": "default", "reason": "Bez pravidla, výchozí úroveň."}


def load_review(out):
    agent = read_agent_result(out / "review.json")
    try:
        return parse_json_answer(agent.get("result", ""))
    except (ValueError, TypeError):
        return {"verdict": "request_changes", "summary": "Review se nepodařilo načíst, brána ho bere jako nesouhlas.",
                "findings": []}


def decide(policy, files, changed_lines, tests_ok, review):
    """Vrátí (úroveň, vlastníci, řádky zdůvodnění)."""
    tier, owners, reasons = "low", set(), []

    for path in files:
        rule = classify(path, policy)
        tier = max_tier(tier, rule["tier"])
        owners.add(policy["owners"][rule["owner"]])
        reasons.append(("cesta", f"`{path}`", rule["tier"], rule["reason"]))

    limits = policy["limits"]
    if changed_lines > limits["medium_max_changed_lines"]:
        tier = "high"
        reasons.append(("velikost", f"{changed_lines} řádků", "high", "Nad limitem pro kontrolu člověkem."))
    elif changed_lines > limits["low_max_changed_lines"]:
        tier = max_tier(tier, "medium")
        reasons.append(("velikost", f"{changed_lines} řádků", "medium", "Nad limitem pro automatické sloučení."))
    else:
        reasons.append(("velikost", f"{changed_lines} řádků", "low", "V limitu."))

    touches_src = any(p.startswith("src/") for p in files)
    touches_tests = any(p.startswith("tests/") for p in files)
    if policy["signals"]["require_tests_for_src"] and touches_src and not touches_tests:
        tier = max_tier(tier, "medium")
        reasons.append(("testy", "kód bez nového testu", "medium", "Změna chování bez testu."))

    if review.get("verdict") != "approve":
        floor = policy["signals"]["review_request_changes_min_tier"]
        tier = max_tier(tier, floor)
        reasons.append(("AI review", "nesouhlasí", floor, review.get("summary", "")))
    else:
        reasons.append(("AI review", "souhlasí", "low", review.get("summary", "")))

    reasons.append(("testy", "prošly" if tests_ok else "NEPROŠLY", "low" if tests_ok else "blocked",
                    "Deterministické ověření: dotnet test."))
    return tier, owners, reasons


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


def main():
    pr, out = sys.argv[1], Path(sys.argv[2])
    dry_run = "--dry-run" in sys.argv
    policy = yaml.safe_load(Path("risk-policy.yml").read_text(encoding="utf-8"))
    files, changed_lines = parse_patch((out / "change.patch").read_text(errors="replace"))
    tests_ok = (out / "tests_exit.txt").read_text().strip() == "0"
    review = load_review(out)

    tier, owners, reasons = decide(policy, files, changed_lines, tests_ok, review)
    if not tests_ok:
        decision, label = "zablokováno, neprošly testy", "blocked"
    elif tier == "low":
        decision, label = "sloučeno automaticky", "low"
    elif tier == "medium":
        decision, label = "čeká na schválení člověkem", "medium"
    else:
        decision, label = "jen vlastnický tým", "high"

    comment = render(tier if tests_ok else "blocked", decision, reasons, review)
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

    if label == "low":
        gh("pr", "merge", pr, "--repo", REPO, "--squash", "--delete-branch")
    elif label in ("medium", "high"):
        reviewers = ",".join(sorted(owners))
        gh("pr", "edit", pr, "--repo", REPO, "--add-reviewer", reviewers, check=False)


if __name__ == "__main__":
    main()
