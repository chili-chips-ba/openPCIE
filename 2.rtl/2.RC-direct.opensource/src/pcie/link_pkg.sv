// SPDX-FileCopyrightText: 2026 Chili.CHIPS*ba
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openPCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
//                   Copyright (C) 2026 Chili.CHIPS*ba
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

package link_pkg;

  localparam int PIPE_MAX_LANES = 8;
  localparam int PCIE_LANES     = 1;

  typedef struct packed {
    logic [1:0]  char_is_k;
    logic [15:0] data;
    logic        compliance;
    logic        elec_idle;
    logic [1:0]  powerdown;
  } pipe_tx_lane_t;

  typedef struct packed {
    logic [1:0]  char_is_k;
    logic [15:0] data;
    logic        valid;
    logic        chanisaligned;
    logic [2:0]  status;
    logic        phy_status;
    logic        elec_idle;
  } pipe_rx_lane_t;

  typedef struct packed {
    logic        rcvr_det;
    logic        reset;
    logic        rate;
    logic        deemph;
    logic [2:0]  margin;
    logic        swing;
  } pipe_tx_ctrl_t;

  localparam pipe_rx_lane_t PIPE_RX_LANE_RST =
    '{char_is_k:2'b00, data:16'h0, valid:1'b0, chanisaligned:1'b0,
      status:3'b000, phy_status:1'b0, elec_idle:1'b0};
  localparam pipe_tx_lane_t PIPE_TX_LANE_RST =
    '{char_is_k:2'b00, data:16'h0, compliance:1'b0, elec_idle:1'b1, powerdown:2'b10};
  localparam pipe_tx_ctrl_t PIPE_TX_CTRL_RST =
    '{rcvr_det:1'b0, reset:1'b1, rate:1'b0, deemph:1'b1, margin:3'b000, swing:1'b0};

  localparam pipe_rx_lane_t PIPE_RX_LANE_TIE =
    '{char_is_k:2'b00, data:16'h0, valid:1'b0, chanisaligned:1'b0,
      status:3'b000, phy_status:1'b0, elec_idle:1'b1};
  localparam pipe_tx_lane_t PIPE_TX_LANE_TIE =
    '{char_is_k:2'b00, data:16'h0, compliance:1'b0, elec_idle:1'b1, powerdown:2'b00};

  typedef struct packed {
    logic [15:0] status;
    logic [15:0] command;
    logic [15:0] dstatus;
    logic [15:0] dcommand;
    logic [15:0] lstatus;
    logic [15:0] lcommand;
    logic [15:0] dcommand2;
  } cfg_regs_t;

endpackage
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
