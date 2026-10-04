"""Render an interactive HTML graph of the packages without maintainers in
the system closures of a flake's NixOS/nix-darwin machines.

Each machine is evaluated with nixpkgs' `maintainerless` problem switched to
"warn" (via extendModules, so the flake itself is not changed and no
derivation changes). The warnings name the unmaintained packages; the graph
comes from `nix derivation show -r` on the system derivation, so build
dependencies are included.

Package meta (description, homepage, ...) is collected in the same evaluation
by walking the derivation values the system is built from. Packages only
referenced through strings (e.g. "${pkg}/bin/foo") are not reachable that way;
for those the tool looks up the attribute by name in one extra evaluation.
"""

import argparse
import concurrent.futures
import json
import os
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

# second group is "<file>:<line>", the package's meta.position
WARNING = re.compile(
    r"evaluation warning: Package '([^']+)' in (/nix/store/[^:\s]+:\d+) "
    r"has the following problem: maintainerless"
)
MAX_MACHINES = 31  # the page stores machine membership in 32-bit masks

# Nix function: the cheap, JSON-safe subset of a derivation's meta
META_FN = """
  metaOf = d:
    let
      m = d.meta or { };
      str = v: if builtins.isString v then v else null;
      first = v: if builtins.isList v then (if v == [ ] then null else builtins.head v) else v;
      lic = x: if builtins.isAttrs x then x.spdxId or x.shortName or x.fullName or null else str x;
      licenses = let l = m.license or [ ]; in if builtins.isList l then l else [ l ];
    in
    {
      description = str (m.description or null);
      homepage = str (first (m.homepage or null));
      changelog = str (first (m.changelog or null));
      license = builtins.filter (x: x != null) (map lic licenses);
      vulnerabilities = builtins.filter builtins.isString (m.knownVulnerabilities or [ ]);
    };
"""

EVAL_EXPR = """
let
  flake = builtins.getFlake %(flake)s;
  base = flake.%(kind)sConfigurations.${%(machine)s};
  sys = base.extendModules {
    modules = [
      { nixpkgs.config.problems.matchers = [ { kind = "maintainerless"; handler = "warn"; } ]; }
    ];
  };
  top = if %(kind_str)s == "nixos" then sys.config.system.build.toplevel else sys.system;
  %(meta_fn)s
  isDrv = v: builtins.isAttrs v && (v.type or null) == "derivation";
  # derivation values a derivation was given as attributes: directly, in lists, or one attrset deep.
  # All of these were already forced to compute drvPath, so walking them is nearly free.
  depsOf = d:
    let
      pick = v:
        if isDrv v then [ v ]
        else if builtins.isList v then builtins.concatMap pick v
        else if builtins.isAttrs v then builtins.filter isDrv (builtins.attrValues v)
        else [ ];
    in
    builtins.concatMap pick (builtins.attrValues (d.drvAttrs or { }));
  closure = builtins.genericClosure {
    startSet = [ { key = top.drvPath; d = top; } ];
    operator = n: map (d: { key = d.drvPath; inherit d; }) (depsOf n.d);
  };
  unmaintained = builtins.filter
    (n: (n.d.meta.maintainers or [ ]) == [ ] && (n.d.meta.teams or [ ]) == [ ]) closure;
in
{
  drv = top.drvPath;
  # warnings point into the source nixpkgs was evaluated from, which pkgs.path may only be a copy of
  nixpkgs = sys.pkgs.hello.meta.position;
  rev = sys.config.system.nixos.revision or sys.config.system.nixpkgsRevision or "";
  meta = builtins.listToAttrs (map (n: { name = n.d.name; value = metaOf n.d; }) unmaintained);
}
"""

# For packages the walk could not reach: try likely attribute paths, accept one whose name matches.
LOOKUP_EXPR = """
let
  flake = builtins.getFlake %(flake)s;
  pkgs = flake.%(kind)sConfigurations.${%(machine)s}.pkgs;
  lib = pkgs.lib;
  %(meta_fn)s
  wanted = builtins.fromJSON %(wanted)s;
  get = path: let r = builtins.tryEval (lib.attrByPath path null pkgs); in if r.success then r.value else null;
  nameOf = v: let r = builtins.tryEval (v.name or null); in if r.success then r.value else null;
  find = it:
    let
      p = builtins.parseDrvName it.name;
      py = builtins.match "python3[.0-9]*-(.*)" p.name;
      candidates =
        lib.optional (it.byname != null) [ it.byname ]
        ++ [ [ p.name ] [ "haskellPackages" p.name ] ]
        ++ lib.optional (py != null) [ "python3Packages" (builtins.head py) ];
      hits = builtins.filter (c: let v = get c; in lib.isDerivation v && nameOf v == it.name) candidates;
    in
    if hits == [ ] then null
    else metaOf (get (builtins.head hits)) // { attr = lib.concatStringsSep "." (builtins.head hits); };
in
lib.filterAttrs (_: v: v != null) (builtins.listToAttrs (map (it: { name = it.name; value = find it; }) wanted))
"""


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def nix_str(s):
    return json.dumps(s)  # a JSON string literal is a valid Nix string for these inputs


