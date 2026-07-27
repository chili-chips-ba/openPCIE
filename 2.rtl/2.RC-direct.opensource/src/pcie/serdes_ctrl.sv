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

module serdes_ctrl
  import link_pkg::*;
#
(
    localparam EXT_CH_GT_DRP                 = "FALSE",

    localparam PCIE_TXSYNC_MODE              = 0,
    localparam PCIE_RXSYNC_MODE              = 0,
    localparam PCIE_CHAN_BOND                = 1,
    localparam PCIE_CHAN_BOND_EN             = "TRUE",
    localparam PCIE_OOBCLK_MODE              = 1,
    localparam PCIE_DEBUG_MODE               = 0

)
(
    input                           PIPE_CLK,
    input                           PIPE_RESET_N,
   
    output                          PIPE_PCLK,
    input       [(PCIE_LANES*32)-1:0]PIPE_TXDATA,
    input       [(PCIE_LANES*4)-1:0] PIPE_TXDATAK,
    
    output      [PCIE_LANES-1:0]    PIPE_TXP,
    output      [PCIE_LANES-1:0]    PIPE_TXN,

    input       [PCIE_LANES-1:0]    PIPE_RXP,
    input       [PCIE_LANES-1:0]    PIPE_RXN,
    
    output      [(PCIE_LANES*32)-1:0]PIPE_RXDATA,
    output      [(PCIE_LANES*4)-1:0] PIPE_RXDATAK,
    
    input                           PIPE_TXDETECTRX,
    input       [PCIE_LANES-1:0]    PIPE_TXELECIDLE,
    input       [PCIE_LANES-1:0]    PIPE_TXCOMPLIANCE,
    input       [PCIE_LANES-1:0]    PIPE_RXPOLARITY,
    input       [(PCIE_LANES*2)-1:0] PIPE_POWERDOWN,
    input       [ 1:0]              PIPE_RATE,
    
    input       [ 2:0]              PIPE_TXMARGIN,
    input                           PIPE_TXSWING,
    input       [PCIE_LANES-1:0]    PIPE_TXDEEMPH,
    input       [(PCIE_LANES*2)-1:0] PIPE_TXEQ_CONTROL,
    input       [(PCIE_LANES*4)-1:0] PIPE_TXEQ_PRESET,
    input       [(PCIE_LANES*4)-1:0] PIPE_TXEQ_PRESET_DEFAULT,
    input       [(PCIE_LANES*6)-1:0] PIPE_TXEQ_DEEMPH,
                                                                            
    input       [(PCIE_LANES*2)-1:0] PIPE_RXEQ_CONTROL,
    input       [(PCIE_LANES*3)-1:0] PIPE_RXEQ_PRESET,
    input       [(PCIE_LANES*6)-1:0] PIPE_RXEQ_LFFS,
    input       [(PCIE_LANES*4)-1:0] PIPE_RXEQ_TXPRESET,
    input       [PCIE_LANES-1:0]    PIPE_RXEQ_USER_EN,
    input       [(PCIE_LANES*18)-1:0]PIPE_RXEQ_USER_TXCOEFF,
    input       [PCIE_LANES-1:0]    PIPE_RXEQ_USER_MODE,
                                                                           
    output      [ 5:0]              PIPE_TXEQ_FS,
    output      [ 5:0]              PIPE_TXEQ_LF,
    output      [(PCIE_LANES*18)-1:0]PIPE_TXEQ_COEFF,
    output      [PCIE_LANES-1:0]    PIPE_TXEQ_DONE,
                                                                           
    output      [(PCIE_LANES*18)-1:0]PIPE_RXEQ_NEW_TXCOEFF,
    output      [PCIE_LANES-1:0]    PIPE_RXEQ_LFFS_SEL,
    output      [PCIE_LANES-1:0]    PIPE_RXEQ_ADAPT_DONE,
    output      [PCIE_LANES-1:0]    PIPE_RXEQ_DONE,
    
    output      [PCIE_LANES-1:0]    PIPE_RXVALID,
    output      [PCIE_LANES-1:0]    PIPE_PHYSTATUS,
    output      [PCIE_LANES-1:0]    PIPE_PHYSTATUS_RST,
    output      [PCIE_LANES-1:0]    PIPE_RXELECIDLE,
    output      [PCIE_LANES-1:0]    PIPE_EYESCANDATAERROR,
    output      [(PCIE_LANES*3)-1:0] PIPE_RXSTATUS,
    output      [PCIE_LANES-1:0]    PIPE_RXPMARESETDONE,
    output      [(PCIE_LANES*3)-1:0] PIPE_RXBUFSTATUS,
    output      [PCIE_LANES-1:0]    PIPE_TXPHALIGNDONE,
    output      [PCIE_LANES-1:0]    PIPE_TXPHINITDONE,
    output      [PCIE_LANES-1:0]    PIPE_TXDLYSRESETDONE,
    output      [PCIE_LANES-1:0]    PIPE_RXPHALIGNDONE,
    output      [PCIE_LANES-1:0]    PIPE_RXDLYSRESETDONE,
    output      [PCIE_LANES-1:0]    PIPE_RXSYNCDONE,
    output      [(PCIE_LANES*8)-1:0] PIPE_RXDISPERR,
    output      [(PCIE_LANES*8)-1:0] PIPE_RXNOTINTABLE,
    output      [PCIE_LANES-1:0]    PIPE_RXCOMMADET,
    
    input                           PIPE_MMCM_RST_N,
    input       [PCIE_LANES-1:0]    PIPE_RXSLIDE,
    
    output      [PCIE_LANES-1:0]    PIPE_CPLL_LOCK,
    output      [(PCIE_LANES-1)>>2:0]PIPE_QPLL_LOCK,
    output                          PIPE_PCLK_LOCK,
    output      [PCIE_LANES-1:0]    PIPE_RXCDRLOCK,
    output                          PIPE_USERCLK1,
    output                          PIPE_USERCLK2,
    output                          PIPE_RXUSRCLK,
    output      [PCIE_LANES-1:0]    PIPE_RXOUTCLK,
    output      [PCIE_LANES-1:0]    PIPE_TXSYNC_DONE,
    output      [PCIE_LANES-1:0]    PIPE_RXSYNC_DONE,
    output      [PCIE_LANES-1:0]    PIPE_GEN3_RDY,
    output      [PCIE_LANES-1:0]    PIPE_RXCHANISALIGNED,
    output      [PCIE_LANES-1:0]    PIPE_ACTIVE_LANE,

    output                          INT_PCLK_OUT_SLAVE,
    output                          INT_RXUSRCLK_OUT,
    output  [PCIE_LANES-1:0  ]       INT_RXOUTCLK_OUT,
    output                          INT_DCLK_OUT,
    output                          INT_USERCLK1_OUT,
    output                          INT_USERCLK2_OUT,
    output                          INT_OOBCLK_OUT,
    output                          INT_MMCM_LOCK_OUT,
    output  [1:0]                   INT_QPLLLOCK_OUT,
    output  [1:0]                   INT_QPLLOUTCLK_OUT,
    output  [1:0]                   INT_QPLLOUTREFCLK_OUT,
    input   [PCIE_LANES-1:0]        INT_PCLK_SEL_SLAVE,

 
    
    input                           PIPE_PCLK_IN,
    input                           PIPE_RXUSRCLK_IN,
    input       [PCIE_LANES-1:0]    PIPE_RXOUTCLK_IN,
    input                           PIPE_DCLK_IN,
    input                           PIPE_USERCLK1_IN,
    input                           PIPE_USERCLK2_IN,
    input                           PIPE_OOBCLK_IN,
    input                           PIPE_MMCM_LOCK_IN,
    
    output                          PIPE_TXOUTCLK_OUT,
    output      [PCIE_LANES-1:0]    PIPE_RXOUTCLK_OUT,
    output      [PCIE_LANES-1:0]    PIPE_PCLK_SEL_OUT,
    output                          PIPE_GEN3_OUT,
    input       [11:0]              QPLL_DRP_CRSCODE,
    input       [17:0]              QPLL_DRP_FSM,
    input       [1:0]               QPLL_DRP_DONE,
    input       [1:0]               QPLL_DRP_RESET,
    input       [1:0]               QPLL_QPLLLOCK,
    input       [1:0]               QPLL_QPLLOUTCLK,
    input       [1:0]               QPLL_QPLLOUTREFCLK,
    output              	          QPLL_QPLLPD,
    output      [1:0]               QPLL_QPLLRESET,
    output              	          QPLL_DRP_CLK,
    output              	          QPLL_DRP_RST_N,
    output              	          QPLL_DRP_OVRD,
    output              	          QPLL_DRP_GEN3,
    output              	          QPLL_DRP_START,

    input       [ 2:0]              PIPE_TXPRBSSEL,
    input       [ 2:0]              PIPE_RXPRBSSEL,
    input                           PIPE_TXPRBSFORCEERR,
    input                           PIPE_RXPRBSCNTRESET,
    input       [ 2:0]              PIPE_LOOPBACK,
    
    output      [PCIE_LANES-1:0]    PIPE_RXPRBSERR,
    input       [PCIE_LANES-1:0]    PIPE_TXINHIBIT,
    
    output      [4:0]               PIPE_RST_FSM,
    output      [11:0]              PIPE_QRST_FSM,
    output      [(PCIE_LANES*5)-1:0] PIPE_RATE_FSM,
    output      [(PCIE_LANES*6)-1:0] PIPE_SYNC_FSM_TX,
    output      [(PCIE_LANES*7)-1:0] PIPE_SYNC_FSM_RX,
    output      [(PCIE_LANES*7)-1:0] PIPE_DRP_FSM,
    output      [(PCIE_LANES*6)-1:0] PIPE_TXEQ_FSM,
    output      [(PCIE_LANES*6)-1:0] PIPE_RXEQ_FSM,
    output      [((((PCIE_LANES-1)>>2)+1)*9)-1:0]PIPE_QDRP_FSM,
        
    output                          PIPE_RST_IDLE,
    output                          PIPE_QRST_IDLE,
    output                          PIPE_RATE_IDLE,
    
    output                            EXT_CH_GT_DRPCLK,
    input        [(PCIE_LANES*9)-1:0] EXT_CH_GT_DRPADDR,
    input        [PCIE_LANES-1:0]    EXT_CH_GT_DRPEN,
    input        [(PCIE_LANES*16)-1:0]EXT_CH_GT_DRPDI,
    input        [PCIE_LANES-1:0]    EXT_CH_GT_DRPWE,

    output       [(PCIE_LANES*16)-1:0]EXT_CH_GT_DRPDO,
    output       [PCIE_LANES-1:0]    EXT_CH_GT_DRPRDY,

    input                           PIPE_JTAG_EN,
    output      [PCIE_LANES-1:0]    PIPE_JTAG_RDY,
    
    output      [PCIE_LANES-1:0]    PIPE_DEBUG_0,
    output      [PCIE_LANES-1:0]    PIPE_DEBUG_1,
    output      [PCIE_LANES-1:0]    PIPE_DEBUG_2,
    output      [PCIE_LANES-1:0]    PIPE_DEBUG_3,
    output      [PCIE_LANES-1:0]    PIPE_DEBUG_4,
    output      [PCIE_LANES-1:0]    PIPE_DEBUG_5,
    output      [PCIE_LANES-1:0]    PIPE_DEBUG_6,
    output      [PCIE_LANES-1:0]    PIPE_DEBUG_7,
    output      [PCIE_LANES-1:0]    PIPE_DEBUG_8,
    output      [PCIE_LANES-1:0]    PIPE_DEBUG_9,
    output      [31:0]              PIPE_DEBUG,
    
    output      [(PCIE_LANES*15)-1:0] PIPE_DMONITOROUT
    
);

