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

module buffer_tile #(
  parameter       IMPL_TARGET = "HARD",
  parameter       DOB_REG     = 0,
  parameter       WIDTH       = 0,
  parameter [3:0] LINK_CAP_MAX_LINK_SPEED = 4'h1,
  parameter [5:0] LINK_CAP_MAX_LINK_WIDTH = 6'h08
) (
  input               user_clk_i,
  input               reset_i,
  input               wen_i,
  input  [12:0]       waddr_i,
  input  [WIDTH-1:0]  wdata_i,
  input               ren_i,
  input               rce_i,
  input  [12:0]       raddr_i,
  output [WIDTH-1:0]  rdata_o
);

  localparam ADDR_MSB = (WIDTH == 4)  ? 12 :
                        (WIDTH == 9)  ? 11 :
                        (WIDTH == 18) ? 10 :
                        (WIDTH == 36) ?  9 : 8;
  localparam WE_WIDTH = (WIDTH <= 9)  ? 1 :
                        (WIDTH <= 18) ? 2 :
                        (WIDTH <= 36) ? 4 : 8;
  localparam WRITE_MODE = ((LINK_CAP_MAX_LINK_SPEED == 4'h2) && (LINK_CAP_MAX_LINK_WIDTH == 6'h08))
                          ? "WRITE_FIRST" : "NO_CHANGE";
  localparam DEVICE = (IMPL_TARGET == "HARD") ? "7SERIES" : "VIRTEX6";

  generate
    if (WIDTH <= 36) begin : use_tdp
      BRAM_TDP_MACRO #(
        .DEVICE        (DEVICE),
        .BRAM_SIZE     ("36Kb"),
        .DOA_REG       (0),
        .DOB_REG       (DOB_REG),
        .READ_WIDTH_A  (WIDTH),
        .READ_WIDTH_B  (WIDTH),
        .WRITE_WIDTH_A (WIDTH),
        .WRITE_WIDTH_B (WIDTH),
        .WRITE_MODE_A  (WRITE_MODE)
      ) ramb36 (
        .DOA    (),
        .DOB    (rdata_o[WIDTH-1:0]),
        .ADDRA  (waddr_i[ADDR_MSB:0]),
        .ADDRB  (raddr_i[ADDR_MSB:0]),
        .CLKA   (user_clk_i),
        .CLKB   (user_clk_i),
        .DIA    (wdata_i[WIDTH-1:0]),
        .DIB    ({WIDTH{1'b0}}),
        .ENA    (wen_i),
        .ENB    (ren_i),
        .REGCEA (1'b0),
        .REGCEB (rce_i),
        .RSTA   (reset_i),
        .RSTB   (reset_i),
        .WEA    ({WE_WIDTH{1'b1}}),
        .WEB    ({WE_WIDTH{1'b0}})
      );
    end
  endgenerate

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
