"""Zveřejní specifikaci od agenta jako komentář k issue a označí pruh. Použití: post_spec.py ISSUE AGENT_JSON"""
import json
import sys

from common import REPO, SPEC_MARKER, ensure_label, gh, parse_json_answer, read_agent_result

LANES = {
    "1-osobni": ("pruh:1-osobni", "0e8a16", "Osobní nástroj mimo produkci"),
    "2-produkt": ("pruh:2-produkt", "fbca04", "Produktová změna mimo citlivé oblasti"),
    "3-core": ("pruh:3-core", "b60205", "Core: navrhnout smí kdokoliv, sloučit jen vlastnický tým"),
}


def bullets(items):
    return "\n".join(f"- {i}" for i in items) if items else "- žádné"


def main():
    number, agent_path = sys.argv[1], sys.argv[2]
    spec = parse_json_answer(read_agent_result(agent_path).get("result", ""))
    lane = spec.get("pruh", "2-produkt")
    label, color, description = LANES.get(lane, LANES["2-produkt"])

    if lane == "3-core":
        next_step = ("Pruh 3 (core): štítek `ai:implement` může přidat kdokoliv, ale od ne-vlastníka "
                     "vznikne jen draft PR. Sloučit smí jen vlastnický tým.")
    else:
        next_step = ("Pokud specifikace sedí, přidej štítek `ai:implement` a agent připraví PR. "
                     "Pokud ne, oprav text issue a štítek `pozadavek` odeber a přidej znovu.")

    paths = json.dumps(spec.get("dotcene_casti", []), ensure_ascii=False).replace("-->", "")
    body = f"""{SPEC_MARKER}
<!-- ai-spec-paths: {paths} -->
## Specifikace k potvrzení

**{spec.get('shrnuti', '')}**

**Cíl:** {spec.get('cil', '')}

**Akceptační kritéria**
{bullets(spec.get('akceptacni_kriteria', []))}

**Dotčené části:** {', '.join(f'`{p}`' for p in spec.get('dotcene_casti', [])) or 'neurčeno'}

**Pruh:** `{lane}` – {spec.get('zduvodneni_pruhu', '')}

**Otevřené otázky**
{bullets(spec.get('otevrene_otazky', []))}

---
{next_step}
"""
    gh("issue", "comment", number, "--repo", REPO, "--body-file", "-", input_text=body)
    ensure_label(label, color, description)
    ensure_label("spec:k-potvrzeni", "c5def5", "Specifikace čeká na potvrzení zadavatelem")
    gh("issue", "edit", number, "--repo", REPO, "--add-label", f"{label},spec:k-potvrzeni")


if __name__ == "__main__":
    main()
