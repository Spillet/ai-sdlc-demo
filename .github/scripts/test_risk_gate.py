"""Testy risk gate. Spuštění: python3 -m unittest discover -s .github/scripts -p 'test_*.py'

Pokrývají nálezy z oponentury: cesty s mezerou, diakritikou a přejmenováním, fail-closed při
nesouladu, chráněný kontext agentů, testy a build v risk policy, nálezy AI review a draft z preflightu.
A policy profiles s change calendar: hranice oken v Europe/Prague, překryv, hotfix ve freeze,
ruční přepsání a to, že profil risk tier nikdy nesníží. A auditní stopu v komentáři: záměr,
kdo spustil agenta a verze pravidel.
"""
import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

from datetime import datetime, timezone

import yaml

from common import find_spec, spec_paths
from policy import TIERS, calendar_profile, classify, load_calendar, load_policy, resolve_profile, validate_calendar
from preflight import high_paths, needs_owner
from demo_change import build, load_messages, pick, prepared_review, validate
from risk_gate import (UNRECOGNIZED, count_patch, decide, decode_history, integrity, intent_of, load_review, outcome,
                       parse_numstat_z, render, rules_version)

ROOT = Path(__file__).resolve().parents[2]
POLICY = load_policy(ROOT / "risk-policy.yml")
CALENDAR = load_calendar(ROOT / "change-calendar.yml")
APPROVE = {"verdict": "approve", "summary": "ok", "findings": []}


def git(cwd, *args):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, check=True).stdout.decode("utf-8")


def real_diff(files_before, files_after, renames=()):
    """Skutečný `git diff` v dočasném repu. Vrátí (numstat -z, patch)."""
    with tempfile.TemporaryDirectory() as tmp:
        git(tmp, "init", "-q")
        git(tmp, "config", "user.email", "t@t")
        git(tmp, "config", "user.name", "t")
        for path, text in files_before.items():
            (Path(tmp) / path).parent.mkdir(parents=True, exist_ok=True)
            (Path(tmp) / path).write_text(text, encoding="utf-8")
        git(tmp, "add", "-A")
        git(tmp, "commit", "-qm", "base", "--allow-empty")
        for old, new in renames:
            (Path(tmp) / new).parent.mkdir(parents=True, exist_ok=True)
            git(tmp, "mv", old, new)
        for path, text in files_after.items():
            (Path(tmp) / path).parent.mkdir(parents=True, exist_ok=True)
            (Path(tmp) / path).write_text(text, encoding="utf-8")
        git(tmp, "add", "-A")
        numstat = git(tmp, "diff", "--cached", "--numstat", "-z", "-M")
        patch = git(tmp, "-c", "core.quotePath=true", "diff", "--cached")
        return numstat, patch


class ParseChanges(unittest.TestCase):
    def test_diacritics_space_and_rename_are_visible(self):
        numstat, patch = real_diff(
            {"docs/navod.md": "a\nb\nc\nd\ne\n"},
            {"src/Claims.Api/Refunds/Vrácení.cs": "class Vraceni {}\n",
             "src/Claims.Api/Refunds/Nová třída.cs": "class Nova {}\n"},
            renames=[("docs/navod.md", "src/Claims.Api/Refunds/navod.cs")],
        )
        # Git cesty s diakritikou v hlavičce uvozuje a escapuje. Původní parser je proto neviděl.
        headers = [line for line in patch.splitlines() if line.startswith("diff --git")]
        self.assertTrue(any('"' in h for h in headers))
        changes = parse_numstat_z(numstat)
        paths = sorted(p for c in changes for p in c["paths"])
        self.assertEqual(paths, sorted([
            "docs/navod.md", "src/Claims.Api/Refunds/navod.cs",
            "src/Claims.Api/Refunds/Nová třída.cs", "src/Claims.Api/Refunds/Vrácení.cs",
        ]))
        files, lines = count_patch(patch)
        self.assertEqual(files, len(changes))
        tier, _, _ = decide(POLICY, changes, True, APPROVE, integrity(changes, {"patch": files}, lines))
        self.assertEqual(tier, "high")

    def test_rename_out_of_refunds_counts_as_refunds_change(self):
        numstat, _ = real_diff({"src/Claims.Api/Refunds/A.cs": "x\ny\nz\n"}, {},
                               renames=[("src/Claims.Api/Refunds/A.cs", "docs/A.md")])
        changes = parse_numstat_z(numstat)
        self.assertEqual(len(changes), 1)
        self.assertEqual(decide(POLICY, changes, True, APPROVE)[0], "high")

    def test_binary_file(self):
        changes = parse_numstat_z("-\t-\tdocs/obr.png\0")
        self.assertEqual(changes[0]["paths"], ["docs/obr.png"])
        self.assertTrue(changes[0]["binary"])


