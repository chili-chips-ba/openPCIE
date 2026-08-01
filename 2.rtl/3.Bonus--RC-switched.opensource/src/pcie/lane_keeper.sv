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

module lane_keeper #(
  localparam RXCDRLOCK_MAX = 4'd15,
  localparam RXVALID_MAX = 4'd15,
  localparam CONVERGE_MAX = 22'd3125000) (
  input               USER_TXUSRCLK,
  input               USER_RXUSRCLK,
  input               USER_OOBCLK_IN,
  input               USER_RST_N,
  input               USER_RXUSRCLK_RST_N,
  input               USER_PCLK_SEL,
  input               USER_RESETOVRD_START,
  input               USER_TXRESETDONE,
  input               USER_RXRESETDONE,
  input               USER_TXELECIDLE,
  input               USER_TXCOMPLIANCE,
  input               USER_RXCDRLOCK_IN,
  input               USER_RXVALID_IN,
  input               USER_RXSTATUS_IN,
  input               USER_PHYSTATUS_IN,
  input               USER_RATE_DONE,
  input               USER_RST_IDLE,
  input               USER_RATE_RXSYNC,
  input               USER_RATE_IDLE,
  input               USER_RATE_GEN3,
  input               USER_RXEQ_ADAPT_DONE,

  output              USER_OOBCLK,
  output              USER_RESETOVRD,
  output              USER_TXPMARESET,
  output              USER_RXPMARESET,
  output              USER_RXCDRRESET,
  output              USER_RXCDRFREQRESET,
  output              USER_RXDFELPMRESET,
  output              USER_EYESCANRESET,
  output              USER_TXPCSRESET,
  output              USER_RXPCSRESET,
  output              USER_RXBUFRESET,
  output              USER_RESETOVRD_DONE,
  output              USER_RESETDONE,
  output              USER_ACTIVE_LANE,
  output              USER_RXCDRLOCK_OUT,
  output              USER_RXVALID_OUT,
  output              USER_PHYSTATUS_OUT,
  output              USER_PHYSTATUS_RST,
  output              USER_GEN3_RDY,
  output              USER_RX_CONVERGE
);

  localparam [21:0] CONV_MAX = CONVERGE_MAX;

  wire [7:0] tx_async = { USER_RXEQ_ADAPT_DONE, USER_RXCDRLOCK_IN, USER_TXCOMPLIANCE,
                          USER_TXELECIDLE, USER_RXRESETDONE, USER_TXRESETDONE,
                          USER_RESETOVRD_START, USER_PCLK_SEL };
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [7:0] tx_s1 = 8'd0, tx_s2 = 8'd0;

  always_ff @(posedge USER_TXUSRCLK)
    if (!USER_RST_N) begin tx_s1 <= 8'd0; tx_s2 <= 8'd0; end
    else             begin tx_s1 <= tx_async; tx_s2 <= tx_s1; end

  wire pclk_sel_2      = tx_s2[0];
  wire resetovrd_st_2  = tx_s2[1];
  wire txresetdone_2   = tx_s2[2];
  wire rxresetdone_2   = tx_s2[3];
  wire txelecidle_2    = tx_s2[4];
  wire txcompliance_2  = tx_s2[5];
  wire rxcdrlock_2     = tx_s2[6];
  wire rxeq_adapt_2    = tx_s2[7];

  wire [6:0] rx_async = { USER_RATE_GEN3, USER_RATE_IDLE, USER_RATE_RXSYNC,
                          USER_RATE_DONE, USER_RST_IDLE, USER_RXSTATUS_IN, USER_RXVALID_IN };
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [6:0] rx_s1 = 7'd0, rx_s2 = 7'd0;

  always_ff @(posedge USER_RXUSRCLK)
    if (!USER_RXUSRCLK_RST_N) begin rx_s1 <= 7'd0; rx_s2 <= 7'd0; end
    else                      begin rx_s1 <= rx_async; rx_s2 <= rx_s1; end

  wire rxvalid_2     = rx_s2[0];
  wire rxstatus_2    = rx_s2[1];
  wire rst_idle_2    = rx_s2[2];
  wire rate_done_2   = rx_s2[3];
  wire rate_rxsync_2 = rx_s2[4];
  wire rate_idle_2   = rx_s2[5];
  wire rate_gen3_2   = rx_s2[6];

  typedef enum logic [1:0] { FSM_IDLE, FSM_RESETOVRD, FSM_RESET_INIT, FSM_RESET } fsm_e;

  fsm_e        fsm       = FSM_IDLE,  fsm_nx;
  logic [7:0]  reset_cnt = 8'd127,    reset_cnt_nx;
  logic [7:0]  reset     = 8'h00,     reset_nx;

  always_comb begin
    unique case (fsm)
      FSM_IDLE      : fsm_nx = resetovrd_st_2                        ? FSM_RESETOVRD  : FSM_IDLE;
      FSM_RESETOVRD : fsm_nx = (reset_cnt == 8'd0)                   ? FSM_RESET_INIT : FSM_RESETOVRD;
      FSM_RESET_INIT: fsm_nx = FSM_RESET;
      FSM_RESET     : fsm_nx = ((reset == 8'd0) && rxresetdone_2)    ? FSM_IDLE       : FSM_RESET;
      default       : fsm_nx = FSM_IDLE;
    endcase
    if (((fsm == FSM_RESETOVRD) || (fsm == FSM_RESET)) && (reset_cnt != 8'd0))
      reset_cnt_nx = reset_cnt - 8'd1;
    else
      reset_cnt_nx = 8'd127;
    if (fsm == FSM_RESET_INIT)
      reset_nx = 8'hFF;
    else if ((fsm == FSM_RESET) && (reset_cnt == 8'd0))
      reset_nx = {reset[6:0], 1'b0};
    else
      reset_nx = reset;
  end

  always_ff @(posedge USER_TXUSRCLK)
    if (!USER_RST_N) begin
      fsm <= FSM_IDLE; reset_cnt <= 8'd127; reset <= 8'h00;
    end else begin
      fsm <= fsm_nx;   reset_cnt <= reset_cnt_nx; reset <= reset_nx;
    end

  logic [1:0] oobclk_cnt = 2'd0;
  logic       oobclk     = 1'b0;

  always_ff @(posedge USER_OOBCLK_IN)
    if (!USER_RST_N) begin oobclk_cnt <= 2'd0; oobclk <= 1'b0; end
    else begin
      oobclk_cnt <= oobclk_cnt + 2'd1;
      oobclk     <= pclk_sel_2 ? oobclk_cnt[1] : oobclk_cnt[0];
    end

  logic [3:0] rxcdrlock_cnt = 4'd0;
  always_ff @(posedge USER_TXUSRCLK)
    if      (!USER_RST_N)                         rxcdrlock_cnt <= 4'd0;
    else if (!rxcdrlock_2)                        rxcdrlock_cnt <= 4'd0;
    else if (rxcdrlock_cnt != RXCDRLOCK_MAX)      rxcdrlock_cnt <= rxcdrlock_cnt + 4'd1;

  logic [3:0] rxvalid_cnt = 4'd0;
  always_ff @(posedge USER_RXUSRCLK)
    if      (!USER_RXUSRCLK_RST_N)                       rxvalid_cnt <= 4'd0;
    else if (rxvalid_2 && (rxvalid_cnt == RXVALID_MAX))  rxvalid_cnt <= rxvalid_cnt;
    else if (rxvalid_2 && !rxstatus_2)                   rxvalid_cnt <= rxvalid_cnt + 4'd1;
    else                                                 rxvalid_cnt <= 4'd0;

  logic [21:0] converge_cnt  = 22'd0;
  logic        converge_gen3 = 1'b0;

  always_ff @(posedge USER_TXUSRCLK)
    if (!USER_RST_N)
      converge_cnt <= 22'd0;
    else if (rst_idle_2 && rate_idle_2 && !rate_gen3_2)
      converge_cnt <= (converge_cnt < CONV_MAX) ? (converge_cnt + 22'd1) : converge_cnt;
    else
      converge_cnt <= 22'd0;

  always_ff @(posedge USER_TXUSRCLK)
    if (!USER_RST_N)
      converge_gen3 <= 1'b0;
    else if (rate_gen3_2)
      converge_gen3 <= rxeq_adapt_2 ? 1'b1 : converge_gen3;
    else
      converge_gen3 <= 1'b0;

  assign USER_RESETOVRD      = (fsm != FSM_IDLE);
  assign USER_TXPMARESET     = 1'b0;
  assign USER_RXPMARESET     = reset[0];
  assign USER_RXCDRRESET     = reset[1];
  assign USER_RXCDRFREQRESET = reset[2];
  assign USER_RXDFELPMRESET  = reset[3];
  assign USER_EYESCANRESET   = reset[4];
  assign USER_TXPCSRESET     = 1'b0;
  assign USER_RXPCSRESET     = reset[5];
  assign USER_RXBUFRESET     = reset[6];
  assign USER_RESETOVRD_DONE = (fsm == FSM_IDLE);

  assign USER_OOBCLK         = oobclk;
  assign USER_RESETDONE      = txresetdone_2 && rxresetdone_2;
  assign USER_ACTIVE_LANE    = !(txelecidle_2 && txcompliance_2);
  assign USER_RXCDRLOCK_OUT  = USER_RXCDRLOCK_IN && (rxcdrlock_cnt == RXCDRLOCK_MAX);
  assign USER_RXVALID_OUT    = USER_RXVALID_IN && (rxvalid_cnt == RXVALID_MAX) && rst_idle_2 && rate_idle_2;
  assign USER_PHYSTATUS_OUT  = (!rst_idle_2)
                            || ((rate_idle_2 || rate_rxsync_2) && USER_PHYSTATUS_IN)
                            || rate_done_2;
  assign USER_PHYSTATUS_RST  = !rst_idle_2;
  assign USER_GEN3_RDY       = 1'b0;
  assign USER_RX_CONVERGE    = (converge_cnt == CONV_MAX) || converge_gen3;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
