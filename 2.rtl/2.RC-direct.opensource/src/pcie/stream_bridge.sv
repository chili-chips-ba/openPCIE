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

module stream_bridge #(
  localparam int C_DATA_WIDTH = 64,
  localparam int KEEP_WIDTH   = 8,
  localparam int REM_WIDTH    = 1
) (
  stream_if.slave        s_axis_tx,
  stream_if.master       m_axis_rx,

  input                     user_turnoff_ok,
  input                     user_tcfg_gnt,

  output [C_DATA_WIDTH-1:0] trn_td,
  output                    trn_tsof,
  output                    trn_teof,
  output                    trn_tsrc_rdy,
  input                     trn_tdst_rdy,
  output                    trn_tsrc_dsc,
  output    [REM_WIDTH-1:0] trn_trem,
  output                    trn_terrfwd,
  output                    trn_tstr,
  input               [5:0] trn_tbuf_av,
  output                    trn_tecrc_gen,

  input  [C_DATA_WIDTH-1:0] trn_rd,
  input                     trn_rsof,
  input                     trn_reof,
  input                     trn_rsrc_rdy,
  output                    trn_rdst_rdy,
  input                     trn_rsrc_dsc,
  input     [REM_WIDTH-1:0] trn_rrem,
  input                     trn_rerrfwd,
  input               [6:0] trn_rbar_hit,
  input                     trn_recrc_err,

  input                     trn_tcfg_req,
  output                    trn_tcfg_gnt,
  input                     trn_lnk_up,

  input               [2:0] cfg_pcie_link_state,
  input                     cfg_pm_send_pme_to,
  input               [1:0] cfg_pmcsr_powerstate,
  input              [31:0] trn_rdllp_data,
  input                     trn_rdllp_src_rdy,
  input                     cfg_to_turnoff,
  output                    cfg_turnoff_ok,

  output              [2:0] np_counter,
  input                     user_clk,
  input                     user_rst
);

  wire tready_thrtl;

  wire                  null_rx_tvalid;
  wire                  null_rx_tlast;
  wire [KEEP_WIDTH-1:0] null_rx_tkeep;
  wire                  null_rdst_rdy;
  logic           [4:0] null_is_eof;

  stream_rx_path rx_path_i (
    .m_axis_rx_tdata  (m_axis_rx.tdata),
    .m_axis_rx_tvalid (m_axis_rx.tvalid),
    .m_axis_rx_tready (m_axis_rx.tready),
    .m_axis_rx_tkeep  (m_axis_rx.tkeep),
    .m_axis_rx_tlast  (m_axis_rx.tlast),
    .m_axis_rx_tuser  (m_axis_rx.tuser),

    .trn_rd           (trn_rd),
    .trn_rsof         (trn_rsof),
    .trn_reof         (trn_reof),
    .trn_rsrc_rdy     (trn_rsrc_rdy),
    .trn_rdst_rdy     (trn_rdst_rdy),
    .trn_rsrc_dsc     (trn_rsrc_dsc),
    .trn_rrem         (trn_rrem),
    .trn_rerrfwd      (trn_rerrfwd),
    .trn_rbar_hit     (trn_rbar_hit),
    .trn_recrc_err    (trn_recrc_err),

    .null_rx_tvalid   (null_rx_tvalid),
    .null_rx_tlast    (null_rx_tlast),
    .null_rx_tkeep    (null_rx_tkeep),
    .null_rdst_rdy    (null_rdst_rdy),
    .null_is_eof      (null_is_eof),

    .np_counter       (np_counter),
    .user_clk         (user_clk),
    .user_rst         (user_rst)
  );

  // --- generator null podataka (nekada zaseban modul) -----------------------
  localparam logic [10:0] NG_INTERFACE_WIDTH_DWORDS = 11'd2;
  localparam logic NG_IDLE      = 1'b0;
  localparam logic NG_IN_PACKET = 1'b1;

  logic        ng_cur_state;
  logic        ng_next_state;
  logic [11:0] ng_reg_pkt_len_counter;
  logic [11:0] ng_pkt_len_counter;
  logic [11:0] ng_pkt_len_counter_dec;
  logic        ng_pkt_done;
  logic [11:0] ng_new_pkt_len;
  logic  [9:0] ng_payload_len;
  logic  [1:0] ng_packet_fmt;
  logic        ng_packet_td;
  logic  [1:0] ng_packet_overhead;
  logic [7:0]  ng_eof_tkeep;
  logic        ng_eof;

  assign ng_eof         = m_axis_rx.tuser[21];
  assign ng_packet_fmt  = m_axis_rx.tdata[30:29];
  assign ng_packet_td   = m_axis_rx.tdata[15];
  assign ng_payload_len = ng_packet_fmt[1] ? m_axis_rx.tdata[9:0] : 10'h0;

  always_comb begin
    case ({ng_packet_fmt[0], ng_packet_td})
      2'b00:   ng_packet_overhead = 2'b01;
      2'b01:   ng_packet_overhead = 2'b10;
      2'b10:   ng_packet_overhead = 2'b10;
      2'b11:   ng_packet_overhead = 2'b11;
      default: ng_packet_overhead = 2'b01;
    endcase
  end

  assign ng_new_pkt_len = {10'b0, ng_packet_overhead} + {2'b0, ng_payload_len};

  assign ng_pkt_len_counter_dec = ng_reg_pkt_len_counter - NG_INTERFACE_WIDTH_DWORDS;
  assign ng_pkt_done            = (ng_reg_pkt_len_counter <= NG_INTERFACE_WIDTH_DWORDS);

  always_comb begin
    case (ng_cur_state)
      NG_IDLE: begin
        if (m_axis_rx.tvalid && m_axis_rx.tready && !ng_eof)
          ng_next_state = NG_IN_PACKET;
        else
          ng_next_state = NG_IDLE;
        ng_pkt_len_counter = ng_new_pkt_len;
      end

      NG_IN_PACKET: begin
        if (m_axis_rx.tready && ng_pkt_done) begin
          ng_pkt_len_counter = ng_new_pkt_len;
          ng_next_state      = NG_IDLE;
        end else begin
          ng_pkt_len_counter = m_axis_rx.tready ? ng_pkt_len_counter_dec : ng_reg_pkt_len_counter;
          ng_next_state      = NG_IN_PACKET;
        end
      end

      default: begin
        ng_pkt_len_counter = ng_reg_pkt_len_counter;
        ng_next_state      = NG_IDLE;
      end
    endcase
  end

  always_ff @(posedge user_clk) begin
    if (user_rst) begin
      ng_cur_state           <= NG_IDLE;
      ng_reg_pkt_len_counter <= 12'h0;
    end else begin
      ng_cur_state           <= ng_next_state;
      ng_reg_pkt_len_counter <= ng_pkt_len_counter;
    end
  end

  always_comb begin
    case (ng_pkt_len_counter)
      12'd1:   null_is_eof = 5'b10011;
      12'd2:   null_is_eof = 5'b10111;
      default: null_is_eof = 5'b00011;
    endcase
  end

  assign ng_eof_tkeep = { ((ng_pkt_len_counter == 12'd2) ? 4'hF : 4'h0), 4'hF };

  assign null_rx_tvalid = 1'b1;
  assign null_rx_tlast  = (ng_pkt_len_counter <= NG_INTERFACE_WIDTH_DWORDS);
  assign null_rx_tkeep  = null_rx_tlast ? ng_eof_tkeep : 8'hFF;
  assign null_rdst_rdy  = null_rx_tlast;
  // ---------------------------------------------------------------------------

  stream_tx_path tx_path_i (
    .s_axis_tx_tdata  (s_axis_tx.tdata),
    .s_axis_tx_tready (s_axis_tx.tready),
    .s_axis_tx_tvalid (s_axis_tx.tvalid),
    .s_axis_tx_tkeep  (s_axis_tx.tkeep),
    .s_axis_tx_tlast  (s_axis_tx.tlast),
    .s_axis_tx_tuser  (s_axis_tx.tuser),

    .trn_td           (trn_td),
    .trn_tsof         (trn_tsof),
    .trn_teof         (trn_teof),
    .trn_tsrc_rdy     (trn_tsrc_rdy),
    .trn_tdst_rdy     (trn_tdst_rdy),
    .trn_tsrc_dsc     (trn_tsrc_dsc),
    .trn_trem         (trn_trem),
    .trn_terrfwd      (trn_terrfwd),
    .trn_tstr         (trn_tstr),
    .trn_tecrc_gen    (trn_tecrc_gen),
    .trn_lnk_up       (trn_lnk_up),

    .tready_thrtl     (tready_thrtl),
    .user_clk         (user_clk),
    .user_rst         (user_rst)
  );

  stream_tx_gate tx_gate_i (
    .s_axis_tx_tdata      (s_axis_tx.tdata),
    .s_axis_tx_tvalid     (s_axis_tx.tvalid),
    .s_axis_tx_tuser      (s_axis_tx.tuser),
    .s_axis_tx_tlast      (s_axis_tx.tlast),

    .user_turnoff_ok      (user_turnoff_ok),
    .user_tcfg_gnt        (user_tcfg_gnt),

    .trn_tbuf_av          (trn_tbuf_av),
    .trn_tdst_rdy         (trn_tdst_rdy),

    .trn_tcfg_req         (trn_tcfg_req),
    .trn_tcfg_gnt         (trn_tcfg_gnt),
    .trn_lnk_up           (trn_lnk_up),

    .cfg_pcie_link_state  (cfg_pcie_link_state),

    .cfg_pm_send_pme_to   (cfg_pm_send_pme_to),
    .cfg_pmcsr_powerstate (cfg_pmcsr_powerstate),
    .trn_rdllp_data       (trn_rdllp_data),
    .trn_rdllp_src_rdy    (trn_rdllp_src_rdy),

    .cfg_to_turnoff       (cfg_to_turnoff),
    .cfg_turnoff_ok       (cfg_turnoff_ok),

    .tready_thrtl         (tready_thrtl),
    .user_clk             (user_clk),
    .user_rst             (user_rst)
  );

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
