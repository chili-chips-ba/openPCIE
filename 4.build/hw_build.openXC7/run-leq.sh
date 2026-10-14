#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Formal equivalence check of the whole opensource design (top RC_opensource:
# PCIE stack, SOC, CPU, CSR) between two versions of the RTL, with the openXC7
# v1.0.0 Yosys (read_slang). Use it to prove that a cleanup does not change
# behaviour.
#
# usage:  bash run-leq.sh <gold src> <gate src> [sed script]
#         LANES=1 bash run-leq.sh ...         compare the x1 build (default x4)
#         LEQ_EXTRA=<file> bash run-leq.sh ... Yosys commands run after equiv_make,
#                                              e.g. equiv_add for registers that
#                                              were regrouped into a struct
#                                              (gold: name_gold, gate: name_gate):
#           cd eq
#           equiv_add -try \u_x.ng_cur_state_gold \u_x.ng_q_gate[12]
#           cd ..
#   <gold src>, <gate src>  copies of 2.rtl/0.common.opensource/src, e.g.
#                           mkdir -p /tmp/gold && git archive HEAD 2.rtl/0.common.opensource/src | tar -x -C /tmp/gold
#   [sed script]            renames gold objects to their gate names, for a change
#                           that moves logic between modules, e.g.
#                           's|^u_pcie\.u_core\.u_x\.|u_pcie.u_core.|'
#
# Both versions use the same generated CSR (4.build/csr_build/generated-files)
# and the same firmware.hex (4.build/sw_build) for the RAM contents.
#
# The Xilinx hard macros and the BRAM macro are black boxes turned into ports
# (expose -evert): their inputs are compared, their outputs are shared free
# inputs. equiv_induct starts from any state, so logic that is only constant
# after reset shows up as unproven and needs a look by hand.
#
# Needs yosys from openXC7 v1.0.0 on the PATH (source its export.sh).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
GOLD=$(cd "$1" && pwd); GATE=$(cd "$2" && pwd); MAP=${3:-}
CSR=$HERE/../csr_build/generated-files
TOP=RC_opensource
LANES=${LANES:-4}
W=$(mktemp -d); cd "$W"
cp "$HERE/../sw_build/firmware.hex" .

python3 "$HERE/gen_xilinx_bb.py" "$(yosys-config --datdir)/xilinx" bb.sv \
  PCIE_2_1 GTPE2_CHANNEL GTPE2_COMMON MMCME2_ADV IBUFDS_GTE2 BUFG BUFGCTRL RAMB36E1 >/dev/null

cat > bram_bb.sv <<'EOF'
(* blackbox *)
module BRAM_TDP_MACRO #(
  parameter BRAM_SIZE = "36Kb", parameter DEVICE = "7SERIES",
  parameter DOA_REG = 0, parameter DOB_REG = 0,
  parameter READ_WIDTH_A = 1, parameter READ_WIDTH_B = 1,
  parameter WRITE_WIDTH_A = 1, parameter WRITE_WIDTH_B = 1,
  parameter WRITE_MODE_A = "WRITE_FIRST", parameter WRITE_MODE_B = "WRITE_FIRST",
  localparam WE_W = (WRITE_WIDTH_A <= 9) ? 1 : (WRITE_WIDTH_A <= 18) ? 2 : (WRITE_WIDTH_A <= 36) ? 4 : 8
) (
  output [READ_WIDTH_A-1:0] DOA,  output [READ_WIDTH_B-1:0] DOB,
  input  [15:0] ADDRA, input [15:0] ADDRB, input CLKA, input CLKB,
  input  [WRITE_WIDTH_A-1:0] DIA, input [WRITE_WIDTH_B-1:0] DIB,
  input  ENA, input ENB, input REGCEA, input REGCEB, input RSTA, input RSTB,
  input  [WE_W-1:0] WEA, input [WE_W-1:0] WEB
);
endmodule
EOF

# FDCE is a plain flop, not a black box: model it so that LEQ compares it like
# any other register (the design's reset source in clk_rst_gen)
cat > fdce.sv <<'EOF'
module FDCE #(parameter logic INIT = 1'b0) (output logic Q, input logic C, CE, CLR, D);
  always_ff @(posedge C or posedge CLR)
    if (CLR)     Q <= 1'b0;
    else if (CE) Q <= D;
endmodule
EOF

files() {  # $1 = src dir; same order as SV_ORDERED in the Makefile
  local P=$1/pcie
  echo bb.sv bram_bb.sv fdce.sv $P/link_pkg.sv $P/pcie_pkg.sv "$CSR/csr_pkg.sv" $(ls $P/*_if.sv) \
       $(ls $P/*.sv | grep -v -e '_if.sv$' -e '_pkg.sv$') \
       "$CSR/csr.sv" $1/soc_csr.sv $1/picorv32.CHILI.sv $1/riscv_pcie_soc.sv $1/$TOP.sv
}
BB="t:PCIE_2_1 t:GTPE2_CHANNEL t:GTPE2_COMMON t:MMCME2_ADV t:BUFG t:BUFGCTRL t:IBUFDS_GTE2 t:RAMB36E1 t:BRAM_TDP_MACRO"
PREP="hierarchy -top $TOP; proc; flatten; memory; async2sync"

REN=""
if [ -n "$MAP" ]; then   # rename gold objects to their gate names (skip names the gold already has)
  cat > names.ys <<EOF
read_slang -D SYN_YOSYS_BUG -D PCIE_LANES=$LANES --top $TOP -I $GOLD/pcie -I $GOLD $(files $GOLD)
$PREP
tee -q -o names.txt select -list $TOP/w:* $TOP/c:*
EOF
  yosys -q names.ys >/dev/null
  sed "s|^$TOP/||" names.txt | sed -n "h; $MAP; G; s/\n/ /; p" |
    awk 'NR==FNR {have[$1]=1; next} $1!=$2 && substr($2,1,1)!="$" && !($1 in have) {print "rename \\" $2 " \\" $1}' \
        <(sed "s|^$TOP/||" names.txt) - > ren.ys
  echo "renamed: $(wc -l < ren.ys)"
  REN="cd $TOP; script ren.ys; cd .."
fi

EXTRA=""
[ -n "${LEQ_EXTRA:-}" ] && EXTRA="script $(cd "$(dirname "$LEQ_EXTRA")" && pwd)/$(basename "$LEQ_EXTRA")"

cat > eq.ys <<EOF
read_slang -D SYN_YOSYS_BUG -D PCIE_LANES=$LANES --top $TOP -I $GOLD/pcie -I $GOLD $(files $GOLD)
$PREP
$REN
expose -evert $BB; opt_clean; rename $TOP gold; design -stash gold
read_slang -D SYN_YOSYS_BUG -D PCIE_LANES=$LANES --top $TOP -I $GATE/pcie -I $GATE $(files $GATE)
$PREP
expose -evert $BB; opt_clean; rename $TOP gate; design -stash gate
design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
equiv_make gold gate eq
hierarchy -top eq
$EXTRA
equiv_simple -seq 3
equiv_induct -seq 3
equiv_status
EOF
yosys -q -l eq.log eq.ys >/dev/null || true
grep -E "Found [0-9]+ .equiv|Of those cells|^ERROR" eq.log | tail -3
grep "Unproven" eq.log | sed -E 's/.*: .([^ ]*)_gold.*/\1/; s/\[[0-9]+\]//g' | sort | uniq -c
echo "log: $W/eq.log"