(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *)    logic                             reset_n_reg1;
(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *)    logic                             reset_n_reg2;

    wire                            clk_pclk;  
    wire                            clk_rxusrclk;
    wire        [PCIE_LANES-1:0]    clk_rxoutclk;
    wire                            clk_dclk;
    wire                            clk_oobclk;
    wire                            clk_mmcm_lock;
    
    wire                            rst_cpllreset;
    wire                            rst_cpllpd;
    wire                            rst_rxusrclk_reset;
    wire                            rst_dclk_reset;   
    wire rst_gtreset;
    wire                            rst_drp_start;
    wire                            rst_drp_x16x20_mode;
    wire                            rst_drp_x16;
    wire rst_userrdy;
    wire                            rst_txsync_start;
    wire                            rst_idle;
    wire        [4:0]               rst_fsm;
    
    wire                            gtp_rst_qpllreset;
    wire                            gtp_rst_qpllpd;
    
    wire        [(PCIE_LANES-1)>>2:0]qpllreset;          
    wire                            qpllpd;
    
    wire                            qrst_ovrd;
    wire                            qrst_drp_start;
    wire                            qrst_qpllreset;
    wire                            qrst_qpllpd;
    wire                            qrst_idle;
    wire        [3:0]               qrst_fsm;
    
    wire        [(PCIE_LANES*37)-1:0] jtag_sl_iport;
    wire        [(PCIE_LANES*17)-1:0] jtag_sl_oport;
    
    wire [PCIE_LANES-1:0] gt_txpmareset_i;                 
    wire [PCIE_LANES-1:0] gt_rxpmareset_i;                 

    wire        [PCIE_LANES-1:0]    user_oobclk;
    wire        [PCIE_LANES-1:0]    user_resetovrd;
    wire        [PCIE_LANES-1:0]    user_txpmareset;                 
    wire        [PCIE_LANES-1:0]    user_rxpmareset;                
    wire        [PCIE_LANES-1:0]    user_rxcdrreset;
    wire        [PCIE_LANES-1:0]    user_rxcdrfreqreset;
    wire [PCIE_LANES-1:0] user_rxdfelpmreset;
    wire [PCIE_LANES-1:0] user_eyescanreset;
    wire [PCIE_LANES-1:0] user_txpcsreset;                   
    wire [PCIE_LANES-1:0] user_rxpcsreset;                 
    wire [PCIE_LANES-1:0] user_rxbufreset;
    wire        [PCIE_LANES-1:0]    user_resetovrd_done;
    wire        [PCIE_LANES-1:0]    user_active_lane;
    wire        [PCIE_LANES-1:0]    user_resetdone ;
    wire        [PCIE_LANES-1:0]    user_rxcdrlock;
    wire        [PCIE_LANES-1:0]    user_rx_converge; 
    wire        [PCIE_LANES-1:0]    PIPE_RXEQ_CONVERGE; 
    
    wire        [PCIE_LANES-1:0]    rate_cpllpd;
    wire        [PCIE_LANES-1:0]    rate_qpllpd;
    wire        [PCIE_LANES-1:0]    rate_cpllreset;
    wire        [PCIE_LANES-1:0]    rate_qpllreset;
    wire        [PCIE_LANES-1:0]    rate_txpmareset;
    wire        [PCIE_LANES-1:0]    rate_rxpmareset;
    wire        [(PCIE_LANES*2)-1:0] rate_sysclksel;
    wire        [PCIE_LANES-1:0]    rate_pclk_sel;
    wire        [PCIE_LANES-1:0]    rate_drp_start;
    wire        [PCIE_LANES-1:0]    rate_drp_x16x20_mode;
    wire        [PCIE_LANES-1:0]    rate_drp_x16;
    wire        [PCIE_LANES-1:0]    rate_gen3;
    wire        [(PCIE_LANES*3)-1:0] rate_rate;
    wire        [PCIE_LANES-1:0]    rate_resetovrd_start;
    wire        [PCIE_LANES-1:0]    rate_txsync_start;
    wire        [PCIE_LANES-1:0]    rate_done;
    wire        [PCIE_LANES-1:0]    rate_rxsync_start;
    wire        [PCIE_LANES-1:0]    rate_rxsync;
    wire        [PCIE_LANES-1:0]    rate_idle;
    wire        [(PCIE_LANES*5)-1:0] rate_fsm;

    wire        [PCIE_LANES-1:0]    sync_txphdlyreset;
    wire        [PCIE_LANES-1:0]    sync_txphalign;    
    wire        [PCIE_LANES-1:0]    sync_txphalignen; 
    wire        [PCIE_LANES-1:0]    sync_txphinit;   
    wire        [PCIE_LANES-1:0]    sync_txdlybypass; 
    wire        [PCIE_LANES-1:0]    sync_txdlysreset;   
    wire        [PCIE_LANES-1:0]    sync_txdlyen;      
    wire        [PCIE_LANES-1:0]    sync_txsync_done;
    wire        [(PCIE_LANES*6)-1:0] sync_fsm_tx;
    
    wire        [PCIE_LANES-1:0]    sync_rxphalign;
    wire        [PCIE_LANES-1:0]    sync_rxphalignen;
    wire        [PCIE_LANES-1:0]    sync_rxdlybypass;
    wire        [PCIE_LANES-1:0]    sync_rxdlysreset;
    wire        [PCIE_LANES-1:0]    sync_rxdlyen;
    wire        [PCIE_LANES-1:0]    sync_rxddien;
    wire        [PCIE_LANES-1:0]    sync_rxsync_done; 
    wire        [PCIE_LANES-1:0]    sync_rxsync_donem;      
    wire        [(PCIE_LANES*7)-1:0] sync_fsm_rx;
 
    wire        [PCIE_LANES-1:0]    txdlysresetdone;
    wire        [PCIE_LANES-1:0]    txphaligndone;
    wire        [PCIE_LANES-1:0]    rxdlysresetdone;
    wire        [PCIE_LANES-1:0]    rxphaligndone_s;    
    
    wire                            txsyncallin;
    wire                            rxsyncallin;
    
    wire        [(PCIE_LANES*9)-1:0] drp_addr;
    wire        [PCIE_LANES-1:0]    drp_en;
    wire        [(PCIE_LANES*16)-1:0]drp_di;   
    wire        [PCIE_LANES-1:0]    drp_we;
    wire        [PCIE_LANES-1:0]    drp_done;
    wire        [(PCIE_LANES*3)-1:0] drp_fsm;

    wire	      [(PCIE_LANES*17)-1:0]jtag_sl_addr;
    wire        [PCIE_LANES-1:0]    jtag_sl_den;
    wire        [PCIE_LANES-1:0]    jtag_sl_en;
    wire        [(PCIE_LANES*16)-1:0]jtag_sl_di;
    wire        [PCIE_LANES-1:0]    jtag_sl_we;
    
    wire	      [(PCIE_LANES*9)-1:0] drp_mux_addr;
    wire        [PCIE_LANES-1:0]    drp_mux_en;
    wire        [(PCIE_LANES*16)-1:0]drp_mux_di;
    wire        [PCIE_LANES-1:0]    drp_mux_we;

    wire        [PCIE_LANES-1:0]    eq_txeq_deemph;
    wire [(PCIE_LANES*5)-1:0] eq_txeq_precursor;
    wire        [(PCIE_LANES*7)-1:0] eq_txeq_maincursor;
    wire [(PCIE_LANES*5)-1:0] eq_txeq_postcursor;
    
    wire        [PCIE_LANES-1:0]    eq_rxeq_adapt_done;
    
    wire        [((((PCIE_LANES-1)>>2)+1)*8)-1:0]  qdrp_addr;
    wire        [(PCIE_LANES-1)>>2:0]             qdrp_en;
    wire        [((((PCIE_LANES-1)>>2)+1)*16)-1:0] qdrp_di;   
    wire        [(PCIE_LANES-1)>>2:0]             qdrp_we;
    wire        [(PCIE_LANES-1)>>2:0]             qdrp_done;
    wire        [(PCIE_LANES-1)>>2:0]             qdrp_qpllreset;
    wire        [((((PCIE_LANES-1)>>2)+1)*6)-1:0]  qdrp_crscode;
    wire        [((((PCIE_LANES-1)>>2)+1)*9)-1:0]  qdrp_fsm;

    wire        [(PCIE_LANES-1)>>2:0]             qpll_qplloutclk;
    wire        [(PCIE_LANES-1)>>2:0]             qpll_qplloutrefclk;
    wire        [(PCIE_LANES-1)>>2:0]             qpll_qplllock;
    wire        [((((PCIE_LANES-1)>>2)+1)*16)-1:0] qpll_do;
    wire        [(PCIE_LANES-1)>>2:0]             qpll_rdy;

    wire        [PCIE_LANES-1:0]    gt_txoutclk;
    wire        [PCIE_LANES-1:0]    gt_rxoutclk;
    wire        [PCIE_LANES-1:0] gt_cplllock;
    wire        [PCIE_LANES-1:0]    gt_rxcdrlock;
    wire        [PCIE_LANES-1:0]    gt_txresetdone;
    wire        [PCIE_LANES-1:0]    gt_rxresetdone;
    wire        [PCIE_LANES-1:0]    gt_eyescandataerror;
    wire        [PCIE_LANES-1:0] gt_rxpmaresetdone;
    wire        [(PCIE_LANES*8)-1:0]     gt_rxdisperr;
    wire        [(PCIE_LANES*8)-1:0]     gt_rxnotintable;
    wire        [PCIE_LANES-1:0]    gt_rxvalid;
    wire        [PCIE_LANES-1:0]    gt_phystatus;
    wire        [(PCIE_LANES*3)-1:0] gt_rxstatus;
    wire        [(PCIE_LANES*3)-1:0] gt_rxbufstatus;
    wire        [PCIE_LANES-1:0]    gt_rxelecidle;
    wire        [PCIE_LANES-1:0]    gt_rxelecidle_i;
    logic         [PCIE_LANES-1:0]    gt_rxrcvrdet_c;
    wire        [PCIE_LANES-1:0]    gt_txratedone;
    wire        [PCIE_LANES-1:0]    gt_rxratedone;
    wire        [(PCIE_LANES*16)-1:0]gt_do;
    wire        [PCIE_LANES-1:0]    gt_rdy;
    wire        [PCIE_LANES-1:0] gt_txphinitdone;  
    wire        [PCIE_LANES-1:0] gt_txdlysresetdone;
    wire        [PCIE_LANES-1:0] gt_txphaligndone;
    wire        [PCIE_LANES-1:0] gt_rxdlysresetdone;
    wire        [PCIE_LANES:0] gt_rxphaligndone;
    wire        [PCIE_LANES-1:0]    gt_txsyncout;
    wire        [PCIE_LANES-1:0]    gt_txsyncdone;
    wire        [PCIE_LANES-1:0]    gt_rxsyncout;
    wire        [PCIE_LANES-1:0] gt_rxsyncdone;
    wire        [PCIE_LANES-1:0] gt_rxcommadet;                        
    wire        [(PCIE_LANES*4)-1:0] gt_rxchariscomma;                      
    wire        [PCIE_LANES-1:0]    gt_rxbyteisaligned;                   
    wire        [PCIE_LANES-1:0]    gt_rxbyterealign; 
    wire        [ 4:0]              gt_rxchbondi [PCIE_LANES:0]; 
    wire        [(PCIE_LANES*3)-1:0] gt_rxchbondlevel;
    wire        [ 4:0]              gt_rxchbondo [PCIE_LANES:0];  
   
    wire        [PCIE_LANES-1:0]    rxchbonden;
    wire        [PCIE_LANES-1:0]    rxchbondmaster;
    wire        [PCIE_LANES-1:0]    rxchbondslave;    
    wire        [PCIE_LANES-1:0]    oobclk; 



    genvar                          i;
    
    
    
