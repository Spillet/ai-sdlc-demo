"""Testy souhrnu metrik. Spuštění: python3 -m unittest discover -s .github/scripts -p 'test_*.py'

Hlídají, že ručně sloučené PR souhrn nevydává za automatický merge brány.
"""
import unittest

from metrics import merged_by_gate, summarize


def pr(number, merged_by=None, merged=True, branch="ai/issue-1"):
    data = {"number": number, "title": f"PR {number}", "labels": [{"name": "risk:low"}],
            "createdAt": "2026-11-03T20:00:00Z", "mergedAt": "2026-11-03T20:10:00Z" if merged else None,
            "closedAt": None, "isDraft": False, "body": "", "headRefName": branch}
    if merged_by is not None:
        data["mergedBy"] = {"login": merged_by}
    return data


class MergedByTest(unittest.TestCase):
    def test_gate_and_human_are_separate(self):
        self.assertTrue(merged_by_gate(pr(1, "github-actions")))
        self.assertTrue(merged_by_gate(pr(2, "github-actions[bot]")))
        self.assertFalse(merged_by_gate(pr(3, "Spillet")))
        self.assertIsNone(merged_by_gate(pr(4)))

    def test_summary_counts_both_kinds(self):
        text = summarize([pr(1, "github-actions"), pr(2, "Spillet"), pr(3, merged=False)])
        self.assertIn("Sloučeno: 2 z 3 (67 %); z toho sloučila brána sama 1, člověk 1", text)
        self.assertIn("sloučila brána", text)
        self.assertIn("sloučil člověk", text)
        self.assertNotIn("auto-merge", text)

    def test_missing_merger_is_reported_as_unknown(self):
        text = summarize([pr(1)])
        self.assertIn("neznámo 1", text)

    def test_only_agent_branches_count(self):
        text = summarize([pr(1, "Spillet", branch="readme-pro-hodnotitele"), pr(2, "github-actions")])
        self.assertIn("PR od agenta: 1", text)


if __name__ == "__main__":
    unittest.main()
