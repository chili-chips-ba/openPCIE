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

module soc_csr
  import csr_pkg::*;
(
    input logic clk,
    input logic resetn,

    // picorv32 native memory interface, already decoded for this slave
    input logic sel,  // address hits the CSR window
    mem_if.target mem,  // CPU request; addr[CSR_MIN_ADDR_WIDTH-1:2] is the CSR word index
    output logic [CSR_DATA_WIDTH-1:0] rdat,  // -> mem_rdata
    output logic rdy,  // -> mem_ready

    // Hardware side of the register block
    input  csr__in_t  csr_in,
    output csr__out_t csr_out
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
  assign cpuif_wr_biten[31:24] = mem.wstrb[3] ? '1 : '0;
  assign cpuif_wr_biten[23:16] = mem.wstrb[2] ? '1 : '0;
  assign cpuif_wr_biten[15:8]  = mem.wstrb[1] ? '1 : '0;
  assign cpuif_wr_biten[7:0]   = mem.wstrb[0] ? '1 : '0;

  assign cpuif_ack             = cpuif_rd_ack | cpuif_wr_ack;

  // One request per CPU access: not while one is outstanding (csr_busy), and
  // not in the cycle the CPU is being told "ready" -- mem_valid is still high
  // there and would otherwise start a second, spurious transaction.
  assign cpuif_req             = sel & mem.valid & ~csr_busy & ~rdy;

  // PeakRDL-regblock answers in the SAME cycle as the request when the block
  // has no external or buffered registers: decoded_req is combinational from
  // cpuif_req, and both the ack and the read data come straight back out of
  // the always_comb readback mux. Waiting a cycle for the ack therefore hangs
  // the bus forever, so the acknowledge is accepted either in the request
  // cycle or in any later one.
  assign cpuif_done            = cpuif_ack & (cpuif_req | csr_busy);

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      csr_busy <= 1'b0;
      rdy      <= 1'b0;
      rdat     <= '0;
    end
    else begin
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


  // the register map (csr.rdl) must fit in the address bits decoded here
  if (CSR_SIZE > (1 << CSR_MIN_ADDR_WIDTH)) begin : gen_csr_size_check
    $error("csr.rdl: CSR_SIZE exceeds the CSR_MIN_ADDR_WIDTH address bits of soc_csr");
  end


  csr u_csr (
      .clk   (clk),
      .arst_n(resetn),

      .s_cpuif_req         (cpuif_req),
      .s_cpuif_req_is_wr   (|mem.wstrb),
      .s_cpuif_addr        ({mem.addr[CSR_MIN_ADDR_WIDTH-1:2], 2'b00}),
      .s_cpuif_wr_data     (mem.wdata),
      .s_cpuif_wr_biten    (cpuif_wr_biten),
      .s_cpuif_req_stall_wr(),
      .s_cpuif_req_stall_rd(),
      .s_cpuif_rd_ack      (cpuif_rd_ack),
      .s_cpuif_rd_err      (),
      .s_cpuif_rd_data     (cpuif_rd_data),
      .s_cpuif_wr_ack      (cpuif_wr_ack),
      .s_cpuif_wr_err      (),

      .hwif_in (csr_in),
      .hwif_out(csr_out)
  );

  //=========================================
  // Sim-only
  //=========================================
`ifdef SIM_ONLY
`ifdef CSR_DEBUG

  always_ff @(posedge clk) begin
    if ({cpuif_req, cpuif_ack} != 2'b00 && rdy) begin
      if (|mem.wstrb == 1) begin
        $display("%t %m WRITE [%08x]<=%08x", $time, {mem.addr[CSR_MIN_ADDR_WIDTH-1:2], 2'b00},
                 mem.wdata);
      end
      else begin
        $display("%t %m READ [%08x]=>%08x", $time, {mem.addr[CSR_MIN_ADDR_WIDTH-1:2], 2'b00}, rdat);
      end
    end
  end

`endif
`endif

endmodule : soc_csr

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// -----------------------------------------------------------------------------
