"""Testy HTML šablony mapy: struktura pohledů, popisy a offline provoz.  python3 -m unittest discover tests

JavaScript stránky se tu nespouští. Testy hlídají, že šablona má všechno, co hodnotitel potřebuje
k pochopení mapy bez výkladu, a že nic nenačítá z internetu.
"""
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
from mapa import render, score  # noqa: E402

with open(os.path.join(ROOT, "mapa", "template.html"), encoding="utf-8") as f:
    TPL = f.read()

VIEWS = ["domeny", "lane", "graf", "blind", "objekty"]


class TemplateTest(unittest.TestCase):
    def test_data_placeholder_and_banner_marker(self):
        self.assertEqual(TPL.count("/*__DATA__*/null"), 1)
        # pages/map_banner.py vkládá lištu za tuto značku a bez ní web nesestaví
        self.assertEqual(TPL.count("<body>\n"), 1)

    def test_czech_title(self):
        self.assertIn("<title>Mapa monolitu · ukázka</title>", TPL)
        self.assertIn("<h1>Mapa monolitu</h1>", TPL)

    def test_five_views_with_tabs_and_panels(self):
        tabs = re.findall(r'role="tab" id="t-(\w+)" data-t="(\w+)" aria-controls="(\w+)"', TPL)
        self.assertEqual([t[1] for t in tabs], VIEWS)
        for tid, dt, ctl in tabs:
            self.assertEqual(tid, dt)
            self.assertEqual(dt, ctl)
            self.assertRegex(TPL, r'<section class="tab[^"]*" id="%s" role="tabpanel" aria-labelledby="t-%s"' % (dt, dt))

    def test_every_view_has_reading_guide(self):
        # tři pohledy mají návod v HTML, Core lane a Blind spots ho skládají ve skriptu
        self.assertGreaterEqual(TPL.count("Jak číst tento pohled"), len(VIEWS))

    def test_every_weight_has_description(self):
        block = re.search(r"const WDESC = \{(.*?)\n\};", TPL, re.S).group(1)
        keys = set(re.findall(r"^\s*(\w+):", block, re.M))
        self.assertEqual(keys, set(score.WEIGHTS))

    def test_header_explains_purpose(self):
        for title in ("Proč mapa před dekompozicí", "Co katalog databáze nevidí",
                      "Jak vybrat první doménu", "Kde chybí důkaz pro změny od AI", "Hranice prototypu"):
            self.assertIn(title, TPL)

    def test_core_lane_states_and_gate_relation(self):
        for state in ("closed", "draft-only", "open"):
            self.assertIn('["%s", "L' % state, TPL)
        self.assertIn("Brána ho v ukázce zatím nečte", TPL)

    def test_no_external_resources(self):
        # mapa musí fungovat otevřená z disku a projít pages/check_public.py
        self.assertNotRegex(TPL, r"https?://")
        self.assertNotRegex(TPL, r"""(?i)<(script|img)[^>]+src\s*=|<link[^>]+href\s*=|@import""")

    def test_render_inserts_and_escapes_data(self):
        html = render.html({"summary": {}, "x": "</script>"})
        self.assertNotIn("/*__DATA__*/null", html)
        self.assertIn('"x":"<\\/script>"', html)

    def test_committed_site_matches_template(self):
        # site/index.html v repu je offline verze mapy; po změně šablony je potřeba spustit analyze.py
        with open(os.path.join(ROOT, "site", "index.html"), encoding="utf-8") as f:
            site = f.read()
        head = TPL.split("/*__DATA__*/null")[0]
        self.assertTrue(site.startswith(head), "site/index.html neodpovídá šabloně, spusť python3 analyze.py")


if __name__ == "__main__":
    unittest.main()
