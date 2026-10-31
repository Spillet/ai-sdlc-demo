"""Testy evidence pack a stavu core lane.  python3 -m unittest discover -s tests"""
import json
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, HERE)
from mapa import evidence  # noqa: E402

THRESHOLDS = {"min_verified_coverage": 0.8, "all_writers_verified": True, "max_blocking_blind_spots": 0}
OWNER = {"team": "Poprodej", "github_team": "kompas/poprodej"}


def facts(**kw):
    f = dict(owner=OWNER, candidate=True, not_candidate_reason=None, live=10, verified=10,
             writers_unverified=[], blocking=[])
    f.update(kw)
    return f


class LaneStateTest(unittest.TestCase):
    def test_open_when_all_rules_hold(self):
        st, rules, missing = evidence.lane_state(facts(), THRESHOLDS)
        self.assertEqual(st, "open")
        self.assertTrue(all(r["met"] for r in rules))
        self.assertEqual(missing, [])

    def test_no_owner_closes(self):
        st, _, missing = evidence.lane_state(facts(owner=None), THRESHOLDS)
        self.assertEqual(st, "closed")
        self.assertTrue(any("owning team" in m for m in missing))

    def test_cleanup_cluster_closes_even_with_owner_and_tests(self):
        st, _, _ = evidence.lane_state(facts(candidate=False, not_candidate_reason="úklid"), THRESHOLDS)
        self.assertEqual(st, "closed")

    def test_low_coverage_gives_draft_only(self):
        st, _, missing = evidence.lane_state(facts(verified=7), THRESHOLDS)
        self.assertEqual(st, "draft-only")
        self.assertTrue(any("pokrytí" in m for m in missing))

    def test_coverage_threshold_is_inclusive(self):
        self.assertEqual(evidence.lane_state(facts(verified=8), THRESHOLDS)[0], "open")

    def test_unverified_writer_blocks_open_despite_coverage(self):
        st, _, _ = evidence.lane_state(facts(verified=9, writers_unverified=["usp_X"]), THRESHOLDS)
        self.assertEqual(st, "draft-only")

    def test_blocking_blind_spot_blocks_open(self):
        st, rules, _ = evidence.lane_state(facts(blocking=["usp_Dyn"]), THRESHOLDS)
        self.assertEqual(st, "draft-only")
        self.assertFalse(next(r for r in rules if r["id"] == "R5")["met"])

    def test_empty_domain_cannot_open(self):
        self.assertEqual(evidence.lane_state(facts(live=0, verified=0), THRESHOLDS)[0], "draft-only")


