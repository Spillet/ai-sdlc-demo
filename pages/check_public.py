#!/usr/bin/env python3
"""Kontrola webu před zveřejněním na GitHub Pages. Použití: check_public.py SLOŽKA

Web na Pages je veřejný i u soukromého repa. Kontrola selže, když složka obsahuje:
- e-mailovou adresu (kromě noreply adres GitHubu),
- něco, co vypadá jako přístupový klíč nebo token,
- načítání skriptu, stylu nebo obrázku z jiného webu (stránky mají fungovat offline a nic nesledovat),
- nenahrazenou značku __COMMIT__,
- jiné soubory než HTML a CSS.
Kontrola nenahrazuje lidské přečtení obsahu před první publikací.
"""
import re
import sys
from pathlib import Path

EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")
ALLOWED_EMAIL = re.compile(r"@users\.noreply\.github\.com$|^noreply@")
SECRET = re.compile(r"(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-ant-[A-Za-z0-9_-]{10,}"
                    r"|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)")
EXTERNAL = re.compile(r"""(?:<script[^>]+src|<link[^>]+href|<img[^>]+src|@import\s+url\()\s*=?\s*["']?(?:https?:)?//""",
                      re.IGNORECASE)
ALLOWED_SUFFIXES = {".html", ".css"}


def check(root):
    problems = []
    files = [p for p in Path(root).rglob("*") if p.is_file() and p.name != ".nojekyll"]
    if not files:
        problems.append(f"{root}: prázdná složka")
    for path in files:
        if path.suffix not in ALLOWED_SUFFIXES:
            problems.append(f"{path}: nečekaný typ souboru")
            continue
        text = path.read_text(encoding="utf-8")
        for match in EMAIL.finditer(text):
            if not ALLOWED_EMAIL.search(match.group(0)):
                problems.append(f"{path}: e-mailová adresa {match.group(0)}")
        if SECRET.search(text):
            problems.append(f"{path}: vypadá to na přístupový klíč nebo token")
        if EXTERNAL.search(text):
            problems.append(f"{path}: načítá zdroj z jiného webu")
        if "__COMMIT__" in text:
            problems.append(f"{path}: nenahrazená značka __COMMIT__")
    return problems


if __name__ == "__main__":
    found = check(sys.argv[1] if len(sys.argv) > 1 else "_site")
    for line in found:
        print(f"::error::{line}")
    if found:
        sys.exit(1)
    print("Kontrola veřejného webu: bez nálezů.")