def nix_eval_json(expr):
    return subprocess.run(
        ["nix", "eval", "--impure", "--json", "--expr", expr],
        capture_output=True,
        text=True,
    )


def discover(flake):
    expr = (
        f"let f = builtins.getFlake {nix_str(flake)}; in {{"
        " nixos = builtins.attrNames (f.nixosConfigurations or { });"
        " darwin = builtins.attrNames (f.darwinConfigurations or { }); }"
    )
    proc = nix_eval_json(expr)
    if proc.returncode != 0:
        sys.exit(f"could not list machines of {flake}:\n{proc.stderr[-2000:]}")
    found = json.loads(proc.stdout)
    return [(m, "nixos") for m in found["nixos"]] + [(m, "darwin") for m in found["darwin"]]


def evaluate(flake, machine, kind):
    expr = EVAL_EXPR % {
        "flake": nix_str(flake),
        "kind": kind,
        "kind_str": nix_str(kind),
        "machine": nix_str(machine),
        "meta_fn": META_FN,
    }
    proc = nix_eval_json(expr)
    if proc.returncode != 0:
        lines = proc.stderr.strip().splitlines()
        raise RuntimeError(lines[-1] if lines else "evaluation failed")
    result = json.loads(proc.stdout)
    result["warned"] = sorted(set(WARNING.findall(proc.stderr)))
    return result


def lookup_meta(flake, machine, kind, warned):
    """Meta for the packages the closure walk missed, via attribute lookup on one machine's pkgs."""
    wanted = []
    for name, path in warned.items():
        m = re.search(r"/pkgs/by-name/[^/]+/([^/]+)/package\.nix:\d+$", path)
        wanted.append({"name": name, "byname": m.group(1) if m else None})
    expr = LOOKUP_EXPR % {
        "flake": nix_str(flake),
        "kind": kind,
        "machine": nix_str(machine),
        "meta_fn": META_FN,
        "wanted": nix_str(json.dumps(wanted)),
    }
    proc = nix_eval_json(expr)
    if proc.returncode != 0:
        lines = proc.stderr.strip().splitlines()
        log(f"[meta] lookup failed, continuing without: {lines[-1] if lines else '?'}")
        return {}
    return json.loads(proc.stdout)


def derivation_graph(drv):
    """{drv basename: (name, [input drv basenames])} for the whole build closure of drv."""
    proc = subprocess.run(["nix", "derivation", "show", "-r", drv], capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip()[-500:])
    data = json.loads(proc.stdout)
    data = data.get("derivations", data)  # newer nix nests them
    graph = {}
    for path, d in data.items():
        inputs = d.get("inputDrvs") or d.get("inputs", {}).get("drvs") or {}
        graph[os.path.basename(path)] = (d["name"], [os.path.basename(p) for p in inputs])
    return graph


def dependents_counts(children):
    """How many nodes transitively depend on each node (bitset DP in topological order)."""
    n = len(children)
    indeg = [0] * n
    for cs in children:
        for c in cs:
            indeg[c] += 1
    order = [i for i in range(n) if indeg[i] == 0]
    for i in order:  # grows while iterating
        for c in children[i]:
            indeg[c] -= 1
            if indeg[c] == 0:
                order.append(c)
    anc = [0] * n  # bitset of strict ancestors
    for i in order:
        a = anc[i] | (1 << i)
        for c in children[i]:
            anc[c] |= a
    return [bin(a).count("1") for a in anc]


def file_entry(position, sources):
    """[file:line to show, GitHub link to that line or None] for a warning's meta.position."""
    path, _, line = position.rpartition(":")
    for src, rev in sources.items():
        if path.startswith(src + "/"):
            rel = path[len(src) + 1 :]
            link = re.fullmatch(r"[0-9a-f]{7,40}", rev or "")
            url = f"https://github.com/NixOS/nixpkgs/blob/{rev}/{rel}#L{line}" if link else None
            return [f"{rel}:{line}", url]
    m = re.match(r"/nix/store/[^/]+/(.*)", path)
    return [f"{m.group(1) if m else path}:{line} (not nixpkgs)", None]


