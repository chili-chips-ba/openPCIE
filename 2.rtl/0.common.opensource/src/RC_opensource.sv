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
  import pcie_pkg::*;
(
    input logic refclk_p,
    input logic refclk_n,

    input  logic [PCIE_LANES-1:0] rxn,
    input  logic [PCIE_LANES-1:0] rxp,
    output logic [PCIE_LANES-1:0] txn,
    output logic [PCIE_LANES-1:0] txp,

    input logic perst_n,  // PERST# from the connector (pin J1), active low

    output logic [3:0] led_link_up,

    output logic clk_req
);


  logic user_clk;
  logic core_rst_n;
  logic trn_link_up;
  logic fw_pass;




  // TLP streams between the SOC and the PCIE stack
  axis_if #(
      .DATA_W(TRN_DATA_W),
      .USER_W($bits(pcie_tx_tuser_t))
  ) s_axis_tx ();
  axis_if #(
      .DATA_W(TRN_DATA_W),
      .USER_W($bits(pcie_rx_tuser_t))
  ) m_axis_rx ();

  cfg_if cfg ();

  pcie_top u_pcie (
      .pci_exp_txp(txp),
      .pci_exp_txn(txn),
      .pci_exp_rxp(rxp),
      .pci_exp_rxn(rxn),

      .refclk_p(refclk_p),
      .refclk_n(refclk_n),
      .perst_n (perst_n),

      .user_clk   (user_clk),
      .core_rst_n (core_rst_n),
      .trn_link_up(trn_link_up),

      .s_axis_tx(s_axis_tx),
      .m_axis_rx(m_axis_rx),

      .cfg(cfg)
  );

  riscv_pcie_soc u_soc (
      .clk   (user_clk),
      .resetn(core_rst_n),

      .s_axis_tx(s_axis_tx),
      .m_axis_rx(m_axis_rx),

      .cfg(cfg),

      .fw_pass(fw_pass)
  );

  // LEDs are active low: [3] the firmware passed its self-test, [2] link up
  assign led_link_up = {~fw_pass, ~trn_link_up, 2'b11};

  assign clk_req     = 1'b0;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
