"""Kdo spouští agenta a kam změna míří. Použití: preflight.py ISSUE

Pruh 3 (core) nebo specifikace, která míří do cest s úrovní high, spuštěná někým jiným než
vlastníkem: agent běží, ale PR vznikne jako draft a brána ho jen okomentuje. Kdokoliv tedy
může v core navrhnout změnu, sloučit ji smí jen vlastnický tým.

Výstup `draft=true|false` jde do GITHUB_OUTPUT.
"""
import json
import os
import sys

from common import REPO, find_spec, gh, load_issue, spec_paths
from policy import classify, load_policy


def high_paths(paths, policy):
    """Cesty ze specifikace, které politika řadí do high. Adresář se bere i s obsahem."""
    hits = []
    for path in paths:
        probes = [path, path.rstrip("/") + "/x"]
        if any(classify(p, policy)["tier"] == "high" for p in probes):
            hits.append(path)
    return hits


def needs_owner(labels, paths, policy):
    reasons = []
    if "pruh:3-core" in labels:
        reasons.append("pruh 3 (core)")
    hits = high_paths(paths, policy)
    if hits:
        reasons.append("specifikace míří do chráněných cest: " + ", ".join(f"`{p}`" for p in hits))
    return reasons


def main():
    number = sys.argv[1]
    labels = json.loads(os.environ.get("LABELS", "[]"))
    sender, owner = os.environ["SENDER"], os.environ["OWNER"]
    policy = load_policy()
    paths = spec_paths(find_spec(load_issue(number)))

    reasons = needs_owner(labels, paths, policy)
    draft = bool(reasons) and sender != owner
    if draft:
        gh("issue", "comment", number, "--repo", REPO, "--body-file", "-", input_text=(
            f"Spuštění od @{sender}: {'; '.join(reasons)}. Agent připraví návrh jako **draft PR**. "
            "Brána ho jen okomentuje, sloučit ho smí jen vlastnický tým."))
    print(f"Důvody pro vlastníka: {reasons or 'žádné'}; spouští {sender}; draft={draft}")
    with open(os.environ.get("GITHUB_OUTPUT", os.devnull), "a", encoding="utf-8") as f:
        f.write(f"draft={'true' if draft else 'false'}\n")


if __name__ == "__main__":
    main()
