#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Convert the VCD that "make run USRSIMOPTS=--define DUMP_VCD" writes into FST
# (GTKWave's compressed format, also read by WaveCrux and Surfer). XSIM writes
# only VCD; tb.fst is the tracked copy, tb.vcd stays local.
#
# usage:  bash 5.sim/tools/vcd2fst.sh [in.vcd [out.fst]]
#         defaults: 5.sim/tb.vcd -> 5.sim/tb.fst
#
# Needs vcd2fst from GTKWave (sudo apt install gtkwave), or VCD2FST set by
# 4.build/set-env.sh.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
IN=${1:-$HERE/../tb.vcd}
OUT=${2:-${IN%.vcd}.fst}
VCD2FST=${VCD2FST:-vcd2fst}

command -v "$VCD2FST" >/dev/null || { echo "vcd2fst.sh: $VCD2FST not found (sudo apt install gtkwave)" >&2; exit 1; }
[ -f "$IN" ] || { echo "vcd2fst.sh: $IN not found" >&2; exit 1; }

# -Z: zlib blocks, smaller than the default lz4
"$VCD2FST" -Z "$IN" "$OUT" >/dev/null ||
    { echo "vcd2fst.sh: cannot write $OUT -- close it in WaveCrux or any other viewer, then: make fst" >&2; exit 1; }
echo "vcd2fst.sh: $(basename "$IN") $(stat -c %s "$IN") B -> $(basename "$OUT") $(stat -c %s "$OUT") B"
