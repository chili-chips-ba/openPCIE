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

module phy_top
  import link_pkg::*;
(
    input logic [5:0] pl_ltssm_state,

    pipe_if.phy pipe_mac,

    output logic [PCIE_LANES-1:0] pci_exp_txn,
    output logic [PCIE_LANES-1:0] pci_exp_txp,
    input  logic [PCIE_LANES-1:0] pci_exp_rxn,
    input  logic [PCIE_LANES-1:0] pci_exp_rxp,

    input logic refclk_p,   // 100 MHz PCIE REFCLK+
    input logic refclk_n,   // REFCLK-
    input logic rst125_n,   // released on clk125
    input logic pipe_rst_n, // released on pipe_clk

    input  logic pipe_clk_in,
    input  logic pipe_drp_clk_in,
    input  logic pipe_mmcm_lock_in,
    output logic pipe_txoutclk_out,
    output logic pipe_clk_sel_out,

    output logic phy_rdy_n
);

  logic [PCIE_LANES-1:0] phystatus_rst;

  // PIPE towards gtp_wrapper (GTP side, 32-bit per lane)
  pipe_if #(
      .LANES (PCIE_LANES),
      .DATA_W(32)
  ) pipe_phy ();

  logic all_phystatus_rst;

  mac2phy u_mac2phy (
      .pipe_mac      (pipe_mac),
      .pipe_phy      (pipe_phy),
      .pl_ltssm_state(pl_ltssm_state),
      .pipe_clk      (pipe_clk_in),
      .pipe_rst_n    (pipe_rst_n),
      .phy_rdy_n     (phy_rdy_n)
  );

  gtp_wrapper u_gtp_wrapper (
      .refclk_p  (refclk_p),
      .refclk_n  (refclk_n),
      .rst125_n  (rst125_n),
      .pipe_rst_n(pipe_rst_n),

      .pipe(pipe_phy),
      .txp (pci_exp_txp),
      .txn (pci_exp_txn),

      .rxp(pci_exp_rxp),
      .rxn(pci_exp_rxn),

      .phystatus_rst(phystatus_rst),

      .pipe_clk    (pipe_clk_in),
      .clk125      (pipe_drp_clk_in),
      .mmcm_lock   (pipe_mmcm_lock_in),
      .txoutclk    (pipe_txoutclk_out),
      .pipe_clk_sel(pipe_clk_sel_out)
  );

  assign all_phystatus_rst = &phystatus_rst;

  always_ff @(posedge pipe_clk_in or negedge pipe_rst_n) begin
    if (!pipe_rst_n) begin
      phy_rdy_n <= 1'b1;  // not ready: holds SYSRSTN of PCIE_2_1 asserted
    end
    else begin
      phy_rdy_n <= all_phystatus_rst;
    end
  end


endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
