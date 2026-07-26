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
module margin_tuner #(
  localparam PCIE_SIM_MODE = "FALSE",
  localparam PCIE_GT_DEVICE = "GTP",
  localparam PCIE_RXEQ_MODE_GEN3 = 1) (
  input               EQ_CLK,
  input               EQ_RST_N,
  input               EQ_GEN3,

  input      [1:0]    EQ_TXEQ_CONTROL,
  input      [3:0]    EQ_TXEQ_PRESET,
  input      [3:0]    EQ_TXEQ_PRESET_DEFAULT,
  input      [5:0]    EQ_TXEQ_DEEMPH_IN,

  input      [1:0]    EQ_RXEQ_CONTROL,
  input      [2:0]    EQ_RXEQ_PRESET,
  input      [5:0]    EQ_RXEQ_LFFS,
  input      [3:0]    EQ_RXEQ_TXPRESET,
  input               EQ_RXEQ_USER_EN,
  input      [17:0]   EQ_RXEQ_USER_TXCOEFF,
  input               EQ_RXEQ_USER_MODE,

  output              EQ_TXEQ_DEEMPH,
  output     [4:0]    EQ_TXEQ_PRECURSOR,
  output     [6:0]    EQ_TXEQ_MAINCURSOR,
  output     [4:0]    EQ_TXEQ_POSTCURSOR,
  output     [17:0]   EQ_TXEQ_DEEMPH_OUT,
  output              EQ_TXEQ_DONE,
  output     [5:0]    EQ_TXEQ_FSM,

  output     [17:0]   EQ_RXEQ_NEW_TXCOEFF,
  output              EQ_RXEQ_LFFS_SEL,
  output              EQ_RXEQ_ADAPT_DONE,
  output              EQ_RXEQ_DONE,
  output     [5:0]    EQ_RXEQ_FSM
);

  function automatic logic [18:0] txeq_preset_lut(input logic [3:0] sel);
    unique case (sel)
      4'd0 : txeq_preset_lut = {6'd20, 7'd60, 6'd0 };
      4'd1 : txeq_preset_lut = {6'd13, 7'd68, 6'd0 };
      4'd2 : txeq_preset_lut = {6'd16, 7'd64, 6'd0 };
      4'd3 : txeq_preset_lut = {6'd10, 7'd70, 6'd0 };
      4'd4 : txeq_preset_lut = {6'd0,  7'd80, 6'd0 };
      4'd5 : txeq_preset_lut = {6'd0,  7'd72, 6'd8 };
      4'd6 : txeq_preset_lut = {6'd0,  7'd70, 6'd10};
      4'd7 : txeq_preset_lut = {6'd16, 7'd56, 6'd8 };
      4'd8 : txeq_preset_lut = {6'd10, 7'd60, 6'd10};
      4'd9 : txeq_preset_lut = {6'd0,  7'd68, 6'd13};
      4'd10: txeq_preset_lut = {6'd25, 7'd56, 6'd0 };
      default: txeq_preset_lut = 19'd4;
    endcase
  endfunction

  typedef enum logic [5:0] {
    TX_IDLE=6'b000001, TX_PRESET=6'b000010, TX_TXCOEFF=6'b000100,
    TX_REMAP=6'b001000, TX_QUERY=6'b010000, TX_DONE=6'b100000
  } txeq_state_e;
  typedef enum logic [5:0] {
    RX_IDLE=6'b000001, RX_PRESET=6'b000010, RX_TXCOEFF=6'b000100,
    RX_LF=6'b001000, RX_NEWREQ=6'b010000, RX_DONE=6'b100000
  } rxeq_state_e;

  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic        gen3_r1, gen3_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [1:0]  txctl_r1, txctl_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [3:0]  txpre_r1, txpre_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [5:0]  txdeemph_r1, txdeemph_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [1:0]  rxctl_r1, rxctl_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [2:0]  rxpre_r1, rxpre_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [5:0]  rxlffs_r1, rxlffs_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [3:0]  rxtxpre_r1, rxtxpre_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic        rxuen_r1, rxuen_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [17:0] rxucoeff_r1, rxucoeff_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic        rxumode_r1, rxumode_r2;

  always_ff @(posedge EQ_CLK)
    if (!EQ_RST_N) begin
      gen3_r1<=1'b0;      gen3_r2<=1'b0;
      txctl_r1<=2'd0;     txctl_r2<=2'd0;
      txpre_r1<=4'd0;     txpre_r2<=4'd0;
      txdeemph_r1<=6'd1;  txdeemph_r2<=6'd1;
      rxctl_r1<=2'd0;     rxctl_r2<=2'd0;
      rxpre_r1<=3'd0;     rxpre_r2<=3'd0;
      rxlffs_r1<=6'd0;    rxlffs_r2<=6'd0;
      rxtxpre_r1<=4'd0;   rxtxpre_r2<=4'd0;
      rxuen_r1<=1'b0;     rxuen_r2<=1'b0;
      rxucoeff_r1<=18'd0; rxucoeff_r2<=18'd0;
      rxumode_r1<=1'b0;   rxumode_r2<=1'b0;
    end else begin
      gen3_r1<=EQ_GEN3;                 gen3_r2<=gen3_r1;
      txctl_r1<=EQ_TXEQ_CONTROL;        txctl_r2<=txctl_r1;
      txpre_r1<=EQ_TXEQ_PRESET;         txpre_r2<=txpre_r1;
      txdeemph_r1<=EQ_TXEQ_DEEMPH_IN;   txdeemph_r2<=txdeemph_r1;
      rxctl_r1<=EQ_RXEQ_CONTROL;        rxctl_r2<=rxctl_r1;
      rxpre_r1<=EQ_RXEQ_PRESET;         rxpre_r2<=rxpre_r1;
      rxlffs_r1<=EQ_RXEQ_LFFS;          rxlffs_r2<=rxlffs_r1;
      rxtxpre_r1<=EQ_RXEQ_TXPRESET;     rxtxpre_r2<=rxtxpre_r1;
      rxuen_r1<=EQ_RXEQ_USER_EN;        rxuen_r2<=rxuen_r1;
      rxucoeff_r1<=EQ_RXEQ_USER_TXCOEFF;rxucoeff_r2<=rxucoeff_r1;
      rxumode_r1<=EQ_RXEQ_USER_MODE;    rxumode_r2<=rxumode_r1;
    end

  logic [18:0] txeq_preset      = 19'd0;
  logic        txeq_preset_done = 1'b0;

  txeq_state_e fsm_tx = TX_IDLE, fsm_tx_nx;

  always_ff @(posedge EQ_CLK)
    if (!EQ_RST_N) begin
      txeq_preset      <= txeq_preset_lut(EQ_TXEQ_PRESET_DEFAULT);
      txeq_preset_done <= 1'b0;
    end else if (fsm_tx == TX_PRESET) begin
      txeq_preset      <= txeq_preset_lut(txpre_r2);
      txeq_preset_done <= 1'b1;
    end else begin
      txeq_preset      <= txeq_preset;
      txeq_preset_done <= 1'b0;
    end

  logic [18:0] txeq_txcoeff = 19'd0, txeq_txcoeff_nx;
  logic [1:0]  txeq_cnt     = 2'd0,  txeq_cnt_nx;
  logic        txeq_done    = 1'b0,  txeq_done_nx;

  always_comb begin
    fsm_tx_nx       = fsm_tx;
    txeq_txcoeff_nx = txeq_txcoeff;
    txeq_cnt_nx     = 2'd0;
    txeq_done_nx    = 1'b0;
    unique case (fsm_tx)
      TX_IDLE:
        unique case (txctl_r2)
          2'd1: fsm_tx_nx = TX_PRESET;
          2'd2: begin
            fsm_tx_nx       = TX_TXCOEFF;
            txeq_txcoeff_nx = {txdeemph_r2, txeq_txcoeff[18:6]};
            txeq_cnt_nx     = 2'd1;
          end
          2'd3: fsm_tx_nx = TX_QUERY;
          default: fsm_tx_nx = TX_IDLE;
        endcase
      TX_PRESET: begin
        fsm_tx_nx       = txeq_preset_done ? TX_DONE : TX_PRESET;
        txeq_txcoeff_nx = txeq_preset;
      end
      TX_TXCOEFF: begin
        fsm_tx_nx       = (txeq_cnt == 2'd2) ? TX_REMAP : TX_TXCOEFF;
        txeq_txcoeff_nx = (txeq_cnt == 2'd1) ? {1'b0, txdeemph_r2, txeq_txcoeff[18:7]}
                                             : {txdeemph_r2, txeq_txcoeff[18:6]};
        txeq_cnt_nx     = txeq_cnt + 2'd1;
      end
      TX_REMAP: begin
        fsm_tx_nx       = TX_DONE;
        txeq_txcoeff_nx = txeq_txcoeff << 1;
      end
      TX_QUERY: begin
        fsm_tx_nx       = TX_DONE;
      end
      TX_DONE: begin
        fsm_tx_nx    = (txctl_r2 == 2'd0) ? TX_IDLE : TX_DONE;
        txeq_done_nx = 1'b1;
      end
      default: begin
        fsm_tx_nx = TX_IDLE; txeq_txcoeff_nx = 19'd0;
      end
    endcase
  end

  always_ff @(posedge EQ_CLK)
    if (!EQ_RST_N) begin
      fsm_tx <= TX_IDLE; txeq_txcoeff <= 19'd0; txeq_cnt <= 2'd0; txeq_done <= 1'b0;
    end else begin
      fsm_tx <= fsm_tx_nx; txeq_txcoeff <= txeq_txcoeff_nx; txeq_cnt <= txeq_cnt_nx; txeq_done <= txeq_done_nx;
    end

  wire         rxeqscan_lffs_sel;
  wire         rxeqscan_preset_done;
  wire [17:0]  rxeqscan_new_txcoeff;
  wire         rxeqscan_new_txcoeff_done;
  wire         rxeqscan_adapt_done;

  rxeq_state_e fsm_rx = RX_IDLE, fsm_rx_nx;
  logic [2:0]  rxeq_preset       = 3'd0,  rxeq_preset_nx;
  logic        rxeq_preset_valid = 1'b0,  rxeq_preset_valid_nx;
  logic [3:0]  rxeq_txpreset     = 4'd0,  rxeq_txpreset_nx;
  logic [17:0] rxeq_txcoeff      = 18'd0, rxeq_txcoeff_nx;
  logic [2:0]  rxeq_cnt          = 3'd0,  rxeq_cnt_nx;
  logic [5:0]  rxeq_fs           = 6'd0,  rxeq_fs_nx;
  logic [5:0]  rxeq_lf           = 6'd0,  rxeq_lf_nx;
  logic        rxeq_new_txcoeff_req = 1'b0, rxeq_new_txcoeff_req_nx;
  logic [17:0] rxeq_new_txcoeff  = 18'd0, rxeq_new_txcoeff_nx;
  logic        rxeq_lffs_sel     = 1'b0,  rxeq_lffs_sel_nx;
  logic        rxeq_adapt_done_r = 1'b0,  rxeq_adapt_done_r_nx;
  logic        rxeq_adapt_done   = 1'b0,  rxeq_adapt_done_nx;
  logic        rxeq_done         = 1'b0,  rxeq_done_nx;

  always_comb begin
    fsm_rx_nx               = fsm_rx;
    rxeq_preset_nx          = rxeq_preset;
    rxeq_preset_valid_nx    = 1'b0;
    rxeq_txpreset_nx        = rxeq_txpreset;
    rxeq_txcoeff_nx         = rxeq_txcoeff;
    rxeq_cnt_nx             = 3'd0;
    rxeq_fs_nx              = rxeq_fs;
    rxeq_lf_nx              = rxeq_lf;
    rxeq_new_txcoeff_req_nx = 1'b0;
    rxeq_new_txcoeff_nx     = rxeq_new_txcoeff;
    rxeq_lffs_sel_nx        = rxeq_lffs_sel;
    rxeq_adapt_done_r_nx    = rxeq_adapt_done_r;
    rxeq_adapt_done_nx      = 1'b0;
    rxeq_done_nx            = 1'b0;

    case (fsm_rx)
      RX_IDLE: begin
        rxeq_lffs_sel_nx = 1'b0;
        unique case (rxctl_r2)
          2'd1: begin
            fsm_rx_nx            = RX_PRESET;
            rxeq_preset_nx       = rxpre_r2;
            rxeq_adapt_done_r_nx = 1'b0;
          end
          2'd2, 2'd3: begin
            fsm_rx_nx        = RX_TXCOEFF;
            rxeq_txpreset_nx = rxtxpre_r2;
            rxeq_txcoeff_nx  = {txdeemph_r2, rxeq_txcoeff[17:6]};
            rxeq_cnt_nx      = 3'd1;
            rxeq_fs_nx       = rxlffs_r2;
          end
          default: fsm_rx_nx = RX_IDLE;
        endcase
      end
      RX_PRESET: begin
        fsm_rx_nx            = rxeqscan_preset_done ? RX_DONE : RX_PRESET;
        rxeq_preset_nx       = rxpre_r2;
        rxeq_preset_valid_nx = 1'b1;
        rxeq_lffs_sel_nx     = 1'b0;
      end
      RX_TXCOEFF: begin
        fsm_rx_nx        = (rxeq_cnt == 3'd2) ? RX_LF : RX_TXCOEFF;
        rxeq_txpreset_nx = rxtxpre_r2;
        rxeq_txcoeff_nx  = {txdeemph_r2, rxeq_txcoeff[17:6]};
        rxeq_cnt_nx      = rxeq_cnt + 3'd1;
        rxeq_lffs_sel_nx = 1'b1;
      end
      RX_LF: begin
        fsm_rx_nx        = (rxeq_cnt == 3'd7) ? RX_NEWREQ : RX_LF;
        rxeq_cnt_nx      = rxeq_cnt + 3'd1;
        rxeq_lf_nx       = (rxeq_cnt == 3'd7) ? rxlffs_r2 : rxeq_lf;
        rxeq_lffs_sel_nx = 1'b1;
      end
      RX_NEWREQ:
        if (rxeqscan_new_txcoeff_done) begin
          fsm_rx_nx            = RX_DONE;
          rxeq_new_txcoeff_nx  = rxeqscan_lffs_sel ? {14'd0, rxeqscan_new_txcoeff[3:0]} : rxeqscan_new_txcoeff;
          rxeq_lffs_sel_nx     = rxeqscan_lffs_sel;
          rxeq_adapt_done_r_nx = rxeqscan_adapt_done || rxeq_adapt_done_r;
          rxeq_adapt_done_nx   = rxeqscan_adapt_done || rxeq_adapt_done_r;
          rxeq_done_nx         = 1'b1;
        end else begin
          fsm_rx_nx               = RX_NEWREQ;
          rxeq_new_txcoeff_req_nx = 1'b1;
          rxeq_lffs_sel_nx        = 1'b0;
        end
      RX_DONE: begin
        fsm_rx_nx          = (rxctl_r2 == 2'd0) ? RX_IDLE : RX_DONE;
        rxeq_adapt_done_nx = rxeq_adapt_done;
        rxeq_done_nx       = 1'b1;
      end
      default: begin
        fsm_rx_nx = RX_IDLE;
        rxeq_preset_nx = 3'd0; rxeq_txpreset_nx = 4'd0; rxeq_txcoeff_nx = 18'd0;
        rxeq_fs_nx = 6'd0; rxeq_lf_nx = 6'd0; rxeq_new_txcoeff_nx = 18'd0;
        rxeq_lffs_sel_nx = 1'b0; rxeq_adapt_done_r_nx = 1'b0;
      end
    endcase
  end

  always_ff @(posedge EQ_CLK)
    if (!EQ_RST_N) begin
      fsm_rx <= RX_IDLE; rxeq_preset <= 3'd0; rxeq_preset_valid <= 1'b0; rxeq_txpreset <= 4'd0;
      rxeq_txcoeff <= 18'd0; rxeq_cnt <= 3'd0; rxeq_fs <= 6'd0; rxeq_lf <= 6'd0;
      rxeq_new_txcoeff_req <= 1'b0; rxeq_new_txcoeff <= 18'd0; rxeq_lffs_sel <= 1'b0;
      rxeq_adapt_done_r <= 1'b0; rxeq_adapt_done <= 1'b0; rxeq_done <= 1'b0;
    end else begin
      fsm_rx <= fsm_rx_nx; rxeq_preset <= rxeq_preset_nx; rxeq_preset_valid <= rxeq_preset_valid_nx;
      rxeq_txpreset <= rxeq_txpreset_nx; rxeq_txcoeff <= rxeq_txcoeff_nx; rxeq_cnt <= rxeq_cnt_nx;
      rxeq_fs <= rxeq_fs_nx; rxeq_lf <= rxeq_lf_nx; rxeq_new_txcoeff_req <= rxeq_new_txcoeff_req_nx;
      rxeq_new_txcoeff <= rxeq_new_txcoeff_nx; rxeq_lffs_sel <= rxeq_lffs_sel_nx;
      rxeq_adapt_done_r <= rxeq_adapt_done_r_nx; rxeq_adapt_done <= rxeq_adapt_done_nx; rxeq_done <= rxeq_done_nx;
    end

  signal_probe  signal_probe_i (
    .RXEQSCAN_CLK            (EQ_CLK),
    .RXEQSCAN_RST_N          (EQ_RST_N),
    .RXEQSCAN_CONTROL        (rxctl_r2),
    .RXEQSCAN_FS             (rxeq_fs),
    .RXEQSCAN_LF             (rxeq_lf),
    .RXEQSCAN_PRESET         (rxeq_preset),
    .RXEQSCAN_PRESET_VALID   (rxeq_preset_valid),
    .RXEQSCAN_TXPRESET       (rxeq_txpreset),
    .RXEQSCAN_TXCOEFF        (rxeq_txcoeff),
    .RXEQSCAN_NEW_TXCOEFF_REQ(rxeq_new_txcoeff_req),
    .RXEQSCAN_PRESET_DONE     (rxeqscan_preset_done),
    .RXEQSCAN_NEW_TXCOEFF     (rxeqscan_new_txcoeff),
    .RXEQSCAN_NEW_TXCOEFF_DONE(rxeqscan_new_txcoeff_done),
    .RXEQSCAN_LFFS_SEL        (rxeqscan_lffs_sel),
    .RXEQSCAN_ADAPT_DONE      (rxeqscan_adapt_done)
  );

  assign EQ_TXEQ_DEEMPH     = txeq_txcoeff[0];
  assign EQ_TXEQ_PRECURSOR  = gen3_r2 ? txeq_txcoeff[ 4: 0] : 5'h00;
  assign EQ_TXEQ_MAINCURSOR = gen3_r2 ? txeq_txcoeff[12: 6] : 7'h00;
  assign EQ_TXEQ_POSTCURSOR = gen3_r2 ? txeq_txcoeff[17:13] : 5'h00;
  assign EQ_TXEQ_DEEMPH_OUT = {1'b0, txeq_txcoeff[18:14], txeq_txcoeff[12:7], 1'b0, txeq_txcoeff[5:1]};
  assign EQ_TXEQ_DONE       = txeq_done;
  assign EQ_TXEQ_FSM        = fsm_tx;

  assign EQ_RXEQ_NEW_TXCOEFF = rxuen_r2 ? rxucoeff_r2 : rxeq_new_txcoeff;
  assign EQ_RXEQ_LFFS_SEL    = rxuen_r2 ? rxumode_r2  : rxeq_lffs_sel;
  assign EQ_RXEQ_ADAPT_DONE  = rxeq_adapt_done;
  assign EQ_RXEQ_DONE        = rxeq_done;
  assign EQ_RXEQ_FSM         = fsm_rx;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
