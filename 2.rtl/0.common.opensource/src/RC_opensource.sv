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

module RC_opensource
  import link_pkg::*;
(
    input  logic                    sys_clk_p,
    input  logic                    sys_clk_n,

    input  logic [PCIE_LANES-1:0]   RXN,
    input  logic [PCIE_LANES-1:0]   RXP,
    output logic [PCIE_LANES-1:0]   TXN,
    output logic [PCIE_LANES-1:0]   TXP,

    input  logic                    sys_rst_n,

    output logic  [3:0]             led_link_up,

    output logic                    clk_req
  );

  localparam int C_DATA_WIDTH = 64;

  logic  user_clk;
  logic  user_reset;
  logic  user_lnk_up;

  logic  sys_clk;
  logic  rp_reset_n;

  IBUFDS_GTE2 refclk_ibuf (.O(sys_clk), .ODIV2(), .I(sys_clk_p), .CEB(1'b0), .IB(sys_clk_n));

  assign rp_reset_n = sys_rst_n;

  // TLP streams between the SOC and the PCIE stack
  axis_if #(.DATA_W(C_DATA_WIDTH), .USER_W(4))  s_axis_tx ();
  axis_if #(.DATA_W(C_DATA_WIDTH), .USER_W(22)) m_axis_rx ();

  cfg_if                                          cfg    ();

  pcie_top u_pcie (
    .pci_exp_txp                    ( TXP ),
    .pci_exp_txn                    ( TXN ),
    .pci_exp_rxp                    ( RXP ),
    .pci_exp_rxn                    ( RXN ),

    .sys_clk                        ( sys_clk ),
    .sys_rst_n                      ( rp_reset_n ),
    .pipe_mmcm_rst_n                ( 1'b1 ),

    .user_clk_out                   ( user_clk ),
    .user_reset_out                 ( user_reset ),
    .user_lnk_up                    ( user_lnk_up ),

    .s_axis_tx                      ( s_axis_tx ),
    .m_axis_rx                      ( m_axis_rx ),

    .cfg                         ( cfg )
  );

  riscv_pcie_soc u_soc (
    .clk                        ( user_clk ),
    .resetn                     ( ~user_reset && user_lnk_up ),

    .s_axis_tx                  ( s_axis_tx ),
    .m_axis_rx                  ( m_axis_rx ),

    .cfg                     ( cfg )
  );

  assign led_link_up = {1'b1, ~user_lnk_up, 2'b11};

  assign clk_req = 1'b0;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