class FailClosed(unittest.TestCase):
    def test_empty_list_with_changed_lines_is_high(self):
        problems = integrity([], {"patch": 0}, patch_lines=12)
        tier, _, reasons = decide(POLICY, [], True, APPROVE, problems)
        self.assertEqual(tier, "high")
        self.assertTrue(any(UNRECOGNIZED in why for *_, why in reasons))

    def test_count_mismatch_is_high(self):
        changes = parse_numstat_z("1\t0\tdocs/a.md\0")
        problems = integrity(changes, {"patch": 2, "PR": 1}, 1)
        self.assertEqual(len(problems), 1)
        self.assertEqual(decide(POLICY, changes, True, APPROVE, problems)[0], "high")

    def test_consistent_sources_pass(self):
        changes = parse_numstat_z("1\t0\tdocs/a.md\0")
        self.assertEqual(integrity(changes, {"patch": 1, "PR": 1, "nezjištěno": None}, 1), [])


class Policy(unittest.TestCase):
    PROTECTED = ["CLAUDE.md", "docs/CLAUDE.md", "AGENTS.md", "tests/AGENTS.md", "CLAUDE.local.md",
                 ".claude/settings.json", ".mcp.json", ".github/workflows/x.yml", ".github/scripts/risk_gate.py",
                 "CODEOWNERS", "risk-policy.yml", "change-calendar.yml", "src/.claude/hooks.json", "docs/claude.md"]
    FREE = ["docs/faq-reklamace.md", "src/Claims.Api/Program.cs", "tests/Claims.Tests/NewTests.cs",
            "README.md", "docs/github-navod.md", "src/Claims.Api/Content/Templates/X.cs", "demo/messages.yml"]

    def test_protected_paths_are_high(self):
        for path in self.PROTECTED:
            self.assertEqual(classify(path, POLICY)["tier"], "high", path)

    def test_workflow_guard_matches_policy(self):
        guards = {}
        for path in sorted((ROOT / ".github/workflows").glob("*.yml")):
            env = yaml.safe_load(path.read_text(encoding="utf-8")).get("env") or {}
            if "PROTECTED_PATHS" in env:
                guards[path.name] = env["PROTECTED_PATHS"]
        self.assertIn("agent-pipeline.yml", guards)
        self.assertEqual(len(set(guards.values())), 1, f"guardrails se ve workflow liší: {guards}")
        guard = re.compile(guards["agent-pipeline.yml"], re.IGNORECASE)
        for path in self.PROTECTED:
            self.assertTrue(guard.search(path), f"guardrail nepokrývá {path}")
        for path in self.FREE:
            self.assertFalse(guard.search(path), f"guardrail zbytečně blokuje {path}")

    def test_tests_inherit_tier_and_build_files_are_medium(self):
        expected = {
            "tests/Claims.Tests/RefundCalculatorTests.cs": "high",
            "tests/Claims.Tests/ClaimPolicyTests.cs": "medium",
            "tests/Claims.Tests/Claims.Tests.csproj": "medium",
            "Directory.Build.props": "medium",
            "build/custom.targets": "medium",
            "NuGet.Config": "medium",
            "global.json": "medium",
            "db/procedures/usp_ClaimRefund.sql": "high",
            "tests/Claims.Tests/OtherTests.cs": "low",
            "src/Claims.Api/Refunds/Vrácení.cs": "high",
            "src/Claims.Api/Content/Templates/Nova.cs": "low",
            "src/Claims.Api/Program.cs": "medium",
            "src/Claims.Api/Shipping/Nova.cs": "medium",
        }
        for path, tier in expected.items():
            self.assertEqual(classify(path, POLICY)["tier"], tier, path)


