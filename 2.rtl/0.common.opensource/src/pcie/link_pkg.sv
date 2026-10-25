// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openPCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
//                   Copyright (C) 2026 Chili.CHIPS
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
// contributors may be used to endorse or promote products derived
// from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
// IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//              https://opensource.org/license/bsd-3-clause
//--------------------------------------------------------------------------

// Link width: 4 (default) or 1, set by the build with  PCIE_LANES=1 / =4.
// x4 runs only on the direct link: RC-switched is x1.
`ifndef PCIE_LANES
`define PCIE_LANES 4
`endif

// Link speed: 1 (Gen1) or 2 (Gen2), set by the build with  PCIE_GEN=1 / =2.
// Default (0): Gen1 at x4 (x4 Gen2 closes timing in Vivado only), Gen2 at x1.
// Width and speed set the user clock (pcie_pkg.sv).
`ifndef PCIE_GEN
`define PCIE_GEN 0
`endif

package link_pkg;

  localparam int PCIE_LANES = `PCIE_LANES;

  // Link speed: 1 = Gen1, 2 = Gen2.
  //
  // SIM_GEN1_ONLY pins it to Gen1 for co-simulation. The pcievhost endpoint VIP
  // advertises Gen1 in its training sequences and its LTSSM helper hands control
  // back to the user program once L0 is reached, so it cannot follow the RC into
  // Recovery.Speed for a Gen1 -> Gen2 change: the RC would sit in Recovery until
  // it times out. Only the simulation file list defines it.
`ifdef SIM_GEN1_ONLY
  localparam int PCIE_GEN = 1;
`else
  localparam int PCIE_GEN = (`PCIE_GEN != 0) ? `PCIE_GEN : (PCIE_LANES == 4) ? 1 : 2;
`endif

  localparam int PIPE_MAX_LANES = 8;


  typedef struct packed {
    logic [1:0]  char_is_k;
    logic [15:0] data;
    logic        compliance;
    logic        elec_idle;
    logic [1:0]  powerdown;
  } pipe_tx_lane_t;

  typedef struct packed {
    logic [1:0]  char_is_k;
    logic [15:0] data;
    logic        valid;
    logic        chanisaligned;
    logic [2:0]  status;
    logic        phy_status;
    logic        elec_idle;
  } pipe_rx_lane_t;

  typedef struct packed {
    logic       rcvr_det;
    logic       reset;
    logic       rate;
    logic       deemph;
    logic [2:0] margin;
  } pipe_tx_ctrl_t;

  localparam pipe_rx_lane_t PIPE_RX_LANE_RST = '{
      char_is_k: 2'b00,
      data: 16'h0,
      valid: 1'b0,
      chanisaligned: 1'b0,
      status: 3'b000,
      phy_status: 1'b0,
      elec_idle: 1'b0
  };
  localparam pipe_tx_lane_t PIPE_TX_LANE_RST = '{
      char_is_k: 2'b00,
      data: 16'h0,
      compliance: 1'b0,
      elec_idle: 1'b1,
      powerdown: 2'b10
  };
  localparam pipe_tx_ctrl_t PIPE_TX_CTRL_RST = '{
      rcvr_det: 1'b0,
      reset: 1'b1,
      rate: 1'b0,
      deemph: 1'b1,
      margin: 3'b000
  };

  localparam pipe_rx_lane_t PIPE_RX_LANE_TIE = '{
      char_is_k: 2'b00,
      data: 16'h0,
      valid: 1'b0,
      chanisaligned: 1'b0,
      status: 3'b000,
      phy_status: 1'b0,
      elec_idle: 1'b1
  };
  typedef struct packed {
    logic [15:0] status;
    logic [15:0] command;
    logic [15:0] dstatus;
    logic [15:0] dcommand;
    logic [15:0] lstatus;
    logic [15:0] lcommand;
    logic [15:0] dcommand2;
  } cfg_regs_t;

  // GTP reset sequencing from init_ctrl, common to all lanes
  typedef struct packed {
    logic gtpll0_reset;    // PLL / lane logic reset
    logic rxusrclk_reset;
    logic drp_clk_reset;
    logic gtreset;         // GTTXRESET, GTRXRESET
    logic drp_start;       // start the DRP rate retune
    logic drp_x16;         // ... to the 16-bit internal width
    logic userrdy;         // TXUSERRDY, RXUSERRDY
    logic txsync_start;    // start TX phase alignment
    logic idle;            // sequence done
  } gtp_rst_t;

  // GTPE2_CHANNEL dynamic reconfiguration port (DRP), from chan_retune
  typedef struct packed {
    logic [8:0]  addr;  // DRPADDR
    logic        en;    // DRPEN
    logic [15:0] di;    // DRPDI
    logic        we;    // DRPWE
  } gtp_drp_req_t;

  typedef struct packed {
    logic [15:0] dout;  // DRPDO
    logic        rdy;   // DRPRDY
  } gtp_drp_rsp_t;

  // Gen1 / Gen2 rate change of one lane, from speed_ctrl
  typedef struct packed {
    logic       pipe_clk_sel;  // PIPE clock: 0 = 125 MHz (Gen1), 1 = 250 MHz (Gen2)
    logic       drp_start;     // start the DRP retune
    logic       drp_x16;       // ... to the 16-bit internal width
    logic [2:0] rate;          // TXRATE / RXRATE
    logic       txsync_start;  // start TX phase alignment
    logic       done;
    logic       idle;
  } gtp_rate_t;

  // GTP TX buffer-bypass phase alignment (UG482): control from phase_align
  // to the GTPE2_CHANNEL, status from the channels (all active lanes)
  typedef struct packed {
    logic dlysreset;  // TXDLYSRESET
    logic phinit;     // TXPHINIT
    logic phalign;    // TXPHALIGN
    logic dlyen;      // TXDLYEN
  } gtp_txsync_ctrl_t;

  typedef struct packed {
    logic phinitdone;     // TXPHINITDONE
    logic dlysresetdone;  // TXDLYSRESETDONE
    logic phaligndone;    // TXPHALIGNDONE
  } gtp_txsync_stat_t;

endpackage
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
