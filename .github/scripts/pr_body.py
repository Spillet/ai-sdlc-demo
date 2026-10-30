"""Popis PR z výstupu agenta. Použití: pr_body.py ARTIFACT_DIR ISSUE"""
import sys
from pathlib import Path

from common import read_agent_result


def main():
    out, issue = Path(sys.argv[1]), sys.argv[2]
    agent = read_agent_result(out / "agent.json")
    tests_ok = (out / "tests_exit.txt").read_text().strip() == "0"
    tail = "\n".join((out / "tests.log").read_text(errors="replace").splitlines()[-8:])
    cost = agent.get("total_cost_usd")
    duration = agent.get("duration_ms")

    print(f"""Closes #{issue}

Toto PR připravil kódovací agent podle potvrzené specifikace v issue. O sloučení rozhoduje brána podle rizika (komentář níže), ne agent.

## Shrnutí od agenta

{(agent.get('result') or '').strip()[:3000]}

## Ověření

- Testy v jobu agenta: {'✅ prošly' if tests_ok else '❌ neprošly'} (informativní; brána bere výsledek z čistého jobu `verify` bez secrets)

```
{tail}
```

## Běh agenta

| Kroky | Cena | Doba |
|---|---|---|
| {agent.get('num_turns', '?')} | {f'{cost:.2f} USD' if cost is not None else '?'} | {f'{duration / 60000:.1f} min' if duration else '?'} |
""")


if __name__ == "__main__":
    main()
