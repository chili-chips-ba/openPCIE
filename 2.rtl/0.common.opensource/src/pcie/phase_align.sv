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

module phase_align
  import link_pkg::*;
(
    input logic clk,
    input logic rst_n,
    input logic slave,
    input logic mmcm_lock,
    input logic active_lane,

    input  logic             txsync_start,
    input  gtp_txsync_stat_t tx_stat,
    output gtp_txsync_ctrl_t tx_ctrl,
    output logic             txsync_done
);

  typedef enum logic [5:0] {
    TX_IDLE      = 6'b000001,
    TX_MMCM_LOCK = 6'b000010,
    TX_START     = 6'b000100,
    TX_PHINIT    = 6'b001000,
    TX_DONE1     = 6'b010000,
    TX_DONE2     = 6'b100000
  } tx_state_e;

  tx_state_e fsm_tx, fsm_tx_nx;

  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic mmcm_r1, mmcm_r2;  // MMCM LOCKED: async
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic
      txstart_r1, txstart_r2;  // txsync_start: pipe_clk, latency only
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic
      txphinit_r1, txphinit_r2, txphinit_r3;  // TXPHINITDONE: async
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic
      txdlyrst_r1, txdlyrst_r2, txdlyrst_r3;  // TXDLYSRESETDONE: async
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic
      txphalign_r1, txphalign_r2, txphalign_r3;  // TXPHALIGNDONE: async

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      mmcm_r1      <= 1'b0;
      mmcm_r2      <= 1'b0;
      txstart_r1   <= 1'b0;
      txstart_r2   <= 1'b0;
      txphinit_r1  <= 1'b0;
      txphinit_r2  <= 1'b0;
      txphinit_r3  <= 1'b0;
      txdlyrst_r1  <= 1'b0;
      txdlyrst_r2  <= 1'b0;
      txdlyrst_r3  <= 1'b0;
      txphalign_r1 <= 1'b0;
      txphalign_r2 <= 1'b0;
      txphalign_r3 <= 1'b0;
    end
    else begin
      mmcm_r1      <= mmcm_lock;
      mmcm_r2      <= mmcm_r1;
      txstart_r1   <= txsync_start;
      txstart_r2   <= txstart_r1;
      txphinit_r1  <= tx_stat.phinitdone;
      txphinit_r2  <= txphinit_r1;
      txphinit_r3  <= txphinit_r2;
      txdlyrst_r1  <= tx_stat.dlysresetdone;
      txdlyrst_r2  <= txdlyrst_r1;
      txdlyrst_r3  <= txdlyrst_r2;
      txphalign_r1 <= tx_stat.phaligndone;
      txphalign_r2 <= txphalign_r1;
      txphalign_r3 <= txphalign_r2;
    end
  end

  logic dlyrst_done_edge;
  assign dlyrst_done_edge = (!txdlyrst_r3 && txdlyrst_r2);
  logic phinit_done_edge;
  assign phinit_done_edge = (!txphinit_r3 && txphinit_r2);
  logic phalign_done_edge;
  assign phalign_done_edge = (!txphalign_r3 && txphalign_r2);

  logic txdlyen, txdlyen_nx;
  logic txsync_done_nx;

  always_comb begin
    fsm_tx_nx      = fsm_tx;
    txdlyen_nx     = txdlyen;
    txsync_done_nx = txsync_done;
    unique case (fsm_tx)
      TX_IDLE:
      if (txstart_r2) begin
        fsm_tx_nx      = TX_MMCM_LOCK;
        txdlyen_nx     = 1'b0;
        txsync_done_nx = 1'b0;
      end
      TX_MMCM_LOCK: begin
        fsm_tx_nx      = mmcm_r2 ? TX_START : TX_MMCM_LOCK;
        txdlyen_nx     = 1'b0;
        txsync_done_nx = 1'b0;
      end
      TX_START: begin
        fsm_tx_nx      = dlyrst_done_edge ? TX_PHINIT : TX_START;
        txdlyen_nx     = 1'b0;
        txsync_done_nx = 1'b0;
      end
      TX_PHINIT: begin
        fsm_tx_nx      = (phinit_done_edge || (!active_lane)) ? TX_DONE1 : TX_PHINIT;
        txdlyen_nx     = 1'b0;
        txsync_done_nx = 1'b0;
      end
      TX_DONE1: begin
        fsm_tx_nx      = (phalign_done_edge || (!active_lane)) ? TX_DONE2 : TX_DONE1;
        txdlyen_nx     = 1'b0;
        txsync_done_nx = 1'b0;
      end
      TX_DONE2:
      if (phalign_done_edge || (!active_lane) || slave) begin
        fsm_tx_nx      = TX_IDLE;
        txdlyen_nx     = !slave;
        txsync_done_nx = 1'b1;
      end
      else begin
        fsm_tx_nx      = TX_DONE2;
        txdlyen_nx     = !slave;
        txsync_done_nx = 1'b0;
      end
    endcase
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      fsm_tx      <= TX_IDLE;
      txdlyen     <= 1'b0;
      txsync_done <= 1'b0;
    end
    else begin
      fsm_tx      <= fsm_tx_nx;
      txdlyen     <= txdlyen_nx;
      txsync_done <= txsync_done_nx;
    end
  end

  assign tx_ctrl.dlysreset = (fsm_tx == TX_START);
  assign tx_ctrl.phinit    = (fsm_tx == TX_PHINIT);
  assign tx_ctrl.phalign   = (fsm_tx == TX_DONE1);
  assign tx_ctrl.dlyen     = txdlyen;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
