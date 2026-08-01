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

module speed_ctrl #(
  localparam TXDATA_WAIT_MAX = 4'd15) (
  input               RATE_CLK,
  input               RATE_RST_N,
  input       [1:0]   RATE_RATE_IN,
  input               RATE_DRP_DONE,
  input               RATE_RXPMARESETDONE,
  input               RATE_TXRATEDONE,
  input               RATE_RXRATEDONE,
  input               RATE_TXSYNC_DONE,
  input               RATE_PHYSTATUS,

  output              RATE_PCLK_SEL,
  output              RATE_DRP_START,
  output              RATE_DRP_X16,
  output      [2:0]   RATE_RATE_OUT,
  output              RATE_TXSYNC_START,
  output              RATE_DONE,
  output              RATE_IDLE,
  output      [4:0]   RATE_FSM
);

  typedef enum logic [3:0] {
    ST_IDLE, ST_TXDATA_WAIT, ST_PCLK_SEL, ST_DRP16_REQ, ST_DRP16_ACK,
    ST_RATE_SEL, ST_RXPMA_DN, ST_DRP20_REQ, ST_DRP20_ACK, ST_RATE_WAIT,
    ST_TXSYNC_REQ, ST_TXSYNC_ACK, ST_DONE
  } state_e;

  state_e state = ST_IDLE;
  state_e state_nx;

  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [1:0] rate_in_r1, rate_in_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic drp_done_r1,  drp_done_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic rxpma_r1,     rxpma_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic txrate_r1,    txrate_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic rxrate_r1,    rxrate_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic phy_r1,       phy_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic txsync_r1,    txsync_r2;

  always_ff @(posedge RATE_CLK) begin
    if (!RATE_RST_N) begin
      {rate_in_r1, drp_done_r1, rxpma_r1, txrate_r1, rxrate_r1, phy_r1, txsync_r1} <= '0;
      {rate_in_r2, drp_done_r2, rxpma_r2, txrate_r2, rxrate_r2, phy_r2, txsync_r2} <= '0;
    end else begin
      rate_in_r1 <= RATE_RATE_IN;        rate_in_r2 <= rate_in_r1;
      drp_done_r1<= RATE_DRP_DONE;        drp_done_r2<= drp_done_r1;
      rxpma_r1   <= RATE_RXPMARESETDONE;  rxpma_r2   <= rxpma_r1;
      txrate_r1  <= RATE_TXRATEDONE;      txrate_r2  <= txrate_r1;
      rxrate_r1  <= RATE_RXRATEDONE;      rxrate_r2  <= rxrate_r1;
      phy_r1     <= RATE_PHYSTATUS;       phy_r2     <= phy_r1;
      txsync_r1  <= RATE_TXSYNC_DONE;     txsync_r2  <= txsync_r1;
    end
  end

  wire [2:0] rate = (rate_in_r2 == 2'd1) ? 3'd1 : 3'd0;

  logic [3:0] txdata_wait_cnt = 4'd0;
  always_ff @(posedge RATE_CLK) begin
    if      (!RATE_RST_N)                       txdata_wait_cnt <= 4'd0;
    else if (state != ST_TXDATA_WAIT)           txdata_wait_cnt <= 4'd0;
    else if (txdata_wait_cnt < TXDATA_WAIT_MAX) txdata_wait_cnt <= txdata_wait_cnt + 4'd1;
  end
  wire txdata_wait_done = (txdata_wait_cnt == TXDATA_WAIT_MAX);

  logic txratedone = 1'b0;
  logic rxratedone = 1'b0;
  logic phystatus  = 1'b0;
  logic ratedone   = 1'b0;

  wire latch_phase = (state == ST_RATE_WAIT) || (state == ST_RXPMA_DN) ||
                     (state == ST_DRP20_REQ) || (state == ST_DRP20_ACK);

  always_ff @(posedge RATE_CLK) begin
    if (!RATE_RST_N) begin
      txratedone <= 1'b0; rxratedone <= 1'b0; phystatus <= 1'b0; ratedone <= 1'b0;
    end else if (latch_phase) begin
      if (txrate_r2) txratedone <= 1'b1;
      if (rxrate_r2) rxratedone <= 1'b1;
      if (phy_r2)    phystatus  <= 1'b1;
      if (rxratedone && txratedone && phystatus) ratedone <= 1'b1;
    end else begin
      txratedone <= 1'b0; rxratedone <= 1'b0; phystatus <= 1'b0; ratedone <= 1'b0;
    end
  end

  always_comb begin
    state_nx = state;
    unique case (state)
      ST_IDLE       : state_nx = (rate_in_r2 != rate_in_r1) ? ST_TXDATA_WAIT : ST_IDLE;
      ST_TXDATA_WAIT: state_nx = txdata_wait_done            ? ST_PCLK_SEL    : ST_TXDATA_WAIT;
      ST_PCLK_SEL   : state_nx = ST_DRP16_REQ;
      ST_DRP16_REQ  : state_nx = (!drp_done_r2) ? ST_DRP16_ACK  : ST_DRP16_REQ;
      ST_DRP16_ACK  : state_nx =  drp_done_r2   ? ST_RATE_SEL   : ST_DRP16_ACK;
      ST_RATE_SEL   : state_nx = ST_RXPMA_DN;
      ST_RXPMA_DN   : state_nx = (!rxpma_r2)    ? ST_DRP20_REQ  : ST_RXPMA_DN;
      ST_DRP20_REQ  : state_nx = (!drp_done_r2) ? ST_DRP20_ACK  : ST_DRP20_REQ;
      ST_DRP20_ACK  : state_nx =  drp_done_r2   ? ST_RATE_WAIT  : ST_DRP20_ACK;
      ST_RATE_WAIT  : state_nx =  ratedone      ? ST_TXSYNC_REQ : ST_RATE_WAIT;
      ST_TXSYNC_REQ : state_nx = (!txsync_r2)   ? ST_TXSYNC_ACK : ST_TXSYNC_REQ;
      ST_TXSYNC_ACK : state_nx =  txsync_r2     ? ST_DONE       : ST_TXSYNC_ACK;
      ST_DONE       : state_nx = ST_IDLE;
      default       : state_nx = ST_IDLE;
    endcase
  end

  logic       pclk_sel = 1'b0;
  logic [2:0] rate_out = 3'd0;

  wire       pclk_sel_d = (state == ST_PCLK_SEL) ? (rate_in_r2 == 2'd1) : pclk_sel;
  wire [2:0] rate_out_d = (state == ST_RATE_SEL) ? rate                 : rate_out;

  always_ff @(posedge RATE_CLK) begin
    if (!RATE_RST_N) begin
      state    <= ST_IDLE;
      pclk_sel <= 1'b0;
      rate_out <= 3'd0;
    end else begin
      state    <= state_nx;
      pclk_sel <= pclk_sel_d;
      rate_out <= rate_out_d;
    end
  end

  assign RATE_PCLK_SEL     = pclk_sel;
  assign RATE_DRP_START    = (state == ST_DRP16_REQ) || (state == ST_DRP20_REQ);
  assign RATE_DRP_X16      = (state == ST_DRP16_REQ) || (state == ST_DRP16_ACK);
  assign RATE_RATE_OUT     = rate_out;
  assign RATE_TXSYNC_START = (state == ST_TXSYNC_REQ);
  assign RATE_DONE         = (state == ST_DONE);
  assign RATE_IDLE         = (state == ST_IDLE);
  assign RATE_FSM          = {1'b0, state};

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
