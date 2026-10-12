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

module pcie_core
  import link_pkg::*;
#(
  localparam int C_DATA_WIDTH  = 64,
  localparam int REM_WIDTH     = 1
) (
  output                     user_clk_out,
  input                      user_reset,
  input                      user_lnk_up,
  output                     trn_lnk_up,
  output                     user_rst_n,

  axis_if.slave         s_axis_tx,
  axis_if.master        m_axis_rx,

  output  [5:0]              tx_buf_avail,

  input  [15:0]              cfg_dev_id,
  input  [15:0]              cfg_vend_id,
  input   [7:0]              cfg_rev_id,
  input  [15:0]              cfg_subsys_id,
  input  [15:0]              cfg_subsys_vend_id,

  output                     cfg_msg_received_err_fatal,

  output  [5:0]              pl_ltssm_state,
  output                     pl_phy_lnk_up,
  output                     pl_received_hot_rst,

  pipe_if.mac           pipe_mac,
  input                      phy_rdy_n,
  input                      pipe_clk,
  input                      user_clk
);

  wire  tx_cfg_req;
  wire  cfg_to_turnoff;
  wire [2:0] cfg_pcie_link_state;
  wire [1:0] cfg_pmcsr_powerstate;
  wire  cfg_msg_received;
  wire [15:0] cfg_msg_data;

  assign user_clk_out = user_clk;

  // TRN bus between trn_bridge and the PCIE_2_1 block below; the block's
  // wider RX fields are cut here.
  trn_if #(.DATA_W(C_DATA_WIDTH), .REM_W(REM_WIDTH)) trn ();

  wire [127:0]             trn_rd;
  wire [1:0]               trn_rrem;
  wire [7:0]               trn_rbar_hit;

  assign trn.rd       = trn_rd[C_DATA_WIDTH-1:0];
  assign trn.rrem     = trn_rrem[REM_WIDTH-1:0];
  assign trn.rbar_hit = trn_rbar_hit[6:0];
  assign trn.tbuf_av  = tx_buf_avail;
  assign trn.tcfg_req = tx_cfg_req;
  assign trn.lnk_up   = user_lnk_up;
  assign trn.rx_dllp_data    = 32'b0;   // received DLLPs: not used yet
  assign trn.rx_dllp_src_rdy = 1'b0;

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
      rx_q          <= pipe_mac.rx;
    end
  end

  assign pipe_mac.tx_ctrl = tx_ctrl_q;

  generate
    for (genvar l = 0; l < PIPE_MAX_LANES; l++) begin : pipe_lane_sel
      if (l < PCIE_LANES) begin : active
        assign pipe_mac.tx[l]          = tx_q[l];
        assign pipe_mac.rx_polarity[l] = rx_polarity_q[l];
        assign rx_blk[l]           = rx_q[l];
      end
      else begin : unused
        assign pipe_mac.tx[l]          = PIPE_TX_LANE_TIE;
        assign pipe_mac.rx_polarity[l] = 1'b0;
        assign rx_blk[l]           = PIPE_RX_LANE_TIE;
      end
    end
  endgenerate

  wire pl_phy_lnk_up_n;
  wire cfg_msg_received_pme_to;
  wire cfg_turnoff_ok_w;

  assign pl_phy_lnk_up             = ~pl_phy_lnk_up_n;
  assign cfg_to_turnoff            = cfg_msg_received_pme_to;

  wire        cfg_command_interrupt_disable, cfg_command_serr_en;
  wire        cfg_command_bus_master_enable, cfg_command_mem_enable, cfg_command_io_enable;
  wire        cfg_dev_status_ur_detected, cfg_dev_status_fatal_err_detected;
  wire        cfg_dev_status_non_fatal_err_detected, cfg_dev_status_corr_err_detected;
  wire        cfg_dev_control_no_snoop_en, cfg_dev_control_aux_power_en;
  wire        cfg_dev_control_phantom_en, cfg_dev_control_ext_tag_en;
  wire        cfg_dev_control_enable_ro, cfg_dev_control_ur_err_reporting_en;
  wire        cfg_dev_control_fatal_err_reporting_en, cfg_dev_control_non_fatal_reporting_en;
  wire        cfg_link_status_auto_bandwidth_status, cfg_link_status_bandwidth_status;
  wire        cfg_link_status_dll_active, cfg_link_status_link_training;
  wire        cfg_link_control_auto_bandwidth_int_en, cfg_link_control_bandwidth_int_en;
  wire        cfg_link_control_hw_auto_width_dis, cfg_link_control_clock_pm_en;
  wire        cfg_link_control_extended_sync, cfg_link_control_common_clock;
  wire        cfg_link_control_retrain_link, cfg_link_control_link_disable;
  wire        cfg_dev_control2_tlp_prefix_block, cfg_dev_control2_ltr_en;
  wire        cfg_dev_control2_ido_cpl_en, cfg_dev_control2_ido_req_en;
  wire        cfg_dev_control2_atomic_egress_block, cfg_dev_control2_atomic_requester_en;
  wire        cfg_dev_control2_ari_forward_en, cfg_dev_control2_cpl_timeout_dis;

  logic [7:0] cfg_bus_number_d;
  logic [4:0] cfg_device_number_d;
  logic [2:0] cfg_function_number_d;

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

  trn_bridge u_trn_bridge (
    .s_axis_tx            (s_axis_tx),
    .m_axis_rx            (m_axis_rx),

    .trn                  (trn),

    .cfg_pcie_link_state  (cfg_pcie_link_state),
    .cfg_pmcsr_powerstate (cfg_pmcsr_powerstate),

    .cfg_to_turnoff       (cfg_to_turnoff),
    .cfg_turnoff_ok       (cfg_turnoff_ok_w),

    .user_clk             (user_clk_out),
    .user_rst             (user_reset)
  );

  // ---- PCIE_2_1 hard block and its RX/TX buffers
  localparam [11:0] AER_BASE_PTR = 12'h000;
  localparam AER_CAP_ECRC_CHECK_CAPABLE = "FALSE";
  localparam AER_CAP_ECRC_GEN_CAPABLE = "FALSE";
  localparam [15:0] AER_CAP_ID = 16'h0001;
  localparam AER_CAP_MULTIHEADER = "FALSE";
  localparam [11:0] AER_CAP_NEXTPTR = 12'h000;
  localparam AER_CAP_ON = "FALSE";
  localparam [23:0] AER_CAP_OPTIONAL_ERR_SUPPORT = 24'h000000;
  localparam AER_CAP_PERMIT_ROOTERR_UPDATE = "FALSE";
  localparam [3:0] AER_CAP_VERSION = 4'h1;
  localparam ALLOW_X8_GEN2 = "FALSE";
  localparam [31:0] BAR0 = 32'hFFFFF800;
  localparam [31:0] BAR1 = 32'h00000000;
  localparam [31:0] BAR2 = 32'h00FF00FF;
  localparam [31:0] BAR3 = 32'hFFFF0000;
  localparam [31:0] BAR4 = 32'hFF00FF00;
  localparam [31:0] BAR5 = 32'h00000000;
  localparam [7:0] CAPABILITIES_PTR = 8'h40;
  localparam [31:0] CARDBUS_CIS_POINTER = 32'h00000000;
  localparam CFG_ECRC_ERR_CPLSTAT = 0;
  localparam [23:0] CLASS_CODE = 24'h060000;
  localparam CMD_INTX_IMPLEMENTED = "TRUE";
  localparam CPL_TIMEOUT_DISABLE_SUPPORTED = "FALSE";
  localparam [3:0] CPL_TIMEOUT_RANGES_SUPPORTED = 4'h2;
  localparam [6:0] CRM_MODULE_RSTS = 7'h00;
  localparam DEV_CAP2_ARI_FORWARDING_SUPPORTED = "FALSE";
  localparam DEV_CAP2_ATOMICOP32_COMPLETER_SUPPORTED = "FALSE";
  localparam DEV_CAP2_ATOMICOP64_COMPLETER_SUPPORTED = "FALSE";
  localparam DEV_CAP2_ATOMICOP_ROUTING_SUPPORTED = "FALSE";
  localparam DEV_CAP2_CAS128_COMPLETER_SUPPORTED = "FALSE";
  localparam DEV_CAP2_ENDEND_TLP_PREFIX_SUPPORTED = "FALSE";
  localparam DEV_CAP2_EXTENDED_FMT_FIELD_SUPPORTED = "FALSE";
  localparam DEV_CAP2_LTR_MECHANISM_SUPPORTED = "FALSE";
  localparam [1:0] DEV_CAP2_MAX_ENDEND_TLP_PREFIXES = 2'h0;
  localparam DEV_CAP2_NO_RO_ENABLED_PRPR_PASSING = "FALSE";
  localparam [1:0] DEV_CAP2_TPH_COMPLETER_SUPPORTED = 2'b00;
  localparam DEV_CAP_ENABLE_SLOT_PWR_LIMIT_SCALE = "TRUE";
  localparam DEV_CAP_ENABLE_SLOT_PWR_LIMIT_VALUE = "TRUE";
  localparam integer DEV_CAP_ENDPOINT_L0S_LATENCY = 0;
  localparam integer DEV_CAP_ENDPOINT_L1_LATENCY = 0;
  localparam DEV_CAP_EXT_TAG_SUPPORTED = "FALSE";
  localparam DEV_CAP_FUNCTION_LEVEL_RESET_CAPABLE = "FALSE";
  localparam integer DEV_CAP_MAX_PAYLOAD_SUPPORTED = 2;
  localparam integer DEV_CAP_PHANTOM_FUNCTIONS_SUPPORT = 0;
  localparam DEV_CAP_ROLE_BASED_ERROR = "TRUE";
  localparam integer DEV_CAP_RSVD_14_12 = 0;
  localparam integer DEV_CAP_RSVD_17_16 = 0;
  localparam integer DEV_CAP_RSVD_31_29 = 0;
  localparam DEV_CONTROL_AUX_POWER_SUPPORTED = "FALSE";
  localparam DEV_CONTROL_EXT_TAG_DEFAULT = "FALSE";
  localparam DISABLE_ASPM_L1_TIMER = "FALSE";
  localparam DISABLE_BAR_FILTERING = "FALSE";
  localparam DISABLE_ERR_MSG = "FALSE";
  localparam DISABLE_ID_CHECK = "FALSE";
  localparam DISABLE_LANE_REVERSAL = "TRUE";
  localparam DISABLE_LOCKED_FILTER = "FALSE";
  localparam DISABLE_PPM_FILTER = "FALSE";
  localparam DISABLE_RX_POISONED_RESP = "FALSE";
  localparam DISABLE_RX_TC_FILTER = "FALSE";
  // Co-simulation override. Only 5.sim/Makefile defines it; both synthesis
  // flows take the "FALSE" branch, unchanged.
