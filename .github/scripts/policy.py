"""Risk policy: načtení, zařazení cesty a výběr policy profile podle change calendar.

Sdílí ji risk gate (risk_gate.py), preflight a regresní scénáře. Žádné prahy tu nejsou natvrdo:
všechno je v risk-policy.yml a change-calendar.yml.
"""
import fnmatch
import unicodedata
from datetime import date, datetime, timezone
from pathlib import Path

# `blocked` je nad high: freeze nebo neprošlé ověření, merge nelze.
TIERS = ["low", "medium", "high", "blocked"]


def _yaml(path):
    import yaml  # jen tady, aby šly testy čistých funkcí spustit i bez PyYAML

    return yaml.safe_load(Path(path).read_text(encoding="utf-8"))


def load_policy(path="risk-policy.yml"):
    return _yaml(path)


def load_calendar(path="change-calendar.yml"):
    return _yaml(path)


def max_tier(*tiers):
    return max(tiers, key=TIERS.index)


def normalize(path):
    """Porovnání nezávislé na velikosti písmen a na tvaru diakritiky (NFC/NFD).

    Git na Linuxu je citlivý na velikost písmen, ale Windows a macOS ne. `NuGet.Config`
    a `nuget.config` jsou pro build totéž, proto se porovnává malými písmeny.
    """
    return unicodedata.normalize("NFC", path).lower()


def matches(path, patterns):
    norm = normalize(path)
    return any(fnmatch.fnmatchcase(norm, normalize(pattern)) for pattern in patterns)


def classify(path, policy):
    for rule in policy["rules"]:
        if matches(path, rule["paths"]):
            return rule
    return {"tier": policy["default_tier"], "owner": "default", "reason": "Bez pravidla, výchozí risk tier."}


def _day(value):
    return value if isinstance(value, date) else date.fromisoformat(str(value))


def validate_calendar(policy, calendar):
    """Seznam chyb v kalendáři (neznámý profil, konec před začátkem). Prázdný = v pořádku."""
    errors = []
    for window in calendar.get("windows") or []:
        name = window.get("name", "?")
        if window.get("profile") not in policy["profiles"]:
            errors.append(f"Okno „{name}“: neznámý profil `{window.get('profile')}`.")
        if _day(window["end"]) < _day(window["start"]):
            errors.append(f"Okno „{name}“: konec je před začátkem.")
    return errors


def calendar_profile(policy, calendar, now):
    """Profil podle change calendar v daný okamžik. Vrátí (název, okno nebo None).

    Okno platí celé dny `start`–`end` včetně v časovém pásmu kalendáře. Při překryvu vyhrává
    profil s vyšším `rank`; při shodě první okno v souboru.
    """
    from zoneinfo import ZoneInfo

    errors = validate_calendar(policy, calendar)
    if errors:
        raise ValueError("Chybný change calendar: " + " ".join(errors))
    if now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)
    today = now.astimezone(ZoneInfo(calendar.get("timezone", "Europe/Prague"))).date()
    active = [w for w in calendar.get("windows") or [] if _day(w["start"]) <= today <= _day(w["end"])]
    if not active:
        return policy["default_profile"], None
    best = active[0]
    for window in active[1:]:
        if policy["profiles"][window["profile"]]["rank"] > policy["profiles"][best["profile"]]["rank"]:
            best = window
    return best["profile"], best


def resolve_profile(policy, calendar, now=None, override=None, actor=None):
    """Aktivní profil a proč. Vrátí dict {name, source, reason, calendar_name}.

    `override` je ruční přepsání z gate-reevaluate.yml; kalendář se přesto spočítá, aby
    komentář risk gate ukázal, co by platilo bez přepsání.
    """
    now = now or datetime.now(timezone.utc)
    name, window = calendar_profile(policy, calendar, now)
    if window:
        why = f"change calendar: okno „{window['name']}“ ({_day(window['start'])} až {_day(window['end'])}, {calendar.get('timezone', 'Europe/Prague')})"
        source = "calendar"
    else:
        why = f"change calendar: mimo okna, výchozí profil `{name}`"
        source = "default"
    if override and override != "calendar":
        if override not in policy["profiles"]:
            raise ValueError(f"Neznámý profil `{override}`. Platné: {', '.join(policy['profiles'])}.")
        return {"name": override, "source": "override", "calendar_name": name,
                "reason": f"ruční přepsání, spustil @{actor or '?'} přes gate-reevaluate. Bez přepsání by platil `{name}` ({why})"}
    return {"name": name, "source": source, "calendar_name": name, "reason": why}
