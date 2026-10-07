// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openPCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
// Description:
//   Simulation-only TLP monitor, for waveform viewers with a PCIe TLP decoder.
//
//   The SOC talks to the PCIe core over a 64-bit AXI-Stream: two DWs per beat,
//   DW0 in [31:0], with tkeep marking a lone DW in the last beat. Decoders such
//   as the one in WaveCrux expect one DW per beat instead, framed by start- and
//   end-of-packet flags. This module re-times the 64-bit stream into exactly
//   that, one DW per clock, through a small queue:
//
//     tlp_data[31:0]  one TLP DW, byte 0 (Fmt/Type) in bits [31:24]
//     tlp_sop         first DW of a TLP
//     tlp_eop         last DW of a TLP
//     tlp_valid       tlp_data carries a DW this cycle
//
//   The output lags the AXI-Stream by a few clocks -- nothing in the design
//   reads it, it only exists to be dumped. Port names match the decoder's
//   roles, so it binds them automatically.
//==========================================================================

`timescale 1ns / 1ps

module tlp_dw_monitor (
    input  logic        clk,

    input  logic [63:0] axis_tdata,
    input  logic [7:0]  axis_tkeep,
    input  logic        axis_tlast,
    input  logic        axis_tvalid,
    input  logic        axis_tready,

    output logic [31:0] tlp_data,
    output logic        tlp_sop,
    output logic        tlp_eop,
    output logic        tlp_valid
);

    typedef struct packed {
        logic [31:0] dw;
        logic        sop;
        logic        eop;
    } dw_t;

    dw_t  queue [$];
    logic in_packet = 1'b0;

    initial begin
        tlp_data  = '0;
        tlp_sop   = 1'b0;
        tlp_eop   = 1'b0;
        tlp_valid = 1'b0;
    end

    always @(posedge clk) begin
        if (axis_tvalid && axis_tready) begin
            // Upper DW is only present when tkeep says so (3-DW TLP tails)
            queue.push_back('{axis_tdata[31:0], !in_packet,
                              axis_tlast && !axis_tkeep[4]});
            if (axis_tkeep[4]) begin
                queue.push_back('{axis_tdata[63:32], 1'b0, axis_tlast});
            end
            in_packet = !axis_tlast;
        end

        if (queue.size() != 0) begin
            dw_t d = queue.pop_front();
            tlp_data  <= d.dw;
            tlp_sop   <= d.sop;
            tlp_eop   <= d.eop;
            tlp_valid <= 1'b1;
        end else begin
            tlp_sop   <= 1'b0;
            tlp_eop   <= 1'b0;
            tlp_valid <= 1'b0;
        end
    end

endmodule: tlp_dw_monitor

//--------------------------------------------------------------------------
// Revision history:
//  2026/10/06 - initial creation, feeds the WaveCrux PCIe TLP decoder
//--------------------------------------------------------------------------