`ifdef SIM_PIPE_CODING
  localparam DISABLE_SCRAMBLING = "TRUE";
`else
  localparam DISABLE_SCRAMBLING = "FALSE";
`endif
  localparam [7:0] DNSTREAM_LINK_NUM = 8'h00;
  localparam [11:0] DSN_BASE_PTR = 12'h100;
  localparam [15:0] DSN_CAP_ID = 16'h0003;
  localparam [11:0] DSN_CAP_NEXTPTR = 12'h000;
  localparam DSN_CAP_ON = "TRUE";
  localparam [3:0] DSN_CAP_VERSION = 4'h1;
  localparam [10:0] ENABLE_MSG_ROUTE = 11'b00000000000;
  localparam ENABLE_RX_TD_ECRC_TRIM = "FALSE";
  localparam ENDEND_TLP_PREFIX_FORWARDING_SUPPORTED = "FALSE";
  localparam ENTER_RVRY_EI_L0 = "TRUE";
  localparam EXIT_LOOPBACK_ON_EI = "TRUE";
  localparam [31:0] EXPANSION_ROM = 32'h00000000;
  localparam [5:0] EXT_CFG_CAP_PTR = 6'h3F;
  localparam [9:0] EXT_CFG_XP_CAP_PTR = 10'h3FF;
  localparam [7:0] HEADER_TYPE = 8'h01;
  localparam [4:0] INFER_EI = 5'h00;
  localparam [7:0] INTERRUPT_PIN = 8'h1;
  localparam INTERRUPT_STAT_AUTO = "TRUE";
  localparam IS_SWITCH = "FALSE";
  localparam [9:0] LAST_CONFIG_DWORD = 10'h3FF;
  localparam LINK_CAP_ASPM_OPTIONALITY = "FALSE";
  localparam integer LINK_CAP_ASPM_SUPPORT = 1;
  localparam LINK_CAP_CLOCK_POWER_MANAGEMENT = "FALSE";
  localparam LINK_CAP_DLL_LINK_ACTIVE_REPORTING_CAP = "FALSE";
  localparam integer LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN1 = 7;
  localparam integer LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN2 = 7;
  localparam integer LINK_CAP_L0S_EXIT_LATENCY_GEN1 = 7;
  localparam integer LINK_CAP_L0S_EXIT_LATENCY_GEN2 = 7;
  localparam integer LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN1 = 7;
  localparam integer LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN2 = 7;
  localparam integer LINK_CAP_L1_EXIT_LATENCY_GEN1 = 7;
  localparam integer LINK_CAP_L1_EXIT_LATENCY_GEN2 = 7;
  localparam LINK_CAP_LINK_BANDWIDTH_NOTIFICATION_CAP = "FALSE";
  localparam integer LINK_CAP_RSVD_23 = 0;
  localparam LINK_CAP_SURPRISE_DOWN_ERROR_CAPABLE = "FALSE";
  localparam integer LINK_CONTROL_RCB = 0;
  localparam LINK_CTRL2_DEEMPHASIS = "FALSE";
  localparam LINK_CTRL2_HW_AUTONOMOUS_SPEED_DISABLE = "FALSE";
  localparam LINK_STATUS_SLOT_CLOCK_CONFIG = "TRUE";
  localparam [14:0] LL_ACK_TIMEOUT = 15'h0000;
  localparam LL_ACK_TIMEOUT_EN = "FALSE";
  localparam integer LL_ACK_TIMEOUT_FUNC = 0;
  localparam [14:0] LL_REPLAY_TIMEOUT = 15'h0000;
  localparam LL_REPLAY_TIMEOUT_EN = "FALSE";
  localparam integer LL_REPLAY_TIMEOUT_FUNC = 1;
  localparam MPS_FORCE = "FALSE";
  localparam [7:0] MSIX_BASE_PTR = 8'h9C;
  localparam [7:0] MSIX_CAP_ID = 8'h11;
  localparam [7:0] MSIX_CAP_NEXTPTR = 8'h00;
  localparam MSIX_CAP_ON = "FALSE";
  localparam integer MSIX_CAP_PBA_BIR = 0;
  localparam [28:0] MSIX_CAP_PBA_OFFSET = 29'h0;
  localparam integer MSIX_CAP_TABLE_BIR = 0;
  localparam [28:0] MSIX_CAP_TABLE_OFFSET = 29'h0;
  localparam [10:0] MSIX_CAP_TABLE_SIZE = 11'h000;
  localparam [7:0] MSI_BASE_PTR = 8'h48;
  localparam MSI_CAP_64_BIT_ADDR_CAPABLE = "TRUE";
  localparam [7:0] MSI_CAP_ID = 8'h05;
  localparam integer MSI_CAP_MULTIMSGCAP = 0;
  localparam integer MSI_CAP_MULTIMSG_EXTENSION = 0;
  localparam [7:0] MSI_CAP_NEXTPTR = 8'h60;
  localparam MSI_CAP_ON = "TRUE";
  localparam MSI_CAP_PER_VECTOR_MASKING_CAPABLE = "FALSE";
  localparam integer N_FTS_COMCLK_GEN1 = 255;
  localparam integer N_FTS_COMCLK_GEN2 = 255;
  localparam integer N_FTS_GEN1 = 255;
  localparam integer N_FTS_GEN2 = 255;
  localparam [7:0] PCIE_BASE_PTR = 8'h60;
  localparam [7:0] PCIE_CAP_CAPABILITY_ID = 8'h10;
  localparam [3:0] PCIE_CAP_CAPABILITY_VERSION = 4'h2;
  localparam [3:0] PCIE_CAP_DEVICE_PORT_TYPE = 4'h4;
  localparam [7:0] PCIE_CAP_NEXTPTR = 8'h00;
  localparam PCIE_CAP_ON = "TRUE";
  localparam integer PCIE_CAP_RSVD_15_14 = 0;
  localparam PCIE_CAP_SLOT_IMPLEMENTED = "FALSE";
  localparam integer PCIE_REVISION = 2;
  localparam integer PL_AUTO_CONFIG = 0;
  // PL_FAST_TRAIN shortens the LTSSM's training timers. It is a simulation-only
  // feature of the hard macro -- AMD's own example designs turn it on for
  // simulation and off for the bitstream, because with the real 12/24 ms timers
  // link training takes longer than any practical simulation run. The
  // co-simulation file list defines SIM_FAST_TRAIN; the synthesis flows never
  // do, so the bitstream is unaffected.
`ifdef SIM_FAST_TRAIN
  localparam PL_FAST_TRAIN = "TRUE";
