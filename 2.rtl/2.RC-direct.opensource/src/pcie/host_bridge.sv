// SPDX-FileCopyrightText: 2026 Chili.CHIPS*ba
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openPCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
//                   Copyright (C) 2026 Chili.CHIPS*ba
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

module host_bridge   
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

  output                        s_axis_tx_tready,
  input  [C_DATA_WIDTH-1:0]     s_axis_tx_tdata,
  input  [KEEP_WIDTH-1:0]       s_axis_tx_tkeep,
  input  [3:0]                  s_axis_tx_tuser,
  input                         s_axis_tx_tlast,
  input                         s_axis_tx_tvalid,

  output  [C_DATA_WIDTH-1:0]    m_axis_rx_tdata,
  output  [KEEP_WIDTH-1:0]      m_axis_rx_tkeep,
  output                        m_axis_rx_tlast,
  output                        m_axis_rx_tvalid,
  output  [21:0]                m_axis_rx_tuser,
  input                         m_axis_rx_tready,

  output  [5:0]                 tx_buf_av,
  output  [15:0]                cfg_status,
  output                        cfg_msg_received_err_fatal,

  input                 sys_clk,
  input                 sys_rst_n
);

  localparam [15:0] CFG_VEND_ID        = 16'h10EE;
  localparam [15:0] CFG_DEV_ID         = 16'h7121;
  localparam [7:0]  CFG_REV_ID         =  8'h00;
  localparam [15:0] CFG_SUBSYS_VEND_ID = 16'h10EE;
  localparam [15:0] CFG_SUBSYS_ID      = 16'h0007;

  wire pipe_clk;
  wire user_clk;
  wire user_clk2;
  wire phy_rdy_n;
  wire user_rst_n;
  wire trn_lnk_up;

  wire        clk_pclk;
  wire        clk_rxusrclk;
  wire        clk_dclk;
  wire        clk_userclk1;
  wire        clk_userclk2;
  wire        clk_oobclk;
  wire        clk_mmcm_lock;
  wire [(LINK_CAP_MAX_LINK_WIDTH-1):0] clk_rxoutclk;

  wire                                 pipe_txoutclk;
  wire [(LINK_CAP_MAX_LINK_WIDTH-1):0] pipe_rxoutclk;
  wire [(LINK_CAP_MAX_LINK_WIDTH-1):0] pipe_pclk_sel;
  wire                                 pipe_gen3;

  wire [5:0] pl_ltssm_state_int;
  wire       pl_phy_lnk_up_wire;
  wire       pl_received_hot_rst_wire;

  phy_lanes_if                                 pipe();
  stream_if #(.DATA_W(C_DATA_WIDTH), .USER_W(4))  s_axis_tx_if();
  stream_if #(.DATA_W(C_DATA_WIDTH), .USER_W(22)) m_axis_rx_if();

  assign s_axis_tx_if.tdata  = s_axis_tx_tdata;
  assign s_axis_tx_if.tkeep  = s_axis_tx_tkeep;
  assign s_axis_tx_if.tuser  = s_axis_tx_tuser;
  assign s_axis_tx_if.tlast  = s_axis_tx_tlast;
  assign s_axis_tx_if.tvalid = s_axis_tx_tvalid;
  assign s_axis_tx_tready    = s_axis_tx_if.tready;

  assign m_axis_rx_tdata     = m_axis_rx_if.tdata;
  assign m_axis_rx_tkeep     = m_axis_rx_if.tkeep;
  assign m_axis_rx_tuser     = m_axis_rx_if.tuser;
  assign m_axis_rx_tlast     = m_axis_rx_if.tlast;
  assign m_axis_rx_tvalid    = m_axis_rx_if.tvalid;
  assign m_axis_rx_if.tready = m_axis_rx_tready;

  clk_synth  clk_synth_i (
    .CLK_CLK            (sys_clk),
    .CLK_TXOUTCLK       (pipe_txoutclk),
    .CLK_RXOUTCLK_IN    (pipe_rxoutclk),
    .CLK_RST_N          (pipe_mmcm_rst_n),
    .CLK_PCLK_SEL       (pipe_pclk_sel),
    .CLK_PCLK_SEL_SLAVE (1'b0),
    .CLK_GEN3           (pipe_gen3),

    .CLK_PCLK           (clk_pclk),
    .CLK_PCLK_SLAVE     (),
    .CLK_RXUSRCLK       (clk_rxusrclk),
    .CLK_RXOUTCLK_OUT   (clk_rxoutclk),
    .CLK_DCLK           (clk_dclk),
    .CLK_OOBCLK         (clk_oobclk),
    .CLK_USERCLK1       (clk_userclk1),
    .CLK_USERCLK2       (clk_userclk2),
    .CLK_MMCM_LOCK      (clk_mmcm_lock)
  );

  serdes_front serdes_front_i (
    .pl_ltssm_state   (pl_ltssm_state_int),
    .pipe             (pipe),

    .pci_exp_txn      (pci_exp_txn),
    .pci_exp_txp      (pci_exp_txp),
    .pci_exp_rxn      (pci_exp_rxn),
    .pci_exp_rxp      (pci_exp_rxp),

    .sys_clk          (sys_clk),
    .sys_rst_n        (sys_rst_n),
    .PIPE_MMCM_RST_N  (pipe_mmcm_rst_n),
    .pipe_clk         (pipe_clk),
    .user_clk         (user_clk),
    .user_clk2        (user_clk2),

    .PIPE_PCLK_IN     (clk_pclk),
    .PIPE_RXUSRCLK_IN (clk_rxusrclk),
    .PIPE_RXOUTCLK_IN (clk_rxoutclk),
    .PIPE_DCLK_IN     (clk_dclk),
    .PIPE_USERCLK1_IN (clk_userclk1),
    .PIPE_USERCLK2_IN (clk_userclk2),
    .PIPE_OOBCLK_IN   (clk_oobclk),
    .PIPE_MMCM_LOCK_IN(clk_mmcm_lock),
    .PIPE_TXOUTCLK_OUT(pipe_txoutclk),
    .PIPE_RXOUTCLK_OUT(pipe_rxoutclk),
    .PIPE_PCLK_SEL_OUT(pipe_pclk_sel),
    .PIPE_GEN3_OUT    (pipe_gen3),

    .phy_rdy_n        (phy_rdy_n)
  );

  cfg_regs_t cfg_regs;
  assign cfg_status = cfg_regs.status;

  txn_engine txn_engine_i (
    .user_clk_out   (user_clk_out),
    .user_reset     (user_reset_out),
    .user_lnk_up    (user_lnk_up),
    .trn_lnk_up     (trn_lnk_up),
    .user_rst_n     (user_rst_n),

    .s_axis_tx      (s_axis_tx_if),
    .m_axis_rx      (m_axis_rx_if),

    .tx_buf_av      (tx_buf_av),
    .tx_err_drop    (),
    .tx_cfg_req     (),
    .tx_cfg_gnt     (1'b0),
    .rx_np_ok       (1'b1),
    .rx_np_req      (1'b1),

    .fc_cpld        (),
    .fc_cplh        (),
    .fc_npd         (),
    .fc_nph         (),
    .fc_pd          (),
    .fc_ph          (),
    .fc_sel         (3'b0),

    .cfg_regs       (cfg_regs),

    .cfg_mgmt_do            (),
    .cfg_mgmt_rd_wr_done    (),
    .cfg_mgmt_di            (32'd0),
    .cfg_mgmt_byte_en       (4'h0),
    .cfg_mgmt_dwaddr        (10'd0),
    .cfg_mgmt_wr_en         (1'b0),
    .cfg_mgmt_rd_en         (1'b0),
    .cfg_mgmt_wr_readonly   (1'b0),
    .cfg_mgmt_wr_rw1c_as_rw (1'b0),

    .cfg_err_ecrc                  (1'b0),
    .cfg_err_ur                    (1'b0),
    .cfg_err_cpl_timeout           (1'b0),
    .cfg_err_cpl_unexpect          (1'b0),
    .cfg_err_cpl_abort             (1'b0),
    .cfg_err_posted                (1'b0),
    .cfg_err_cor                   (1'b0),
    .cfg_err_atomic_egress_blocked (1'b0),
    .cfg_err_internal_cor          (1'b0),
    .cfg_err_malformed             (1'b0),
    .cfg_err_mc_blocked            (1'b0),
    .cfg_err_poisoned              (1'b0),
    .cfg_err_norecovery            (1'b0),
    .cfg_err_locked                (1'b0),
    .cfg_err_internal_uncor        (1'b0),
    .cfg_err_tlp_cpl_header        (48'd0),
    .cfg_err_cpl_rdy               (),
    .cfg_err_aer_headerlog         (128'd0),
    .cfg_aer_interrupt_msgnum      (5'd0),
    .cfg_err_aer_headerlog_set     (),
    .cfg_aer_ecrc_check_en         (),
    .cfg_aer_ecrc_gen_en           (),

    .cfg_interrupt                 (1'b0),
    .cfg_interrupt_rdy             (),
    .cfg_interrupt_assert          (1'b0),
    .cfg_interrupt_di              (8'd0),
    .cfg_interrupt_do              (),
    .cfg_interrupt_mmenable        (),
    .cfg_interrupt_msienable       (),
    .cfg_interrupt_msixenable      (),
    .cfg_interrupt_msixfm          (),
    .cfg_interrupt_stat            (1'b0),
    .cfg_pciecap_interrupt_msgnum  (5'd0),

    .cfg_trn_pending        (1'b0),
    .cfg_pm_halt_aspm_l0s   (1'b0),
    .cfg_pm_halt_aspm_l1    (1'b0),
    .cfg_pm_force_state_en  (1'b0),
    .cfg_pm_force_state     (2'b00),
    .cfg_pm_wake            (1'b0),
    .cfg_dsn                (64'd0),
    .cfg_ds_bus_number      (8'd0),
    .cfg_ds_device_number   (5'd0),
    .cfg_ds_function_number (3'b000),
    .cfg_turnoff_ok         (1'b0),
    .cfg_to_turnoff         (),
    .cfg_bus_number         (),
    .cfg_device_number      (),
    .cfg_function_number    (),
    .cfg_pcie_link_state    (),
    .cfg_pmcsr_pme_en       (),
    .cfg_pmcsr_powerstate   (),
    .cfg_pmcsr_pme_status   (),
    .cfg_received_func_lvl_rst (),

    .cfg_dev_id             (CFG_DEV_ID),
    .cfg_vend_id            (CFG_VEND_ID),
    .cfg_rev_id             (CFG_REV_ID),
    .cfg_subsys_id          (CFG_SUBSYS_ID),
    .cfg_subsys_vend_id     (CFG_SUBSYS_VEND_ID),

    .cfg_msg_received                (),
    .cfg_msg_data                    (),
    .cfg_msg_received_pm_as_nak      (),
    .cfg_msg_received_setslotpowerlimit (),
    .cfg_msg_received_err_cor        (),
    .cfg_msg_received_err_non_fatal  (),
    .cfg_msg_received_err_fatal      (cfg_msg_received_err_fatal),
    .cfg_msg_received_pm_pme         (),
    .cfg_msg_received_pme_to_ack     (),
    .cfg_msg_received_assert_int_a   (),
    .cfg_msg_received_assert_int_b   (),
    .cfg_msg_received_assert_int_c   (),
    .cfg_msg_received_assert_int_d   (),
    .cfg_msg_received_deassert_int_a (),
    .cfg_msg_received_deassert_int_b (),
    .cfg_msg_received_deassert_int_c (),
    .cfg_msg_received_deassert_int_d (),

    .cfg_bridge_serr_en                        (),
    .cfg_slot_control_electromech_il_ctl_pulse (),
    .cfg_root_control_syserr_corr_err_en       (),
    .cfg_root_control_syserr_non_fatal_err_en  (),
    .cfg_root_control_syserr_fatal_err_en      (),
    .cfg_root_control_pme_int_en               (),
    .cfg_aer_rooterr_corr_err_reporting_en     (),
    .cfg_aer_rooterr_non_fatal_err_reporting_en(),
    .cfg_aer_rooterr_fatal_err_reporting_en    (),
    .cfg_aer_rooterr_corr_err_received         (),
    .cfg_aer_rooterr_non_fatal_err_received    (),
    .cfg_aer_rooterr_fatal_err_received        (),
    .cfg_vc_tcvc_map                           (),

    .pl_directed_link_change     (2'd0),
    .pl_directed_link_width      (2'b0),
    .pl_directed_link_speed      (1'b0),
    .pl_directed_link_auton      (1'b0),
    .pl_upstream_prefer_deemph   (1'b0),
    .pl_downstream_deemph_source (1'b0),
    .pl_transmit_hot_rst         (1'b0),
    .pl_sel_lnk_rate             (),
    .pl_sel_lnk_width            (),
    .pl_ltssm_state              (pl_ltssm_state_int),
    .pl_lane_reversal_mode       (),
    .pl_phy_lnk_up               (pl_phy_lnk_up_wire),
    .pl_tx_pm_state              (),
    .pl_rx_pm_state              (),
    .pl_link_upcfg_cap           (),
    .pl_link_gen2_cap            (),
    .pl_link_partner_gen2_supported (),
    .pl_initial_link_width       (),
    .pl_directed_change_done     (),
    .pl_received_hot_rst         (pl_received_hot_rst_wire),

    .pcie_drp_clk   (1'b1),
    .pcie_drp_en    (1'b0),
    .pcie_drp_we    (1'b0),
    .pcie_drp_addr  (9'd0),
    .pcie_drp_di    (16'd0),
    .pcie_drp_rdy   (),
    .pcie_drp_do    (),

    .pipe           (pipe),
    .phy_rdy_n      (phy_rdy_n),
    .pipe_clk       (pipe_clk),
    .user_clk       (user_clk),
    .user_clk2      (user_clk2)
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
    .src_clk  (pipe_clk),
    .src_in   (pl_phy_lnk_up_wire),
    .dest_clk (user_clk_out),
    .dest_out (pl_phy_lnk_up_sync)
  );
  xpm_cdc_single #(.DEST_SYNC_FF(2), .SRC_INPUT_REG(0)) pl_received_hot_rst_cdc (
    .src_clk  (pipe_clk),
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
