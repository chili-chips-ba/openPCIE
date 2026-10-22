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
    input logic refclk_p,   // 100 MHz PCIE REFCLK+
    input logic refclk_n,   // REFCLK-
    input logic rst125_n,   // released on clk125
    input logic pipe_rst_n, // released on pipe_clk

    pipe_if.phy pipe,  // 32-bit PIPE from phy_top (see pipe_if.sv)

    output logic [PCIE_LANES-1:0] txp,
    output logic [PCIE_LANES-1:0] txn,
    input  logic [PCIE_LANES-1:0] rxp,
    input  logic [PCIE_LANES-1:0] rxn,

    output logic [PCIE_LANES-1:0] phystatus_rst,

    input logic pipe_clk,
    input logic clk125,
    input logic mmcm_lock,

    output logic txoutclk,
    output logic pipe_clk_sel  // 1 = 250 MHz (Gen2): all lanes voted
);


  logic gtpll0_outclk, gtpll0_outrefclk, gtpll0_lock;
  logic gtpll0_pd, gtpll0_reset;

  gtp_if #(.LANES(PCIE_LANES)) gtp ();

  // ---- PLL0 power-up after reset: power-down for 96, then reset until 128
  // clk125 cycles. rst125_n is released on clk125, so it resets this sequence
  // directly; asserted, it holds PLL0 powered down from configuration on,
  // before clk125 runs. FIXME: clocked from clk125 as a workaround for
  // openXC7's dead IBUFDS_GTE2.O -> BUFG clock (openPCIE #22). Back to
  // BUFG(PIPE_CLK) once a v1.0.0 bitstream proves the fix on hardware.
  (* equivalent_register_removal = "no" *)logic [ 95:0] gtpll0_pwrdn_seq;
  (* equivalent_register_removal = "no" *)logic [127:0] gtpll0_reset_seq;
  logic         gtpll0_reset_req;  // from init_ctrl

  always_ff @(posedge clk125 or negedge rst125_n) begin
    if (!rst125_n) begin
      gtpll0_pwrdn_seq <= '1;
      gtpll0_reset_seq <= 128'hFF;
    end
    else begin
      gtpll0_pwrdn_seq <= {gtpll0_pwrdn_seq[94:0], 1'b0};
      gtpll0_reset_seq <= {gtpll0_reset_seq[126:0], 1'b0};
    end
  end

  assign gtpll0_pd    = gtpll0_pwrdn_seq[95];
  assign gtpll0_reset = gtpll0_reset_seq[127] | gtpll0_reset_req;

  // ---- GT and PLL reset sequencing
  init_ctrl u_init_ctrl (
      .pipe_clk        (pipe_clk),
      .clk125          (clk125),
      .pipe_rst_n      (pipe_rst_n),
      .gtpll0_lock     (gtpll0_lock),
      .mmcm_lock       (mmcm_lock),
      .gtp             (gtp),
      .gtpll0_reset_req(gtpll0_reset_req)
  );

  // ---- refclk: dedicated GT clock input buffer
  logic refclk;

  IBUFDS_GTE2 u_refclk_ibuf (
      .O    (refclk),
      .ODIV2(  /*LINT:OK*/),
      .I    (refclk_p),
      .CEB  (1'b0),
      .IB   (refclk_n)
  );

  // ---- GTPE2_COMMON: PLL0 feeds all lanes (PCIE_LANES <= 4, one quad)
  GTPE2_COMMON #(
      .SIM_PLL0REFCLK_SEL(3'b001),
      .SIM_PLL1REFCLK_SEL(3'b001),
      .SIM_RESET_SPEEDUP ("FALSE"),
      .SIM_VERSION       ("1.0"),

      // FIXME: openXC7 v1.0.0 ignores these and writes 0x1F03DC (openPCIE #18;
      // fixed on nextpnr main, nextpnr#84, not yet released); the
      // board-proven openXC7 bitstream runs on that value, not on this one.
      // Test on hardware before relying on a fixed nextpnr.
      .PLL0_CFG       (27'h01F024C),
      .PLL1_CFG       (27'h01F024C),
      .PLL_CLKOUT_CFG (8'd0),
      .PLL0_DMON_CFG  (1'b0),
      .PLL1_DMON_CFG  (1'b0),
      .PLL0_FBDIV     (5),
      .PLL1_FBDIV     (5),
      .PLL0_FBDIV_45  (5),
      .PLL1_FBDIV_45  (5),
      .PLL0_INIT_CFG  (24'h00001E),
      .PLL1_INIT_CFG  (24'h00001E),
      .PLL0_LOCK_CFG  (9'h1E8),
      .PLL1_LOCK_CFG  (9'h1E8),
      .PLL0_REFCLK_DIV(1),
      .PLL1_REFCLK_DIV(1),

      .BIAS_CFG  (64'h0000000000050001),
      .RSVD_ATTR0(16'd0),
      .RSVD_ATTR1(16'd0)

  ) u_gtpe2_common (
      // Only GTREFCLK0 is used. The other refclk inputs stay unconnected, not
      // tied to 0: nextpnr rejects a constant on a GT refclk input.
      .GTGREFCLK0    (),
      .GTGREFCLK1    (),
      .GTREFCLK0     (refclk),
      .GTREFCLK1     (),
      .GTEASTREFCLK0 (),
      .GTEASTREFCLK1 (),
      .GTWESTREFCLK0 (),
      .GTWESTREFCLK1 (),
      .PLL0LOCKDETCLK(1'd0),
      .PLL1LOCKDETCLK(1'd0),
      .PLL0LOCKEN    (1'd1),
      .PLL1LOCKEN    (1'd1),
      .PLL0REFCLKSEL (3'd1),
      .PLL1REFCLKSEL (3'd1),
      .PLLRSVD1      ('0),
      .PLLRSVD2      ('0),

      .PLL0OUTCLK    (gtpll0_outclk),
      .PLL1OUTCLK    (  /*LINT:OK*/),
      .PLL0OUTREFCLK (gtpll0_outrefclk),
      .PLL1OUTREFCLK (  /*LINT:OK*/),
      .PLL0LOCK      (gtpll0_lock),       // async (UG482)
      .PLL1LOCK      (  /*LINT:OK*/),
      .PLL0FBCLKLOST (  /*LINT:OK*/),
      .PLL1FBCLKLOST (  /*LINT:OK*/),
      .PLL0REFCLKLOST(  /*LINT:OK*/),
      .PLL1REFCLKLOST(  /*LINT:OK*/),
      .DMONITOROUT   (  /*LINT:OK*/),

      .PLL0PD   (gtpll0_pd),
      .PLL1PD   (1'd1),
      .PLL0RESET(gtpll0_reset),
      .PLL1RESET(1'd1),

      .DRPCLK (1'd0),
      .DRPADDR('0),
      .DRPEN  (1'd0),
      .DRPDI  ('0),
      .DRPWE  (1'd0),

      .DRPDO (  /*LINT:OK*/),
      .DRPRDY(  /*LINT:OK*/),

      .BGBYPASSB    (1'd1),
      .BGMONITORENB (1'd1),
      .BGPDB        (1'd1),
      .BGRCALOVRD   ('1),
      .BGRCALOVRDENB(1'd1),

      .PMARSVD('0),
      .RCALENB(1'd1),

      .REFCLKOUTMONITOR0(  /*LINT:OK*/),
      .REFCLKOUTMONITOR1(  /*LINT:OK*/),
      .PMARSVDOUT       (  /*LINT:OK*/)
  );

  // ---- cross-lane: TX/RX buffer-bypass phase alignment, lane 0 is the master
  assign gtp.txsyncallin         = &(gtp.txphaligndone | ~gtp.active_lane);
  assign gtp.rxsyncallin         = &(gtp.rxphaligndone | ~gtp.active_lane);
  assign gtp.txphinitdone_all    = &(gtp.txphinitdone | ~gtp.active_lane);
  assign gtp.txdlysresetdone_all = &gtp.txdlysresetdone;
  assign gtp.txsyncin            = gtp.txsyncout;
  assign gtp.rxsyncin            = gtp.rxsyncout;

  // ---- one lane_xcvr per lane; channel bonding chain lane 0 -> 1 -> ...
  // The last lane's RXCHBONDO has no next lane to feed: no-connect (NC_)
  logic [3:0] NC_rxchbondo;
  assign NC_rxchbondo = gtp.rxchbondo[PCIE_LANES-1];

  for (genvar i = 0; i < PCIE_LANES; i++) begin : g_lane
    if (i == 0) begin : g_chbond_head
      assign gtp.rxchbondi[i] = 4'd0;
    end
    else begin : g_chbond_chain
      assign gtp.rxchbondi[i] = gtp.rxchbondo[i-1];
    end

    lane_xcvr #(
        .LANE(i)
    ) u_xcvr (
        .pipe_clk        (pipe_clk),
        .clk125          (clk125),
        .clk_mmcm_lock   (mmcm_lock),
        .gtpll0_outclk   (gtpll0_outclk),
        .gtpll0_outrefclk(gtpll0_outrefclk),
        .pipe_phy        (pipe),
        .gtp             (gtp),
        .gt_txp          (txp[i]),
        .gt_txn          (txn[i]),
        .gt_rxp          (rxp[i]),
        .gt_rxn          (rxn[i])
    );
  end

  logic gt_txoutclk;
  assign gt_txoutclk   = gtp.txoutclk;  // openxc7.x*.xdc create the txoutclk clock on this net

  assign phystatus_rst = gtp.phystatus_rst;
  assign txoutclk      = gt_txoutclk;
  // ---- pipe_clk select: each lane's speed_ctrl votes for the new rate once
  // it is ready; pipe_clk switches when all lanes agree, and holds otherwise
  logic [PCIE_LANES-1:0] pipe_clk_sel_reg1, pipe_clk_sel_reg2;

  always_ff @(posedge pipe_clk or negedge pipe_rst_n) begin
    if (!pipe_rst_n) begin
      pipe_clk_sel_reg1 <= '0;
      pipe_clk_sel_reg2 <= '0;
      pipe_clk_sel      <= 1'b0;
    end
    else begin
      pipe_clk_sel_reg1 <= gtp.pipe_clk_sel;
      pipe_clk_sel_reg2 <= pipe_clk_sel_reg1;
      if (&pipe_clk_sel_reg2) begin
        pipe_clk_sel <= 1'b1;
      end
      else if (&(~pipe_clk_sel_reg2)) begin
        pipe_clk_sel <= 1'b0;
      end
    end
  end

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
