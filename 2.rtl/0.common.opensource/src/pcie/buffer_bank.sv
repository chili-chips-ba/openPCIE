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

module buffer_bank #(
    parameter int DATA_W            = 69,  // 69 (TX) or 68 (RX), see mim_if.sv
    parameter int NUM_BRAMS         = 4,
    parameter int RAM_RDATA_LATENCY = 2    // TL_*_RAM_RDATA_LATENCY of PCIE_2_1
) (
    input logic      user_clk_i,
          mim_if.ram mim          // packet buffer port of PCIE_2_1 (see mim_if.sv)
);
  // PCIE_2_1 runs with TL_*_RAM_RADDR_LATENCY = TL_*_RAM_WRITE_LATENCY = 0, so
  // address and write data go straight to the BRAMs; a read data latency of 2
  // is the BRAM output register (DOB_REG).
  localparam int DOB_REG = (RAM_RDATA_LATENCY > 1) ? 1 : 0;
  localparam logic [6:0] WIDTH = (NUM_BRAMS == 1) ? 72 :
                           (NUM_BRAMS == 2) ? 36 :
                           (NUM_BRAMS == 4) ? 18 :
                           (NUM_BRAMS == 8) ?  9 : 4;

  // the PCIE_2_1 data is 68 or 69 bits wide; the tiles are 72: the write data
  // is padded, the read bits above it are no-connect
  logic [71:0] wdata;
  assign wdata = {{(72 - DATA_W) {1'b0}}, mim.wdata};
  logic [     71:0] rdata;
  logic [71:DATA_W] NC_rdata;
  assign {NC_rdata, mim.rdata} = rdata;

  // One RAMB36 per tile, WIDTH bits of the 72-bit word each
  localparam int ADDR_MSB   = (WIDTH == 4)  ? 12 :
                          (WIDTH == 9)  ? 11 :
                          (WIDTH == 18) ? 10 :
                          (WIDTH == 36) ?  9 : 8;

  // PCIE_2_1 addresses up to 8K words; bits above the tile depth are no-connect
  if (ADDR_MSB < 12) begin : g_addr_nc
    logic [12:ADDR_MSB+1] NC_waddr;
    assign NC_waddr = mim.waddr[12:ADDR_MSB+1];
    logic [12:ADDR_MSB+1] NC_raddr;
    assign NC_raddr = mim.raddr[12:ADDR_MSB+1];
  end

  for (genvar ii = 0; ii < NUM_BRAMS; ii = ii + 1) begin : g_tile
    BRAM_TDP_MACRO #(
        .DEVICE       ("7SERIES"),
        .BRAM_SIZE    ("36Kb"),
        .DOA_REG      (0),
        .DOB_REG      (DOB_REG),
        .READ_WIDTH_A (WIDTH),
        .READ_WIDTH_B (WIDTH),
        .WRITE_WIDTH_A(WIDTH),
        .WRITE_WIDTH_B(WIDTH),
        .WRITE_MODE_A ("NO_CHANGE")
    ) ramb36 (
        .DOA   (  /*LINT:OK*/),
        .DOB   (rdata[(ii*WIDTH)+:WIDTH]),
        .ADDRA (mim.waddr[ADDR_MSB:0]),
        .ADDRB (mim.raddr[ADDR_MSB:0]),
        .CLKA  (user_clk_i),
        .CLKB  (user_clk_i),
        .DIA   (wdata[(ii*WIDTH)+:WIDTH]),
        .DIB   ('0),
        .ENA   (mim.wen),
        .ENB   (mim.ren),
        .REGCEA(1'b0),
        .REGCEB(1'b1),
        .RSTA  (1'b0),
        .RSTB  (1'b0),
        .WEA   ('1),
        .WEB   ('0)
    );
  end

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
