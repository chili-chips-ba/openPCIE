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

(* DowngradeIPIdentifiedWarnings = "yes" *)
module init_ctrl #(
  localparam PCIE_SIM_SPEEDUP = "FALSE",
  localparam PCIE_LANE = 1,
  localparam CFG_WAIT_MAX = 6'd63,
  localparam BYPASS_RXCDRLOCK = 1) (
  input                       RST_CLK,
  input                       RST_RXUSRCLK,
  input                       RST_DCLK,
  input                       RST_RST_N,
  input      [PCIE_LANE-1:0]  RST_DRP_DONE,
  input      [PCIE_LANE-1:0]  RST_RXPMARESETDONE,
  input                       RST_PLLLOCK,
  input      [PCIE_LANE-1:0]  RST_RATE_IDLE,
  input      [PCIE_LANE-1:0]  RST_RXCDRLOCK,
  input                       RST_MMCM_LOCK,
  input      [PCIE_LANE-1:0]  RST_RESETDONE,
  input      [PCIE_LANE-1:0]  RST_PHYSTATUS,
  input      [PCIE_LANE-1:0]  RST_TXSYNC_DONE,

  output                      RST_CPLLRESET,
  output                      RST_CPLLPD,
  output logic                RST_DRP_START,
  output logic                RST_DRP_X16,
  output                      RST_RXUSRCLK_RESET,
  output                      RST_DCLK_RESET,
  output                      RST_GTRESET,
  output                      RST_USERRDY,
  output                      RST_TXSYNC_START,
  output                      RST_IDLE,
  output     [4:0]            RST_FSM
);

  typedef enum logic [4:0] {
    ST_IDLE, ST_CFG_WAIT, ST_PLL_HOLD, ST_DRP16_REQ, ST_DRP16_ACK,
    ST_PLL_LOCK, ST_GT_RELEASE, ST_RXPMA_UP, ST_RXPMA_DN, ST_DRP20_REQ,
    ST_DRP20_ACK, ST_LOCK_WAIT, ST_RESET_DONE, ST_TXSYNC_REQ, ST_TXSYNC_ACK
  } state_e;

  state_e state = ST_CFG_WAIT;
  state_e state_nx;

  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANE-1:0] drp_done_r1,       drp_done_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANE-1:0] rxpma_r1,          rxpma_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic                 plllock_r1,        plllock_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANE-1:0] rate_idle_r1,      rate_idle_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANE-1:0] rxcdrlock_r1,      rxcdrlock_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic                 mmcmlock_r1,       mmcmlock_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANE-1:0] resetdone_r1,      resetdone_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANE-1:0] phystatus_r1,      phystatus_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANE-1:0] txsyncdone_r1,     txsyncdone_r2;

  always_ff @(posedge RST_CLK) begin
    if (!RST_RST_N) begin
      {drp_done_r1, rxpma_r1, rate_idle_r1, rxcdrlock_r1, resetdone_r1, phystatus_r1, txsyncdone_r1} <= '0;
      {drp_done_r2, rxpma_r2, rate_idle_r2, rxcdrlock_r2, resetdone_r2, phystatus_r2, txsyncdone_r2} <= '0;
      {plllock_r1, mmcmlock_r1, plllock_r2, mmcmlock_r2} <= '0;
    end else begin
      drp_done_r1  <= RST_DRP_DONE;       drp_done_r2  <= drp_done_r1;
      rxpma_r1     <= RST_RXPMARESETDONE; rxpma_r2     <= rxpma_r1;
      plllock_r1   <= RST_PLLLOCK;        plllock_r2   <= plllock_r1;
      rate_idle_r1 <= RST_RATE_IDLE;      rate_idle_r2 <= rate_idle_r1;
      rxcdrlock_r1 <= RST_RXCDRLOCK;      rxcdrlock_r2 <= rxcdrlock_r1;
      mmcmlock_r1  <= RST_MMCM_LOCK;      mmcmlock_r2  <= mmcmlock_r1;
      resetdone_r1 <= RST_RESETDONE;      resetdone_r2 <= resetdone_r1;
      phystatus_r1 <= RST_PHYSTATUS;      phystatus_r2 <= phystatus_r1;
      txsyncdone_r1<= RST_TXSYNC_DONE;    txsyncdone_r2<= txsyncdone_r1;
    end
  end

  wire sim_fast     = (PCIE_SIM_SPEEDUP == "TRUE");
  wire pll_unlocked = ~plllock_r2;
  wire pll_locked   =  plllock_r2;
  wire resetdone_lo = &(~resetdone_r2);
  wire resetdone_hi = &resetdone_r2;
  wire drp_busy     = &(~drp_done_r2);
  wire drp_ready    = &drp_done_r2;
  wire rxpma_hi     = &rxpma_r2;
  wire rxpma_lo     = &(~rxpma_r2);
  wire phystatus_lo = &(~phystatus_r2);
  wire txsync_lo    = &(~txsyncdone_r2);
  wire txsync_hi    = &txsyncdone_r2;
  wire locks_ok     = mmcmlock_r2 && (&rxcdrlock_r2 || (BYPASS_RXCDRLOCK == 1));

  logic [5:0] cfg_wait_cnt = 6'd0;

  always_ff @(posedge RST_CLK) begin
    if      (!RST_RST_N)                  cfg_wait_cnt <= 6'd0;
    else if (state != ST_CFG_WAIT)        cfg_wait_cnt <= 6'd0;
    else if (cfg_wait_cnt < CFG_WAIT_MAX) cfg_wait_cnt <= cfg_wait_cnt + 6'd1;
  end
  wire cfg_wait_done = (cfg_wait_cnt == CFG_WAIT_MAX);

  always_comb begin
    state_nx = state;
    unique case (state)
      ST_IDLE       : state_nx = ST_IDLE;
      ST_CFG_WAIT   : state_nx = cfg_wait_done                    ? ST_PLL_HOLD    : ST_CFG_WAIT;
      ST_PLL_HOLD   : state_nx = (pll_unlocked && resetdone_lo)   ? ST_DRP16_REQ   : ST_PLL_HOLD;
      ST_DRP16_REQ  : state_nx = drp_busy                        ? ST_DRP16_ACK   : ST_DRP16_REQ;
      ST_DRP16_ACK  : state_nx = drp_ready                       ? ST_PLL_LOCK    : ST_DRP16_ACK;
      ST_PLL_LOCK   : state_nx = pll_locked                      ? ST_GT_RELEASE  : ST_PLL_LOCK;
      ST_GT_RELEASE : state_nx = ST_RXPMA_UP;
      ST_RXPMA_UP   : state_nx = (rxpma_hi || sim_fast)          ? ST_RXPMA_DN    : ST_RXPMA_UP;
      ST_RXPMA_DN   : state_nx = (rxpma_lo || sim_fast)          ? ST_DRP20_REQ   : ST_RXPMA_DN;
      ST_DRP20_REQ  : state_nx = drp_busy                        ? ST_DRP20_ACK   : ST_DRP20_REQ;
      ST_DRP20_ACK  : state_nx = drp_ready                       ? ST_LOCK_WAIT   : ST_DRP20_ACK;
      ST_LOCK_WAIT  : state_nx = locks_ok                        ? ST_RESET_DONE  : ST_LOCK_WAIT;
      ST_RESET_DONE : state_nx = (resetdone_hi && phystatus_lo)  ? ST_TXSYNC_REQ  : ST_RESET_DONE;
      ST_TXSYNC_REQ : state_nx = txsync_lo                       ? ST_TXSYNC_ACK  : ST_TXSYNC_REQ;
      ST_TXSYNC_ACK : state_nx = txsync_hi                       ? ST_IDLE        : ST_TXSYNC_ACK;
      default       : state_nx = ST_CFG_WAIT;
    endcase
  end

  logic cpllreset_q = 1'b0;
  logic gtreset_q   = 1'b0;
  logic userrdy_q   = 1'b0;

  wire cpllreset_d = (state == ST_PLL_HOLD)  || (state == ST_DRP16_REQ) || (state == ST_DRP16_ACK);
  wire gtreset_d   = (state == ST_PLL_HOLD)  || (state == ST_DRP16_REQ) || (state == ST_DRP16_ACK) || (state == ST_PLL_LOCK);
  wire userrdy_d   = (state == ST_LOCK_WAIT) ? locks_ok : userrdy_q;

  always_ff @(posedge RST_CLK) begin
    if (!RST_RST_N) begin
      state       <= ST_CFG_WAIT;
      cpllreset_q <= 1'b0;
      gtreset_q   <= 1'b0;
      userrdy_q   <= 1'b0;
    end else begin
      state       <= state_nx;
      cpllreset_q <= cpllreset_d;
      gtreset_q   <= gtreset_d;
      userrdy_q   <= userrdy_d;
    end
  end

  always_ff @(posedge RST_CLK) begin
    if (!RST_RST_N) begin
      RST_DRP_START <= 1'b0;
      RST_DRP_X16   <= 1'b0;
    end else begin
      RST_DRP_START <= (state == ST_DRP16_REQ) || (state == ST_DRP20_REQ);
      RST_DRP_X16   <= (state == ST_DRP16_REQ) || (state == ST_DRP16_ACK);
    end
  end

  logic rxusrclk_rst_r1 = 1'b0;
  logic rxusrclk_rst_r2 = 1'b0;

  always_ff @(posedge RST_RXUSRCLK) begin
    if (cpllreset_q) begin
      rxusrclk_rst_r1 <= 1'b1;
      rxusrclk_rst_r2 <= 1'b1;
    end else begin
      rxusrclk_rst_r1 <= 1'b0;
      rxusrclk_rst_r2 <= rxusrclk_rst_r1;
    end
  end

  logic dclk_rst_r1 = 1'b0;
  logic dclk_rst_r2 = 1'b0;

  always_ff @(posedge RST_DCLK) begin
    dclk_rst_r1 <= (state == ST_CFG_WAIT);
    dclk_rst_r2 <= dclk_rst_r1;
  end

  assign RST_CPLLRESET      = cpllreset_q;
  assign RST_CPLLPD         = 1'b0;
  assign RST_RXUSRCLK_RESET = rxusrclk_rst_r2;
  assign RST_DCLK_RESET     = dclk_rst_r2;
  assign RST_GTRESET        = gtreset_q;
  assign RST_USERRDY        = userrdy_q;
  assign RST_TXSYNC_START   = (state == ST_TXSYNC_REQ);
  assign RST_IDLE           = (state == ST_IDLE);
  assign RST_FSM            = state;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
