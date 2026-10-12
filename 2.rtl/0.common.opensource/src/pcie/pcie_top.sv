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
#(
  localparam int C_DATA_WIDTH            = 64,
  localparam int KEEP_WIDTH              = 8
) (
  output  [PCIE_LANES-1:0]  pci_exp_txp,
  output  [PCIE_LANES-1:0]  pci_exp_txn,
  input   [PCIE_LANES-1:0]  pci_exp_rxp,
  input   [PCIE_LANES-1:0]  pci_exp_rxn,

  input             pipe_mmcm_rst_n,

  output                        user_clk_out,
  output logic                  user_reset_out,
  output                        user_lnk_up,

  axis_if.slave               s_axis_tx,   // TLPs from the SOC (USER_W 4)
  axis_if.master              m_axis_rx,   // TLPs to the SOC   (USER_W 22)

  cfg_if.core                   cfg,      // status sideband to the SOC

  input                 sys_clk,
  input                 sys_rst_n
);

  localparam [15:0] CFG_VEND_ID        = 16'h10EE;
  localparam [15:0] CFG_DEV_ID         = 16'h7121;
  localparam [7:0]  CFG_REV_ID         =  8'h00;
  localparam [15:0] CFG_SUBSYS_VEND_ID = 16'h10EE;
  localparam [15:0] CFG_SUBSYS_ID      = 16'h0007;

  wire phy_rdy_n;
  wire user_rst_n;
  wire trn_lnk_up;

  wire        clk_pclk;
  wire        clk_rxusrclk;
  wire        clk_dclk;
  wire        clk_userclk1;
  wire        clk_oobclk;
  wire        clk_mmcm_lock;

  wire                                 pipe_txoutclk;
  wire [(LINK_CAP_MAX_LINK_WIDTH-1):0] pipe_pclk_sel;

  wire [5:0] pl_ltssm_state_int;
  wire       pl_phy_lnk_up_wire;
  wire       pl_received_hot_rst_wire;

  pipe_if                                 pipe_mac ();   // 16-bit PIPE at the MAC

  clk_gen  u_clk_gen (
    .CLK_CLK            (sys_clk),
    .CLK_TXOUTCLK       (pipe_txoutclk),
    .CLK_RST_N          (pipe_mmcm_rst_n),
    .CLK_PCLK_SEL       (pipe_pclk_sel),

    .CLK_PCLK           (clk_pclk),
    .CLK_RXUSRCLK       (clk_rxusrclk),
    .CLK_DCLK           (clk_dclk),
    .CLK_OOBCLK         (clk_oobclk),
    .CLK_USERCLK1       (clk_userclk1),
    .CLK_MMCM_LOCK      (clk_mmcm_lock)
  );

  phy_top u_phy_top (
    .pl_ltssm_state   (pl_ltssm_state_int),
    .pipe_mac         (pipe_mac),

    .pci_exp_txn      (pci_exp_txn),
    .pci_exp_txp      (pci_exp_txp),
    .pci_exp_rxn      (pci_exp_rxn),
    .pci_exp_rxp      (pci_exp_rxp),

    .sys_clk          (sys_clk),
    .sys_rst_n        (sys_rst_n),

    .PIPE_PCLK_IN     (clk_pclk),
    .PIPE_RXUSRCLK_IN (clk_rxusrclk),
    .PIPE_DCLK_IN     (clk_dclk),
    .PIPE_OOBCLK_IN   (clk_oobclk),
    .PIPE_MMCM_LOCK_IN(clk_mmcm_lock),
    .PIPE_TXOUTCLK_OUT(pipe_txoutclk),
    .PIPE_PCLK_SEL_OUT(pipe_pclk_sel),

    .phy_rdy_n        (phy_rdy_n)
  );

  pcie_core u_pcie_core (
    .user_clk_out   (user_clk_out),
    .user_reset     (user_reset_out),
    .user_lnk_up    (user_lnk_up),
    .trn_lnk_up     (trn_lnk_up),
    .user_rst_n     (user_rst_n),

    .s_axis_tx      (s_axis_tx),
    .m_axis_rx      (m_axis_rx),

    .tx_buf_avail      (cfg.tx_buf_avail),

    .cfg_dev_id             (CFG_DEV_ID),
    .cfg_vend_id            (CFG_VEND_ID),
    .cfg_rev_id             (CFG_REV_ID),
    .cfg_subsys_id          (CFG_SUBSYS_ID),
    .cfg_subsys_vend_id     (CFG_SUBSYS_VEND_ID),

    .cfg_msg_received_err_fatal      (cfg.msg_err_fatal),

    .pl_ltssm_state              (pl_ltssm_state_int),
    .pl_phy_lnk_up               (pl_phy_lnk_up_wire),
    .pl_received_hot_rst         (pl_received_hot_rst_wire),

    .pipe_mac       (pipe_mac),
    .phy_rdy_n      (phy_rdy_n),
    .pipe_clk       (clk_pclk),
    .user_clk       (clk_userclk1)
  );

  (* KEEP = "TRUE", ASYNC_REG = "TRUE" *) logic user_lnk_up_int;
  logic  user_reset_int;
  logic  pl_received_hot_rst_q;
  logic  pl_phy_lnk_up_q;
  wire pl_received_hot_rst_sync;
  wire pl_phy_lnk_up_sync;
  wire sys_or_hot_rst;

  assign user_lnk_up        = user_lnk_up_int;
  assign sys_or_hot_rst     = !sys_rst_n || pl_received_hot_rst_q;

  xpm_cdc_single #(.DEST_SYNC_FF(2), .SRC_INPUT_REG(0)) phy_lnk_up_cdc (
    .src_clk  (clk_pclk),
    .src_in   (pl_phy_lnk_up_wire),
    .dest_clk (user_clk_out),
    .dest_out (pl_phy_lnk_up_sync)
  );
  xpm_cdc_single #(.DEST_SYNC_FF(2), .SRC_INPUT_REG(0)) pl_received_hot_rst_cdc (
    .src_clk  (clk_pclk),
    .src_in   (pl_received_hot_rst_wire),
    .dest_clk (user_clk_out),
    .dest_out (pl_received_hot_rst_sync)
  );

  always_ff @(posedge user_clk_out) begin
    if (!sys_rst_n) begin
      pl_received_hot_rst_q <= 1'b0;
      pl_phy_lnk_up_q       <= 1'b0;
    end else begin
      pl_received_hot_rst_q <= pl_received_hot_rst_sync;
      pl_phy_lnk_up_q       <= pl_phy_lnk_up_sync;
    end
  end

  always_ff @(posedge user_clk_out) begin
    if (!sys_rst_n) user_lnk_up_int <= 1'b0;
    else            user_lnk_up_int <= trn_lnk_up;
  end

  always_ff @(posedge user_clk_out or posedge sys_or_hot_rst) begin
    if (sys_or_hot_rst)                        user_reset_int <= 1'b1;
    else if (user_rst_n && pl_phy_lnk_up_q)    user_reset_int <= 1'b0;
  end

  always_ff @(posedge user_clk_out or posedge sys_or_hot_rst) begin
    if (sys_or_hot_rst) user_reset_out <= 1'b1;
    else                user_reset_out <= user_reset_int;
  end

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
