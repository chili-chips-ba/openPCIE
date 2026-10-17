#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# riscv-formal on eduBOS5: SymbiYosys with the Yosys (read_slang) and ABC of
# openXC7 v1.0.0 (source 4.build/set-env.sh first).
#
# usage: RISCV_FORMAL=<riscv-formal clone> [LEGAL=1] bash run-riscv-formal.sh [EN_WAIT4REGS] [jobs] [checks]
#   LEGAL=1       assume legal, aligned code (rvfi_wrapper.sv): eduBOS5 has no traps
#   EN_WAIT4REGS  0 (default): the 2-stage core; 1: the 3-stage core
#   jobs          parallel checks (default: all CPUs)
#   checks        make targets, e.g. "insn_add_ch0 reg_ch0" (default: all)
# Results: the work folder printed at the end, one folder per check.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
C=$HERE/..
RVF=${RISCV_FORMAL:?set RISCV_FORMAL to a riscv-formal clone}
EN=${1:-0}
JOBS=${2:-$(nproc)}
CHECKS=${3:-}
W=$(mktemp -d /tmp/rvf_edubos5_$EN.XXXX)
ln -s "$RVF/checks" "$RVF/insns" "$W/"
mkdir -p "$W/cores/edubos5"
cp "$C"/edubos5_pkg.sv "$C"/edubos5_rf.sv "$C"/edubos5_alu.sv "$C"/edubos5.sv \
   "$HERE/rvfi_wrapper.sv" "$W/cores/edubos5/"
sed "s/@slang_defs@/-G EN_WAIT4REGS=$EN/" "$HERE/checks.cfg" > "$W/cores/edubos5/checks.cfg"
if [ "${LEGAL:-0}" = 1 ]; then
  sed -i '/^\[defines\]$/a `define EDUBOS5_LEGAL_CODE' "$W/cores/edubos5/checks.cfg"
fi
cd "$W/cores/edubos5"
python3 "$RVF/checks/genchecks.py" > /dev/null
# "skip" (start checking late) is for SMT engines only; z3 replays a failure
sed -i -e "/^skip /d" -e "/^mode bmc$/a aigsmt z3" checks/*.sby
sed -i "s/^abc bmc3$/smtbmc z3/" checks/cover.sby  # ABC has no cover mode
make -C checks -k -j"$JOBS" $CHECKS > make.log 2>&1 || true
for d in checks/*/; do
  s=$(cat "$d/status" 2>/dev/null || echo "NONE")
  echo "$(basename "$d") $s"
done | sort -k2 | awk '{print} {n[$2]++} END {for (s in n) printf "== %s: %d\n", s, n[s]}'
echo "work folder: $W/cores/edubos5"