def build_data(title, results, graphs, meta):
    mach = sorted(results)
    # "<nixpkgs>/pkgs/by-name/he/hello/package.nix:42" -> "<nixpkgs>"
    sources = {r["nixpkgs"].rsplit("/pkgs/", 1)[0]: r["rev"] for r in results.values()}
    warned = {name: path for m in mach for name, path in results[m]["warned"]}

    key2i, names, keys, parents, mask = {}, [], [], [], []
    direct = defaultdict(int)  # node -> machines where it is a direct input of system-path
    dep = defaultdict(dict)  # node -> {machine index: dependents}
    roots = []

    def nid(key, name):
        i = key2i.get(key)
        if i is None:
            i = key2i[key] = len(names)
            names.append(name)
            keys.append(key)
            parents.append(set())
            mask.append(0)
        return i

    for mi, m in enumerate(mach):
        g = graphs[m]
        local = list(g)
        loc = {k: j for j, k in enumerate(local)}
        gid = [nid(k, g[k][0]) for k in local]
        children = [[loc[c] for c in g[k][1] if c in loc] for k in local]
        for j, cs in enumerate(children):
            mask[gid[j]] |= 1 << mi
            for c in cs:
                parents[gid[c]].add(gid[j])
            if g[local[j]][0] == "system-path":
                for c in cs:
                    direct[gid[c]] |= 1 << mi
        for j, count in enumerate(dependents_counts(children)):
            dep[gid[j]][mi] = count
        roots.append(key2i[os.path.basename(results[m]["drv"])])

    unmaintained = [i for i, n in enumerate(names) if n in warned]
    data = {
        "title": title,
        "machines": mach,
        "roots": roots,
        "names": names,
        "hash": [k[:8] for k in keys],
        "mask": mask,
        "direct": {str(i): v for i, v in direct.items()},
        "dep": [max(dep[i].values()) for i in range(len(names))],
        "udep": {str(i): [dep[i].get(k, -1) for k in range(len(mach))] for i in unmaintained},
        "file": {str(i): file_entry(warned[names[i]], sources) for i in unmaintained},
        "parents": [sorted(p) for p in parents],
        "meta": {n: meta[n] for n in {names[i] for i in unmaintained} if n in meta},
    }
    return data, len({names[i] for i in unmaintained})


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--flake", default=".", help="flake to inspect (default: .)")
    ap.add_argument(
        "-m",
        "--machine",
        action="append",
        default=[],
        help="only this machine (repeatable; default: all nixos/darwin configurations)",
    )
    ap.add_argument("-o", "--output", default="unmaintained-graph.html", help="output HTML file")
    ap.add_argument("-j", "--jobs", type=int, default=4, help="parallel evaluations (default: 4)")
    ap.add_argument("--title", help="page title (default: derived from the flake)")
    args = ap.parse_args()

    flake = args.flake
    if os.path.exists(flake):
        flake = str(Path(flake).resolve())
    machines = discover(flake)
    if args.machine:
        known = {m for m, _ in machines}
        missing = [m for m in args.machine if m not in known]
        if missing:
            sys.exit(f"unknown machine(s): {', '.join(missing)}")
        machines = [(m, k) for m, k in machines if m in args.machine]
    if not machines:
        sys.exit("no nixosConfigurations/darwinConfigurations found")
    if len(machines) > MAX_MACHINES:
        sys.exit(f"{len(machines)} machines, at most {MAX_MACHINES} supported; pick some with --machine")

    results = {}
    with concurrent.futures.ThreadPoolExecutor(args.jobs) as pool:
        futures = {pool.submit(evaluate, flake, m, k): m for m, k in machines}
        for fut in concurrent.futures.as_completed(futures):
            m = futures[fut]
            try:
                results[m] = fut.result()
            except Exception as e:  # report and keep going with the other machines
                log(f"[skip] {m}: {e}")
                continue
            log(f"[{len(results)}/{len(machines)}] {m}: {len(results[m]['warned'])} unmaintained")
    if not results:
        sys.exit("every evaluation failed")

    warned = {name: path for r in results.values() for name, path in r["warned"]}
    meta = {}
    for r in results.values():
        meta.update((n, v) for n, v in r.pop("meta").items() if n in warned)
    missing = {n: p for n, p in warned.items() if n not in meta}
    if missing:
        first = next(m for m, _ in machines if m in results)
        meta.update(lookup_meta(flake, first, dict(machines)[first], missing))
    log(f"[meta] {len(meta)}/{len(warned)} packages with meta")

    with concurrent.futures.ThreadPoolExecutor(args.jobs) as pool:
        graphs = dict(zip(results, pool.map(lambda m: derivation_graph(results[m]["drv"]), results)))

    title = args.title or f"Unmaintained packages in {Path(flake).name if os.path.isabs(flake) else flake}"
    data, count = build_data(title, results, graphs, meta)

    template = Path(os.environ["UNMAINTAINED_GRAPH_TEMPLATE"]).read_text()
    d3 = Path(os.environ["UNMAINTAINED_GRAPH_D3"]).read_text()
    payload = json.dumps(data, separators=(",", ":")).replace("</", "<\\/")
    Path(args.output).write_text(template.replace("/*D3*/", d3, 1).replace("/*DATA*/", payload, 1))
    log(f"wrote {args.output}: {count} unmaintained packages across {len(results)} machine(s)")


if __name__ == "__main__":
    main()
