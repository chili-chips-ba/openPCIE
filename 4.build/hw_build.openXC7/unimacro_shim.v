// SPDX-FileCopyrightText: 2026 Chili.CHIPS*ba
//
// SPDX-License-Identifier: BSD-3-Clause
//
// -----------------------------------------------------------------------------
// UNIMACRO shim for the openXC7 build -- open-source flow ONLY.
//
// buffer_tile.sv instantiates BRAM_TDP_MACRO, the Xilinx UNIMACRO wrapper around
// RAMB36E1. Vivado pulls it from its own unimacro library; Yosys/openXC7 do not
// have it, so synthesis fails with:
//     ERROR: Module `\BRAM_TDP_MACRO' ... is not part of the design
//
// Below is a behavioural equivalent that Yosys maps onto RAMB36E1 by its
// standard BRAM inference.
//
// NOTE: this file is NOT part of the Vivado build. The RTL in 2.rtl/ is untouched.
//
// SCOPE: covers only how this design uses the macro -- symmetric widths
// (READ_WIDTH_x == WRITE_WIDTH_x), BRAM_SIZE "36Kb", port A writes, port B reads.
// Asymmetric widths and "18Kb" are NOT supported; extend this if they are needed.
// -----------------------------------------------------------------------------

`timescale 1ps/1ps

module BRAM_TDP_MACRO #(
    parameter         DEVICE        = "7SERIES",
    parameter         BRAM_SIZE     = "36Kb",
    parameter integer DOA_REG       = 0,
    parameter integer DOB_REG       = 0,
    parameter integer READ_WIDTH_A  = 0,
    parameter integer READ_WIDTH_B  = 0,
    parameter integer WRITE_WIDTH_A = 0,
    parameter integer WRITE_WIDTH_B = 0,
    parameter         WRITE_MODE_A  = "WRITE_FIRST",
    parameter         WRITE_MODE_B  = "WRITE_FIRST",
    parameter         INIT_FILE     = "NONE",

    // ---- DERIVED, do not override at the instance --------------------------
    // Word width; this design uses symmetric ports.
    parameter integer W = (READ_WIDTH_A > READ_WIDTH_B) ? READ_WIDTH_A : READ_WIDTH_B,

    // Address width and number of WE bits -- computed exactly as in
    // buffer_tile.sv so the instance widths match.
    parameter integer ADDR_W = (W == 4)  ? 13 :
                               (W == 9)  ? 12 :
                               (W == 18) ? 11 :
                               (W == 36) ? 10 : 9,

    parameter integer WE_W = (W <= 9)  ? 1 :
                             (W <= 18) ? 2 :
                             (W <= 36) ? 4 : 8
) (
    output [READ_WIDTH_A-1:0] DOA,
    output [READ_WIDTH_B-1:0] DOB,
    input  [ADDR_W-1:0]       ADDRA,
    input  [ADDR_W-1:0]       ADDRB,
    input                     CLKA,
    input                     CLKB,
    input  [WRITE_WIDTH_A-1:0] DIA,
    input  [WRITE_WIDTH_B-1:0] DIB,
    input                     ENA,
    input                     ENB,
    input                     REGCEA,
    input                     REGCEB,
    input                     RSTA,
    input                     RSTB,
    input  [WE_W-1:0]         WEA,
    input  [WE_W-1:0]         WEB
);

    localparam integer DEPTH = 1 << ADDR_W;

    reg [W-1:0] mem [0:DEPTH-1];

    reg [READ_WIDTH_A-1:0] doa_int = {READ_WIDTH_A{1'b0}};
    reg [READ_WIDTH_B-1:0] dob_int = {READ_WIDTH_B{1'b0}};

    // ---- Port A --------------------------------------------------------
    always @(posedge CLKA) begin
        if (ENA) begin
            if (|WEA) begin
                mem[ADDRA] <= DIA[W-1:0];
                if (WRITE_MODE_A == "WRITE_FIRST")
                    doa_int <= DIA[READ_WIDTH_A-1:0];
                else if (WRITE_MODE_A == "READ_FIRST")
                    doa_int <= mem[ADDRA][READ_WIDTH_A-1:0];
                // "NO_CHANGE" -> doa_int is left untouched
            end else begin
                doa_int <= mem[ADDRA][READ_WIDTH_A-1:0];
            end
        end
    end

    // ---- Port B --------------------------------------------------------
    always @(posedge CLKB) begin
        if (ENB) begin
            if (|WEB) begin
                mem[ADDRB] <= DIB[W-1:0];
                if (WRITE_MODE_B == "WRITE_FIRST")
                    dob_int <= DIB[READ_WIDTH_B-1:0];
                else if (WRITE_MODE_B == "READ_FIRST")
                    dob_int <= mem[ADDRB][READ_WIDTH_B-1:0];
            end else begin
                dob_int <= mem[ADDRB][READ_WIDTH_B-1:0];
            end
        end
    end

    // ---- Optional output registers (DO*_REG) -----------------------------
    generate
        if (DOA_REG != 0) begin : g_doa_reg
            reg [READ_WIDTH_A-1:0] doa_q = {READ_WIDTH_A{1'b0}};
            always @(posedge CLKA)
                if (RSTA)        doa_q <= {READ_WIDTH_A{1'b0}};
                else if (REGCEA) doa_q <= doa_int;
            assign DOA = doa_q;
        end else begin : g_doa_comb
            assign DOA = doa_int;
        end

        if (DOB_REG != 0) begin : g_dob_reg
            reg [READ_WIDTH_B-1:0] dob_q = {READ_WIDTH_B{1'b0}};
            always @(posedge CLKB)
                if (RSTB)        dob_q <= {READ_WIDTH_B{1'b0}};
                else if (REGCEB) dob_q <= dob_int;
            assign DOB = dob_q;
        end else begin : g_dob_comb
            assign DOB = dob_int;
        end
    endgenerate

endmodule
