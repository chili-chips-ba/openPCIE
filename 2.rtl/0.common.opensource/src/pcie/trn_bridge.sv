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

module trn_bridge #(
  localparam int C_DATA_WIDTH = 64,
  localparam int KEEP_WIDTH   = 8,
  localparam int REM_WIDTH    = 1
) (
  axis_if.slave        s_axis_tx,
  axis_if.master       m_axis_rx,

  trn_if.user               trn,          // TRN bus to PCIE_2_1 in pcie_core (see trn_if.sv)

  input               [2:0] cfg_pcie_link_state,
  input               [1:0] cfg_pmcsr_powerstate,
  input                     cfg_to_turnoff,
  output                    cfg_turnoff_ok,

  input                     user_clk,
  input                     user_rst
);

  wire tready_thrtl;

  wire                  null_rx_tvalid;
  wire                  null_rx_tlast;
  wire [KEEP_WIDTH-1:0] null_rx_tkeep;
  wire                  null_rdst_rdy;
  logic           [4:0] null_is_eof;

  trn_rx u_trn_rx (
    .m_axis_rx        (m_axis_rx),

    .trn_rd           (trn.rd),
    .trn_rsof         (trn.rsof),
    .trn_reof         (trn.reof),
    .trn_rsrc_rdy     (trn.rsrc_rdy),
    .trn_rdst_rdy     (trn.rdst_rdy),
    .trn_rsrc_dsc     (trn.rsrc_dsc),
    .trn_rrem         (trn.rrem),
    .trn_rerrfwd      (trn.rerrfwd),
    .trn_rbar_hit     (trn.rbar_hit),
    .trn_recrc_err    (trn.recrc_err),

    .null_rx_tvalid   (null_rx_tvalid),
    .null_rx_tlast    (null_rx_tlast),
    .null_rx_tkeep    (null_rx_tkeep),
    .null_rdst_rdy    (null_rdst_rdy),
    .null_is_eof      (null_is_eof),

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

  trn_tx u_trn_tx (
    .s_axis_tx        (s_axis_tx),

    .trn_td           (trn.td),
    .trn_tsof         (trn.tsof),
    .trn_teof         (trn.teof),
    .trn_tsrc_rdy     (trn.tsrc_rdy),
    .trn_tdst_rdy     (trn.tdst_rdy),
    .trn_tsrc_dsc     (trn.tsrc_dsc),
    .trn_trem         (trn.trem),
    .trn_terrfwd      (trn.terrfwd),
    .trn_tstr         (trn.tstr),
    .trn_tecrc_gen    (trn.tecrc_gen),
    .trn_lnk_up       (trn.lnk_up),

    .tready_thrtl     (tready_thrtl),
    .user_clk         (user_clk),
    .user_rst         (user_rst)
  );

  trn_tx_throttle u_trn_tx_throttle (
    .s_axis_tx_tdata      (s_axis_tx.tdata),
    .s_axis_tx_tvalid     (s_axis_tx.tvalid),
    .s_axis_tx_tuser      (s_axis_tx.tuser),
    .s_axis_tx_tlast      (s_axis_tx.tlast),

    .trn_tbuf_av          (trn.tbuf_av),
    .trn_tdst_rdy         (trn.tdst_rdy),

    .trn_tcfg_req         (trn.tcfg_req),
    .trn_tcfg_gnt         (trn.tcfg_gnt),
    .trn_lnk_up           (trn.lnk_up),

    .cfg_pcie_link_state  (cfg_pcie_link_state),

    .cfg_pmcsr_powerstate (cfg_pmcsr_powerstate),
    .trn_rx_dllp_data     (trn.rx_dllp_data),
    .trn_rx_dllp_src_rdy  (trn.rx_dllp_src_rdy),

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
