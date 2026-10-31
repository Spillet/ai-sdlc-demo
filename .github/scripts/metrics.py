"""Souhrn běhů pipeline z PR, které založil agent. Použití: metrics.py [--json SOUBOR]

Bez argumentu čte PR přes `gh pr list`. S `--json` čte uložený výstup téhož příkazu
(`gh pr list --state all --json number,title,labels,createdAt,mergedAt,closedAt,isDraft,body,headRefName`).
Počítá: PR podle risk tier, podíl PR sloučených přes auto-merge, dobu do sloučení a cenu agenta z popisu PR.
Cena z popisu PR je jen implementace; intake a review mají cenu v artefaktech běhů.
"""
import json
import re
import sys
from datetime import datetime

from common import REPO, gh

# Nové štítky podle slovníku termínů a staré české štítky na PR, které vznikly před přejmenováním.
TIERS = {"risk:low": "🟢 low", "risk:medium": "🟡 medium", "risk:high": "🔴 high", "blocked": "⛔ blocked",
         "riziko:nizke": "🟢 low", "riziko:stredni": "🟡 medium", "riziko:vysoke": "🔴 high", "blokovano": "⛔ blocked"}
COST = re.compile(r"\|\s*(\d+)\s*\|\s*([\d.]+) USD\s*\|\s*([\d.]+) min\s*\|")


def load():
    if "--json" in sys.argv:
        with open(sys.argv[sys.argv.index("--json") + 1], encoding="utf-8") as f:
            return json.load(f)
    raw = gh("pr", "list", "--repo", REPO, "--state", "all", "--limit", "200", "--json",
             "number,title,labels,createdAt,mergedAt,closedAt,isDraft,body,headRefName")
    return json.loads(raw)


def hours(start, end):
    parse = lambda s: datetime.fromisoformat(s.replace("Z", "+00:00"))
    return (parse(end) - parse(start)).total_seconds() / 3600


def summarize(prs):
    prs = [p for p in prs if p.get("headRefName", "").startswith("ai/issue-")]
    rows, costs, minutes = [], [], []
    by_tier = {}
    for pr in prs:
        names = {label["name"] for label in pr.get("labels", [])}
        tier = next((TIERS[n] for n in TIERS if n in names), "bez rozhodnutí risk gate")
        by_tier[tier] = by_tier.get(tier, 0) + 1
        match = COST.search(pr.get("body") or "")
        if match:
            costs.append(float(match.group(2)))
            minutes.append(float(match.group(3)))
        state = "sloučeno" if pr.get("mergedAt") else ("zavřeno" if pr.get("closedAt") else "otevřené")
        if pr.get("isDraft"):
            state += ", draft"
        rows.append(f"| #{pr['number']} | {pr['title']} | {tier} | {state} | "
                    f"{match.group(2) + ' USD' if match else '?'} |")
    merged = [p for p in prs if p.get("mergedAt")]
    lines = ["| PR | Název | Risk tier | Stav | Cena agenta |", "|---|---|---|---|---|", *sorted(rows)]
    lines.append("")
    lines.append(f"- PR od agenta: {len(prs)}; podle risk tier: "
                 + ", ".join(f"{k} {v}" for k, v in sorted(by_tier.items())))
    if prs:
        lines.append(f"- Sloučeno (auto-merge): {len(merged)} z {len(prs)} ({100 * len(merged) / len(prs):.0f} %)")
    if merged:
        lines.append(f"- Doba od PR do merge (medián): "
                     f"{sorted(hours(p['createdAt'], p['mergedAt']) * 60 for p in merged)[len(merged) // 2]:.1f} min")
    if costs:
        lines.append(f"- Cena implementace: celkem {sum(costs):.2f} USD, průměr {sum(costs) / len(costs):.2f} USD na PR, "
                     f"průměrná doba agenta {sum(minutes) / len(minutes):.1f} min")
    return "\n".join(lines)


if __name__ == "__main__":
    print(summarize(load()))