class Signals(unittest.TestCase):
    def test_docs_only_is_low(self):  # scénář PR #6
        changes = parse_numstat_z("30\t0\tdocs/faq-reklamace.md\0")
        self.assertEqual(decide(POLICY, changes, True, APPROVE)[0], "low")

    def test_serious_finding_raises_even_on_approve(self):  # scénář PR #2
        review = {"verdict": "approve", "summary": "ok",
                  "findings": [{"severity": "medium", "file": "src/Claims.Api/Program.cs", "issue": "endpoint bez testu"}]}
        changes = parse_numstat_z("5\t0\tdocs/a.md\0")
        self.assertEqual(decide(POLICY, changes, True, review)[0], "medium")

    def test_low_finding_does_not_raise(self):
        review = {"verdict": "approve", "summary": "ok", "findings": [{"severity": "low"}]}
        changes = parse_numstat_z("5\t0\tdocs/a.md\0")
        self.assertEqual(decide(POLICY, changes, True, review)[0], "low")

    def test_removed_test_lines_raise_to_medium(self):
        changes = parse_numstat_z("0\t4\ttests/Claims.Tests/OtherTests.cs\0")
        self.assertEqual(decide(POLICY, changes, True, APPROVE)[0], "medium")

    def test_src_without_tests_is_medium(self):
        changes = parse_numstat_z("3\t1\tsrc/Claims.Api/Program.cs\0")
        self.assertEqual(decide(POLICY, changes, True, APPROVE)[0], "medium")

    def test_outcome(self):
        self.assertEqual(outcome("low", True, False)[1:], ("low", "success"))
        self.assertEqual(outcome("low", True, True)[2], "failure")  # draft se nikdy nesloučí
        self.assertEqual(outcome("low", False, False)[1], "blocked")
        self.assertEqual(outcome("medium", True, False)[2], "failure")
        self.assertEqual(outcome("blocked", True, False, "freeze")[1:], ("blocked", "failure"))
        self.assertIn("2×", outcome("high", True, False, "peak", {"high": 2})[0])


class SpecAndPreflight(unittest.TestCase):
    def test_find_spec_ignores_comments_from_people(self):
        issue = {"body": "původní", "comments": [
            {"author": {"login": "github-actions"}, "body": "<!-- ai-spec -->\nod bota"},
            {"author": {"login": "nekdo"}, "body": "<!-- ai-spec -->\npodvržená"},
        ]}
        self.assertIn("od bota", find_spec(issue))

    def test_spec_paths(self):
        spec = '<!-- ai-spec -->\n<!-- ai-spec-paths: ["src/Claims.Api/Refunds/", "docs/x.md"] -->\n'
        self.assertEqual(spec_paths(spec), ["src/Claims.Api/Refunds/", "docs/x.md"])
        self.assertEqual(spec_paths("bez značky"), [])

    def test_high_paths_from_spec_need_owner_even_in_lane_2(self):
        self.assertEqual(high_paths(["src/Claims.Api/Refunds/", "docs/a.md"], POLICY), ["src/Claims.Api/Refunds/"])
        self.assertTrue(needs_owner(["lane:product"], ["src/Claims.Api/Refunds/X.cs"], POLICY))
        self.assertFalse(needs_owner(["lane:product"], ["docs/a.md"], POLICY))
        self.assertTrue(needs_owner(["lane:core"], [], POLICY))
        self.assertTrue(needs_owner(["pruh:3-core"], [], POLICY))  # starý štítek platí dál



def changes_of(*rows):
    return [{"paths": [p], "additions": a, "deletions": d, "binary": False} for p, a, d in rows]


CONTENT = changes_of(("src/Claims.Api/Content/Templates/PickupTemplate.cs", 10, 0),
                     ("tests/Claims.Tests/Content/PickupTemplateTests.cs", 22, 0))


def tier_in(profile, changes, labels=(), review=APPROVE):
    return decide(POLICY, changes, True, review, (), profile, labels)[0]


