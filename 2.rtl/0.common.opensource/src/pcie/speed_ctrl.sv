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

module speed_ctrl
  import link_pkg::*;
(
    input logic clk,
    input logic rst_n,
    input logic rate,            // 0 = Gen1, 1 = Gen2
    input logic drp_done,
    input logic rxpmaresetdone,
    input logic txratedone,
    input logic rxratedone,
    input logic txsync_done,
    input logic phystatus,

    output gtp_rate_t rate_ctrl
);

  localparam logic [3:0] TXDATA_WAIT_MAX = 4'd15;

  typedef enum logic [3:0] {
    ST_IDLE,
    ST_TXDATA_WAIT,
    ST_PIPE_CLK_SEL,
    ST_DRP16_REQ,
    ST_DRP16_ACK,
    ST_RATE_SEL,
    ST_RXPMA_DN,
    ST_DRP20_REQ,
    ST_DRP20_ACK,
    ST_RATE_WAIT,
    ST_TXSYNC_REQ,
    ST_TXSYNC_ACK,
    ST_DONE
  } state_e;

  state_e state;
  state_e state_nx;

  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic
      rate_in_r1, rate_in_r2;  // PIPE rate: pipe_clk, latency only
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic
      drp_done_r1, drp_done_r2;  // chan_retune: clk125 -> pipe_clk
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic rxpma_r1, rxpma_r2;  // RXPMARESETDONE: async
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic
      txrate_r1, txrate_r2;  // TXRATEDONE: TXUSRCLK2 = pipe_clk, latency only
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic
      rxrate_r1, rxrate_r2;  // RXRATEDONE: RXUSRCLK2 = pipe_clk, latency only
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic
      phy_r1, phy_r2;  // PHYSTATUS: RXUSRCLK2 = pipe_clk, latency only
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic
      txsync_r1, txsync_r2;  // phase_align: pipe_clk, latency only

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      {rate_in_r1, drp_done_r1, rxpma_r1, txrate_r1, rxrate_r1, phy_r1, txsync_r1} <= '0;
      {rate_in_r2, drp_done_r2, rxpma_r2, txrate_r2, rxrate_r2, phy_r2, txsync_r2} <= '0;
    end
    else begin
      rate_in_r1  <= rate;
      rate_in_r2  <= rate_in_r1;
      drp_done_r1 <= drp_done;
      drp_done_r2 <= drp_done_r1;
      rxpma_r1    <= rxpmaresetdone;
      rxpma_r2    <= rxpma_r1;
      txrate_r1   <= txratedone;
      txrate_r2   <= txrate_r1;
      rxrate_r1   <= rxratedone;
      rxrate_r2   <= rxrate_r1;
      phy_r1      <= phystatus;
      phy_r2      <= phy_r1;
      txsync_r1   <= txsync_done;
      txsync_r2   <= txsync_r1;
    end
  end

  logic [2:0] rate_sel;
  assign rate_sel = rate_in_r2 ? 3'd1 : 3'd0;

  logic [3:0] txdata_wait_cnt;
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      txdata_wait_cnt <= 4'd0;
    end
    else if (state != ST_TXDATA_WAIT) begin
      txdata_wait_cnt <= 4'd0;
    end
    else if (txdata_wait_cnt < TXDATA_WAIT_MAX) begin
      txdata_wait_cnt <= txdata_wait_cnt + 4'd1;
    end
  end
  logic txdata_wait_done;
  assign txdata_wait_done = (txdata_wait_cnt == TXDATA_WAIT_MAX);

  logic txratedone_q;
  logic rxratedone_q;
  logic phystatus_q;
  logic ratedone;

  logic latch_phase;
  assign latch_phase = (state == ST_RATE_WAIT) || (state == ST_RXPMA_DN) ||
                     (state == ST_DRP20_REQ) || (state == ST_DRP20_ACK);

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      txratedone_q <= 1'b0;
      rxratedone_q <= 1'b0;
      phystatus_q  <= 1'b0;
      ratedone     <= 1'b0;
    end
    else if (latch_phase) begin
      if (txrate_r2) begin
        txratedone_q <= 1'b1;
      end
      if (rxrate_r2) begin
        rxratedone_q <= 1'b1;
      end
      if (phy_r2) begin
        phystatus_q <= 1'b1;
      end
      if (rxratedone_q && txratedone_q && phystatus_q) begin
        ratedone <= 1'b1;
      end
    end
    else begin
      txratedone_q <= 1'b0;
      rxratedone_q <= 1'b0;
      phystatus_q  <= 1'b0;
      ratedone     <= 1'b0;
    end
  end

  always_comb begin
    state_nx = state;
    unique case (state)
      ST_IDLE:         state_nx = (rate_in_r2 != rate_in_r1) ? ST_TXDATA_WAIT : ST_IDLE;
      ST_TXDATA_WAIT:  state_nx = txdata_wait_done ? ST_PIPE_CLK_SEL : ST_TXDATA_WAIT;
      ST_PIPE_CLK_SEL: state_nx = ST_DRP16_REQ;
      ST_DRP16_REQ:    state_nx = (!drp_done_r2) ? ST_DRP16_ACK : ST_DRP16_REQ;
      ST_DRP16_ACK:    state_nx = drp_done_r2 ? ST_RATE_SEL : ST_DRP16_ACK;
      ST_RATE_SEL:     state_nx = ST_RXPMA_DN;
      ST_RXPMA_DN:     state_nx = (!rxpma_r2) ? ST_DRP20_REQ : ST_RXPMA_DN;
      ST_DRP20_REQ:    state_nx = (!drp_done_r2) ? ST_DRP20_ACK : ST_DRP20_REQ;
      ST_DRP20_ACK:    state_nx = drp_done_r2 ? ST_RATE_WAIT : ST_DRP20_ACK;
      ST_RATE_WAIT:    state_nx = ratedone ? ST_TXSYNC_REQ : ST_RATE_WAIT;
      ST_TXSYNC_REQ:   state_nx = (!txsync_r2) ? ST_TXSYNC_ACK : ST_TXSYNC_REQ;
      ST_TXSYNC_ACK:   state_nx = txsync_r2 ? ST_DONE : ST_TXSYNC_ACK;
      ST_DONE:         state_nx = ST_IDLE;
    endcase
  end

  logic       pipe_clk_sel;
  logic [2:0] rate_out;

  logic       pipe_clk_sel_d;
  assign pipe_clk_sel_d = (state == ST_PIPE_CLK_SEL) ? rate_in_r2 : pipe_clk_sel;
  logic [2:0] rate_out_d;
  assign rate_out_d = (state == ST_RATE_SEL) ? rate_sel : rate_out;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state        <= ST_IDLE;
      pipe_clk_sel <= 1'b0;
      rate_out     <= 3'd0;
    end
    else begin
      state        <= state_nx;
      pipe_clk_sel <= pipe_clk_sel_d;
      rate_out     <= rate_out_d;
    end
  end

  assign rate_ctrl.pipe_clk_sel = pipe_clk_sel;
  assign rate_ctrl.drp_start    = (state == ST_DRP16_REQ) || (state == ST_DRP20_REQ);
  assign rate_ctrl.drp_x16      = (state == ST_DRP16_REQ) || (state == ST_DRP16_ACK);
  assign rate_ctrl.rate         = rate_out;
  assign rate_ctrl.txsync_start = (state == ST_TXSYNC_REQ);
  assign rate_ctrl.done         = (state == ST_DONE);
  assign rate_ctrl.idle         = (state == ST_IDLE);

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
