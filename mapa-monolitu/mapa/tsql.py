"""Hrubý parser T-SQL na regulárních výrazech.

Není to parser jazyka. Dělá přesně to, co potřebuje mapa závislostí:
rozdělí skript na objekty, odstraní komentáře, oddělí řetězcové literály
a v kódu najde odkazy na tabulky, volání procedur, funkce a dynamické SQL.
Slepá místa jsou popsaná v README (sekce „Co nefunguje“).
"""
import re

GO_SPLIT = re.compile(r"^\s*GO\s*;?\s*$", re.I | re.M)
CREATE_RE = re.compile(
    r"\bCREATE\s+(?:OR\s+ALTER\s+)?(PROCEDURE|PROC|FUNCTION|VIEW|TRIGGER|TABLE)\s+((?:\[?\w+\]?\.)?\[?\w+\]?)",
    re.I)
NAME = r"((?:\[?\w+\]?\.){0,3}\[?#?\w+\]?)"


def norm(name):
    """'[dbo].[Orders]' -> ('', '', 'dbo', 'Orders'); vrací (server, db, schema, objekt)."""
    parts = [p.strip("[]") for p in name.split(".")]
    while len(parts) < 4:
        parts.insert(0, "")
    return tuple(parts[-4:])


def split_batches(text):
    return [b for b in GO_SPLIT.split(text) if b.strip()]


def strip_comments_and_strings(sql):
    """Vrátí (kód bez komentářů a s prázdnými řetězci, seznam literálů).

    Ruční průchod znak po znaku, protože regex neumí spolehlivě
    rozlišit '--' uvnitř řetězce od komentáře.
    """
    out = []
    literals = []
    i, n = 0, len(sql)
    while i < n:
        c = sql[i]
        nx = sql[i + 1] if i + 1 < n else ""
        if c == "-" and nx == "-":
            j = sql.find("\n", i)
            i = n if j < 0 else j
            continue
        if c == "/" and nx == "*":
            depth, j = 1, i + 2
            while j < n and depth:
                if sql.startswith("/*", j):
                    depth += 1
                    j += 2
                elif sql.startswith("*/", j):
                    depth -= 1
                    j += 2
                else:
                    j += 1
            i = j
            out.append(" ")
            continue
        if c == "'":
            j = i + 1
            buf = []
            while j < n:
                if sql[j] == "'":
                    if j + 1 < n and sql[j + 1] == "'":
                        buf.append("'")
                        j += 2
                        continue
                    break
                buf.append(sql[j])
                j += 1
            literals.append("".join(buf))
            out.append("''")
            i = j + 1
            continue
        out.append(c)
        i += 1
    return "".join(out), literals


READ_RE = re.compile(r"\b(?:FROM|JOIN|APPLY)\s+" + NAME + r"(?:\s+(?:AS\s+)?(\w+))?", re.I)
INSERT_RE = re.compile(r"\bINSERT\s+(?:INTO\s+)?" + NAME, re.I)
UPDATE_RE = re.compile(r"\bUPDATE\s+(?:TOP\s*\(\s*\d+\s*\)\s+)?" + NAME, re.I)
DELETE_RE = re.compile(r"\bDELETE\s+(?:TOP\s*\(\s*\d+\s*\)\s+)?(?:FROM\s+)?" + NAME, re.I)
MERGE_RE = re.compile(r"\bMERGE\s+(?:INTO\s+)?" + NAME, re.I)
TRUNC_RE = re.compile(r"\bTRUNCATE\s+TABLE\s+" + NAME, re.I)
EXEC_RE = re.compile(r"\bEXEC(?:UTE)?\s+(?:@\w+\s*=\s*)?" + NAME, re.I)
FUNC_RE = re.compile(r"\b((?:\[?\w+\]?\.)?\[?\w+\]?)\s*\(", re.I)
TRIGGER_ON_RE = re.compile(r"\bON\s+" + NAME, re.I)
DYN_RE = re.compile(r"\bsp_executesql\b|\bEXEC(?:UTE)?\s*\(\s*@?|\bEXEC(?:UTE)?\s+@\w+\s*(?:;|$|\n)", re.I)
DYN_CONCAT_RE = re.compile(r"(?:dbo\.|\.)?\s*''\s*\+\s*(?:QUOTENAME\s*\()?\s*@\w+|N?''\s*\+\s*CAST\s*\(\s*@\w+", re.I)

KEYWORDS = {"select", "where", "set", "values", "output", "inserted", "deleted", "openjson", "string_split",
            "openquery", "sp_executesql", "with", "as", "on", "top"}


