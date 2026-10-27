#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Upgrade the co-simulation models in 5.sim/models from their upstream sources
# (github.com/wyvernSemi): VProc, pcievhost, mem_model, rv32. Builds the Linux
# libraries (rv32: copies its sources), copies headers and HDL, and re-applies
# our local changes (see 5.sim/README.md, "Local changes"). rv32 is used at a
# commit past its last tag, so pass RV32_REF to keep it.
#
# usage:  bash 5.sim/tools/vip-upgrade.sh          latest tag of each model
#         VPROC_REF=VERSION_1_13_4 PCIEVHOST_REF=... MEM_MODEL_REF=main \
#         RV32_REF=774d84fa bash 5.sim/tools/vip-upgrade.sh
#
# Upstream clones go to VIP_WORK (default ~/.cache/openpcie-vip). Needs git,
# gcc, g++, make, sed, patch. Afterwards: build VProc.so for CPU=rtl, vproc
# and iss, run "make run", update the version table in 5.sim/README.md, and
# review the diff before committing.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
M=$HERE/../models
W=${VIP_WORK:-$HOME/.cache/openpcie-vip}
mkdir -p "$W"

# clone or update a repo, check out $2 (default: its newest tag); prints the ref.
# It runs in $(...), where set -e does not stop the script, so each step
# checks itself and fetch_ref below stops on a failure.
fetch() {
    local repo=$1 ref=${2:-}
    if [ ! -d "$W/$repo" ]; then
        git clone -q "https://github.com/wyvernSemi/$repo.git" "$W/$repo" || return 1
    fi
    git -C "$W/$repo" fetch -q --tags origin || return 1
    git -C "$W/$repo" checkout -q -- . || return 1  # drop a patch from the last run
    [ -n "$ref" ] || ref=$(git -C "$W/$repo" tag --sort=-creatordate | head -1)
    [ -n "$ref" ] || { echo "$repo: no tag found" >&2; return 1; }
    git -C "$W/$repo" checkout -q "$ref" || return 1
    echo "$ref"
}
fetch_ref() { fetch "$@" || { echo "vip-upgrade: fetching $1 failed" >&2; exit 1; }; }

lf() { tr -d '\r' < "$1"; }  # upstream mixes CRLF and LF; we keep LF

VPROC_REF=$(fetch_ref vproc "${VPROC_REF:-}") || exit 1
PCIEVHOST_REF=$(fetch_ref pcievhost "${PCIEVHOST_REF:-}") || exit 1
MEM_MODEL_REF=$(fetch_ref mem_model "${MEM_MODEL_REF:-}") || exit 1
RV32_REF=$(fetch_ref rv32 "${RV32_REF:-}") || exit 1
echo "VProc $VPROC_REF, pcievhost $PCIEVHOST_REF, mem_model $MEM_MODEL_REF, rv32 $RV32_REF"

O=$(mktemp -d)
trap 'rm -rf "$O"' EXIT

# ---- VProc: libcosimlnx.a (DPI build) and its headers/HDL ------------------
V=$W/vproc
for f in VSched VUser; do
    gcc -c -fPIC -m64 -I"$V/code" -DVPROC_SV "$V/code/$f.c" -o "$O/$f.o"
done
rm -f "$M/cosim/lib/libcosimlnx.a"
ar cr "$M/cosim/lib/libcosimlnx.a" "$O"/VSched.o "$O"/VUser.o
for f in VProc.h VProcClass.h VProcIrqClass.h VSched_pli.h VUser.h; do
    lf "$V/code/$f" > "$M/cosim/include/$f"
done
for f in f_VProc.v extradefs.v vprocdefs.vh vprocdpi.vh; do lf "$V/$f" > "$M/cosim/$f"; done

# ---- mem_model: HDL only (its C model is in pcievhost); mem_model.sv is ours
lf "$W/mem_model/mem_model.v" > "$M/cosim/f_mem_model.v"
lf "$W/mem_model/mem_model_dpi.vh" > "$M/cosim/mem_model_dpi.vh"

# ---- pcievhost: libpcielnx.a, headers, HDL ---------------------------------
P=$W/pcievhost
# local change: transaction taps, TLP and DLLP ports (models/pcievhost/README.md),
# on LF copies of the files it changes
for f in src/displink.c src/pcie_vhost_map.h verilog/pcieVHost/pcieVHost.v verilog/pcieVHost/pcieVHostPipex1.v; do
    sed -i 's/\r$//' "$P/$f"