class ScanTestsTest(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.ai = os.path.join(self.root, "ai-vrstva")
        os.makedirs(os.path.join(self.ai, "usp_A"))
        os.makedirs(os.path.join(self.ai, "usp_B"))
        os.makedirs(os.path.join(self.ai, "kontrakt"))
        open(os.path.join(self.ai, "usp_A", "test_usp_A.sql"), "w").write("-- NESPUŠTĚNO")
        open(os.path.join(self.ai, "usp_B", "golden_master.sql"), "w").write("--")
        open(os.path.join(self.ai, "usp_B", "test_usp_B.sql"), "w").write("--")
        json.dump({"tsqlt": {"result": "green", "date": "2026-11-02", "environment": "kopie DB"},
                   "golden_master": {"result": "red"}},
                  open(os.path.join(self.ai, "usp_B", "run.json"), "w"))
        open(os.path.join(self.ai, "kontrakt", "X.cs"), "w").write("//")

    def tearDown(self):
        shutil.rmtree(self.root)

    def test_draft_without_run(self):
        t = evidence.scan_tests(self.ai)
        self.assertEqual(t["usp_A"]["tsqlt"]["status"], "draft")
        self.assertNotIn("golden_master", t["usp_A"])

    def test_run_result_counts(self):
        t = evidence.scan_tests(self.ai)
        self.assertEqual(t["usp_B"]["tsqlt"]["status"], "green")
        self.assertEqual(t["usp_B"]["tsqlt"]["run"]["date"], "2026-11-02")
        self.assertEqual(t["usp_B"]["golden_master"]["status"], "red")

    def test_dirs_without_tests_ignored(self):
        self.assertNotIn("kontrakt", evidence.scan_tests(self.ai))

    def test_missing_dir(self):
        self.assertEqual(evidence.scan_tests(os.path.join(self.root, "nic")), {})


def _index(state="open", valid_to="2026-11-30"):
    idx = dict(snapshot=dict(date="2026-10-31", valid_until=valid_to),
               domains={"D:Claim": dict(state=state)},
               objects={"usp_ok": "D:Claim", "usp_bez": "D:Claim", "Claim": "D:Claim", "Orders": "shared"})
    packs = {"D:Claim": dict(procedures=[dict(name="usp_ok", coverage="verified"), dict(name="usp_bez", coverage="draft")])}
    return idx, packs


class GateDecisionTest(unittest.TestCase):
    def test_verified_proc_in_open_domain(self):
        idx, packs = _index()
        self.assertEqual(evidence.gate_decision(idx, packs, ["usp_ok"])[0], "open")

    def test_unverified_proc_downgrades_to_draft(self):
        idx, packs = _index()
        self.assertEqual(evidence.gate_decision(idx, packs, ["usp_ok", "usp_bez"])[0], "draft-only")

    def test_unknown_object_fails_closed(self):
        idx, packs = _index()
        self.assertEqual(evidence.gate_decision(idx, packs, ["usp_ok", "usp_neznama"])[0], "closed")

    def test_shared_table_closed(self):
        idx, packs = _index()
        self.assertEqual(evidence.gate_decision(idx, packs, ["Orders"])[0], "closed")

    def test_stale_snapshot_closed(self):
        idx, packs = _index()
        self.assertEqual(evidence.gate_decision(idx, packs, ["usp_ok"], today="2026-12-01")[0], "closed")

    def test_domain_state_caps_result(self):
        idx, packs = _index(state="draft-only")
        self.assertEqual(evidence.gate_decision(idx, packs, ["usp_ok"])[0], "draft-only")


class SyntheticEvidenceTest(unittest.TestCase):
    """Celý řetězec nad syntetickou DB: tvar kontraktu a deterministický výstup."""

    @classmethod
    def setUpClass(cls):
        from mapa.model import Monolith
        from mapa.cluster import cluster
        from mapa.score import score_domains
        data = os.path.join(HERE, "data", "synthetic")
        mono = Monolith(data).load()
        mono.index()
        status = mono.liveness()
        cl = cluster(mono, status)
        domains, _ = score_domains(mono, status, cl)
        policy = evidence.load_policy(os.path.join(HERE, "policy", "core-lane.json"))
        tests = evidence.scan_tests(os.path.join(HERE, "ai-vrstva"))
        cls.args = (mono, status, cl, domains, tests, policy, "x")
        cls.packs, cls.index = evidence.build(*cls.args)

    def test_claim_is_draft_only_because_tests_never_ran(self):
        p = self.packs["D:Claim"]
        self.assertEqual(p["core_lane"]["state"], "draft-only")
        self.assertEqual(p["coverage"]["verified"], 0)
        self.assertEqual(p["core_lane"]["autonomy_level"], "L1")
        self.assertEqual(self.index["domains"]["D:OrderNote"]["autonomy_level"], "L0")
        self.assertEqual(p["coverage"]["draft"], 3)

    def test_domain_without_owner_closed(self):
        self.assertEqual(self.packs["D:OrderNote"]["core_lane"]["state"], "closed")

    def test_contract_shape(self):
        p = self.packs["D:Claim"]
        self.assertEqual(p["schema"], evidence.SCHEMA)
        self.assertTrue(evidence.SCHEMA.endswith("@2"))
        for k in ("snapshot", "core_lane", "owner", "readiness", "coverage", "blind_spots", "procedures", "tables", "objects"):
            self.assertIn(k, p)
        self.assertIn(p["core_lane"]["state"], evidence.STATES)
        self.assertEqual(self.index["objects"]["usp_Claim_Create"], "D:Claim")
        self.assertEqual(self.index["objects"]["Orders"], "shared")
        self.assertEqual(self.index["default_state"], "closed")

    def test_json_serializable_and_deterministic(self):
        again, idx2 = evidence.build(*self.args)
        self.assertEqual(json.dumps(self.packs, sort_keys=True, ensure_ascii=False),
                         json.dumps(again, sort_keys=True, ensure_ascii=False))
        self.assertEqual(json.dumps(self.index, sort_keys=True), json.dumps(idx2, sort_keys=True))

    def test_composed_name_in_client_blocks_reporting(self):
        blind = self.packs["D:RptDailySales"]["blind_spots"]
        self.assertTrue(any(b["type"] == "client_composed_name" and b["blocking"] for b in blind))

    def test_markdown_renders(self):
        md = evidence.evidence_md(self.packs["D:Claim"])
        self.assertIn("Core lane: **draft-only** (autonomy level L1)", md)
        self.assertIn("usp_Claim_SetStatus", md)


if __name__ == "__main__":
    unittest.main()
