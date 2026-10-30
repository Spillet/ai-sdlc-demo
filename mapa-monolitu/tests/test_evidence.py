"""Testy balíčku důkazů a stavu pruhu core.  python3 -m unittest discover tests"""
import json
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, HERE)
from mapa import evidence  # noqa: E402

PRAHY = {"min_overene_pokryti": 0.8, "vsechny_zapisujici_overene": True, "max_blokujicich_slepych_mist": 0}
OWNER = {"tym": "Poprodej", "github_tym": "kompas/poprodej"}


def fakta(**kw):
    f = dict(vlastnik=OWNER, kandidat=True, duvod_nekandidat=None, zive=10, overene=10,
             zapisujici_neoverene=[], blokujici=[])
    f.update(kw)
    return f


class LaneStateTest(unittest.TestCase):
    def test_open_when_all_rules_hold(self):
        st, rules, missing = evidence.lane_state(fakta(), PRAHY)
        self.assertEqual(st, "otevreny_s_vlastnikem")
        self.assertTrue(all(r["splneno"] for r in rules))
        self.assertEqual(missing, [])

    def test_no_owner_closes(self):
        st, _, missing = evidence.lane_state(fakta(vlastnik=None), PRAHY)
        self.assertEqual(st, "zavreny")
        self.assertTrue(any("vlastnický tým" in m for m in missing))

    def test_cleanup_cluster_closes_even_with_owner_and_tests(self):
        st, _, _ = evidence.lane_state(fakta(kandidat=False, duvod_nekandidat="úklid"), PRAHY)
        self.assertEqual(st, "zavreny")

    def test_low_coverage_gives_draft_only(self):
        st, _, missing = evidence.lane_state(fakta(overene=7), PRAHY)
        self.assertEqual(st, "jen_draft_pr")
        self.assertTrue(any("pokrytí" in m for m in missing))

    def test_coverage_threshold_is_inclusive(self):
        self.assertEqual(evidence.lane_state(fakta(overene=8), PRAHY)[0], "otevreny_s_vlastnikem")

    def test_unverified_writer_blocks_open_despite_coverage(self):
        st, _, _ = evidence.lane_state(fakta(overene=9, zapisujici_neoverene=["usp_X"]), PRAHY)
        self.assertEqual(st, "jen_draft_pr")

    def test_blocking_blind_spot_blocks_open(self):
        st, rules, _ = evidence.lane_state(fakta(blokujici=["usp_Dyn"]), PRAHY)
        self.assertEqual(st, "jen_draft_pr")
        self.assertFalse(next(r for r in rules if r["id"] == "R5")["splneno"])

    def test_empty_domain_cannot_open(self):
        self.assertEqual(evidence.lane_state(fakta(zive=0, overene=0), PRAHY)[0], "jen_draft_pr")


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
        json.dump({"tsqlt": {"vysledek": "zelene", "datum": "2026-11-02", "prostredi": "kopie DB"},
                   "golden_master": {"vysledek": "cervene"}},
                  open(os.path.join(self.ai, "usp_B", "beh.json"), "w"))
        open(os.path.join(self.ai, "kontrakt", "X.cs"), "w").write("//")

    def tearDown(self):
        shutil.rmtree(self.root)

    def test_draft_without_run(self):
        t = evidence.scan_tests(self.ai)
        self.assertEqual(t["usp_A"]["tsqlt"]["stav"], "navrh")
        self.assertNotIn("golden_master", t["usp_A"])

    def test_run_result_counts(self):
        t = evidence.scan_tests(self.ai)
        self.assertEqual(t["usp_B"]["tsqlt"]["stav"], "zelene")
        self.assertEqual(t["usp_B"]["tsqlt"]["beh"]["datum"], "2026-11-02")
        self.assertEqual(t["usp_B"]["golden_master"]["stav"], "cervene")

    def test_dirs_without_tests_ignored(self):
        self.assertNotIn("kontrakt", evidence.scan_tests(self.ai))

    def test_missing_dir(self):
        self.assertEqual(evidence.scan_tests(os.path.join(self.root, "nic")), {})