done
if ! patch -s --no-backup-if-mismatch -p1 -d "$P" < "$M/pcievhost/pcievhost-taps.patch"; then
    echo "ERROR: pcievhost-taps.patch no longer applies to pcievhost $PCIEVHOST_REF."
    exit 1
fi
for f in codec mem pcie pcie_utils pcicrc32 displink; do
    gcc -c -fPIC -m64 -I"$V/code" -DVPROC_SV -DLTSSM_ABBREVIATED "$P/src/$f.c" -o "$O/$f.o"
done
rm -f "$M/pcievhost/lib/libpcielnx.a"
ar cr "$M/pcievhost/lib/libpcielnx.a" "$O"/{codec,mem,pcie,pcie_utils,pcicrc32,displink}.o
for f in codec.h mem.h pci_express.h pcie.h pcieModelClass.h pcie_utils.h pcie_vhost_map.h; do
    lf "$P/src/$f" > "$M/pcievhost/include/$f"
done
H=$M/pcievhost/verilog/headers
for f in allheaders.v pciedispheader.v pciexpress_header.v timescale.v; do
    lf "$P/verilog/headers/$f" > "$H/$f"
done
# register map, generated from the C header as upstream's makefiles do
lf "$P/src/pcie_vhost_map.h" |
    sed "s/0x/32'h/;s/#/\`/;s/DEFINES/AUTO GENERATED. DO NOT EDIT!/;" > "$H/pcie_vhost_map.v"
# local change: our test bench top is tb
lf "$P/verilog/test/test_defs.v" | sed 's/`define fatal test\.Fatal;/`define fatal tb.Fatal;/' > "$H/test_defs.v"
grep -q 'define fatal tb\.Fatal' "$H/test_defs.v"
for f in pcieVHost.v pcieVHostPipex1.v; do
    lf "$P/verilog/pcieVHost/$f" > "$M/pcievhost/verilog/pcieVHost/$f"
done
# local change: VProc byte-enable/burst ports, left open (we build VProc with
# VPROC_BYTE_ENABLE)
F=$M/pcievhost/verilog/pcieVHost/pcieVHost.v
grep -qE '^\s*\.RD\s*\(RD\),$' "$F"
sed -i -E '/^\s*\.RD\s*\(RD\),$/a\
`ifdef VPROC_BYTE_ENABLE\
           .BE             (),\
`endif\
`ifdef VPROC_BURST_IF\
           .Burst          (),\
           .BurstFirst     (),\
           .BurstLast      (),\
`endif' "$F"

# local change: LTSSM fixes, kept as a patch on upstream ltssm.c
L=$M/pcievhost/ltssm
lf "$P/src/ltssm.h" > "$L/ltssm.h"
lf "$P/src/ltssm.c" > "$L/ltssm.c.orig"
cp "$L/ltssm.c.orig" "$L/ltssm.c"
if ! patch -s --no-backup-if-mismatch "$L/ltssm.c" < "$L/ltssm-openpcie.patch"; then
    echo "ERROR: ltssm-openpcie.patch no longer applies to pcievhost $PCIEVHOST_REF."
    echo "       Port the fixes by hand into $L/ltssm.c, then regenerate the patch:"
    echo "       diff -u ltssm.c.orig ltssm.c > ltssm-openpcie.patch"
    exit 1
fi

# ---- rv32: library sources (5.sim/Makefile builds the library) -------------
# Only the files in models/rv32/src are refreshed; a file upstream adds to the
# library must be added there and to RV32_CPP in 5.sim/Makefile by hand.
R=$W/rv32/iss
for f in "$M"/rv32/src/*; do
    src="$R/src/$(basename "$f")"
    [ -f "$src" ] && lf "$src" > "$f" || echo "note: $(basename "$f") not in rv32 $RV32_REF, kept"
done
if ! patch -s --no-backup-if-mismatch -p0 -d "$M/rv32/src" < "$M/rv32/rv32-openpcie.patch"; then
    echo "ERROR: rv32-openpcie.patch no longer applies to rv32 $RV32_REF."
    echo "       Port the fixes by hand into models/rv32/src, then regenerate the patch."
    exit 1
fi

echo "Done. Next: build VProc.so for CPU=rtl/vproc/iss, make run, update the"
echo "version table in 5.sim/README.md, review the diff."

# -----------------------------------------------------------------------------
# Project:     openPCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        May 24, 2024
# -----------------------------------------------------------------------------
