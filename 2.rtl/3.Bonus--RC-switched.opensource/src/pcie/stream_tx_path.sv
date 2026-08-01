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

module stream_tx_path #(
  localparam int C_DATA_WIDTH = 64,
  localparam int KEEP_WIDTH   = 8,
  localparam int REM_WIDTH    = 1
) (
  input      [C_DATA_WIDTH-1:0] s_axis_tx_tdata,
  input                         s_axis_tx_tvalid,
  output                        s_axis_tx_tready,
  input        [KEEP_WIDTH-1:0] s_axis_tx_tkeep,
  input                         s_axis_tx_tlast,
  input                   [3:0] s_axis_tx_tuser,

  output     [C_DATA_WIDTH-1:0] trn_td,
  output                        trn_tsof,
  output                        trn_teof,
  output                        trn_tsrc_rdy,
  input                         trn_tdst_rdy,
  output                        trn_tsrc_dsc,
  output        [REM_WIDTH-1:0] trn_trem,
  output                        trn_terrfwd,
  output                        trn_tstr,
  output                        trn_tecrc_gen,
  input                         trn_lnk_up,

  input                         tready_thrtl,
  input                         user_clk,
  input                         user_rst
);

  logic  [C_DATA_WIDTH-1:0] reg_tdata;
  logic                     reg_tvalid;
  logic    [KEEP_WIDTH-1:0] reg_tkeep;
  logic               [3:0] reg_tuser;
  logic                     reg_tlast;

  logic                     trn_in_packet;
  logic                     axi_in_packet;
  logic                     disable_trn;
  logic                     reg_disable_trn;
  logic                     reg_tsrc_rdy;

  wire axi_beat_live  = s_axis_tx_tvalid && s_axis_tx_tready;
  wire axi_end_packet = axi_beat_live && s_axis_tx_tlast;

  assign trn_td = {reg_tdata[31:0], reg_tdata[63:32]};

  assign trn_tsof = reg_tvalid && !trn_in_packet;

  always_ff @(posedge user_clk) begin
    if (user_rst) begin
      trn_in_packet <= 1'b0;
    end else begin
      if (trn_tsof && trn_tsrc_rdy && trn_tdst_rdy && !trn_teof)
        trn_in_packet <= 1'b1;
      else if ((trn_in_packet && trn_teof && trn_tsrc_rdy) || !trn_lnk_up)
        trn_in_packet <= 1'b0;
    end
  end

  always_ff @(posedge user_clk) begin
    if (user_rst) begin
      axi_in_packet <= 1'b0;
    end else begin
      if (axi_beat_live && !s_axis_tx_tlast)
        axi_in_packet <= 1'b1;
      else if (axi_beat_live)
        axi_in_packet <= 1'b0;
    end
  end

  always_ff @(posedge user_clk) begin
    if (user_rst) begin
      reg_disable_trn <= 1'b0;
    end else begin
      if (axi_in_packet && !trn_lnk_up && !axi_end_packet)
        reg_disable_trn <= 1'b1;
      else if (axi_end_packet)
        reg_disable_trn <= 1'b0;
    end
  end
  assign disable_trn = reg_disable_trn || !trn_lnk_up;

  assign trn_trem = reg_tkeep[7];

  assign trn_teof      = reg_tlast;
  assign trn_tecrc_gen = reg_tuser[0];
  assign trn_terrfwd   = reg_tuser[1];
  assign trn_tstr      = reg_tuser[2];
  assign trn_tsrc_dsc  = reg_tuser[3];

  always_ff @(posedge user_clk) begin
    if (user_rst) begin
      reg_tdata    <= {C_DATA_WIDTH{1'b0}};
      reg_tvalid   <= 1'b0;
      reg_tkeep    <= {KEEP_WIDTH{1'b0}};
      reg_tlast    <= 1'b0;
      reg_tuser    <= 4'h0;
      reg_tsrc_rdy <= 1'b0;
    end else begin
      reg_tdata    <= s_axis_tx_tdata;
      reg_tvalid   <= s_axis_tx_tvalid;
      reg_tkeep    <= s_axis_tx_tkeep;
      reg_tlast    <= s_axis_tx_tlast;
      reg_tuser    <= s_axis_tx_tuser;
      reg_tsrc_rdy <= axi_beat_live && !disable_trn;
    end
  end

  assign trn_tsrc_rdy     = reg_tsrc_rdy;
  assign s_axis_tx_tready = tready_thrtl;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
