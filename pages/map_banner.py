#!/usr/bin/env python3
"""Doplní do vygenerované mapy na Pages lištu s odkazem zpět na přehled.

Použití: map_banner.py _site/mapa/index.html

Mění jen kopii mapy ve složce webu, ne mapa-monolitu/site/index.html v repu.
Když se šablona mapy změní a značky nenajde, skončí chybou, aby se web nesestavil potichu bez lišty.
"""
import sys
from pathlib import Path

BANNER = (
    '<div style="background:var(--panel);border-bottom:1px solid var(--line);padding:8px 16px;font-size:14px">'
    '<div style="max-width:1400px;margin:0 auto">'
    '<a href="../" style="color:var(--accent);font-weight:600">← Přehled case study</a>'
    ' · Mapa nad syntetickou databází fiktivního e-shopu Kompas. '
    '<a href="../#mapa" style="color:var(--accent)">Jak mapu číst</a>'
    '</div></div>\n'
)

# Český titulek a nadpis má mapa přímo ze šablony (mapa-monolitu/mapa/template.html), skript doplní jen lištu.
REPLACEMENTS = [
    ("<body>\n", "<body>\n" + BANNER),
]


def main(path):
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    for old, new in REPLACEMENTS:
        if text.count(old) != 1:
            sys.exit(f"::error::{path}: značka {old!r} není v mapě právě jednou")
        text = text.replace(old, new)
    p.write_text(text, encoding="utf-8")
    print(f"Mapa doplněna o lištu: {path}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "_site/mapa/index.html")
