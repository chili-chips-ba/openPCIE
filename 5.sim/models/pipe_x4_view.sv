//==========================================================================
// Copyright (C) 2026 Chili.CHIPS
//--------------------------------------------------------------------------
// SPDX-License-Identifier: BSD-3-Clause
//--------------------------------------------------------------------------
// Description:
//   pipe_x4_view: a x4 PIPE link, both directions, lane by lane under the
//   names the multi-lane PIPE and Data Link Layer decoders auto-bind
//   (wavecrux-decoders decoders/pcie SPEC.md §12: data, datak, then
//   data<l>, datak<l> per lane). dn = RC -> EP, up = EP -> RC.
//
//   phy_top.PIPE.sv has one next to the pcieVHost EP; tb.sv dumps it only
//   at x4 (make SIM_LANES=4), so an x1 dump has no lanes 1 to 3 for
//   auto-bind to find. A module beside the EP, not a scope inside it:
//   xsim drops $dumpvars on a scope below one already dumped, and cannot
//   name a generate block at all.
//==========================================================================

module pipe_x4_view #(
    parameter int DataWidth = 16
) (
    input logic                     pclk,
    input logic [4*DataWidth  -1:0] dn,   // RC -> EP, lane l in [l*DataWidth +: DataWidth]
    input logic [4*DataWidth/8-1:0] dnk,
    input logic [4*DataWidth  -1:0] up,   // EP -> RC
    input logic [4*DataWidth/8-1:0] upk
);

  logic                   pipe_dn_pclk, pipe_up_pclk;
  logic [  DataWidth-1:0] pipe_dn_data,  pipe_dn_data1,  pipe_dn_data2,  pipe_dn_data3;
  logic [DataWidth/8-1:0] pipe_dn_datak, pipe_dn_datak1, pipe_dn_datak2, pipe_dn_datak3;
  logic [  DataWidth-1:0] pipe_up_data,  pipe_up_data1,  pipe_up_data2,  pipe_up_data3;
  logic [DataWidth/8-1:0] pipe_up_datak, pipe_up_datak1, pipe_up_datak2, pipe_up_datak3;

  assign pipe_dn_pclk = pclk;
  assign pipe_up_pclk = pclk;
  assign {pipe_dn_data3,  pipe_dn_data2,  pipe_dn_data1,  pipe_dn_data}  = dn;
  assign {pipe_dn_datak3, pipe_dn_datak2, pipe_dn_datak1, pipe_dn_datak} = dnk;
  assign {pipe_up_data3,  pipe_up_data2,  pipe_up_data1,  pipe_up_data}  = up;
  assign {pipe_up_datak3, pipe_up_datak2, pipe_up_datak1, pipe_up_datak} = upk;

endmodule: pipe_x4_view

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 24, 2026
// -----------------------------------------------------------------------------
