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

interface gtp_if #(parameter int LANES = link_pkg::PCIE_LANES);
  // gtp_wrapper <-> lane_xcvr. One instance; lane_xcvr #(LANE) drives and reads
  // its own slice [LANE]. gtp_wrapper derives the cross-lane values from the
  // per-lane status and sends them back.

  // ---- reset sequencing from init_ctrl, common to all lanes
  logic rst_cpllreset;
  logic rst_rxusrclk_reset;
  logic rst_dclk_reset;
  logic rst_gtreset;
  logic rst_drp_start;
  logic rst_drp_x16;
  logic rst_userrdy;
  logic rst_txsync_start;
  logic rst_idle;

  // ---- cross-lane, from gtp_wrapper
  logic txsyncallin;           // TX phase aligned on all active lanes
  logic rxsyncallin;           // RX phase aligned on all active lanes
  logic txphinitdone_all;
  logic txdlysresetdone_all;
  logic rxdlysresetdone_all;
  logic rxphaligndone_m;       // lane 0 (master)
  logic rxphaligndone_s;       // all other lanes
  logic rxsync_donem_m;        // lane 0
  logic txsyncin;              // lane 0 TXSYNCOUT
  logic rxsyncin;              // lane 0 RXSYNCOUT
  logic [3:0] rxchbondi [LANES];   // channel bonding chain: lane i-1 -> lane i

  // ---- per lane, from lane_xcvr
  logic [LANES-1:0] drp_done;
  logic [LANES-1:0] rxpmaresetdone;
  logic [LANES-1:0] rate_idle;
  logic [LANES-1:0] resetdone;
  logic [LANES-1:0] phystatus;
  logic [LANES-1:0] phystatus_rst;
  logic [LANES-1:0] txsync_done;
  logic [LANES-1:0] active_lane;
  logic [LANES-1:0] txphinitdone;
  logic [LANES-1:0] txdlysresetdone;
  logic [LANES-1:0] txphaligndone;
  logic [LANES-1:0] rxdlysresetdone;
  logic [LANES-1:0] rxphaligndone;
  logic [LANES-1:0] rxsync_donem;
  logic [LANES-1:0] txsyncout;
  logic [LANES-1:0] rxsyncout;
  logic [LANES-1:0] txoutclk;
  logic [LANES-1:0] pclk_sel;
  logic [3:0]       rxchbondo [LANES];

  modport ctrl (
    output rst_cpllreset, rst_rxusrclk_reset, rst_dclk_reset, rst_gtreset, rst_drp_start,
           rst_drp_x16, rst_userrdy, rst_txsync_start, rst_idle,
           txsyncallin, rxsyncallin, txphinitdone_all, txdlysresetdone_all, rxdlysresetdone_all,
           rxphaligndone_m, rxphaligndone_s, rxsync_donem_m, txsyncin, rxsyncin, rxchbondi,
    input  drp_done, rxpmaresetdone, rate_idle, resetdone, phystatus, phystatus_rst,
           txsync_done, active_lane, txphinitdone, txdlysresetdone, txphaligndone, rxdlysresetdone,
           rxphaligndone, rxsync_donem, txsyncout, rxsyncout, txoutclk, pclk_sel, rxchbondo
  );
  modport lane (
    input  rst_cpllreset, rst_rxusrclk_reset, rst_dclk_reset, rst_gtreset, rst_drp_start,
           rst_drp_x16, rst_userrdy, rst_txsync_start, rst_idle,
           txsyncallin, rxsyncallin, txphinitdone_all, txdlysresetdone_all, rxdlysresetdone_all,
           rxphaligndone_m, rxphaligndone_s, rxsync_donem_m, txsyncin, rxsyncin, rxchbondi,
    output drp_done, rxpmaresetdone, rate_idle, resetdone, phystatus, phystatus_rst,
           txsync_done, active_lane, txphinitdone, txdlysresetdone, txphaligndone, rxdlysresetdone,
           rxphaligndone, rxsync_donem, txsyncout, rxsyncout, txoutclk, pclk_sel, rxchbondo
  );
endinterface
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 11, 2026
// -----------------------------------------------------------------------------
