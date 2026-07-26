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
module phase_align #(
  localparam PCIE_GT_DEVICE = "GTP",
  localparam PCIE_TXBUF_EN = "FALSE",
  localparam PCIE_RXBUF_EN = "TRUE",
  localparam PCIE_TXSYNC_MODE = 0,
  localparam PCIE_RXSYNC_MODE = 0,
  localparam PCIE_LANE = 1,
  localparam PCIE_LINK_SPEED = 3,
  localparam BYPASS_TXDELAY_ALIGN = 0,
  localparam BYPASS_RXDELAY_ALIGN = 0) (
  input               SYNC_CLK,
  input               SYNC_RST_N,
  input               SYNC_SLAVE,
  input               SYNC_GEN3,
  input               SYNC_RATE_IDLE,
  input               SYNC_MMCM_LOCK,
  input               SYNC_RXELECIDLE,
  input               SYNC_RXCDRLOCK,
  input               SYNC_ACTIVE_LANE,

  input               SYNC_TXSYNC_START,
  input               SYNC_TXPHINITDONE,
  input               SYNC_TXDLYSRESETDONE,
  input               SYNC_TXPHALIGNDONE,
  input               SYNC_TXSYNCDONE,

  input               SYNC_RXSYNC_START,
  input               SYNC_RXDLYSRESETDONE,
  input               SYNC_RXPHALIGNDONE_M,
  input               SYNC_RXPHALIGNDONE_S,
  input               SYNC_RXSYNC_DONEM_IN,
  input               SYNC_RXSYNCDONE,

  output              SYNC_TXPHDLYRESET,
  output              SYNC_TXPHALIGN,
  output              SYNC_TXPHALIGNEN,
  output              SYNC_TXPHINIT,
  output              SYNC_TXDLYBYPASS,
  output              SYNC_TXDLYSRESET,
  output              SYNC_TXDLYEN,
  output              SYNC_TXSYNC_DONE,
  output     [5:0]    SYNC_FSM_TX,

  output              SYNC_RXPHALIGN,
  output              SYNC_RXPHALIGNEN,
  output              SYNC_RXDLYBYPASS,
  output              SYNC_RXDLYSRESET,
  output              SYNC_RXDLYEN,
  output              SYNC_RXDDIEN,
  output              SYNC_RXSYNC_DONEM_OUT,
  output              SYNC_RXSYNC_DONE,
  output     [6:0]    SYNC_FSM_RX
);

  typedef enum logic [5:0] {
    TX_IDLE      = 6'b000001,
    TX_MMCM_LOCK = 6'b000010,
    TX_START     = 6'b000100,
    TX_PHINIT    = 6'b001000,
    TX_DONE1     = 6'b010000,
    TX_DONE2     = 6'b100000
  } tx_state_e;

  tx_state_e fsm_tx = TX_IDLE, fsm_tx_nx;

  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic mmcm_r1, mmcm_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic txstart_r1, txstart_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic txphinit_r1, txphinit_r2, txphinit_r3;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic txdlyrst_r1, txdlyrst_r2, txdlyrst_r3;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic txphalign_r1, txphalign_r2, txphalign_r3;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic txsyncdone_r1, txsyncdone_r2, txsyncdone_r3;

  always_ff @(posedge SYNC_CLK) begin
    if (!SYNC_RST_N) begin
      mmcm_r1<=1'b0;      mmcm_r2<=1'b0;
      txstart_r1<=1'b0;   txstart_r2<=1'b0;
      txphinit_r1<=1'b0;  txphinit_r2<=1'b0;  txphinit_r3<=1'b0;
      txdlyrst_r1<=1'b0;  txdlyrst_r2<=1'b0;  txdlyrst_r3<=1'b0;
      txphalign_r1<=1'b0; txphalign_r2<=1'b0; txphalign_r3<=1'b0;
      txsyncdone_r1<=1'b0;txsyncdone_r2<=1'b0;txsyncdone_r3<=1'b0;
    end else begin
      mmcm_r1<=SYNC_MMCM_LOCK;          mmcm_r2<=mmcm_r1;
      txstart_r1<=SYNC_TXSYNC_START;    txstart_r2<=txstart_r1;
      txphinit_r1<=SYNC_TXPHINITDONE;   txphinit_r2<=txphinit_r1;   txphinit_r3<=txphinit_r2;
      txdlyrst_r1<=SYNC_TXDLYSRESETDONE;txdlyrst_r2<=txdlyrst_r1;   txdlyrst_r3<=txdlyrst_r2;
      txphalign_r1<=SYNC_TXPHALIGNDONE; txphalign_r2<=txphalign_r1; txphalign_r3<=txphalign_r2;
      txsyncdone_r1<=SYNC_TXSYNCDONE;   txsyncdone_r2<=txsyncdone_r1;txsyncdone_r3<=txsyncdone_r2;
    end
  end

  wire dlyrst_done_edge  = (!txdlyrst_r3  && txdlyrst_r2);
  wire phinit_done_edge  = (!txphinit_r3  && txphinit_r2);
  wire phalign_done_edge = (!txphalign_r3 && txphalign_r2);

  logic txdlyen = 1'b0, txdlyen_nx;
  logic txsync_done = 1'b0, txsync_done_nx;

  always_comb begin
    fsm_tx_nx      = fsm_tx;
    txdlyen_nx     = txdlyen;
    txsync_done_nx = txsync_done;
    unique case (fsm_tx)
      TX_IDLE:
        if (txstart_r2) begin
          fsm_tx_nx = TX_MMCM_LOCK; txdlyen_nx = 1'b0; txsync_done_nx = 1'b0;
        end
      TX_MMCM_LOCK: begin
        fsm_tx_nx = mmcm_r2 ? TX_START : TX_MMCM_LOCK;
        txdlyen_nx = 1'b0; txsync_done_nx = 1'b0;
      end
      TX_START: begin
        fsm_tx_nx = dlyrst_done_edge ? TX_PHINIT : TX_START;
        txdlyen_nx = 1'b0; txsync_done_nx = 1'b0;
      end
      TX_PHINIT: begin
        fsm_tx_nx = (phinit_done_edge || (!SYNC_ACTIVE_LANE)) ? TX_DONE1 : TX_PHINIT;
        txdlyen_nx = 1'b0; txsync_done_nx = 1'b0;
      end
      TX_DONE1: begin
        fsm_tx_nx = (phalign_done_edge || (!SYNC_ACTIVE_LANE)) ? TX_DONE2 : TX_DONE1;
        txdlyen_nx = 1'b0; txsync_done_nx = 1'b0;
      end
      TX_DONE2:
        if (phalign_done_edge || (!SYNC_ACTIVE_LANE) || SYNC_SLAVE) begin
          fsm_tx_nx = TX_IDLE; txdlyen_nx = !SYNC_SLAVE; txsync_done_nx = 1'b1;
        end else begin
          fsm_tx_nx = TX_DONE2; txdlyen_nx = !SYNC_SLAVE; txsync_done_nx = 1'b0;
        end
      default: begin
        fsm_tx_nx = TX_IDLE; txdlyen_nx = 1'b0; txsync_done_nx = 1'b0;
      end
    endcase
  end

  always_ff @(posedge SYNC_CLK) begin
    if (!SYNC_RST_N) begin
      fsm_tx <= TX_IDLE; txdlyen <= 1'b0; txsync_done <= 1'b0;
    end else begin
      fsm_tx <= fsm_tx_nx; txdlyen <= txdlyen_nx; txsync_done <= txsync_done_nx;
    end
  end

  assign SYNC_TXPHALIGNEN  = 1'b1;
  assign SYNC_TXDLYBYPASS  = 1'b0;
  assign SYNC_TXDLYSRESET  = (fsm_tx == TX_START);
  assign SYNC_TXPHDLYRESET = 1'b0;
  assign SYNC_TXPHINIT     = (fsm_tx == TX_PHINIT);
  assign SYNC_TXPHALIGN    = (fsm_tx == TX_DONE1);
  assign SYNC_TXDLYEN      = txdlyen;
  assign SYNC_TXSYNC_DONE  = txsync_done;
  assign SYNC_FSM_TX       = fsm_tx;

  assign SYNC_RXPHALIGNEN      = 1'b0;
  assign SYNC_RXDLYBYPASS      = 1'b1;
  assign SYNC_RXDLYSRESET      = 1'b0;
  assign SYNC_RXPHALIGN        = 1'b0;
  assign SYNC_RXDLYEN          = 1'b0;
  assign SYNC_RXDDIEN          = 1'b0;
  assign SYNC_RXSYNC_DONE      = 1'b0;
  assign SYNC_RXSYNC_DONEM_OUT = 1'b0;
  assign SYNC_FSM_RX           = 7'b0000001;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
