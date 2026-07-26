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

(* DowngradeIPIdentifiedWarnings = "yes" *)
module stream_rx_path #(
  localparam int C_DATA_WIDTH = 64,
  localparam int KEEP_WIDTH   = 8,
  localparam int REM_WIDTH    = 1
  ) (

  output logic [C_DATA_WIDTH-1:0] m_axis_rx_tdata,
  output logic                    m_axis_rx_tvalid,
  input                         m_axis_rx_tready,
  output       [KEEP_WIDTH-1:0] m_axis_rx_tkeep,
  output                        m_axis_rx_tlast,
  output logic             [21:0] m_axis_rx_tuser,

  input      [C_DATA_WIDTH-1:0] trn_rd,
  input                         trn_rsof,
  input                         trn_reof,
  input                         trn_rsrc_rdy,
  output logic                    trn_rdst_rdy,
  input                         trn_rsrc_dsc,
  input         [REM_WIDTH-1:0] trn_rrem,
  input                         trn_rerrfwd,
  input                   [6:0] trn_rbar_hit,
  input                         trn_recrc_err,

  input                         null_rx_tvalid,
  input                         null_rx_tlast,
  input        [KEEP_WIDTH-1:0] null_rx_tkeep,
  input                         null_rdst_rdy,
  input                   [4:0] null_is_eof,

  output                  [2:0] np_counter,
  input                         user_clk,
  input                         user_rst
);


wire              [4:0] is_sof;
wire              [4:0] is_sof_prev;

wire              [4:0] is_eof;
wire              [4:0] is_eof_prev;

logic    [KEEP_WIDTH-1:0] reg_tkeep;
wire   [KEEP_WIDTH-1:0] tkeep;
wire   [KEEP_WIDTH-1:0] tkeep_prev;

logic                     reg_tlast;
wire                    rsrc_rdy_filtered;

wire [C_DATA_WIDTH-1:0] trn_rd_DW_swapped;
logic  [C_DATA_WIDTH-1:0] trn_rd_prev;

wire                    data_hold;
logic                     data_prev;

logic                     trn_reof_prev;
logic     [REM_WIDTH-1:0] trn_rrem_prev;
logic                     trn_rsrc_rdy_prev;
logic                     trn_rsrc_dsc_prev;
logic                     trn_rsof_prev;
logic               [6:0] trn_rbar_hit_prev;
logic                     trn_rerrfwd_prev;
logic                     trn_recrc_err_prev;

logic                     null_mux_sel;
logic                     trn_in_packet;
wire                    dsc_flag;
wire                    dsc_detect;
logic                     reg_dsc_detect;
logic                     trn_rsrc_dsc_d;


assign rsrc_rdy_filtered = trn_rsrc_rdy &&
                                 (trn_in_packet || (trn_rsof && !trn_rsrc_dsc));

