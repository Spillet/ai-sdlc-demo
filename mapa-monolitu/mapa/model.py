"""Načtení vstupů a sestavení grafu závislostí ve čtyřech vrstvách.

Vrstvy (každá hrana si pamatuje, kdo ji viděl):
  static    text modulů, obdoba sys.sql_expression_dependencies (+ triggery)
  dynamic   literály dynamického SQL (co jde vyčíst z textu, i když katalog ne)
  runtime   simulovaný export Extended Events / Query Store
  client    grep zdrojáků Delphi klienta
  agent     kroky SQL Agent jobů
"""
import csv
import glob
import os
import re
from collections import defaultdict

from . import tsql

LAYERS = ("static", "dynamic", "runtime", "client", "agent")


def _csv(path):
    if not os.path.exists(path):
        return []
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def _short(name):
    return tsql.norm(name.strip())[3]


class Monolith:
    def __init__(self, data_dir):
        self.data_dir = data_dir
        self.objects = {}            # jméno -> dict
        self.edges = {}              # (src, dst, typ) -> dict(layers=set, ...)
        self.entries = defaultdict(lambda: defaultdict(int))   # proc -> zdroj -> počet volání
        self.entry_refs = defaultdict(set)                     # proc -> {'client','agent','web',...} (deklarované)
        self.schedule = {}           # proc -> (rozvrh, enabled, job)
        self.runtime_calls = {}      # proc -> počet (module_end)
        self.qs = {}                 # proc -> dict(cpu_ms, logical_writes, ...)
        self.sizes = {}              # tabulka -> GB
        self.blind = defaultdict(list)  # druh -> seznam záznamů
        self.client_tables = defaultdict(list)

    # ------------------------------------------------------------------ vstupy
    def load(self):
        for path in sorted(glob.glob(os.path.join(self.data_dir, "db", "*.sql"))):
            with open(path, encoding="utf-8") as f:
                for o in tsql.parse_script(f.read()):
                    o["file"] = os.path.relpath(path, self.data_dir)
                    self.objects[o["name"]] = o
        for r in _csv(os.path.join(self.data_dir, "catalog", "table_sizes.csv")):
            self.sizes[r["table_name"]] = float(r["reserved_gb"])
        self._static()
        self._dynamic_literals()
        self._client()
        self._agent()
        self._runtime()
        return self

    def kind(self, name):
        o = self.objects.get(name)
        return o["type"] if o else None

    def is_module(self, name):
        return self.kind(name) in ("P", "FN", "TR")

    def is_data(self, name):
        return self.kind(name) in ("U", "V")

    def add_edge(self, src, dst, typ, layer, **extra):
        k = (src, dst, typ)
        e = self.edges.get(k)
        if not e:
            e = dict(src=src, dst=dst, type=typ, layers=set(), flags=set(), count=0)
            self.edges[k] = e
        e["layers"].add(layer)
        for f in extra.get("flags", ()):
            e["flags"].add(f)
        if extra.get("count"):
            e["count"] += extra["count"]
        return e

    def _static(self):
        lower = {n.lower(): n for n in self.objects}
        for name, o in self.objects.items():
            if o["type"] in ("U",):
                continue
            if o["type"] == "TR" and o["on_table"]:
                self.add_edge(name, o["on_table"], "trigger_on", "static")
            for r in o["refs"]:
                target = lower.get(r["name"].lower())
                if r["db"] or r["server"]:
                    self.blind["cross_db"].append(dict(obj=name, ref=".".join(x for x in (r["server"], r["db"], r["schema"], r["name"]) if x), op=r["op"]))
                    continue
                if not target:
                    if r["schema"] and r["op"] in ("read", "write", "exec"):
                        self.blind["unresolved"].append(dict(obj=name, ref=r["name"], op=r["op"]))
                    continue
                tk = self.objects[target]["type"]
                if r["op"] in ("read", "write") and tk in ("U", "V", "FN"):
                    if tk == "FN":
                        self.add_edge(name, target, "calls", "static")
                    else:
                        self.add_edge(name, target, "writes" if r["op"] == "write" else "reads", "static")
                elif r["op"] == "exec" and tk == "P":
                    flags = {"caller_dependent"} if not r["schema"] else set()
                    e = self.add_edge(name, target, "calls", "static", flags=flags)
                    if flags:
                        self.blind["caller_dependent"].append(dict(obj=name, ref=target))
                elif r["op"] == "call_fn" and tk == "FN":
                    self.add_edge(name, target, "calls", "static")
        # zápis do tabulky spustí trigger: skrytá hrana zapisovatel -> trigger
        triggers = defaultdict(list)
        for n, o in self.objects.items():
            if o["type"] == "TR" and o["on_table"]:
                triggers[o["on_table"]].append(n)
        for (s, d, t), e in list(self.edges.items()):
            if t == "writes" and d in triggers:
                for trg in triggers[d]:
                    if trg != s:
                        self.add_edge(s, trg, "calls", "static", flags={"via_trigger"})

    def _dynamic_literals(self):
        for name, o in self.objects.items():
            d = o.get("dynamic")
            if not d:
                continue
            for t, op in d["tables"]:
                if t in self.objects and self.objects[t]["type"] in ("U", "V"):
                    self.add_edge(name, t, "writes" if op == "write" else "reads", "dynamic", flags={"dynamic_sql"})
            for p in d["procs"]:
                if p in self.objects:
                    self.add_edge(name, p, "calls", "dynamic", flags={"dynamic_sql"})
            if d["blind"]:
                self.blind["dynamic_blind"].append(dict(obj=name))

    def _client(self):
        for r in _csv(os.path.join(self.data_dir, "client", "delphi_calls.csv")):
            p = _short(r["proc_name"]) if r["proc_name"] else ""
            if p and p in self.objects:
                self.entry_refs[p].add("client")
                continue
            expr = r.get("expression", "")
            tabs = tsql.statement_tables(expr.strip("'"))
            if tabs:
                for t, op in tabs:
                    if t in self.objects:
                        self.client_tables[t].append(dict(file=r["source_file"], line=r["line"], op=op))
                        self.add_edge("[Delphi klient]", t, "writes" if op == "write" else "reads", "client")
            else:
                self.blind["client_unresolved"].append(dict(file=r["source_file"], line=r["line"], expression=expr))

    def _agent(self):
        exec_re = re.compile(r"\bEXEC(?:UTE)?\s+((?:\[?\w+\]?\.)?\[?\w+\]?)", re.I)
        for r in _csv(os.path.join(self.data_dir, "scheduler", "sql_agent_jobs.csv")):
            names = [_short(m.group(1)) for m in exec_re.finditer(r["command"])]
            for p in names:
                if p not in self.objects:
                    continue
                self.entry_refs[p].add("agent")
                self.schedule[p] = dict(schedule=r["schedule"], enabled=r["enabled"] == "1", job=r["job_name"],
                                        subsystem=r["subsystem"])
                if r["subsystem"] != "TSQL":
                    self.blind["agent_non_tsql"].append(dict(job=r["job_name"], proc=p, subsystem=r["subsystem"]))

    def _runtime(self):
        rt = os.path.join(self.data_dir, "runtime")
        for r in _csv(os.path.join(rt, "xe_rpc_completed_histogram.csv")):
            p = _short(r["object_name"])
            app = r["client_app_name"]
            src = ("client" if app.startswith("Konzole") else "agent" if app.startswith("SQLAgent") else
                   "web" if "Web" in app else "other")
            self.entries[p][src] += int(r["event_count"])
            self.entries[p]["_app:" + app] += int(r["event_count"])
        for r in _csv(os.path.join(rt, "xe_module_end_histogram.csv")):
            self.runtime_calls[_short(r["object_name"])] = int(r["event_count"])
        for r in _csv(os.path.join(rt, "query_store_proc_stats.csv")):
            self.qs[_short(r["object_name"])] = {k: int(v) for k, v in r.items() if k != "object_name"}
        for r in _csv(os.path.join(rt, "xe_dynamic_sql.csv")):
            parent = _short(r["parent_object"])
            stmt = r["statement_sample"]
            m = re.match(r"\s*EXEC(?:UTE)?\s+((?:\[?\w+\]?\.)?\[?\w+\]?)", stmt, re.I)
            if m:
                p = _short(m.group(1))
                if p in self.objects:
                    self.add_edge(parent, p, "calls", "runtime", flags={"dynamic_sql"}, count=int(r["event_count"]))
                continue
            for t, op in tsql.statement_tables(stmt):
                if t in self.objects:
                    self.add_edge(parent, t, "writes" if op == "write" else "reads", "runtime", flags={"dynamic_sql"},
                                  count=int(r["event_count"]))

    # ---------------------------------------------------------------- dotazy
    def modules(self, types=("P", "FN", "TR")):
        return sorted(n for n, o in self.objects.items() if o["type"] in types)

    def out_edges(self, n):
        return [e for e in self.edges.values() if e["src"] == n]

    def in_edges(self, n):
        return [e for e in self.edges.values() if e["dst"] == n]

    def index(self):
        self._out = defaultdict(list)
        self._in = defaultdict(list)
        for e in self.edges.values():
            self._out[e["src"]].append(e)
            self._in[e["dst"]].append(e)
        self.out_edges = lambda n: self._out.get(n, [])
        self.in_edges = lambda n: self._in.get(n, [])

    def view_tables(self, v):
        return [e["dst"] for e in self.out_edges(v) if e["type"] == "reads" and self.kind(e["dst"]) == "U"]

    # ------------------------------------------------------- živé vs. mrtvé
    def liveness(self):
        """Stav každé procedury ze všech vrstev dohromady."""
        status = {}
        for p in self.modules(("P",)):
            calls = self.runtime_calls.get(p, 0)
            sch = self.schedule.get(p)
            if calls > 0:
                status[p] = "živá"
            elif sch and sch["enabled"]:
                status[p] = "mimo okno měření"          # např. roční job
            elif "client" in self.entry_refs.get(p, ()):
                status[p] = "v klientovi, nepoužitá"
            else:
                status[p] = "mrtvá"
        # funkce a triggery: živé, když je volá živý modul
        for n in self.modules(("FN", "TR")):
            callers = [e["src"] for e in self.in_edges(n) if e["type"] == "calls"]
            status[n] = "živá" if any(status.get(c) == "živá" for c in callers) else (
                "mrtvá" if not callers or all(status.get(c) == "mrtvá" for c in callers) else "nejistá")
        self.status = status
        return status

    def static_only_dead(self):
        """Procedury, které statická vrstva považuje za nevolané, ale běh ukázal provoz."""
        out = []
        for p in self.modules(("P",)):
            static_callers = [e for e in self.in_edges(p) if e["type"] == "calls" and "static" in e["layers"]]
            if not static_callers and self.runtime_calls.get(p, 0) > 0:
                declared = self.entry_refs.get(p, set())
                out.append(dict(proc=p, runtime=self.runtime_calls[p],
                                seen_by=sorted(declared) or ["jen běh"],
                                apps=sorted(k[5:] for k in self.entries.get(p, {}) if k.startswith("_app:"))))
        return out
