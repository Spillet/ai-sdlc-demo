"""Testy citlivosti pořadí na váhy.  python3 -m unittest discover tests"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from mapa import sensitivity  # noqa: E402

W = {"foreign_writes": 10, "bonus_readonly": 10}


def dom(name, fw, ro, cleanup=False, small=False):
    return dict(domain=name, components={"foreign_writes": fw, "bonus_readonly": ro}, cleanup_only=cleanup, too_small=small)


DOMS = [dom("A", 0.5, 0.3), dom("B", 0.2, 0.0), dom("C", 0.9, 0.0), dom("U", 0.0, 1.0, cleanup=True)]
# skóre: A 100−5+3 = 98, B 98, C 91 -> A a B remíza, řadí se podle jména


class SensitivityTest(unittest.TestCase):
    def test_rescore_linear_and_clamped(self):
        self.assertAlmostEqual(sensitivity.rescore(DOMS[0], W), 98.0)
        self.assertEqual(sensitivity.rescore(dom("X", 0, 1), {"bonus_readonly": 50}), 100.0)

    def test_ranking_skips_cleanup_and_small(self):
        self.assertEqual(sensitivity.ranking(DOMS, W), ["A", "B", "C"])

    def test_break_even_exact(self):
        doms = [dom("A", 0.1, 0.0), dom("B", 0.3, 0.1)]   # A 99, B 98: rozdíl 1
        gap, be = sensitivity.break_even(doms, "A", "B", W)
        self.assertAlmostEqual(gap, 1.0)
        # bonus čtení: B má o 0,1 víc, potřebuje +10 bodů váhy = +100 %
        self.assertAlmostEqual(be["bonus_readonly"], 1.0)
        # zápisy: A má o 0,2 méně penalizace; dorovná se při váze 5 = −50 %
        self.assertAlmostEqual(be["foreign_writes"], -0.5)
        w = dict(W, bonus_readonly=20)
        self.assertAlmostEqual(sensitivity.rescore(doms[0], w), sensitivity.rescore(doms[1], w))

    def test_break_even_none_when_component_equal(self):
        _, be = sensitivity.break_even([dom("A", 0.1, 0.2), dom("B", 0.3, 0.2)], "A", "B", W)
        self.assertIsNone(be["bonus_readonly"])

    def test_one_at_a_time_rows(self):
        base, rows = sensitivity.one_at_a_time(DOMS, W, 0.2)
        self.assertEqual(len(rows), 2 * len(W))
        self.assertEqual(base, ["A", "B", "C"])
        # +20 % bonus čtení pomůže A (má čtecí cesty): zůstane první s náskokem 0,6
        r = next(x for x in rows if x["vaha"] == "bonus_readonly" and x["zmena"] > 0)
        self.assertEqual(r["prvni"], "A")
        self.assertAlmostEqual(r["rozdil_1_2"], 0.6)
        # −20 % bonus čtení: A 97,4 vs B 98 -> B první
        r = next(x for x in rows if x["vaha"] == "bonus_readonly" and x["zmena"] < 0)
        self.assertEqual(r["prvni"], "B")

    def test_monte_carlo_deterministic_and_sums_to_one(self):
        a = sensitivity.monte_carlo(DOMS, W, 0.2, n=300, seed=3)
        b = sensitivity.monte_carlo(DOMS, W, 0.2, n=300, seed=3)
        self.assertEqual(a, b)
        self.assertAlmostEqual(sum(a["prvni"].values()), 1.0, places=2)
        self.assertEqual(a["rozsah_poradi"]["C"], [3, 3])

    def test_report_renders(self):
        labels = {"foreign_writes": "zápisy", "bonus_readonly": "čtení"}
        md = sensitivity.report_md(sensitivity.analyze(DOMS, W, n=50), labels)
        self.assertIn("Bod zvratu", md)
        self.assertIn("| zápisy |", md)


if __name__ == "__main__":
    unittest.main()
