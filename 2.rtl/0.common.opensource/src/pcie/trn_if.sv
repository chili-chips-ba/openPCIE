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

interface trn_if #(
  parameter int DATA_W = 64,
  parameter int REM_W  = 1
);
  // TRN ("transaction") bus: the native TLP port of the PCIE_2_1 hard block.
  // trn_bridge converts AXI-Stream to and from it.

  // TX: user -> core
  logic [DATA_W-1:0] td;
  logic [REM_W-1:0]  trem;
  logic              tsof, teof, tsrc_rdy, tsrc_dsc, terrfwd, tstr, tecrc_gen, tcfg_gnt;
  logic              tdst_rdy, tcfg_req;
  logic        [5:0] tbuf_av;

  // RX: core -> user
  logic [DATA_W-1:0] rd;
  logic [REM_W-1:0]  rrem;
  logic              rsof, reof, rsrc_rdy, rsrc_dsc, rerrfwd, recrc_err;
  logic        [6:0] rbar_hit;
  logic              rdst_rdy;

  // status: core -> user
  logic              lnk_up;           // link up, in the user clock domain
  logic       [31:0] rx_dllp_data;     // received DLLP (tied off: not used yet)
  logic              rx_dllp_src_rdy;

  modport user (output td, trem, tsof, teof, tsrc_rdy, tsrc_dsc, terrfwd, tstr, tecrc_gen, tcfg_gnt, rdst_rdy,
                input  tdst_rdy, tcfg_req, tbuf_av, rd, rrem, rsof, reof, rsrc_rdy, rsrc_dsc, rerrfwd, recrc_err, rbar_hit,
                       lnk_up, rx_dllp_data, rx_dllp_src_rdy);
  modport core (input  td, trem, tsof, teof, tsrc_rdy, tsrc_dsc, terrfwd, tstr, tecrc_gen, tcfg_gnt, rdst_rdy,
                output tdst_rdy, tcfg_req, tbuf_av, rd, rrem, rsof, reof, rsrc_rdy, rsrc_dsc, rerrfwd, recrc_err, rbar_hit,
                       lnk_up, rx_dllp_data, rx_dllp_src_rdy);
endinterface
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 11, 2026
// -----------------------------------------------------------------------------
