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

module RC_switched_opensource
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
  localparam int KEEP_WIDTH   = C_DATA_WIDTH / 8;

  logic  user_clk;
  logic  user_reset;
  logic  user_lnk_up;

  logic  sys_clk;
  logic  rp_reset_n;

  IBUFDS_GTE2 refclk_ibuf (.O(sys_clk), .ODIV2(), .I(sys_clk_p), .CEB(1'b0), .IB(sys_clk_n));

  assign rp_reset_n = sys_rst_n;

  logic                     s_axis_tx_tready;
  logic [C_DATA_WIDTH-1:0]  s_axis_tx_tdata;
  logic [KEEP_WIDTH-1:0]    s_axis_tx_tkeep;
  logic                     s_axis_tx_tlast;
  logic                     s_axis_tx_tvalid;
  logic [3:0]               s_axis_tx_tuser;

  logic [C_DATA_WIDTH-1:0]  m_axis_rx_tdata;
  logic [KEEP_WIDTH-1:0]    m_axis_rx_tkeep;
  logic                     m_axis_rx_tlast;
  logic                     m_axis_rx_tvalid;
  logic [21:0]              m_axis_rx_tuser;
  logic                     m_axis_rx_tready;

  logic [15:0]              cfg_status_wire;
  logic                     cfg_msg_err_fatal_wire;
  logic [5:0]               rport_tx_buf_av;

  host_bridge pcie_inst (

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

    .s_axis_tx_tready               ( s_axis_tx_tready ),
    .s_axis_tx_tdata                ( s_axis_tx_tdata ),
    .s_axis_tx_tkeep                ( s_axis_tx_tkeep ),
    .s_axis_tx_tuser                ( s_axis_tx_tuser ),
    .s_axis_tx_tlast                ( s_axis_tx_tlast ),
    .s_axis_tx_tvalid               ( s_axis_tx_tvalid ),

    .m_axis_rx_tdata                ( m_axis_rx_tdata ),
    .m_axis_rx_tkeep                ( m_axis_rx_tkeep ),
    .m_axis_rx_tlast                ( m_axis_rx_tlast ),
    .m_axis_rx_tvalid               ( m_axis_rx_tvalid ),
    .m_axis_rx_tready               ( m_axis_rx_tready ),
    .m_axis_rx_tuser                ( m_axis_rx_tuser ),

    .tx_buf_av                      ( rport_tx_buf_av ),
    .cfg_status                     ( cfg_status_wire ),
    .cfg_msg_received_err_fatal     ( cfg_msg_err_fatal_wire )
  );

  riscv_pcie_soc soc_inst (
    .clk                        ( user_clk ),
    .resetn                     ( ~user_reset && user_lnk_up ),

    .s_axis_tx_tdata            ( s_axis_tx_tdata ),
    .s_axis_tx_tkeep            ( s_axis_tx_tkeep ),
    .s_axis_tx_tlast            ( s_axis_tx_tlast ),
    .s_axis_tx_tvalid           ( s_axis_tx_tvalid ),
    .s_axis_tx_tready           ( s_axis_tx_tready ),

    .m_axis_rx_tdata            ( m_axis_rx_tdata ),
    .m_axis_rx_tkeep            ( m_axis_rx_tkeep ),
    .m_axis_rx_tlast            ( m_axis_rx_tlast ),
    .m_axis_rx_tvalid           ( m_axis_rx_tvalid ),
    .m_axis_rx_tready           ( m_axis_rx_tready ),

    .cfg_status                 ( cfg_status_wire ),
    .cfg_msg_received_err_fatal ( cfg_msg_err_fatal_wire ),

    .tx_buf_av                  ( rport_tx_buf_av )
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
