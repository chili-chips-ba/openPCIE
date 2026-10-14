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

module trn_tx
  import pcie_pkg::*;
(
    axis_if.slave s_axis_tx,
    trn_if.user   trn,        // TX half: td ... tecrc_gen, tdst_rdy, link_up

    input logic tready_thrtl,
    input logic clk62m5,
    input logic core_rst_n
);


  logic           [TRN_DATA_W-1:0] reg_tdata;
  logic                            reg_tvalid;
  logic                            reg_trem;  // tkeep[7]: upper TRN_DATA_W of the beat valid
  pcie_tx_tuser_t                  reg_tuser;
  logic                            reg_tlast;

  logic                            trn_in_packet;
  logic                            axi_in_packet;
  logic                            disable_trn;
  logic                            reg_disable_trn;
  logic                            reg_tsrc_rdy;

  logic                            axi_beat_live;
  assign axi_beat_live = s_axis_tx.tvalid && s_axis_tx.tready;
  logic axi_end_packet;
  assign axi_end_packet = axi_beat_live && s_axis_tx.tlast;

  assign trn.td         = {reg_tdata[31:0], reg_tdata[63:32]};

  assign trn.tsof       = reg_tvalid && !trn_in_packet;

  always_ff @(posedge clk62m5 or negedge core_rst_n) begin
    if (!core_rst_n) begin
      trn_in_packet <= 1'b0;
    end
    else begin
      if (trn.tsof && trn.tsrc_rdy && trn.tdst_rdy && !trn.teof) begin
        trn_in_packet <= 1'b1;
      end
      else if ((trn_in_packet && trn.teof && trn.tsrc_rdy) || !trn.link_up) begin
        trn_in_packet <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk62m5 or negedge core_rst_n) begin
    if (!core_rst_n) begin
      axi_in_packet <= 1'b0;
    end
    else begin
      if (axi_beat_live && !s_axis_tx.tlast) begin
        axi_in_packet <= 1'b1;
      end
      else if (axi_beat_live) begin
        axi_in_packet <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk62m5 or negedge core_rst_n) begin
    if (!core_rst_n) begin
      reg_disable_trn <= 1'b0;
    end
    else begin
      if (axi_in_packet && !trn.link_up && !axi_end_packet) begin
        reg_disable_trn <= 1'b1;
      end
      else if (axi_end_packet) begin
        reg_disable_trn <= 1'b0;
      end
    end
  end
  assign disable_trn   = reg_disable_trn || !trn.link_up;

  assign trn.trem      = reg_trem;

  assign trn.teof      = reg_tlast;
  assign trn.tecrc_gen = reg_tuser.ecrc_gen;
  assign trn.terrfwd   = reg_tuser.err_fwd;
  assign trn.tstr      = reg_tuser.str;
  assign trn.tsrc_dsc  = reg_tuser.src_dsc;

  always_ff @(posedge clk62m5 or negedge core_rst_n) begin
    if (!core_rst_n) begin
      reg_tdata    <= {TRN_DATA_W{1'b0}};
      reg_tvalid   <= 1'b0;
      reg_trem     <= 1'b0;
      reg_tlast    <= 1'b0;
      reg_tuser    <= '0;
      reg_tsrc_rdy <= 1'b0;
    end
    else begin
      reg_tdata    <= s_axis_tx.tdata;
      reg_tvalid   <= s_axis_tx.tvalid;
      reg_trem     <= s_axis_tx.tkeep[7];
      reg_tlast    <= s_axis_tx.tlast;
      reg_tuser    <= s_axis_tx.tuser;
      reg_tsrc_rdy <= axi_beat_live && !disable_trn;
    end
  end

  assign trn.tsrc_rdy     = reg_tsrc_rdy;
  assign s_axis_tx.tready = tready_thrtl;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
