// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openPCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
// Description:
//   Simulation-only interface: one direction of a TLP stream, one DW per
//   clock, framed by SOP/EOP. Driven by tlp_dw_monitor.sv, read by
//   tlp_wavecrux_view.sv.
//
//   The member names are the signal roles of the openPCIE PCIe TLP decoder
//   plugin (5.sim/tools/wavecrux-pcie-tlp), so a dumped instance already
//   binds the decoder's five required inputs by name:
//
//     clk        stream clock, rising edge samples
//     tlp_data   one TLP DW, byte 0 (Fmt/Type) in bits [31:24]
//     tlp_sop    first DW of a TLP
//     tlp_eop    last DW of a TLP
//     tlp_valid  tlp_data carries a DW this cycle
//==========================================================================

`timescale 1ns / 1ps

interface tlp_dw_if (
  input logic clk
);
  logic [31:0] tlp_data;
  logic        tlp_sop;
  logic        tlp_eop;
  logic        tlp_valid;

  modport source (input clk, output tlp_data, tlp_sop, tlp_eop, tlp_valid);
  modport sink   (input clk, input  tlp_data, tlp_sop, tlp_eop, tlp_valid);
endinterface: tlp_dw_if

//--------------------------------------------------------------------------
// Revision history:
//  2026/10/06 - initial creation
//--------------------------------------------------------------------------
