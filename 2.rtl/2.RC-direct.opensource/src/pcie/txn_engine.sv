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

module txn_engine
  import link_pkg::*;
#(
  localparam     PL_FAST_TRAIN = "FALSE",
  localparam int C_DATA_WIDTH  = 64,
  localparam int KEEP_WIDTH    = 8,
  localparam int REM_WIDTH     = 1
) (
  output                     user_clk_out,
  input                      user_reset,
  input                      user_lnk_up,
  output                     trn_lnk_up,
  output                     user_rst_n,

  stream_if.slave         s_axis_tx,
  stream_if.master        m_axis_rx,

  output  [5:0]              tx_buf_av,
  output                     tx_err_drop,
  output                     tx_cfg_req,
  input                      tx_cfg_gnt,
  input                      rx_np_ok,
  input                      rx_np_req,

  output [11:0]              fc_cpld,
  output  [7:0]              fc_cplh,
  output [11:0]              fc_npd,
  output  [7:0]              fc_nph,
  output [11:0]              fc_pd,
  output  [7:0]              fc_ph,
  input   [2:0]              fc_sel,

  output cfg_regs_t          cfg_regs,

  output [31:0]              cfg_mgmt_do,
  output                     cfg_mgmt_rd_wr_done,
  input  [31:0]              cfg_mgmt_di,
  input   [3:0]              cfg_mgmt_byte_en,
  input   [9:0]              cfg_mgmt_dwaddr,
  input                      cfg_mgmt_wr_en,
  input                      cfg_mgmt_rd_en,
  input                      cfg_mgmt_wr_readonly,
  input                      cfg_mgmt_wr_rw1c_as_rw,

  input                      cfg_err_ecrc,
  input                      cfg_err_ur,
  input                      cfg_err_cpl_timeout,
  input                      cfg_err_cpl_unexpect,
  input                      cfg_err_cpl_abort,
  input                      cfg_err_posted,
  input                      cfg_err_cor,
  input                      cfg_err_atomic_egress_blocked,
  input                      cfg_err_internal_cor,
  input                      cfg_err_malformed,
  input                      cfg_err_mc_blocked,
  input                      cfg_err_poisoned,
  input                      cfg_err_norecovery,
  input                      cfg_err_locked,
  input                      cfg_err_internal_uncor,
  input  [47:0]              cfg_err_tlp_cpl_header,
  output                     cfg_err_cpl_rdy,
  input  [127:0]             cfg_err_aer_headerlog,
  input   [4:0]              cfg_aer_interrupt_msgnum,
  output                     cfg_err_aer_headerlog_set,
  output                     cfg_aer_ecrc_check_en,
  output                     cfg_aer_ecrc_gen_en,

  input                      cfg_interrupt,
  output                     cfg_interrupt_rdy,
  input                      cfg_interrupt_assert,
  input   [7:0]              cfg_interrupt_di,
  output  [7:0]              cfg_interrupt_do,
  output  [2:0]              cfg_interrupt_mmenable,
  output                     cfg_interrupt_msienable,
  output                     cfg_interrupt_msixenable,
  output                     cfg_interrupt_msixfm,
  input                      cfg_interrupt_stat,
  input   [4:0]              cfg_pciecap_interrupt_msgnum,

  input                      cfg_trn_pending,
  input                      cfg_pm_halt_aspm_l0s,
  input                      cfg_pm_halt_aspm_l1,
  input                      cfg_pm_force_state_en,
  input   [1:0]              cfg_pm_force_state,
  input                      cfg_pm_wake,
  input  [63:0]              cfg_dsn,
  input   [7:0]              cfg_ds_bus_number,
  input   [4:0]              cfg_ds_device_number,
  input   [2:0]              cfg_ds_function_number,
  input                      cfg_turnoff_ok,
  output                     cfg_to_turnoff,
  output  [7:0]              cfg_bus_number,
  output  [4:0]              cfg_device_number,
  output  [2:0]              cfg_function_number,
  output  [2:0]              cfg_pcie_link_state,
  output                     cfg_pmcsr_pme_en,
  output  [1:0]              cfg_pmcsr_powerstate,
  output                     cfg_pmcsr_pme_status,
  output                     cfg_received_func_lvl_rst,

  input  [15:0]              cfg_dev_id,
  input  [15:0]              cfg_vend_id,
  input   [7:0]              cfg_rev_id,
  input  [15:0]              cfg_subsys_id,
  input  [15:0]              cfg_subsys_vend_id,

  output                     cfg_msg_received,
  output [15:0]              cfg_msg_data,
  output                     cfg_msg_received_pm_as_nak,
  output                     cfg_msg_received_setslotpowerlimit,
  output                     cfg_msg_received_err_cor,
  output                     cfg_msg_received_err_non_fatal,
  output                     cfg_msg_received_err_fatal,
  output                     cfg_msg_received_pm_pme,
  output                     cfg_msg_received_pme_to_ack,
  output                     cfg_msg_received_assert_int_a,
  output                     cfg_msg_received_assert_int_b,
  output                     cfg_msg_received_assert_int_c,
  output                     cfg_msg_received_assert_int_d,
  output                     cfg_msg_received_deassert_int_a,
  output                     cfg_msg_received_deassert_int_b,
  output                     cfg_msg_received_deassert_int_c,
  output                     cfg_msg_received_deassert_int_d,

  output                     cfg_bridge_serr_en,
  output                     cfg_slot_control_electromech_il_ctl_pulse,
  output                     cfg_root_control_syserr_corr_err_en,
  output                     cfg_root_control_syserr_non_fatal_err_en,
  output                     cfg_root_control_syserr_fatal_err_en,
  output                     cfg_root_control_pme_int_en,
  output                     cfg_aer_rooterr_corr_err_reporting_en,
  output                     cfg_aer_rooterr_non_fatal_err_reporting_en,
  output                     cfg_aer_rooterr_fatal_err_reporting_en,
  output                     cfg_aer_rooterr_corr_err_received,
  output                     cfg_aer_rooterr_non_fatal_err_received,
  output                     cfg_aer_rooterr_fatal_err_received,
  output  [6:0]              cfg_vc_tcvc_map,

  input   [1:0]              pl_directed_link_change,
  input   [1:0]              pl_directed_link_width,
  input                      pl_directed_link_speed,
  input                      pl_directed_link_auton,
  input                      pl_upstream_prefer_deemph,
  input                      pl_downstream_deemph_source,
  input                      pl_transmit_hot_rst,
  output                     pl_sel_lnk_rate,
  output  [1:0]              pl_sel_lnk_width,
  output  [5:0]              pl_ltssm_state,
  output  [1:0]              pl_lane_reversal_mode,
  output                     pl_phy_lnk_up,
  output  [2:0]              pl_tx_pm_state,
  output  [1:0]              pl_rx_pm_state,
  output                     pl_link_upcfg_cap,
  output                     pl_link_gen2_cap,
  output                     pl_link_partner_gen2_supported,
  output  [2:0]              pl_initial_link_width,
  output                     pl_directed_change_done,
  output                     pl_received_hot_rst,

  input                      pcie_drp_clk,
  input                      pcie_drp_en,
  input                      pcie_drp_we,
  input   [8:0]              pcie_drp_addr,
  input  [15:0]              pcie_drp_di,
  output                     pcie_drp_rdy,
  output [15:0]              pcie_drp_do,

  phy_lanes_if.mac           pipe,
  input                      phy_rdy_n,
  input                      pipe_clk,
  input                      user_clk,
  input                      user_clk2
);

  localparam TCQ = 1;

  assign user_clk_out = user_clk;

  wire [C_DATA_WIDTH-1:0]  trn_td;
  wire [REM_WIDTH-1:0]     trn_trem;
  wire                     trn_tsof;
  wire                     trn_teof;
  wire                     trn_tsrc_rdy;
  wire                     trn_tdst_rdy;
  wire                     trn_tsrc_dsc;
  wire                     trn_terrfwd;
  wire                     trn_tecrc_gen;
  wire                     trn_tstr;
  wire                     trn_tcfg_gnt;

  wire [127:0]             trn_rd;
  wire [1:0]               trn_rrem;
  wire                     trn_rdst_rdy;
  wire                     trn_rsof;
  wire                     trn_reof;
  wire                     trn_rsrc_rdy;
  wire                     trn_rsrc_dsc;
  wire                     trn_rerrfwd;
  wire                     trn_recrc_err;
  wire [7:0]               trn_rbar_hit;

  wire [1:0]  tx_char_is_k_blk  [PIPE_MAX_LANES];
  wire [15:0] tx_data_blk       [PIPE_MAX_LANES];
  wire        tx_compliance_blk [PIPE_MAX_LANES];
  wire        tx_elec_idle_blk  [PIPE_MAX_LANES];
  wire [1:0]  tx_powerdown_blk  [PIPE_MAX_LANES];
  wire        rx_polarity_flat  [PIPE_MAX_LANES];
  wire        tx_rcvr_det_blk, tx_reset_blk, tx_rate_blk, tx_deemph_blk;
  wire [2:0]  tx_margin_blk;

  pipe_tx_ctrl_t                      tx_ctrl_blk;
  pipe_tx_lane_t [PIPE_MAX_LANES-1:0] tx_blk;
  logic          [PIPE_MAX_LANES-1:0] rx_polarity_blk;
  pipe_rx_lane_t [PIPE_MAX_LANES-1:0] rx_blk;

  pipe_tx_ctrl_t                      tx_ctrl_q;
  pipe_tx_lane_t [PIPE_MAX_LANES-1:0] tx_q;
  logic          [PIPE_MAX_LANES-1:0] rx_polarity_q;
  pipe_rx_lane_t [PIPE_MAX_LANES-1:0] rx_q;

  assign tx_ctrl_blk = '{rcvr_det: tx_rcvr_det_blk,
                         reset:    tx_reset_blk,
                         rate:     tx_rate_blk,
                         deemph:   tx_deemph_blk,
                         margin:   tx_margin_blk,
                         swing:    1'b0};

  generate
    for (genvar l = 0; l < PIPE_MAX_LANES; l++) begin : tx_pack
      assign tx_blk[l] = '{char_is_k:  tx_char_is_k_blk[l],
                           data:       tx_data_blk[l],
                           compliance: tx_compliance_blk[l],
                           elec_idle:  tx_elec_idle_blk[l],
                           powerdown:  tx_powerdown_blk[l]};
      assign rx_polarity_blk[l] = rx_polarity_flat[l];
    end
  endgenerate

  always_ff @(posedge pipe_clk) begin
    if (phy_rdy_n) begin
      tx_ctrl_q     <= PIPE_TX_CTRL_RST;
      rx_polarity_q <= '0;
      for (int l = 0; l < PIPE_MAX_LANES; l++) begin
        tx_q[l] <= PIPE_TX_LANE_RST;
        rx_q[l] <= PIPE_RX_LANE_RST;
      end
    end
    else begin
      tx_ctrl_q     <= tx_ctrl_blk;
      rx_polarity_q <= rx_polarity_blk;
      tx_q          <= tx_blk;
      rx_q          <= pipe.rx;
    end
  end

  assign pipe.tx_ctrl = tx_ctrl_q;

  generate
    for (genvar l = 0; l < PIPE_MAX_LANES; l++) begin : pipe_lane_sel
      if (l < PCIE_LANES) begin : active
        assign pipe.tx[l]          = tx_q[l];
        assign pipe.rx_polarity[l] = rx_polarity_q[l];
        assign rx_blk[l]           = rx_q[l];
      end
      else begin : unused
        assign pipe.tx[l]          = PIPE_TX_LANE_TIE;
        assign pipe.rx_polarity[l] = 1'b0;
        assign rx_blk[l]           = PIPE_RX_LANE_TIE;
      end
    end
  endgenerate

  wire cfg_received_func_lvl_rst_n;
  wire cfg_err_cpl_rdy_n;
  wire cfg_interrupt_rdy_n;
  wire cfg_mgmt_rd_wr_done_n;
  wire pl_phy_lnk_up_n;
  wire cfg_err_aer_headerlog_set_n;
  wire cfg_msg_received_pme_to;
  wire cfg_turnoff_ok_w;

  assign cfg_received_func_lvl_rst = ~cfg_received_func_lvl_rst_n;
  assign cfg_err_cpl_rdy           = ~cfg_err_cpl_rdy_n;
  assign cfg_interrupt_rdy         = ~cfg_interrupt_rdy_n;
  assign cfg_mgmt_rd_wr_done       = ~cfg_mgmt_rd_wr_done_n;
  assign pl_phy_lnk_up             = ~pl_phy_lnk_up_n;
  assign cfg_err_aer_headerlog_set = ~cfg_err_aer_headerlog_set_n;
  assign cfg_to_turnoff            = cfg_msg_received_pme_to;

  wire        cfg_command_interrupt_disable, cfg_command_serr_en;
  wire        cfg_command_bus_master_enable, cfg_command_mem_enable, cfg_command_io_enable;
  wire        cfg_dev_status_ur_detected, cfg_dev_status_fatal_err_detected;
  wire        cfg_dev_status_non_fatal_err_detected, cfg_dev_status_corr_err_detected;
  wire  [2:0] cfg_dev_control_max_read_req;
  wire        cfg_dev_control_no_snoop_en, cfg_dev_control_aux_power_en;
  wire        cfg_dev_control_phantom_en, cfg_dev_control_ext_tag_en;
  wire  [2:0] cfg_dev_control_max_payload;
  wire        cfg_dev_control_enable_ro, cfg_dev_control_ur_err_reporting_en;
  wire        cfg_dev_control_fatal_err_reporting_en, cfg_dev_control_non_fatal_reporting_en;
  wire        cfg_dev_control_corr_err_reporting_en;
  wire        cfg_link_status_auto_bandwidth_status, cfg_link_status_bandwidth_status;
  wire        cfg_link_status_dll_active, cfg_link_status_link_training;
  wire  [3:0] cfg_link_status_negotiated_width;
  wire  [1:0] cfg_link_status_current_speed;
  wire        cfg_link_control_auto_bandwidth_int_en, cfg_link_control_bandwidth_int_en;
  wire        cfg_link_control_hw_auto_width_dis, cfg_link_control_clock_pm_en;
  wire        cfg_link_control_extended_sync, cfg_link_control_common_clock;
  wire        cfg_link_control_retrain_link, cfg_link_control_link_disable;
  wire        cfg_link_control_rcb;
  wire  [1:0] cfg_link_control_aspm_control;
  wire        cfg_dev_control2_tlp_prefix_block, cfg_dev_control2_ltr_en;
  wire        cfg_dev_control2_ido_cpl_en, cfg_dev_control2_ido_req_en;
  wire        cfg_dev_control2_atomic_egress_block, cfg_dev_control2_atomic_requester_en;
  wire        cfg_dev_control2_ari_forward_en, cfg_dev_control2_cpl_timeout_dis;
  wire  [3:0] cfg_dev_control2_cpl_timeout_val;

  assign cfg_regs.status   = 16'b0;

  assign cfg_regs.command  = {5'b0,
                              cfg_command_interrupt_disable,
                              1'b0,
                              cfg_command_serr_en,
                              5'b0,
                              cfg_command_bus_master_enable,
                              cfg_command_mem_enable,
                              cfg_command_io_enable};

  assign cfg_regs.dstatus  = {10'h0,
                              cfg_trn_pending,
                              1'b0,
                              cfg_dev_status_ur_detected,
                              cfg_dev_status_fatal_err_detected,
                              cfg_dev_status_non_fatal_err_detected,
                              cfg_dev_status_corr_err_detected};

  assign cfg_regs.dcommand = {1'b0,
                              cfg_dev_control_max_read_req,
                              cfg_dev_control_no_snoop_en,
                              cfg_dev_control_aux_power_en,
                              cfg_dev_control_phantom_en,
                              cfg_dev_control_ext_tag_en,
                              cfg_dev_control_max_payload,
                              cfg_dev_control_enable_ro,
                              cfg_dev_control_ur_err_reporting_en,
                              cfg_dev_control_fatal_err_reporting_en,
                              cfg_dev_control_non_fatal_reporting_en,
                              cfg_dev_control_corr_err_reporting_en};

  assign cfg_regs.lstatus  = {cfg_link_status_auto_bandwidth_status,
                              cfg_link_status_bandwidth_status,
                              cfg_link_status_dll_active,
                              1'b1,
                              cfg_link_status_link_training,
                              1'b0,
                              {2'b00, cfg_link_status_negotiated_width},
                              {2'b00, cfg_link_status_current_speed}};

  assign cfg_regs.lcommand = {4'b0,
                              cfg_link_control_auto_bandwidth_int_en,
                              cfg_link_control_bandwidth_int_en,
                              cfg_link_control_hw_auto_width_dis,
                              cfg_link_control_clock_pm_en,
                              cfg_link_control_extended_sync,
                              cfg_link_control_common_clock,
                              cfg_link_control_retrain_link,
                              cfg_link_control_link_disable,
                              cfg_link_control_rcb,
                              1'b0,
                              cfg_link_control_aspm_control};

  assign cfg_regs.dcommand2 = {4'b0,
                               cfg_dev_control2_tlp_prefix_block,
                               cfg_dev_control2_ltr_en,
                               cfg_dev_control2_ido_cpl_en,
                               cfg_dev_control2_ido_req_en,
                               cfg_dev_control2_atomic_egress_block,
                               cfg_dev_control2_atomic_requester_en,
                               cfg_dev_control2_ari_forward_en,
                               cfg_dev_control2_cpl_timeout_dis,
                               cfg_dev_control2_cpl_timeout_val};

  logic [7:0] cfg_bus_number_d;
  logic [4:0] cfg_device_number_d;
  logic [2:0] cfg_function_number_d;

  assign cfg_bus_number      = cfg_bus_number_d;
  assign cfg_device_number   = cfg_device_number_d;
  assign cfg_function_number = cfg_function_number_d;

  always_ff @(posedge user_clk_out) begin
    if (~user_lnk_up) begin
      cfg_bus_number_d      <= 8'b0;
      cfg_device_number_d   <= 5'b0;
      cfg_function_number_d <= 3'b0;
    end
    else if (~cfg_msg_received) begin
      cfg_bus_number_d      <= cfg_msg_data[15:8];
      cfg_device_number_d   <= cfg_msg_data[7:3];
      cfg_function_number_d <= cfg_msg_data[2:0];
    end
  end

  stream_bridge stream_bridge_i (
    .s_axis_tx            (s_axis_tx),
    .m_axis_rx            (m_axis_rx),

    .user_turnoff_ok      (cfg_turnoff_ok),
    .user_tcfg_gnt        (tx_cfg_gnt),

    .trn_td               (trn_td),
    .trn_tsof             (trn_tsof),
    .trn_teof             (trn_teof),
    .trn_tsrc_rdy         (trn_tsrc_rdy),
    .trn_tdst_rdy         (trn_tdst_rdy),
    .trn_tsrc_dsc         (trn_tsrc_dsc),
    .trn_trem             (trn_trem),
    .trn_terrfwd          (trn_terrfwd),
    .trn_tstr             (trn_tstr),
    .trn_tbuf_av          (tx_buf_av),
    .trn_tecrc_gen        (trn_tecrc_gen),

    .trn_rd               (trn_rd[C_DATA_WIDTH-1:0]),
    .trn_rsof             (trn_rsof),
    .trn_reof             (trn_reof),
    .trn_rsrc_rdy         (trn_rsrc_rdy),
    .trn_rdst_rdy         (trn_rdst_rdy),
    .trn_rsrc_dsc         (trn_rsrc_dsc),
    .trn_rrem             (trn_rrem[REM_WIDTH-1:0]),
    .trn_rerrfwd          (trn_rerrfwd),
    .trn_rbar_hit         (trn_rbar_hit[6:0]),
    .trn_recrc_err        (trn_recrc_err),

    .trn_tcfg_req         (tx_cfg_req),
    .trn_tcfg_gnt         (trn_tcfg_gnt),
    .trn_lnk_up           (user_lnk_up),

    .cfg_pcie_link_state  (cfg_pcie_link_state),
    .cfg_pm_send_pme_to   (1'b0),
    .cfg_pmcsr_powerstate (cfg_pmcsr_powerstate),
    .trn_rdllp_data       (32'b0),
    .trn_rdllp_src_rdy    (1'b0),

    .cfg_to_turnoff       (cfg_to_turnoff),
    .cfg_turnoff_ok       (cfg_turnoff_ok_w),

    .np_counter           (),
    .user_clk             (user_clk_out),
    .user_rst             (user_reset)
  );

  silicon_core silicon_core_i (
    .trn_lnk_up                                (trn_lnk_up),
    .trn_clk                                   (user_clk_out),
    .lnk_clk_en                                (),
    .user_rst_n                                (user_rst_n),
    .received_func_lvl_rst_n                   (cfg_received_func_lvl_rst_n),
    .sys_rst_n                                 (~phy_rdy_n),
    .pl_rst_n                                  (1'b1),
    .dl_rst_n                                  (1'b1),
    .tl_rst_n                                  (1'b1),
    .cm_sticky_rst_n                           (1'b1),
    .func_lvl_rst_n                            (1'b1),
    .cm_rst_n                                  (1'b1),

    .trn_rbar_hit                              (trn_rbar_hit),
    .trn_rd                                    (trn_rd),
    .trn_recrc_err                             (trn_recrc_err),
    .trn_reof                                  (trn_reof),
    .trn_rerrfwd                               (trn_rerrfwd),
    .trn_rrem                                  (trn_rrem),
    .trn_rsof                                  (trn_rsof),
    .trn_rsrc_dsc                              (trn_rsrc_dsc),
    .trn_rsrc_rdy                              (trn_rsrc_rdy),
    .trn_rdst_rdy                              (trn_rdst_rdy),
    .trn_rnp_ok                                (rx_np_ok),
    .trn_rnp_req                               (rx_np_req),
    .trn_rfcp_ret                              (1'b1),
    .trn_tbuf_av                               (tx_buf_av),
    .trn_tcfg_req                              (tx_cfg_req),
    .trn_tdllp_dst_rdy                         (),
    .trn_tdst_rdy                              (trn_tdst_rdy),
    .trn_terr_drop                             (tx_err_drop),
    .trn_tcfg_gnt                              (trn_tcfg_gnt),
    .trn_td                                    (trn_td),
    .trn_tdllp_data                            (32'b0),
    .trn_tdllp_src_rdy                         (1'b0),
    .trn_tecrc_gen                             (trn_tecrc_gen),
    .trn_teof                                  (trn_teof),
    .trn_terrfwd                               (trn_terrfwd),
    .trn_trem                                  (trn_trem),
    .trn_tsof                                  (trn_tsof),
    .trn_tsrc_dsc                              (trn_tsrc_dsc),
    .trn_tsrc_rdy                              (trn_tsrc_rdy),
    .trn_tstr                                  (trn_tstr),

    .trn_fc_cpld                               (fc_cpld),
    .trn_fc_cplh                               (fc_cplh),
    .trn_fc_npd                                (fc_npd),
    .trn_fc_nph                                (fc_nph),
    .trn_fc_pd                                 (fc_pd),
    .trn_fc_ph                                 (fc_ph),
    .trn_fc_sel                                (fc_sel),

    .cfg_dev_id                                (cfg_dev_id),
    .cfg_vend_id                               (cfg_vend_id),
    .cfg_rev_id                                (cfg_rev_id),
    .cfg_subsys_id                             (cfg_subsys_id),
    .cfg_subsys_vend_id                        (cfg_subsys_vend_id),
    .cfg_pciecap_interrupt_msgnum              (cfg_pciecap_interrupt_msgnum),

    .cfg_bridge_serr_en                        (cfg_bridge_serr_en),

    .cfg_command_bus_master_enable             (cfg_command_bus_master_enable),
    .cfg_command_interrupt_disable             (cfg_command_interrupt_disable),
    .cfg_command_io_enable                     (cfg_command_io_enable),
    .cfg_command_mem_enable                    (cfg_command_mem_enable),
    .cfg_command_serr_en                       (cfg_command_serr_en),
    .cfg_dev_control_aux_power_en              (cfg_dev_control_aux_power_en),
    .cfg_dev_control_corr_err_reporting_en     (cfg_dev_control_corr_err_reporting_en),
    .cfg_dev_control_enable_ro                 (cfg_dev_control_enable_ro),
    .cfg_dev_control_ext_tag_en                (cfg_dev_control_ext_tag_en),
    .cfg_dev_control_fatal_err_reporting_en    (cfg_dev_control_fatal_err_reporting_en),
    .cfg_dev_control_max_payload               (cfg_dev_control_max_payload),
    .cfg_dev_control_max_read_req              (cfg_dev_control_max_read_req),
    .cfg_dev_control_non_fatal_reporting_en    (cfg_dev_control_non_fatal_reporting_en),
    .cfg_dev_control_no_snoop_en               (cfg_dev_control_no_snoop_en),
    .cfg_dev_control_phantom_en                (cfg_dev_control_phantom_en),
    .cfg_dev_control_ur_err_reporting_en       (cfg_dev_control_ur_err_reporting_en),
    .cfg_dev_control2_cpl_timeout_dis          (cfg_dev_control2_cpl_timeout_dis),
    .cfg_dev_control2_cpl_timeout_val          (cfg_dev_control2_cpl_timeout_val),
    .cfg_dev_control2_ari_forward_en           (cfg_dev_control2_ari_forward_en),
    .cfg_dev_control2_atomic_requester_en      (cfg_dev_control2_atomic_requester_en),
    .cfg_dev_control2_atomic_egress_block      (cfg_dev_control2_atomic_egress_block),
    .cfg_dev_control2_ido_req_en               (cfg_dev_control2_ido_req_en),
    .cfg_dev_control2_ido_cpl_en               (cfg_dev_control2_ido_cpl_en),
    .cfg_dev_control2_ltr_en                   (cfg_dev_control2_ltr_en),
    .cfg_dev_control2_tlp_prefix_block         (cfg_dev_control2_tlp_prefix_block),
    .cfg_dev_status_corr_err_detected          (cfg_dev_status_corr_err_detected),
    .cfg_dev_status_fatal_err_detected         (cfg_dev_status_fatal_err_detected),
    .cfg_dev_status_non_fatal_err_detected     (cfg_dev_status_non_fatal_err_detected),
    .cfg_dev_status_ur_detected                (cfg_dev_status_ur_detected),

    .cfg_mgmt_do                               (cfg_mgmt_do),
    .cfg_err_aer_headerlog_set_n               (cfg_err_aer_headerlog_set_n),
    .cfg_err_aer_headerlog                     (cfg_err_aer_headerlog),
    .cfg_err_cpl_rdy_n                         (cfg_err_cpl_rdy_n),
    .cfg_interrupt_do                          (cfg_interrupt_do),
    .cfg_interrupt_mmenable                    (cfg_interrupt_mmenable),
    .cfg_interrupt_msienable                   (cfg_interrupt_msienable),
    .cfg_interrupt_msixenable                  (cfg_interrupt_msixenable),
    .cfg_interrupt_msixfm                      (cfg_interrupt_msixfm),
    .cfg_interrupt_rdy_n                       (cfg_interrupt_rdy_n),
    .cfg_link_control_rcb                      (cfg_link_control_rcb),
    .cfg_link_control_aspm_control             (cfg_link_control_aspm_control),
    .cfg_link_control_auto_bandwidth_int_en    (cfg_link_control_auto_bandwidth_int_en),
    .cfg_link_control_bandwidth_int_en         (cfg_link_control_bandwidth_int_en),
    .cfg_link_control_clock_pm_en              (cfg_link_control_clock_pm_en),
    .cfg_link_control_common_clock             (cfg_link_control_common_clock),
    .cfg_link_control_extended_sync            (cfg_link_control_extended_sync),
    .cfg_link_control_hw_auto_width_dis        (cfg_link_control_hw_auto_width_dis),
    .cfg_link_control_link_disable             (cfg_link_control_link_disable),
    .cfg_link_control_retrain_link             (cfg_link_control_retrain_link),
    .cfg_link_status_auto_bandwidth_status     (cfg_link_status_auto_bandwidth_status),
    .cfg_link_status_bandwidth_status          (cfg_link_status_bandwidth_status),
    .cfg_link_status_current_speed             (cfg_link_status_current_speed),
    .cfg_link_status_dll_active                (cfg_link_status_dll_active),
    .cfg_link_status_link_training             (cfg_link_status_link_training),
    .cfg_link_status_negotiated_width          (cfg_link_status_negotiated_width),
    .cfg_msg_data                              (cfg_msg_data),
    .cfg_msg_received                          (cfg_msg_received),
    .cfg_msg_received_assert_int_a             (cfg_msg_received_assert_int_a),
    .cfg_msg_received_assert_int_b             (cfg_msg_received_assert_int_b),
    .cfg_msg_received_assert_int_c             (cfg_msg_received_assert_int_c),
    .cfg_msg_received_assert_int_d             (cfg_msg_received_assert_int_d),
    .cfg_msg_received_deassert_int_a           (cfg_msg_received_deassert_int_a),
    .cfg_msg_received_deassert_int_b           (cfg_msg_received_deassert_int_b),
    .cfg_msg_received_deassert_int_c           (cfg_msg_received_deassert_int_c),
    .cfg_msg_received_deassert_int_d           (cfg_msg_received_deassert_int_d),
    .cfg_msg_received_err_cor                  (cfg_msg_received_err_cor),
    .cfg_msg_received_err_fatal                (cfg_msg_received_err_fatal),
    .cfg_msg_received_err_non_fatal            (cfg_msg_received_err_non_fatal),
    .cfg_msg_received_pm_as_nak                (cfg_msg_received_pm_as_nak),
    .cfg_msg_received_pme_to                   (cfg_msg_received_pme_to),
    .cfg_msg_received_pme_to_ack               (cfg_msg_received_pme_to_ack),
    .cfg_msg_received_pm_pme                   (cfg_msg_received_pm_pme),
    .cfg_msg_received_setslotpowerlimit        (cfg_msg_received_setslotpowerlimit),
    .cfg_msg_received_unlock                   (),
    .cfg_pcie_link_state                       (cfg_pcie_link_state),
    .cfg_pmcsr_pme_en                          (cfg_pmcsr_pme_en),
    .cfg_pmcsr_powerstate                      (cfg_pmcsr_powerstate),
    .cfg_pmcsr_pme_status                      (cfg_pmcsr_pme_status),
    .cfg_pm_rcv_as_req_l1_n                    (),
    .cfg_pm_rcv_enter_l1_n                     (),
    .cfg_pm_rcv_enter_l23_n                    (),
    .cfg_pm_rcv_req_ack_n                      (),
    .cfg_mgmt_rd_wr_done_n                     (cfg_mgmt_rd_wr_done_n),
    .cfg_slot_control_electromech_il_ctl_pulse (cfg_slot_control_electromech_il_ctl_pulse),
    .cfg_root_control_syserr_corr_err_en       (cfg_root_control_syserr_corr_err_en),
    .cfg_root_control_syserr_non_fatal_err_en  (cfg_root_control_syserr_non_fatal_err_en),
    .cfg_root_control_syserr_fatal_err_en      (cfg_root_control_syserr_fatal_err_en),
    .cfg_root_control_pme_int_en               (cfg_root_control_pme_int_en),
    .cfg_aer_ecrc_check_en                     (cfg_aer_ecrc_check_en),
    .cfg_aer_ecrc_gen_en                       (cfg_aer_ecrc_gen_en),
    .cfg_aer_rooterr_corr_err_reporting_en     (cfg_aer_rooterr_corr_err_reporting_en),
    .cfg_aer_rooterr_non_fatal_err_reporting_en (cfg_aer_rooterr_non_fatal_err_reporting_en),
    .cfg_aer_rooterr_fatal_err_reporting_en    (cfg_aer_rooterr_fatal_err_reporting_en),
    .cfg_aer_rooterr_corr_err_received         (cfg_aer_rooterr_corr_err_received),
    .cfg_aer_rooterr_non_fatal_err_received    (cfg_aer_rooterr_non_fatal_err_received),
    .cfg_aer_rooterr_fatal_err_received        (cfg_aer_rooterr_fatal_err_received),
    .cfg_aer_interrupt_msgnum                  (cfg_aer_interrupt_msgnum),
    .cfg_transaction                           (),
    .cfg_transaction_addr                      (),
    .cfg_transaction_type                      (),
    .cfg_vc_tcvc_map                           (cfg_vc_tcvc_map),
    .cfg_mgmt_byte_en_n                        (~cfg_mgmt_byte_en),
    .cfg_mgmt_di                               (cfg_mgmt_di),
    .cfg_ds_bus_number                         (cfg_ds_bus_number),
    .cfg_ds_device_number                      (cfg_ds_device_number),
    .cfg_ds_function_number                    (cfg_ds_function_number),
    .cfg_dsn                                   (cfg_dsn),
    .cfg_mgmt_dwaddr                           (cfg_mgmt_dwaddr),
    .cfg_err_acs_n                             (1'b1),
    .cfg_err_cor_n                             (~cfg_err_cor),
    .cfg_err_cpl_abort_n                       (~cfg_err_cpl_abort),
    .cfg_err_cpl_timeout_n                     (~cfg_err_cpl_timeout),
    .cfg_err_cpl_unexpect_n                    (~cfg_err_cpl_unexpect),
    .cfg_err_ecrc_n                            (~cfg_err_ecrc),
    .cfg_err_locked_n                          (~cfg_err_locked),
    .cfg_err_posted_n                          (~cfg_err_posted),
    .cfg_err_tlp_cpl_header                    (cfg_err_tlp_cpl_header),
    .cfg_err_ur_n                              (~cfg_err_ur),
    .cfg_err_malformed_n                       (~cfg_err_malformed),
    .cfg_err_poisoned_n                        (~cfg_err_poisoned),
    .cfg_err_atomic_egress_blocked_n           (~cfg_err_atomic_egress_blocked),
    .cfg_err_mc_blocked_n                      (~cfg_err_mc_blocked),
    .cfg_err_internal_uncor_n                  (~cfg_err_internal_uncor),
    .cfg_err_internal_cor_n                    (~cfg_err_internal_cor),
    .cfg_err_norecovery_n                      (~cfg_err_norecovery),

    .cfg_interrupt_assert_n                    (~cfg_interrupt_assert),
    .cfg_interrupt_di                          (cfg_interrupt_di),
    .cfg_interrupt_n                           (~cfg_interrupt),
    .cfg_interrupt_stat_n                      (~cfg_interrupt_stat),
    .cfg_pm_send_pme_to_n                      (1'b1),
    .cfg_pm_turnoff_ok_n                       (cfg_turnoff_ok_w),
    .cfg_pm_wake_n                             (~cfg_pm_wake),
    .cfg_pm_halt_aspm_l0s_n                    (~cfg_pm_halt_aspm_l0s),
    .cfg_pm_halt_aspm_l1_n                     (~cfg_pm_halt_aspm_l1),
    .cfg_pm_force_state_en_n                   (~cfg_pm_force_state_en),
    .cfg_pm_force_state                        (cfg_pm_force_state),
    .cfg_force_mps                             (3'b0),
    .cfg_force_common_clock_off                (1'b0),
    .cfg_force_extended_sync_on                (1'b0),
    .cfg_port_number                           (8'b0),
    .cfg_mgmt_rd_en_n                          (~cfg_mgmt_rd_en),
    .cfg_trn_pending_n                         (~cfg_trn_pending),
    .cfg_mgmt_wr_en_n                          (~cfg_mgmt_wr_en),
    .cfg_mgmt_wr_readonly_n                    (~cfg_mgmt_wr_readonly),
    .cfg_mgmt_wr_rw1c_as_rw_n                  (~cfg_mgmt_wr_rw1c_as_rw),

    .pl_initial_link_width                     (pl_initial_link_width),
    .pl_lane_reversal_mode                     (pl_lane_reversal_mode),
    .pl_link_gen2_cap                          (pl_link_gen2_cap),
    .pl_link_partner_gen2_supported            (pl_link_partner_gen2_supported),
    .pl_link_upcfg_cap                         (pl_link_upcfg_cap),
    .pl_ltssm_state                            (pl_ltssm_state),
    .pl_phy_lnk_up_n                           (pl_phy_lnk_up_n),
    .pl_received_hot_rst                       (pl_received_hot_rst),
    .pl_rx_pm_state                            (pl_rx_pm_state),
    .pl_sel_lnk_rate                           (pl_sel_lnk_rate),
    .pl_sel_lnk_width                          (pl_sel_lnk_width),
    .pl_tx_pm_state                            (pl_tx_pm_state),
    .pl_directed_link_auton                    (pl_directed_link_auton),
    .pl_directed_link_change                   (pl_directed_link_change),
    .pl_directed_link_speed                    (pl_directed_link_speed),
    .pl_directed_link_width                    (pl_directed_link_width),
    .pl_downstream_deemph_source               (pl_downstream_deemph_source),
    .pl_upstream_prefer_deemph                 (pl_upstream_prefer_deemph),
    .pl_transmit_hot_rst                       (pl_transmit_hot_rst),
    .pl_directed_ltssm_new_vld                 (1'b0),
    .pl_directed_ltssm_new                     (6'b0),
    .pl_directed_ltssm_stall                   (1'b0),
    .pl_directed_change_done                   (pl_directed_change_done),

    .dbg_sclr_a                                (),
    .dbg_sclr_b                                (),
    .dbg_sclr_c                                (),
    .dbg_sclr_d                                (),
    .dbg_sclr_e                                (),
    .dbg_sclr_f                                (),
    .dbg_sclr_g                                (),
    .dbg_sclr_h                                (),
    .dbg_sclr_i                                (),
    .dbg_sclr_j                                (),
    .dbg_sclr_k                                (),
    .dbg_vec_a                                 (),
    .dbg_vec_b                                 (),
    .dbg_vec_c                                 (),
    .pl_dbg_vec                                (),
    .trn_rdllp_data                            (),
    .trn_rdllp_src_rdy                         (),
    .dbg_mode                                  (2'b0),
    .dbg_sub_mode                              (1'b0),
    .pl_dbg_mode                               (3'b0),

    .drp_clk                                   (pcie_drp_clk),
    .drp_do                                    (pcie_drp_do),
    .drp_rdy                                   (pcie_drp_rdy),
    .drp_addr                                  (pcie_drp_addr),
    .drp_en                                    (pcie_drp_en),
    .drp_di                                    (pcie_drp_di),
    .drp_we                                    (pcie_drp_we),

    .ll2_tlp_rcv                               (1'b0),
    .ll2_send_enter_l1                         (1'b0),
    .ll2_send_enter_l23                        (1'b0),
    .ll2_send_as_req_l1                        (1'b0),
    .ll2_send_pm_ack                           (1'b0),
    .ll2_suspend_now                           (1'b0),
    .ll2_tfc_init1_seq                         (),
    .ll2_tfc_init2_seq                         (),
    .ll2_suspend_ok                            (),
    .ll2_tx_idle                               (),
    .ll2_link_status                           (),
    .ll2_receiver_err                          (),
    .ll2_protocol_err                          (),
    .ll2_bad_tlp_err                           (),
    .ll2_bad_dllp_err                          (),
    .ll2_replay_ro_err                         (),
    .ll2_replay_to_err                         (),
    .tl2_ppm_suspend_req                       (1'b0),
    .tl2_aspm_suspend_credit_check             (1'b0),
    .tl2_ppm_suspend_ok                        (),
    .tl2_aspm_suspend_req                      (),
    .tl2_aspm_suspend_credit_check_ok          (),
    .tl2_err_hdr                               (),
    .tl2_err_malformed                         (),
    .tl2_err_rxoverflow                        (),
    .tl2_err_fcpe                              (),
    .pl2_directed_lstate                       (5'b0),
    .pl2_suspend_ok                            (),
    .pl2_recovery                              (),
    .pl2_rx_elec_idle                          (),
    .pl2_rx_pm_state                           (),
    .pl2_l0_req                                (),
    .pl2_link_up                               (),
    .pl2_receiver_err                          (),

    .pipe_clk                                  (pipe_clk),
    .user_clk2                                 (user_clk2),
    .user_clk                                  (user_clk),

    .pipe_rx0_polarity                         (rx_polarity_flat[0]),
    .pipe_rx1_polarity                         (rx_polarity_flat[1]),
    .pipe_rx2_polarity                         (rx_polarity_flat[2]),
    .pipe_rx3_polarity                         (rx_polarity_flat[3]),
    .pipe_rx4_polarity                         (rx_polarity_flat[4]),
    .pipe_rx5_polarity                         (rx_polarity_flat[5]),
    .pipe_rx6_polarity                         (rx_polarity_flat[6]),
    .pipe_rx7_polarity                         (rx_polarity_flat[7]),
    .pipe_tx0_compliance                       (tx_compliance_blk[0]),
    .pipe_tx1_compliance                       (tx_compliance_blk[1]),
    .pipe_tx2_compliance                       (tx_compliance_blk[2]),
    .pipe_tx3_compliance                       (tx_compliance_blk[3]),
    .pipe_tx4_compliance                       (tx_compliance_blk[4]),
    .pipe_tx5_compliance                       (tx_compliance_blk[5]),
    .pipe_tx6_compliance                       (tx_compliance_blk[6]),
    .pipe_tx7_compliance                       (tx_compliance_blk[7]),
    .pipe_tx0_char_is_k                        (tx_char_is_k_blk[0]),
    .pipe_tx1_char_is_k                        (tx_char_is_k_blk[1]),
    .pipe_tx2_char_is_k                        (tx_char_is_k_blk[2]),
    .pipe_tx3_char_is_k                        (tx_char_is_k_blk[3]),
    .pipe_tx4_char_is_k                        (tx_char_is_k_blk[4]),
    .pipe_tx5_char_is_k                        (tx_char_is_k_blk[5]),
    .pipe_tx6_char_is_k                        (tx_char_is_k_blk[6]),
    .pipe_tx7_char_is_k                        (tx_char_is_k_blk[7]),
    .pipe_tx0_data                             (tx_data_blk[0]),
    .pipe_tx1_data                             (tx_data_blk[1]),
    .pipe_tx2_data                             (tx_data_blk[2]),
    .pipe_tx3_data                             (tx_data_blk[3]),
    .pipe_tx4_data                             (tx_data_blk[4]),
    .pipe_tx5_data                             (tx_data_blk[5]),
    .pipe_tx6_data                             (tx_data_blk[6]),
    .pipe_tx7_data                             (tx_data_blk[7]),
    .pipe_tx0_elec_idle                        (tx_elec_idle_blk[0]),
    .pipe_tx1_elec_idle                        (tx_elec_idle_blk[1]),
    .pipe_tx2_elec_idle                        (tx_elec_idle_blk[2]),
    .pipe_tx3_elec_idle                        (tx_elec_idle_blk[3]),
    .pipe_tx4_elec_idle                        (tx_elec_idle_blk[4]),
    .pipe_tx5_elec_idle                        (tx_elec_idle_blk[5]),
    .pipe_tx6_elec_idle                        (tx_elec_idle_blk[6]),
    .pipe_tx7_elec_idle                        (tx_elec_idle_blk[7]),
    .pipe_tx0_powerdown                        (tx_powerdown_blk[0]),
    .pipe_tx1_powerdown                        (tx_powerdown_blk[1]),
    .pipe_tx2_powerdown                        (tx_powerdown_blk[2]),
    .pipe_tx3_powerdown                        (tx_powerdown_blk[3]),
    .pipe_tx4_powerdown                        (tx_powerdown_blk[4]),
    .pipe_tx5_powerdown                        (tx_powerdown_blk[5]),
    .pipe_tx6_powerdown                        (tx_powerdown_blk[6]),
    .pipe_tx7_powerdown                        (tx_powerdown_blk[7]),

    .pipe_rx0_char_is_k                        (rx_blk[0].char_is_k),
    .pipe_rx1_char_is_k                        (rx_blk[1].char_is_k),
    .pipe_rx2_char_is_k                        (rx_blk[2].char_is_k),
    .pipe_rx3_char_is_k                        (rx_blk[3].char_is_k),
    .pipe_rx4_char_is_k                        (rx_blk[4].char_is_k),
    .pipe_rx5_char_is_k                        (rx_blk[5].char_is_k),
    .pipe_rx6_char_is_k                        (rx_blk[6].char_is_k),
    .pipe_rx7_char_is_k                        (rx_blk[7].char_is_k),
    .pipe_rx0_valid                            (rx_blk[0].valid),
    .pipe_rx1_valid                            (rx_blk[1].valid),
    .pipe_rx2_valid                            (rx_blk[2].valid),
    .pipe_rx3_valid                            (rx_blk[3].valid),
    .pipe_rx4_valid                            (rx_blk[4].valid),
    .pipe_rx5_valid                            (rx_blk[5].valid),
    .pipe_rx6_valid                            (rx_blk[6].valid),
    .pipe_rx7_valid                            (rx_blk[7].valid),
    .pipe_rx0_data                             (rx_blk[0].data),
    .pipe_rx1_data                             (rx_blk[1].data),
    .pipe_rx2_data                             (rx_blk[2].data),
    .pipe_rx3_data                             (rx_blk[3].data),
    .pipe_rx4_data                             (rx_blk[4].data),
    .pipe_rx5_data                             (rx_blk[5].data),
    .pipe_rx6_data                             (rx_blk[6].data),
    .pipe_rx7_data                             (rx_blk[7].data),
    .pipe_rx0_chanisaligned                    (rx_blk[0].chanisaligned),
    .pipe_rx1_chanisaligned                    (rx_blk[1].chanisaligned),
    .pipe_rx2_chanisaligned                    (rx_blk[2].chanisaligned),
    .pipe_rx3_chanisaligned                    (rx_blk[3].chanisaligned),
    .pipe_rx4_chanisaligned                    (rx_blk[4].chanisaligned),
    .pipe_rx5_chanisaligned                    (rx_blk[5].chanisaligned),
    .pipe_rx6_chanisaligned                    (rx_blk[6].chanisaligned),
    .pipe_rx7_chanisaligned                    (rx_blk[7].chanisaligned),
    .pipe_rx0_status                           (rx_blk[0].status),
    .pipe_rx1_status                           (rx_blk[1].status),
    .pipe_rx2_status                           (rx_blk[2].status),
    .pipe_rx3_status                           (rx_blk[3].status),
    .pipe_rx4_status                           (rx_blk[4].status),
    .pipe_rx5_status                           (rx_blk[5].status),
    .pipe_rx6_status                           (rx_blk[6].status),
    .pipe_rx7_status                           (rx_blk[7].status),
    .pipe_rx0_phy_status                       (rx_blk[0].phy_status),
    .pipe_rx1_phy_status                       (rx_blk[1].phy_status),
    .pipe_rx2_phy_status                       (rx_blk[2].phy_status),
    .pipe_rx3_phy_status                       (rx_blk[3].phy_status),
    .pipe_rx4_phy_status                       (rx_blk[4].phy_status),
    .pipe_rx5_phy_status                       (rx_blk[5].phy_status),
    .pipe_rx6_phy_status                       (rx_blk[6].phy_status),
    .pipe_rx7_phy_status                       (rx_blk[7].phy_status),
    .pipe_tx_deemph                            (tx_deemph_blk),
    .pipe_tx_margin                            (tx_margin_blk),
    .pipe_tx_reset                             (tx_reset_blk),
    .pipe_tx_rcvr_det                          (tx_rcvr_det_blk),
    .pipe_tx_rate                              (tx_rate_blk),

    .pipe_rx0_elec_idle                        (rx_blk[0].elec_idle),
    .pipe_rx1_elec_idle                        (rx_blk[1].elec_idle),
    .pipe_rx2_elec_idle                        (rx_blk[2].elec_idle),
    .pipe_rx3_elec_idle                        (rx_blk[3].elec_idle),
    .pipe_rx4_elec_idle                        (rx_blk[4].elec_idle),
    .pipe_rx5_elec_idle                        (rx_blk[5].elec_idle),
    .pipe_rx6_elec_idle                        (rx_blk[6].elec_idle),
    .pipe_rx7_elec_idle                        (rx_blk[7].elec_idle)
  );

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
