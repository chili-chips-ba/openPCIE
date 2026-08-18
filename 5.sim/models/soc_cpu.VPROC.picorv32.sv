// SPDX-FileCopyrightText: 2026 Chili.CHIPS*ba
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openPCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
// Description:
//   VProc virtual processor presented as a picorv32.
//
//   Drop-in replacement for the picorv32 instance in riscv_pcie_soc.sv, so
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
//   a rising edge, then updates them on the following edge -- the same shape
//   as picorv32's mem_valid/mem_ready. The one thing picorv32 gives for free
//   and VProc does not is a guaranteed idle cycle between accesses, so the
//   little state machine below inserts one. Without it a back-to-back pair of
//   VProc accesses can catch the trailing edge of the previous ready.
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
    typedef enum logic [1:0] {
        BUS_IDLE = 2'd0,   // waiting for VProc to raise WE or RD
        BUS_REQ  = 2'd1,   // mem_valid asserted, waiting for mem_ready
        BUS_ACK  = 2'd2    // acknowledging VProc; mem_valid low -> idle cycle
    } bus_state_e;

    bus_state_e  bus_state;
    logic [31:0] rdat_reg;
    logic        ack_reg;

    assign mem_valid = (bus_state == BUS_REQ);
    assign mem_addr  = vp_addr;
    assign mem_wdata = vp_wdat;
    assign mem_wstrb = vp_we ? vp_be : 4'b0000;

    always_ff @(posedge clk) begin
        if (!resetn) begin
            bus_state <= BUS_IDLE;
            ack_reg   <= 1'b0;
            rdat_reg  <= '0;
        end else begin
            ack_reg <= 1'b0;

            case (bus_state)
                BUS_IDLE:
                    if (vp_we || vp_rd)
                        bus_state <= BUS_REQ;

                BUS_REQ:
                    if (mem_ready) begin
                        rdat_reg  <= mem_rdata;
                        ack_reg   <= 1'b1;
                        bus_state <= BUS_ACK;
                    end

                BUS_ACK:
                    // ack_reg is high through this cycle; VProc samples it at
                    // the edge that ends it and drops WE/RD at the next one.
                    bus_state <= BUS_IDLE;

                default:
                    bus_state <= BUS_IDLE;
            endcase
        end
    end

    assign vp_wack = ack_reg & vp_we;
    assign vp_rack = ack_reg & vp_rd;
    assign vp_rdat = rdat_reg;

    // ---------------------------------------------------------------------
    // The virtual processor itself
    // ---------------------------------------------------------------------
    VProc #(
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

        .Interrupt      ('0),            // i (unused)

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
*/
