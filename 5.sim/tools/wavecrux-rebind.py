#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Rebind a WaveCrux session to a new FST. A session binds its signal rows,
# decoders and stage widgets by signal number in the file ("ref"), which
# changes when the dumped signals change. This maps each old ref to its path,
# then to the new ref. A ref numbers the FST's signal handles, in the order
# they first appear, not its names: all names of an alias (one net seen from
# several scopes, as Verilator writes interface ports) share one ref.
#
# usage:  python3 wavecrux-rebind.py <session> <new.fst> [<old.fst>] [-r OLD=NEW ...] [-o <out>]
#   <old.fst>    the FST the session was made for; default: the paths in the
#                session's signal rows (enough when every binding is a row)
#   -r OLD=NEW   rename a path prefix, e.g. -r tb.cpu_view=tb_soc.cpu_view
#   -o <out>     write there (default: in place); sourceFilePath becomes the
#                new FST's name
#
# Needs fst2vcd (GTKWave) on PATH.
import argparse, json, os, subprocess, sys

def fst_refs(fst):
    """path -> ref: the number of the path's handle (its VCD id code), in
    the order the handles first appear"""
    vcd = subprocess.run(["fst2vcd", fst], capture_output=True, text=True, check=True).stdout
    refs, handles, scope = {}, {}, []
    for line in vcd.splitlines():
        w = line.split()
        if line.startswith("$enddefinitions"):
            break
        if line.startswith("$scope"):
            scope.append(w[2])
        elif line.startswith("$upscope"):
            scope.pop()
        elif line.startswith("$var"):
            h = handles.setdefault(w[3], str(len(handles)))
            refs.setdefault(".".join(scope + [w[4]]), h)
    return refs

a = argparse.ArgumentParser()
a.add_argument("session"); a.add_argument("new_fst"); a.add_argument("old_fst", nargs="?")
a.add_argument("-r", action="append", default=[]); a.add_argument("-o")
args = a.parse_args()

d = json.load(open(args.session))
new = fst_refs(args.new_fst)
old = ({r: p for p, r in fst_refs(args.old_fst).items()} if args.old_fst
       else {s["ref"]: s["path"] for s in d["signals"]})
ren = [x.split("=", 1) for x in args.r]

def path(p):
    for o, n in ren:
        if p == o or p.startswith(o + "."):
            return n + p[len(o):]
    return p

def remap(r):
    if r not in old:
        sys.exit(f"ref {r} is not in the old FST or the session's rows")
    p = path(old[r])
    if p not in new:
        sys.exit(f"{p} is not in {args.new_fst}")
    return new[p]

for s in d["signals"]:
    s["path"] = path(s["path"])
    s["ref"] = new[s["path"]]
for dec in d.get("decoders", []):
    b = dec["config"]["bindings"]
    for k in b:
        b[k] = remap(b[k])
for panel in d.get("stage", {}).get("panels", []):
    for inst in panel.get("instances", []):
        for b in inst.get("bindings", {}).values():
            b["ref"] = remap(b["ref"])
d["signalTreeState"] = {"expanded": [], "selected": [], "scroll": 0.0}
d["sourceFilePath"] = os.path.basename(args.new_fst)

out = args.o or args.session
json.dump(d, open(out, "w"), indent=2)
open(out, "a").write("\n")
print(f"{out}: {len(d['signals'])} rows, {len(d.get('decoders', []))} decoders")

# -----------------------------------------------------------------------------
# Project:     openPCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        Oct 18, 2026
# -----------------------------------------------------------------------------
