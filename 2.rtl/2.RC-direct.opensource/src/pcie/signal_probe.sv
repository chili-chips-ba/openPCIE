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
module signal_probe #(
  localparam PCIE_SIM_MODE = "FALSE",
  localparam PCIE_GT_DEVICE = "GTP",
  localparam PCIE_RXEQ_MODE_GEN3 = 1,
  localparam CONVERGE_MAX = 22'd3125000,
  localparam CONVERGE_MAX_BYPASS = 22'd2083333) (
  input               RXEQSCAN_CLK,
  input               RXEQSCAN_RST_N,
  input      [1:0]    RXEQSCAN_CONTROL,
  input      [2:0]    RXEQSCAN_PRESET,
  input               RXEQSCAN_PRESET_VALID,
  input      [3:0]    RXEQSCAN_TXPRESET,
  input      [17:0]   RXEQSCAN_TXCOEFF,
  input               RXEQSCAN_NEW_TXCOEFF_REQ,
  input      [5:0]    RXEQSCAN_FS,
  input      [5:0]    RXEQSCAN_LF,

  output              RXEQSCAN_PRESET_DONE,
  output     [17:0]   RXEQSCAN_NEW_TXCOEFF,
  output              RXEQSCAN_NEW_TXCOEFF_DONE,
  output              RXEQSCAN_LFFS_SEL,
  output              RXEQSCAN_ADAPT_DONE
);

  localparam [21:0] CONV_MAX     = (PCIE_SIM_MODE == "TRUE") ? 22'd1000 : CONVERGE_MAX;
  localparam [21:0] CONV_MAX_BYP = (PCIE_SIM_MODE == "TRUE") ? 22'd1000 : CONVERGE_MAX_BYPASS;

  typedef enum logic [1:0] { ST_IDLE, ST_PRESET, ST_CONVERGE, ST_NEWCOEFF } state_e;
  state_e state = ST_IDLE, state_nx;

  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [2:0]  preset_r1, preset_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic        pvalid_r1, pvalid_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [3:0]  txpreset_r1, txpreset_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [17:0] txcoeff_r1, txcoeff_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic        req_r1, req_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [5:0]  fs_r1, fs_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [5:0]  lf_r1, lf_r2;

  always_ff @(posedge RXEQSCAN_CLK) begin
    if (!RXEQSCAN_RST_N) begin
      preset_r1<=3'd0; pvalid_r1<=1'b0; txpreset_r1<=4'd0; txcoeff_r1<=18'd0; req_r1<=1'b0; fs_r1<=6'd0; lf_r1<=6'd0;
      preset_r2<=3'd0; pvalid_r2<=1'b0; txpreset_r2<=4'd0; txcoeff_r2<=18'd0; req_r2<=1'b0; fs_r2<=6'd0; lf_r2<=6'd0;
    end else begin
      preset_r1<=RXEQSCAN_PRESET;        preset_r2<=preset_r1;
      pvalid_r1<=RXEQSCAN_PRESET_VALID;  pvalid_r2<=pvalid_r1;
      txpreset_r1<=RXEQSCAN_TXPRESET;    txpreset_r2<=txpreset_r1;
      txcoeff_r1<=RXEQSCAN_TXCOEFF;      txcoeff_r2<=txcoeff_r1;
      req_r1<=RXEQSCAN_NEW_TXCOEFF_REQ;  req_r2<=req_r1;
      fs_r1<=RXEQSCAN_FS;                fs_r2<=fs_r1;
      lf_r1<=RXEQSCAN_LF;                lf_r2<=lf_r1;
    end
  end

  logic        preset_done = 1'b0,  preset_done_nx;
  logic [21:0] converge_cnt = 22'd0, converge_cnt_nx;
  logic [17:0] new_txcoeff = 18'd0,  new_txcoeff_nx;
  logic        new_txcoeff_done = 1'b0, new_txcoeff_done_nx;
  logic        lffs_sel = 1'b0,      lffs_sel_nx;
  logic        adapt_done = 1'b0,    adapt_done_nx;
  logic        adapt_done_cnt = 1'b0, adapt_done_cnt_nx;

  wire [17:0] coeff_on_req = (PCIE_RXEQ_MODE_GEN3 == 0) ? txcoeff_r2
                          : ((PCIE_GT_DEVICE == "GTX")  ? 18'd5 : 18'd4);
  wire        lffs_on_req  = (PCIE_RXEQ_MODE_GEN3 == 0) ? 1'b0 : 1'b1;

  always_comb begin
    state_nx            = state;
    preset_done_nx      = 1'b0;
    converge_cnt_nx     = 22'd0;
    new_txcoeff_nx      = new_txcoeff;
    new_txcoeff_done_nx = 1'b0;
    lffs_sel_nx         = 1'b0;
    adapt_done_nx       = 1'b0;
    adapt_done_cnt_nx   = adapt_done_cnt;

    unique case (state)
      ST_IDLE:
        if (pvalid_r2) begin
          state_nx       = ST_PRESET;
          preset_done_nx = 1'b1;
        end else if (req_r2) begin
          state_nx       = ST_CONVERGE;
          new_txcoeff_nx = coeff_on_req;
          lffs_sel_nx    = lffs_on_req;
        end
      ST_PRESET: begin
        state_nx       = (!pvalid_r2) ? ST_IDLE : ST_PRESET;
        preset_done_nx = 1'b1;
      end
      ST_CONVERGE:
        if ((adapt_done_cnt == 1'b0) && (RXEQSCAN_CONTROL == 2'd2)) begin
          state_nx    = ST_NEWCOEFF;
          lffs_sel_nx = lffs_sel;
        end else begin
          if (RXEQSCAN_CONTROL == 2'd2)
            state_nx = (converge_cnt == CONV_MAX)     ? ST_NEWCOEFF : ST_CONVERGE;
          else
            state_nx = (converge_cnt == CONV_MAX_BYP) ? ST_NEWCOEFF : ST_CONVERGE;
          converge_cnt_nx = converge_cnt + 22'd1;
          lffs_sel_nx     = lffs_sel;
        end
      ST_NEWCOEFF:
        if (!req_r2) begin
          state_nx          = ST_IDLE;
          lffs_sel_nx       = lffs_sel;
          adapt_done_cnt_nx = (RXEQSCAN_CONTROL == 2'd3) ? 1'b0 : (adapt_done_cnt + 1'b1);
        end else begin
          state_nx            = ST_NEWCOEFF;
          new_txcoeff_done_nx = 1'b1;
          lffs_sel_nx         = lffs_sel;
          adapt_done_nx       = (adapt_done_cnt == 1'b1) || (RXEQSCAN_CONTROL == 2'd3);
        end
      default: begin
        state_nx          = ST_IDLE;
        new_txcoeff_nx    = 18'd0;
        adapt_done_cnt_nx = 1'b0;
      end
    endcase
  end

  always_ff @(posedge RXEQSCAN_CLK) begin
    if (!RXEQSCAN_RST_N) begin
      state <= ST_IDLE; preset_done <= 1'b0; converge_cnt <= 22'd0; new_txcoeff <= 18'd0;
      new_txcoeff_done <= 1'b0; lffs_sel <= 1'b0; adapt_done <= 1'b0; adapt_done_cnt <= 1'b0;
    end else begin
      state <= state_nx; preset_done <= preset_done_nx; converge_cnt <= converge_cnt_nx;
      new_txcoeff <= new_txcoeff_nx; new_txcoeff_done <= new_txcoeff_done_nx;
      lffs_sel <= lffs_sel_nx; adapt_done <= adapt_done_nx; adapt_done_cnt <= adapt_done_cnt_nx;
    end
  end

  assign RXEQSCAN_PRESET_DONE      = preset_done;
  assign RXEQSCAN_NEW_TXCOEFF      = new_txcoeff;
  assign RXEQSCAN_NEW_TXCOEFF_DONE = new_txcoeff_done;
  assign RXEQSCAN_LFFS_SEL         = lffs_sel;
  assign RXEQSCAN_ADAPT_DONE       = adapt_done;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