class Profiles(unittest.TestCase):
    def test_content_change_by_profile(self):  # scénář dema
        self.assertEqual(tier_in("normal", CONTENT), "low")
        self.assertEqual(tier_in("peak", CONTENT), "medium")
        self.assertEqual(tier_in("freeze", CONTENT), "blocked")

    def test_default_profile_is_normal(self):
        self.assertEqual(decide(POLICY, CONTENT, True, APPROVE)[0], "low")

    def test_normal_code_outside_safe_area(self):
        domain = changes_of(("src/Claims.Api/Domain/ClaimPolicy.cs", 5, 1), ("tests/Claims.Tests/OtherTests.cs", 10, 0))
        refunds = changes_of(("src/Claims.Api/Refunds/RefundCalculator.cs", 2, 1), ("tests/Claims.Tests/OtherTests.cs", 10, 0))
        program = changes_of(("src/Claims.Api/Program.cs", 2, 0), ("tests/Claims.Tests/OtherTests.cs", 10, 0))
        self.assertEqual(tier_in("normal", domain), "medium")
        self.assertEqual(tier_in("normal", refunds), "high")
        self.assertEqual(tier_in("normal", program), "medium")

    def test_normal_content_needs_tests_review_and_size(self):
        no_test = changes_of(("src/Claims.Api/Content/Templates/PickupTemplate.cs", 10, 0))
        big = changes_of(("src/Claims.Api/Content/Templates/PickupTemplate.cs", 140, 0),
                         ("tests/Claims.Tests/Content/PickupTemplateTests.cs", 20, 0))
        finding = {"verdict": "approve", "summary": "", "findings": [{"severity": "medium"}]}
        self.assertEqual(tier_in("normal", no_test), "medium")
        self.assertEqual(tier_in("normal", big), "medium")
        self.assertEqual(tier_in("normal", CONTENT, review=finding), "medium")
        self.assertEqual(tier_in("normal", CONTENT, review={"verdict": "request_changes", "findings": []}), "medium")

    def test_peak_auto_merge_only_small_docs(self):
        self.assertEqual(tier_in("peak", changes_of(("docs/faq-reklamace.md", 30, 0))), "low")
        self.assertEqual(tier_in("peak", changes_of(("docs/faq-reklamace.md", 45, 10))), "medium")  # limit 50
        self.assertEqual(tier_in("peak", changes_of(("README.md", 3, 0))), "medium")
        self.assertEqual(tier_in("peak", changes_of(("tests/Claims.Tests/OtherTests.cs", 5, 0))), "medium")

    def test_peak_high_needs_two_approvals(self):
        refunds = changes_of(("src/Claims.Api/Refunds/RefundCalculator.cs", 1, 1), ("tests/Claims.Tests/OtherTests.cs", 5, 0))
        self.assertEqual(tier_in("peak", refunds), "high")
        self.assertEqual(POLICY["profiles"]["peak"]["approvals"]["high"], 2)
        self.assertIn("2×", outcome("high", True, False, "peak", POLICY["profiles"]["peak"]["approvals"])[0])

    def test_freeze_blocks_everything_except_hotfix(self):
        docs = changes_of(("docs/faq-reklamace.md", 3, 0))
        self.assertEqual(tier_in("freeze", docs), "blocked")
        self.assertEqual(tier_in("freeze", docs, labels=["hotfix"]), "high")
        self.assertEqual(tier_in("freeze", CONTENT, labels=["hotfix", "jiny"]), "high")
        tier, owners, _ = decide(POLICY, docs, True, APPROVE, (), "freeze", ["hotfix"])
        self.assertIn(POLICY["owners"]["default"], owners)
        self.assertEqual(outcome(tier, True, False, "freeze")[1], "high")
        self.assertEqual(outcome(tier, False, False, "freeze")[1], "blocked")  # hotfix s neprošlými testy ne

    def test_hotfix_label_changes_nothing_outside_freeze(self):
        self.assertEqual(tier_in("normal", CONTENT, labels=["hotfix"]), "low")
        self.assertEqual(tier_in("peak", CONTENT, labels=["hotfix"]), "medium")

    def test_profile_never_lowers_tier(self):
        samples = [CONTENT, changes_of(("docs/a.md", 5, 0)), changes_of(("README.md", 200, 0)),
                   changes_of(("src/Claims.Api/Refunds/A.cs", 1, 0)), changes_of(("tests/Claims.Tests/OtherTests.cs", 0, 3)),
                   changes_of((".github/workflows/x.yml", 1, 0)), changes_of(("src/Claims.Api/Domain/X.cs", 3, 0))]
        ranked = sorted(POLICY["profiles"], key=lambda n: POLICY["profiles"][n]["rank"])
        for changes in samples:
            for labels in ((), ("hotfix",)):
                tiers = [TIERS.index(tier_in(name, changes, labels)) for name in ranked]
                self.assertEqual(tiers, sorted(tiers), f"{changes} {labels}: {tiers}")

    def test_profiles_are_declarative(self):
        for name in ("risk_gate.py", "policy.py"):
            source = (ROOT / ".github/scripts" / name).read_text(encoding="utf-8")
            for literal in ('"peak"', '"freeze"', '"hotfix"', "'peak'", "'freeze'", "'hotfix'"):
                self.assertNotIn(literal, source, f"{name}: profil natvrdo v kódu ({literal})")