def _index(state="otevreny_s_vlastnikem", valid_to="2026-11-30"):
    idx = dict(snimek=dict(datum="2026-10-31", platne_do=valid_to),
               domeny={"D:Claim": dict(stav=state)},
               objekty={"usp_ok": "D:Claim", "usp_bez": "D:Claim", "Claim": "D:Claim", "Orders": "sdílené"})
    packs = {"D:Claim": dict(procedury=[dict(nazev="usp_ok", pokryti="overeno"), dict(nazev="usp_bez", pokryti="navrh")])}
    return idx, packs


class GateDecisionTest(unittest.TestCase):
    def test_verified_proc_in_open_domain(self):
        idx, packs = _index()
        self.assertEqual(evidence.gate_decision(idx, packs, ["usp_ok"])[0], "otevreny_s_vlastnikem")

    def test_unverified_proc_downgrades_to_draft(self):
        idx, packs = _index()
        self.assertEqual(evidence.gate_decision(idx, packs, ["usp_ok", "usp_bez"])[0], "jen_draft_pr")

    def test_unknown_object_fails_closed(self):
        idx, packs = _index()
        self.assertEqual(evidence.gate_decision(idx, packs, ["usp_ok", "usp_neznama"])[0], "zavreny")

    def test_shared_table_closed(self):
        idx, packs = _index()
        self.assertEqual(evidence.gate_decision(idx, packs, ["Orders"])[0], "zavreny")

    def test_stale_snapshot_closed(self):
        idx, packs = _index()
        self.assertEqual(evidence.gate_decision(idx, packs, ["usp_ok"], today="2026-12-01")[0], "zavreny")

    def test_domain_state_caps_result(self):
        idx, packs = _index(state="jen_draft_pr")
        self.assertEqual(evidence.gate_decision(idx, packs, ["usp_ok"])[0], "jen_draft_pr")


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
        policy = evidence.load_policy(os.path.join(HERE, "politika", "pruh-core.json"))
        tests = evidence.scan_tests(os.path.join(HERE, "ai-vrstva"))
        cls.args = (mono, status, cl, domains, tests, policy, "x")
        cls.packs, cls.index = evidence.build(*cls.args)

    def test_claim_is_draft_only_because_tests_never_ran(self):
        p = self.packs["D:Claim"]
        self.assertEqual(p["pruh_core"]["stav"], "jen_draft_pr")
        self.assertEqual(p["pokryti"]["overeno"], 0)
        self.assertEqual(p["pokryti"]["navrh"], 3)

    def test_domain_without_owner_closed(self):
        self.assertEqual(self.packs["D:OrderNote"]["pruh_core"]["stav"], "zavreny")

    def test_contract_shape(self):
        p = self.packs["D:Claim"]
        self.assertEqual(p["schema"], evidence.SCHEMA)
        for k in ("snimek", "pruh_core", "vlastnik", "pripravenost", "pokryti", "slepa_mista", "procedury", "tabulky", "objekty"):
            self.assertIn(k, p)
        self.assertIn(p["pruh_core"]["stav"], evidence.STATES)
        self.assertEqual(self.index["objekty"]["usp_Claim_Create"], "D:Claim")
        self.assertEqual(self.index["objekty"]["Orders"], "sdílené")
        self.assertEqual(self.index["vychozi_stav"], "zavreny")

    def test_json_serializable_and_deterministic(self):
        again, idx2 = evidence.build(*self.args)
        self.assertEqual(json.dumps(self.packs, sort_keys=True, ensure_ascii=False),
                         json.dumps(again, sort_keys=True, ensure_ascii=False))
        self.assertEqual(json.dumps(self.index, sort_keys=True), json.dumps(idx2, sort_keys=True))

    def test_composed_name_in_client_blocks_reporting(self):
        blind = self.packs["D:RptDailySales"]["slepa_mista"]
        self.assertTrue(any(b["typ"] == "klient_sklada_jmeno" and b["blokujici"] for b in blind))

    def test_markdown_renders(self):
        md = evidence.evidence_md(self.packs["D:Claim"])
        self.assertIn("Pruh core: **jen draft PR**", md)
        self.assertIn("usp_Claim_SetStatus", md)


if __name__ == "__main__":
    unittest.main()
