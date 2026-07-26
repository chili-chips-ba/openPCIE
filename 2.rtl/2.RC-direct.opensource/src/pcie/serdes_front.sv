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

module serdes_front
  import link_pkg::*;
#(
  localparam         LINK_CAP_MAX_LINK_WIDTH = 1,
  localparam         REF_CLK_FREQ            = 0,
  localparam         USER_CLK2_DIV2          = "FALSE",
  localparam int USER_CLK_FREQ           = 1,
  localparam         PL_FAST_TRAIN           = "FALSE",
  localparam         PCIE_EXT_CLK            = "FALSE",
  localparam         PCIE_USE_MODE           = "1.0",
  localparam         PCIE_GT_DEVICE          = "GTP",
  localparam         PCIE_PLL_SEL            = "CPLL",
  localparam         PCIE_ASYNC_EN           = "FALSE",
  localparam         PCIE_TXBUF_EN           = "FALSE",
  localparam         PCIE_EXT_GT_COMMON      = "FALSE",
  localparam         EXT_CH_GT_DRP           = "FALSE",
  localparam         TX_MARGIN_FULL_0        = 7'b1001111,
  localparam         TX_MARGIN_FULL_1        = 7'b1001110,
  localparam         TX_MARGIN_FULL_2        = 7'b1001101,
  localparam         TX_MARGIN_FULL_3        = 7'b1001100,
  localparam         TX_MARGIN_FULL_4        = 7'b1000011,
  localparam         TX_MARGIN_LOW_0         = 7'b1000101,
  localparam         TX_MARGIN_LOW_1         = 7'b1000110,
  localparam         TX_MARGIN_LOW_2         = 7'b1000011,
  localparam         TX_MARGIN_LOW_3         = 7'b1000010,
  localparam         TX_MARGIN_LOW_4         = 7'b1000000,
  localparam         PCIE_CHAN_BOND          = 1,
  localparam         TCQ                     = 1
) (
  input  wire [5:0]                             pl_ltssm_state,

  phy_lanes_if.phy                              pipe,

  output wire [LINK_CAP_MAX_LINK_WIDTH-1:0]     pci_exp_txn,
  output wire [LINK_CAP_MAX_LINK_WIDTH-1:0]     pci_exp_txp,
  input  wire [LINK_CAP_MAX_LINK_WIDTH-1:0]     pci_exp_rxn,
  input  wire [LINK_CAP_MAX_LINK_WIDTH-1:0]     pci_exp_rxp,

  input  wire                                   sys_clk,
  input  wire                                   sys_rst_n,
  input  wire                                   PIPE_MMCM_RST_N,
  output wire                                   pipe_clk,
  output wire                                   user_clk,
  output wire                                   user_clk2,

  input  wire                                   PIPE_PCLK_IN,
  input  wire                                   PIPE_RXUSRCLK_IN,
  input  wire [LINK_CAP_MAX_LINK_WIDTH-1:0]     PIPE_RXOUTCLK_IN,
  input  wire                                   PIPE_DCLK_IN,
  input  wire                                   PIPE_USERCLK1_IN,
  input  wire                                   PIPE_USERCLK2_IN,
  input  wire                                   PIPE_OOBCLK_IN,
  input  wire                                   PIPE_MMCM_LOCK_IN,
  output wire                                   PIPE_TXOUTCLK_OUT,
  output wire [LINK_CAP_MAX_LINK_WIDTH-1:0]     PIPE_RXOUTCLK_OUT,
  output wire [LINK_CAP_MAX_LINK_WIDTH-1:0]     PIPE_PCLK_SEL_OUT,
  output wire                                   PIPE_GEN3_OUT,

  output wire                                   phy_rdy_n
);

  localparam USERCLK2_FREQ  = (USER_CLK2_DIV2 == "FALSE") ? USER_CLK_FREQ :
                              (USER_CLK_FREQ == 4) ? 3 :
                              (USER_CLK_FREQ == 3) ? 2 : USER_CLK_FREQ;
  localparam PCIE_LPM_DFE   = (PL_FAST_TRAIN == "TRUE") ? "DFE" : "LPM";
  localparam PCIE_LINK_SPEED = (PL_FAST_TRAIN == "TRUE") ? 2 : 3;
  localparam PCIE_OOBCLK_MODE_ENABLE = 1;
  localparam PCIE_TX_EIDLE_ASSERT_DELAY = (PL_FAST_TRAIN == "TRUE") ? 3'd4 : 3'd2;

  wire [  7:0]                       gt_rx_phy_status_wire;
  wire [  7:0]                       gt_rxchanisaligned_wire;
  wire [ 31:0]                       gt_rx_data_k_wire;
  wire [255:0]                       gt_rx_data_wire;
  wire [  7:0]                       gt_rx_elec_idle_wire;
  wire [ 23:0]                       gt_rx_status_wire;
  wire [  7:0]                       gt_rx_valid_wire;
  wire [  7:0]                       gt_rx_polarity;
  wire [ 15:0]                       gt_power_down;
  wire [  7:0]                       gt_tx_char_disp_mode;
  wire [ 31:0]                       gt_tx_data_k;
  wire [255:0]                       gt_tx_data;
  wire                               gt_tx_detect_rx_loopback;
  wire [  7:0]                       gt_tx_elec_idle;
  wire [LINK_CAP_MAX_LINK_WIDTH-1:0] phystatus_rst;
  wire                               clock_locked;

  wire [  7:0]                       gt_rx_phy_status_wire_filter;
  wire [ 31:0]                       gt_rx_data_k_wire_filter;
  wire [255:0]                       gt_rx_data_wire_filter;
  wire [  7:0]                       gt_rx_elec_idle_wire_filter;
  wire [ 23:0]                       gt_rx_status_wire_filter;
  wire [  7:0]                       gt_rx_valid_wire_filter;

  wire                               pipe_clk_int;
  logic                                phy_rdy_n_int;
  logic                                reg_clock_locked;
  wire                               all_phystatus_rst;

  assign pipe_clk = pipe_clk_int;

  logic [5:0] pl_ltssm_state_q;

  always_ff @(posedge pipe_clk_int or negedge clock_locked) begin
    if (!clock_locked) pl_ltssm_state_q <= 6'b0;
    else               pl_ltssm_state_q <= pl_ltssm_state;
  end

  wire plm_in_l0 = (pl_ltssm_state_q == 6'h16);
  wire plm_in_rs = (pl_ltssm_state_q == 6'h1f);

  genvar i;
  generate for (i = 0; i < LINK_CAP_MAX_LINK_WIDTH; i = i + 1)
    begin : squelch_gen

      eios_squelch squelch_i (
        .USER_RXCHARISK     (gt_rx_data_k_wire[(4*i)+:2]),
        .USER_RXDATA        (gt_rx_data_wire[(32*i)+:16]),
        .USER_RXVALID       (gt_rx_valid_wire[i]),
        .USER_RXELECIDLE    (gt_rx_elec_idle_wire[i]),
        .USER_RX_STATUS     (gt_rx_status_wire[(3*i)+:3]),
        .USER_RX_PHY_STATUS (gt_rx_phy_status_wire[i]),

        .GT_RXCHARISK       (gt_rx_data_k_wire_filter[(4*i)+:2]),
        .GT_RXDATA          (gt_rx_data_wire_filter[(32*i)+:16]),
        .GT_RXVALID         (gt_rx_valid_wire_filter[i]),
        .GT_RXELECIDLE      (gt_rx_elec_idle_wire_filter[i]),
        .GT_RX_STATUS       (gt_rx_status_wire_filter[(3*i)+:3]),
        .GT_RX_PHY_STATUS   (gt_rx_phy_status_wire_filter[i]),

        .PLM_IN_L0          (plm_in_l0),
        .PLM_IN_RS          (plm_in_rs),
        .USER_CLK           (pipe_clk_int),
        .RESET              (phy_rdy_n_int)
      );

    end
  endgenerate

  generate for (i = 0; i < PIPE_MAX_LANES; i = i + 1)
    begin : lane_map

      assign gt_tx_data      [(32*i)+:32] = {16'd0, pipe.tx[i].data};
      assign gt_tx_data_k    [( 4*i)+: 4] = { 2'd0, pipe.tx[i].char_is_k};
      assign gt_power_down   [( 2*i)+: 2] = pipe.tx[i].powerdown;
      assign gt_tx_char_disp_mode[i]      = pipe.tx[i].compliance;
      assign gt_tx_elec_idle [i]          = pipe.tx[i].elec_idle;
      assign gt_rx_polarity  [i]          = pipe.rx_polarity[i];

      if (i < LINK_CAP_MAX_LINK_WIDTH) begin : active
        assign pipe.rx[i].char_is_k     = gt_rx_data_k_wire[(4*i)+:2];
        assign pipe.rx[i].data          = gt_rx_data_wire[(32*i)+:16];
        assign pipe.rx[i].valid         = gt_rx_valid_wire[i];
        assign pipe.rx[i].chanisaligned = gt_rxchanisaligned_wire[i];
        assign pipe.rx[i].status        = gt_rx_status_wire[(3*i)+:3];
        assign pipe.rx[i].phy_status    = gt_rx_phy_status_wire[i];
        assign pipe.rx[i].elec_idle     = gt_rx_elec_idle_wire[i];

        assign gt_rx_data_wire  [(32*i)+16+:16] = 16'b0;
        assign gt_rx_data_k_wire[( 4*i)+ 2+: 2] =  2'b0;
      end
      else begin : unused
        assign pipe.rx[i] = PIPE_RX_LANE_TIE;

        assign gt_rx_data_wire  [(32*i)+:32] = 32'b0;
        assign gt_rx_data_k_wire[( 4*i)+: 4] =  4'b0;
      end

    end
  endgenerate

  assign gt_tx_detect_rx_loopback = pipe.tx_ctrl.rcvr_det;

  serdes_ctrl serdes_ctrl_i (
    .PIPE_CLK           (sys_clk),
    .PIPE_RESET_N       (sys_rst_n),
    .PIPE_PCLK          (pipe_clk_int),

    .PIPE_TXDATA        (gt_tx_data[(32*LINK_CAP_MAX_LINK_WIDTH)-1:0]),
    .PIPE_TXDATAK       (gt_tx_data_k[(4*LINK_CAP_MAX_LINK_WIDTH)-1:0]),
    .PIPE_TXP           (pci_exp_txp),
    .PIPE_TXN           (pci_exp_txn),

    .PIPE_RXP           (pci_exp_rxp),
    .PIPE_RXN           (pci_exp_rxn),
    .PIPE_RXDATA        (gt_rx_data_wire_filter[(32*LINK_CAP_MAX_LINK_WIDTH)-1:0]),
    .PIPE_RXDATAK       (gt_rx_data_k_wire_filter[(4*LINK_CAP_MAX_LINK_WIDTH)-1:0]),

    .PIPE_TXDETECTRX    (gt_tx_detect_rx_loopback),
    .PIPE_TXELECIDLE    (gt_tx_elec_idle[LINK_CAP_MAX_LINK_WIDTH-1:0]),
    .PIPE_TXCOMPLIANCE  (gt_tx_char_disp_mode[LINK_CAP_MAX_LINK_WIDTH-1:0]),
    .PIPE_RXPOLARITY    (gt_rx_polarity[LINK_CAP_MAX_LINK_WIDTH-1:0]),
    .PIPE_POWERDOWN     (gt_power_down[(2*LINK_CAP_MAX_LINK_WIDTH)-1:0]),
    .PIPE_RATE          ({1'b0, pipe.tx_ctrl.rate}),

    .PIPE_TXMARGIN      (pipe.tx_ctrl.margin),
    .PIPE_TXSWING       (1'b0),
    .PIPE_TXDEEMPH      ({LINK_CAP_MAX_LINK_WIDTH{pipe.tx_ctrl.deemph}}),
    .PIPE_TXEQ_CONTROL  ({ 2*LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .PIPE_TXEQ_PRESET   ({ 4*LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .PIPE_TXEQ_PRESET_DEFAULT ({4*LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .PIPE_RXEQ_CONTROL  ({ 2*LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .PIPE_RXEQ_PRESET   ({ 3*LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .PIPE_RXEQ_LFFS     ({ 6*LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .PIPE_RXEQ_TXPRESET ({ 4*LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .PIPE_RXEQ_USER_EN  ({ 1*LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .PIPE_RXEQ_USER_TXCOEFF ({18*LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .PIPE_RXEQ_USER_MODE({ 1*LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .PIPE_TXEQ_COEFF    (),
    .PIPE_TXEQ_DEEMPH   ({ 6*LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .PIPE_TXEQ_FS       (),
    .PIPE_TXEQ_LF       (),
    .PIPE_TXEQ_DONE     (),
    .PIPE_RXEQ_NEW_TXCOEFF (),
    .PIPE_RXEQ_LFFS_SEL (),
    .PIPE_RXEQ_ADAPT_DONE (),
    .PIPE_RXEQ_DONE     (),

    .PIPE_RXVALID       (gt_rx_valid_wire_filter[LINK_CAP_MAX_LINK_WIDTH-1:0]),
    .PIPE_PHYSTATUS     (gt_rx_phy_status_wire_filter[LINK_CAP_MAX_LINK_WIDTH-1:0]),
    .PIPE_PHYSTATUS_RST (phystatus_rst),
    .PIPE_RXELECIDLE    (gt_rx_elec_idle_wire_filter[LINK_CAP_MAX_LINK_WIDTH-1:0]),
    .PIPE_EYESCANDATAERROR (),
    .PIPE_RXSTATUS      (gt_rx_status_wire_filter[(3*LINK_CAP_MAX_LINK_WIDTH)-1:0]),

    .INT_PCLK_OUT_SLAVE    (),
    .INT_RXUSRCLK_OUT      (),
    .INT_RXOUTCLK_OUT      (),
    .INT_DCLK_OUT          (),
    .INT_USERCLK1_OUT      (),
    .INT_USERCLK2_OUT      (),
    .INT_OOBCLK_OUT        (),
    .INT_MMCM_LOCK_OUT     (),
    .INT_QPLLLOCK_OUT      (),
    .INT_QPLLOUTCLK_OUT    (),
    .INT_QPLLOUTREFCLK_OUT (),
    .INT_PCLK_SEL_SLAVE    ({LINK_CAP_MAX_LINK_WIDTH{1'b0}}),

    .PIPE_MMCM_RST_N    (PIPE_MMCM_RST_N),
    .PIPE_RXSLIDE       ({LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .PIPE_PCLK_LOCK     (clock_locked),
    .PIPE_RXCDRLOCK     (),
    .PIPE_USERCLK1      (user_clk),
    .PIPE_USERCLK2      (user_clk2),
    .PIPE_RXUSRCLK      (),
    .PIPE_RXOUTCLK      (),
    .PIPE_TXSYNC_DONE   (),
    .PIPE_RXSYNC_DONE   (),
    .PIPE_GEN3_RDY      (),
    .PIPE_RXCHANISALIGNED (gt_rxchanisaligned_wire[LINK_CAP_MAX_LINK_WIDTH-1:0]),
    .PIPE_ACTIVE_LANE   (),

    .PIPE_PCLK_IN       (PIPE_PCLK_IN),
    .PIPE_RXUSRCLK_IN   (PIPE_RXUSRCLK_IN),
    .PIPE_RXOUTCLK_IN   (PIPE_RXOUTCLK_IN),
    .PIPE_DCLK_IN       (PIPE_DCLK_IN),
    .PIPE_USERCLK1_IN   (PIPE_USERCLK1_IN),
    .PIPE_USERCLK2_IN   (PIPE_USERCLK2_IN),
    .PIPE_OOBCLK_IN     (PIPE_OOBCLK_IN),
    .PIPE_JTAG_EN       (1'b0),
    .PIPE_JTAG_RDY      (),
    .PIPE_MMCM_LOCK_IN  (PIPE_MMCM_LOCK_IN),
    .PIPE_TXOUTCLK_OUT  (PIPE_TXOUTCLK_OUT),
    .PIPE_RXOUTCLK_OUT  (PIPE_RXOUTCLK_OUT),
    .PIPE_PCLK_SEL_OUT  (PIPE_PCLK_SEL_OUT),
    .PIPE_GEN3_OUT      (PIPE_GEN3_OUT),

    .EXT_CH_GT_DRPCLK   (),
    .EXT_CH_GT_DRPADDR  ({9*LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .EXT_CH_GT_DRPEN    ({LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .EXT_CH_GT_DRPDI    ({16*LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .EXT_CH_GT_DRPWE    ({LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .EXT_CH_GT_DRPDO    (),
    .EXT_CH_GT_DRPRDY   (),

    .QPLL_DRP_CRSCODE   (12'b0),
    .QPLL_DRP_FSM       (18'b0),
    .QPLL_DRP_DONE      (2'b0),
    .QPLL_DRP_RESET     (2'b0),
    .QPLL_QPLLLOCK      (2'b0),
    .QPLL_QPLLOUTCLK    (2'b0),
    .QPLL_QPLLOUTREFCLK (2'b0),
    .QPLL_QPLLPD        (),
    .QPLL_QPLLRESET     (),
    .QPLL_DRP_CLK       (),
    .QPLL_DRP_RST_N     (),
    .QPLL_DRP_OVRD      (),
    .QPLL_DRP_GEN3      (),
    .QPLL_DRP_START     (),

    .PIPE_TXPRBSSEL     (3'b0),
    .PIPE_RXPRBSSEL     (3'b0),
    .PIPE_TXPRBSFORCEERR (1'b0),
    .PIPE_RXPRBSCNTRESET (1'b0),
    .PIPE_LOOPBACK      (3'b0),
    .PIPE_RXPRBSERR     (),
    .PIPE_TXINHIBIT     ({LINK_CAP_MAX_LINK_WIDTH{1'b0}}),

    .PIPE_RST_FSM       (),
    .PIPE_QRST_FSM      (),
    .PIPE_RATE_FSM      (),
    .PIPE_SYNC_FSM_TX   (),
    .PIPE_SYNC_FSM_RX   (),
    .PIPE_QDRP_FSM      (),
    .PIPE_RXEQ_FSM      (),
    .PIPE_TXEQ_FSM      (),
    .PIPE_DRP_FSM       (),
    .PIPE_RST_IDLE      (),
    .PIPE_QRST_IDLE     (),
    .PIPE_RATE_IDLE     (),
    .PIPE_CPLL_LOCK     (),
    .PIPE_QPLL_LOCK     (),
    .PIPE_RXPMARESETDONE (),
    .PIPE_RXBUFSTATUS   (),
    .PIPE_TXPHALIGNDONE (),
    .PIPE_TXPHINITDONE  (),
    .PIPE_TXDLYSRESETDONE (),
    .PIPE_RXPHALIGNDONE (),
    .PIPE_RXDLYSRESETDONE (),
    .PIPE_RXSYNCDONE    (),
    .PIPE_RXDISPERR     (),
    .PIPE_RXNOTINTABLE  (),
    .PIPE_RXCOMMADET    (),
    .PIPE_DEBUG_0       (),
    .PIPE_DEBUG_1       (),
    .PIPE_DEBUG_2       (),
    .PIPE_DEBUG_3       (),
    .PIPE_DEBUG_4       (),
    .PIPE_DEBUG_5       (),
    .PIPE_DEBUG_6       (),
    .PIPE_DEBUG_7       (),
    .PIPE_DEBUG_8       (),
    .PIPE_DEBUG_9       (),
    .PIPE_DEBUG         (),
    .PIPE_DMONITOROUT   ()
  );

  always_ff @(posedge pipe_clk_int or negedge clock_locked) begin
    if (!clock_locked) reg_clock_locked <= 1'b0;
    else               reg_clock_locked <= 1'b1;
  end

  assign all_phystatus_rst = &phystatus_rst;

  always_ff @(posedge pipe_clk_int) begin
    if (!reg_clock_locked) phy_rdy_n_int <= 1'b0;
    else                   phy_rdy_n_int <= all_phystatus_rst;
  end

  assign phy_rdy_n = phy_rdy_n_int;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
