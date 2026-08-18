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
// Description:
//   CSR wrapper for the PeakRDL-generated CSR.
//
//   Bridges the picorv32 native memory interface to the "passthrough" CPU
//   interface of the register block that PeakRDL-regblock generates out of
//   4.build/csr_build/csr.rdl:
//
//     picorv32                soc_csr                 csr (generated)
//     --------                -------                 ---------------
//     mem_valid  ---------->  req launcher  ------->  s_cpuif_req
//     mem_wstrb  ---------->  byte -> biten ------->  s_cpuif_wr_biten
//     mem_ready  <----------  ack capture   <-------  s_cpuif_*_ack
//
//   picorv32 keeps mem_valid asserted until it sees mem_ready, whereas the
//   passthrough interface samples s_cpuif_req on every clock edge. The
//   request must therefore be launched for exactly one cycle and then held
//   off until the register block acknowledges it -- that is all the busy /
//   ready handshake below does.
//==========================================================================

`timescale 1ns / 1ps

module soc_csr
   import csr_pkg::*;
(
   input  logic                clk,
   input  logic                resetn,

   // picorv32 native memory interface, already decoded for this slave
   input  logic                sel,      // address hits the CSR window
   input  logic                vld,      // mem_valid
   input  logic [3:0]          we,       // mem_wstrb
   input  logic [5:2]          addr,     // mem_addr[5:2], the CSR word index
   input  logic [31:0]         wdat,     // mem_wdata
   output logic [31:0]         rdat,     // -> mem_rdata
   output logic                rdy,      // -> mem_ready

   // Hardware side of the register block
   input  csr_pkg::csr__in_t   hwif_in,
   output csr_pkg::csr__out_t  hwif_out
);

   logic        cpuif_req;
   logic [31:0] cpuif_wr_biten;
   logic        cpuif_rd_ack;
   logic        cpuif_wr_ack;
   logic [31:0] cpuif_rd_data;
   logic        cpuif_ack;
   logic        cpuif_done;

   logic        csr_busy;

   // mem_wstrb is one bit per byte, s_cpuif_wr_biten one bit per bit
   assign cpuif_wr_biten[31:24] = we[3] ? '1 : '0;
   assign cpuif_wr_biten[23:16] = we[2] ? '1 : '0;
   assign cpuif_wr_biten[15:8]  = we[1] ? '1 : '0;
   assign cpuif_wr_biten[7:0]   = we[0] ? '1 : '0;

   assign cpuif_ack = cpuif_rd_ack | cpuif_wr_ack;

   // One request per CPU access: not while one is outstanding (csr_busy), and
   // not in the cycle the CPU is being told "ready" -- mem_valid is still high
   // there and would otherwise start a second, spurious transaction.
   assign cpuif_req = sel & vld & ~csr_busy & ~rdy;

   // PeakRDL-regblock answers in the SAME cycle as the request when the block
   // has no external or buffered registers: decoded_req is combinational from
   // cpuif_req, and both the ack and the read data come straight back out of
   // the always_comb readback mux. Waiting a cycle for the ack therefore hangs
   // the bus forever, so the acknowledge is accepted either in the request
   // cycle or in any later one.
   assign cpuif_done = cpuif_ack & (cpuif_req | csr_busy);

   always_ff @(posedge clk) begin
      if (!resetn) begin
         csr_busy <= 1'b0;
         rdy      <= 1'b0;
         rdat     <= '0;
      end else begin
         rdy <= 1'b0;

         // Outstanding only if the request was not answered straight away
         if (cpuif_req && !cpuif_ack) begin
            csr_busy <= 1'b1;
         end

         if (cpuif_done) begin
            csr_busy <= 1'b0;
            rdy      <= 1'b1;
            rdat     <= cpuif_rd_data;
         end
      end
   end

   csr csr_inst (
      .clk                  (clk),
      .rst                  (~resetn),

      .s_cpuif_req          (cpuif_req),
      .s_cpuif_req_is_wr    (|we),
      .s_cpuif_addr         ({addr, 2'b00}),
      .s_cpuif_wr_data      (wdat),
      .s_cpuif_wr_biten     (cpuif_wr_biten),
      .s_cpuif_req_stall_wr (),
      .s_cpuif_req_stall_rd (),
      .s_cpuif_rd_ack       (cpuif_rd_ack),
      .s_cpuif_rd_err       (),
      .s_cpuif_rd_data      (cpuif_rd_data),
      .s_cpuif_wr_ack       (cpuif_wr_ack),
      .s_cpuif_wr_err       (),

      .hwif_in              (hwif_in),
      .hwif_out             (hwif_out)
   );

//=========================================
// Sim-only
//=========================================
`ifdef SIM_ONLY
`ifdef CSR_DEBUG

   always @(posedge clk) begin
      if ({cpuif_req, cpuif_ack} != 2'b00 && rdy) begin
         if (|we == 1) begin
            $display("%t %m WRITE [%08x]<=%08x", $time, {addr, 2'b00}, wdat);
         end
         else begin
            $display("%t %m READ [%08x]=>%08x", $time, {addr, 2'b00}, rdat);
         end
      end
   end

`endif
`endif

endmodule: soc_csr

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// -----------------------------------------------------------------------------
