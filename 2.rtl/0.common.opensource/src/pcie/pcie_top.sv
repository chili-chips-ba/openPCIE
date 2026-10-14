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

module pcie_top
  import link_pkg::*;
(
    output logic [PCIE_LANES-1:0] pci_exp_txp,
    output logic [PCIE_LANES-1:0] pci_exp_txn,
    input  logic [PCIE_LANES-1:0] pci_exp_rxp,
    input  logic [PCIE_LANES-1:0] pci_exp_rxn,


    output logic clk62m5,     // 62.5 MHz, from clk_rst_gen
    output logic core_rst_n,  // clk62m5 reset: low on PERST# or no data link
    output logic trn_link_up, // data link up (TRNLNKUP), clk62m5

    axis_if.slave  s_axis_tx,  // TLPs from the SOC (tuser: pcie_tx_tuser_t)
    axis_if.master m_axis_rx,  // TLPs to the SOC   (tuser: pcie_rx_tuser_t)

    cfg_if.core cfg,  // status sideband to the SOC

    input logic refclk_p,  // 100 MHz PCIE REFCLK+
    input logic refclk_n,  // REFCLK-
    input logic perst_n
);

  localparam logic [15:0] CFG_VEND_ID        = 16'h10EE;
  localparam logic [15:0] CFG_DEV_ID         = 16'h7121;
  localparam logic [ 7:0] CFG_REV_ID         = 8'h00;
  localparam logic [15:0] CFG_SUBSYS_VEND_ID = 16'h10EE;
  localparam logic [15:0] CFG_SUBSYS_ID      = 16'h0007;

  logic       phy_rdy_n;

  logic       pipe_clk;
  logic       clk125;
  logic       clk_mmcm_lock;

  logic       pipe_txoutclk;
  logic       pipe_clk_sel;  // all lanes voted (gtp_wrapper)

  logic [5:0] pl_ltssm_state_int;

  pipe_if pipe_mac ();  // 16-bit PIPE at the MAC

  logic rst125_n;  // from clk_rst_gen: PERST# or FPGA configuration
  logic rst62m5_n;  // the same, released on clk62m5
  logic pipe_rst_n;  // the same, released on pipe_clk

  clk_rst_gen u_clk_rst_gen (
      .txoutclk    (pipe_txoutclk),
      .perst_n     (perst_n),
      .rst125_n    (rst125_n),
      .rst62m5_n   (rst62m5_n),
      .pipe_clk_sel(pipe_clk_sel),

      .pipe_clk  (pipe_clk),
      .pipe_rst_n(pipe_rst_n),
      .clk125    (clk125),
      .clk62m5   (clk62m5),
      .mmcm_lock (clk_mmcm_lock)
  );

  phy_top u_phy_top (
      .pl_ltssm_state(pl_ltssm_state_int),
      .pipe_mac      (pipe_mac),

      .pci_exp_txn(pci_exp_txn),
      .pci_exp_txp(pci_exp_txp),
      .pci_exp_rxn(pci_exp_rxn),
      .pci_exp_rxp(pci_exp_rxp),

      .refclk_p  (refclk_p),
      .refclk_n  (refclk_n),
      .rst125_n  (rst125_n),
      .pipe_rst_n(pipe_rst_n),

      .pipe_clk_in      (pipe_clk),
      .pipe_drp_clk_in  (clk125),
      .pipe_mmcm_lock_in(clk_mmcm_lock),
      .pipe_txoutclk_out(pipe_txoutclk),
      .pipe_clk_sel_out (pipe_clk_sel),

      .phy_rdy_n(phy_rdy_n)
  );

  pcie_core u_core (
      .core_rst_n (core_rst_n),
      .trn_link_up(trn_link_up),

      .s_axis_tx(s_axis_tx),
      .m_axis_rx(m_axis_rx),

      .tx_buf_avail(cfg.tx_buf_avail),

      .cfg_dev_id        (CFG_DEV_ID),
      .cfg_vend_id       (CFG_VEND_ID),
      .cfg_rev_id        (CFG_REV_ID),
      .cfg_subsys_id     (CFG_SUBSYS_ID),
      .cfg_subsys_vend_id(CFG_SUBSYS_VEND_ID),

      .cfg_msg_received_err_fatal(cfg.msg_err_fatal),

      .pl_ltssm_state(pl_ltssm_state_int),

      .pipe_mac (pipe_mac),
      .phy_rdy_n(phy_rdy_n),
      .pipe_clk (pipe_clk),
      .clk62m5  (clk62m5)
  );

  // core_rst_n: the clk62m5 reset of the TRN modules and the SOC. PERST# (by
  // rst62m5_n) asserts it; it is released once the PCIE data link is up
  // (trn_link_up, from TRNLNKUP in this clock domain), and a link drop asserts
  // it again. An RC is a Downstream Port and never receives a hot reset.
  always_ff @(posedge clk62m5 or negedge rst62m5_n) begin
    if (!rst62m5_n) begin
      core_rst_n <= 1'b0;
    end
    else begin
      core_rst_n <= trn_link_up;
    end
  end

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
