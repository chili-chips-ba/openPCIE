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

module gtp_wrapper
  import link_pkg::*;
(
    input                           PIPE_CLK,          // 100 MHz refclk (IBUFDS_GTE2)
    input                           PIPE_RESET_N,

    pipe_if.phy                     pipe_phy,          // 32-bit PIPE from phy_top (see pipe_if.sv)

    output      [PCIE_LANES-1:0]    PIPE_TXP,
    output      [PCIE_LANES-1:0]    PIPE_TXN,
    input       [PCIE_LANES-1:0]    PIPE_RXP,
    input       [PCIE_LANES-1:0]    PIPE_RXN,

    output      [PCIE_LANES-1:0]    PIPE_PHYSTATUS_RST,

    input                           PIPE_PCLK_IN,
    input                           PIPE_RXUSRCLK_IN,
    input                           PIPE_DCLK_IN,
    input                           PIPE_OOBCLK_IN,
    input                           PIPE_MMCM_LOCK_IN,

    output                          PIPE_TXOUTCLK_OUT,
    output      [PCIE_LANES-1:0]    PIPE_PCLK_SEL_OUT
);

  wire clk_pclk      = PIPE_PCLK_IN;
  wire clk_rxusrclk  = PIPE_RXUSRCLK_IN;
  wire clk_dclk      = PIPE_DCLK_IN;
  wire clk_oobclk    = PIPE_OOBCLK_IN;
  wire clk_mmcm_lock = PIPE_MMCM_LOCK_IN;

  wire pll0_outclk, pll0_outrefclk, pll0_lock;
  wire rst_pllpd, rst_pllreset;

  gtp_if #(.LANES(PCIE_LANES)) gtp ();

  // ---- PIPE_RESET_N synchroniser
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic reset_n_reg1, reset_n_reg2;

  always_ff @(posedge clk_pclk or negedge PIPE_RESET_N) begin
    if (!PIPE_RESET_N) begin
      reset_n_reg1 <= 1'd0;
      reset_n_reg2 <= 1'd0;
    end else begin
      reset_n_reg1 <= 1'd1;
      reset_n_reg2 <= reset_n_reg1;
    end
  end

  // ---- GT and PLL reset sequencing
  init_ctrl u_init_ctrl (
    .RST_CLK            (clk_pclk),
    .RST_RXUSRCLK       (clk_rxusrclk),
    .RST_DCLK           (clk_dclk),
    .RST_RST_N          (reset_n_reg2),
    .RST_DRP_DONE       (gtp.drp_done),
    .RST_RXPMARESETDONE (gtp.rxpmaresetdone),
    .RST_PLLLOCK        (pll0_lock),
    .RST_RATE_IDLE      (gtp.rate_idle),
    .RST_MMCM_LOCK      (clk_mmcm_lock),
    .RST_RESETDONE      (gtp.resetdone),
    .RST_PHYSTATUS      (gtp.phystatus),
    .RST_TXSYNC_DONE    (gtp.txsync_done),

    .RST_CPLLRESET      (gtp.rst_cpllreset),
    .RST_PLLPD          (rst_pllpd),
    .RST_PLLRESET       (rst_pllreset),
    .RST_RXUSRCLK_RESET (gtp.rst_rxusrclk_reset),
    .RST_DCLK_RESET     (gtp.rst_dclk_reset),
    .RST_GTRESET        (gtp.rst_gtreset),
    .RST_DRP_START      (gtp.rst_drp_start),
    .RST_DRP_X16        (gtp.rst_drp_x16),
    .RST_USERRDY        (gtp.rst_userrdy),
    .RST_TXSYNC_START   (gtp.rst_txsync_start),
    .RST_IDLE           (gtp.rst_idle)
  );

  // ---- GTPE2_COMMON: PLL0 feeds all lanes (PCIE_LANES <= 4, one quad)
  GTPE2_COMMON #
  (
      .SIM_PLL0REFCLK_SEL             (3'b001),
      .SIM_PLL1REFCLK_SEL             (3'b001),
      .SIM_RESET_SPEEDUP              ("FALSE"),
      .SIM_VERSION                    ("1.0"),

      // FIXME: openXC7 ignores these and writes 0x1F03DC (openPCIE #18); the
      // board-proven openXC7 bitstream runs on that value, not on this one.
      // Test on hardware before relying on a fixed nextpnr.
      .PLL0_CFG                       (27'h01F024C),
      .PLL1_CFG                       (27'h01F024C),
      .PLL_CLKOUT_CFG                 (8'd0),
      .PLL0_DMON_CFG                  (1'b0),
      .PLL1_DMON_CFG                  (1'b0),
      .PLL0_FBDIV                     (5),
      .PLL1_FBDIV                     (5),
      .PLL0_FBDIV_45                  (5),
      .PLL1_FBDIV_45                  (5),
      .PLL0_INIT_CFG                  (24'h00001E),
      .PLL1_INIT_CFG                  (24'h00001E),
      .PLL0_LOCK_CFG                  ( 9'h1E8),
      .PLL1_LOCK_CFG                  ( 9'h1E8),
      .PLL0_REFCLK_DIV                (1),
      .PLL1_REFCLK_DIV                (1),

      .BIAS_CFG                       (64'h0000000000050001),
      .RSVD_ATTR0                     (16'd0),
      .RSVD_ATTR1                     (16'd0)

  )
  u_gtpe2_common
  (
      .GTGREFCLK0                     (     ),
      .GTGREFCLK1                     (     ),
      .GTREFCLK0                      (PIPE_CLK),
      .GTREFCLK1                      (     ),
      .GTEASTREFCLK0                  (     ),
      .GTEASTREFCLK1                  (     ),
      .GTWESTREFCLK0                  (     ),
      .GTWESTREFCLK1                  (     ),
      .PLL0LOCKDETCLK                 ( 1'd0),
      .PLL1LOCKDETCLK                 ( 1'd0),
      .PLL0LOCKEN                     ( 1'd1),
      .PLL1LOCKEN                     ( 1'd1),
      .PLL0REFCLKSEL                  ( 3'd1),
      .PLL1REFCLKSEL                  ( 3'd1),
      .PLLRSVD1                       ('0),
      .PLLRSVD2                       ('0),

      .PLL0OUTCLK                     (pll0_outclk),
      .PLL1OUTCLK                     (),
      .PLL0OUTREFCLK                  (pll0_outrefclk),
      .PLL1OUTREFCLK                  (),
      .PLL0LOCK                       (pll0_lock),
      .PLL1LOCK                       (),
      .PLL0FBCLKLOST                  (),
      .PLL1FBCLKLOST                  (),
      .PLL0REFCLKLOST                 (),
      .PLL1REFCLKLOST                 (),
      .DMONITOROUT                    (),

      .PLL0PD                         (rst_pllpd),
      .PLL1PD                         ( 1'd1),
      .PLL0RESET                      (rst_pllreset),
      .PLL1RESET                      ( 1'd1),

      .DRPCLK                         ( 1'd0),
      .DRPADDR                        ('0),
      .DRPEN                          ( 1'd0),
      .DRPDI                          ('0),
      .DRPWE                          ( 1'd0),

      .DRPDO                          (),
      .DRPRDY                         (),

      .BGBYPASSB                      ( 1'd1),
      .BGMONITORENB                   ( 1'd1),
      .BGPDB                          ( 1'd1),
      .BGRCALOVRD                     ('1),
      .BGRCALOVRDENB                  ( 1'd1),

      .PMARSVD                        ('0),
      .RCALENB                        ( 1'd1),

      .REFCLKOUTMONITOR0              (),
      .REFCLKOUTMONITOR1              (),
      .PMARSVDOUT                     ()
  );

  // ---- cross-lane: TX/RX buffer-bypass phase alignment, lane 0 is the master
  assign gtp.txsyncallin         = &(gtp.txphaligndone | ~gtp.active_lane);
  assign gtp.rxsyncallin         = &(gtp.rxphaligndone | ~gtp.active_lane);
  assign gtp.txphinitdone_all    = &(gtp.txphinitdone  | ~gtp.active_lane);
  assign gtp.txdlysresetdone_all = &gtp.txdlysresetdone;
  assign gtp.rxdlysresetdone_all = &gtp.rxdlysresetdone;
  assign gtp.rxphaligndone_m     = gtp.rxphaligndone[0];
  if (PCIE_LANES == 1) begin : one_lane
    assign gtp.rxphaligndone_s   = 1'b0;
  end else begin : multi_lane
    assign gtp.rxphaligndone_s   = &gtp.rxphaligndone[PCIE_LANES-1:1];
  end
  assign gtp.rxsync_donem_m      = gtp.rxsync_donem[0];
  assign gtp.txsyncin            = gtp.txsyncout[0];
  assign gtp.rxsyncin            = gtp.rxsyncout[0];

  // ---- one lane_xcvr per lane; channel bonding chain lane 0 -> 1 -> ...
  for (genvar i = 0; i < PCIE_LANES; i++) begin : lane_gen
    if (i == 0) begin : chbond_head
      assign gtp.rxchbondi[i] = 4'd0;
    end else begin : chbond_chain
      assign gtp.rxchbondi[i] = gtp.rxchbondo[i-1];
    end

    lane_xcvr #(.LANE(i)) u_xcvr (
      .clk_pclk       (clk_pclk),
      .clk_rxusrclk   (clk_rxusrclk),
      .clk_dclk       (clk_dclk),
      .clk_oobclk     (clk_oobclk),
      .clk_mmcm_lock  (clk_mmcm_lock),
      .pll0_outclk    (pll0_outclk),
      .pll0_outrefclk (pll0_outrefclk),
      .pipe_phy       (pipe_phy),
      .gtp            (gtp),
      .gt_txp         (PIPE_TXP[i]),
      .gt_txn         (PIPE_TXN[i]),
      .gt_rxp         (PIPE_RXP[i]),
      .gt_rxn         (PIPE_RXN[i])
    );
  end

  wire [PCIE_LANES-1:0] gt_txoutclk = gtp.txoutclk;    // openxc7.xdc creates the txoutclk clock on this net

  assign PIPE_PHYSTATUS_RST = gtp.phystatus_rst;
  assign PIPE_TXOUTCLK_OUT  = gt_txoutclk[0];
  assign PIPE_PCLK_SEL_OUT  = gtp.pclk_sel;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