def at(text):
    return datetime.fromisoformat(text.replace("Z", "+00:00"))


class Calendar(unittest.TestCase):
    def test_calendar_is_valid(self):
        self.assertEqual(validate_calendar(POLICY, CALENDAR), [])
        broken = {"windows": [{"name": "x", "profile": "neni", "start": "2026-01-02", "end": "2026-01-01"}]}
        self.assertEqual(len(validate_calendar(POLICY, broken)), 2)
        with self.assertRaises(ValueError):
            calendar_profile(POLICY, broken, at("2026-01-01T12:00:00Z"))

    def test_window_boundaries_in_prague_time(self):
        cases = {
            "2026-10-29T22:59:00Z": "normal",  # 29. 10. 23:59 v Praze (CET)
            "2026-10-29T23:00:00Z": "peak",    # 30. 10. 00:00 v Praze, začátek sezóny
            "2026-10-31T09:00:00Z": "peak",    # dnešek
            "2026-11-25T22:59:00Z": "peak",
            "2026-11-25T23:00:00Z": "freeze",  # 26. 11. 00:00, freeze uvnitř peak
            "2026-11-30T22:59:00Z": "freeze",  # 30. 11. 23:59, poslední minuta obou oken
            "2026-11-30T23:00:00Z": "normal",  # 1. 12. 00:00
            "2026-12-14T12:00:00Z": "peak",
            "2027-01-05T12:00:00Z": "normal",
        }
        for moment, expected in cases.items():
            self.assertEqual(calendar_profile(POLICY, CALENDAR, at(moment))[0], expected, moment)

    def test_overlap_takes_strictest_regardless_of_order(self):
        reversed_calendar = dict(CALENDAR, windows=list(reversed(CALENDAR["windows"])))
        for calendar in (CALENDAR, reversed_calendar):
            name, window = calendar_profile(POLICY, calendar, at("2026-11-27T12:00:00Z"))
            self.assertEqual(name, "freeze")
            self.assertEqual(window["name"], "Nejsilnější dny Black Friday")

    def test_manual_override_is_explained(self):
        now = at("2026-10-31T09:00:00Z")
        resolved = resolve_profile(POLICY, CALENDAR, now, override="normal", actor="Spillet")
        self.assertEqual((resolved["name"], resolved["source"], resolved["calendar_name"]), ("normal", "override", "peak"))
        self.assertIn("@Spillet", resolved["reason"])
        self.assertIn("Black Friday sezóna", resolved["reason"])
        self.assertEqual(resolve_profile(POLICY, CALENDAR, now, override="calendar")["name"], "peak")
        self.assertEqual(resolve_profile(POLICY, CALENDAR, now)["source"], "calendar")
        self.assertEqual(resolve_profile(POLICY, CALENDAR, at("2027-01-05T12:00:00Z"))["source"], "default")
        with self.assertRaises(ValueError):
            resolve_profile(POLICY, CALENDAR, now, override="volno")


class Demo(unittest.TestCase):
    def test_prepared_messages_are_valid(self):
        messages = load_messages(ROOT)
        for message in messages:
            self.assertEqual(validate(message), [], message["key"])
        self.assertEqual(len({m["key"] for m in messages}), len(messages))
        self.assertTrue(validate({"key": "X", "class": "a", "subject": 'bez "', "body": "{neco}"}))

    def demo_changes(self, message):
        return [{"paths": [str(path)], "additions": len(text.splitlines()), "deletions": 0, "binary": False}
                for path, text in build(message).items()]

    def test_demo_change_is_low_in_normal_and_medium_in_peak(self):  # cíl dema
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "review.json").write_text(json.dumps(prepared_review()), encoding="utf-8")
            review = load_review(Path(tmp))
        self.assertTrue(review["prepared"])
        for message in load_messages(ROOT):
            changes = self.demo_changes(message)
            self.assertEqual(tier_in("normal", changes, review=review), "low", message["key"])
            self.assertEqual(tier_in("peak", changes, review=review), "medium", message["key"])
        strict = dict(POLICY, signals=dict(POLICY["signals"], accept_prepared_review=False))
        self.assertEqual(decide(strict, changes, True, review, (), "normal")[0], "medium")

    def test_pick_skips_used_messages_and_repeats_with_run_number(self):
        messages = load_messages(ROOT)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(pick(messages, root, "7")["key"], messages[0]["key"])
            for message in messages[:-1]:
                for path, text in build(message).items():
                    (root / path).parent.mkdir(parents=True, exist_ok=True)
                    (root / path).write_text(text, encoding="utf-8")
            self.assertEqual(pick(messages, root, "7")["key"], messages[-1]["key"])
            for path, text in build(messages[-1]).items():
                (root / path).write_text(text, encoding="utf-8")
            again = pick(messages, root, "7")
            self.assertEqual((again["key"], again["class"]), (messages[0]["key"] + "-7", messages[0]["class"] + "R7"))

    def test_prepared_flag_comes_only_from_workflow_wrapper(self):
        # Model nemůže review označit jako připravené: příznak je v obalu, který píše skript.
        forged = {"result": json.dumps({"verdict": "approve", "prepared": True, "findings": []})}
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "review.json").write_text(json.dumps(forged), encoding="utf-8")
            self.assertFalse(load_review(Path(tmp))["prepared"])