assign gt_rxchbondo[0]             = 5'd0;
assign gt_rxphaligndone[PCIE_LANES] = 1'd1;
assign txsyncallin                 = &(gt_txphaligndone | (~user_active_lane));     
assign rxsyncallin                 = &(gt_rxphaligndone | (~user_active_lane));  

always_ff @(posedge clk_pclk or negedge PIPE_RESET_N)
begin

    if (!PIPE_RESET_N) 
        begin
        reset_n_reg1 <= 1'd0;
        reset_n_reg2 <= 1'd0;
        end
    else
        begin
        reset_n_reg1 <= 1'd1;
        reset_n_reg2 <= reset_n_reg1;
        end   
end  


    
        assign clk_pclk      = PIPE_PCLK_IN;
        assign clk_rxusrclk  = PIPE_RXUSRCLK_IN;
        assign clk_rxoutclk  = PIPE_RXOUTCLK_IN;
        assign clk_dclk      = PIPE_DCLK_IN;
        assign PIPE_USERCLK1 = PIPE_USERCLK1_IN;
        assign PIPE_USERCLK2 = PIPE_USERCLK2_IN;
        assign clk_oobclk    = PIPE_OOBCLK_IN;
        assign clk_mmcm_lock = PIPE_MMCM_LOCK_IN;


        assign INT_PCLK_OUT_SLAVE= 1'b0;
        assign INT_RXUSRCLK_OUT  = 1'b0;
        assign INT_RXOUTCLK_OUT  = {PCIE_LANES{1'b0}};
        assign INT_DCLK_OUT      = 1'b0;
        assign INT_USERCLK1_OUT  = 1'b0;
        assign INT_USERCLK2_OUT  = 1'b0;
        assign INT_OOBCLK_OUT    = 1'b0;
        assign INT_MMCM_LOCK_OUT = 1'b0;




    init_ctrl 
        init_ctrl_i
        (
            .RST_CLK                        (clk_pclk),
            .RST_RXUSRCLK                   (clk_rxusrclk),
            .RST_DCLK                       (clk_dclk),
            .RST_RST_N                      (reset_n_reg2),
            .RST_DRP_DONE                   (drp_done),
            .RST_RXPMARESETDONE             (gt_rxpmaresetdone),
            .RST_PLLLOCK                    (&qpll_qplllock),
            .RST_RATE_IDLE                  (rate_idle),
            .RST_RXCDRLOCK                  (user_rxcdrlock),
            .RST_MMCM_LOCK                  (clk_mmcm_lock),
            .RST_RESETDONE                  (user_resetdone),
            .RST_PHYSTATUS                  (gt_phystatus),
            .RST_TXSYNC_DONE                (sync_txsync_done),

            .RST_CPLLRESET                  (rst_cpllreset),
            .RST_CPLLPD                     (rst_cpllpd),
            .RST_RXUSRCLK_RESET             (rst_rxusrclk_reset),
            .RST_DCLK_RESET                 (rst_dclk_reset),
            .RST_GTRESET                    (rst_gtreset),
            .RST_DRP_START                  (rst_drp_start),
            .RST_DRP_X16                    (rst_drp_x16),
            .RST_USERRDY                    (rst_userrdy),
            .RST_TXSYNC_START               (rst_txsync_start),
            .RST_IDLE                       (rst_idle),
            .RST_FSM                        (rst_fsm)
        );

    assign gtp_rst_qpllreset = rst_cpllreset;
    assign gtp_rst_qpllpd    = rst_cpllpd;



pll_init_ctrl 
        pll_init_ctrl_i
        (
        
            .QRST_CLK                       (clk_pclk),                 
            .QRST_RST_N                     (reset_n_reg2),
            .QRST_MMCM_LOCK                 (clk_mmcm_lock),
            .QRST_CPLLLOCK                  (gt_cplllock),
            .QRST_DRP_DONE                  (qdrp_done),
            .QRST_QPLLLOCK                  (qpll_qplllock),
            .QRST_RATE                      (PIPE_RATE),
            .QRST_QPLLRESET_IN              (rate_qpllreset),
            .QRST_QPLLPD_IN                 (rate_qpllpd),
            
            .QRST_OVRD                      (qrst_ovrd),
            .QRST_DRP_START                 (qrst_drp_start),
            .QRST_QPLLRESET_OUT             (qrst_qpllreset),
            .QRST_QPLLPD_OUT                (qrst_qpllpd),
            .QRST_IDLE                      (qrst_idle),
            .QRST_FSM                       (qrst_fsm)
        
        );
        
assign jtag_sl_iport = {PCIE_LANES{37'd0}};


wire gt_cpllpdrefclk;

BUFG wake_refclk_bufg (.I (PIPE_CLK), .O (gt_cpllpdrefclk));

generate for (i=0; i<PCIE_LANES; i=i+1) 

    begin : lane_gen

lane_keeper 
    lane_keeper_i
    (
    
        .USER_TXUSRCLK                  (clk_pclk),
        .USER_RXUSRCLK                  (clk_rxusrclk),
        .USER_OOBCLK_IN                 (clk_oobclk),
        .USER_RST_N                     (!rst_cpllreset),
        .USER_RXUSRCLK_RST_N            (!rst_rxusrclk_reset),
        .USER_PCLK_SEL                  (rate_pclk_sel[i]),
        .USER_RESETOVRD_START           (rate_resetovrd_start[i]),
        .USER_TXRESETDONE               (gt_txresetdone[i]),
        .USER_RXRESETDONE               (gt_rxresetdone[i]),
        .USER_TXELECIDLE                (PIPE_TXELECIDLE[i]),
        .USER_TXCOMPLIANCE              (PIPE_TXCOMPLIANCE[i]),
        .USER_RXCDRLOCK_IN              (gt_rxcdrlock[i]),
        .USER_RXVALID_IN                (gt_rxvalid[i]),
        .USER_RXSTATUS_IN               (gt_rxstatus[(3*i)+2]),
        .USER_PHYSTATUS_IN              (gt_phystatus[i]),
        .USER_RATE_DONE                 (rate_done[i]),
        .USER_RST_IDLE                  (rst_idle),
        .USER_RATE_RXSYNC               (rate_rxsync[i]),
        .USER_RATE_IDLE                 (rate_idle[i]),
        .USER_RATE_GEN3                 (rate_gen3[i]),
        .USER_RXEQ_ADAPT_DONE           (eq_rxeq_adapt_done[i]),
        
        .USER_OOBCLK                    (user_oobclk[i]),
        .USER_RESETOVRD                 (user_resetovrd[i]),
        .USER_TXPMARESET                (user_txpmareset[i]),                 
        .USER_RXPMARESET                (user_rxpmareset[i]),                
        .USER_RXCDRRESET                (user_rxcdrreset[i]),
        .USER_RXCDRFREQRESET            (user_rxcdrfreqreset[i]),
        .USER_RXDFELPMRESET             (user_rxdfelpmreset[i]),
        .USER_EYESCANRESET              (user_eyescanreset[i]),
        .USER_TXPCSRESET                (user_txpcsreset[i]),                   
        .USER_RXPCSRESET                (user_rxpcsreset[i]),                 
        .USER_RXBUFRESET                (user_rxbufreset[i]),
        .USER_RESETOVRD_DONE            (user_resetovrd_done[i]),
        .USER_RESETDONE                 (user_resetdone[i]),
        .USER_ACTIVE_LANE               (user_active_lane[i]),
        .USER_RXCDRLOCK_OUT             (user_rxcdrlock[i]),
        .USER_RXVALID_OUT               (PIPE_RXVALID[i]),
        .USER_PHYSTATUS_OUT             (PIPE_PHYSTATUS[i]),
        .USER_PHYSTATUS_RST             (PIPE_PHYSTATUS_RST[i]),
        .USER_GEN3_RDY                  (PIPE_GEN3_RDY[i]),
        .USER_RX_CONVERGE               (user_rx_converge[i])
    
    );
    
    
    
speed_ctrl                                                                                                            
        speed_ctrl_i
        (
    
            .RATE_CLK                       (clk_pclk),
            .RATE_RST_N                     (!rst_cpllreset),
            .RATE_RATE_IN                   (PIPE_RATE),   
            .RATE_DRP_DONE                  (drp_done[i]),                       
            .RATE_RXPMARESETDONE            (gt_rxpmaresetdone[i]),         
            .RATE_TXRATEDONE                (gt_txratedone[i]),
            .RATE_RXRATEDONE                (gt_rxratedone[i]),
            .RATE_PHYSTATUS                 (gt_phystatus[i]),   
            .RATE_TXSYNC_DONE               (sync_txsync_done[i]),    
                  
            .RATE_DRP_START                 (rate_drp_start[i]),                
            .RATE_DRP_X16                   (rate_drp_x16[i]),
            .RATE_PCLK_SEL                  (rate_pclk_sel[i]),       
            .RATE_RATE_OUT                  (rate_rate[(3*i)+2:(3*i)]),      
            .RATE_TXSYNC_START              (rate_txsync_start[i]),            
            .RATE_DONE                      (rate_done[i]),       
            .RATE_IDLE                      (rate_idle[i]),                     
            .RATE_FSM                       (rate_fsm[(5*i)+4:(5*i)])       
        );
    
        assign rate_cpllpd[i]                = 1'd0;
        assign rate_qpllpd[i]                = 1'd0;
        assign rate_cpllreset[i]             = 1'd0;
        assign rate_qpllreset[i]             = 1'd0;
        assign rate_txpmareset[i]            = 1'd0;
        assign rate_rxpmareset[i]            = 1'd0;
        assign rate_sysclksel[(2*i)+1:(2*i)] = 2'b0;
        assign rate_gen3[i]                  = 1'd0;
        assign rate_resetovrd_start[i]       = 1'd0;
        assign rate_rxsync_start[i]          = 1'd0;
        assign rate_rxsync[i]                = 1'd0; 
    
    
    
phase_align 
    phase_align_i 
    (
    
        .SYNC_CLK                       (clk_pclk),
        .SYNC_RST_N                     (!rst_cpllreset),
        .SYNC_SLAVE                     (i > 0),
        .SYNC_GEN3                      (rate_gen3[i]),
        .SYNC_RATE_IDLE                 (rate_idle[i]),
        .SYNC_MMCM_LOCK                 (clk_mmcm_lock),
        .SYNC_RXELECIDLE                (gt_rxelecidle_i[i]),
        .SYNC_RXCDRLOCK                 (user_rxcdrlock[i]),
        .SYNC_ACTIVE_LANE               (user_active_lane[i]),
        
        .SYNC_TXSYNC_START              (rate_txsync_start[i] || rst_txsync_start),
        .SYNC_TXPHINITDONE              (&(gt_txphinitdone | (~user_active_lane))),     
        .SYNC_TXDLYSRESETDONE           (txdlysresetdone[i]),                 
        .SYNC_TXPHALIGNDONE             (txphaligndone[i]),  
        .SYNC_TXSYNCDONE                (gt_txsyncdone[i]),
        
        .SYNC_RXSYNC_START              (rate_rxsync_start[i]),
        .SYNC_RXDLYSRESETDONE           (rxdlysresetdone[i]),
        .SYNC_RXPHALIGNDONE_M           (gt_rxphaligndone[0]),
        .SYNC_RXPHALIGNDONE_S           (rxphaligndone_s[i]),
        .SYNC_RXSYNC_DONEM_IN           (sync_rxsync_donem[0]),   
        .SYNC_RXSYNCDONE                (gt_rxsyncdone[i]),
    
        .SYNC_TXPHDLYRESET              (sync_txphdlyreset[i]),
        .SYNC_TXPHALIGN                 (sync_txphalign[i]),           
        .SYNC_TXPHALIGNEN               (sync_txphalignen[i]),        
        .SYNC_TXPHINIT                  (sync_txphinit[i]),    
        .SYNC_TXDLYBYPASS               (sync_txdlybypass[i]),                   
        .SYNC_TXDLYSRESET               (sync_txdlysreset[i]),
        .SYNC_TXDLYEN                   (sync_txdlyen[i]), 
        .SYNC_TXSYNC_DONE               (sync_txsync_done[i]),
        .SYNC_FSM_TX                    (sync_fsm_tx[(6*i)+5:(6*i)]),
        
        .SYNC_RXPHALIGN                 (sync_rxphalign[i]),
        .SYNC_RXPHALIGNEN               (sync_rxphalignen[i]),
        .SYNC_RXDLYBYPASS               (sync_rxdlybypass[i]),          
        .SYNC_RXDLYSRESET               (sync_rxdlysreset[i]),
        .SYNC_RXDLYEN                   (sync_rxdlyen[i]),
        .SYNC_RXDDIEN                   (sync_rxddien[i]),
        .SYNC_RXSYNC_DONEM_OUT          (sync_rxsync_donem[i]),
        .SYNC_RXSYNC_DONE               (sync_rxsync_done[i]),
        .SYNC_FSM_RX                    (sync_fsm_rx[(7*i)+6:(7*i)])
        
    );
    
    assign txdlysresetdone[i] = (PCIE_TXSYNC_MODE == 1) ? gt_txdlysresetdone[i] : &gt_txdlysresetdone;
    assign txphaligndone[i]   = (PCIE_TXSYNC_MODE == 1) ? gt_txphaligndone[i]   : &(gt_txphaligndone | (~user_active_lane));
    assign rxdlysresetdone[i] = (PCIE_RXSYNC_MODE == 1) ? gt_rxdlysresetdone[i] : &gt_rxdlysresetdone;
    assign rxphaligndone_s[i] = (PCIE_LANES == 1)        ? 1'd0                  : &gt_rxphaligndone[PCIE_LANES:1];
    
    
chan_retune 
        chan_retune_i
        (
            
            .DRP_CLK                        (clk_dclk),
            .DRP_RST_N                      (!rst_dclk_reset),
            .DRP_X16                        (rst_drp_x16 || rate_drp_x16[i]),
            .DRP_START                      (rst_drp_start || rate_drp_start[i]),                      
            .DRP_DO                         (gt_do[(16*i)+15:(16*i)]),
            .DRP_RDY                        (gt_rdy[i]),
            
            .DRP_ADDR                       (drp_addr[(9*i)+8:(9*i)]),
            .DRP_EN                         (drp_en[i]),  
            .DRP_DI                         (drp_di[(16*i)+15:(16*i)]),   
            .DRP_WE                         (drp_we[i]),
            .DRP_DONE                       (drp_done[i]),
            .DRP_FSM                        (drp_fsm[(3*i)+2:(3*i)])
            
        );

    
         assign jtag_sl_oport[((i+1)*17)-1 : (i*17)] = 17'd0;
         assign jtag_sl_addr[(17*i)+16:(17*i)]       = 17'd0;   
         assign jtag_sl_den[i]                       =  1'd0;
         assign jtag_sl_di[(16*i)+15:(16*i)]         = 16'd0;
         assign jtag_sl_we[i]                        =  1'd0;

    assign PIPE_JTAG_RDY[i] = (drp_fsm[(3*i)+2:(3*i)] == 3'b000);
    assign jtag_sl_en[i]	  = (jtag_sl_addr[(17*i)+16:(17*i)+9] == 8'd0) ? jtag_sl_den[i] : 1'd0;

    assign drp_mux_en[i]                = (PIPE_JTAG_RDY[i] && EXT_CH_GT_DRP) ? EXT_CH_GT_DRPEN[i] : drp_en[i];
    assign drp_mux_di[(16*i)+15:(16*i)] = (PIPE_JTAG_RDY[i] && EXT_CH_GT_DRP) ? EXT_CH_GT_DRPDI[(16*i)+15:(16*i)] : drp_di[(16*i)+15:(16*i)];
    assign drp_mux_addr[(9*i)+8:(9*i)]  = (PIPE_JTAG_RDY[i] && EXT_CH_GT_DRP) ? EXT_CH_GT_DRPADDR[(9*i)+8:(9*i)] : drp_addr[(9*i)+8:(9*i)];
    assign drp_mux_we[i]                = (PIPE_JTAG_RDY[i] && EXT_CH_GT_DRP) ? EXT_CH_GT_DRPWE[i]  : drp_we[i];

margin_tuner 
        margin_tuner_i
        (
        
            .EQ_CLK                         (clk_pclk),
            .EQ_RST_N                       (!rst_cpllreset),
            .EQ_GEN3                        (rate_gen3[i]),
            
            .EQ_TXEQ_CONTROL                (PIPE_TXEQ_CONTROL[(2*i)+1:(2*i)]),    
            .EQ_TXEQ_PRESET                 (PIPE_TXEQ_PRESET[(4*i)+3:(4*i)]),
            .EQ_TXEQ_PRESET_DEFAULT         (PIPE_TXEQ_PRESET_DEFAULT[(4*i)+3:(4*i)]),
            .EQ_TXEQ_DEEMPH_IN              (PIPE_TXEQ_DEEMPH[(6*i)+5:(6*i)]),
                                           
            .EQ_RXEQ_CONTROL                (PIPE_RXEQ_CONTROL[(2*i)+1:(2*i)]),  
            .EQ_RXEQ_PRESET                 (PIPE_RXEQ_PRESET[(3*i)+2:(3*i)]),
            .EQ_RXEQ_LFFS                   (PIPE_RXEQ_LFFS[(6*i)+5:(6*i)]),  
            .EQ_RXEQ_TXPRESET               (PIPE_RXEQ_TXPRESET[(4*i)+3:(4*i)]),
            .EQ_RXEQ_USER_EN                (PIPE_RXEQ_USER_EN[i]),          
            .EQ_RXEQ_USER_TXCOEFF           (PIPE_RXEQ_USER_TXCOEFF[(18*i)+17:(18*i)]),     
            .EQ_RXEQ_USER_MODE              (PIPE_RXEQ_USER_MODE[i]),        
            
            .EQ_TXEQ_DEEMPH                 (eq_txeq_deemph[i]),
            .EQ_TXEQ_PRECURSOR              (eq_txeq_precursor[(5*i)+4:(5*i)]),
            .EQ_TXEQ_MAINCURSOR             (eq_txeq_maincursor[(7*i)+6:(7*i)]),
            .EQ_TXEQ_POSTCURSOR             (eq_txeq_postcursor[(5*i)+4:(5*i)]),
            .EQ_TXEQ_DEEMPH_OUT             (PIPE_TXEQ_COEFF[(18*i)+17:(18*i)]),
            .EQ_TXEQ_DONE                   (PIPE_TXEQ_DONE[i]),
            .EQ_TXEQ_FSM                    (PIPE_TXEQ_FSM[(6*i)+5:(6*i)]),
            
            .EQ_RXEQ_NEW_TXCOEFF            (PIPE_RXEQ_NEW_TXCOEFF[(18*i)+17:(18*i)]), 
            .EQ_RXEQ_LFFS_SEL               (PIPE_RXEQ_LFFS_SEL[i]),
            .EQ_RXEQ_ADAPT_DONE             (eq_rxeq_adapt_done[i]),
            .EQ_RXEQ_DONE                   (PIPE_RXEQ_DONE[i]),
            .EQ_RXEQ_FSM                    (PIPE_RXEQ_FSM[(6*i)+5:(6*i)])
        
        );

    if ((i%4)==0)

        begin : quad_gen

        assign qpllpd          = gtp_rst_qpllpd;
        assign qpllreset[i>>2] = gtp_rst_qpllreset;

        wire [ 7:0] q_drp_addr;
        wire        q_drp_en;
        wire [15:0] q_drp_di;
        wire        q_drp_we;
        wire [15:0] q_drp_do;
        wire        q_drp_rdy;

pll_retune pll_retune_i
            (
            .DRP_CLK                             (clk_dclk),
            .DRP_RST_N                           (!rst_dclk_reset),
            .DRP_OVRD                            (qrst_ovrd),
            .DRP_GEN3                            (&rate_gen3),
            .DRP_QPLLLOCK                        (qpll_qplllock[i>>2]),
            .DRP_START                           (qrst_drp_start),
            .DRP_DO                              (q_drp_do),
            .DRP_RDY                             (q_drp_rdy),
            .DRP_ADDR                            (q_drp_addr),
            .DRP_EN                              (q_drp_en),
            .DRP_DI                              (q_drp_di),
            .DRP_WE                              (q_drp_we),
            .DRP_DONE                            (qdrp_done[i>>2]),
            .DRP_QPLLRESET                       (qdrp_qpllreset[i>>2]),
            .DRP_CRSCODE                         (qdrp_crscode[(6*(i>>2))+5:(6*(i>>2))]),
            .DRP_FSM                             (qdrp_fsm[(9*(i>>2))+8:(9*(i>>2))])
            );

pll_bank pll_bank_i
            (
            .QPLL_CPLLPDREFCLK                   (gt_cpllpdrefclk),
            .QPLL_GTGREFCLK                      (PIPE_CLK),
            .QPLL_QPLLLOCKDETCLK                 (1'd0),
            .QPLL_QPLLOUTCLK                     (qpll_qplloutclk[i>>2]),
            .QPLL_QPLLOUTREFCLK                  (qpll_qplloutrefclk[i>>2]),
            .QPLL_QPLLLOCK                       (qpll_qplllock[i>>2]),
            .QPLL_QPLLPD                         (qpllpd),
            .QPLL_QPLLRESET                      (qpllreset[i>>2]),
            .QPLL_DRPCLK                         (clk_dclk),
            .QPLL_DRPADDR                        (q_drp_addr),
            .QPLL_DRPEN                          (q_drp_en),
            .QPLL_DRPDI                          (q_drp_di),
            .QPLL_DRPWE                          (q_drp_we),
            .QPLL_DRPDO                          (q_drp_do),
            .QPLL_DRPRDY                         (q_drp_rdy)
            );
              assign QPLL_QPLLPD                           =  1'b0;
              assign QPLL_QPLLRESET[i>>2]                  =  1'b0;              
              assign QPLL_DRP_CLK                          =  1'b0;
              assign QPLL_DRP_RST_N                        =  1'b0;
              assign QPLL_DRP_OVRD                         =  1'b0;
              assign QPLL_DRP_GEN3                         =  1'b0;
              assign QPLL_DRP_START                        =  1'b0;
              assign INT_QPLLLOCK_OUT[i>>2]                =  qpll_qplllock[i>>2] ;
              assign INT_QPLLOUTREFCLK_OUT[i>>2]           =  qpll_qplloutrefclk[i>>2];
              assign INT_QPLLOUTCLK_OUT[i>>2]              =  qpll_qplloutclk[i>>2];
     end

    assign gt_txpmareset_i[i] = (user_txpmareset[i] || rate_txpmareset[i]);
    assign gt_rxpmareset_i[i] = (user_rxpmareset[i] || rate_rxpmareset[i]);

lane_xcvr 
    xcvr_i
    (
    
        .GT_MASTER                      (i == 0),
        .GT_GEN3                        (rate_gen3[i]),   
        .GT_RX_CONVERGE                 (&user_rx_converge),     
    
        .GT_GTREFCLK0                   (PIPE_CLK),
        .GT_QPLLCLK                     (qpll_qplloutclk[i>>2]),
        .GT_QPLLREFCLK                  (qpll_qplloutrefclk[i>>2]),
        .GT_TXUSRCLK                    (clk_pclk),
        .GT_RXUSRCLK                    (clk_rxusrclk), 
        .GT_TXUSRCLK2                   (clk_pclk),
        .GT_RXUSRCLK2                   (clk_rxusrclk), 
        .GT_OOBCLK                      (oobclk[i]),
        .GT_TXSYSCLKSEL                 (rate_sysclksel[(2*i)+1:(2*i)]),
        .GT_RXSYSCLKSEL                 (rate_sysclksel[(2*i)+1:(2*i)]),
        .GT_CPLLPDREFCLK                (gt_cpllpdrefclk),
                                
        .GT_TXOUTCLK                    (gt_txoutclk[i]),
        .GT_RXOUTCLK                    (gt_rxoutclk[i]),
        .GT_CPLLLOCK                    (gt_cplllock[i]),  
        .GT_RXCDRLOCK                   (gt_rxcdrlock[i]),
        
        .GT_CPLLPD                      (rst_cpllpd    || rate_cpllpd[i]),
        .GT_CPLLRESET                   (rst_cpllreset || rate_cpllreset[i]),
        .GT_TXUSERRDY                   (rst_userrdy),
        .GT_RXUSERRDY                   (rst_userrdy),
        .GT_RESETOVRD                   (user_resetovrd[i]),
        .GT_GTTXRESET                   (rst_gtreset),
        .GT_GTRXRESET                   (rst_gtreset),
        .GT_TXPMARESET                  (gt_txpmareset_i[i]),
        .GT_RXPMARESET                  (gt_rxpmareset_i[i]),
        .GT_RXCDRRESET                  (user_rxcdrreset[i]),
        .GT_RXCDRFREQRESET              (user_rxcdrfreqreset[i]),
        .GT_RXDFELPMRESET               (user_rxdfelpmreset[i]),
        .GT_EYESCANRESET                (user_eyescanreset[i]),
        .GT_TXPCSRESET                  (user_txpcsreset[i]),                   
        .GT_RXPCSRESET                  (user_rxpcsreset[i]),                 
        .GT_RXBUFRESET                  (user_rxbufreset[i]),
                                    
        .GT_EYESCANDATAERROR            (gt_eyescandataerror[i]),
        .GT_TXRESETDONE                 (gt_txresetdone[i]),
        .GT_RXRESETDONE                 (gt_rxresetdone[i]),
        .GT_RXPMARESETDONE              (gt_rxpmaresetdone[i]),
        
        .GT_TXDATA                      (PIPE_TXDATA[(32*i)+31:(32*i)]),
        .GT_TXDATAK                     (PIPE_TXDATAK[(4*i)+3:(4*i)]),
        
        .GT_TXP                         (PIPE_TXP[i]),
        .GT_TXN                         (PIPE_TXN[i]),
        
        .GT_RXP                         (PIPE_RXP[i]),
        .GT_RXN                         (PIPE_RXN[i]),
        
        .GT_RXDATA                      (PIPE_RXDATA[(32*i)+31:(32*i)]),
        .GT_RXDATAK                     (PIPE_RXDATAK[(4*i)+3:(4*i)]),
        
        .GT_TXDETECTRX                  (PIPE_TXDETECTRX),
        .GT_TXELECIDLE                  (PIPE_TXELECIDLE[i]), 
        .GT_TXCOMPLIANCE                (PIPE_TXCOMPLIANCE[i]),
        .GT_RXPOLARITY                  (PIPE_RXPOLARITY[i]),
        .GT_TXPOWERDOWN                 (PIPE_POWERDOWN[(2*i)+1:(2*i)]),
        .GT_RXPOWERDOWN                 (PIPE_POWERDOWN[(2*i)+1:(2*i)]),
        .GT_TXRATE                      (rate_rate[(3*i)+2:(3*i)]),
        .GT_RXRATE                      (rate_rate[(3*i)+2:(3*i)]),        
            
        .GT_TXMARGIN                    (PIPE_TXMARGIN),
        .GT_TXSWING                     (PIPE_TXSWING),
        .GT_TXDEEMPH                    (PIPE_TXDEEMPH[i]),  
        .GT_TXINHIBIT                   (PIPE_TXINHIBIT[i]),
        .GT_TXPRECURSOR                 (eq_txeq_precursor[(5*i)+4:(5*i)]),
        .GT_TXMAINCURSOR                (eq_txeq_maincursor[(7*i)+6:(7*i)]),
        .GT_TXPOSTCURSOR                (eq_txeq_postcursor[(5*i)+4:(5*i)]),
    
        .GT_RXVALID                     (gt_rxvalid[i]),
        .GT_PHYSTATUS                   (gt_phystatus[i]),
        .GT_RXELECIDLE                  (gt_rxelecidle_i[i]),
        .GT_RXSTATUS                    (gt_rxstatus[(3*i)+2:(3*i)]),
        .GT_RXBUFSTATUS                 (gt_rxbufstatus[(3*i)+2:(3*i)]),
        .GT_TXRATEDONE                  (gt_txratedone[i]),
        .GT_RXRATEDONE                  (gt_rxratedone[i]),
        .GT_RXDISPERR                   (gt_rxdisperr[(8*i)+7:(8*i)]),  
        .GT_RXNOTINTABLE                (gt_rxnotintable[(8*i)+7:(8*i)]),
    
        .GT_DRPCLK                      (clk_dclk),
        .GT_DRPADDR                     (drp_mux_addr[(9*i)+8:(9*i)]),
        .GT_DRPEN                       (drp_mux_en[i]),
        .GT_DRPDI                       (drp_mux_di[(16*i)+15:(16*i)]),
        .GT_DRPWE                       (drp_mux_we[i]),
                                     
        .GT_DRPDO                       (gt_do[(16*i)+15:(16*i)]),
        .GT_DRPRDY                      (gt_rdy[i]),
        
        .GT_TXPHALIGN                   (sync_txphalign[i]),    
        .GT_TXPHALIGNEN                 (sync_txphalignen[i]), 
        .GT_TXPHINIT                    (sync_txphinit[i]),   
        .GT_TXDLYBYPASS                 (sync_txdlybypass[i]),  
        .GT_TXDLYSRESET                 (sync_txdlysreset[i]),
        .GT_TXDLYEN                     (sync_txdlyen[i]),      
                                     
        .GT_TXDLYSRESETDONE             (gt_txdlysresetdone[i]),
        .GT_TXPHINITDONE                (gt_txphinitdone[i]),  
        .GT_TXPHALIGNDONE               (gt_txphaligndone[i]), 
        
        .GT_TXPHDLYRESET                (sync_txphdlyreset[i]),
        .GT_TXSYNCMODE                  (i == 0),
        .GT_TXSYNCIN                    (gt_txsyncout[0]),
        .GT_TXSYNCALLIN                 (txsyncallin),
        
        .GT_TXSYNCOUT                   (gt_txsyncout[i]),
        .GT_TXSYNCDONE                  (gt_txsyncdone[i]),
        
        .GT_RXPHALIGN                   (sync_rxphalign[i]),
        .GT_RXPHALIGNEN                 (sync_rxphalignen[i]),  
        .GT_RXDLYBYPASS                 (sync_rxdlybypass[i]),         
        .GT_RXDLYSRESET                 (sync_rxdlysreset[i]),
        .GT_RXDLYEN                     (sync_rxdlyen[i]),
        .GT_RXDDIEN                     (sync_rxddien[i]),
                                     
        .GT_RXDLYSRESETDONE             (gt_rxdlysresetdone[i]),
        .GT_RXPHALIGNDONE               (gt_rxphaligndone[i]),
                                                                   
        .GT_RXSYNCMODE                  (i == 0),
        .GT_RXSYNCIN                    (gt_rxsyncout[0]),
        .GT_RXSYNCALLIN                 (rxsyncallin),
                    
        .GT_RXSYNCOUT                   (gt_rxsyncout[i]),
        .GT_RXSYNCDONE                  (gt_rxsyncdone[i]),
                                                                         
        .GT_RXSLIDE                     (PIPE_RXSLIDE[i]),
    
        .GT_RXCOMMADET                  (gt_rxcommadet[i]),                        
        .GT_RXCHARISCOMMA               (gt_rxchariscomma[(4*i)+3:(4*i)]),                      
        .GT_RXBYTEISALIGNED             (gt_rxbyteisaligned[i]),                   
        .GT_RXBYTEREALIGN               (gt_rxbyterealign[i]),
    
        .GT_RXCHANISALIGNED             (PIPE_RXCHANISALIGNED[i]),
        .GT_RXCHBONDEN                  (rxchbonden[i]),
        .GT_RXCHBONDI                   (gt_rxchbondi[i]),
        .GT_RXCHBONDLEVEL               (gt_rxchbondlevel[(3*i)+2:(3*i)]),
        .GT_RXCHBONDMASTER              (rxchbondmaster[i]),
        .GT_RXCHBONDSLAVE               (rxchbondslave[i]),
        .GT_RXCHBONDO                   (gt_rxchbondo[i+1]),
        
        .GT_TXPRBSSEL                   (PIPE_TXPRBSSEL),
        .GT_RXPRBSSEL                   (PIPE_RXPRBSSEL),
        .GT_TXPRBSFORCEERR              (PIPE_TXPRBSFORCEERR),
        .GT_RXPRBSCNTRESET              (PIPE_RXPRBSCNTRESET),
        .GT_LOOPBACK                    (PIPE_LOOPBACK),    
        
        .GT_RXPRBSERR                   (PIPE_RXPRBSERR[i]),
        
        .GT_DMONITOROUT                 (PIPE_DMONITOROUT[(15*i)+14:(15*i)])
    );

    always_ff @(posedge clk_rxusrclk)
    begin
      if (PIPE_TXDETECTRX && gt_phystatus[i] && (gt_rxstatus[(3*i)+2:(3*i)] == 3'h3))
        gt_rxrcvrdet_c[i] <= 1'b1;
      else
        if (PIPE_TXDETECTRX && gt_phystatus[i] && (gt_rxstatus[(3*i)+2:(3*i)] != 3'h3))
          gt_rxrcvrdet_c[i] <= 1'b0;
    end

    initial
      gt_rxrcvrdet_c[i] = 1'b0;

    assign gt_rxelecidle[i] = gt_rxelecidle_i[i];

    assign oobclk[i]         = (PCIE_OOBCLK_MODE == 1) ? user_oobclk[i] : clk_oobclk;
    
    if (PCIE_CHAN_BOND_EN == "FALSE") 
        begin : channel_bonding_ms_disable
        assign rxchbonden[i]     = 1'd0; 
        assign rxchbondmaster[i] = 1'd0;
        assign rxchbondslave[i]  = 1'd0;
        end 
    else 
        begin : channel_bonding_ms_enable
        assign rxchbonden[i]     = (PCIE_LANES > 1) && (PCIE_CHAN_BOND_EN == "TRUE") ? !rate_gen3[i] : 1'd0; 
        assign rxchbondmaster[i] =  rate_gen3[i] ? 1'd0 : (i == 0);
        assign rxchbondslave[i]  =  rate_gen3[i] ? 1'd0 : (i  > 0);
        end
    
    if (PCIE_CHAN_BOND_EN == "FALSE") 
        begin : channel_bonding_in_disable
        assign gt_rxchbondi[i]                 = 5'd0; 
        assign gt_rxchbondlevel[(3*i)+2:(3*i)] = 3'd0;
        end
    else
        begin : channel_bonding_in_enable
        
        if (PCIE_CHAN_BOND == 2) 
        
            begin : channel_bonding_a
            
            case (i)
            
            0 : 
                begin
                assign gt_rxchbondi[0]         = gt_rxchbondo[0];
                assign gt_rxchbondlevel[2:0]   = (PCIE_LANES == 4'd8) ? 3'd4 : 
                                                 (PCIE_LANES >  4'd5) ? 3'd3 : 
                                                 (PCIE_LANES >  4'd3) ? 3'd2 : 
                                                 (PCIE_LANES >  4'd1) ? 3'd1 : 3'd0; 
                end
            1 : 
                begin
                assign gt_rxchbondi[1]         = gt_rxchbondo[1];
                assign gt_rxchbondlevel[5:3]   = (PCIE_LANES == 4'd8) ? 3'd3 : 
                                                 (PCIE_LANES >  4'd5) ? 3'd2 : 
                                                 (PCIE_LANES >  4'd3) ? 3'd1 : 3'd0; 
                end
            2 : 
                begin
                assign gt_rxchbondi[2]         = gt_rxchbondo[1];
                assign gt_rxchbondlevel[8:6]   = (PCIE_LANES == 4'd8) ? 3'd3 : 
                                                 (PCIE_LANES >  4'd5) ? 3'd2 : 
                                                 (PCIE_LANES >  4'd3) ? 3'd1 : 3'd0; 
                end
            3 : 
                begin
                assign gt_rxchbondi[3]         = gt_rxchbondo[3];
                assign gt_rxchbondlevel[11:9]  = (PCIE_LANES == 4'd8) ? 3'd2 : 
                                                 (PCIE_LANES >  4'd5) ? 3'd1 : 3'd0;
                end
            4 : 
                begin
                assign gt_rxchbondi[4]         = gt_rxchbondo[3];
                assign gt_rxchbondlevel[14:12] = (PCIE_LANES == 4'd8) ? 3'd2 : 
                                                 (PCIE_LANES >  4'd5) ? 3'd1 : 3'd0;
                end
            5 : 
                begin
                assign gt_rxchbondi[5]         = gt_rxchbondo[5];
                assign gt_rxchbondlevel[17:15] = (PCIE_LANES == 4'd8) ? 3'd1 : 3'd0;
                end
            6 : 
                begin
                assign gt_rxchbondi[6]         = gt_rxchbondo[5];
                assign gt_rxchbondlevel[20:18] = (PCIE_LANES == 4'd8) ? 3'd1 : 3'd0;
                end
            7 : 
                begin
                assign gt_rxchbondi[7]         = gt_rxchbondo[7]; 
                assign gt_rxchbondlevel[23:21] = 3'd0;
                end     
            default :
                begin
                assign gt_rxchbondi[i]                 = gt_rxchbondo[7]; 
                assign gt_rxchbondlevel[(3*i)+2:(3*i)] = 3'd0;
                end
                
            endcase    
                
            end
            
        else 
        
            begin : channel_bonding_b
            assign gt_rxchbondi[i]                 = (PCIE_CHAN_BOND == 1) ? gt_rxchbondo[i] : ((i == 0) ? gt_rxchbondo[0] : gt_rxchbondo[1]);
            assign gt_rxchbondlevel[(3*i)+2:(3*i)] = (PCIE_CHAN_BOND == 1) ? (PCIE_LANES-1)-i  : ((PCIE_LANES > 1) && (i == 0));       
            end
        
        end 
        
        end

endgenerate 



assign PIPE_TXEQ_FS      = 0;
assign PIPE_TXEQ_LF      = 0;
assign PIPE_RXELECIDLE   = gt_rxelecidle;
assign PIPE_RXSTATUS     = gt_rxstatus;

assign PIPE_RXDISPERR       = gt_rxdisperr;  
assign PIPE_RXNOTINTABLE    = gt_rxnotintable;
assign PIPE_RXPMARESETDONE  = gt_rxpmaresetdone;
assign PIPE_RXBUFSTATUS     = gt_rxbufstatus;
assign PIPE_TXPHALIGNDONE   = gt_txphaligndone;
assign PIPE_TXPHINITDONE    = gt_txphinitdone;
assign PIPE_TXDLYSRESETDONE = gt_txdlysresetdone;
assign PIPE_RXPHALIGNDONE   = gt_rxphaligndone;
assign PIPE_RXDLYSRESETDONE = gt_rxdlysresetdone;
assign PIPE_RXSYNCDONE      = gt_rxsyncdone;
assign PIPE_RXCOMMADET      = gt_rxcommadet;
assign PIPE_QPLL_LOCK       = qpll_qplllock;
assign PIPE_CPLL_LOCK       = gt_cplllock;   

assign PIPE_PCLK         = clk_pclk;
assign PIPE_PCLK_LOCK    = clk_mmcm_lock; 
assign PIPE_RXCDRLOCK    = 0;
assign PIPE_RXUSRCLK     = 0;
assign PIPE_RXOUTCLK     = 0;
assign PIPE_TXSYNC_DONE  = 0;
assign PIPE_RXSYNC_DONE  = 0;
assign PIPE_ACTIVE_LANE  = 0;
             
assign PIPE_TXOUTCLK_OUT = gt_txoutclk[0];
assign PIPE_RXOUTCLK_OUT = gt_rxoutclk;
assign PIPE_PCLK_SEL_OUT = rate_pclk_sel;
assign PIPE_GEN3_OUT     = rate_gen3[0];

assign PIPE_RXEQ_CONVERGE   = user_rx_converge;
assign PIPE_RXEQ_ADAPT_DONE = {PCIE_LANES{1'd0}};

assign PIPE_EYESCANDATAERROR = gt_eyescandataerror;
assign PIPE_RST_FSM      = rst_fsm;
assign PIPE_QRST_FSM     = qrst_fsm;
assign PIPE_RATE_FSM     = rate_fsm;
assign PIPE_SYNC_FSM_TX  = sync_fsm_tx;
assign PIPE_SYNC_FSM_RX  = sync_fsm_rx;
assign PIPE_DRP_FSM      = drp_fsm;   
assign PIPE_QDRP_FSM     = 0;
                        
assign PIPE_RST_IDLE     = &rst_idle;
assign PIPE_QRST_IDLE    = &qrst_idle;
assign PIPE_RATE_IDLE    = &rate_idle;

assign EXT_CH_GT_DRPDO   =  gt_do[(PCIE_LANES*16)-1:0];
assign EXT_CH_GT_DRPRDY  =  gt_rdy[(PCIE_LANES-1):0];
assign EXT_CH_GT_DRPCLK  =  clk_dclk;

assign PIPE_DEBUG_0      = (PCIE_DEBUG_MODE == 1) ? gt_txresetdone                  : {PCIE_LANES{1'b0}};
assign PIPE_DEBUG_1      = (PCIE_DEBUG_MODE == 1) ? gt_rxresetdone                  : {PCIE_LANES{1'b0}};
assign PIPE_DEBUG_2      = (PCIE_DEBUG_MODE == 1) ? gt_phystatus                    : {PCIE_LANES{1'b0}};
assign PIPE_DEBUG_3      = (PCIE_DEBUG_MODE == 1) ? gt_rxvalid                      : {PCIE_LANES{1'b0}};
assign PIPE_DEBUG_4      = (PCIE_DEBUG_MODE == 1) ? clk_dclk                        : {PCIE_LANES{1'b0}};
assign PIPE_DEBUG_5      = (PCIE_DEBUG_MODE == 1) ? drp_mux_en                      : {PCIE_LANES{1'b0}};
assign PIPE_DEBUG_6      = (PCIE_DEBUG_MODE == 1) ? drp_mux_we                      : {PCIE_LANES{1'b0}};
assign PIPE_DEBUG_7      = (PCIE_DEBUG_MODE == 1) ? gt_rdy                          : {PCIE_LANES{1'b0}};
assign PIPE_DEBUG_8      = (PCIE_DEBUG_MODE == 1) ? user_rx_converge                : {PCIE_LANES{1'b0}};
assign PIPE_DEBUG_9      = (PCIE_DEBUG_MODE == 1) ? PIPE_TXELECIDLE                 : {PCIE_LANES{1'b0}};

assign PIPE_DEBUG[ 1:0]  = (PCIE_DEBUG_MODE == 1) ? PIPE_TXEQ_CONTROL[1:0] : 2'd0;
assign PIPE_DEBUG[ 5:2]  = (PCIE_DEBUG_MODE == 1) ? PIPE_TXEQ_PRESET[3:0]  : 4'd0;
assign PIPE_DEBUG[31:6]  = 26'd0;



endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
