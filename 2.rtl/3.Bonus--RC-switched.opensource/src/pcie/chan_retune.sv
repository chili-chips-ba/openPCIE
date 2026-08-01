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

module chan_retune #(
  localparam LOAD_CNT_MAX = 2'd1,
  localparam INDEX_MAX = 1'd0) (
  input               DRP_CLK,
  input               DRP_RST_N,
  input               DRP_X16,
  input               DRP_START,
  input      [15:0]   DRP_DO,
  input               DRP_RDY,

  output     [8:0]    DRP_ADDR,
  output              DRP_EN,
  output     [15:0]   DRP_DI,
  output              DRP_WE,
  output              DRP_DONE,
  output     [2:0]    DRP_FSM
);

  localparam [8:0]  ADDR_RX_DW = 9'h011;
  localparam [15:0] MASK_RX_DW = 16'b1111011111111111;
  localparam [15:0] X16_RX_DW  = 16'b0000000000000000;
  localparam [15:0] X20_RX_DW  = 16'b0000100000000000;

  typedef enum logic [2:0] { ST_IDLE, ST_LOAD, ST_READ, ST_RRDY, ST_WRITE, ST_WRDY, ST_DONE } state_e;
  state_e state = ST_IDLE, state_nx;

  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic        x16_r1,   x16_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic        start_r1, start_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [15:0] do_r1,    do_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic        rdy_r1,   rdy_r2;

  always_ff @(posedge DRP_CLK) begin
    if (!DRP_RST_N) begin
      x16_r1 <= 1'b0; start_r1 <= 1'b0; do_r1 <= 16'd0; rdy_r1 <= 1'b0;
      x16_r2 <= 1'b0; start_r2 <= 1'b0; do_r2 <= 16'd0; rdy_r2 <= 1'b0;
    end else begin
      x16_r1 <= DRP_X16;   x16_r2   <= x16_r1;
      start_r1 <= DRP_START; start_r2 <= start_r1;
      do_r1  <= DRP_DO;    do_r2    <= do_r1;
      rdy_r1 <= DRP_RDY;   rdy_r2   <= rdy_r1;
    end
  end

  wire [15:0] data_rx_dw = x16_r2 ? X16_RX_DW : X20_RX_DW;

  logic [1:0] load_cnt = 2'd0;
  always_ff @(posedge DRP_CLK) begin
    if      (!DRP_RST_N)                  load_cnt <= 2'd0;
    else if (state != ST_LOAD)            load_cnt <= 2'd0;
    else if (load_cnt < LOAD_CNT_MAX)     load_cnt <= load_cnt + 2'd1;
  end
  wire load_done = (load_cnt == LOAD_CNT_MAX);

  logic [4:0] index = 5'd0, index_nx;
  logic [8:0]  addr_reg = 9'd0;
  logic [15:0] di_reg   = 16'd0;

  always_ff @(posedge DRP_CLK) begin
    if (!DRP_RST_N) begin
      addr_reg <= 9'd0;
      di_reg   <= 16'd0;
    end else if (index == 5'd0) begin
      addr_reg <= ADDR_RX_DW;
      di_reg   <= (do_r2 & MASK_RX_DW) | data_rx_dw;
    end else begin
      addr_reg <= 9'd0;
      di_reg   <= 16'd0;
    end
  end

  logic done = 1'b1, done_nx;

  always_comb begin
    state_nx = state;
    index_nx = index;
    done_nx  = done;
    unique case (state)
      ST_IDLE : if (start_r2) begin state_nx = ST_LOAD;  index_nx = 5'd0; done_nx = 1'b0; end
                else          begin state_nx = ST_IDLE;  index_nx = 5'd0; done_nx = 1'b1; end
      ST_LOAD : begin state_nx = load_done ? ST_READ : ST_LOAD;  done_nx = 1'b0; end
      ST_READ : begin state_nx = ST_RRDY;                        done_nx = 1'b0; end
      ST_RRDY : begin state_nx = rdy_r2 ? ST_WRITE : ST_RRDY;    done_nx = 1'b0; end
      ST_WRITE: begin state_nx = ST_WRDY;                        done_nx = 1'b0; end
      ST_WRDY : begin state_nx = rdy_r2 ? ST_DONE : ST_WRDY;     done_nx = 1'b0; end
      ST_DONE : if (index == INDEX_MAX) begin state_nx = ST_IDLE; index_nx = 5'd0;      done_nx = 1'b1; end
                else                    begin state_nx = ST_LOAD; index_nx = index + 5'd1; done_nx = 1'b0; end
      default : begin state_nx = ST_IDLE; index_nx = 5'd0; done_nx = 1'b1; end
    endcase
  end

  always_ff @(posedge DRP_CLK) begin
    if (!DRP_RST_N) begin
      state <= ST_IDLE;
      index <= 5'd0;
      done  <= 1'b1;
    end else begin
      state <= state_nx;
      index <= index_nx;
      done  <= done_nx;
    end
  end

  assign DRP_ADDR = addr_reg;
  assign DRP_EN   = (state == ST_READ) || (state == ST_WRITE);
  assign DRP_DI   = di_reg;
  assign DRP_WE   = (state == ST_WRITE);
  assign DRP_DONE = done;
  assign DRP_FSM  = state;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
