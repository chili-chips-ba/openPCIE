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

module lane_xcvr
  import link_pkg::*;
#
(
    localparam PCIE_GT_DEVICE = "GTP",
    localparam PCIE_USE_MODE = "1.0",
    localparam PCIE_PLL_SEL = "CPLL",
    localparam PCIE_LPM_DFE = "LPM",
    localparam PCIE_LPM_DFE_GEN3 = "DFE",
    localparam PCIE_ASYNC_EN = "FALSE",
    localparam PCIE_TXBUF_EN = "FALSE",
    localparam PCIE_TXSYNC_MODE = 0,
    localparam PCIE_RXSYNC_MODE = 0,
    localparam PCIE_CHAN_BOND = 1,
    localparam PCIE_CHAN_BOND_EN = "TRUE",
    localparam PCIE_REFCLK_FREQ = 0,
    localparam PCIE_TX_EIDLE_ASSERT_DELAY = 3'd2,
    localparam PCIE_OOBCLK_MODE = 1,
    localparam TX_MARGIN_FULL_0 = 7'b1001111,
    localparam TX_MARGIN_FULL_1 = 7'b1001110,
    localparam TX_MARGIN_FULL_2 = 7'b1001101,
    localparam TX_MARGIN_FULL_3 = 7'b1001100,
    localparam TX_MARGIN_FULL_4 = 7'b1000011,
    localparam TX_MARGIN_LOW_0 = 7'b1000101,
    localparam TX_MARGIN_LOW_1 = 7'b1000110,
    localparam TX_MARGIN_LOW_2 = 7'b1000011,
    localparam TX_MARGIN_LOW_3 = 7'b1000010,
    localparam TX_MARGIN_LOW_4 = 7'b1000000,
    localparam PCIE_DEBUG_MODE = 0)

