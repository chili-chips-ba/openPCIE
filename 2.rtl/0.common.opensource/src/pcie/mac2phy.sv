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
  pipe_if.phy                         pipe_mac,
  // PHY side: 32-bit PIPE to gtp_wrapper
  pipe_if.mac                         pipe_phy,

  input  wire [5:0]                   pl_ltssm_state,   // gates the EIOS filter
  input  wire                         pipe_clk,
  input  wire                         clock_locked,     // async reset of the LTSSM register
  input  wire                         phy_rdy_n         // reset of the EIOS filters
);

  // Per lane: TX 16 -> 32 bit widening, RX EIOS filter then 32 -> 16 bit.

  wire [  7:0]                       gt_rx_phy_status_wire;
  wire [ 31:0]                       gt_rx_data_k_wire;
  wire [255:0]                       gt_rx_data_wire;
  wire [  7:0]                       gt_rx_elec_idle_wire;
  wire [ 23:0]                       gt_rx_status_wire;
  wire [  7:0]                       gt_rx_valid_wire;

  logic [5:0] pl_ltssm_state_q;

  always_ff @(posedge pipe_clk or negedge clock_locked) begin
    if (!clock_locked) pl_ltssm_state_q <= 6'b0;
    else               pl_ltssm_state_q <= pl_ltssm_state;
  end

  wire plm_in_l0 = (pl_ltssm_state_q == 6'h16);
  wire plm_in_rs = (pl_ltssm_state_q == 6'h1f);

  genvar i;
  generate for (i = 0; i < LINK_CAP_MAX_LINK_WIDTH; i = i + 1)
    begin : rx_eios_filter_gen

      rx_eios_filter u_rx_eios_filter (
        .USER_RXCHARISK     (gt_rx_data_k_wire[(4*i)+:2]),
        .USER_RXDATA        (gt_rx_data_wire[(32*i)+:16]),
        .USER_RXVALID       (gt_rx_valid_wire[i]),
        .USER_RXELECIDLE    (gt_rx_elec_idle_wire[i]),
        .USER_RX_STATUS     (gt_rx_status_wire[(3*i)+:3]),
        .USER_RX_PHY_STATUS (gt_rx_phy_status_wire[i]),

        .GT_RXCHARISK       (pipe_phy.rx[i].char_is_k[1:0]),
        .GT_RXDATA          (pipe_phy.rx[i].data[15:0]),
        .GT_RXVALID         (pipe_phy.rx[i].valid),
        .GT_RXELECIDLE      (pipe_phy.rx[i].elec_idle),
        .GT_RX_STATUS       (pipe_phy.rx[i].status),
        .GT_RX_PHY_STATUS   (pipe_phy.rx[i].phy_status),

        .PLM_IN_L0          (plm_in_l0),
        .PLM_IN_RS          (plm_in_rs),
        .USER_CLK           (pipe_clk),
        .RESET              (phy_rdy_n)
      );

    end
  endgenerate

  generate for (i = 0; i < PIPE_MAX_LANES; i = i + 1)
    begin : lane_map

      if (i < LINK_CAP_MAX_LINK_WIDTH) begin : active
        // 16-bit MAC lane -> 32-bit GTP lane (upper half unused at 2.5/5 GT/s)
        assign pipe_phy.tx[i].char_is_k  = { 2'd0, pipe_mac.tx[i].char_is_k};
        assign pipe_phy.tx[i].data       = {16'd0, pipe_mac.tx[i].data};
        assign pipe_phy.tx[i].compliance = pipe_mac.tx[i].compliance;
        assign pipe_phy.tx[i].elec_idle  = pipe_mac.tx[i].elec_idle;
        assign pipe_phy.tx[i].powerdown  = pipe_mac.tx[i].powerdown;
        assign pipe_phy.rx_polarity[i]   = pipe_mac.rx_polarity[i];

        assign pipe_mac.rx[i].char_is_k     = gt_rx_data_k_wire[(4*i)+:2];
        assign pipe_mac.rx[i].data          = gt_rx_data_wire[(32*i)+:16];
        assign pipe_mac.rx[i].valid         = gt_rx_valid_wire[i];
        assign pipe_mac.rx[i].chanisaligned = pipe_phy.rx[i].chanisaligned;
        assign pipe_mac.rx[i].status        = gt_rx_status_wire[(3*i)+:3];
        assign pipe_mac.rx[i].phy_status    = gt_rx_phy_status_wire[i];
        assign pipe_mac.rx[i].elec_idle     = gt_rx_elec_idle_wire[i];

        assign gt_rx_data_wire  [(32*i)+16+:16] = 16'b0;
        assign gt_rx_data_k_wire[( 4*i)+ 2+: 2] =  2'b0;
      end
      else begin : unused
        assign pipe_mac.rx[i] = PIPE_RX_LANE_TIE;

        assign gt_rx_data_wire  [(32*i)+:32] = 32'b0;
        assign gt_rx_data_k_wire[( 4*i)+: 4] =  4'b0;
      end

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
