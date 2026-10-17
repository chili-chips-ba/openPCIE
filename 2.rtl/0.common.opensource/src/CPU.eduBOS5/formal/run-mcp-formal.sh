#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Static proof of edubos5.3STG-ONLY.mcp.xdc with Yosys (read_slang) and ABC,
# both in openXC7 v1.0.0 (source 4.build/set-env.sh first).
#
# usage: bash run-mcp-formal.sh [source|miter] [EN_WAIT4REGS] [ABC engine]
#   source  edubos5_mcp_formal.sv: the sources change only at launch, hold 2 clocks,
#           and nothing loads at the 1st edge after it (go2exec)
#   miter   edubos5_mcp_miter.sv:  what is captured at the 1st edge is never used
#           (two cores: slow; use a bounded engine, e.g. "bmc3 -F 12")
#   EN_WAIT4REGS  1 (default): the 3-stage core, must pass
#                 0: the 2-stage core; both must fail (clock 6)
#   engine  pdr (default, unbounded proof), e.g. "bmc3 -F 40" (40 clocks), or
#           print_stats (model size: inputs/asserts, flip-flops, AND gates)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
C=$HERE/..
CHECK=${1:-source}
EN=${2:-1}
ENGINE=${3:-pdr}
case $CHECK in
  source) TOP=edubos5_mcp_formal DEFS="-D EDUBOS5_MCP_FORMAL" ;;
  miter) TOP=edubos5_mcp_miter DEFS="" ;;  # without the core's own checks: B sees junk on purpose
  *) echo "usage: $0 [source|miter] [EN_WAIT4REGS] [ABC engine]" && exit 1 ;;
esac
W=$(mktemp -d)
cd "$W"
# Every flip-flop starts at 0, also the hidden $past ones; the harness then
# resets the core for 2 clocks.
yosys -q -p "read_slang $DEFS -G EN_WAIT4REGS=$EN --top $TOP \
               $C/edubos5_pkg.sv $C/edubos5_rf.sv $C/edubos5_alu.sv $C/edubos5.sv $HERE/$TOP.sv; \
             prep -flatten -top $TOP; memory_map; opt -fast; \
             async2sync; chformal -lower; chformal -assume -early; \
             formalff -clk2ff; setundef -init -zero; opt_clean; \
             techmap; opt -fast; abc -g AND; opt_clean; \
             write_aiger -I -B -zinit model.aig" 2>&1 |
  grep -v "^Warning: Treating .*undriven" || true  # the free inputs: intended
yosys-abc -c "read_aiger model.aig; fold; strash; $ENGINE" |
  grep -E "lat =|Property proved|was asserted|No output asserted|Reached"
rm -rf "$W"

# -----------------------------------------------------------------------------
# Project:     openPCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        May 24, 2024
# -----------------------------------------------------------------------------
