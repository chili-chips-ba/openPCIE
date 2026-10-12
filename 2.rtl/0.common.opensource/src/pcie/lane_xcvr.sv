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
)(
  input  logic  clk_pclk,          // TXUSRCLK/TXUSRCLK2, PIPE clock
  input  logic  clk_rxusrclk,
  input  logic  clk_dclk,          // DRP clock
  input  logic  clk_oobclk,
  input  logic  clk_mmcm_lock,
  input  logic  pll0_outclk,       // from GTPE2_COMMON
  input  logic  pll0_outrefclk,

  pipe_if.phy   pipe_phy,          // this lane's slice: pipe_phy.tx/rx[LANE]
  gtp_if.lane   gtp,               // to/from gtp_wrapper, slice [LANE]

  output logic  gt_txp,
  output logic  gt_txn,
  input  logic  gt_rxp,
  input  logic  gt_rxn
);

  localparam bit MULTILANE       = (PCIE_LANES > 1);
  // PCIE_LANES <= 4: one GTP quad, channel bonding chain lane 0 -> 1 -> 2 -> 3
  localparam int CLK_COR_MIN_LAT = (PCIE_LANES == 1) ? 13 : (PCIE_LANES == 4) ? 19 : 18;

  // ---- lane_status
  logic user_oobclk, user_rxcdrlock, active_lane;
  // ---- speed_ctrl
  logic       rate_drp_start, rate_drp_x16, rate_pclk_sel, rate_txsync_start, rate_done, rate_idle;
  logic [2:0] rate_rate;
  // ---- phase_align
  logic sync_txphdlyreset, sync_txphalign, sync_txphalignen, sync_txphinit;
  logic sync_txdlybypass, sync_txdlysreset, sync_txdlyen, sync_txsync_done;
  logic sync_rxphalign, sync_rxphalignen, sync_rxdlybypass, sync_rxdlysreset, sync_rxdlyen, sync_rxddien;
  // ---- chan_retune (DRP)
  logic [8:0]  drp_addr;
  logic [15:0] drp_di, drp_do;
  logic        drp_en, drp_we, drp_rdy, drp_done;
  // ---- GTPE2_CHANNEL status
  logic       gt_rxcdrlock, gt_txresetdone, gt_rxresetdone, gt_rxpmaresetdone;
  logic       gt_rxvalid, gt_phystatus, gt_rxelecidle, gt_txratedone, gt_rxratedone;
  logic       gt_txsyncdone, gt_rxsyncdone;
  logic [2:0] gt_rxstatus;

  assign gtp.drp_done[LANE]       = drp_done;
  assign gtp.rate_idle[LANE]      = rate_idle;
  assign gtp.phystatus[LANE]      = gt_phystatus;
  assign gtp.txsync_done[LANE]    = sync_txsync_done;
  assign gtp.active_lane[LANE]    = active_lane;
  assign gtp.pclk_sel[LANE]       = rate_pclk_sel;
  assign gtp.rxpmaresetdone[LANE] = gt_rxpmaresetdone;

  assign pipe_phy.rx[LANE].elec_idle = gt_rxelecidle;
  assign pipe_phy.rx[LANE].status    = gt_rxstatus;

  lane_status u_lane_status (
    .USER_TXUSRCLK        (clk_pclk),
    .USER_RXUSRCLK        (clk_rxusrclk),
    .USER_OOBCLK_IN       (clk_oobclk),
    .USER_RST_N           (!gtp.rst_cpllreset),
    .USER_RXUSRCLK_RST_N  (!gtp.rst_rxusrclk_reset),
    .USER_PCLK_SEL        (rate_pclk_sel),
    .USER_TXRESETDONE     (gt_txresetdone),
    .USER_RXRESETDONE     (gt_rxresetdone),
    .USER_TXELECIDLE      (pipe_phy.tx[LANE].elec_idle),
    .USER_TXCOMPLIANCE    (pipe_phy.tx[LANE].compliance),
    .USER_RXCDRLOCK_IN    (gt_rxcdrlock),
    .USER_RXVALID_IN      (gt_rxvalid),
    .USER_RXSTATUS_IN     (gt_rxstatus[2]),
    .USER_PHYSTATUS_IN    (gt_phystatus),
    .USER_RATE_DONE       (rate_done),
    .USER_RST_IDLE        (gtp.rst_idle),
    .USER_RATE_IDLE       (rate_idle),

    .USER_OOBCLK          (user_oobclk),
    .USER_RESETDONE       (gtp.resetdone[LANE]),
    .USER_ACTIVE_LANE     (active_lane),
    .USER_RXCDRLOCK_OUT   (user_rxcdrlock),
    .USER_RXVALID_OUT     (pipe_phy.rx[LANE].valid),
    .USER_PHYSTATUS_OUT   (pipe_phy.rx[LANE].phy_status),
    .USER_PHYSTATUS_RST   (gtp.phystatus_rst[LANE])
  );

  speed_ctrl u_speed_ctrl (
    .RATE_CLK             (clk_pclk),
    .RATE_RST_N           (!gtp.rst_cpllreset),
    .RATE_RATE_IN         (pipe_phy.tx_ctrl.rate),
    .RATE_DRP_DONE        (drp_done),
    .RATE_RXPMARESETDONE  (gt_rxpmaresetdone),
    .RATE_TXRATEDONE      (gt_txratedone),
    .RATE_RXRATEDONE      (gt_rxratedone),
    .RATE_PHYSTATUS       (gt_phystatus),
    .RATE_TXSYNC_DONE     (sync_txsync_done),

    .RATE_DRP_START       (rate_drp_start),
    .RATE_DRP_X16         (rate_drp_x16),
    .RATE_PCLK_SEL        (rate_pclk_sel),
    .RATE_RATE_OUT        (rate_rate),
    .RATE_TXSYNC_START    (rate_txsync_start),
    .RATE_DONE            (rate_done),
    .RATE_IDLE            (rate_idle)
  );

  phase_align u_phase_align (
    .SYNC_CLK              (clk_pclk),
    .SYNC_RST_N            (!gtp.rst_cpllreset),
    .SYNC_SLAVE            (LANE > 0),
    .SYNC_RATE_IDLE        (rate_idle),
    .SYNC_MMCM_LOCK        (clk_mmcm_lock),
    .SYNC_RXELECIDLE       (gt_rxelecidle),
    .SYNC_RXCDRLOCK        (user_rxcdrlock),
    .SYNC_ACTIVE_LANE      (active_lane),

    .SYNC_TXSYNC_START     (rate_txsync_start || gtp.rst_txsync_start),
    .SYNC_TXPHINITDONE     (gtp.txphinitdone_all),
    .SYNC_TXDLYSRESETDONE  (gtp.txdlysresetdone_all),
    .SYNC_TXPHALIGNDONE    (gtp.txsyncallin),
    .SYNC_TXSYNCDONE       (gt_txsyncdone),

    .SYNC_RXDLYSRESETDONE  (gtp.rxdlysresetdone_all),
    .SYNC_RXPHALIGNDONE_M  (gtp.rxphaligndone_m),
    .SYNC_RXPHALIGNDONE_S  (gtp.rxphaligndone_s),
    .SYNC_RXSYNC_DONEM_IN  (gtp.rxsync_donem_m),
    .SYNC_RXSYNCDONE       (gt_rxsyncdone),

    .SYNC_TXPHDLYRESET     (sync_txphdlyreset),
    .SYNC_TXPHALIGN        (sync_txphalign),
    .SYNC_TXPHALIGNEN      (sync_txphalignen),
    .SYNC_TXPHINIT         (sync_txphinit),
    .SYNC_TXDLYBYPASS      (sync_txdlybypass),
    .SYNC_TXDLYSRESET      (sync_txdlysreset),
    .SYNC_TXDLYEN          (sync_txdlyen),
    .SYNC_TXSYNC_DONE      (sync_txsync_done),

    .SYNC_RXPHALIGN        (sync_rxphalign),
    .SYNC_RXPHALIGNEN      (sync_rxphalignen),
    .SYNC_RXDLYBYPASS      (sync_rxdlybypass),
    .SYNC_RXDLYSRESET      (sync_rxdlysreset),
    .SYNC_RXDLYEN          (sync_rxdlyen),
    .SYNC_RXDDIEN          (sync_rxddien),
    .SYNC_RXSYNC_DONEM_OUT (gtp.rxsync_donem[LANE])
  );

  chan_retune u_chan_retune (
    .DRP_CLK   (clk_dclk),
    .DRP_RST_N (!gtp.rst_dclk_reset),
    .DRP_X16   (gtp.rst_drp_x16 || rate_drp_x16),
    .DRP_START (gtp.rst_drp_start || rate_drp_start),
    .DRP_DO    (drp_do),
    .DRP_RDY   (drp_rdy),

    .DRP_ADDR  (drp_addr),
    .DRP_EN    (drp_en),
    .DRP_DI    (drp_di),
    .DRP_WE    (drp_we),
    .DRP_DONE  (drp_done)
  );

