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

// PCIE descriptors: every TLP header and sideband bit position lives here, and
// only here. The RTL declares signals of these types and uses their members.
//
// Layout as on the 64-bit transaction interface of the PCIE_2_1 hard macro --
// 7 Series FPGAs Integrated Block for PCI Express, UG477 (0.doc/xilinx),
// chapter 5 and tables 2-9 / 2-10, for the 64-bit interface this design
// uses (TRN_DATA_W = 64): a TLP starts with header DW0 in
// tdata[31:0] and DW1 in tdata[63:32]; DW2 and DW3 follow in the next beat.
// Header fields follow the PCI Express Base Specification. Reserved bits are
// listed as rsvd0, rsvd1, ... so that each struct spans its full width.

package pcie_pkg;
  import link_pkg::*;

  // TRN / AXI-Stream widths of this design: declared and sized here, used
  // everywhere else (interface instances and modules)
  localparam int TRN_DATA_W    = 64;
  localparam int TRN_KEEP_W    = TRN_DATA_W / 8;
  localparam int TRN_REM_W     = 1;

  // User clock (user_clk): PCIE_2_1 USERCLK = USERCLK2, the TRN bus and the SOC.
  // The 64-bit TRN bus carries the link's bandwidth at this rate (UG477 table
  // 2-8). PCIE_2_1 encoding: 1 = 62.5 MHz, 2 = 125 MHz, 3 = 250 MHz.
  //   x1 Gen1 / Gen2:  62.5 MHz  (250 / 500 MB/s)
  //   x4 Gen1:          125 MHz  (1 GB/s)
  //   x4 Gen2:          250 MHz  (2 GB/s; 128-bit TRN would need only 125 MHz)
  localparam int USER_CLK_FREQ = (PCIE_LANES == 1) ? 1 : (PCIE_GEN == 1) ? 2 : 3;

  // ---- TLP header -----------------------------------------------------------

  // DW0, common to all TLPs
  typedef struct packed {
    logic       rsvd0;     // [31]
    logic [1:0] fmt;       // [30:29] [0]: 4-DW header, [1]: with data
    logic [4:0] tlp_type;  // [28:24]
    logic       rsvd1;     // [23]
    logic [2:0] tc;        // [22:20] traffic class
    logic [3:0] rsvd2;     // [19:16]
    logic       td;        // [15]    TLP digest (ECRC) present
    logic       ep;        // [14]    poisoned
    logic [1:0] attr;      // [13:12]
    logic [1:0] rsvd3;     // [11:10]
    logic [9:0] length;    // [9:0]   payload length in DW, 0 = 1024
  } pcie_tlp_dw0_t;

  // tlp_type codes the design decodes
  localparam logic [4:0] TLP_TYPE_CPL = 5'b01010;  // Completion (Cpl, CplD)
  localparam logic [3:0] TLP_TYPE_CFG = 4'b0010;   // tlp_type[4:1]: Configuration;
                                                   // tlp_type[0]: Type 0 / Type 1

  // Completion DW1
  typedef struct packed {
    logic [15:0] completer_id;  // [31:16]
    logic [2:0]  cpl_status;    // [15:13]
    logic        bcm;           // [12]
    logic [11:0] byte_count;    // [11:0]
  } pcie_cpl_dw1_t;

  // Completion DW2
  typedef struct packed {
    logic [15:0] requester_id;  // [31:16]
    logic [7:0]  tag;           // [15:8]
    logic        rsvd0;         // [7]
    logic [6:0]  lower_addr;    // [6:0]
  } pcie_cpl_dw2_t;

  // Configuration request DW2
  typedef struct packed {
    logic [7:0] bus;      // [31:24]
    logic [4:0] device;   // [23:19]
    logic [2:0] func;     // [18:16]
    logic [3:0] rsvd0;    // [15:12]
    logic [3:0] ext_reg;  // [11:8]
    logic [5:0] reg_num;  // [7:2]
    logic [1:0] rsvd1;    // [1:0]
  } pcie_cfg_dw2_t;

  // First beat of a TLP on the 64-bit bus
  typedef struct packed {
    logic [31:0]   dw1;  // [63:32]
    pcie_tlp_dw0_t dw0;  // [31:0]
  } pcie_trn_desc_t;

  // ---- AXI-Stream sideband --------------------------------------------------

  // s_axis_tx_tuser (UG477 table 2-9)
  typedef struct packed {
    logic src_dsc;   // [3] source discontinue
    logic str;       // [2] streamed
    logic err_fwd;   // [1] error forward (poison)
    logic ecrc_gen;  // [0] generate ECRC
  } pcie_tx_tuser_t;

  // m_axis_rx_tuser on the 64-bit interface (UG477 table 2-10); bits [21:10]
  // (is_sof, is_eof) exist on the 128-bit interface only -- on 64 bits the
  // end of a packet is tlast
  typedef struct packed {
    logic [7:0] bar_hit;   // [9:2] [7]: expansion ROM
    logic       err_fwd;   // [1]
    logic       ecrc_err;  // [0]
  } pcie_rx_tuser_t;

endpackage

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