(    
    input               GT_MASTER,
    input               GT_GEN3, 
    input               GT_RX_CONVERGE,
    
    input               GT_GTREFCLK0,
    input               GT_QPLLCLK,
    input               GT_QPLLREFCLK,
    input               GT_TXUSRCLK,
    input               GT_RXUSRCLK,
    input               GT_TXUSRCLK2,
    input               GT_RXUSRCLK2, 
    input               GT_OOBCLK,
    input       [ 1:0]  GT_TXSYSCLKSEL,
    input       [ 1:0]  GT_RXSYSCLKSEL,                
    input               GT_CPLLPDREFCLK,                   
    output              GT_TXOUTCLK,
    output              GT_RXOUTCLK,
    output              GT_CPLLLOCK,
    output              GT_RXCDRLOCK,
    
    input               GT_CPLLPD,
    input               GT_CPLLRESET,
    input               GT_TXUSERRDY,
    input               GT_RXUSERRDY,
    input               GT_RESETOVRD,
    input               GT_GTTXRESET,
    input               GT_GTRXRESET,
    input               GT_TXPMARESET,
    input               GT_RXPMARESET,
    input               GT_RXCDRRESET,
    input               GT_RXCDRFREQRESET,
    input               GT_RXDFELPMRESET,
    input               GT_EYESCANRESET,
    input               GT_TXPCSRESET,
    input               GT_RXPCSRESET,
    input               GT_RXBUFRESET,
    
    output              GT_EYESCANDATAERROR,
    output              GT_TXRESETDONE,
    output              GT_RXRESETDONE,
    output              GT_RXPMARESETDONE,
    
    input       [31:0]  GT_TXDATA,
    input       [ 3:0]  GT_TXDATAK,
    
    output              GT_TXP,
    output              GT_TXN,
    
    input               GT_RXN,
    input               GT_RXP,
    
    output      [31:0]  GT_RXDATA,
    output      [ 3:0]  GT_RXDATAK,
    
    input               GT_TXDETECTRX,
    input               GT_TXELECIDLE,
    input               GT_TXCOMPLIANCE,
    input               GT_RXPOLARITY,
    input       [ 1:0]  GT_TXPOWERDOWN,
    input       [ 1:0]  GT_RXPOWERDOWN,
    input       [ 2:0]  GT_TXRATE,
    input       [ 2:0]  GT_RXRATE,
      
    input       [ 2:0]  GT_TXMARGIN,
    input               GT_TXSWING,
    input               GT_TXDEEMPH,
    input               GT_TXINHIBIT,
    input       [ 4:0]  GT_TXPRECURSOR,
    input       [ 6:0]  GT_TXMAINCURSOR,
    input       [ 4:0]  GT_TXPOSTCURSOR,
       
    output              GT_RXVALID,
    output              GT_PHYSTATUS,
    output              GT_RXELECIDLE,
    output      [ 2:0]  GT_RXSTATUS,
    output      [ 2:0]  GT_RXBUFSTATUS,
    output              GT_TXRATEDONE,
    output              GT_RXRATEDONE,

    output      [7:0]   GT_RXDISPERR,  
    output      [7:0]   GT_RXNOTINTABLE,

    input               GT_DRPCLK,
    input       [ 8:0]  GT_DRPADDR,
    input               GT_DRPEN,
    input       [15:0]  GT_DRPDI,
    input               GT_DRPWE,
    
    output      [15:0]  GT_DRPDO,
    output              GT_DRPRDY,
    
    input               GT_TXPHALIGN,     
    input               GT_TXPHALIGNEN,  
    input               GT_TXPHINIT, 
    input               GT_TXDLYBYPASS,
    input               GT_TXDLYSRESET,
    input               GT_TXDLYEN,       
    
    output              GT_TXDLYSRESETDONE,
    output              GT_TXPHINITDONE,  
    output              GT_TXPHALIGNDONE,
    
    input               GT_TXPHDLYRESET,
    input               GT_TXSYNCMODE,
    input               GT_TXSYNCIN,
    input               GT_TXSYNCALLIN,
        
    output              GT_TXSYNCOUT,
    output              GT_TXSYNCDONE,
                                                                            
    input               GT_RXPHALIGN,
    input               GT_RXPHALIGNEN,
    input               GT_RXDLYBYPASS,
    input               GT_RXDLYSRESET,
    input               GT_RXDLYEN,
    input               GT_RXDDIEN,
    
    output              GT_RXDLYSRESETDONE,
    output              GT_RXPHALIGNDONE,    
    
    input               GT_RXSYNCMODE,
    input               GT_RXSYNCIN,
    input               GT_RXSYNCALLIN,
    
    output              GT_RXSYNCOUT,
    output              GT_RXSYNCDONE,
    
    input               GT_RXSLIDE,
    
    output              GT_RXCOMMADET,                        
    output      [ 3:0]  GT_RXCHARISCOMMA,                      
    output              GT_RXBYTEISALIGNED,                   
    output              GT_RXBYTEREALIGN,                     
    
    input               GT_RXCHBONDEN,
    input       [ 4:0]  GT_RXCHBONDI,
    input       [ 2:0]  GT_RXCHBONDLEVEL,
    input               GT_RXCHBONDMASTER,
    input               GT_RXCHBONDSLAVE,
    
    output              GT_RXCHANISALIGNED,
    output      [ 4:0]  GT_RXCHBONDO,
    
    input       [ 2:0]  GT_TXPRBSSEL,
    input       [ 2:0]  GT_RXPRBSSEL,
    input               GT_TXPRBSFORCEERR,
    input               GT_RXPRBSCNTRESET,
    input       [ 2:0]  GT_LOOPBACK,
    
    output              GT_RXPRBSERR,
    
    output      [14:0]  GT_DMONITOROUT

);

    wire        [ 2:0]  txoutclksel;
    wire        [ 2:0]  rxoutclksel;
    wire        [63:0]  rxdata;
    wire        [ 7:0]  rxdatak;
    wire        [ 7:0]  rxchariscomma;
    wire rxlpmen;
    wire        [14:0]  dmonitorout;
    wire                dmonitorclk;

    wire cpllpd;
    wire cpllrst;

    localparam          OUT_DIV         = (PCIE_PLL_SEL == "QPLL") ? 4 : 2;
    localparam          CLK25_DIV       = (PCIE_REFCLK_FREQ == 2) ? 10 : 
                                          (PCIE_REFCLK_FREQ == 1) ?  5 : 4;
    
    localparam          TX_XCLK_SEL = (PCIE_TXBUF_EN == "TRUE") ? "TXOUT" : "TXUSR";
                                                   
    localparam          TX_RXDETECT_CFG = (PCIE_REFCLK_FREQ == 2) ? 14'd250 : 
                                          (PCIE_REFCLK_FREQ == 1) ? 14'd125 : 14'd100;
    localparam          TX_RXDETECT_REF = ((PCIE_USE_MODE == "1.0") || (PCIE_USE_MODE == "1.1")) ? 3'b000 : 3'b011;
                                                      
    localparam          OOBCLK_SEL    = (PCIE_OOBCLK_MODE == 0) ? 1'd0  : 1'd1;
    localparam          RXOOB_CLK_CFG = (PCIE_OOBCLK_MODE == 0) ? "PMA" : "FABRIC";
    
    localparam          PCS_RSVD_ATTR = ((PCIE_USE_MODE == "1.0")                           && (PCIE_TXBUF_EN == "FALSE")) ? {44'h0000000001C, OOBCLK_SEL, 3'd1} :
                                        ((PCIE_USE_MODE == "1.0")                           && (PCIE_TXBUF_EN == "TRUE" )) ? {44'h0000000001C, OOBCLK_SEL, 3'd0} : 
                                        ((PCIE_RXSYNC_MODE == 0) && (PCIE_TXSYNC_MODE == 0) && (PCIE_TXBUF_EN == "FALSE")) ? {44'h0000000001C, OOBCLK_SEL, 3'd7} : 
                                        ((PCIE_RXSYNC_MODE == 0) && (PCIE_TXSYNC_MODE == 0) && (PCIE_TXBUF_EN == "TRUE" )) ? {44'h0000000001C, OOBCLK_SEL, 3'd6} :   
                                        ((PCIE_RXSYNC_MODE == 0) && (PCIE_TXSYNC_MODE == 1) && (PCIE_TXBUF_EN == "FALSE")) ? {44'h0000000001C, OOBCLK_SEL, 3'd5} : 
                                        ((PCIE_RXSYNC_MODE == 0) && (PCIE_TXSYNC_MODE == 1) && (PCIE_TXBUF_EN == "TRUE" )) ? {44'h0000000001C, OOBCLK_SEL, 3'd4} : 
                                        ((PCIE_RXSYNC_MODE == 1) && (PCIE_TXSYNC_MODE == 0) && (PCIE_TXBUF_EN == "FALSE")) ? {44'h0000000001C, OOBCLK_SEL, 3'd3} : 
                                        ((PCIE_RXSYNC_MODE == 1) && (PCIE_TXSYNC_MODE == 0) && (PCIE_TXBUF_EN == "TRUE" )) ? {44'h0000000001C, OOBCLK_SEL, 3'd2} : 
                                        ((PCIE_RXSYNC_MODE == 1) && (PCIE_TXSYNC_MODE == 1) && (PCIE_TXBUF_EN == "FALSE")) ? {44'h0000000001C, OOBCLK_SEL, 3'd1} : 
                                        ((PCIE_RXSYNC_MODE == 1) && (PCIE_TXSYNC_MODE == 1) && (PCIE_TXBUF_EN == "TRUE" )) ? {44'h0000000001C, OOBCLK_SEL, 3'd0} : {44'h0000000001C, OOBCLK_SEL, 3'd7};                                      
                             
    
    
    localparam          RXCDR_CFG_GTP =((PCIE_ASYNC_EN == "TRUE") ? 83'h0_0001_07FE_4060_2104_1010
                                                                   : 83'h0_0001_07FE_4060_0104_1010);
                   
                         
                                                                                           
                            
    localparam          TXSYNC_OVRD      = (PCIE_TXSYNC_MODE == 1) ? 1'd0 : 1'd1;                             
    localparam          RXSYNC_OVRD      = (PCIE_TXSYNC_MODE == 1) ? 1'd0 : 1'd1;     
                                                                          
    localparam          TXSYNC_MULTILANE = (PCIE_LANES == 1) ? 1'd0 : 1'd1;  
    localparam          RXSYNC_MULTILANE = (PCIE_LANES == 1) ? 1'd0 : 1'd1;                                             
                                       
   
    
    localparam          CLK_COR_MIN_LAT = ((PCIE_LANES == 8) && (PCIE_CHAN_BOND != 0) && (PCIE_CHAN_BOND_EN == "TRUE"))  ? ((PCIE_CHAN_BOND == 1) ? 27 : 21) : 
                                          ((PCIE_LANES == 7) && (PCIE_CHAN_BOND != 0) && (PCIE_CHAN_BOND_EN == "TRUE"))  ? ((PCIE_CHAN_BOND == 1) ? 25 : 19) : 
                                          ((PCIE_LANES == 6) && (PCIE_CHAN_BOND != 0) && (PCIE_CHAN_BOND_EN == "TRUE"))  ? ((PCIE_CHAN_BOND == 1) ? 23 : 19) : 
                                          ((PCIE_LANES == 5) && (PCIE_CHAN_BOND != 0) && (PCIE_CHAN_BOND_EN == "TRUE"))  ? ((PCIE_CHAN_BOND == 1) ? 21 : 18) : 
                                          ((PCIE_LANES == 4) && (PCIE_CHAN_BOND != 0) && (PCIE_CHAN_BOND_EN == "TRUE"))  ? ((PCIE_CHAN_BOND == 1) ? 19 : 18) :
                                          ((PCIE_LANES == 3) && (PCIE_CHAN_BOND != 0) && (PCIE_CHAN_BOND_EN == "TRUE"))  ? ((PCIE_CHAN_BOND == 1) ? 18 : 18) :
                                          ((PCIE_LANES == 2) && (PCIE_CHAN_BOND != 0) && (PCIE_CHAN_BOND_EN == "TRUE"))  ? ((PCIE_CHAN_BOND == 1) ? 18 : 18) :
                                          ((PCIE_LANES == 1)                          || (PCIE_CHAN_BOND_EN == "FALSE")) ? 13 : 18; 
                                           
    localparam          CLK_COR_MAX_LAT = CLK_COR_MIN_LAT + 2;                                                     
    

    assign txoutclksel = GT_MASTER ? 3'd3 : 3'd0;
    assign rxoutclksel = ((PCIE_DEBUG_MODE == 1) || ((PCIE_ASYNC_EN == "TRUE") && GT_MASTER)) ? 3'd2 : 3'd0;
 
    assign rxlpmen = GT_GEN3 ? ((PCIE_LPM_DFE_GEN3 == "LPM") ? 1'd1 : 1'd0) : ((PCIE_LPM_DFE == "LPM") ? 1'd1 : 1'd0);
    

 
generate if (PCIE_DEBUG_MODE == 1)
 
    begin : dmonitorclk_i
    BUFG dmonitorclk_i
    (
        .I                              (dmonitorout[7]),   
        .O                              (dmonitorclk)
    ); 
    end
    
else

    begin : dmonitorclk_i_disable
    assign dmonitorclk = 1'd0;
    end
    
endgenerate

   
wake_timer wake_timer_i (
   .i_ibufds_gte2(GT_CPLLPDREFCLK),
   .o_cpllpd_ovrd(cpllpd),
   .o_cpllreset_ovrd(cpllrst));
 
generate if (PCIE_GT_DEVICE == "GTP") 

    begin : hm_chan

    GTPE2_CHANNEL #
    (
                
        .SIM_RESET_SPEEDUP              ("FALSE"),
        .SIM_RECEIVER_DETECT_PASS       ("TRUE"),
        .SIM_TX_EIDLE_DRIVE_LEVEL       ("1"),
        .SIM_VERSION                    (PCIE_USE_MODE),
                                                                                 
        .TXOUT_DIV                      (OUT_DIV),
        .RXOUT_DIV                      (OUT_DIV),
        .TX_CLK25_DIV                   (CLK25_DIV),
        .RX_CLK25_DIV                   (CLK25_DIV),
        .TX_XCLK_SEL                    (TX_XCLK_SEL),
        .RX_XCLK_SEL                    ("RXREC"),
                                                                                 
        .TXPCSRESET_TIME                ( 5'b00001),
        .RXPCSRESET_TIME                ( 5'b00001),
        .TXPMARESET_TIME                ( 5'b00011),
        .RXPMARESET_TIME                ( 5'b00011),
                                                                                 
        .TX_DATA_WIDTH                  (20),
        
        .RX_DATA_WIDTH                  (20),
        
        .TX_RXDETECT_CFG                (TX_RXDETECT_CFG),
        .TX_RXDETECT_REF                ( 3'b011),
        .RX_CM_SEL                      ( 2'd3),
        .RX_CM_TRIM	                    ( 4'b1010),
        .TX_EIDLE_ASSERT_DELAY          (PCIE_TX_EIDLE_ASSERT_DELAY),
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
                                             
        .RXCDR_CFG                      (RXCDR_CFG_GTP),
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
                                                                                 
        .TXBUF_EN                       (PCIE_TXBUF_EN),
        .TXBUF_RESET_ON_RATE_CHANGE     ("TRUE"),
                                                                                 
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
                 
        .TXSYNC_OVRD                    (TXSYNC_OVRD),
        .TXSYNC_MULTILANE               (TXSYNC_MULTILANE),
        .TXSYNC_SKIP_DA                 (1'b0),
                                                                                 
        .RXPH_CFG                       (24'd0),
        .RXPH_MONITOR_SEL               ( 5'd0),
        .RXPHDLY_CFG                    (24'h004020),
        .RXDLY_CFG                      (16'h001F),
        .RXDLY_LCFG	                    ( 9'h030),
        .RXDLY_TAP_CFG                  (16'd0),
        .RX_DDI_SEL	                    ( 6'd0),
            
        .RXSYNC_OVRD                    (RXSYNC_OVRD),
        .RXSYNC_MULTILANE               (RXSYNC_MULTILANE),
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
        .CLK_COR_MAX_LAT                (CLK_COR_MAX_LAT),
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
        .RXOOB_CLK_CFG                  (RXOOB_CLK_CFG),
                                                                                 
        .DMONITOR_CFG                   (24'h000B01),
        .RX_DEBUG_CFG                   (14'h0000),
      
        .CFOK_CFG                       (43'h490_0004_0E80),
        .CFOK_CFG2                      ( 7'b010_0000),
        .CFOK_CFG3                      ( 7'b010_0000),
        .CFOK_CFG4                      ( 1'd0),
        .CFOK_CFG5                      ( 2'd0),
        .CFOK_CFG6                      ( 4'd0)
      
     )                                                                        
     gtpe2_channel_i                                                                     
     (                                                                           
                                                                                 
        .PLL0CLK                        (GT_QPLLCLK),
        .PLL1CLK                        (1'd0),
        .PLL0REFCLK                     (GT_QPLLREFCLK),
        .PLL1REFCLK                     (1'd0),
        .TXUSRCLK                       (GT_TXUSRCLK),
        .RXUSRCLK                       (GT_RXUSRCLK),
        .TXUSRCLK2                      (GT_TXUSRCLK2),
        .RXUSRCLK2                      (GT_RXUSRCLK2),
        .TXSYSCLKSEL                    (GT_TXSYSCLKSEL),
        .RXSYSCLKSEL                    (GT_RXSYSCLKSEL),
        .TXOUTCLKSEL                    (txoutclksel),
        .RXOUTCLKSEL                    (rxoutclksel),
        .CLKRSVD0                       (1'd0),
        .CLKRSVD1                       (1'd0),
                                                                                
        .TXOUTCLK                       (GT_TXOUTCLK),
        .RXOUTCLK                       (GT_RXOUTCLK),
        .TXOUTCLKFABRIC                 (),
        .RXOUTCLKFABRIC                 (),
        .TXOUTCLKPCS                    (),
        .RXOUTCLKPCS                    (),
        .RXCDRLOCK                      (GT_RXCDRLOCK),
                                                                                
        .TXUSERRDY                      (GT_TXUSERRDY),
        .RXUSERRDY                      (GT_RXUSERRDY),
        .CFGRESET                       (1'd0),
        .GTRESETSEL                     (1'd0),
        .RESETOVRD                      (GT_RESETOVRD),
        .GTTXRESET                      (GT_GTTXRESET),
        .GTRXRESET                      (GT_GTRXRESET),
                                                                               
        .TXRESETDONE                    (GT_TXRESETDONE),
        .RXRESETDONE                    (GT_RXRESETDONE),
                                                                                
        .TXDATA                         (GT_TXDATA),
        .TXCHARISK                      (GT_TXDATAK),
                                                                                
        .GTPTXP                         (GT_TXP),
        .GTPTXN                         (GT_TXN),
                                                                                
        .GTPRXP                         (GT_RXP),
        .GTPRXN                         (GT_RXN),
                                                                              
        .RXDATA                         (rxdata[31:0]),
        .RXCHARISK                      (rxdatak[3:0]),
                                                                                
        .TXDETECTRX                     (GT_TXDETECTRX),
        .TXPDELECIDLEMODE               ( 1'd0),
        .RXELECIDLEMODE                 ( 2'd0),
        .TXELECIDLE                     (GT_TXELECIDLE),
        .TXCHARDISPMODE                 ({3'd0, GT_TXCOMPLIANCE}),
        .TXCHARDISPVAL                  ( 4'd0),
        .TXPOLARITY                     ( 1'b0),
        .RXPOLARITY                     (GT_RXPOLARITY),
        .TXPD                           (GT_TXPOWERDOWN),
        .RXPD                           (GT_RXPOWERDOWN),
        .TXRATE                         (GT_TXRATE),
        .RXRATE                         (GT_RXRATE),
        .TXRATEMODE                     (1'b0),
        .RXRATEMODE                     (1'b0),
                                                                                
        .TXMARGIN                       (GT_TXMARGIN),
        .TXSWING                        (GT_TXSWING),
        .TXDEEMPH                       (GT_TXDEEMPH),
        .TXINHIBIT                      (GT_TXINHIBIT),
        .TXBUFDIFFCTRL                  (3'b100),
        .TXDIFFCTRL                     (4'b1100),
        .TXPRECURSOR                    (GT_TXPRECURSOR),
        .TXPRECURSORINV                 (1'd0),
        .TXMAINCURSOR                   (GT_TXMAINCURSOR),
        .TXPOSTCURSOR                   (GT_TXPOSTCURSOR),
        .TXPOSTCURSORINV                (1'd0),
                                                                                
        .RXVALID                        (GT_RXVALID),
        .PHYSTATUS                      (GT_PHYSTATUS),
        .RXELECIDLE                     (GT_RXELECIDLE),
        .RXSTATUS                       (GT_RXSTATUS),
        .TXRATEDONE                     (GT_TXRATEDONE),
        .RXRATEDONE                     (GT_RXRATEDONE),
                                                                                
        .DRPCLK                         (GT_DRPCLK),
        .DRPADDR                        (GT_DRPADDR),
        .DRPEN                          (GT_DRPEN),
        .DRPDI                          (GT_DRPDI),
        .DRPWE                          (GT_DRPWE),
                                                                                
        .DRPDO                          (GT_DRPDO),
        .DRPRDY                         (GT_DRPRDY),
                                                                                
        .TXPMARESET                     (GT_TXPMARESET),
        .RXPMARESET                     (GT_RXPMARESET),
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
        .GTRSVD                         (16'd0),
              
        .PMARSVDOUT0                    (),
        .PMARSVDOUT1                    (),
        .DMONITOROUT                    (dmonitorout),
                                                                              
        .TXPCSRESET                     (GT_TXPCSRESET),
        .RXPCSRESET                     (GT_RXPCSRESET),
        .PCSRSVDIN                      (16'd0),
        
        .PCSRSVDOUT                     (),
        
        .RXCDRRESET                     (GT_RXCDRRESET),
        .RXCDRRESETRSV                  (1'd0),
        .RXCDRFREQRESET                 (GT_RXCDRFREQRESET),
        .RXCDRHOLD                      (1'b0),
        .RXCDROVRDEN                    (1'd0),
         
        .TXPIPPMEN                      (1'd0),
        .TXPIPPMOVRDEN                  (1'd0),
        .TXPIPPMPD                      (1'd0),
        .TXPIPPMSEL                     (1'd0),
        .TXPIPPMSTEPSIZE                (5'd0),
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
        .RXOSINTID0                     (4'd0),
                                  
        .RXOSINTDONE                    (),
        .RXOSINTSTARTED                 (),
        .RXOSINTSTROBEDONE              (),
        .RXOSINTSTROBESTARTED           (),
                                                                                
        .EYESCANRESET                   (GT_EYESCANRESET),
        .EYESCANMODE                    (1'd0),
        .EYESCANTRIGGER                 (1'b0),
                                                                                
        .EYESCANDATAERROR               (GT_EYESCANDATAERROR),
                                                                                
        .TXBUFSTATUS                    (),
                                                                                
        .RXBUFRESET                     (GT_RXBUFRESET),
        
        .RXBUFSTATUS                    (GT_RXBUFSTATUS),
                                                                                
        .TXPHDLYRESET                   (GT_TXPHDLYRESET),
        .TXPHDLYTSTCLK                  (1'd0),
        .TXPHALIGN                      (GT_TXPHALIGN),
        .TXPHALIGNEN                    (GT_TXPHALIGNEN),
        .TXPHDLYPD                      (1'd0),
        .TXPHINIT                       (GT_TXPHINIT),
        .TXPHOVRDEN                     (1'd0),
        .TXDLYBYPASS                    (GT_TXDLYBYPASS),
        .TXDLYSRESET                    (GT_TXDLYSRESET),
        .TXDLYEN                        (GT_TXDLYEN),
        .TXDLYOVRDEN                    (1'd0),
        .TXDLYHOLD                      (1'd0),
        .TXDLYUPDOWN                    (1'd0),
                                                                                
        .TXPHALIGNDONE                  (GT_TXPHALIGNDONE),
        .TXPHINITDONE                   (GT_TXPHINITDONE),
        .TXDLYSRESETDONE                (GT_TXDLYSRESETDONE),
        
        .TXSYNCMODE                     (GT_TXSYNCMODE),
        .TXSYNCIN                       (GT_TXSYNCIN),
        .TXSYNCALLIN                    (GT_TXSYNCALLIN),
        
        .TXSYNCDONE                     (GT_TXSYNCDONE),
        .TXSYNCOUT                      (GT_TXSYNCOUT),
        
        .RXPHDLYRESET                   (1'd0),
        .RXPHALIGN                      (GT_RXPHALIGN),
        .RXPHALIGNEN                    (GT_RXPHALIGNEN),
        .RXPHDLYPD                      (1'd0),
        .RXPHOVRDEN                     (1'd0),
        .RXDLYBYPASS                    (GT_RXDLYBYPASS),
        .RXDLYSRESET                    (GT_RXDLYSRESET),
        .RXDLYEN                        (GT_RXDLYEN),
        .RXDLYOVRDEN                    (1'd0),
        .RXDDIEN                        (GT_RXDDIEN),
                                                                                
        .RXPHALIGNDONE                  (GT_RXPHALIGNDONE),
        .RXPHMONITOR                    (),
        .RXPHSLIPMONITOR                (),
        .RXDLYSRESETDONE                (GT_RXDLYSRESETDONE),

        .RXSYNCMODE                     (GT_RXSYNCMODE),
        .RXSYNCIN                       (GT_RXSYNCIN),
        .RXSYNCALLIN                    (GT_RXSYNCALLIN),
        
        .RXSYNCDONE                     (GT_RXSYNCDONE),
        .RXSYNCOUT                      (GT_RXSYNCOUT),
                
        .RXCOMMADETEN                   (1'd1),
        .RXMCOMMAALIGNEN                (1'd1),
        .RXPCOMMAALIGNEN                (1'd1),
        .RXSLIDE                        (GT_RXSLIDE),
        .RXCOMMADET                     (GT_RXCOMMADET),
        .RXCHARISCOMMA                  (rxchariscomma[3:0]),
        .RXBYTEISALIGNED                (GT_RXBYTEISALIGNED),
        .RXBYTEREALIGN                  (GT_RXBYTEREALIGN),
                                                                                
        .RXCHBONDEN                     (GT_RXCHBONDEN),
        .RXCHBONDI                      (GT_RXCHBONDI[3:0]),
        .RXCHBONDLEVEL                  (GT_RXCHBONDLEVEL),
        .RXCHBONDMASTER                 (GT_RXCHBONDMASTER),
        .RXCHBONDSLAVE                  (GT_RXCHBONDSLAVE),
                                                                                
        .RXCHANBONDSEQ                  (),
        .RXCHANISALIGNED                (GT_RXCHANISALIGNED),
        .RXCHANREALIGN                  (),
        .RXCHBONDO                      (GT_RXCHBONDO[3:0]),
                                                                                
        .RXCLKCORCNT                    (),
                                                                                
        .TX8B10BBYPASS                  (4'd0),
        .TX8B10BEN                      (1'b1),
        .RX8B10BEN                      (1'b1),
                                                                                
        .RXDISPERR                      (GT_RXDISPERR[3:0]),
        .RXNOTINTABLE                   (GT_RXNOTINTABLE[3:0]),
                                                                                
        .TXHEADER                       (3'd0),
        .TXSEQUENCE                     (7'd0),
        .TXSTARTSEQ                     (1'd0),
        .RXGEARBOXSLIP                  (1'd0),
                                                                                
        .TXGEARBOXREADY                 (),
        .RXDATAVALID                    (),
        .RXHEADER                       (),
        .RXHEADERVALID                  (),
        .RXSTARTOFSEQ                   (),
                                                                                
        .TXPRBSSEL                      (GT_TXPRBSSEL),
        .RXPRBSSEL                      (GT_RXPRBSSEL),
        .TXPRBSFORCEERR                 (GT_TXPRBSFORCEERR),
        .RXPRBSCNTRESET                 (GT_RXPRBSCNTRESET),
        .LOOPBACK                       (GT_LOOPBACK),
                                                                                
        .RXPRBSERR                      (GT_RXPRBSERR),
                                                                                
        .SIGVALIDCLK                    (GT_OOBCLK),
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
        .TSTIN                          (20'hFFFFF),
                 
        .RXADAPTSELTEST                 (14'd0),
        .DMONFIFORESET                  ( 1'd0),
        .DMONITORCLK                    (dmonitorclk),
        .RXOSCALRESET                   ( 1'd0),
                             
        .RXPMARESETDONE                 (GT_RXPMARESETDONE),
        .TXPMARESETDONE                 ()
        
     );         
     
     assign GT_CPLLLOCK = 1'b0;

    end

endgenerate
    
assign GT_RXDATA        = rxdata [31:0];
assign GT_RXDATAK       = rxdatak[ 3:0];
assign GT_RXCHARISCOMMA = rxchariscomma[ 3:0];
assign GT_DMONITOROUT   = dmonitorout;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
