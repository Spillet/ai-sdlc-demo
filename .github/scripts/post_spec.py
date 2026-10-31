"""Zveřejní spec od intake agenta jako komentář k issue a označí lane. Použití: post_spec.py ISSUE AGENT_JSON"""
import json
import sys

from common import REPO, SPEC_MARKER, ensure_label, gh, parse_json_answer, read_agent_result

LANES = {
    "personal": ("lane:personal", "0e8a16", "Osobní nástroj mimo produkci"),
    "product": ("lane:product", "fbca04", "Produktová změna mimo citlivé oblasti"),
    "core": ("lane:core", "b60205", "Core: navrhnout smí kdokoliv, merge jen owning team"),
}
# Hodnoty z doby před slovníkem termínů (starší odpovědi modelu).
LEGACY = {"1-osobni": "personal", "2-produkt": "product", "3-core": "core"}
SPEC_PENDING = ("spec:pending", "c5def5", "Spec čeká na potvrzení zadavatelem")


def bullets(items):
    return "\n".join(f"- {i}" for i in items) if items else "- žádné"


def main():
    number, agent_path = sys.argv[1], sys.argv[2]
    spec = parse_json_answer(read_agent_result(agent_path).get("result", ""))
    lane = spec.get("lane") or spec.get("pruh") or "product"
    lane = LEGACY.get(lane, lane)
    if lane not in LANES:
        lane = "product"
    label, color, description = LANES[lane]

    if lane == "core":
        next_step = ("Lane core: štítek `ai:implement` může přidat kdokoliv, ale od ne-vlastníka "
                     "vznikne jen draft PR. Merge smí jen owning team.")
    else:
        next_step = ("Pokud spec sedí, přidej štítek `ai:implement` a agent připraví PR. "
                     "Pokud ne, oprav text issue a štítek `request` odeber a přidej znovu.")

    paths = json.dumps(spec.get("dotcene_casti", []), ensure_ascii=False).replace("-->", "")
    body = f"""{SPEC_MARKER}
<!-- ai-spec-paths: {paths} -->
## Spec k potvrzení

**{spec.get('shrnuti', '')}**

**Cíl:** {spec.get('cil', '')}

**Akceptační kritéria**
{bullets(spec.get('akceptacni_kriteria', []))}

**Dotčené části:** {', '.join(f'`{p}`' for p in spec.get('dotcene_casti', [])) or 'neurčeno'}

**Lane:** `{lane}` – {spec.get('zduvodneni_lane') or spec.get('zduvodneni_pruhu', '')}

**Otevřené otázky**
{bullets(spec.get('otevrene_otazky', []))}

---
{next_step}
"""
    gh("issue", "comment", number, "--repo", REPO, "--body-file", "-", input_text=body)
    ensure_label(label, color, description)
    ensure_label(*SPEC_PENDING)
    gh("issue", "edit", number, "--repo", REPO, "--add-label", f"{label},{SPEC_PENDING[0]}")


if __name__ == "__main__":
    main()