`else
  localparam PL_FAST_TRAIN = "FALSE";
`endif
  localparam [14:0] PM_ASPML0S_TIMEOUT = 15'h0000;
  localparam PM_ASPML0S_TIMEOUT_EN = "FALSE";
  localparam integer PM_ASPML0S_TIMEOUT_FUNC = 0;
  localparam PM_ASPM_FASTEXIT = "FALSE";
  localparam [7:0] PM_BASE_PTR = 8'h40;
  localparam integer PM_CAP_AUXCURRENT = 0;
  localparam PM_CAP_D1SUPPORT = "FALSE";
  localparam PM_CAP_D2SUPPORT = "FALSE";
  localparam PM_CAP_DSI = "FALSE";
  localparam [7:0] PM_CAP_ID = 8'h01;
  localparam [7:0] PM_CAP_NEXTPTR = 8'h48;
  localparam PM_CAP_ON = "TRUE";
  localparam [4:0] PM_CAP_PMESUPPORT = 5'h0F;
  localparam PM_CAP_PME_CLOCK = "FALSE";
  localparam integer PM_CAP_RSVD_04 = 0;
  localparam integer PM_CAP_VERSION = 3;
  localparam PM_CSR_B2B3 = "FALSE";
  localparam PM_CSR_BPCCEN = "FALSE";
  localparam PM_CSR_NOSOFTRST = "TRUE";
  localparam [7:0] PM_DATA0 = 8'h00;
  localparam [7:0] PM_DATA1 = 8'h00;
  localparam [7:0] PM_DATA2 = 8'h00;
  localparam [7:0] PM_DATA3 = 8'h00;
  localparam [7:0] PM_DATA4 = 8'h00;
  localparam [7:0] PM_DATA5 = 8'h00;
  localparam [7:0] PM_DATA6 = 8'h00;
  localparam [7:0] PM_DATA7 = 8'h00;
  localparam [1:0] PM_DATA_SCALE0 = 2'h0;
  localparam [1:0] PM_DATA_SCALE1 = 2'h0;
  localparam [1:0] PM_DATA_SCALE2 = 2'h0;
  localparam [1:0] PM_DATA_SCALE3 = 2'h0;
  localparam [1:0] PM_DATA_SCALE4 = 2'h0;
  localparam [1:0] PM_DATA_SCALE5 = 2'h0;
  localparam [1:0] PM_DATA_SCALE6 = 2'h0;
  localparam [1:0] PM_DATA_SCALE7 = 2'h0;
  localparam PM_MF = "FALSE";
  localparam [11:0] RBAR_BASE_PTR = 12'h000;
  localparam [4:0] RBAR_CAP_CONTROL_ENCODEDBAR0 = 5'h00;
  localparam [4:0] RBAR_CAP_CONTROL_ENCODEDBAR1 = 5'h00;
  localparam [4:0] RBAR_CAP_CONTROL_ENCODEDBAR2 = 5'h00;
  localparam [4:0] RBAR_CAP_CONTROL_ENCODEDBAR3 = 5'h00;
  localparam [4:0] RBAR_CAP_CONTROL_ENCODEDBAR4 = 5'h00;
  localparam [4:0] RBAR_CAP_CONTROL_ENCODEDBAR5 = 5'h00;
  localparam [15:0] RBAR_CAP_ID = 16'h0015;
  localparam [2:0] RBAR_CAP_INDEX0 = 3'h0;
  localparam [2:0] RBAR_CAP_INDEX1 = 3'h0;
  localparam [2:0] RBAR_CAP_INDEX2 = 3'h0;
  localparam [2:0] RBAR_CAP_INDEX3 = 3'h0;
  localparam [2:0] RBAR_CAP_INDEX4 = 3'h0;
  localparam [2:0] RBAR_CAP_INDEX5 = 3'h0;
  localparam [11:0] RBAR_CAP_NEXTPTR = 12'h000;
  localparam RBAR_CAP_ON = "FALSE";
  localparam [31:0] RBAR_CAP_SUP0 = 32'h00001;
  localparam [31:0] RBAR_CAP_SUP1 = 32'h00001;
  localparam [31:0] RBAR_CAP_SUP2 = 32'h00001;
  localparam [31:0] RBAR_CAP_SUP3 = 32'h00001;
  localparam [31:0] RBAR_CAP_SUP4 = 32'h00001;
  localparam [31:0] RBAR_CAP_SUP5 = 32'h00001;
  localparam [3:0] RBAR_CAP_VERSION = 4'h1;
  localparam [2:0] RBAR_NUM = 3'h0;
  localparam integer RECRC_CHK = 0;
  localparam RECRC_CHK_TRIM = "FALSE";
  localparam ROOT_CAP_CRS_SW_VISIBILITY = "FALSE";
  localparam [1:0] RP_AUTO_SPD = 2'h1;
  localparam [4:0] RP_AUTO_SPD_LOOPCNT = 5'h1f;
  localparam SELECT_DLL_IF = "FALSE";
  localparam SLOT_CAP_ATT_BUTTON_PRESENT = "FALSE";
  localparam SLOT_CAP_ATT_INDICATOR_PRESENT = "FALSE";
  localparam SLOT_CAP_ELEC_INTERLOCK_PRESENT = "FALSE";
  localparam SLOT_CAP_HOTPLUG_CAPABLE = "FALSE";
  localparam SLOT_CAP_HOTPLUG_SURPRISE = "FALSE";
  localparam SLOT_CAP_MRL_SENSOR_PRESENT = "FALSE";
  localparam SLOT_CAP_NO_CMD_COMPLETED_SUPPORT = "FALSE";
  localparam [12:0] SLOT_CAP_PHYSICAL_SLOT_NUM = 13'h0000;
  localparam SLOT_CAP_POWER_CONTROLLER_PRESENT = "FALSE";
  localparam SLOT_CAP_POWER_INDICATOR_PRESENT = "FALSE";
  localparam integer SLOT_CAP_SLOT_POWER_LIMIT_SCALE = 0;
  localparam [7:0] SLOT_CAP_SLOT_POWER_LIMIT_VALUE = 8'h00;
  localparam integer SPARE_BIT0 = 0;
  localparam integer SPARE_BIT1 = 0;
  localparam integer SPARE_BIT2 = 0;
  localparam integer SPARE_BIT3 = 0;
  localparam integer SPARE_BIT4 = 0;
  localparam integer SPARE_BIT5 = 0;
  localparam integer SPARE_BIT6 = 0;
  localparam integer SPARE_BIT7 = 0;
  localparam integer SPARE_BIT8 = 0;
  localparam [7:0] SPARE_BYTE0 = 8'h00;
  localparam [7:0] SPARE_BYTE1 = 8'h00;
  localparam [7:0] SPARE_BYTE2 = 8'h00;
  localparam [7:0] SPARE_BYTE3 = 8'h00;
  localparam [31:0] SPARE_WORD0 = 32'h00000000;
  localparam [31:0] SPARE_WORD1 = 32'h00000000;
  localparam [31:0] SPARE_WORD2 = 32'h00000000;
  localparam [31:0] SPARE_WORD3 = 32'h00000000;
  localparam SSL_MESSAGE_AUTO = "FALSE";
  localparam TECRC_EP_INV = "FALSE";
  localparam TL_RBYPASS = "FALSE";
  localparam integer TL_RX_RAM_RADDR_LATENCY = 0;
  localparam integer TL_RX_RAM_RDATA_LATENCY = 2;
  localparam integer TL_RX_RAM_WRITE_LATENCY = 0;
  localparam TL_TFC_DISABLE = "FALSE";
  localparam TL_TX_CHECKS_DISABLE = "FALSE";
  localparam integer TL_TX_RAM_RADDR_LATENCY = 0;
  localparam integer TL_TX_RAM_RDATA_LATENCY = 2;
  localparam integer TL_TX_RAM_WRITE_LATENCY = 0;
  localparam TRN_DW = "FALSE";
  localparam TRN_NP_FC = "TRUE";
  localparam UPCONFIG_CAPABLE = "TRUE";
  localparam UPSTREAM_FACING = "FALSE";
  localparam UR_ATOMIC = "FALSE";
  localparam UR_CFG1 = "TRUE";
  localparam UR_INV_REQ = "TRUE";
  localparam UR_PRS_RESPONSE = "TRUE";
  localparam USER_CLK2_DIV2 = "FALSE";
  localparam integer USER_CLK_FREQ = 1;
  localparam USE_RID_PINS = "FALSE";
  localparam VC0_CPL_INFINITE = "TRUE";
  localparam [12:0] VC0_RX_RAM_LIMIT = 13'h7FF;
  localparam integer VC0_TOTAL_CREDITS_CD = 461;
  localparam integer VC0_TOTAL_CREDITS_CH = 36;
  localparam integer VC0_TOTAL_CREDITS_NPD = 24;
  localparam integer VC0_TOTAL_CREDITS_NPH = 12;
  localparam integer VC0_TOTAL_CREDITS_PD = 437;
  localparam integer VC0_TOTAL_CREDITS_PH = 32;
  localparam integer VC0_TX_LASTPACKET = 29;
  localparam [11:0] VC_BASE_PTR = 12'h000;
  localparam [15:0] VC_CAP_ID = 16'h0002;
  localparam [11:0] VC_CAP_NEXTPTR = 12'h000;
  localparam VC_CAP_ON = "FALSE";
  localparam VC_CAP_REJECT_SNOOP_TRANSACTIONS = "FALSE";
  localparam [3:0] VC_CAP_VERSION = 4'h1;
  localparam [11:0] VSEC_BASE_PTR = 12'h000;
  localparam [15:0] VSEC_CAP_HDR_ID = 16'h1234;
  localparam [3:0] VSEC_CAP_HDR_REVISION = 4'h1;
  localparam [15:0] VSEC_CAP_ID = 16'h000B;
  localparam VSEC_CAP_IS_LINK_VISIBLE = "TRUE";
  localparam [11:0] VSEC_CAP_NEXTPTR = 12'h000;
  localparam VSEC_CAP_ON = "FALSE";
  localparam [3:0] VSEC_CAP_VERSION = 4'h1;

  wire [3:0]        trn_tdst_rdy_bus;

  assign            trn.tdst_rdy = trn_tdst_rdy_bus[0];

  mim_if #(.DATA_W(69)) mim_tx ();
  mim_if #(.DATA_W(68)) mim_rx ();

