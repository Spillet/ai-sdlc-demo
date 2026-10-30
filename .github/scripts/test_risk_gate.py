"""Testy brány podle rizika. Spuštění: python3 -m unittest discover -s .github/scripts -p 'test_*.py'

Pokrývají nálezy z oponentury: cesty s mezerou, diakritikou a přejmenováním, fail-closed při
nesouladu, chráněný kontext agentů, testy a build v politice, nálezy AI review a draft z preflightu.
"""
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

from common import find_spec, spec_paths
from policy import classify, load_policy
from preflight import high_paths, needs_owner
from risk_gate import UNRECOGNIZED, count_patch, decide, integrity, outcome, parse_numstat_z

ROOT = Path(__file__).resolve().parents[2]
POLICY = load_policy(ROOT / "risk-policy.yml")
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
                 "CODEOWNERS", "risk-policy.yml", "src/.claude/hooks.json", "docs/claude.md"]
    FREE = ["docs/faq-reklamace.md", "src/Claims.Api/Program.cs", "tests/Claims.Tests/NewTests.cs",
            "README.md", "docs/github-navod.md"]

    def test_protected_paths_are_high(self):
        for path in self.PROTECTED:
            self.assertEqual(classify(path, POLICY)["tier"], "high", path)

    def test_workflow_guard_matches_policy(self):
        workflow = yaml.safe_load((ROOT / ".github/workflows/agent-pipeline.yml").read_text(encoding="utf-8"))
        guard = re.compile(workflow["env"]["PROTECTED_PATHS"], re.IGNORECASE)
        for path in self.PROTECTED:
            self.assertTrue(guard.search(path), f"mantinel nepokrývá {path}")
        for path in self.FREE:
            self.assertFalse(guard.search(path), f"mantinel zbytečně blokuje {path}")

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
        self.assertTrue(needs_owner(["pruh:2-produkt"], ["src/Claims.Api/Refunds/X.cs"], POLICY))
        self.assertFalse(needs_owner(["pruh:2-produkt"], ["docs/a.md"], POLICY))
        self.assertTrue(needs_owner(["pruh:3-core"], [], POLICY))


if __name__ == "__main__":
    os.chdir(ROOT)
    unittest.main()
