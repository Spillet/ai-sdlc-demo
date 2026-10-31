"""Risk policy: načtení a zařazení cesty. Sdílí ji risk gate (risk_gate.py) a preflight."""
import fnmatch
import unicodedata
from pathlib import Path

TIERS = ["low", "medium", "high"]


def load_policy(path="risk-policy.yml"):
    import yaml  # jen tady, aby šly testy čistých funkcí spustit i bez PyYAML

    return yaml.safe_load(Path(path).read_text(encoding="utf-8"))


def max_tier(*tiers):
    return max(tiers, key=TIERS.index)


def normalize(path):
    """Porovnání nezávislé na velikosti písmen a na tvaru diakritiky (NFC/NFD).

    Git na Linuxu je citlivý na velikost písmen, ale Windows a macOS ne. `NuGet.Config`
    a `nuget.config` jsou pro build totéž, proto se porovnává malými písmeny.
    """
    return unicodedata.normalize("NFC", path).lower()


def classify(path, policy):
    norm = normalize(path)
    for rule in policy["rules"]:
        if any(fnmatch.fnmatchcase(norm, normalize(pattern)) for pattern in rule["paths"]):
            return rule
    return {"tier": policy["default_tier"], "owner": "default", "reason": "Bez pravidla, výchozí úroveň."}