always_ff @(posedge user_clk) begin
  if(user_rst) begin
    trn_rd_prev        <= {C_DATA_WIDTH{1'b0}};
    trn_rsof_prev      <= 1'b0;
    trn_rrem_prev      <= {REM_WIDTH{1'b0}};
    trn_rsrc_rdy_prev  <= 1'b0;
    trn_rbar_hit_prev  <= 7'h00;
    trn_rerrfwd_prev   <= 1'b0;
    trn_recrc_err_prev <= 1'b0;
    trn_reof_prev      <= 1'b0;
    trn_rsrc_dsc_prev  <= 1'b0;
  end
  else begin
    if(trn_rdst_rdy) begin
      trn_rd_prev        <= trn_rd_DW_swapped;
      trn_rsof_prev      <= trn_rsof;
      trn_rrem_prev      <= trn_rrem;
      trn_rbar_hit_prev  <= trn_rbar_hit;
      trn_rerrfwd_prev   <= trn_rerrfwd;
      trn_recrc_err_prev <= trn_recrc_err;
      trn_rsrc_rdy_prev  <= rsrc_rdy_filtered;
      trn_reof_prev      <= trn_reof;
      trn_rsrc_dsc_prev  <= trn_rsrc_dsc || dsc_flag;
    end
  end
end



assign trn_rd_DW_swapped = {trn_rd[31:0], trn_rd[63:32]};


always_ff @(posedge user_clk) begin
  if(user_rst) begin
    m_axis_rx_tdata <= {C_DATA_WIDTH{1'b0}};
  end
  else begin
    if(!data_hold) begin
      if(data_prev) begin
        m_axis_rx_tdata <= trn_rd_prev;
      end

      else begin
        m_axis_rx_tdata <= trn_rd_DW_swapped;
      end
    end
  end
end

assign data_hold = (!m_axis_rx_tready && m_axis_rx_tvalid);

always_ff @(posedge user_clk) begin
  if(user_rst) begin
    data_prev <= 1'b0;
  end
  else begin
    data_prev <= data_hold;
  end
end


always_ff @(posedge user_clk) begin
  if(user_rst) begin
    m_axis_rx_tvalid <= 1'b0;
    reg_tlast        <= 1'b0;
    reg_tkeep        <= {KEEP_WIDTH{1'b1}};
    m_axis_rx_tuser  <= 22'h0;
  end
  else begin
    if(!data_hold) begin
      if(null_mux_sel) begin
        m_axis_rx_tvalid <= null_rx_tvalid;
        reg_tlast        <= null_rx_tlast;
        reg_tkeep        <= null_rx_tkeep;
        m_axis_rx_tuser  <= {null_is_eof, 17'h0000};
      end

      else if(data_prev) begin
        m_axis_rx_tvalid <= (trn_rsrc_rdy_prev || dsc_flag);
        reg_tlast        <= trn_reof_prev;
        reg_tkeep        <= tkeep_prev;
        m_axis_rx_tuser  <= {is_eof_prev,
                                  2'b00,
                                  is_sof_prev,
                                  1'b0,
                                  trn_rbar_hit_prev,
                                  trn_rerrfwd_prev,
                                  trn_recrc_err_prev};
      end

      else begin
        m_axis_rx_tvalid <= (rsrc_rdy_filtered || dsc_flag);
        reg_tlast        <= trn_reof;
        reg_tkeep        <= tkeep;
        m_axis_rx_tuser  <= {is_eof,
                                  2'b00,
                                  is_sof,
                                  1'b0,
                                  trn_rbar_hit,
                                  trn_rerrfwd,
                                  trn_recrc_err};
      end
    end
  end
end

assign m_axis_rx_tlast = reg_tlast;
assign m_axis_rx_tkeep = reg_tkeep;


assign tkeep      = trn_rrem      ? 8'hFF : 8'h0F;
assign tkeep_prev = trn_rrem_prev ? 8'hFF : 8'h0F;


assign is_sof      = {(trn_rsof && !trn_rsrc_dsc), 4'b0000};
assign is_sof_prev = {(trn_rsof_prev && !trn_rsrc_dsc_prev), 4'b0000};


assign is_eof      = {trn_reof,      1'b0, trn_rrem,      2'b11};
assign is_eof_prev = {trn_reof_prev, 1'b0, trn_rrem_prev, 2'b11};



always_ff @(posedge user_clk) begin
  if(user_rst) begin
    trn_rdst_rdy <= 1'b0;
  end
  else begin
    if(null_mux_sel && m_axis_rx_tready) begin
      trn_rdst_rdy <= null_rdst_rdy;
    end

    else if(dsc_flag) begin
      trn_rdst_rdy <= 1'b0;
    end

    else if(m_axis_rx_tvalid) begin
      trn_rdst_rdy <= m_axis_rx_tready;
    end

    else begin
      trn_rdst_rdy <= 1'b1;
    end
  end
end

always_ff @(posedge user_clk) begin
  if(user_rst) begin
    null_mux_sel <= 1'b0;
  end
  else begin
    if(null_mux_sel && null_rx_tlast && m_axis_rx_tready)
    begin
      null_mux_sel <= 1'b0;
    end

    else if(dsc_flag && !data_hold) begin
      null_mux_sel <= 1'b1;
    end
  end
end


always_ff @(posedge user_clk) begin
  if(user_rst) begin
    trn_in_packet <= 1'b0;
  end
  else begin
    if(trn_rsof && !trn_reof && rsrc_rdy_filtered && trn_rdst_rdy)
    begin
      trn_in_packet <= 1'b1;
    end
    else if(trn_rsrc_dsc) begin
      trn_in_packet <= 1'b0;
    end
    else if(trn_reof && !trn_rsof && trn_rsrc_rdy && trn_rdst_rdy) begin
      trn_in_packet <= 1'b0;
    end
  end
end


assign dsc_detect = trn_rsrc_dsc && !trn_rsrc_dsc_d && trn_in_packet &&
                         (!trn_rsof || trn_reof) && !(trn_rdst_rdy && trn_reof);

always_ff @(posedge user_clk) begin
  if(user_rst) begin
    reg_dsc_detect <= 1'b0;
    trn_rsrc_dsc_d <= 1'b0;
  end
  else begin
    if(dsc_detect) begin
      reg_dsc_detect <= 1'b1;
    end
    else if(null_mux_sel) begin
      reg_dsc_detect <= 1'b0;
    end

    trn_rsrc_dsc_d <= trn_rsrc_dsc;
  end
end

assign dsc_flag = dsc_detect || reg_dsc_detect;



assign np_counter = 3'h0;


endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
