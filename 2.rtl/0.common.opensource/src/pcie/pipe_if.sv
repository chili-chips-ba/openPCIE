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

interface pipe_if #(
    parameter int LANES  = link_pkg::PCIE_LANES,
    parameter int DATA_W = 16                     // 16 at the MAC, 32 at the GTP
);
  // PIPE between the MAC (PCIE_2_1) and the PHY (phy_top + gtp_wrapper).
  // Two instances: pipe_mac (16-bit, at the MAC) and pipe_phy (32-bit, at the
  // GTP). The lane fields are in link_pkg order, so at DATA_W = 16 a lane is
  // bit-identical to link_pkg::pipe_tx_lane_t / pipe_rx_lane_t.
  localparam int K_W = DATA_W / 8;

  typedef struct packed {
    logic [K_W-1:0]    char_is_k;
    logic [DATA_W-1:0] data;
    logic              compliance;
    logic              elec_idle;
    logic [1:0]        powerdown;
  } tx_lane_t;

  typedef struct packed {
    logic [K_W-1:0]    char_is_k;
    logic [DATA_W-1:0] data;
    logic              valid;
    logic              chanisaligned;
    logic [2:0]        status;
    logic              phy_status;
    logic              elec_idle;
  } rx_lane_t;

  link_pkg::pipe_tx_ctrl_t             tx_ctrl;  // common to all lanes
  tx_lane_t                [LANES-1:0] tx;
  logic                    [LANES-1:0] rx_polarity;
  rx_lane_t                [LANES-1:0] rx;

  modport mac(output tx_ctrl, tx, rx_polarity, input rx);
  modport phy(input tx_ctrl, tx, rx_polarity, output rx);
endinterface
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
