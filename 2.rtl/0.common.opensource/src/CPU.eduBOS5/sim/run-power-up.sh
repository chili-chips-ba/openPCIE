#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# eduBOS5 before reset acts, in a 4-state and a 2-state simulator: Icarus
# Verilog (after sv2v, as Icarus does not read `unique if`) and Verilator.
# Both pipelines, `define RISCV_FORMAL (RVFI outputs on).
#
# usage: bash run-power-up.sh
# Needs iverilog/vvp, sv2v and verilator on PATH.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
C=$HERE/..
SRC=("$C"/edubos5_pkg.sv "$C"/edubos5_rf.sv "$C"/edubos5_alu.sv "$C"/edubos5.sv "$HERE"/tb_power_up.sv)
W=$(mktemp -d /tmp/power_up_edubos5.XXXX)
cd "$W"

sv2v -DRISCV_FORMAL "${SRC[@]}" > all.v
for en in 0 1; do
  echo "== Icarus, EN_WAIT4REGS=$en"
  iverilog -g2012 -P tb_power_up.EN_WAIT4REGS=$en -o ivl_$en.vvp all.v
  vvp -n ivl_$en.vvp | grep '^t='
done

for en in 0 1; do
  echo "== Verilator, EN_WAIT4REGS=$en"
  verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -DRISCV_FORMAL \
    -GEN_WAIT4REGS=$en --top-module tb_power_up -Mdir vl_$en "${SRC[@]}" > vl_$en.log 2>&1
  ./vl_$en/Vtb_power_up | grep '^t='
done
echo "work folder: $W"
