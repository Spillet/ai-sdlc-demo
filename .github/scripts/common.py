"""Sdílené pomůcky pro skripty pipeline. Volají jen `gh` CLI, žádné další závislosti."""
import json
import os
import re
import subprocess

SPEC_MARKER = "<!-- ai-spec -->"
SPEC_PATHS = re.compile(r"<!-- ai-spec-paths: (\[.*\]) -->")
# Spec smí zapsat jen pipeline. `gh issue view --json comments` vrací login bota bez `[bot]`.
SPEC_AUTHORS = {"github-actions", "github-actions[bot]"}
REPO = os.environ.get("GITHUB_REPOSITORY", "")


def gh(*args, input_text=None, check=True):
    result = subprocess.run(
        ["gh", *args], input=input_text, text=True, capture_output=True, check=False
    )
    if check and result.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args)} selhalo: {result.stderr.strip()}")
    return result.stdout


def ensure_label(name, color="ededed", description=""):
    gh("label", "create", name, "--repo", REPO, "--color", color,
       "--description", description, "--force", check=False)


def load_issue(number):
    raw = gh("issue", "view", str(number), "--repo", REPO, "--json", "title,body,comments,labels")
    return json.loads(raw)


def find_spec(issue):
    """Poslední spec od pipeline (bota), jinak text issue.

    Komentář se značkou od kohokoli jiného se ignoruje: jinak by kdokoli s právem komentovat
    mohl po potvrzení podstrčit jinou spec.
    """
    for comment in reversed(issue.get("comments", [])):
        author = (comment.get("author") or {}).get("login", "")
        if author in SPEC_AUTHORS and SPEC_MARKER in comment.get("body", ""):
            return comment["body"]
    return issue.get("body") or ""


def spec_paths(spec):
    """Dotčené části ze strojově čitelné značky ve spec. Bez značky prázdný seznam."""
    match = SPEC_PATHS.search(spec or "")
    if not match:
        return []
    try:
        return [str(p) for p in json.loads(match.group(1))]
    except json.JSONDecodeError:
        return []


def parse_json_answer(text):
    """Agent vrací JSON, někdy obalený v ```json bloku. Vytáhne první objekt."""
    match = re.search(r"\{.*\}", text or "", re.DOTALL)
    if not match:
        raise ValueError("Odpověď agenta neobsahuje JSON.")
    return json.loads(match.group(0))


def read_agent_result(path):
    """Výstup `claude -p --output-format json`: text odpovědi a metriky běhu."""
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError):
        return {"result": "", "num_turns": None, "total_cost_usd": None, "duration_ms": None}
    return data
