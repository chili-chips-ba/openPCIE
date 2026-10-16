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

module lane_xcvr
  import link_pkg::*;
#(
    parameter int LANE = 0
) (
    input logic pipe_clk,         // TXUSRCLK/TXUSRCLK2, PIPE clock
    input logic clk125,           // DRP clock
    input logic clk_mmcm_lock,
    input logic gtpll0_outclk,    // from GTPE2_COMMON
    input logic gtpll0_outrefclk,

    pipe_if.phy pipe_phy,  // this lane's slice: pipe_phy.tx/rx[LANE]
    gtp_if.lane gtp,       // to/from gtp_wrapper, slice [LANE]

    output logic gt_txp,
    output logic gt_txn,
    input  logic gt_rxp,
    input  logic gt_rxn
);

  localparam bit MULTILANE       = (PCIE_LANES > 1);
  // PCIE_LANES <= 4: one GTP quad, channel bonding chain lane 0 -> 1 -> 2 -> 3
  localparam int CLK_COR_MIN_LAT = (PCIE_LANES == 1) ? 13 : (PCIE_LANES == 4) ? 19 : 18;

  // ---- lane status (sampled below)
  logic sigvalidclk, active_lane;
  // ---- speed_ctrl
  gtp_rate_t        rate;
  // ---- phase_align
  gtp_txsync_ctrl_t sync_tx;
  gtp_txsync_stat_t sync_tx_stat;
  logic             sync_txsync_done;
  // ---- chan_retune (DRP)
  gtp_drp_req_t     drp_req;
  gtp_drp_rsp_t     drp_rsp;
  logic             drp_done;
  // ---- GTPE2_CHANNEL status
  logic gt_txresetdone, gt_rxresetdone, gt_rxpmaresetdone;
  logic gt_rxvalid, gt_phystatus, gt_rxelecidle, gt_txratedone, gt_rxratedone;
  logic [2:0] gt_rxstatus;
  logic gt_txsyncout, gt_rxsyncout, gt_txoutclk;

  // lane 0 is the sync master and the PIPE clock source; on the other lanes
  // these GT outputs are no-connect (NC_)
  if (LANE == 0) begin : g_master
    assign gtp.txsyncout = gt_txsyncout;
    assign gtp.rxsyncout = gt_rxsyncout;
    assign gtp.txoutclk  = gt_txoutclk;
  end
  else begin : g_slave
    logic NC_txsyncout;
    assign NC_txsyncout = gt_txsyncout;
    logic NC_rxsyncout;
    assign NC_rxsyncout = gt_rxsyncout;
    logic NC_txoutclk;
    assign NC_txoutclk = gt_txoutclk;
  end

  assign gtp.drp_done[LANE]          = drp_done;
  assign gtp.phystatus[LANE]         = gt_phystatus;
  assign gtp.txsync_done[LANE]       = sync_txsync_done;
  assign gtp.active_lane[LANE]       = active_lane;
  assign gtp.pipe_clk_sel[LANE]      = rate.pipe_clk_sel;
  assign gtp.rxpmaresetdone[LANE]    = gt_rxpmaresetdone;

  assign pipe_phy.rx[LANE].elec_idle = gt_rxelecidle;
  assign pipe_phy.rx[LANE].status    = gt_rxstatus;

  // ---- lane status: GT and PIPE status sampled on pipe_clk (all inputs here
  // are pipe_clk: TX/RXRESETDONE are TX/RXUSRCLK2, the rest come from the PIPE
  // and speed_ctrl), so the stage pairs only add latency
  localparam logic [3:0] RXVALID_MAX = 4'd15;

  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [4:0] txst_s1, txst_s2;

  always_ff @(posedge pipe_clk) begin
    if (gtp.rst.gtpll0_reset) begin
      txst_s1 <= 5'd0;
      txst_s2 <= 5'd0;
    end
    else begin
      txst_s1 <= {
        pipe_phy.tx[LANE].compliance,
        pipe_phy.tx[LANE].elec_idle,
        gt_rxresetdone,
        gt_txresetdone,
        rate.pipe_clk_sel
      };
      txst_s2 <= txst_s1;
    end
  end

  logic pipe_clk_sel_2, txresetdone_2, rxresetdone_2, txelecidle_2, txcompliance_2;
  assign {txcompliance_2, txelecidle_2, rxresetdone_2, txresetdone_2, pipe_clk_sel_2} = txst_s2;

  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [4:0]
      rx_s1, rx_s2;  // rxvalid: not in the UG482 port tables

  always_ff @(posedge pipe_clk) begin
    if (gtp.rst.rxusrclk_reset) begin
      rx_s1 <= 5'd0;
      rx_s2 <= 5'd0;
    end
    else begin
      rx_s1 <= {rate.idle, rate.done, gtp.rst.idle, gt_rxstatus[2], gt_rxvalid};
      rx_s2 <= rx_s1;
    end
  end

  logic rxvalid_2, rxstatus_2, rst_idle_2, rate_done_2, rate_idle_2;
  assign {rate_idle_2, rate_done_2, rst_idle_2, rxstatus_2, rxvalid_2} = rx_s2;

  // SIGVALIDCLK for the OOB detector: pipe_clk / 2, or / 4 at Gen2
  logic [1:0] sigvalidclk_cnt;

  always_ff @(posedge pipe_clk) begin
    if (gtp.rst.gtpll0_reset) begin
      sigvalidclk_cnt <= 2'd0;
      sigvalidclk     <= 1'b0;
    end
    else begin
      sigvalidclk_cnt <= sigvalidclk_cnt + 2'd1;
      sigvalidclk     <= pipe_clk_sel_2 ? sigvalidclk_cnt[1] : sigvalidclk_cnt[0];
    end
  end

  // RX valid only after RXVALID_MAX clean cycles
  logic [3:0] rxvalid_cnt;

  always_ff @(posedge pipe_clk) begin
    if (gtp.rst.rxusrclk_reset) begin
      rxvalid_cnt <= 4'd0;
    end
    else if (rxvalid_2 && (rxvalid_cnt == RXVALID_MAX)) begin
      rxvalid_cnt <= rxvalid_cnt;
    end
    else if (rxvalid_2 && !rxstatus_2) begin
      rxvalid_cnt <= rxvalid_cnt + 4'd1;
    end
    else begin
      rxvalid_cnt <= 4'd0;
    end
  end

  assign gtp.resetdone[LANE] = txresetdone_2 && rxresetdone_2;
  assign active_lane = !(txelecidle_2 && txcompliance_2);
  assign pipe_phy.rx[LANE].valid    = gt_rxvalid && (rxvalid_cnt == RXVALID_MAX) && rst_idle_2 &&
                                        rate_idle_2;
  assign pipe_phy.rx[LANE].phy_status = (!rst_idle_2) || (rate_idle_2 && gt_phystatus) ||
                                        rate_done_2;
  assign gtp.phystatus_rst[LANE] = !rst_idle_2;

  speed_ctrl u_speed_ctrl (
      .clk           (pipe_clk),
      .rst_n         (!gtp.rst.gtpll0_reset),
      .rate          (pipe_phy.tx_ctrl.rate),
      .drp_done      (drp_done),
      .rxpmaresetdone(gt_rxpmaresetdone),
      .txratedone    (gt_txratedone),
      .rxratedone    (gt_rxratedone),
      .phystatus     (gt_phystatus),
      .txsync_done   (sync_txsync_done),

      .rate_ctrl(rate)
  );

  assign sync_tx_stat = '{
          phinitdone: gtp.txphinitdone_all,
          dlysresetdone: gtp.txdlysresetdone_all,
          phaligndone: gtp.txsyncallin
      };

  phase_align u_phase_align (
      .clk        (pipe_clk),
      .rst_n      (!gtp.rst.gtpll0_reset),
      .slave      (LANE > 0),
      .mmcm_lock  (clk_mmcm_lock),
      .active_lane(active_lane),

      .txsync_start(rate.txsync_start || gtp.rst.txsync_start),
      .tx_stat     (sync_tx_stat),
      .tx_ctrl     (sync_tx),
      .txsync_done (sync_txsync_done)
  );

  chan_retune u_chan_retune (
      .clk    (clk125),
      .rst_n  (!gtp.rst.drp_clk_reset),
      .x16    (gtp.rst.drp_x16 || rate.drp_x16),
      .start  (gtp.rst.drp_start || rate.drp_start),
      .drp_req(drp_req),
      .drp_rsp(drp_rsp),
      .done   (drp_done)
  );

  GTPE2_CHANNEL #(
      .SIM_RESET_SPEEDUP       ("FALSE"),
      .SIM_RECEIVER_DETECT_PASS("TRUE"),
      .SIM_TX_EIDLE_DRIVE_LEVEL("1"),
      .SIM_VERSION             ("1.0"),

      .TXOUT_DIV   (2),
      .RXOUT_DIV   (2),
      .TX_CLK25_DIV(4),
      .RX_CLK25_DIV(4),
      .TX_XCLK_SEL ("TXUSR"),
      .RX_XCLK_SEL ("RXREC"),

      .TXPCSRESET_TIME(5'b00001),
      .RXPCSRESET_TIME(5'b00001),
      .TXPMARESET_TIME(5'b00011),
      .RXPMARESET_TIME(5'b00011),

      .TX_DATA_WIDTH(20),

      .RX_DATA_WIDTH(20),

      .TX_RXDETECT_CFG        (14'd100),
      .TX_RXDETECT_REF        (3'b011),
      .RX_CM_SEL              (2'd3),
      .RX_CM_TRIM             (4'b1010),
      .TX_EIDLE_ASSERT_DELAY  (3'd2),
      .TX_EIDLE_DEASSERT_DELAY(3'b010),
      .PD_TRANS_TIME_NONE_P2  (8'h09),

      .TX_DRIVE_MODE    ("PIPE"),
      .TX_DEEMPH0       (5'b10100),
      .TX_DEEMPH1       (5'b01011),
      .TX_MARGIN_FULL_0 (7'b1001111),
      .TX_MARGIN_FULL_1 (7'b1001110),
      .TX_MARGIN_FULL_2 (7'b1001101),
      .TX_MARGIN_FULL_3 (7'b1001100),
      .TX_MARGIN_FULL_4 (7'b1000011),
      .TX_MARGIN_LOW_0  (7'b1000101),
      .TX_MARGIN_LOW_1  (7'b1000110),
      .TX_MARGIN_LOW_2  (7'b1000011),
      .TX_MARGIN_LOW_3  (7'b1000010),
      .TX_MARGIN_LOW_4  (7'b1000000),
      .TX_MAINCURSOR_SEL(1'b0),
      .TX_PREDRIVER_MODE(1'b0),

      .PCS_PCIE_EN  ("TRUE"),
      .PCS_RSVD_ATTR(48'h0000_0000_0100),

      .PMA_RSV2      (32'h00002040),
      .RX_BIAS_CFG   (16'h0F33),
      .TERM_RCAL_CFG (15'b100001000010000),
      .TERM_RCAL_OVRD(3'b000),

      .RXPI_CFG0(3'd0),
      .RXPI_CFG1(1'd1),
      .RXPI_CFG2(1'd1),

      .RXCDR_CFG              (83'h0_0001_07FE_4060_0104_1010),
      .RXCDR_LOCK_CFG         (6'b010101),
      .RXCDR_HOLD_DURING_EIDLE(1'd1),
      .RXCDR_FR_RESET_ON_EIDLE(1'd0),
      .RXCDR_PH_RESET_ON_EIDLE(1'd0),

      .RXLPM_CFG              (4'b0110),
      .RXLPM_GC_CFG           (9'b111100010),
      .RXLPM_GC_CFG2          (3'b001),
      .RXLPM_HF_CFG2          (5'b01010),
      .RXLPM_HOLD_DURING_EIDLE(1'b1),
      .RXLPM_INCM_CFG         (1'b1),
      .RXLPM_IPCM_CFG         (1'b0),
      .RXLPM_LF_CFG2          (5'b01010),
      .RXLPM_OSINT_CFG        (3'b100),

      .RX_OS_CFG           (13'h0080),
      .RXOSCALRESET_TIME   (5'b00011),
      .RXOSCALRESET_TIMEOUT(5'b00000),

      .ES_EYE_SCAN_EN("FALSE"),

      .TXBUF_EN                  ("FALSE"),
      .TXBUF_RESET_ON_RATE_CHANGE("TRUE"),

      // FIXME (openPCIE #27): 1 only gets past nextpnr's "must not be zero" check; Xilinx's
      // default and its PCIE IP use 0. Back to 0 once nextpnr accepts it, see
      // 4.build/hw_build.openXC7/README.md, TXPI_SYNFREQ_PPM forced to non-zero
      .TXPI_SYNFREQ_PPM(3'd1),

      .PMA_RSV           (32'h00000333),
      .PMA_RSV3          (2'b00),
      .TXPI_PPMCLK_SEL   ("TXUSRCLK2"),
      .TXPI_CFG0         (2'b00),
      .TXPI_CFG1         (2'b00),
      .TXPI_CFG2         (2'b00),
      .TXPI_CFG3         (1'b0),
      .TXPI_CFG4         (1'b0),
      .TXPI_CFG5         (3'b000),
      .TXPI_GREY_SEL     (1'b0),
      .TXPI_INVSTROBE_SEL(1'b0),
      .TXPI_PPM_CFG      (8'h00),
      .CLK_COMMON_SWING  (1'b0),

      .TX_CLKMUX_EN         (1'b1),
      .RX_CLKMUX_EN         (1'b1),
      .OUTREFCLK_SEL_INV    (2'b11),
      .PD_TRANS_TIME_FROM_P2(12'h03C),
      .PD_TRANS_TIME_TO_P2  (8'h64),
      .TRANS_TIME_RATE      (8'h0E),
      .RXBUFRESET_TIME      (5'b00001),
      .RXCDRFREQRESET_TIME  (5'b00001),
      .RXCDRPHRESET_TIME    (5'b00001),
      .RXISCANRESET_TIME    (5'b00001),
      .RXLPMRESET_TIME      (7'b0001111),
      .RXLPM_HF_CFG         (14'b00001111110000),
      .RXLPM_LF_CFG         (18'b000000001111110000),
      .RXOOB_CFG            (7'b0000110),
      .SATA_BURST_SEQ_LEN   (4'b1111),
      .SATA_BURST_VAL       (3'b100),
      .SATA_EIDLE_VAL       (3'b100),

      .RXBUF_EN                  ("TRUE"),
      .RX_DEFER_RESET_BUF_EN     ("TRUE"),
      .RXBUF_ADDR_MODE           ("FULL"),
      .RXBUF_EIDLE_HI_CNT        (4'd4),
      .RXBUF_EIDLE_LO_CNT        (4'd0),
      .RXBUF_RESET_ON_CB_CHANGE  ("TRUE"),
      .RXBUF_RESET_ON_COMMAALIGN ("FALSE"),
      .RXBUF_RESET_ON_EIDLE      ("TRUE"),
      .RXBUF_RESET_ON_RATE_CHANGE("TRUE"),
      .RXBUF_THRESH_OVRD         ("FALSE"),
      .RXBUF_THRESH_OVFLW        (61),
      .RXBUF_THRESH_UNDFLW       (4),

      .TXPH_CFG        (16'h0780),
      .TXPH_MONITOR_SEL(5'd0),
      .TXPHDLY_CFG     (24'h084020),
      .TXDLY_CFG       (16'h001F),
      .TXDLY_LCFG      (9'h030),
      .TXDLY_TAP_CFG   (16'd0),

      .TXSYNC_OVRD     (1'd1),
      .TXSYNC_MULTILANE(MULTILANE),
      .TXSYNC_SKIP_DA  (1'b0),

      .RXPH_CFG        (24'd0),
      .RXPH_MONITOR_SEL(5'd0),
      .RXPHDLY_CFG     (24'h004020),
      .RXDLY_CFG       (16'h001F),
      .RXDLY_LCFG      (9'h030),
      .RXDLY_TAP_CFG   (16'd0),
      .RX_DDI_SEL      (6'd0),

      .RXSYNC_OVRD     (1'd1),
      .RXSYNC_MULTILANE(MULTILANE),
      .RXSYNC_SKIP_DA  (1'b0),

      .ALIGN_COMMA_DOUBLE  ("FALSE"),
      .ALIGN_COMMA_ENABLE  (10'b1111111111),
      .ALIGN_COMMA_WORD    (1),
      .ALIGN_MCOMMA_DET    ("TRUE"),
      .ALIGN_MCOMMA_VALUE  (10'b1010000011),
      .ALIGN_PCOMMA_DET    ("TRUE"),
      .ALIGN_PCOMMA_VALUE  (10'b0101111100),
      .DEC_MCOMMA_DETECT   ("TRUE"),
      .DEC_PCOMMA_DETECT   ("TRUE"),
      .DEC_VALID_COMMA_ONLY("FALSE"),
      .SHOW_REALIGN_COMMA  ("FALSE"),
      .RXSLIDE_AUTO_WAIT   (7),
      .RXSLIDE_MODE        ("PMA"),

      .CHAN_BOND_KEEP_ALIGN  ("TRUE"),
      .CHAN_BOND_MAX_SKEW    (7),
      .CHAN_BOND_SEQ_LEN     (4),
      .CHAN_BOND_SEQ_1_ENABLE(4'b1111),
      .CHAN_BOND_SEQ_1_1     (10'b0001001010),
      .CHAN_BOND_SEQ_1_2     (10'b0001001010),
      .CHAN_BOND_SEQ_1_3     (10'b0001001010),
      .CHAN_BOND_SEQ_1_4     (10'b0110111100),
      .CHAN_BOND_SEQ_2_USE   ("TRUE"),
      .CHAN_BOND_SEQ_2_ENABLE(4'b1111),
      .CHAN_BOND_SEQ_2_1     (10'b0001000101),
      .CHAN_BOND_SEQ_2_2     (10'b0001000101),
      .CHAN_BOND_SEQ_2_3     (10'b0001000101),
      .CHAN_BOND_SEQ_2_4     (10'b0110111100),
      .FTS_DESKEW_SEQ_ENABLE (4'b1111),
      .FTS_LANE_DESKEW_EN    ("TRUE"),
      .FTS_LANE_DESKEW_CFG   (4'b1111),

      .CBCC_DATA_SOURCE_SEL("DECODED"),
      .CLK_CORRECT_USE     ("TRUE"),
      .CLK_COR_KEEP_IDLE   ("TRUE"),
      .CLK_COR_MAX_LAT     (CLK_COR_MIN_LAT + 2),
      .CLK_COR_MIN_LAT     (CLK_COR_MIN_LAT),
      .CLK_COR_PRECEDENCE  ("TRUE"),
      .CLK_COR_REPEAT_WAIT (0),
      .CLK_COR_SEQ_LEN     (1),
      .CLK_COR_SEQ_1_ENABLE(4'b1111),
      .CLK_COR_SEQ_1_1     (10'b0100011100),
      .CLK_COR_SEQ_1_2     (10'b0000000000),
      .CLK_COR_SEQ_1_3     (10'b0000000000),
      .CLK_COR_SEQ_1_4     (10'b0000000000),
      .CLK_COR_SEQ_2_ENABLE(4'b0000),
      .CLK_COR_SEQ_2_USE   ("FALSE"),
      .CLK_COR_SEQ_2_1     (10'b0000000000),
      .CLK_COR_SEQ_2_2     (10'b0000000000),
      .CLK_COR_SEQ_2_3     (10'b0000000000),
      .CLK_COR_SEQ_2_4     (10'b0000000000),

      .RX_DISPERR_SEQ_MATCH("TRUE"),

      .GEARBOX_MODE(3'd0),
      .TXGEARBOX_EN("FALSE"),
      .RXGEARBOX_EN("FALSE"),

      .LOOPBACK_CFG         (1'd0),
      .RXPRBS_ERR_LOOPBACK  (1'd0),
      .TX_LOOPBACK_DRIVE_HIZ("FALSE"),

      .TXOOB_CFG    (1'd1),
      .RXOOB_CLK_CFG("FABRIC"),

      .DMONITOR_CFG(24'h000B01),
      .RX_DEBUG_CFG(14'h0000),

      .CFOK_CFG (43'h490_0004_0E80),
      .CFOK_CFG2(7'b010_0000),
      .CFOK_CFG3(7'b010_0000),
      .CFOK_CFG4(1'd0),
      .CFOK_CFG5(2'd0),
      .CFOK_CFG6(4'd0)

  ) u_gtpe2_channel (
      .PLL0CLK    (gtpll0_outclk),
      .PLL1CLK    (1'd0),
      .PLL0REFCLK (gtpll0_outrefclk),
      .PLL1REFCLK (1'd0),
      .TXUSRCLK   (pipe_clk),
      .RXUSRCLK   (pipe_clk),
      .TXUSRCLK2  (pipe_clk),
      .RXUSRCLK2  (pipe_clk),
      .TXSYSCLKSEL(2'd0),
      .RXSYSCLKSEL(2'd0),
      .TXOUTCLKSEL((LANE == 0) ? 3'd3 : 3'd0),
      .RXOUTCLKSEL(3'd0),
      .CLKRSVD0   (1'd0),
      .CLKRSVD1   (1'd0),

      .TXOUTCLK      (gt_txoutclk),
      .RXOUTCLK      (  /*LINT:OK*/),
      .TXOUTCLKFABRIC(  /*LINT:OK*/),
      .RXOUTCLKFABRIC(  /*LINT:OK*/),
      .TXOUTCLKPCS   (  /*LINT:OK*/),
      .RXOUTCLKPCS   (  /*LINT:OK*/),
      .RXCDRLOCK     (  /*LINT:OK*/),  // async (UG482); RX valid comes from RXVALID and RXSTATUS

      .TXUSERRDY (gtp.rst.userrdy),
      .RXUSERRDY (gtp.rst.userrdy),
      .CFGRESET  (1'd0),
      .GTRESETSEL(1'd0),
      .RESETOVRD (1'd0),
      .GTTXRESET (gtp.rst.gtreset),
      .GTRXRESET (gtp.rst.gtreset),

      .TXRESETDONE(gt_txresetdone),  // TXUSRCLK2 = pipe_clk
      .RXRESETDONE(gt_rxresetdone),  // RXUSRCLK2 = pipe_clk

      .TXDATA   (pipe_phy.tx[LANE].data),
      .TXCHARISK(pipe_phy.tx[LANE].char_is_k),

      .GTPTXP(gt_txp),
      .GTPTXN(gt_txn),

      .GTPRXP(gt_rxp),
      .GTPRXN(gt_rxn),

      .RXDATA   (pipe_phy.rx[LANE].data),      // RXUSRCLK2 = pipe_clk
      .RXCHARISK(pipe_phy.rx[LANE].char_is_k), // RXUSRCLK2 = pipe_clk

      .TXDETECTRX      (pipe_phy.tx_ctrl.rcvr_det),
      .TXPDELECIDLEMODE(1'd0),
      .RXELECIDLEMODE  ('0),
      .TXELECIDLE      (pipe_phy.tx[LANE].elec_idle),
      .TXCHARDISPMODE  ({3'd0, pipe_phy.tx[LANE].compliance}),
      .TXCHARDISPVAL   ('0),
      .TXPOLARITY      (1'b0),
      .RXPOLARITY      (pipe_phy.rx_polarity[LANE]),
      .TXPD            (pipe_phy.tx[LANE].powerdown),
      .RXPD            (pipe_phy.tx[LANE].powerdown),
      .TXRATE          (rate.rate),
      .RXRATE          (rate.rate),
      .TXRATEMODE      (1'b0),
      .RXRATEMODE      (1'b0),

      .TXMARGIN       (pipe_phy.tx_ctrl.margin),
      .TXSWING        (1'b0),
      .TXDEEMPH       (pipe_phy.tx_ctrl.deemph),
      .TXINHIBIT      (1'b0),
      .TXBUFDIFFCTRL  (3'b100),
      .TXDIFFCTRL     (4'b1100),
      .TXPRECURSOR    ('0),
      .TXPRECURSORINV (1'd0),
      .TXMAINCURSOR   ('0),
      .TXPOSTCURSOR   ('0),
      .TXPOSTCURSORINV(1'd0),

      .RXVALID   (gt_rxvalid),     // clock domain not listed in the UG482 port tables
      .PHYSTATUS (gt_phystatus),   // RXUSRCLK2 = pipe_clk
      .RXELECIDLE(gt_rxelecidle),  // RXUSRCLK2 = pipe_clk
      .RXSTATUS  (gt_rxstatus),    // RXUSRCLK2 = pipe_clk
      .TXRATEDONE(gt_txratedone),  // TXUSRCLK2 = pipe_clk
      .RXRATEDONE(gt_rxratedone),  // RXUSRCLK2 = pipe_clk

      .DRPCLK (clk125),
      .DRPADDR(drp_req.addr),
      .DRPEN  (drp_req.en),
      .DRPDI  (drp_req.di),
      .DRPWE  (drp_req.we),

      .DRPDO (drp_rsp.dout),  // DRPCLK = clk125
      .DRPRDY(drp_rsp.rdy),   // DRPCLK = clk125

      .TXPMARESET      (1'd0),
      .RXPMARESET      (1'd0),
      .RXLPMRESET      (1'd0),
      .RXLPMOSINTNTRLEN(1'd0),
      .RXLPMHFHOLD     (1'd0),
      .RXLPMHFOVRDEN   (1'd0),
      .RXLPMLFHOLD     (1'd0),
      .RXLPMLFOVRDEN   (1'd0),
      .PMARSVDIN0      (1'd0),
      .PMARSVDIN1      (1'd0),
      .PMARSVDIN2      (1'd0),
      .PMARSVDIN3      (1'd0),
      .PMARSVDIN4      (1'd0),
      .GTRSVD          ('0),

      .PMARSVDOUT0(  /*LINT:OK*/),
      .PMARSVDOUT1(  /*LINT:OK*/),
      .DMONITOROUT(  /*LINT:OK*/),

      .TXPCSRESET(1'd0),
      .RXPCSRESET(1'd0),
      .PCSRSVDIN ('0),

      .PCSRSVDOUT(  /*LINT:OK*/),

      .RXCDRRESET    (1'd0),
      .RXCDRRESETRSV (1'd0),
      .RXCDRFREQRESET(1'd0),
      .RXCDRHOLD     (1'b0),
      .RXCDROVRDEN   (1'd0),

      .TXPIPPMEN      (1'd0),
      .TXPIPPMOVRDEN  (1'd0),
      .TXPIPPMPD      (1'd0),
      .TXPIPPMSEL     (1'd0),
      .TXPIPPMSTEPSIZE('0),
      .TXPISOPD       (1'd0),

      .RXDFEXYDEN(1'd0),

      .RXOSHOLD         (1'd0),
      .RXOSOVRDEN       (1'd0),
      .RXOSINTEN        (1'd1),
      .RXOSINTHOLD      (1'd0),
      .RXOSINTNTRLEN    (1'd0),
      .RXOSINTOVRDEN    (1'd0),
      .RXOSINTPD        (1'd0),
      .RXOSINTSTROBE    (1'd0),
      .RXOSINTTESTOVRDEN(1'd0),
      .RXOSINTCFG       (4'b0010),
      .RXOSINTID0       ('0),

      .RXOSINTDONE         (  /*LINT:OK*/),
      .RXOSINTSTARTED      (  /*LINT:OK*/),
      .RXOSINTSTROBEDONE   (  /*LINT:OK*/),
      .RXOSINTSTROBESTARTED(  /*LINT:OK*/),

      .EYESCANRESET  (1'd0),
      .EYESCANMODE   (1'd0),
      .EYESCANTRIGGER(1'b0),

      .EYESCANDATAERROR(  /*LINT:OK*/),

      .TXBUFSTATUS(  /*LINT:OK*/),

      .RXBUFRESET(1'd0),

      .RXBUFSTATUS(  /*LINT:OK*/),

      // TX buffer bypass: phase_align runs the TXDLYSRESET / TXPHINIT / TXPHALIGN /
      // TXDLYEN sequence; TXPHALIGNEN = 1 selects manual alignment
      .TXPHDLYRESET (1'd0),
      .TXPHDLYTSTCLK(1'd0),
      .TXPHALIGN    (sync_tx.phalign),
      .TXPHALIGNEN  (1'd1),
      .TXPHDLYPD    (1'd0),
      .TXPHINIT     (sync_tx.phinit),
      .TXPHOVRDEN   (1'd0),
      .TXDLYBYPASS  (1'd0),
      .TXDLYSRESET  (sync_tx.dlysreset),
      .TXDLYEN      (sync_tx.dlyen),
      .TXDLYOVRDEN  (1'd0),
      .TXDLYHOLD    (1'd0),
      .TXDLYUPDOWN  (1'd0),

      .TXPHALIGNDONE  (gtp.txphaligndone[LANE]),   // async (UG482)
      .TXPHINITDONE   (gtp.txphinitdone[LANE]),    // async (UG482)
      .TXDLYSRESETDONE(gtp.txdlysresetdone[LANE]), // async (UG482)

      .TXSYNCMODE (LANE == 0),
      .TXSYNCIN   (gtp.txsyncin),
      .TXSYNCALLIN(gtp.txsyncallin),

      .TXSYNCDONE(  /*LINT:OK*/),
      .TXSYNCOUT (gt_txsyncout),   // async (UG482)

      // RX phase alignment is bypassed (RXDLYBYPASS = 1): the RX elastic buffer is used
      .RXPHDLYRESET(1'd0),
      .RXPHALIGN   (1'd0),
      .RXPHALIGNEN (1'd0),
      .RXPHDLYPD   (1'd0),
      .RXPHOVRDEN  (1'd0),
      .RXDLYBYPASS (1'd1),
      .RXDLYSRESET (1'd0),
      .RXDLYEN     (1'd0),
      .RXDLYOVRDEN (1'd0),
      .RXDDIEN     (1'd0),

      .RXPHALIGNDONE  (gtp.rxphaligndone[LANE]),  // async (UG482)
      .RXPHMONITOR    (  /*LINT:OK*/),
      .RXPHSLIPMONITOR(  /*LINT:OK*/),
      .RXDLYSRESETDONE(  /*LINT:OK*/),

      .RXSYNCMODE (LANE == 0),
      .RXSYNCIN   (gtp.rxsyncin),
      .RXSYNCALLIN(gtp.rxsyncallin),

      .RXSYNCDONE(  /*LINT:OK*/),
      .RXSYNCOUT (gt_rxsyncout),   // async (UG482)

      .RXCOMMADETEN   (1'd1),
      .RXMCOMMAALIGNEN(1'd1),
      .RXPCOMMAALIGNEN(1'd1),
      .RXSLIDE        (1'b0),
      .RXCOMMADET     (  /*LINT:OK*/),
      .RXCHARISCOMMA  (  /*LINT:OK*/),
      .RXBYTEISALIGNED(  /*LINT:OK*/),
      .RXBYTEREALIGN  (  /*LINT:OK*/),

      .RXCHBONDEN    (MULTILANE),
      .RXCHBONDI     (gtp.rxchbondi[LANE]),
      .RXCHBONDLEVEL (3'(PCIE_LANES - 1 - LANE)),
      .RXCHBONDMASTER(LANE == 0),
      .RXCHBONDSLAVE (LANE > 0),

      .RXCHANBONDSEQ  (  /*LINT:OK*/),
      .RXCHANISALIGNED(pipe_phy.rx[LANE].chanisaligned),  // RXUSRCLK2 = pipe_clk
      .RXCHANREALIGN  (  /*LINT:OK*/),
      .RXCHBONDO      (gtp.rxchbondo[LANE]),              // RXUSRCLK = pipe_clk

      .RXCLKCORCNT(  /*LINT:OK*/),

      .TX8B10BBYPASS('0),
      .TX8B10BEN    (1'b1),
      .RX8B10BEN    (1'b1),

      .RXDISPERR   (  /*LINT:OK*/),
      .RXNOTINTABLE(  /*LINT:OK*/),

      .TXHEADER     ('0),
      .TXSEQUENCE   ('0),
      .TXSTARTSEQ   (1'd0),
      .RXGEARBOXSLIP(1'd0),

      .TXGEARBOXREADY(  /*LINT:OK*/),
      .RXDATAVALID   (  /*LINT:OK*/),
      .RXHEADER      (  /*LINT:OK*/),
      .RXHEADERVALID (  /*LINT:OK*/),
      .RXSTARTOFSEQ  (  /*LINT:OK*/),

      .TXPRBSSEL     ('0),
      .RXPRBSSEL     ('0),
      .TXPRBSFORCEERR(1'b0),
      .RXPRBSCNTRESET(1'b0),
      .LOOPBACK      ('0),

      .RXPRBSERR(  /*LINT:OK*/),

      .SIGVALIDCLK(sigvalidclk),
      .TXCOMINIT  (1'd0),
      .TXCOMSAS   (1'd0),
      .TXCOMWAKE  (1'd0),
      .RXOOBRESET (1'd0),

      .TXCOMFINISH (  /*LINT:OK*/),
      .RXCOMINITDET(  /*LINT:OK*/),
      .RXCOMSASDET (  /*LINT:OK*/),
      .RXCOMWAKEDET(  /*LINT:OK*/),

      .SETERRSTATUS(1'd0),
      .TXDIFFPD    (1'd0),
      .TSTIN       ('1),

      .RXADAPTSELTEST('0),
      .DMONFIFORESET (1'd0),
      .DMONITORCLK   (1'd0),
      .RXOSCALRESET  (1'd0),

      .RXPMARESETDONE(gt_rxpmaresetdone),  // async (UG482)
      .TXPMARESETDONE(  /*LINT:OK*/)
  );

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