localparam BRT_TLM_TX_OVERHEAD = 24;
  localparam BRT_MPS_BYTES = (DEV_CAP_MAX_PAYLOAD_SUPPORTED == 0) ? 128 :
                             (DEV_CAP_MAX_PAYLOAD_SUPPORTED == 1) ? 256 :
                             (DEV_CAP_MAX_PAYLOAD_SUPPORTED == 2) ? 512 : 1024;
  localparam BRT_BYTES_TX  = (VC0_TX_LASTPACKET + 1) * (BRT_MPS_BYTES + BRT_TLM_TX_OVERHEAD);
  localparam BRT_COLS_TX   = (BRT_BYTES_TX <= 4096)  ? 1 :
                             (BRT_BYTES_TX <= 8192)  ? 2 :
                             (BRT_BYTES_TX <= 16384) ? 4 :
                             (BRT_BYTES_TX <= 32768) ? 8 : 18;
  localparam BRT_COLS_RX   = (VC0_RX_RAM_LIMIT < 'h0200) ? 1 :
                             (VC0_RX_RAM_LIMIT < 'h0400) ? 2 :
                             (VC0_RX_RAM_LIMIT < 'h0800) ? 4 :
                             (VC0_RX_RAM_LIMIT < 'h1000) ? 8 : 18;

  buffer_bank #(
    .NUM_BRAMS         (BRT_COLS_TX),
    .RAM_RDATA_LATENCY (TL_TX_RAM_RDATA_LATENCY)
  ) tx_buf_bank (
    .user_clk_i (user_clk),
    .mim        (mim_tx)
  );

  buffer_bank #(
    .NUM_BRAMS         (BRT_COLS_RX),
    .RAM_RDATA_LATENCY (TL_RX_RAM_RDATA_LATENCY)
  ) rx_buf_bank (
    .user_clk_i (user_clk),
    .mim        (mim_rx)
  );

  PCIE_2_1 #(
    .AER_BASE_PTR                             ( AER_BASE_PTR ),
    .AER_CAP_ECRC_CHECK_CAPABLE               ( AER_CAP_ECRC_CHECK_CAPABLE ),
    .AER_CAP_ECRC_GEN_CAPABLE                 ( AER_CAP_ECRC_GEN_CAPABLE ),
    .AER_CAP_ID                               ( AER_CAP_ID ),
    .AER_CAP_MULTIHEADER                      ( AER_CAP_MULTIHEADER ),
    .AER_CAP_NEXTPTR                          ( AER_CAP_NEXTPTR ),
    .AER_CAP_ON                               ( AER_CAP_ON ),
    .AER_CAP_OPTIONAL_ERR_SUPPORT             ( AER_CAP_OPTIONAL_ERR_SUPPORT ),
    .AER_CAP_PERMIT_ROOTERR_UPDATE            ( AER_CAP_PERMIT_ROOTERR_UPDATE ),
    .AER_CAP_VERSION                          ( AER_CAP_VERSION ),
    .ALLOW_X8_GEN2                            ( ALLOW_X8_GEN2 ),
    .BAR0                                     ( BAR0 ),
    .BAR1                                     ( BAR1 ),
    .BAR2                                     ( BAR2 ),
    .BAR3                                     ( BAR3 ),
    .BAR4                                     ( BAR4 ),
    .BAR5                                     ( BAR5 ),
    .CAPABILITIES_PTR                         ( CAPABILITIES_PTR ),
    .CARDBUS_CIS_POINTER                      ( CARDBUS_CIS_POINTER ),
    .CFG_ECRC_ERR_CPLSTAT                     ( CFG_ECRC_ERR_CPLSTAT ),
    .CLASS_CODE                               ( CLASS_CODE ),
    .CMD_INTX_IMPLEMENTED                     ( CMD_INTX_IMPLEMENTED ),
    .CPL_TIMEOUT_DISABLE_SUPPORTED            ( CPL_TIMEOUT_DISABLE_SUPPORTED ),
    .CPL_TIMEOUT_RANGES_SUPPORTED             ( CPL_TIMEOUT_RANGES_SUPPORTED ),
    .CRM_MODULE_RSTS                          ( CRM_MODULE_RSTS ),
    .DEV_CAP_ENABLE_SLOT_PWR_LIMIT_SCALE      ( DEV_CAP_ENABLE_SLOT_PWR_LIMIT_SCALE ),
    .DEV_CAP_ENABLE_SLOT_PWR_LIMIT_VALUE      ( DEV_CAP_ENABLE_SLOT_PWR_LIMIT_VALUE ),
    .DEV_CAP_ENDPOINT_L0S_LATENCY             ( DEV_CAP_ENDPOINT_L0S_LATENCY ),
    .DEV_CAP_ENDPOINT_L1_LATENCY              ( DEV_CAP_ENDPOINT_L1_LATENCY ),
    .DEV_CAP_EXT_TAG_SUPPORTED                ( DEV_CAP_EXT_TAG_SUPPORTED ),
    .DEV_CAP_FUNCTION_LEVEL_RESET_CAPABLE     ( DEV_CAP_FUNCTION_LEVEL_RESET_CAPABLE ),
    .DEV_CAP_MAX_PAYLOAD_SUPPORTED            ( DEV_CAP_MAX_PAYLOAD_SUPPORTED ),
    .DEV_CAP_PHANTOM_FUNCTIONS_SUPPORT        ( DEV_CAP_PHANTOM_FUNCTIONS_SUPPORT ),
    .DEV_CAP_ROLE_BASED_ERROR                 ( DEV_CAP_ROLE_BASED_ERROR ),
    .DEV_CAP_RSVD_14_12                       ( DEV_CAP_RSVD_14_12 ),
    .DEV_CAP_RSVD_17_16                       ( DEV_CAP_RSVD_17_16 ),
    .DEV_CAP_RSVD_31_29                       ( DEV_CAP_RSVD_31_29 ),
    .DEV_CAP2_ARI_FORWARDING_SUPPORTED        ( DEV_CAP2_ARI_FORWARDING_SUPPORTED ),
    .DEV_CAP2_ATOMICOP_ROUTING_SUPPORTED      ( DEV_CAP2_ATOMICOP_ROUTING_SUPPORTED ),
    .DEV_CAP2_ATOMICOP32_COMPLETER_SUPPORTED  ( DEV_CAP2_ATOMICOP32_COMPLETER_SUPPORTED ),
    .DEV_CAP2_ATOMICOP64_COMPLETER_SUPPORTED  ( DEV_CAP2_ATOMICOP64_COMPLETER_SUPPORTED ),
    .DEV_CAP2_CAS128_COMPLETER_SUPPORTED      ( DEV_CAP2_CAS128_COMPLETER_SUPPORTED ),
    .DEV_CAP2_ENDEND_TLP_PREFIX_SUPPORTED     ( DEV_CAP2_ENDEND_TLP_PREFIX_SUPPORTED ),
    .DEV_CAP2_EXTENDED_FMT_FIELD_SUPPORTED    ( DEV_CAP2_EXTENDED_FMT_FIELD_SUPPORTED ),
    .DEV_CAP2_LTR_MECHANISM_SUPPORTED         ( DEV_CAP2_LTR_MECHANISM_SUPPORTED ),
    .DEV_CAP2_MAX_ENDEND_TLP_PREFIXES         ( DEV_CAP2_MAX_ENDEND_TLP_PREFIXES ),
    .DEV_CAP2_NO_RO_ENABLED_PRPR_PASSING      ( DEV_CAP2_NO_RO_ENABLED_PRPR_PASSING ),
    .DEV_CAP2_TPH_COMPLETER_SUPPORTED         ( DEV_CAP2_TPH_COMPLETER_SUPPORTED ),
    .DEV_CONTROL_AUX_POWER_SUPPORTED          ( DEV_CONTROL_AUX_POWER_SUPPORTED ),
    .DEV_CONTROL_EXT_TAG_DEFAULT              ( DEV_CONTROL_EXT_TAG_DEFAULT ),
    .DISABLE_ASPM_L1_TIMER                    ( DISABLE_ASPM_L1_TIMER ),
    .DISABLE_BAR_FILTERING                    ( DISABLE_BAR_FILTERING ),
    .DISABLE_ERR_MSG                          ( DISABLE_ERR_MSG ),
    .DISABLE_ID_CHECK                         ( DISABLE_ID_CHECK ),
    .DISABLE_LANE_REVERSAL                    ( DISABLE_LANE_REVERSAL ),
    .DISABLE_LOCKED_FILTER                    ( DISABLE_LOCKED_FILTER ),
    .DISABLE_PPM_FILTER                       ( DISABLE_PPM_FILTER ),
    .DISABLE_RX_POISONED_RESP                 ( DISABLE_RX_POISONED_RESP ),
    .DISABLE_RX_TC_FILTER                     ( DISABLE_RX_TC_FILTER ),
    .DISABLE_SCRAMBLING                       ( DISABLE_SCRAMBLING ),
    .DNSTREAM_LINK_NUM                        ( DNSTREAM_LINK_NUM ),
    .DSN_BASE_PTR                             ( DSN_BASE_PTR ),
    .DSN_CAP_ID                               ( DSN_CAP_ID ),
    .DSN_CAP_NEXTPTR                          ( DSN_CAP_NEXTPTR ),
    .DSN_CAP_ON                               ( DSN_CAP_ON ),
    .DSN_CAP_VERSION                          ( DSN_CAP_VERSION ),
    .ENABLE_MSG_ROUTE                         ( ENABLE_MSG_ROUTE ),
    .ENABLE_RX_TD_ECRC_TRIM                   ( ENABLE_RX_TD_ECRC_TRIM ),
    .ENDEND_TLP_PREFIX_FORWARDING_SUPPORTED   ( ENDEND_TLP_PREFIX_FORWARDING_SUPPORTED ),
    .ENTER_RVRY_EI_L0                         ( ENTER_RVRY_EI_L0 ),
    .EXIT_LOOPBACK_ON_EI                      ( EXIT_LOOPBACK_ON_EI ),
    .EXPANSION_ROM                            ( EXPANSION_ROM ),
    .EXT_CFG_CAP_PTR                          ( EXT_CFG_CAP_PTR ),
    .EXT_CFG_XP_CAP_PTR                       ( EXT_CFG_XP_CAP_PTR ),
    .HEADER_TYPE                              ( HEADER_TYPE ),
    .INFER_EI                                 ( INFER_EI ),
    .INTERRUPT_PIN                            ( INTERRUPT_PIN ),
    .INTERRUPT_STAT_AUTO                      ( INTERRUPT_STAT_AUTO ),
    .IS_SWITCH                                ( IS_SWITCH ),
    .LAST_CONFIG_DWORD                        ( LAST_CONFIG_DWORD ),
    .LINK_CAP_ASPM_OPTIONALITY                ( LINK_CAP_ASPM_OPTIONALITY ),
    .LINK_CAP_ASPM_SUPPORT                    ( LINK_CAP_ASPM_SUPPORT ),
    .LINK_CAP_CLOCK_POWER_MANAGEMENT          ( LINK_CAP_CLOCK_POWER_MANAGEMENT ),
    .LINK_CAP_DLL_LINK_ACTIVE_REPORTING_CAP   ( LINK_CAP_DLL_LINK_ACTIVE_REPORTING_CAP ),
    .LINK_CAP_LINK_BANDWIDTH_NOTIFICATION_CAP ( LINK_CAP_LINK_BANDWIDTH_NOTIFICATION_CAP ),
    .LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN1    ( LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN1 ),
    .LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN2    ( LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN2 ),
    .LINK_CAP_L0S_EXIT_LATENCY_GEN1           ( LINK_CAP_L0S_EXIT_LATENCY_GEN1 ),
    .LINK_CAP_L0S_EXIT_LATENCY_GEN2           ( LINK_CAP_L0S_EXIT_LATENCY_GEN2 ),
    .LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN1     ( LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN1 ),
    .LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN2     ( LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN2 ),
    .LINK_CAP_L1_EXIT_LATENCY_GEN1            ( LINK_CAP_L1_EXIT_LATENCY_GEN1 ),
    .LINK_CAP_L1_EXIT_LATENCY_GEN2            ( LINK_CAP_L1_EXIT_LATENCY_GEN2 ),
    .LINK_CAP_MAX_LINK_SPEED                  ( LINK_CAP_MAX_LINK_SPEED ),
    .LINK_CAP_MAX_LINK_WIDTH                  ( LINK_CAP_MAX_LINK_WIDTH ),
    .LINK_CAP_RSVD_23                         ( LINK_CAP_RSVD_23 ),
    .LINK_CAP_SURPRISE_DOWN_ERROR_CAPABLE     ( LINK_CAP_SURPRISE_DOWN_ERROR_CAPABLE ),
    .LINK_CONTROL_RCB                         ( LINK_CONTROL_RCB ),
    .LINK_CTRL2_DEEMPHASIS                    ( LINK_CTRL2_DEEMPHASIS ),
    .LINK_CTRL2_HW_AUTONOMOUS_SPEED_DISABLE   ( LINK_CTRL2_HW_AUTONOMOUS_SPEED_DISABLE ),
    .LINK_CTRL2_TARGET_LINK_SPEED             ( LINK_CTRL2_TARGET_LINK_SPEED ),
    .LINK_STATUS_SLOT_CLOCK_CONFIG            ( LINK_STATUS_SLOT_CLOCK_CONFIG ),
    .LL_ACK_TIMEOUT                           ( LL_ACK_TIMEOUT ),
    .LL_ACK_TIMEOUT_EN                        ( LL_ACK_TIMEOUT_EN ),
    .LL_ACK_TIMEOUT_FUNC                      ( LL_ACK_TIMEOUT_FUNC ),
    .LL_REPLAY_TIMEOUT                        ( LL_REPLAY_TIMEOUT ),
    .LL_REPLAY_TIMEOUT_EN                     ( LL_REPLAY_TIMEOUT_EN ),
    .LL_REPLAY_TIMEOUT_FUNC                   ( LL_REPLAY_TIMEOUT_FUNC ),
    .LTSSM_MAX_LINK_WIDTH                     ( LTSSM_MAX_LINK_WIDTH ),
    .MPS_FORCE                                ( MPS_FORCE ),
    .MSI_BASE_PTR                             ( MSI_BASE_PTR ),
    .MSI_CAP_ID                               ( MSI_CAP_ID ),
    .MSI_CAP_MULTIMSG_EXTENSION               ( MSI_CAP_MULTIMSG_EXTENSION ),
    .MSI_CAP_MULTIMSGCAP                      ( MSI_CAP_MULTIMSGCAP ),
    .MSI_CAP_NEXTPTR                          ( MSI_CAP_NEXTPTR ),
    .MSI_CAP_ON                               ( MSI_CAP_ON ),
    .MSI_CAP_PER_VECTOR_MASKING_CAPABLE       ( MSI_CAP_PER_VECTOR_MASKING_CAPABLE ),
    .MSI_CAP_64_BIT_ADDR_CAPABLE              ( MSI_CAP_64_BIT_ADDR_CAPABLE ),
    .MSIX_BASE_PTR                            ( MSIX_BASE_PTR ),
    .MSIX_CAP_ID                              ( MSIX_CAP_ID ),
    .MSIX_CAP_NEXTPTR                         ( MSIX_CAP_NEXTPTR ),
    .MSIX_CAP_ON                              ( MSIX_CAP_ON ),
    .MSIX_CAP_PBA_BIR                         ( MSIX_CAP_PBA_BIR ),
    .MSIX_CAP_PBA_OFFSET                      ( MSIX_CAP_PBA_OFFSET ),
    .MSIX_CAP_TABLE_BIR                       ( MSIX_CAP_TABLE_BIR ),
    .MSIX_CAP_TABLE_OFFSET                    ( MSIX_CAP_TABLE_OFFSET ),
    .MSIX_CAP_TABLE_SIZE                      ( MSIX_CAP_TABLE_SIZE ),
    .N_FTS_COMCLK_GEN1                        ( N_FTS_COMCLK_GEN1 ),
    .N_FTS_COMCLK_GEN2                        ( N_FTS_COMCLK_GEN2 ),
    .N_FTS_GEN1                               ( N_FTS_GEN1 ),
    .N_FTS_GEN2                               ( N_FTS_GEN2 ),
    .PCIE_BASE_PTR                            ( PCIE_BASE_PTR ),
    .PCIE_CAP_CAPABILITY_ID                   ( PCIE_CAP_CAPABILITY_ID ),
    .PCIE_CAP_CAPABILITY_VERSION              ( PCIE_CAP_CAPABILITY_VERSION ),
    .PCIE_CAP_DEVICE_PORT_TYPE                ( PCIE_CAP_DEVICE_PORT_TYPE ),
    .PCIE_CAP_NEXTPTR                         ( PCIE_CAP_NEXTPTR ),
    .PCIE_CAP_ON                              ( PCIE_CAP_ON ),
    .PCIE_CAP_RSVD_15_14                      ( PCIE_CAP_RSVD_15_14 ),
    .PCIE_CAP_SLOT_IMPLEMENTED                ( PCIE_CAP_SLOT_IMPLEMENTED ),
    .PCIE_REVISION                            ( PCIE_REVISION ),
    .PL_AUTO_CONFIG                           ( PL_AUTO_CONFIG ),
    .PL_FAST_TRAIN                            ( PL_FAST_TRAIN ),
    .PM_ASPML0S_TIMEOUT                       ( PM_ASPML0S_TIMEOUT ),
    .PM_ASPML0S_TIMEOUT_EN                    ( PM_ASPML0S_TIMEOUT_EN ),
    .PM_ASPML0S_TIMEOUT_FUNC                  ( PM_ASPML0S_TIMEOUT_FUNC ),
    .PM_ASPM_FASTEXIT                         ( PM_ASPM_FASTEXIT ),
    .PM_BASE_PTR                              ( PM_BASE_PTR ),
    .PM_CAP_AUXCURRENT                        ( PM_CAP_AUXCURRENT ),
    .PM_CAP_DSI                               ( PM_CAP_DSI ),
    .PM_CAP_D1SUPPORT                         ( PM_CAP_D1SUPPORT ),
    .PM_CAP_D2SUPPORT                         ( PM_CAP_D2SUPPORT ),
    .PM_CAP_ID                                ( PM_CAP_ID ),
    .PM_CAP_NEXTPTR                           ( PM_CAP_NEXTPTR ),
    .PM_CAP_ON                                ( PM_CAP_ON ),
    .PM_CAP_PME_CLOCK                         ( PM_CAP_PME_CLOCK ),
    .PM_CAP_PMESUPPORT                        ( PM_CAP_PMESUPPORT ),
    .PM_CAP_RSVD_04                           ( PM_CAP_RSVD_04 ),
    .PM_CAP_VERSION                           ( PM_CAP_VERSION ),
    .PM_CSR_BPCCEN                            ( PM_CSR_BPCCEN ),
    .PM_CSR_B2B3                              ( PM_CSR_B2B3 ),
    .PM_CSR_NOSOFTRST                         ( PM_CSR_NOSOFTRST ),
    .PM_DATA_SCALE0                           ( PM_DATA_SCALE0 ),
    .PM_DATA_SCALE1                           ( PM_DATA_SCALE1 ),
    .PM_DATA_SCALE2                           ( PM_DATA_SCALE2 ),
    .PM_DATA_SCALE3                           ( PM_DATA_SCALE3 ),
    .PM_DATA_SCALE4                           ( PM_DATA_SCALE4 ),
    .PM_DATA_SCALE5                           ( PM_DATA_SCALE5 ),
    .PM_DATA_SCALE6                           ( PM_DATA_SCALE6 ),
    .PM_DATA_SCALE7                           ( PM_DATA_SCALE7 ),
    .PM_DATA0                                 ( PM_DATA0 ),
    .PM_DATA1                                 ( PM_DATA1 ),
    .PM_DATA2                                 ( PM_DATA2 ),
    .PM_DATA3                                 ( PM_DATA3 ),
    .PM_DATA4                                 ( PM_DATA4 ),
    .PM_DATA5                                 ( PM_DATA5 ),
    .PM_DATA6                                 ( PM_DATA6 ),
    .PM_DATA7                                 ( PM_DATA7 ),
    .PM_MF                                    ( PM_MF ),
    .RBAR_BASE_PTR                            ( RBAR_BASE_PTR ),
    .RBAR_CAP_CONTROL_ENCODEDBAR0             ( RBAR_CAP_CONTROL_ENCODEDBAR0 ),
    .RBAR_CAP_CONTROL_ENCODEDBAR1             ( RBAR_CAP_CONTROL_ENCODEDBAR1 ),
    .RBAR_CAP_CONTROL_ENCODEDBAR2             ( RBAR_CAP_CONTROL_ENCODEDBAR2 ),
    .RBAR_CAP_CONTROL_ENCODEDBAR3             ( RBAR_CAP_CONTROL_ENCODEDBAR3 ),
    .RBAR_CAP_CONTROL_ENCODEDBAR4             ( RBAR_CAP_CONTROL_ENCODEDBAR4 ),
    .RBAR_CAP_CONTROL_ENCODEDBAR5             ( RBAR_CAP_CONTROL_ENCODEDBAR5 ),
    .RBAR_CAP_ID                              ( RBAR_CAP_ID ),
    .RBAR_CAP_INDEX0                          ( RBAR_CAP_INDEX0 ),
    .RBAR_CAP_INDEX1                          ( RBAR_CAP_INDEX1 ),
    .RBAR_CAP_INDEX2                          ( RBAR_CAP_INDEX2 ),
    .RBAR_CAP_INDEX3                          ( RBAR_CAP_INDEX3 ),
    .RBAR_CAP_INDEX4                          ( RBAR_CAP_INDEX4 ),
    .RBAR_CAP_INDEX5                          ( RBAR_CAP_INDEX5 ),
    .RBAR_CAP_NEXTPTR                         ( RBAR_CAP_NEXTPTR ),
    .RBAR_CAP_ON                              ( RBAR_CAP_ON ),
    .RBAR_CAP_SUP0                            ( RBAR_CAP_SUP0 ),
    .RBAR_CAP_SUP1                            ( RBAR_CAP_SUP1 ),
    .RBAR_CAP_SUP2                            ( RBAR_CAP_SUP2 ),
    .RBAR_CAP_SUP3                            ( RBAR_CAP_SUP3 ),
    .RBAR_CAP_SUP4                            ( RBAR_CAP_SUP4 ),
    .RBAR_CAP_SUP5                            ( RBAR_CAP_SUP5 ),
    .RBAR_CAP_VERSION                         ( RBAR_CAP_VERSION ),
    .RBAR_NUM                                 ( RBAR_NUM ),
    .RECRC_CHK                                ( RECRC_CHK ),
    .RECRC_CHK_TRIM                           ( RECRC_CHK_TRIM ),
    .ROOT_CAP_CRS_SW_VISIBILITY               ( ROOT_CAP_CRS_SW_VISIBILITY ),
    .RP_AUTO_SPD                              ( RP_AUTO_SPD ),
    .RP_AUTO_SPD_LOOPCNT                      ( RP_AUTO_SPD_LOOPCNT ),
    .SELECT_DLL_IF                            ( SELECT_DLL_IF ),
    .SLOT_CAP_ATT_BUTTON_PRESENT              ( SLOT_CAP_ATT_BUTTON_PRESENT ),
    .SLOT_CAP_ATT_INDICATOR_PRESENT           ( SLOT_CAP_ATT_INDICATOR_PRESENT ),
    .SLOT_CAP_ELEC_INTERLOCK_PRESENT          ( SLOT_CAP_ELEC_INTERLOCK_PRESENT ),
    .SLOT_CAP_HOTPLUG_CAPABLE                 ( SLOT_CAP_HOTPLUG_CAPABLE ),
    .SLOT_CAP_HOTPLUG_SURPRISE                ( SLOT_CAP_HOTPLUG_SURPRISE ),
    .SLOT_CAP_MRL_SENSOR_PRESENT              ( SLOT_CAP_MRL_SENSOR_PRESENT ),
    .SLOT_CAP_NO_CMD_COMPLETED_SUPPORT        ( SLOT_CAP_NO_CMD_COMPLETED_SUPPORT ),
    .SLOT_CAP_PHYSICAL_SLOT_NUM               ( SLOT_CAP_PHYSICAL_SLOT_NUM ),
    .SLOT_CAP_POWER_CONTROLLER_PRESENT        ( SLOT_CAP_POWER_CONTROLLER_PRESENT ),
    .SLOT_CAP_POWER_INDICATOR_PRESENT         ( SLOT_CAP_POWER_INDICATOR_PRESENT ),
    .SLOT_CAP_SLOT_POWER_LIMIT_SCALE          ( SLOT_CAP_SLOT_POWER_LIMIT_SCALE ),
    .SLOT_CAP_SLOT_POWER_LIMIT_VALUE          ( SLOT_CAP_SLOT_POWER_LIMIT_VALUE ),
    .SPARE_BIT0                               ( SPARE_BIT0 ),
    .SPARE_BIT1                               ( SPARE_BIT1 ),
    .SPARE_BIT2                               ( SPARE_BIT2 ),
    .SPARE_BIT3                               ( SPARE_BIT3 ),
    .SPARE_BIT4                               ( SPARE_BIT4 ),
    .SPARE_BIT5                               ( SPARE_BIT5 ),
    .SPARE_BIT6                               ( SPARE_BIT6 ),
    .SPARE_BIT7                               ( SPARE_BIT7 ),
    .SPARE_BIT8                               ( SPARE_BIT8 ),
    .SPARE_BYTE0                              ( SPARE_BYTE0 ),
    .SPARE_BYTE1                              ( SPARE_BYTE1 ),
    .SPARE_BYTE2                              ( SPARE_BYTE2 ),
    .SPARE_BYTE3                              ( SPARE_BYTE3 ),
    .SPARE_WORD0                              ( SPARE_WORD0 ),
    .SPARE_WORD1                              ( SPARE_WORD1 ),
    .SPARE_WORD2                              ( SPARE_WORD2 ),
    .SPARE_WORD3                              ( SPARE_WORD3 ),
    .SSL_MESSAGE_AUTO                         ( SSL_MESSAGE_AUTO ),
    .TECRC_EP_INV                             ( TECRC_EP_INV ),
    .TL_RBYPASS                               ( TL_RBYPASS ),
    .TL_RX_RAM_RADDR_LATENCY                  ( TL_RX_RAM_RADDR_LATENCY ),
    .TL_RX_RAM_RDATA_LATENCY                  ( TL_RX_RAM_RDATA_LATENCY ),
    .TL_RX_RAM_WRITE_LATENCY                  ( TL_RX_RAM_WRITE_LATENCY ),
    .TL_TFC_DISABLE                           ( TL_TFC_DISABLE ),
    .TL_TX_CHECKS_DISABLE                     ( TL_TX_CHECKS_DISABLE ),
    .TL_TX_RAM_RADDR_LATENCY                  ( TL_TX_RAM_RADDR_LATENCY ),
    .TL_TX_RAM_RDATA_LATENCY                  ( TL_TX_RAM_RDATA_LATENCY ),
    .TL_TX_RAM_WRITE_LATENCY                  ( TL_TX_RAM_WRITE_LATENCY ),
    .TRN_DW                                   ( TRN_DW ),
    .TRN_NP_FC                                ( TRN_NP_FC ),
    .UPCONFIG_CAPABLE                         ( UPCONFIG_CAPABLE ),
    .UPSTREAM_FACING                          ( UPSTREAM_FACING ),
    .UR_ATOMIC                                ( UR_ATOMIC ),
    .UR_CFG1                                  ( UR_CFG1 ),
    .UR_INV_REQ                               ( UR_INV_REQ ),
    .UR_PRS_RESPONSE                          ( UR_PRS_RESPONSE ),
    .USE_RID_PINS                             ( USE_RID_PINS ),
    .USER_CLK_FREQ                            ( USER_CLK_FREQ ),
    .USER_CLK2_DIV2                           ( USER_CLK2_DIV2 ),
    .VC_BASE_PTR                              ( VC_BASE_PTR ),
    .VC_CAP_ID                                ( VC_CAP_ID ),
    .VC_CAP_NEXTPTR                           ( VC_CAP_NEXTPTR ),
    .VC_CAP_ON                                ( VC_CAP_ON ),
    .VC_CAP_REJECT_SNOOP_TRANSACTIONS         ( VC_CAP_REJECT_SNOOP_TRANSACTIONS ),
    .VC_CAP_VERSION                           ( VC_CAP_VERSION ),
    .VC0_CPL_INFINITE                         ( VC0_CPL_INFINITE ),
    .VC0_RX_RAM_LIMIT                         ( VC0_RX_RAM_LIMIT ),
    .VC0_TOTAL_CREDITS_CD                     ( VC0_TOTAL_CREDITS_CD ),
    .VC0_TOTAL_CREDITS_CH                     ( VC0_TOTAL_CREDITS_CH ),
    .VC0_TOTAL_CREDITS_NPD                    ( VC0_TOTAL_CREDITS_NPD ),
    .VC0_TOTAL_CREDITS_NPH                    ( VC0_TOTAL_CREDITS_NPH ),
    .VC0_TOTAL_CREDITS_PD                     ( VC0_TOTAL_CREDITS_PD ),
    .VC0_TOTAL_CREDITS_PH                     ( VC0_TOTAL_CREDITS_PH ),
    .VC0_TX_LASTPACKET                        ( VC0_TX_LASTPACKET ),
    .VSEC_BASE_PTR                            ( VSEC_BASE_PTR ),
    .VSEC_CAP_HDR_ID                          ( VSEC_CAP_HDR_ID ),
    .VSEC_CAP_HDR_REVISION                    ( VSEC_CAP_HDR_REVISION ),
    .VSEC_CAP_ID                              ( VSEC_CAP_ID ),
    .VSEC_CAP_IS_LINK_VISIBLE                 ( VSEC_CAP_IS_LINK_VISIBLE ),
    .VSEC_CAP_NEXTPTR                         ( VSEC_CAP_NEXTPTR ),
    .VSEC_CAP_ON                              ( VSEC_CAP_ON ),
    .VSEC_CAP_VERSION                         ( VSEC_CAP_VERSION )

  )
  u_pcie_block (
    .TRNTD                               ({{(128-C_DATA_WIDTH){1'b0}},trn.td}          ),
    .TRNTREM                             ({1'b0,trn.trem}          ),

    .TRNTSOF                             (trn.tsof                                   ),
    .TRNTEOF                             (trn.teof                                   ),
    .TRNTSRCRDY                          (trn.tsrc_rdy                               ),
    .TRNTSRCDSC                          (trn.tsrc_dsc                               ),
    .TRNTERRFWD                          (trn.terrfwd                                ),
    .TRNTECRCGEN                         (trn.tecrc_gen                              ),
    .TRNTSTR                             (trn.tstr                                   ),
    .TRNTCFGGNT                          (trn.tcfg_gnt                               ),
    .TRNRDSTRDY                          (trn.rdst_rdy                               ),
    .TRNRNPREQ                           (1'b1),
    .TRNRFCPRET                          (1'b1),
    .TRNRNPOK                            (1'b1),
    .TRNFCSEL                            ('0),
    .MIMTXRDATA                          (mim_tx.rdata                              ),
    .MIMRXRDATA                          (mim_rx.rdata                              ),
    .TRNTDLLPDATA                        ('0),
    .TRNTDLLPSRCRDY                      (1'b0),
    .LL2TLPRCV                           (1'b0),
    .LL2SENDENTERL1                      (1'b0),
    .LL2SENDENTERL23                     (1'b0),
    .LL2SENDASREQL1                      (1'b0),
    .LL2SENDPMACK                        (1'b0),
    .PL2DIRECTEDLSTATE                   ('0),
    .LL2SUSPENDNOW                       (1'b0),
    .TL2PPMSUSPENDREQ                    (1'b0),
    .TL2ASPMSUSPENDCREDITCHECK           (1'b0),
    .PLDIRECTEDLINKCHANGE                ('0),
    .PLDIRECTEDLINKWIDTH                 ('0),
    .PLDIRECTEDLINKSPEED                 (1'b0),
    .PLDIRECTEDLINKAUTON                 (1'b0),
    .PLUPSTREAMPREFERDEEMPH              (1'b0),
    .PLDOWNSTREAMDEEMPHSOURCE            (1'b0),
    .PLDIRECTEDLTSSMNEW                  ('0),
    .PLDIRECTEDLTSSMNEWVLD               (1'b0),
    .PLDIRECTEDLTSSMSTALL                (1'b0),
    .PIPERX0CHARISK                      ((rx_blk[0].char_is_k)                         ),
    .PIPERX1CHARISK                      ((rx_blk[1].char_is_k)                         ),
    .PIPERX2CHARISK                      ((rx_blk[2].char_is_k)                         ),
    .PIPERX3CHARISK                      ((rx_blk[3].char_is_k)                         ),
    .PIPERX4CHARISK                      ((rx_blk[4].char_is_k)                         ),
    .PIPERX5CHARISK                      ((rx_blk[5].char_is_k)                         ),
    .PIPERX6CHARISK                      ((rx_blk[6].char_is_k)                         ),
    .PIPERX7CHARISK                      ((rx_blk[7].char_is_k)                         ),
    .PIPERX0VALID                        ((rx_blk[0].valid)                             ),
    .PIPERX1VALID                        ((rx_blk[1].valid)                             ),
    .PIPERX2VALID                        ((rx_blk[2].valid)                             ),
    .PIPERX3VALID                        ((rx_blk[3].valid)                             ),
    .PIPERX4VALID                        ((rx_blk[4].valid)                             ),
    .PIPERX5VALID                        ((rx_blk[5].valid)                             ),
    .PIPERX6VALID                        ((rx_blk[6].valid)                             ),
    .PIPERX7VALID                        ((rx_blk[7].valid)                             ),
    .PIPERX0DATA                         ((rx_blk[0].data)                              ),
    .PIPERX1DATA                         ((rx_blk[1].data)                              ),
    .PIPERX2DATA                         ((rx_blk[2].data)                              ),
    .PIPERX3DATA                         ((rx_blk[3].data)                              ),
    .PIPERX4DATA                         ((rx_blk[4].data)                              ),
    .PIPERX5DATA                         ((rx_blk[5].data)                              ),
    .PIPERX6DATA                         ((rx_blk[6].data)                              ),
    .PIPERX7DATA                         ((rx_blk[7].data)                              ),
    .PIPERX0CHANISALIGNED                ((rx_blk[0].chanisaligned)                     ),
    .PIPERX1CHANISALIGNED                ((rx_blk[1].chanisaligned)                     ),
    .PIPERX2CHANISALIGNED                ((rx_blk[2].chanisaligned)                     ),
    .PIPERX3CHANISALIGNED                ((rx_blk[3].chanisaligned)                     ),
    .PIPERX4CHANISALIGNED                ((rx_blk[4].chanisaligned)                     ),
    .PIPERX5CHANISALIGNED                ((rx_blk[5].chanisaligned)                     ),
    .PIPERX6CHANISALIGNED                ((rx_blk[6].chanisaligned)                     ),
    .PIPERX7CHANISALIGNED                ((rx_blk[7].chanisaligned)                     ),
    .PIPERX0STATUS                       ((rx_blk[0].status)                            ),
    .PIPERX1STATUS                       ((rx_blk[1].status)                            ),
    .PIPERX2STATUS                       ((rx_blk[2].status)                            ),
    .PIPERX3STATUS                       ((rx_blk[3].status)                            ),
    .PIPERX4STATUS                       ((rx_blk[4].status)                            ),
    .PIPERX5STATUS                       ((rx_blk[5].status)                            ),
    .PIPERX6STATUS                       ((rx_blk[6].status)                            ),
    .PIPERX7STATUS                       ((rx_blk[7].status)                            ),
    .PIPERX0PHYSTATUS                    ((rx_blk[0].phy_status)                        ),
    .PIPERX1PHYSTATUS                    ((rx_blk[1].phy_status)                        ),
    .PIPERX2PHYSTATUS                    ((rx_blk[2].phy_status)                        ),
    .PIPERX3PHYSTATUS                    ((rx_blk[3].phy_status)                        ),
    .PIPERX4PHYSTATUS                    ((rx_blk[4].phy_status)                        ),
    .PIPERX5PHYSTATUS                    ((rx_blk[5].phy_status)                        ),
    .PIPERX6PHYSTATUS                    ((rx_blk[6].phy_status)                        ),
    .PIPERX7PHYSTATUS                    ((rx_blk[7].phy_status)                        ),
    .PIPERX0ELECIDLE                     ((rx_blk[0].elec_idle)                         ),
    .PIPERX1ELECIDLE                     ((rx_blk[1].elec_idle)                         ),
    .PIPERX2ELECIDLE                     ((rx_blk[2].elec_idle)                         ),
    .PIPERX3ELECIDLE                     ((rx_blk[3].elec_idle)                         ),
    .PIPERX4ELECIDLE                     ((rx_blk[4].elec_idle)                         ),
    .PIPERX5ELECIDLE                     ((rx_blk[5].elec_idle)                         ),
    .PIPERX6ELECIDLE                     ((rx_blk[6].elec_idle)                         ),
    .PIPERX7ELECIDLE                     ((rx_blk[7].elec_idle)                         ),
    .PIPECLK                             (pipe_clk                                   ),
    .USERCLK                             (user_clk                                   ),
    .USERCLK2                            (user_clk                                  ),
    .SYSRSTN                             ((~phy_rdy_n)                                  ),
    .CMRSTN                              (1'b1),
    .CMSTICKYRSTN                        (1'b1),
    .FUNCLVLRSTN                         (1'b1),
    .TLRSTN                              (1'b1),
    .DLRSTN                              (1'b1),
    .PLRSTN                              (1'b1),
    .PLTRANSMITHOTRST                    (1'b0),
    .CFGMGMTDI                           ('0),
    .CFGMGMTBYTEENN                      ((~4'h0)                         ),
    .CFGMGMTDWADDR                       ('0),
    .CFGMGMTWRRW1CASRWN                  ((~1'b0)                   ),
    .CFGMGMTWRREADONLYN                  ((~1'b0)                     ),
    .CFGMGMTWRENN                        ((~1'b0)                           ),
    .CFGMGMTRDENN                        ((~1'b0)                           ),
    .CFGERRMALFORMEDN                    ((~1'b0)                        ),
    .CFGERRCORN                          ((~1'b0)                              ),
    .CFGERRURN                           ((~1'b0)                               ),
    .CFGERRECRCN                         ((~1'b0)                             ),
    .CFGERRCPLTIMEOUTN                   ((~1'b0)                      ),
    .CFGERRCPLABORTN                     ((~1'b0)                        ),
    .CFGERRCPLUNEXPECTN                  ((~1'b0)                     ),
    .CFGERRPOISONEDN                     ((~1'b0)                         ),
    .CFGERRACSN                          (1'b1),
    .CFGERRATOMICEGRESSBLOCKEDN          ((~1'b0)            ),
    .CFGERRMCBLOCKEDN                    ((~1'b0)                       ),
    .CFGERRINTERNALUNCORN                ((~1'b0)                   ),
    .CFGERRINTERNALCORN                  ((~1'b0)                     ),
    .CFGERRPOSTEDN                       ((~1'b0)                           ),
    .CFGERRLOCKEDN                       ((~1'b0)                           ),
    .CFGERRNORECOVERYN                   ((~1'b0)                       ),
    .CFGERRAERHEADERLOG                  ('0),
    .CFGERRTLPCPLHEADER                  ('0),
    .CFGINTERRUPTN                       ((~1'b0)                            ),
    .CFGINTERRUPTDI                      ('0),
    .CFGINTERRUPTASSERTN                 ((~1'b0)                     ),
    .CFGINTERRUPTSTATN                   ((~1'b0)                       ),
    .CFGDSBUSNUMBER                      ('0),
    .CFGDSDEVICENUMBER                   ('0),
    .CFGDSFUNCTIONNUMBER                 ('0),
    .CFGPORTNUMBER                       ('0),
    .CFGPMHALTASPML0SN                   ((~1'b0)                     ),
    .CFGPMHALTASPML1N                    ((~1'b0)                      ),
    .CFGPMFORCESTATEENN                  ((~1'b0)                    ),
    .CFGPMFORCESTATE                     ('0),
    .CFGPMWAKEN                          ((~1'b0)                              ),
    .CFGPMTURNOFFOKN                     (cfg_turnoff_ok_w                        ),
    .CFGPMSENDPMETON                     (1'b1),
    .CFGPCIECAPINTERRUPTMSGNUM           ('0),
    .CFGTRNPENDINGN                      ((~1'b0)                          ),
    .CFGFORCEMPS                         ('0),
    .CFGFORCECOMMONCLOCKOFF              (1'b0),
    .CFGFORCEEXTENDEDSYNCON              (1'b0),
    .CFGDSN                              ('0),
    .CFGDEVID                            (cfg_dev_id                                 ),
    .CFGVENDID                           (cfg_vend_id                                ),
    .CFGREVID                            (cfg_rev_id                                 ),
    .CFGSUBSYSID                         (cfg_subsys_id                              ),
    .CFGSUBSYSVENDID                     (cfg_subsys_vend_id                         ),
    .CFGAERINTERRUPTMSGNUM               ('0),
    .DRPCLK                              (1'b1),
    .DRPEN                               (1'b0),
    .DRPWE                               (1'b0),
    .DRPADDR                             ('0),
    .DRPDI                               ('0),
    .DBGMODE                             ('0),
    .DBGSUBMODE                          (1'b0),
    .PLDBGMODE                           ('0),

    .TRNTDSTRDY                          (trn_tdst_rdy_bus                           ),
    .TRNTERRDROP                         (),
    .TRNTBUFAV                           (tx_buf_avail                                ),
    .TRNTCFGREQ                          (tx_cfg_req                               ),
    .TRNRD                               (trn_rd                                     ),
    .TRNRREM                             (trn_rrem                                   ),
    .TRNRSOF                             (trn.rsof                                   ),
    .TRNREOF                             (trn.reof                                   ),
    .TRNRSRCRDY                          (trn.rsrc_rdy                               ),
    .TRNRSRCDSC                          (trn.rsrc_dsc                               ),
    .TRNRECRCERR                         (trn.recrc_err                              ),
    .TRNRERRFWD                          (trn.rerrfwd                                ),
    .TRNRBARHIT                          (trn_rbar_hit                               ),
    .TRNLNKUP                            (trn_lnk_up                                 ),
    .TRNFCPH                             (),
    .TRNFCPD                             (),
    .TRNFCNPH                            (),
    .TRNFCNPD                            (),
    .TRNFCCPLH                           (),
    .TRNFCCPLD                           (),
    .MIMTXWDATA                          (mim_tx.wdata                              ),
    .MIMTXWADDR                          (mim_tx.waddr                              ),
    .MIMTXWEN                            (mim_tx.wen                                ),
    .MIMTXRADDR                          (mim_tx.raddr                              ),
    .MIMTXREN                            (mim_tx.ren                                ),
    .MIMRXWDATA                          (mim_rx.wdata                              ),
    .MIMRXWADDR                          (mim_rx.waddr                              ),
    .MIMRXWEN                            (mim_rx.wen                                ),
    .MIMRXRADDR                          (mim_rx.raddr                              ),
    .MIMRXREN                            (mim_rx.ren                                ),
    .TRNTDLLPDSTRDY                      (),
    .TRNRDLLPDATA                        (),
    .TRNRDLLPSRCRDY                      (),
    .LL2TFCINIT1SEQ                      (),
    .LL2TFCINIT2SEQ                      (),
    .PL2SUSPENDOK                        (),
    .PL2RECOVERY                         (),
    .PL2RXELECIDLE                       (),
    .PL2RXPMSTATE                        (),
    .PL2L0REQ                            (),
    .LL2SUSPENDOK                        (),
    .LL2TXIDLE                           (),
    .LL2LINKSTATUS                       (),
    .TL2PPMSUSPENDOK                     (),
    .TL2ASPMSUSPENDREQ                   (),
    .TL2ASPMSUSPENDCREDITCHECKOK         (),
    .PL2LINKUP                           (),
    .PL2RECEIVERERR                      (),
    .LL2RECEIVERERR                      (),
    .LL2PROTOCOLERR                      (),
    .LL2BADTLPERR                        (),
    .LL2BADDLLPERR                       (),
    .LL2REPLAYROERR                      (),
    .LL2REPLAYTOERR                      (),
    .TL2ERRHDR                           (),
    .TL2ERRMALFORMED                     (),
    .TL2ERRRXOVERFLOW                    (),
    .TL2ERRFCPE                          (),
    .PLSELLNKRATE                        (),
    .PLSELLNKWIDTH                       (),
    .PLLTSSMSTATE                        (pl_ltssm_state                             ),
    .PLLANEREVERSALMODE                  (),
    .PLPHYLNKUPN                         (pl_phy_lnk_up_n                            ),
    .PLTXPMSTATE                         (),
    .PLRXPMSTATE                         (),
    .PLLINKUPCFGCAP                      (),
    .PLLINKGEN2CAP                       (),
    .PLLINKPARTNERGEN2SUPPORTED          (),
    .PLINITIALLINKWIDTH                  (),
    .PLDIRECTEDCHANGEDONE                (),
    .PIPETXRCVRDET                       (tx_rcvr_det_blk                           ),
    .PIPETXRESET                         (tx_reset_blk                              ),
    .PIPETXRATE                          (tx_rate_blk                               ),
    .PIPETXDEEMPH                        (tx_deemph_blk                             ),
    .PIPETXMARGIN                        (tx_margin_blk                             ),
    .PIPERX0POLARITY                     (rx_polarity_flat[0]                          ),
    .PIPERX1POLARITY                     (rx_polarity_flat[1]                          ),
    .PIPERX2POLARITY                     (rx_polarity_flat[2]                          ),
    .PIPERX3POLARITY                     (rx_polarity_flat[3]                          ),
    .PIPERX4POLARITY                     (rx_polarity_flat[4]                          ),
    .PIPERX5POLARITY                     (rx_polarity_flat[5]                          ),
    .PIPERX6POLARITY                     (rx_polarity_flat[6]                          ),
    .PIPERX7POLARITY                     (rx_polarity_flat[7]                          ),
    .PIPETX0COMPLIANCE                   (tx_compliance_blk[0]                        ),
    .PIPETX1COMPLIANCE                   (tx_compliance_blk[1]                        ),
    .PIPETX2COMPLIANCE                   (tx_compliance_blk[2]                        ),
    .PIPETX3COMPLIANCE                   (tx_compliance_blk[3]                        ),
    .PIPETX4COMPLIANCE                   (tx_compliance_blk[4]                        ),
    .PIPETX5COMPLIANCE                   (tx_compliance_blk[5]                        ),
    .PIPETX6COMPLIANCE                   (tx_compliance_blk[6]                        ),
    .PIPETX7COMPLIANCE                   (tx_compliance_blk[7]                        ),
    .PIPETX0CHARISK                      (tx_char_is_k_blk[0]                         ),
    .PIPETX1CHARISK                      (tx_char_is_k_blk[1]                         ),
    .PIPETX2CHARISK                      (tx_char_is_k_blk[2]                         ),
    .PIPETX3CHARISK                      (tx_char_is_k_blk[3]                         ),
    .PIPETX4CHARISK                      (tx_char_is_k_blk[4]                         ),
    .PIPETX5CHARISK                      (tx_char_is_k_blk[5]                         ),
    .PIPETX6CHARISK                      (tx_char_is_k_blk[6]                         ),
    .PIPETX7CHARISK                      (tx_char_is_k_blk[7]                         ),
    .PIPETX0DATA                         (tx_data_blk[0]                              ),
    .PIPETX1DATA                         (tx_data_blk[1]                              ),
    .PIPETX2DATA                         (tx_data_blk[2]                              ),
    .PIPETX3DATA                         (tx_data_blk[3]                              ),
    .PIPETX4DATA                         (tx_data_blk[4]                              ),
    .PIPETX5DATA                         (tx_data_blk[5]                              ),
    .PIPETX6DATA                         (tx_data_blk[6]                              ),
    .PIPETX7DATA                         (tx_data_blk[7]                              ),
    .PIPETX0ELECIDLE                     (tx_elec_idle_blk[0]                         ),
    .PIPETX1ELECIDLE                     (tx_elec_idle_blk[1]                         ),
    .PIPETX2ELECIDLE                     (tx_elec_idle_blk[2]                         ),
    .PIPETX3ELECIDLE                     (tx_elec_idle_blk[3]                         ),
    .PIPETX4ELECIDLE                     (tx_elec_idle_blk[4]                         ),
    .PIPETX5ELECIDLE                     (tx_elec_idle_blk[5]                         ),
    .PIPETX6ELECIDLE                     (tx_elec_idle_blk[6]                         ),
    .PIPETX7ELECIDLE                     (tx_elec_idle_blk[7]                         ),
    .PIPETX0POWERDOWN                    (tx_powerdown_blk[0]                         ),
    .PIPETX1POWERDOWN                    (tx_powerdown_blk[1]                         ),
    .PIPETX2POWERDOWN                    (tx_powerdown_blk[2]                         ),
    .PIPETX3POWERDOWN                    (tx_powerdown_blk[3]                         ),
    .PIPETX4POWERDOWN                    (tx_powerdown_blk[4]                         ),
    .PIPETX5POWERDOWN                    (tx_powerdown_blk[5]                         ),
    .PIPETX6POWERDOWN                    (tx_powerdown_blk[6]                         ),
    .PIPETX7POWERDOWN                    (tx_powerdown_blk[7]                         ),
    .USERRSTN                            (user_rst_n                                 ),
    .PLRECEIVEDHOTRST                    (pl_received_hot_rst                        ),
    .RECEIVEDFUNCLVLRSTN                 (),
    .LNKCLKEN                            (),
    .CFGMGMTDO                           (),
    .CFGMGMTRDWRDONEN                    (),
    .CFGERRAERHEADERLOGSETN              (),
    .CFGERRCPLRDYN                       (),
    .CFGINTERRUPTRDYN                    (),
    .CFGINTERRUPTMMENABLE                (),
    .CFGINTERRUPTMSIENABLE               (),
    .CFGINTERRUPTDO                      (),
    .CFGINTERRUPTMSIXENABLE              (),
    .CFGINTERRUPTMSIXFM                  (),
    .CFGMSGRECEIVED                      (cfg_msg_received                           ),
    .CFGMSGDATA                          (cfg_msg_data                               ),
    .CFGMSGRECEIVEDERRCOR                (),
    .CFGMSGRECEIVEDERRNONFATAL           (),
    .CFGMSGRECEIVEDERRFATAL              (cfg_msg_received_err_fatal                 ),
    .CFGMSGRECEIVEDASSERTINTA            (),
    .CFGMSGRECEIVEDDEASSERTINTA          (),
    .CFGMSGRECEIVEDASSERTINTB            (),
    .CFGMSGRECEIVEDDEASSERTINTB          (),
    .CFGMSGRECEIVEDASSERTINTC            (),
    .CFGMSGRECEIVEDDEASSERTINTC          (),
    .CFGMSGRECEIVEDASSERTINTD            (),
    .CFGMSGRECEIVEDDEASSERTINTD          (),
    .CFGMSGRECEIVEDPMPME                 (),
    .CFGMSGRECEIVEDPMETOACK              (),
    .CFGMSGRECEIVEDPMETO                 (cfg_msg_received_pme_to                    ),
    .CFGMSGRECEIVEDSETSLOTPOWERLIMIT     (),
    .CFGMSGRECEIVEDUNLOCK                (),
    .CFGMSGRECEIVEDPMASNAK               (),
    .CFGPCIELINKSTATE                    (cfg_pcie_link_state                        ),
    .CFGPMRCVASREQL1N                    (),
    .CFGPMRCVREQACKN                     (),
    .CFGPMRCVENTERL1N                    (),
    .CFGPMRCVENTERL23N                   (),
    .CFGPMCSRPOWERSTATE                  (cfg_pmcsr_powerstate                       ),
    .CFGPMCSRPMEEN                       (),
    .CFGPMCSRPMESTATUS                   (),
    .CFGTRANSACTION                      (),
    .CFGTRANSACTIONTYPE                  (),
    .CFGTRANSACTIONADDR                  (),
    .CFGCOMMANDIOENABLE                  (cfg_command_io_enable                      ),
    .CFGCOMMANDMEMENABLE                 (cfg_command_mem_enable                     ),
    .CFGCOMMANDBUSMASTERENABLE           (cfg_command_bus_master_enable              ),
    .CFGCOMMANDINTERRUPTDISABLE          (cfg_command_interrupt_disable              ),
    .CFGCOMMANDSERREN                    (cfg_command_serr_en                        ),
    .CFGBRIDGESERREN                     (),
    .CFGDEVSTATUSCORRERRDETECTED         (cfg_dev_status_corr_err_detected           ),
    .CFGDEVSTATUSNONFATALERRDETECTED     (cfg_dev_status_non_fatal_err_detected      ),
    .CFGDEVSTATUSFATALERRDETECTED        (cfg_dev_status_fatal_err_detected          ),
    .CFGDEVSTATUSURDETECTED              (cfg_dev_status_ur_detected                 ),
    .CFGDEVCONTROLCORRERRREPORTINGEN     (),
    .CFGDEVCONTROLNONFATALREPORTINGEN    (cfg_dev_control_non_fatal_reporting_en     ),
    .CFGDEVCONTROLFATALERRREPORTINGEN    (cfg_dev_control_fatal_err_reporting_en     ),
    .CFGDEVCONTROLURERRREPORTINGEN       (cfg_dev_control_ur_err_reporting_en        ),
    .CFGDEVCONTROLENABLERO               (cfg_dev_control_enable_ro                  ),
    .CFGDEVCONTROLMAXPAYLOAD             (),
    .CFGDEVCONTROLEXTTAGEN               (cfg_dev_control_ext_tag_en                 ),
    .CFGDEVCONTROLPHANTOMEN              (cfg_dev_control_phantom_en                 ),
    .CFGDEVCONTROLAUXPOWEREN             (cfg_dev_control_aux_power_en               ),
    .CFGDEVCONTROLNOSNOOPEN              (cfg_dev_control_no_snoop_en                ),
    .CFGDEVCONTROLMAXREADREQ             (),
    .CFGLINKSTATUSCURRENTSPEED           (),
    .CFGLINKSTATUSNEGOTIATEDWIDTH        (),
    .CFGLINKSTATUSLINKTRAINING           (cfg_link_status_link_training              ),
    .CFGLINKSTATUSDLLACTIVE              (cfg_link_status_dll_active                 ),
    .CFGLINKSTATUSBANDWIDTHSTATUS        (cfg_link_status_bandwidth_status           ),
    .CFGLINKSTATUSAUTOBANDWIDTHSTATUS    (cfg_link_status_auto_bandwidth_status      ),
    .CFGLINKCONTROLASPMCONTROL           (),
    .CFGLINKCONTROLRCB                   (),
    .CFGLINKCONTROLLINKDISABLE           (cfg_link_control_link_disable              ),
    .CFGLINKCONTROLRETRAINLINK           (cfg_link_control_retrain_link              ),
    .CFGLINKCONTROLCOMMONCLOCK           (cfg_link_control_common_clock              ),
    .CFGLINKCONTROLEXTENDEDSYNC          (cfg_link_control_extended_sync             ),
    .CFGLINKCONTROLCLOCKPMEN             (cfg_link_control_clock_pm_en               ),
    .CFGLINKCONTROLHWAUTOWIDTHDIS        (cfg_link_control_hw_auto_width_dis         ),
    .CFGLINKCONTROLBANDWIDTHINTEN        (cfg_link_control_bandwidth_int_en          ),
    .CFGLINKCONTROLAUTOBANDWIDTHINTEN    (cfg_link_control_auto_bandwidth_int_en     ),
    .CFGDEVCONTROL2CPLTIMEOUTVAL         (),
    .CFGDEVCONTROL2CPLTIMEOUTDIS         (cfg_dev_control2_cpl_timeout_dis           ),
    .CFGDEVCONTROL2ARIFORWARDEN          (cfg_dev_control2_ari_forward_en            ),
    .CFGDEVCONTROL2ATOMICREQUESTEREN     (cfg_dev_control2_atomic_requester_en       ),
    .CFGDEVCONTROL2ATOMICEGRESSBLOCK     (cfg_dev_control2_atomic_egress_block       ),
    .CFGDEVCONTROL2IDOREQEN              (cfg_dev_control2_ido_req_en                ),
    .CFGDEVCONTROL2IDOCPLEN              (cfg_dev_control2_ido_cpl_en                ),
    .CFGDEVCONTROL2LTREN                 (cfg_dev_control2_ltr_en                    ),
    .CFGDEVCONTROL2TLPPREFIXBLOCK        (cfg_dev_control2_tlp_prefix_block          ),
    .CFGSLOTCONTROLELECTROMECHILCTLPULSE (),
    .CFGROOTCONTROLSYSERRCORRERREN       (),
    .CFGROOTCONTROLSYSERRNONFATALERREN   (),
    .CFGROOTCONTROLSYSERRFATALERREN      (),
    .CFGROOTCONTROLPMEINTEN              (),
    .CFGAERECRCCHECKEN                   (),
    .CFGAERECRCGENEN                     (),
    .CFGAERROOTERRCORRERRREPORTINGEN     (),
    .CFGAERROOTERRNONFATALERRREPORTINGEN (),
    .CFGAERROOTERRFATALERRREPORTINGEN    (),
    .CFGAERROOTERRCORRERRRECEIVED        (),
    .CFGAERROOTERRNONFATALERRRECEIVED    (),
    .CFGAERROOTERRFATALERRRECEIVED       (),
    .CFGVCTCVCMAP                        (),
    .DRPRDY                              (),
    .DRPDO                               (),
    .DBGVECA                             (),
    .DBGVECB                             (),
    .DBGVECC                             (),
    .DBGSCLRA                            (),
    .DBGSCLRB                            (),
    .DBGSCLRC                            (),
    .DBGSCLRD                            (),
    .DBGSCLRE                            (),
    .DBGSCLRF                            (),
    .DBGSCLRG                            (),
    .DBGSCLRH                            (),
    .DBGSCLRI                            (),
    .DBGSCLRJ                            (),
    .DBGSCLRK                            (),
    .PLDBGVEC                            ()
  );

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
