// SPDX-FileCopyrightText: 2025 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// Copyright (C) 2025 Chili.CHIPS
//--------------------------------------------------------------------------
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
// Description:
//   Stub in lieu openpcie2-rc DUT for initial TB testing
//==========================================================================

`timescale 1ps/1ps

module top
#(parameter int DataWidth = 64  // 8, 16, 32 or 64 only
)
(
   // Clocks and reset
   input                     clk_p,
   input                     clk_n,
   input                     rst_n,

   input                     pclk,
   input                     pcieclk,

   // PCIe PIPE data
   output [DataWidth-1:0]    txdata,
   output [DataWidth/8-1:0]  txdatak,
   input  [DataWidth-1:0]    rxdata,
   input  [DataWidth/8-1:0]  rxdatak,

   // UART
   input                     uart_rx,
   output                    uart_tx,

   // Keys
   input  [1:0]              key_in,

   // LEDs
   output  [1:0]             led
);

//--------------------------------------------------------------
// Internal signals
//--------------------------------------------------------------

soc_if            bus_cpu (.arst_n(rst_n), .clk(clk_p));

//--------------------------------------------------------------
// Combinatorial logic
//--------------------------------------------------------------

assign bus_cpu.rdy                     = 1'b1;
assign bus_cpu.rdat                    = 32'h900dc0de;
assign led                             = 2'b00;

//--------------------------------------------------------------
// soc_cpu.VPROC
//--------------------------------------------------------------

  soc_cpu #(
     .ADDR_RESET                       (32'h 0000_0000),  // Unused
     .NUM_WORDS_IMEM                   (8192),            // Unused
     .NODE                             (0)                // CPU is node 0
  )
  u_cpu (
     .bus                              (bus_cpu),

    // access point for reloading CPU program memory
    .imem_cpu_rstn                     (1'b0),
    .imem_we                           (1'b0),
    .imem_waddr                        (30'h00000000),
    .imem_wdat                         (32'h00000000)
  );

//--------------------------------------------------------------
// PCIe RC model at VProc node 2
//--------------------------------------------------------------

  pcieVHostPipex1 #(
    .NodeNum                           (1),
    .EndPoint                          (1),
    .DataWidth                         (DataWidth)
  ) bfm_pcie
  (
    .pclk                              (pclk),
    .pcieclk                           (pcieclk),
    .nreset                            (rst_n),

    .TxData                            (txdata),
    .TxDataK                           (txdatak),

    .RxData                            (rxdata),
    .RxDataK                           (rxdatak)
   );

endmodule