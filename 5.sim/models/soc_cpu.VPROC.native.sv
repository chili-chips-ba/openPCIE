// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openPCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
// Description:
//   VProc virtual processor as the SOC's CPU, on its native memory bus
//   (picorv32's mem_valid/mem_ready bus, which eduBOS5 drives too).
//
//   Drop-in replacement for the RTL core (eduBOS5 or PicoRV32) in
//   riscv_pcie_soc.sv, so
//   that the CPU of the SOC can be a native C/C++ program (or the rv32 ISS)
//   instead of the RTL core. Everything else in the design -- the CSR, the
//   PCIe stack, the top level -- is untouched and runs exactly as it does
//   with the real core.
//
//   Selected with `define SOC_CPU_VPROC; see 5.sim/Makefile CPU=... .
//
//   NOTE on the difference from models/soc_cpu.VPROC.sv: that wrapper speaks
//   the `soc_if` bus interface of the sibling Chili.CHIPS SOC infrastructure,
//   which this design does not have. Here the picorv32 *native* memory
//   interface is driven instead, which is what riscv_pcie_soc.sv decodes.
//
//   Protocol note. VProc holds WE/RD asserted until it samples WRAck/RDAck at
//   a rising edge, then updates them on the following edge. The bus follows
//   picorv32's timing: mem_valid with WE/RD, the ack is mem_ready itself, and
//   mem_valid is low for the one cycle after ready, while VProc still holds
//   the finished access. An access takes 2 clocks, as on the RTL core.
//
//   Reset: !resetn is VProc interrupt bit 3, so the ISS can wait for reset
//   release and restart on a new reset (5.sim/models/rv32/usercode).
//==========================================================================

`timescale 1ns / 1ps

module soc_cpu_vproc #(
    parameter [3:0] NODE = 0      // VProc node: 0 is the CPU, 1 is the PCIe EP
)(
    input  logic        clk,
    input  logic        resetn,

    output logic        mem_valid,
    input  logic        mem_ready,
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    output logic [3:0]  mem_wstrb,
    input  logic [31:0] mem_rdata
);

    // ---------------------------------------------------------------------
    // VProc side
    // ---------------------------------------------------------------------
    logic        vp_we, vp_rd;
    logic [3:0]  vp_be;
    logic [31:0] vp_addr;
    logic [31:0] vp_wdat;

    logic        vp_wack, vp_rack;
    logic [31:0] vp_rdat;

    // ---------------------------------------------------------------------
    // Bus side
    // ---------------------------------------------------------------------
    logic done;  // the cycle after ready: VProc still holds the finished access

    always_ff @(posedge clk) begin
        done <= mem_valid & mem_ready;
    end

    assign mem_valid = resetn & (vp_we | vp_rd) & ~done;
    assign mem_addr  = vp_addr;
    assign mem_wdata = vp_wdat;
    assign mem_wstrb = vp_we ? vp_be : 4'b0000;

    assign vp_wack   = mem_valid & mem_ready & vp_we;
    assign vp_rack   = mem_valid & mem_ready & vp_rd;
    assign vp_rdat   = mem_rdata;

    // ---------------------------------------------------------------------
    // The virtual processor itself
    // ---------------------------------------------------------------------
    VProc #(
        .INT_WIDTH      (4),
        .DISABLE_DELTA  (1)
    ) u_vproc (
        .Clk            (clk),           // i

        .Addr           (vp_addr),       // o
        .DataOut        (vp_wdat),       // o
        .WE             (vp_we),         // o
        .WRAck          (vp_wack),       // i

        // VProc is compiled with VPROC_BYTE_ENABLE, hence the BE port
        .BE             (vp_be),         // o

        .DataIn         (vp_rdat),       // i
        .RD             (vp_rd),         // o
        .RDAck          (vp_rack),       // i

        .Interrupt      ({~resetn, 3'b000}),  // i: bit 3 reset, 2:0 unused

        .Update         (),              // o (unused)
        .UpdateResponse ('0),            // i (unused)

        .Node           (NODE)
    );

endmodule: soc_cpu_vproc

/*
-----------------------------------------------------------------------------
Version History:
-----------------------------------------------------------------------------
 2026/08/16 AV: initial creation -- VProc as a picorv32, for CPU=vproc / CPU=iss
 2026/10/15    : 2-clock picorv32-style handshake; reset as interrupt bit 3
*/

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
