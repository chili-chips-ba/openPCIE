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

module init_ctrl
  import link_pkg::*;
(
    input logic pipe_clk,     // PIPE clock
    input logic clk125,       // 125 MHz, runs before PLL0 is powered up
    input logic pipe_rst_n,   // released on pipe_clk
    input logic gtpll0_lock,  // PLL0LOCK of GTPE2_COMMON
    input logic mmcm_lock,

    gtp_if.ctrl gtp,  // reads the lane status, drives gtp.rst

    output logic gtpll0_reset_req  // hold PLL0 in reset (lane init and DRP)
);

  localparam logic [5:0] CFG_WAIT_MAX = 6'd63;

  typedef enum logic [4:0] {
    ST_IDLE,
    ST_CFG_WAIT,
    ST_GTPLL0_HOLD,
    ST_DRP16_REQ,
    ST_DRP16_ACK,
    ST_GTPLL0_LOCK,
    ST_GT_RELEASE,
    ST_RXPMA_UP,
    ST_RXPMA_DN,
    ST_DRP20_REQ,
    ST_DRP20_ACK,
    ST_LOCK_WAIT,
    ST_RESET_DONE,
    ST_TXSYNC_REQ,
    ST_TXSYNC_ACK
  } state_e;

  state_e state;
  state_e state_nx;

  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANES-1:0]
      drp_done_r1, drp_done_r2;  // gtp.drp_done: chan_retune, clk125 -> pipe_clk
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANES-1:0]
      rxpma_r1, rxpma_r2;  // RXPMARESETDONE: async
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic
      gtpll0_lock_r1, gtpll0_locked;  // PLL0LOCK: async
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic
      mmcm_lock_r1, mmcm_locked;  // MMCM LOCKED: async
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANES-1:0]
      resetdone_r1, resetdone_r2;  // lane_xcvr: pipe_clk, latency only
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANES-1:0]
      phystatus_r1, phystatus_r2;  // PHYSTATUS: RXUSRCLK2 = pipe_clk, latency only
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANES-1:0]
      txsyncdone_r1, txsyncdone_r2;  // phase_align: pipe_clk, latency only

  always_ff @(posedge pipe_clk or negedge pipe_rst_n) begin
    if (!pipe_rst_n) begin
      {drp_done_r1, rxpma_r1, resetdone_r1, phystatus_r1, txsyncdone_r1} <= '0;
      {drp_done_r2, rxpma_r2, resetdone_r2, phystatus_r2, txsyncdone_r2} <= '0;
      {gtpll0_lock_r1, mmcm_lock_r1, gtpll0_locked, mmcm_locked}         <= '0;
    end
    else begin
      drp_done_r1    <= gtp.drp_done;
      drp_done_r2    <= drp_done_r1;
      rxpma_r1       <= gtp.rxpmaresetdone;
      rxpma_r2       <= rxpma_r1;
      gtpll0_lock_r1 <= gtpll0_lock;
      gtpll0_locked  <= gtpll0_lock_r1;
      mmcm_lock_r1   <= mmcm_lock;
      mmcm_locked    <= mmcm_lock_r1;
      resetdone_r1   <= gtp.resetdone;
      resetdone_r2   <= resetdone_r1;
      phystatus_r1   <= gtp.phystatus;
      phystatus_r2   <= phystatus_r1;
      txsyncdone_r1  <= gtp.txsync_done;
      txsyncdone_r2  <= txsyncdone_r1;
    end
  end

  logic resetdone_lo;
  assign resetdone_lo = &(~resetdone_r2);
  logic resetdone_hi;
  assign resetdone_hi = &resetdone_r2;
  logic drp_busy;
  assign drp_busy = &(~drp_done_r2);
  logic drp_ready;
  assign drp_ready = &drp_done_r2;
  logic rxpma_hi;
  assign rxpma_hi = &rxpma_r2;
  logic rxpma_lo;
  assign rxpma_lo = &(~rxpma_r2);
  logic phystatus_lo;
  assign phystatus_lo = &(~phystatus_r2);
  logic txsync_lo;
  assign txsync_lo = &(~txsyncdone_r2);
  logic txsync_hi;
  assign txsync_hi = &txsyncdone_r2;

  logic [5:0] cfg_wait_cnt;

  always_ff @(posedge pipe_clk or negedge pipe_rst_n) begin
    if (!pipe_rst_n) begin
      cfg_wait_cnt <= 6'd0;
    end
    else if (state != ST_CFG_WAIT) begin
      cfg_wait_cnt <= 6'd0;
    end
    else if (cfg_wait_cnt < CFG_WAIT_MAX) begin
      cfg_wait_cnt <= cfg_wait_cnt + 6'd1;
    end
  end
  logic cfg_wait_done;
  assign cfg_wait_done = (cfg_wait_cnt == CFG_WAIT_MAX);

  always_comb begin
    state_nx = state;
    unique case (state)
      ST_IDLE:        state_nx = ST_IDLE;
      ST_CFG_WAIT:    state_nx = cfg_wait_done ? ST_GTPLL0_HOLD : ST_CFG_WAIT;
      ST_GTPLL0_HOLD: state_nx = (!gtpll0_locked && resetdone_lo) ? ST_DRP16_REQ : ST_GTPLL0_HOLD;
      ST_DRP16_REQ:   state_nx = drp_busy ? ST_DRP16_ACK : ST_DRP16_REQ;
      ST_DRP16_ACK:   state_nx = drp_ready ? ST_GTPLL0_LOCK : ST_DRP16_ACK;
      ST_GTPLL0_LOCK: state_nx = gtpll0_locked ? ST_GT_RELEASE : ST_GTPLL0_LOCK;
      ST_GT_RELEASE:  state_nx = ST_RXPMA_UP;
      ST_RXPMA_UP:    state_nx = rxpma_hi ? ST_RXPMA_DN : ST_RXPMA_UP;
      ST_RXPMA_DN:    state_nx = rxpma_lo ? ST_DRP20_REQ : ST_RXPMA_DN;
      ST_DRP20_REQ:   state_nx = drp_busy ? ST_DRP20_ACK : ST_DRP20_REQ;
      ST_DRP20_ACK:   state_nx = drp_ready ? ST_LOCK_WAIT : ST_DRP20_ACK;
      ST_LOCK_WAIT:   state_nx = mmcm_locked ? ST_RESET_DONE : ST_LOCK_WAIT;
      ST_RESET_DONE:  state_nx = (resetdone_hi && phystatus_lo) ? ST_TXSYNC_REQ : ST_RESET_DONE;
      ST_TXSYNC_REQ:  state_nx = txsync_lo ? ST_TXSYNC_ACK : ST_TXSYNC_REQ;
      ST_TXSYNC_ACK:  state_nx = txsync_hi ? ST_IDLE : ST_TXSYNC_ACK;
    endcase
  end

  logic gtreset_q;
  logic userrdy_q;

  logic gtpll0_reset_d;
  assign gtpll0_reset_d = (state == ST_GTPLL0_HOLD)  || (state == ST_DRP16_REQ) ||
                          (state == ST_DRP16_ACK);
  logic gtreset_d;
  assign gtreset_d = (state == ST_GTPLL0_HOLD)  || (state == ST_DRP16_REQ) ||
                     (state == ST_DRP16_ACK) || (state == ST_GTPLL0_LOCK);
  logic userrdy_d;
  assign userrdy_d = (state == ST_LOCK_WAIT) ? mmcm_locked : userrdy_q;

  always_ff @(posedge pipe_clk or negedge pipe_rst_n) begin
    if (!pipe_rst_n) begin
      state            <= ST_CFG_WAIT;
      gtpll0_reset_req <= 1'b0;
      gtreset_q        <= 1'b0;
      userrdy_q        <= 1'b0;
    end
    else begin
      state            <= state_nx;
      gtpll0_reset_req <= gtpll0_reset_d;
      gtreset_q        <= gtreset_d;
      userrdy_q        <= userrdy_d;
    end
  end

  always_ff @(posedge pipe_clk or negedge pipe_rst_n) begin
    if (!pipe_rst_n) begin
      gtp.rst.drp_start <= 1'b0;
      gtp.rst.drp_x16   <= 1'b0;
    end
    else begin
      gtp.rst.drp_start <= (state == ST_DRP16_REQ) || (state == ST_DRP20_REQ);
      gtp.rst.drp_x16   <= (state == ST_DRP16_REQ) || (state == ST_DRP16_ACK);
    end
  end

  logic rxusrclk_rst_r1;
  logic rxusrclk_rst_r2;

  always_ff @(posedge pipe_clk) begin
    if (gtpll0_reset_req) begin
      rxusrclk_rst_r1 <= 1'b1;
      rxusrclk_rst_r2 <= 1'b1;
    end
    else begin
      rxusrclk_rst_r1 <= 1'b0;
      rxusrclk_rst_r2 <= rxusrclk_rst_r1;
    end
  end

  logic drp_clk_rst_r1;
  logic drp_clk_rst_r2;

  always_ff @(posedge clk125) begin
    drp_clk_rst_r1 <= (state == ST_CFG_WAIT);
    drp_clk_rst_r2 <= drp_clk_rst_r1;
  end

  assign gtp.rst.gtpll0_reset   = gtpll0_reset_req;
  assign gtp.rst.rxusrclk_reset = rxusrclk_rst_r2;
  assign gtp.rst.drp_clk_reset  = drp_clk_rst_r2;
  assign gtp.rst.gtreset        = gtreset_q;
  assign gtp.rst.userrdy        = userrdy_q;
  assign gtp.rst.txsync_start   = (state == ST_TXSYNC_REQ);
  assign gtp.rst.idle           = (state == ST_IDLE);


endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