class Authorization(unittest.TestCase):
    PROFILE = {"name": "peak", "reason": "okno „Black Friday sezóna“", "source": "calendar"}

    def test_intent_comes_from_branch(self):
        self.assertEqual(intent_of("ai/issue-7"), "spec v issue #7")
        self.assertIn("demo-prepare", intent_of("demo/pickup-12"))
        self.assertIn("neznámý zdroj", intent_of("ai/issue-7-hack"))
        self.assertIn("neznámý zdroj", intent_of(None))

    def test_rules_version_is_last_commit_of_each_rule_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            git(tmp, "init", "-q")
            git(tmp, "config", "user.email", "t@t")
            git(tmp, "config", "user.name", "t")
            for name in ("risk-policy.yml", "change-calendar.yml"):
                (Path(tmp) / name).write_text("a: 1\n", encoding="utf-8")
            git(tmp, "add", "-A")
            git(tmp, "commit", "-qm", "base")
            base = git(tmp, "rev-parse", "HEAD").strip()
            (Path(tmp) / "risk-policy.yml").write_text("a: 2\n", encoding="utf-8")
            git(tmp, "commit", "-qam", "policy")
            policy = git(tmp, "rev-parse", "HEAD").strip()
            (Path(tmp) / "README.md").write_text("x\n", encoding="utf-8")
            git(tmp, "add", "-A")
            git(tmp, "commit", "-qm", "readme")
            self.assertEqual(rules_version(tmp), {"risk-policy.yml": policy, "change-calendar.yml": base})
        with tempfile.TemporaryDirectory() as tmp:  # bez gitu: verze neznámá, risk gate nespadne
            self.assertEqual(rules_version(tmp), {"risk-policy.yml": None, "change-calendar.yml": None})

    def test_comment_answers_the_auditor(self):
        rules = {"risk-policy.yml": "a" * 40, "change-calendar.yml": None}
        authz = {"intent": intent_of("ai/issue-7"), "requested_by": "Spillet", "trigger": "agent-pipeline",
                 "rules": rules}
        old = {"when": "2026-10-31 09:00", "trigger": "demo-prepare", "profile": "peak", "source": "calendar",
               "tier": "medium", "decision": "čeká"}
        new = dict(old, trigger="gate-reevaluate (@Spillet)", rules=rules)
        body = render("medium", "čeká", [], APPROVE, self.PROFILE, {}, {"Spillet"}, [old, new], authz)
        self.assertIn("**Autorizace:** záměr: spec v issue #7", body)
        self.assertIn("agenta spustil @Spillet (`agent-pipeline`)", body)
        self.assertIn(f"[`risk-policy.yml@aaaaaaa`](../blob/{'a' * 40}/risk-policy.yml)", body)
        self.assertIn("`change-calendar.yml@?`", body)
        self.assertIn("| – |", body)  # starší záznam historie bez verze pravidel
        self.assertIn("| aaaaaaa / ? |", body)
        self.assertEqual(decode_history(body)[-1]["rules"], rules)

    def test_reevaluation_of_old_run_says_requester_is_unknown(self):
        authz = {"intent": "spec v issue #7", "requested_by": None, "trigger": "demo-prepare", "rules": {}}
        body = render("low", "auto-merge", [], APPROVE, self.PROFILE, authz=authz)
        self.assertIn("agenta spustil neuvedeno (běh před touto verzí)", body)


if __name__ == "__main__":
    os.chdir(ROOT)
    unittest.main()
