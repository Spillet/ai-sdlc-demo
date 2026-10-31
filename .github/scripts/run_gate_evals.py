"""Regresní scénáře risk gate (evals/gate-cases.yml). Použití: run_gate_evals.py [CESTA]

Pro každý scénář spočítá risk tier nad uvedenou změnou v daném policy profile a porovná ho
s očekáváním. Sekce `calendar` ověří, který profil dá change calendar v daný okamžik.
Nevolá model ani GitHub; běží v CI při každé změně risk policy nebo risk gate.
"""
import sys
from datetime import datetime
from pathlib import Path

import yaml

from policy import calendar_profile, load_calendar, load_policy
from risk_gate import decide

REVIEWS = {
    "approve": {"verdict": "approve", "summary": "", "findings": []},
    "request_changes": {"verdict": "request_changes", "summary": "", "findings": []},
    "approve+medium": {"verdict": "approve", "summary": "", "findings": [{"severity": "medium"}]},
}


def main():
    root = Path(__file__).resolve().parents[2]
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "evals/gate-cases.yml"
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    policy = load_policy(root / "risk-policy.yml")
    calendar = load_calendar(root / "change-calendar.yml")
    failed = 0
    print("| Scénář | Lane | Profil | Očekáváno | Risk gate | Ověřeno během |\n|---|---|---|---|---|---|")
    for case in data["cases"]:
        changes = [{"paths": [p], "additions": a, "deletions": d, "binary": False} for p, a, d in case["changes"]]
        profile = case.get("profile", policy["default_profile"])
        tier, _, _ = decide(policy, changes, True, REVIEWS[case["review"]], (), profile, case.get("labels", []))
        ok = tier == case["tier"]
        failed += not ok
        print(f"| {case['name']} | {case['lane']} | {profile} | {case['tier']} | {tier}{'' if ok else ' ❌'} | {case['overeno']} |")
    moments = data.get("calendar") or []
    print("\n| Okamžik (UTC) | Očekávaný profil | Change calendar | Poznámka |\n|---|---|---|---|")
    for moment in moments:
        name, _ = calendar_profile(policy, calendar, datetime.fromisoformat(moment["at"].replace("Z", "+00:00")))
        ok = name == moment["profile"]
        failed += not ok
        print(f"| {moment['at']} | {moment['profile']} | {name}{'' if ok else ' ❌'} | {moment.get('note', '')} |")
    total = len(data["cases"]) + len(moments)
    print(f"\n{total - failed}/{total} scénářů odpovídá očekávání.")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
