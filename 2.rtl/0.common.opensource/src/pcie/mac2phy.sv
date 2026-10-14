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

module mac2phy
  import link_pkg::*;
(
    // MAC side: 16-bit PIPE from pcie_core
    pipe_if.phy pipe_mac,
    // PHY side: 32-bit PIPE to gtp_wrapper
    pipe_if.mac pipe_phy,

    input logic [5:0] pl_ltssm_state,  // gates the EIOS filter
    input logic       pipe_clk,
    input logic       pipe_rst_n,      // released on pipe_clk
    input logic       phy_rdy_n        // reset of the EIOS filters
);

  logic [5:0] pl_ltssm_state_q;

  always_ff @(posedge pipe_clk or negedge pipe_rst_n) begin
    if (!pipe_rst_n) begin
      pl_ltssm_state_q <= 6'b0;
    end
    else begin
      pl_ltssm_state_q <= pl_ltssm_state;
    end
  end

  logic plm_in_l0;
  assign plm_in_l0 = (pl_ltssm_state_q == 6'h16);

  genvar i;
  generate
    for (i = 0; i < PCIE_LANES; i = i + 1) begin : lane_gen

      // RX: the 16 bits used of the 32-bit GTP lane, EIOS filter, MAC lane
      pipe_rx_lane_t gt_rx;
      assign gt_rx = '{
              char_is_k: pipe_phy.rx[i].char_is_k[1:0],
              data: pipe_phy.rx[i].data[15:0],
              valid: pipe_phy.rx[i].valid,
              chanisaligned: pipe_phy.rx[i].chanisaligned,
              status: pipe_phy.rx[i].status,
              phy_status: pipe_phy.rx[i].phy_status,
              elec_idle: pipe_phy.rx[i].elec_idle
          };

      rx_eios_filter u_rx_eios_filter (
          .user_rx  (pipe_mac.rx[i]),
          .gt_rx    (gt_rx),
          .plm_in_l0(plm_in_l0),
          .pipe_clk (pipe_clk),
          .reset    (phy_rdy_n)
      );

      // TX: 16-bit MAC lane -> 32-bit GTP lane (upper half unused at 2.5/5 GT/s)
      assign pipe_phy.tx[i].char_is_k  = {2'd0, pipe_mac.tx[i].char_is_k};
      assign pipe_phy.tx[i].data       = {16'd0, pipe_mac.tx[i].data};
      assign pipe_phy.tx[i].compliance = pipe_mac.tx[i].compliance;
      assign pipe_phy.tx[i].elec_idle  = pipe_mac.tx[i].elec_idle;
      assign pipe_phy.tx[i].powerdown  = pipe_mac.tx[i].powerdown;
      assign pipe_phy.rx_polarity[i]   = pipe_mac.rx_polarity[i];

    end
  endgenerate

  assign pipe_phy.tx_ctrl = pipe_mac.tx_ctrl;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
