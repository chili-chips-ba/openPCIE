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

module pll_retune #(
  localparam PCIE_GT_DEVICE = "GTP",
  localparam PCIE_PLL_SEL = "CPLL",
  localparam PCIE_REFCLK_FREQ = 0,
  localparam LOAD_CNT_MAX = 2'd3,
  localparam INDEX_MAX = 3'd6) (
  input               DRP_CLK,
  input               DRP_RST_N,
  input               DRP_OVRD,
  input               DRP_GEN3,
  input               DRP_QPLLLOCK,
  input               DRP_START,
  input      [15:0]   DRP_DO,
  input               DRP_RDY,

  output     [7:0]    DRP_ADDR,
  output              DRP_EN,
  output     [15:0]   DRP_DI,
  output              DRP_WE,
  output              DRP_DONE,
  output              DRP_QPLLRESET,
  output     [5:0]    DRP_CRSCODE,
  output     [8:0]    DRP_FSM
);

  localparam [7:0] ADDR_FBDIV      = 8'h36;
  localparam [7:0] ADDR_CFG        = 8'h32;
  localparam [7:0] ADDR_LPF        = 8'h31;
  localparam [7:0] ADDR_CRSCODE    = 8'h88;
  localparam [7:0] ADDR_CFO        = 8'h35;
  localparam [7:0] ADDR_CFO_EN     = 8'h36;
  localparam [7:0] ADDR_LOCK_CFG   = 8'h34;
  localparam [15:0] MASK_FBDIV     = 16'b1111110000000000;
  localparam [15:0] MASK_CFG       = 16'b1111111110111111;
  localparam [15:0] MASK_LPF       = 16'b1000011111111111;
  localparam [15:0] MASK_CFO       = 16'b0000001111111111;
  localparam [15:0] MASK_CFO_EN    = 16'b1111011111111111;
  localparam [15:0] MASK_LOCK_CFG  = 16'b1110011111111111;
  localparam [15:0] NORM_CFO       = 16'b0000000000000000;
  localparam [15:0] NORM_CFO_EN    = 16'b0000000000000000;
  localparam [15:0] NORM_LOCK_CFG  = 16'b0000000000000000;
  localparam [15:0] OVRD_CFO_EN    = 16'b0000100000000000;
  localparam [15:0] OVRD_LOCK_CFG  = 16'b0000000000000000;

  localparam [15:0] QPLL_FBDIV =
      (PCIE_REFCLK_FREQ == 2) && (PCIE_PLL_SEL == "QPLL") ? 16'b0000000010000000 :
      (PCIE_REFCLK_FREQ == 1) && (PCIE_PLL_SEL == "QPLL") ? 16'b0000000100100000 :
      (PCIE_REFCLK_FREQ == 0) && (PCIE_PLL_SEL == "QPLL") ? 16'b0000000101110000 :
      (PCIE_REFCLK_FREQ == 2) && (PCIE_PLL_SEL == "CPLL") ? 16'b0000000001100000 :
      (PCIE_REFCLK_FREQ == 1) && (PCIE_PLL_SEL == "CPLL") ? 16'b0000000011100000 : 16'b0000000100100000;
  localparam [15:0] GEN12_FBDIV = (PCIE_REFCLK_FREQ == 2) ? 16'b0000000010000000 :
                                  (PCIE_REFCLK_FREQ == 1) ? 16'b0000000100100000 : 16'b0000000101110000;
  localparam [15:0] GEN3_FBDIV  = (PCIE_REFCLK_FREQ == 2) ? 16'b0000000001100000 :
                                  (PCIE_REFCLK_FREQ == 1) ? 16'b0000000011100000 : 16'b0000000100100000;
  localparam [15:0] GEN12_CFG = (PCIE_PLL_SEL == "QPLL") ? 16'b0000000000000000 : 16'b0000000001000000;
  localparam [15:0] GEN3_CFG  = 16'b0000000001000000;
  localparam [15:0] GEN12_LPF = (PCIE_PLL_SEL == "QPLL") ? 16'b0_0100_00000000000 : 16'b0_1101_00000000000;
  localparam [15:0] GEN3_LPF  = 16'b0_1101_00000000000;

  typedef enum logic [8:0] {
    ST_IDLE=9'b000000001, ST_LOAD=9'b000000010, ST_READ=9'b000000100,
    ST_RRDY=9'b000001000, ST_WRITE=9'b000010000, ST_WRDY=9'b000100000,
    ST_DONE=9'b001000000, ST_QPLLRESET=9'b010000000, ST_QPLLLOCK=9'b100000000
  } state_e;
  state_e state = ST_IDLE, state_nx;

  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic        ovrd_r1,  ovrd_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic        gen3_r1,  gen3_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic        qlock_r1, qlock_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic        start_r1, start_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [15:0] do_r1,    do_r2;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic        rdy_r1,   rdy_r2;

  always_ff @(posedge DRP_CLK) begin
    if (!DRP_RST_N) begin
      ovrd_r1<=1'b0; gen3_r1<=1'b0; qlock_r1<=1'b0; start_r1<=1'b0; do_r1<=16'd0; rdy_r1<=1'b0;
      ovrd_r2<=1'b0; gen3_r2<=1'b0; qlock_r2<=1'b0; start_r2<=1'b0; do_r2<=16'd0; rdy_r2<=1'b0;
    end else begin
      ovrd_r1<=DRP_OVRD;      ovrd_r2<=ovrd_r1;
      gen3_r1<=DRP_GEN3;      gen3_r2<=gen3_r1;
      qlock_r1<=DRP_QPLLLOCK; qlock_r2<=qlock_r1;
      start_r1<=DRP_START;    start_r2<=start_r1;
      do_r1<=DRP_DO;          do_r2<=do_r1;
      rdy_r1<=DRP_RDY;        rdy_r2<=rdy_r1;
    end
  end

  wire [15:0] data_fbdiv = gen3_r2 ? GEN3_FBDIV : GEN12_FBDIV;
  wire [15:0] data_cfg   = gen3_r2 ? GEN3_CFG   : GEN12_CFG;
  wire [15:0] data_lpf   = gen3_r2 ? GEN3_LPF   : GEN12_LPF;
  wire [15:0] data_cfo_en= ovrd_r2 ? OVRD_CFO_EN : NORM_CFO_EN;
  wire [15:0] data_lock  = ovrd_r2 ? OVRD_LOCK_CFG : NORM_LOCK_CFG;

  logic [1:0] load_cnt = 2'd0;
  always_ff @(posedge DRP_CLK) begin
    if      (!DRP_RST_N)              load_cnt <= 2'd0;
    else if (state != ST_LOAD)        load_cnt <= 2'd0;
    else if (load_cnt < LOAD_CNT_MAX) load_cnt <= load_cnt + 2'd1;
  end
  wire load_done = (load_cnt == LOAD_CNT_MAX);

  logic [2:0]  index = 3'd0, index_nx;
  logic        mode  = 1'b0, mode_nx;
  logic [7:0]  addr    = 8'd0;
  logic [15:0] di      = 16'd0;
  logic [5:0]  crscode = 6'd0;

  always_ff @(posedge DRP_CLK) begin
    if (!DRP_RST_N) begin
      addr <= 8'd0; di <= 16'd0; crscode <= 6'd0;
    end else begin
      case (index)
        3'd0: begin
          addr <= ADDR_FBDIV;
          di   <= (do_r2 & MASK_FBDIV) | (mode ? data_fbdiv : QPLL_FBDIV);
        end
        3'd1: begin
          addr <= ADDR_CFG;
          di   <= (PCIE_GT_DEVICE == "GTX") ? ((do_r2 & MASK_CFG) | data_cfg)
                                            : ((do_r2 & 16'hFFFF) | data_cfg);
        end
        3'd2: begin
          addr <= ADDR_LPF;
          di   <= (PCIE_GT_DEVICE == "GTX") ? ((do_r2 & MASK_LPF) | data_lpf)
                                            : ((do_r2 & 16'hFFFF) | data_lpf);
        end
        3'd3: begin
          addr <= ADDR_CRSCODE;
          di   <= do_r2;
          if (ovrd_r2) crscode <= do_r2[6:1];
        end
        3'd4: begin
          addr <= ADDR_CFO;
          di   <= (do_r2 & MASK_CFO) | {(crscode - 6'd1), NORM_CFO[9:0]};
        end
        3'd5: begin
          addr <= ADDR_CFO_EN;
          di   <= (do_r2 & MASK_CFO_EN) | data_cfo_en;
        end
        3'd6: begin
          addr <= ADDR_LOCK_CFG;
          di   <= (do_r2 & MASK_LOCK_CFG) | data_lock;
        end
        default: begin
          addr <= 8'd0; di <= 16'd0; crscode <= 6'd0;
        end
      endcase
    end
  end

  logic done = 1'b0, done_nx;

  always_comb begin
    state_nx = state;  index_nx = index;  mode_nx = mode;  done_nx = done;
    unique case (state)
      ST_IDLE:
        if (start_r2)                                            begin state_nx=ST_LOAD; index_nx=3'd0; mode_nx=1'b0; done_nx=1'b0; end
        else if ((gen3_r2 != gen3_r1) && (PCIE_PLL_SEL == "QPLL")) begin state_nx=ST_LOAD; index_nx=3'd0; mode_nx=1'b1; done_nx=1'b0; end
        else                                                     begin state_nx=ST_IDLE; index_nx=3'd0; mode_nx=1'b0; done_nx=1'b1; end
      ST_LOAD : begin state_nx = load_done ? ST_READ : ST_LOAD; done_nx = 1'b0; end
      ST_READ : begin state_nx = ST_RRDY;                       done_nx = 1'b0; end
      ST_RRDY : begin state_nx = rdy_r2 ? ST_WRITE : ST_RRDY;   done_nx = 1'b0; end
      ST_WRITE: begin state_nx = ST_WRDY;                       done_nx = 1'b0; end
      ST_WRDY : begin state_nx = rdy_r2 ? ST_DONE : ST_WRDY;    done_nx = 1'b0; end
      ST_DONE :
        if ((index == INDEX_MAX) || (mode && (index == 3'd2))) begin state_nx = mode ? ST_QPLLRESET : ST_IDLE; index_nx=3'd0; done_nx=1'b0; end
        else                                                   begin state_nx = ST_LOAD; index_nx = index + 3'd1; done_nx=1'b0; end
      ST_QPLLRESET: begin state_nx = !qlock_r2 ? ST_QPLLLOCK : ST_QPLLRESET; index_nx=3'd0; done_nx=1'b0; end
      ST_QPLLLOCK : begin state_nx =  qlock_r2 ? ST_IDLE      : ST_QPLLLOCK;  index_nx=3'd0; done_nx=1'b0; end
      default     : begin state_nx = ST_IDLE; index_nx=3'd0; mode_nx=1'b0; done_nx=1'b0; end
    endcase
  end

  always_ff @(posedge DRP_CLK) begin
    if (!DRP_RST_N) begin
      state <= ST_IDLE; index <= 3'd0; mode <= 1'b0; done <= 1'b0;
    end else begin
      state <= state_nx; index <= index_nx; mode <= mode_nx; done <= done_nx;
    end
  end

  assign DRP_ADDR      = addr;
  assign DRP_EN        = (state == ST_READ) || (state == ST_WRITE);
  assign DRP_DI        = di;
  assign DRP_WE        = (state == ST_WRITE);
  assign DRP_DONE      = done;
  assign DRP_QPLLRESET = (state == ST_QPLLRESET);
  assign DRP_CRSCODE   = crscode;
  assign DRP_FSM       = state;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