def parse_object(batch):
    """Najde CREATE ... v dávce a vrátí slovník s typem, jménem a nalezenými odkazy."""
    code, literals = strip_comments_and_strings(batch)
    m = CREATE_RE.search(code)
    if not m:
        return None
    kind = m.group(1).upper()
    kind = {"PROC": "P", "PROCEDURE": "P", "FUNCTION": "FN", "VIEW": "V", "TRIGGER": "TR", "TABLE": "U"}[kind]
    _, _, schema, name = norm(m.group(2))
    obj = dict(name=name, schema=schema or "dbo", type=kind, text=batch.strip(), refs=[], literals=literals,
               dynamic=None, on_table=None)
    if kind == "U":
        return obj
    body = code[m.end():]
    if kind == "TR":
        t = TRIGGER_ON_RE.search(body)
        if t:
            obj["on_table"] = norm(t.group(1))[3]
    # aliasy: FROM dbo.Orders o -> o => Orders
    aliases = {}
    for r in READ_RE.finditer(body):
        full = norm(r.group(1))
        if r.group(2) and r.group(2).lower() not in KEYWORDS:
            aliases[r.group(2).lower()] = full
    refs = []

    def add(full, op, pos):
        srv, db, sch, obj_name = full
        if obj_name.startswith("#") or obj_name.startswith("@") or obj_name.lower() in KEYWORDS:
            return
        if not sch and not db and obj_name.lower() in aliases:
            full = aliases[obj_name.lower()]
            srv, db, sch, obj_name = full
        refs.append(dict(server=srv, db=db, schema=sch, name=obj_name, op=op, pos=pos))

    for r in READ_RE.finditer(body):
        add(norm(r.group(1)), "read", r.start())
    for rx, op in ((INSERT_RE, "write"), (UPDATE_RE, "write"), (DELETE_RE, "write"), (MERGE_RE, "write"), (TRUNC_RE, "write")):
        for r in rx.finditer(body):
            add(norm(r.group(1)), op, r.start())
    for r in EXEC_RE.finditer(body):
        nm = norm(r.group(1))
        if nm[3].lower() in ("sp_executesql",):
            continue
        add(nm, "exec", r.start())
    for r in FUNC_RE.finditer(body):
        nm = norm(r.group(1))
        if nm[2]:                         # jen kvalifikované dbo.fn(...), jinak by to chytalo COUNT( atd.
            add(nm, "call_fn", r.start())
    obj["refs"] = refs

    # dynamické SQL
    if DYN_RE.search(body):
        tables_in_literals = {}
        procs_in_literals = set()
        for lit in literals:
            lit_code, _ = strip_comments_and_strings(lit)
            for t, op in statement_tables(lit_code):
                if op == "write" or t not in tables_in_literals:
                    tables_in_literals[t] = op
            for r in EXEC_RE.finditer(lit_code):
                procs_in_literals.add(norm(r.group(1))[3])
        blind = bool(DYN_CONCAT_RE.search(body)) or bool(re.search(r"\bEXEC(?:UTE)?\s*\(\s*@\w+\s*\)", body, re.I) and not tables_in_literals)
        # literál končící "dbo." nebo "dbo.Sales_" + @x = skládané jméno objektu
        for lit in literals:
            if re.search(r"(?:dbo\.\s*|\.\w*_|EXEC\s+dbo\.\s*)$", lit.strip(), re.I) or lit.rstrip().upper().endswith("EXEC DBO."):
                blind = True
        tables_in_literals = {t: op for t, op in tables_in_literals.items() if t and not t.startswith("#") and t.lower() not in KEYWORDS}
        obj["dynamic"] = dict(tables=sorted(tables_in_literals.items()), procs=sorted(p for p in procs_in_literals if p),
                              blind=blind)
    return obj


def statement_tables(sql):
    """Tabulky v jednom příkazu (pro literály dynamického SQL a vzorky z XE): [(jméno, read|write)]."""
    out = []
    for r in READ_RE.finditer(sql):
        out.append((norm(r.group(1))[3], "read"))
    for rx in (INSERT_RE, UPDATE_RE, DELETE_RE, MERGE_RE, TRUNC_RE):
        for r in rx.finditer(sql):
            out.append((norm(r.group(1))[3], "write"))
    return [(t, op) for t, op in out if t and not t.startswith("#") and t.lower() not in KEYWORDS]


def parse_script(text):
    objs = []
    for b in split_batches(text):
        o = parse_object(b)
        if o:
            objs.append(o)
    return objs
