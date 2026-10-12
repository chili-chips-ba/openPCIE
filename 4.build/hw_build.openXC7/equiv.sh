#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Formal equivalence check of pcie_top between two versions of the RTL, with
# the openXC7 v1.0.0 Yosys (read_slang). Use it to prove that a cleanup does
# not change behaviour.
#
# usage:  bash equiv.sh <gold src> <gate src> [sed script]
#   <gold src>, <gate src>  copies of 2.rtl/0.common.opensource/src, e.g.
#                           mkdir -p /tmp/gold && git archive HEAD 2.rtl/0.common.opensource/src | tar -x -C /tmp/gold
#   [sed script]            renames gold objects to their gate names, for a change
#                           that moves logic between modules, e.g.
#                           's|^u_pcie\.u_pcie_core\.u_x\.|u_pcie.u_pcie_core.|'
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
W=$(mktemp -d); cd "$W"

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

# flat-port wrapper, so both versions have the same top-level ports
cat > eq_wrap.sv <<'EOF'
module eq_wrap (
  output [0:0]  pci_exp_txp, pci_exp_txn,
  input  [0:0]  pci_exp_rxp, pci_exp_rxn,
  input         pipe_mmcm_rst_n, sys_clk, sys_rst_n,
  output        user_clk_out, user_reset_out, user_lnk_up,
  input  [63:0] tx_tdata,  input [7:0] tx_tkeep, input [3:0] tx_tuser,
  input         tx_tlast,  input       tx_tvalid, output      tx_tready,
  output [63:0] rx_tdata,  output [7:0] rx_tkeep, output [21:0] rx_tuser,
  output        rx_tlast,  output       rx_tvalid, input        rx_tready,
  output        msg_err_fatal,
  output [5:0]  tx_buf_avail
);
  axis_if #(.DATA_W(64), .USER_W(4))  s_axis_tx ();
  axis_if #(.DATA_W(64), .USER_W(22)) m_axis_rx ();
  cfg_if                              cfg ();

  assign s_axis_tx.tdata  = tx_tdata;
  assign s_axis_tx.tkeep  = tx_tkeep;
  assign s_axis_tx.tuser  = tx_tuser;
  assign s_axis_tx.tlast  = tx_tlast;
  assign s_axis_tx.tvalid = tx_tvalid;
  assign tx_tready        = s_axis_tx.tready;
  assign rx_tdata  = m_axis_rx.tdata;
  assign rx_tkeep  = m_axis_rx.tkeep;
  assign rx_tuser  = m_axis_rx.tuser;
  assign rx_tlast  = m_axis_rx.tlast;
  assign rx_tvalid = m_axis_rx.tvalid;
  assign m_axis_rx.tready = rx_tready;
  assign msg_err_fatal = cfg.msg_err_fatal;
  assign tx_buf_avail  = cfg.tx_buf_avail;

  pcie_top u_pcie (
    .pci_exp_txp, .pci_exp_txn, .pci_exp_rxp, .pci_exp_rxn,
    .pipe_mmcm_rst_n, .user_clk_out, .user_reset_out, .user_lnk_up,
    .s_axis_tx (s_axis_tx), .m_axis_rx (m_axis_rx), .cfg (cfg),
    .sys_clk, .sys_rst_n
  );
endmodule
EOF

files() {  # $1 = src dir
  local P=$1/pcie
  echo bb.sv bram_bb.sv $P/link_pkg.sv $(ls $P/*_if.sv) \
       $(ls $P/*.sv | grep -v -e '_if.sv$' -e 'link_pkg.sv$') eq_wrap.sv "$HERE/xpm_shim.v"
}
BB="t:PCIE_2_1 t:GTPE2_CHANNEL t:GTPE2_COMMON t:MMCME2_ADV t:BUFG t:BUFGCTRL t:IBUFDS_GTE2 t:RAMB36E1 t:BRAM_TDP_MACRO"
PREP="hierarchy -top eq_wrap; proc; flatten; memory; async2sync"

REN=""
if [ -n "$MAP" ]; then   # rename gold objects to their gate names (skip names the gold already has)
  cat > names.ys <<EOF
read_slang -D SYN_YOSYS_BUG --top eq_wrap -I $GOLD/pcie $(files $GOLD)
$PREP
tee -q -o names.txt select -list eq_wrap/w:* eq_wrap/c:*
EOF
  yosys -q names.ys >/dev/null
  sed 's|^eq_wrap/||' names.txt | sed -n "h; $MAP; G; s/\n/ /; p" |
    awk 'NR==FNR {have[$1]=1; next} $1!=$2 && substr($2,1,1)!="$" && !($1 in have) {print "rename \\" $2 " \\" $1}' \
        <(sed 's|^eq_wrap/||' names.txt) - > ren.ys
  echo "renamed: $(wc -l < ren.ys)"
  REN="cd eq_wrap; script ren.ys; cd .."
fi

cat > eq.ys <<EOF
read_slang -D SYN_YOSYS_BUG --top eq_wrap -I $GOLD/pcie $(files $GOLD)
$PREP
$REN
expose -evert $BB; opt_clean; rename eq_wrap gold; design -stash gold
read_slang -D SYN_YOSYS_BUG --top eq_wrap -I $GATE/pcie $(files $GATE)
$PREP
expose -evert $BB; opt_clean; rename eq_wrap gate; design -stash gate
design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
equiv_make gold gate eq
hierarchy -top eq
equiv_simple -seq 3
equiv_induct -seq 3
equiv_status
EOF
yosys -q -l eq.log eq.ys >/dev/null || true
grep -E "Found [0-9]+ .equiv|Of those cells|^ERROR" eq.log | tail -3
grep "Unproven" eq.log | sed -E 's/.*: .([^ ]*)_gold.*/\1/; s/\[[0-9]+\]//g' | sort | uniq -c
echo "log: $W/eq.log"