GTPE2_CHANNEL #
(
    .SIM_RESET_SPEEDUP              ("FALSE"),
    .SIM_RECEIVER_DETECT_PASS       ("TRUE"),
    .SIM_TX_EIDLE_DRIVE_LEVEL       ("1"),
    .SIM_VERSION                    ("1.0"),

    .TXOUT_DIV                      (2),
    .RXOUT_DIV                      (2),
    .TX_CLK25_DIV                   (4),
    .RX_CLK25_DIV                   (4),
    .TX_XCLK_SEL                    ("TXUSR"),
    .RX_XCLK_SEL                    ("RXREC"),

    .TXPCSRESET_TIME                ( 5'b00001),
    .RXPCSRESET_TIME                ( 5'b00001),
    .TXPMARESET_TIME                ( 5'b00011),
    .RXPMARESET_TIME                ( 5'b00011),

    .TX_DATA_WIDTH                  (20),

    .RX_DATA_WIDTH                  (20),

    .TX_RXDETECT_CFG                (14'd100),
    .TX_RXDETECT_REF                ( 3'b011),
    .RX_CM_SEL                      ( 2'd3),
    .RX_CM_TRIM	                    ( 4'b1010),
    .TX_EIDLE_ASSERT_DELAY          ( 3'd2),
    .TX_EIDLE_DEASSERT_DELAY        ( 3'b010),
    .PD_TRANS_TIME_NONE_P2          ( 8'h09),

    .TX_DRIVE_MODE                  ("PIPE"),
    .TX_DEEMPH0                     ( 5'b10100),
    .TX_DEEMPH1                     ( 5'b01011),
    .TX_MARGIN_FULL_0               ( 7'b1001111),
    .TX_MARGIN_FULL_1               ( 7'b1001110),
    .TX_MARGIN_FULL_2               ( 7'b1001101),
    .TX_MARGIN_FULL_3               ( 7'b1001100),
    .TX_MARGIN_FULL_4               ( 7'b1000011),
    .TX_MARGIN_LOW_0                ( 7'b1000101),
    .TX_MARGIN_LOW_1                ( 7'b1000110),
    .TX_MARGIN_LOW_2                ( 7'b1000011),
    .TX_MARGIN_LOW_3                ( 7'b1000010),
    .TX_MARGIN_LOW_4                ( 7'b1000000),
    .TX_MAINCURSOR_SEL              ( 1'b0),
    .TX_PREDRIVER_MODE              ( 1'b0),

    .PCS_PCIE_EN                    ("TRUE"),
    .PCS_RSVD_ATTR                  (48'h0000_0000_0100),

    .PMA_RSV2                       (32'h00002040),
    .RX_BIAS_CFG                    (16'h0F33),
    .TERM_RCAL_CFG                  (15'b100001000010000),
    .TERM_RCAL_OVRD                 ( 3'b000),

    .RXPI_CFG0                      ( 3'd0),
    .RXPI_CFG1                      ( 1'd1),
    .RXPI_CFG2                      ( 1'd1),

    .RXCDR_CFG                      (83'h0_0001_07FE_4060_0104_1010),
    .RXCDR_LOCK_CFG                 ( 6'b010101),
    .RXCDR_HOLD_DURING_EIDLE        ( 1'd1),
    .RXCDR_FR_RESET_ON_EIDLE        ( 1'd0),
    .RXCDR_PH_RESET_ON_EIDLE        ( 1'd0),

    .RXLPM_CFG                      ( 4'b0110),
    .RXLPM_GC_CFG                   ( 9'b111100010),
    .RXLPM_GC_CFG2                  ( 3'b001),
    .RXLPM_HF_CFG2                  ( 5'b01010),
    .RXLPM_HOLD_DURING_EIDLE        ( 1'b1),
    .RXLPM_INCM_CFG                 ( 1'b1),
    .RXLPM_IPCM_CFG                 ( 1'b0),
    .RXLPM_LF_CFG2                  ( 5'b01010),
    .RXLPM_OSINT_CFG                ( 3'b100),

    .RX_OS_CFG                      (13'h0080),
    .RXOSCALRESET_TIME              (5'b00011),
    .RXOSCALRESET_TIMEOUT           (5'b00000),

    .ES_EYE_SCAN_EN                 ("FALSE"),

    .TXBUF_EN                       ("FALSE"),
    .TXBUF_RESET_ON_RATE_CHANGE     ("TRUE"),

    // FIXME (openPCIE #27): 1 only gets past nextpnr's "must not be zero" check; Xilinx's
    // default and its PCIE IP use 0. Back to 0 once nextpnr accepts it, see
    // 4.build/hw_build.openXC7/README.md, TXPI_SYNFREQ_PPM forced to non-zero
    .TXPI_SYNFREQ_PPM               ( 3'd1),

    .PMA_RSV                        (32'h00000333),
    .PMA_RSV3                       ( 2'b00),
    .TXPI_PPMCLK_SEL                ("TXUSRCLK2"),
    .TXPI_CFG0                      ( 2'b00),
    .TXPI_CFG1                      ( 2'b00),
    .TXPI_CFG2                      ( 2'b00),
    .TXPI_CFG3                      ( 1'b0),
    .TXPI_CFG4                      ( 1'b0),
    .TXPI_CFG5                      ( 3'b000),
    .TXPI_GREY_SEL                  ( 1'b0),
    .TXPI_INVSTROBE_SEL             ( 1'b0),
    .TXPI_PPM_CFG                   ( 8'h00),
    .CLK_COMMON_SWING               ( 1'b0),

    .TX_CLKMUX_EN                   ( 1'b1),
    .RX_CLKMUX_EN                   ( 1'b1),
    .OUTREFCLK_SEL_INV              ( 2'b11),
    .PD_TRANS_TIME_FROM_P2          (12'h03C),
    .PD_TRANS_TIME_TO_P2            ( 8'h64),
    .TRANS_TIME_RATE                ( 8'h0E),
    .RXBUFRESET_TIME                ( 5'b00001),
    .RXCDRFREQRESET_TIME            ( 5'b00001),
    .RXCDRPHRESET_TIME              ( 5'b00001),
    .RXISCANRESET_TIME              ( 5'b00001),
    .RXLPMRESET_TIME                ( 7'b0001111),
    .RXLPM_HF_CFG                   (14'b00001111110000),
    .RXLPM_LF_CFG                   (18'b000000001111110000),
    .RXOOB_CFG                      ( 7'b0000110),
    .SATA_BURST_SEQ_LEN             ( 4'b1111),
    .SATA_BURST_VAL                 ( 3'b100),
    .SATA_EIDLE_VAL                 ( 3'b100),

    .RXBUF_EN                       ("TRUE"),
    .RX_DEFER_RESET_BUF_EN          ("TRUE"),
    .RXBUF_ADDR_MODE                ("FULL"),
    .RXBUF_EIDLE_HI_CNT	            ( 4'd4),
    .RXBUF_EIDLE_LO_CNT	            ( 4'd0),
    .RXBUF_RESET_ON_CB_CHANGE       ("TRUE"),
    .RXBUF_RESET_ON_COMMAALIGN      ("FALSE"),
    .RXBUF_RESET_ON_EIDLE           ("TRUE"),
    .RXBUF_RESET_ON_RATE_CHANGE     ("TRUE"),
    .RXBUF_THRESH_OVRD              ("FALSE"),
    .RXBUF_THRESH_OVFLW             (61),
    .RXBUF_THRESH_UNDFLW            ( 4),

    .TXPH_CFG                       (16'h0780),
    .TXPH_MONITOR_SEL               ( 5'd0),
    .TXPHDLY_CFG                    (24'h084020),
    .TXDLY_CFG                      (16'h001F),
    .TXDLY_LCFG	                    ( 9'h030),
    .TXDLY_TAP_CFG                  (16'd0),

    .TXSYNC_OVRD                    ( 1'd1),
    .TXSYNC_MULTILANE               (MULTILANE),
    .TXSYNC_SKIP_DA                 (1'b0),

    .RXPH_CFG                       (24'd0),
    .RXPH_MONITOR_SEL               ( 5'd0),
    .RXPHDLY_CFG                    (24'h004020),
    .RXDLY_CFG                      (16'h001F),
    .RXDLY_LCFG	                    ( 9'h030),
    .RXDLY_TAP_CFG                  (16'd0),
    .RX_DDI_SEL	                    ( 6'd0),

    .RXSYNC_OVRD                    ( 1'd1),
    .RXSYNC_MULTILANE               (MULTILANE),
    .RXSYNC_SKIP_DA                 (1'b0),

    .ALIGN_COMMA_DOUBLE             ("FALSE"),
    .ALIGN_COMMA_ENABLE             (10'b1111111111),
    .ALIGN_COMMA_WORD               ( 1),
    .ALIGN_MCOMMA_DET               ("TRUE"),
    .ALIGN_MCOMMA_VALUE             (10'b1010000011),
    .ALIGN_PCOMMA_DET               ("TRUE"),
    .ALIGN_PCOMMA_VALUE             (10'b0101111100),
    .DEC_MCOMMA_DETECT              ("TRUE"),
    .DEC_PCOMMA_DETECT              ("TRUE"),
    .DEC_VALID_COMMA_ONLY           ("FALSE"),
    .SHOW_REALIGN_COMMA             ("FALSE"),
    .RXSLIDE_AUTO_WAIT              ( 7),
    .RXSLIDE_MODE                   ("PMA"),

    .CHAN_BOND_KEEP_ALIGN           ("TRUE"),
    .CHAN_BOND_MAX_SKEW             ( 7),
    .CHAN_BOND_SEQ_LEN              ( 4),
    .CHAN_BOND_SEQ_1_ENABLE         ( 4'b1111),
    .CHAN_BOND_SEQ_1_1              (10'b0001001010),
    .CHAN_BOND_SEQ_1_2              (10'b0001001010),
    .CHAN_BOND_SEQ_1_3              (10'b0001001010),
    .CHAN_BOND_SEQ_1_4              (10'b0110111100),
    .CHAN_BOND_SEQ_2_USE            ("TRUE"),
    .CHAN_BOND_SEQ_2_ENABLE         (4'b1111),
    .CHAN_BOND_SEQ_2_1              (10'b0001000101),
    .CHAN_BOND_SEQ_2_2              (10'b0001000101),
    .CHAN_BOND_SEQ_2_3              (10'b0001000101),
    .CHAN_BOND_SEQ_2_4              (10'b0110111100),
    .FTS_DESKEW_SEQ_ENABLE          ( 4'b1111),
    .FTS_LANE_DESKEW_EN             ("TRUE"),
    .FTS_LANE_DESKEW_CFG            ( 4'b1111),

    .CBCC_DATA_SOURCE_SEL           ("DECODED"),
    .CLK_CORRECT_USE                ("TRUE"),
    .CLK_COR_KEEP_IDLE              ("TRUE"),
    .CLK_COR_MAX_LAT                (CLK_COR_MIN_LAT + 2),
    .CLK_COR_MIN_LAT                (CLK_COR_MIN_LAT),
    .CLK_COR_PRECEDENCE             ("TRUE"),
    .CLK_COR_REPEAT_WAIT            ( 0),
    .CLK_COR_SEQ_LEN                ( 1),
    .CLK_COR_SEQ_1_ENABLE           ( 4'b1111),
    .CLK_COR_SEQ_1_1                (10'b0100011100),
    .CLK_COR_SEQ_1_2                (10'b0000000000),
    .CLK_COR_SEQ_1_3                (10'b0000000000),
    .CLK_COR_SEQ_1_4                (10'b0000000000),
    .CLK_COR_SEQ_2_ENABLE           ( 4'b0000),
    .CLK_COR_SEQ_2_USE              ("FALSE"),
    .CLK_COR_SEQ_2_1                (10'b0000000000),
    .CLK_COR_SEQ_2_2                (10'b0000000000),
    .CLK_COR_SEQ_2_3                (10'b0000000000),
    .CLK_COR_SEQ_2_4                (10'b0000000000),

    .RX_DISPERR_SEQ_MATCH           ("TRUE"),

    .GEARBOX_MODE                   ( 3'd0),
    .TXGEARBOX_EN                   ("FALSE"),
    .RXGEARBOX_EN                   ("FALSE"),

    .LOOPBACK_CFG                    ( 1'd0),
    .RXPRBS_ERR_LOOPBACK             ( 1'd0),
    .TX_LOOPBACK_DRIVE_HIZ           ("FALSE"),

    .TXOOB_CFG                      ( 1'd1),
    .RXOOB_CLK_CFG                  ("FABRIC"),

    .DMONITOR_CFG                   (24'h000B01),
    .RX_DEBUG_CFG                   (14'h0000),

    .CFOK_CFG                       (43'h490_0004_0E80),
    .CFOK_CFG2                      ( 7'b010_0000),
    .CFOK_CFG3                      ( 7'b010_0000),
    .CFOK_CFG4                      ( 1'd0),
    .CFOK_CFG5                      ( 2'd0),
    .CFOK_CFG6                      ( 4'd0)

 )
 u_gtpe2_channel
 (
    .PLL0CLK                        (pll0_outclk),
    .PLL1CLK                        (1'd0),
    .PLL0REFCLK                     (pll0_outrefclk),
    .PLL1REFCLK                     (1'd0),
    .TXUSRCLK                       (clk_pclk),
    .RXUSRCLK                       (clk_rxusrclk),
    .TXUSRCLK2                      (clk_pclk),
    .RXUSRCLK2                      (clk_rxusrclk),
    .TXSYSCLKSEL                    (2'd0),
    .RXSYSCLKSEL                    (2'd0),
    .TXOUTCLKSEL                    ((LANE == 0) ? 3'd3 : 3'd0),
    .RXOUTCLKSEL                    (3'd0),
    .CLKRSVD0                       (1'd0),
    .CLKRSVD1                       (1'd0),

    .TXOUTCLK                       (gtp.txoutclk[LANE]),
    .RXOUTCLK                       (),
    .TXOUTCLKFABRIC                 (),
    .RXOUTCLKFABRIC                 (),
    .TXOUTCLKPCS                    (),
    .RXOUTCLKPCS                    (),
    .RXCDRLOCK                      (gt_rxcdrlock),

    .TXUSERRDY                      (gtp.rst_userrdy),
    .RXUSERRDY                      (gtp.rst_userrdy),
    .CFGRESET                       (1'd0),
    .GTRESETSEL                     (1'd0),
    .RESETOVRD                      ( 1'd0),
    .GTTXRESET                      (gtp.rst_gtreset),
    .GTRXRESET                      (gtp.rst_gtreset),

    .TXRESETDONE                    (gt_txresetdone),
    .RXRESETDONE                    (gt_rxresetdone),

    .TXDATA                         (pipe_phy.tx[LANE].data),
    .TXCHARISK                      (pipe_phy.tx[LANE].char_is_k),

    .GTPTXP                         (gt_txp),
    .GTPTXN                         (gt_txn),

    .GTPRXP                         (gt_rxp),
    .GTPRXN                         (gt_rxn),

    .RXDATA                         (pipe_phy.rx[LANE].data),
    .RXCHARISK                      (pipe_phy.rx[LANE].char_is_k),

    .TXDETECTRX                     (pipe_phy.tx_ctrl.rcvr_det),
    .TXPDELECIDLEMODE               ( 1'd0),
    .RXELECIDLEMODE                 ('0),
    .TXELECIDLE                     (pipe_phy.tx[LANE].elec_idle),
    .TXCHARDISPMODE                 ({3'd0, pipe_phy.tx[LANE].compliance}),
    .TXCHARDISPVAL                  ('0),
    .TXPOLARITY                     ( 1'b0),
    .RXPOLARITY                     (pipe_phy.rx_polarity[LANE]),
    .TXPD                           (pipe_phy.tx[LANE].powerdown),
    .RXPD                           (pipe_phy.tx[LANE].powerdown),
    .TXRATE                         (rate_rate),
    .RXRATE                         (rate_rate),
    .TXRATEMODE                     (1'b0),
    .RXRATEMODE                     (1'b0),

    .TXMARGIN                       (pipe_phy.tx_ctrl.margin),
    .TXSWING                        (1'b0),
    .TXDEEMPH                       (pipe_phy.tx_ctrl.deemph),
    .TXINHIBIT                      (1'b0),
    .TXBUFDIFFCTRL                  (3'b100),
    .TXDIFFCTRL                     (4'b1100),
    .TXPRECURSOR                    ('0),
    .TXPRECURSORINV                 (1'd0),
    .TXMAINCURSOR                   ('0),
    .TXPOSTCURSOR                   ('0),
    .TXPOSTCURSORINV                (1'd0),

    .RXVALID                        (gt_rxvalid),
    .PHYSTATUS                      (gt_phystatus),
    .RXELECIDLE                     (gt_rxelecidle),
    .RXSTATUS                       (gt_rxstatus),
    .TXRATEDONE                     (gt_txratedone),
    .RXRATEDONE                     (gt_rxratedone),

    .DRPCLK                         (clk_dclk),
    .DRPADDR                        (drp_addr),
    .DRPEN                          (drp_en),
    .DRPDI                          (drp_di),
    .DRPWE                          (drp_we),

    .DRPDO                          (drp_do),
    .DRPRDY                         (drp_rdy),

    .TXPMARESET                     ( 1'd0),
    .RXPMARESET                     ( 1'd0),
    .RXLPMRESET                     ( 1'd0),
    .RXLPMOSINTNTRLEN               ( 1'd0),
    .RXLPMHFHOLD                    ( 1'd0),
    .RXLPMHFOVRDEN                  ( 1'd0),
    .RXLPMLFHOLD                    ( 1'd0),
    .RXLPMLFOVRDEN                  ( 1'd0),
    .PMARSVDIN0                     ( 1'd0),
    .PMARSVDIN1                     ( 1'd0),
    .PMARSVDIN2                     ( 1'd0),
    .PMARSVDIN3                     ( 1'd0),
    .PMARSVDIN4                     ( 1'd0),
    .GTRSVD                         ('0),

    .PMARSVDOUT0                    (),
    .PMARSVDOUT1                    (),
    .DMONITOROUT                    (),

    .TXPCSRESET                     ( 1'd0),
    .RXPCSRESET                     ( 1'd0),
    .PCSRSVDIN                      ('0),

    .PCSRSVDOUT                     (),

    .RXCDRRESET                     ( 1'd0),
    .RXCDRRESETRSV                  (1'd0),
    .RXCDRFREQRESET                 ( 1'd0),
    .RXCDRHOLD                      (1'b0),
    .RXCDROVRDEN                    (1'd0),

    .TXPIPPMEN                      (1'd0),
    .TXPIPPMOVRDEN                  (1'd0),
    .TXPIPPMPD                      (1'd0),
    .TXPIPPMSEL                     (1'd0),
    .TXPIPPMSTEPSIZE                ('0),
    .TXPISOPD                       (1'd0),

    .RXDFEXYDEN                     (1'd0),

    .RXOSHOLD                       (1'd0),
    .RXOSOVRDEN                     (1'd0),
    .RXOSINTEN                      (1'd1),
    .RXOSINTHOLD                    (1'd0),
    .RXOSINTNTRLEN                  (1'd0),
    .RXOSINTOVRDEN                  (1'd0),
    .RXOSINTPD                      (1'd0),
    .RXOSINTSTROBE                  (1'd0),
    .RXOSINTTESTOVRDEN              (1'd0),
    .RXOSINTCFG                     (4'b0010),
    .RXOSINTID0                     ('0),

    .RXOSINTDONE                    (),
    .RXOSINTSTARTED                 (),
    .RXOSINTSTROBEDONE              (),
    .RXOSINTSTROBESTARTED           (),

    .EYESCANRESET                   ( 1'd0),
    .EYESCANMODE                    (1'd0),
    .EYESCANTRIGGER                 (1'b0),

    .EYESCANDATAERROR               (),

    .TXBUFSTATUS                    (),

    .RXBUFRESET                     ( 1'd0),

    .RXBUFSTATUS                    (),

    .TXPHDLYRESET                   (sync_txphdlyreset),
    .TXPHDLYTSTCLK                  (1'd0),
    .TXPHALIGN                      (sync_txphalign),
    .TXPHALIGNEN                    (sync_txphalignen),
    .TXPHDLYPD                      (1'd0),
    .TXPHINIT                       (sync_txphinit),
    .TXPHOVRDEN                     (1'd0),
    .TXDLYBYPASS                    (sync_txdlybypass),
    .TXDLYSRESET                    (sync_txdlysreset),
    .TXDLYEN                        (sync_txdlyen),
    .TXDLYOVRDEN                    (1'd0),
    .TXDLYHOLD                      (1'd0),
    .TXDLYUPDOWN                    (1'd0),

    .TXPHALIGNDONE                  (gtp.txphaligndone[LANE]),
    .TXPHINITDONE                   (gtp.txphinitdone[LANE]),
    .TXDLYSRESETDONE                (gtp.txdlysresetdone[LANE]),

    .TXSYNCMODE                     (LANE == 0),
    .TXSYNCIN                       (gtp.txsyncin),
    .TXSYNCALLIN                    (gtp.txsyncallin),

    .TXSYNCDONE                     (gt_txsyncdone),
    .TXSYNCOUT                      (gtp.txsyncout[LANE]),

    .RXPHDLYRESET                   (1'd0),
    .RXPHALIGN                      (sync_rxphalign),
    .RXPHALIGNEN                    (sync_rxphalignen),
    .RXPHDLYPD                      (1'd0),
    .RXPHOVRDEN                     (1'd0),
    .RXDLYBYPASS                    (sync_rxdlybypass),
    .RXDLYSRESET                    (sync_rxdlysreset),
    .RXDLYEN                        (sync_rxdlyen),
    .RXDLYOVRDEN                    (1'd0),
    .RXDDIEN                        (sync_rxddien),

    .RXPHALIGNDONE                  (gtp.rxphaligndone[LANE]),
    .RXPHMONITOR                    (),
    .RXPHSLIPMONITOR                (),
    .RXDLYSRESETDONE                (gtp.rxdlysresetdone[LANE]),

    .RXSYNCMODE                     (LANE == 0),
    .RXSYNCIN                       (gtp.rxsyncin),
    .RXSYNCALLIN                    (gtp.rxsyncallin),

    .RXSYNCDONE                     (gt_rxsyncdone),
    .RXSYNCOUT                      (gtp.rxsyncout[LANE]),

    .RXCOMMADETEN                   (1'd1),
    .RXMCOMMAALIGNEN                (1'd1),
    .RXPCOMMAALIGNEN                (1'd1),
    .RXSLIDE                        (1'b0),
    .RXCOMMADET                     (),
    .RXCHARISCOMMA                  (),
    .RXBYTEISALIGNED                (),
    .RXBYTEREALIGN                  (),

    .RXCHBONDEN                     (MULTILANE),
    .RXCHBONDI                      (gtp.rxchbondi[LANE]),
    .RXCHBONDLEVEL                  (3'(PCIE_LANES - 1 - LANE)),
    .RXCHBONDMASTER                 (LANE == 0),
    .RXCHBONDSLAVE                  (LANE > 0),

    .RXCHANBONDSEQ                  (),
    .RXCHANISALIGNED                (pipe_phy.rx[LANE].chanisaligned),
    .RXCHANREALIGN                  (),
    .RXCHBONDO                      (gtp.rxchbondo[LANE]),

    .RXCLKCORCNT                    (),

    .TX8B10BBYPASS                  ('0),
    .TX8B10BEN                      (1'b1),
    .RX8B10BEN                      (1'b1),

    .RXDISPERR                      (),
    .RXNOTINTABLE                   (),

    .TXHEADER                       ('0),
    .TXSEQUENCE                     ('0),
    .TXSTARTSEQ                     (1'd0),
    .RXGEARBOXSLIP                  (1'd0),

    .TXGEARBOXREADY                 (),
    .RXDATAVALID                    (),
    .RXHEADER                       (),
    .RXHEADERVALID                  (),
    .RXSTARTOFSEQ                   (),

    .TXPRBSSEL                      ('0),
    .RXPRBSSEL                      ('0),
    .TXPRBSFORCEERR                 (1'b0),
    .RXPRBSCNTRESET                 (1'b0),
    .LOOPBACK                       ('0),

    .RXPRBSERR                      (),

    .SIGVALIDCLK                    (user_oobclk),
    .TXCOMINIT                      (1'd0),
    .TXCOMSAS                       (1'd0),
    .TXCOMWAKE                      (1'd0),
    .RXOOBRESET                     (1'd0),

    .TXCOMFINISH                    (),
    .RXCOMINITDET                   (),
    .RXCOMSASDET                    (),
    .RXCOMWAKEDET                   (),

    .SETERRSTATUS                   ( 1'd0),
    .TXDIFFPD                       ( 1'd0),
    .TSTIN                          ('1),

    .RXADAPTSELTEST                 ('0),
    .DMONFIFORESET                  ( 1'd0),
    .DMONITORCLK                    (1'd0),
    .RXOSCALRESET                   ( 1'd0),

    .RXPMARESETDONE                 (gt_rxpmaresetdone),
    .TXPMARESETDONE                 ()
 );

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
