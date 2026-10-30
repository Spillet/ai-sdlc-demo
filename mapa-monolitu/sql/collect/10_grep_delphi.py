#!/usr/bin/env python3
"""10  Volání procedur ze zdrojáků Delphi klienta  ->  <data>/client/delphi_calls.csv

    python3 10_grep_delphi.py cesta/ke/zdrojakum > delphi_calls.csv

Sloupce: source_file, line, component, proc_name, expression

Hledá v .pas a .dfm:
  - ProcedureName = 'usp_X'           (TADOStoredProc v .dfm i v kódu)
  - EXEC usp_X / EXECUTE dbo.usp_X    v textu SQL (TADOQuery.SQL, CommandText)
  - SELECT/INSERT/UPDATE/DELETE nad tabulkou přímo z klienta
Řádky, kde se jméno skládá za běhu ('usp_Rpt_' + cbReport.Text), vypíše
s prázdným proc_name: to je slepé místo, které musí projít člověk.

NESPOUŠTĚNO na reálném kódu. Víceřádkové SQL v .dfm (SQL.Strings = (...))
skládá jen hrubě po řádcích.
"""
import csv
import os
import re
import sys

PROC_NAME = re.compile(r"ProcedureName\s*(?:=|:=)\s*'([^']+)'", re.I)
EXEC_IN_SQL = re.compile(r"\bEXEC(?:UTE)?\s+((?:\[?\w+\]?\.)?\[?\w+\]?)", re.I)
DIRECT = re.compile(r"'\s*(SELECT\b.*\bFROM\s+\w+|INSERT\s+INTO\s+\w+|UPDATE\s+\w+\s+SET|DELETE\s+FROM\s+\w+)", re.I)
DYNAMIC = re.compile(r"(ProcedureName\s*:=|EXEC(?:UTE)?\s+)[^;\n]*'\s*\+\s*\w", re.I)


def scan(root):
    w = csv.writer(sys.stdout)
    w.writerow(["source_file", "line", "component", "proc_name", "expression"])
    for dp, _, files in os.walk(root):
        for fn in files:
            if not fn.lower().endswith((".pas", ".dfm", ".inc")):
                continue
            path = os.path.join(dp, fn)
            rel = os.path.relpath(path, root)
            with open(path, encoding="cp1250", errors="replace") as f:
                for i, line in enumerate(f, 1):
                    if DYNAMIC.search(line):
                        w.writerow([rel, i, "dynamic", "", line.strip()[:300]])
                        continue
                    for m in PROC_NAME.finditer(line):
                        w.writerow([rel, i, "TADOStoredProc.ProcedureName", m.group(1), "'%s'" % m.group(1)])
                    if "'" in line:
                        for m in EXEC_IN_SQL.finditer(line):
                            w.writerow([rel, i, "SQL text", m.group(1), line.strip()[:300]])
                        if DIRECT.search(line) and not EXEC_IN_SQL.search(line):
                            w.writerow([rel, i, "TADOQuery.SQL", "", line.strip()[:300]])


if __name__ == "__main__":
    scan(sys.argv[1] if len(sys.argv) > 1 else ".")
