"""Připravená změna pro nácvik dema (demo-prepare.yml), bez modelu.

Použití:
  demo_change.py change RUN_NUMBER   zapíše šablonu a test do pracovního stromu; na stdout key=, cls= (pro GITHUB_OUTPUT)
  demo_change.py review              připravený záznam review (obal jako výstup `claude -p --output-format json`)
  demo_change.py body KEY            popis PR
"""
import json
import re
import sys
from pathlib import Path
from string import Template

TEMPLATES = Path("src/Claims.Api/Content/Templates")
TESTS = Path("tests/Claims.Tests/Content")
KEY = re.compile(r"^[a-z0-9-]+$")
CLASS = re.compile(r"^[A-Z][A-Za-z0-9]*$")
PLACEHOLDERS = {"orderNumber", "claimNumber", "resolveBy"}
EXISTING_KEY = re.compile(r'Key\s*=>\s*"([^"]+)"')

TEMPLATE_CS = Template('''namespace Claims.Api.Content.Templates;

public sealed class $cls : IMessageTemplate
{
    public string Key => "$key";
    public string Subject => "$subject";
    public string Body =>
        "$body";
}
''')

TEST_CS = Template('''using Claims.Api.Content;

namespace Claims.Tests.Content;

public class ${cls}Tests
{
    [Fact]
    public void Template_is_registered_and_fills_placeholders()
    {
        var template = MessageCatalog.Find("$key");
        Assert.NotNull(template);

        var message = MessageCatalog.Render(template, new Dictionary<string, string>
        {
            ["orderNumber"] = "2026-1001",
            ["claimNumber"] = "R-17",
            ["resolveBy"] = "30. 11. 2026",
        });

        Assert.Contains("R-17", message.Subject + message.Body);
        Assert.DoesNotContain("{", message.Subject + message.Body);
    }
}
''')


def validate(message):
    """Seznam chyb jedné připravené zprávy. Prázdný = v pořádku."""
    errors = []
    if not KEY.match(message.get("key", "")):
        errors.append(f"klíč `{message.get('key')}` smí mít jen a-z, 0-9 a pomlčku")
    if not CLASS.match(message.get("class", "")):
        errors.append(f"třída `{message.get('class')}` není platný název C# třídy")
    text = message.get("subject", "") + message.get("body", "")
    used = set(re.findall(r"\{(\w+)\}", text))
    if used - PLACEHOLDERS:
        errors.append(f"neznámé zástupné symboly: {sorted(used - PLACEHOLDERS)}")
    if "claimNumber" not in used:
        errors.append("chybí {claimNumber}")
    if any(c in text for c in '"\\\n'):
        errors.append("text nesmí obsahovat uvozovky, zpětné lomítko ani nový řádek")
    return errors


def existing_keys(root):
    keys = set()
    for path in (root / TEMPLATES).glob("*.cs"):
        keys.update(EXISTING_KEY.findall(path.read_text(encoding="utf-8")))
    return keys


def pick(messages, root, run):
    """První zpráva, která v main ještě není; jinak první s číslem běhu."""
    keys = existing_keys(root)
    for message in messages:
        if message["key"] not in keys and not (root / TEMPLATES / f"{message['class']}.cs").exists():
            return dict(message)
    first = dict(messages[0])
    first["key"], first["class"] = f"{first['key']}-{run}", f"{first['class']}R{run}"
    return first


def build(message):
    """{cesta: obsah} pro šablonu a její test."""
    errors = validate(message)
    if errors:
        raise ValueError(f"Připravená zpráva `{message.get('key')}`: " + "; ".join(errors))
    return {
        TEMPLATES / f"{message['class']}.cs": TEMPLATE_CS.substitute(cls=message["class"], key=message["key"],
                                                                     subject=message["subject"], body=message["body"]),
        TESTS / f"{message['class']}Tests.cs": TEST_CS.substitute(cls=message["class"], key=message["key"]),
    }


def load_messages(root):
    import yaml

    return yaml.safe_load((root / "demo/messages.yml").read_text(encoding="utf-8"))["messages"]


def prepared_review():
    review = {
        "verdict": "approve",
        "summary": ("Připravená změna z demo/messages.yml: nová šablona zprávy a její test. AI review v demo-prepare "
                    "neběží (bez modelu, zdarma, opakovatelné); obsah změny je v main a prošel kontrolou při commitu."),
        "findings": [],
    }
    return {"prepared_by": "demo-prepare", "result": json.dumps(review, ensure_ascii=False),
            "num_turns": 0, "total_cost_usd": 0, "duration_ms": 0}


def body(key):
    return f"""Připravená změna pro nácvik dema: nová šablona zákaznické zprávy `{key}` v `src/Claims.Api/Content/Templates/` a její test.

PR založil workflow `demo-prepare` bez modelu z [`demo/messages.yml`](../blob/main/demo/messages.yml). O merge rozhoduje risk gate (komentář níže) podle aktivního policy profile:

- v profilu **peak** (Black Friday sezóna) jde každá změna kódu ke schválení člověku: 🟡,
- po `gate-reevaluate` s `profile=normal` je to malá změna v bezpečné oblasti `Content/` s testem: 🟢 auto-merge.

AI review tu neběží. Risk gate dostane připravený záznam review a v komentáři to uvádí (`accept_prepared_review` v `risk-policy.yml`).
"""


def main():
    root = Path.cwd()
    mode = sys.argv[1]
    if mode == "change":
        message = pick(load_messages(root), root, sys.argv[2])
        for path, text in build(message).items():
            (root / path).parent.mkdir(parents=True, exist_ok=True)
            (root / path).write_text(text, encoding="utf-8")
        print(f"key={message['key']}\ncls={message['class']}")
    elif mode == "review":
        print(json.dumps(prepared_review(), ensure_ascii=False))
    elif mode == "body":
        print(body(sys.argv[2]))
    else:
        raise SystemExit(f"Neznámý režim: {mode}")


if __name__ == "__main__":
    main()
