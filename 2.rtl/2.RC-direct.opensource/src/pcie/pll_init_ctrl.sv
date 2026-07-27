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

module pll_init_ctrl
  import link_pkg::*;
#(
  localparam PCIE_PLL_SEL = "CPLL",
  localparam PCIE_POWER_SAVING = "TRUE",
  localparam BYPASS_COARSE_OVRD = 1) (
  input                           QRST_CLK,
  input                           QRST_RST_N,
  input                           QRST_MMCM_LOCK,
  input      [PCIE_LANES-1:0]     QRST_CPLLLOCK,
  input      [(PCIE_LANES-1)>>2:0] QRST_DRP_DONE,
  input      [(PCIE_LANES-1)>>2:0] QRST_QPLLLOCK,
  input      [1:0]                QRST_RATE,
  input      [PCIE_LANES-1:0]     QRST_QPLLRESET_IN,
  input      [PCIE_LANES-1:0]     QRST_QPLLPD_IN,

  output                          QRST_OVRD,
  output                          QRST_DRP_START,
  output                          QRST_QPLLRESET_OUT,
  output                          QRST_QPLLPD_OUT,
  output                          QRST_IDLE,
  output     [3:0]                QRST_FSM
);

  localparam bit PLL_IS_QPLL = (PCIE_PLL_SEL == "QPLL");
  localparam bit PLL_IS_CPLL = (PCIE_PLL_SEL == "CPLL");

  typedef enum logic [3:0] {
    ST_IDLE=4'd1, ST_WAIT_LOCK=4'd2, ST_MMCM_LOCK=4'd3, ST_DRP_NOM_REQ=4'd4,
    ST_DRP_NOM_ACK=4'd5, ST_QPLL_LOCK=4'd6, ST_DRP_OPT_REQ=4'd7, ST_DRP_OPT_ACK=4'd8,
    ST_QPLL_RESET=4'd9, ST_QPLL_LOCK2=4'd10, ST_QPLL_PDRESET=4'd11, ST_QPLL_PD=4'd12
  } state_e;

  state_e state = ST_WAIT_LOCK, state_nx;

  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic                 mmcm_r1, mmcm_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANES-1:0] cplllock_r1, cplllock_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [(PCIE_LANES-1)>>2:0] drp_done_r1, drp_done_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [(PCIE_LANES-1)>>2:0] qplllock_r1, qplllock_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [1:0]           rate_r1, rate_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANES-1:0] qpllrst_in_r1, qpllrst_in_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANES-1:0] qpllpd_in_r1,  qpllpd_in_r2;

  always_ff @(posedge QRST_CLK) begin
    if (!QRST_RST_N) begin
      mmcm_r1 <= 1'b0;                   mmcm_r2 <= 1'b0;
      cplllock_r1 <= {PCIE_LANES{1'b1}};  cplllock_r2 <= {PCIE_LANES{1'b1}};
      drp_done_r1 <= '0;                 drp_done_r2 <= '0;
      qplllock_r1 <= '0;                 qplllock_r2 <= '0;
      rate_r1 <= 2'd0;                   rate_r2 <= 2'd0;
      qpllrst_in_r1 <= {PCIE_LANES{1'b1}};qpllrst_in_r2 <= {PCIE_LANES{1'b1}};
      qpllpd_in_r1 <= '0;                qpllpd_in_r2 <= '0;
    end else begin
      mmcm_r1 <= QRST_MMCM_LOCK;         mmcm_r2 <= mmcm_r1;
      cplllock_r1 <= QRST_CPLLLOCK;      cplllock_r2 <= cplllock_r1;
      drp_done_r1 <= QRST_DRP_DONE;      drp_done_r2 <= drp_done_r1;
      qplllock_r1 <= QRST_QPLLLOCK;      qplllock_r2 <= qplllock_r1;
      rate_r1 <= QRST_RATE;              rate_r2 <= rate_r1;
      qpllrst_in_r1 <= QRST_QPLLRESET_IN;qpllrst_in_r2 <= qpllrst_in_r1;
      qpllpd_in_r1 <= QRST_QPLLPD_IN;    qpllpd_in_r2 <= qpllpd_in_r1;
    end
  end

  wire locks_lost = (&(~cplllock_r2)) && (&(~qplllock_r2));
  wire mmcm_cpll  = mmcm_r2 && (&cplllock_r2);
  wire drp_busy   = &(~drp_done_r2);
  wire drp_ready  = &drp_done_r2;
  wire qpll_locked= &qplllock_r2;
  wire qpll_unlock= &(~qplllock_r2);
  wire cpll_hold  = PLL_IS_CPLL && (rate_r2 != 2'd2);

  logic ovrd = 1'b0, ovrd_nx;
  logic qpllreset = 1'b1, qpllreset_nx;
  logic qpllpd = 1'b0, qpllpd_nx;

  always_comb begin
    state_nx     = state;
    ovrd_nx      = ovrd;
    qpllreset_nx = qpllreset;
    qpllpd_nx    = qpllpd;
    unique case (state)
      ST_IDLE: begin
        state_nx     = ST_IDLE;
        qpllreset_nx = &qpllrst_in_r2;
        qpllpd_nx    = &qpllpd_in_r2;
      end
      ST_WAIT_LOCK  : state_nx = locks_lost ? ST_MMCM_LOCK   : ST_WAIT_LOCK;
      ST_MMCM_LOCK  : state_nx = mmcm_cpll   ? ST_DRP_NOM_REQ : ST_MMCM_LOCK;
      ST_DRP_NOM_REQ: state_nx = drp_busy    ? ST_DRP_NOM_ACK : ST_DRP_NOM_REQ;
      ST_DRP_NOM_ACK: state_nx = drp_ready   ? ST_QPLL_LOCK   : ST_DRP_NOM_ACK;
      ST_QPLL_LOCK: begin
        state_nx     = qpll_locked ? ((BYPASS_COARSE_OVRD == 1) ? ST_QPLL_PDRESET : ST_DRP_OPT_REQ) : ST_QPLL_LOCK;
        qpllreset_nx = 1'b0;
      end
      ST_DRP_OPT_REQ: begin
        state_nx = drp_busy ? ST_DRP_OPT_ACK : ST_DRP_OPT_REQ;
        ovrd_nx  = 1'b1;
      end
      ST_DRP_OPT_ACK: if (drp_ready) begin
                        state_nx     = PLL_IS_QPLL ? ST_QPLL_RESET : ST_QPLL_PDRESET;
                        qpllreset_nx = PLL_IS_QPLL;
                      end else
                        state_nx = ST_DRP_OPT_ACK;
      ST_QPLL_RESET: begin
        state_nx     = qpll_unlock ? ST_QPLL_LOCK2 : ST_QPLL_RESET;
        qpllreset_nx = 1'b1;
        qpllpd_nx    = 1'b0;
      end
      ST_QPLL_LOCK2: begin
        state_nx     = qpll_locked ? ST_IDLE : ST_QPLL_LOCK2;
        qpllreset_nx = 1'b0;
        qpllpd_nx    = 1'b0;
      end
      ST_QPLL_PDRESET: begin
        state_nx     = ST_QPLL_PD;
        qpllreset_nx = cpll_hold;
      end
      ST_QPLL_PD: begin
        state_nx  = ST_IDLE;
        qpllpd_nx = cpll_hold;
      end
      default: begin
        state_nx     = ST_WAIT_LOCK;
        ovrd_nx      = 1'b0;
        qpllreset_nx = 1'b0;
        qpllpd_nx    = 1'b0;
      end
    endcase
  end

  always_ff @(posedge QRST_CLK) begin
    if (!QRST_RST_N) begin
      state     <= ST_WAIT_LOCK;
      ovrd      <= 1'b0;
      qpllreset <= 1'b1;
      qpllpd    <= 1'b0;
    end else begin
      state     <= state_nx;
      ovrd      <= ovrd_nx;
      qpllreset <= qpllreset_nx;
      qpllpd    <= qpllpd_nx;
    end
  end

  assign QRST_OVRD          = ovrd;
  assign QRST_DRP_START     = (state == ST_DRP_NOM_REQ) || (state == ST_DRP_OPT_REQ);
  assign QRST_QPLLRESET_OUT = qpllreset;
  assign QRST_QPLLPD_OUT    = (PCIE_POWER_SAVING == "FALSE") ? 1'b0 : qpllpd;
  assign QRST_IDLE          = (state == ST_IDLE);
  assign QRST_FSM           = state;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
