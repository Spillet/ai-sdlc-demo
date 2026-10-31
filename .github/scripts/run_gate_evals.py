"""Regresní scénáře risk gate (evals/gate-cases.yml). Použití: run_gate_evals.py [CESTA]

Pro každý scénář spočítá risk tier nad uvedenou změnou a porovná ji s očekáváním.
Nevolá model ani GitHub; běží v CI při každé změně risk policy nebo risk gate.
"""
import sys
from pathlib import Path

import yaml

from policy import load_policy
from risk_gate import decide

REVIEWS = {
    "approve": {"verdict": "approve", "summary": "", "findings": []},
    "request_changes": {"verdict": "request_changes", "summary": "", "findings": []},
    "approve+medium": {"verdict": "approve", "summary": "", "findings": [{"severity": "medium"}]},
}


def main():
    root = Path(__file__).resolve().parents[2]
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "evals/gate-cases.yml"
    cases = yaml.safe_load(path.read_text(encoding="utf-8"))["cases"]
    policy = load_policy(root / "risk-policy.yml")
    failed = 0
    print("| Scénář | Lane | Očekáváno | Risk gate | Ověřeno během |\n|---|---|---|---|---|")
    for case in cases:
        changes = [{"paths": [p], "additions": a, "deletions": d, "binary": False} for p, a, d in case["changes"]]
        tier, _, _ = decide(policy, changes, True, REVIEWS[case["review"]])
        ok = tier == case["tier"]
        failed += not ok
        print(f"| {case['name']} | {case['lane']} | {case['tier']} | {tier}{'' if ok else ' ❌'} | {case['overeno']} |")
    print(f"\n{len(cases) - failed}/{len(cases)} scénářů odpovídá očekávání.")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
