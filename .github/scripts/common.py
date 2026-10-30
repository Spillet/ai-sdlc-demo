"""Sdílené pomůcky pro skripty pipeline. Volají jen `gh` CLI, žádné další závislosti."""
import json
import os
import re
import subprocess

SPEC_MARKER = "<!-- ai-spec -->"
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
    """Poslední potvrzovaná specifikace z komentářů, jinak text issue."""
    for comment in reversed(issue.get("comments", [])):
        if SPEC_MARKER in comment.get("body", ""):
            return comment["body"]
    return issue.get("body") or ""


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
