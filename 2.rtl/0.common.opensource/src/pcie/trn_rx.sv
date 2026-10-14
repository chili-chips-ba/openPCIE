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

module trn_rx
  import pcie_pkg::*;
(
    axis_if.master m_axis_rx,
    trn_if.user    trn,        // RX half: rd ... recrc_err, rdst_rdy

    input logic clk62m5,
    input logic core_rst_n
);


  logic [TRN_KEEP_W-1:0] reg_tkeep;
  logic [TRN_KEEP_W-1:0] tkeep;
  logic [TRN_KEEP_W-1:0] tkeep_prev;

  logic                  reg_tlast;
  logic                  rsrc_rdy_filtered;

  logic [TRN_DATA_W-1:0] trn_rd_dw_swapped;
  logic [TRN_DATA_W-1:0] trn_rd_prev;

  logic                  data_hold;
  logic                  data_prev;

  logic                  trn_reof_prev;
  logic [ TRN_REM_W-1:0] trn_rrem_prev;
  logic                  trn_rsrc_rdy_prev;
  logic [           6:0] trn_rbar_hit_prev;
  logic                  trn_rerrfwd_prev;
  logic                  trn_recrc_err_prev;

  logic                  null_mux_sel;
  logic                  null_rx_tlast;
  logic [TRN_KEEP_W-1:0] null_rx_tkeep;
  logic                  trn_in_packet;
  logic                  dsc_flag;
  logic                  dsc_detect;
  logic                  reg_dsc_detect;
  logic                  trn_rsrc_dsc_d;

  assign rsrc_rdy_filtered = trn.rsrc_rdy && (trn_in_packet || (trn.rsof && !trn.rsrc_dsc));

  always_ff @(posedge clk62m5 or negedge core_rst_n) begin
    if (!core_rst_n) begin
      trn_rd_prev        <= {TRN_DATA_W{1'b0}};
      trn_rrem_prev      <= {TRN_REM_W{1'b0}};
      trn_rsrc_rdy_prev  <= 1'b0;
      trn_rbar_hit_prev  <= 7'h00;
      trn_rerrfwd_prev   <= 1'b0;
      trn_recrc_err_prev <= 1'b0;
      trn_reof_prev      <= 1'b0;
    end
    else begin
      if (trn.rdst_rdy) begin
        trn_rd_prev        <= trn_rd_dw_swapped;
        trn_rrem_prev      <= trn.rrem;
        trn_rbar_hit_prev  <= trn.rbar_hit;
        trn_rerrfwd_prev   <= trn.rerrfwd;
        trn_recrc_err_prev <= trn.recrc_err;
        trn_rsrc_rdy_prev  <= rsrc_rdy_filtered;
        trn_reof_prev      <= trn.reof;
      end
    end
  end

  assign trn_rd_dw_swapped = {trn.rd[31:0], trn.rd[63:32]};

  always_ff @(posedge clk62m5 or negedge core_rst_n) begin
    if (!core_rst_n) begin
      m_axis_rx.tdata <= {TRN_DATA_W{1'b0}};
    end
    else begin
      if (!data_hold) begin
        if (data_prev) begin
          m_axis_rx.tdata <= trn_rd_prev;
        end
        else begin
          m_axis_rx.tdata <= trn_rd_dw_swapped;
        end
      end
    end
  end

  assign data_hold = (!m_axis_rx.tready && m_axis_rx.tvalid);

  always_ff @(posedge clk62m5 or negedge core_rst_n) begin
    if (!core_rst_n) begin
      data_prev <= 1'b0;
    end
    else begin
      data_prev <= data_hold;
    end
  end

  always_ff @(posedge clk62m5 or negedge core_rst_n) begin
    if (!core_rst_n) begin
      m_axis_rx.tvalid <= 1'b0;
      reg_tlast        <= 1'b0;
      reg_tkeep        <= {TRN_KEEP_W{1'b1}};
      m_axis_rx.tuser  <= '0;
    end
    else begin
      if (!data_hold) begin
        if (null_mux_sel) begin
          m_axis_rx.tvalid <= 1'b1;  // a null-generator beat is always valid
          reg_tlast        <= null_rx_tlast;
          reg_tkeep        <= null_rx_tkeep;
          m_axis_rx.tuser  <= '0;
        end
        else if (data_prev) begin
          m_axis_rx.tvalid <= (trn_rsrc_rdy_prev || dsc_flag);
          reg_tlast <= trn_reof_prev;
          reg_tkeep <= tkeep_prev;
          m_axis_rx.tuser <= pcie_rx_tuser_t'{
              bar_hit: {1'b0, trn_rbar_hit_prev},
              err_fwd: trn_rerrfwd_prev,
              ecrc_err: trn_recrc_err_prev
          };
        end
        else begin
          m_axis_rx.tvalid <= (rsrc_rdy_filtered || dsc_flag);
          reg_tlast <= trn.reof;
          reg_tkeep <= tkeep;
          m_axis_rx.tuser <= pcie_rx_tuser_t'{
              bar_hit: {1'b0, trn.rbar_hit},
              err_fwd: trn.rerrfwd,
              ecrc_err: trn.recrc_err
          };
        end
      end
    end
  end

  assign m_axis_rx.tlast = reg_tlast;
  assign m_axis_rx.tkeep = reg_tkeep;

  assign tkeep           = trn.rrem ? 8'hFF : 8'h0F;
  assign tkeep_prev      = trn_rrem_prev ? 8'hFF : 8'h0F;

  always_ff @(posedge clk62m5 or negedge core_rst_n) begin
    if (!core_rst_n) begin
      trn.rdst_rdy <= 1'b0;
    end
    else begin
      if (null_mux_sel && m_axis_rx.tready) begin
        trn.rdst_rdy <= null_rx_tlast;
      end
      else if (dsc_flag) begin
        trn.rdst_rdy <= 1'b0;
      end
      else if (m_axis_rx.tvalid) begin
        trn.rdst_rdy <= m_axis_rx.tready;
      end
      else begin
        trn.rdst_rdy <= 1'b1;
      end
    end
  end

  always_ff @(posedge clk62m5 or negedge core_rst_n) begin
    if (!core_rst_n) begin
      null_mux_sel <= 1'b0;
    end
    else begin
      if (null_mux_sel && null_rx_tlast && m_axis_rx.tready) begin
        null_mux_sel <= 1'b0;
      end
      else if (dsc_flag && !data_hold) begin
        null_mux_sel <= 1'b1;
      end
    end
  end

  always_ff @(posedge clk62m5 or negedge core_rst_n) begin
    if (!core_rst_n) begin
      trn_in_packet <= 1'b0;
    end
    else begin
      if (trn.rsof && !trn.reof && rsrc_rdy_filtered && trn.rdst_rdy) begin
        trn_in_packet <= 1'b1;
      end
      else if (trn.rsrc_dsc) begin
        trn_in_packet <= 1'b0;
      end
      else if (trn.reof && !trn.rsof && trn.rsrc_rdy && trn.rdst_rdy) begin
        trn_in_packet <= 1'b0;
      end
    end
  end

  assign dsc_detect = trn.rsrc_dsc && !trn_rsrc_dsc_d && trn_in_packet &&
                         (!trn.rsof || trn.reof) && !(trn.rdst_rdy && trn.reof);

  always_ff @(posedge clk62m5 or negedge core_rst_n) begin
    if (!core_rst_n) begin
      reg_dsc_detect <= 1'b0;
      trn_rsrc_dsc_d <= 1'b0;
    end
    else begin
      if (dsc_detect) begin
        reg_dsc_detect <= 1'b1;
      end
      else if (null_mux_sel) begin
        reg_dsc_detect <= 1'b0;
      end

      trn_rsrc_dsc_d <= trn.rsrc_dsc;
    end
  end

  assign dsc_flag = dsc_detect || reg_dsc_detect;

  // ---- null generator: finishes an RX packet the core discontinued, with -----
  // ---- filler beats up to the length in its header                       -----
  localparam logic [11:0] NG_INTERFACE_WIDTH_DWORDS = 12'd2;  // DWs per beat

  typedef enum logic {
    NG_IDLE,
    NG_IN_PACKET
  } ng_state_e;

  typedef struct packed {
    ng_state_e   state;
    logic [11:0] pkt_len;  // DWs of the packet still to come
  } ng_t;

  ng_t ng_q, ng_d;
  logic          [11:0] ng_pkt_len_dec;
  logic                 ng_pkt_done;
  logic          [11:0] ng_new_pkt_len;
  logic          [ 9:0] ng_payload_len;
  pcie_tlp_dw0_t        ng_dw0;  // header DW0 of the packet starting now
  logic          [ 1:0] ng_packet_overhead;
  logic          [ 7:0] ng_eof_tkeep;

  assign ng_dw0         = m_axis_rx.tdata[31:0];
  assign ng_payload_len = ng_dw0.fmt[1] ? ng_dw0.length : 10'h0;

  always_comb begin
    unique case ({
      ng_dw0.fmt[0], ng_dw0.td
    })
      2'b00: ng_packet_overhead = 2'b01;
      2'b01: ng_packet_overhead = 2'b10;
      2'b10: ng_packet_overhead = 2'b10;
      2'b11: ng_packet_overhead = 2'b11;
    endcase
  end

  assign ng_new_pkt_len = {10'b0, ng_packet_overhead} + {2'b0, ng_payload_len};

  assign ng_pkt_len_dec = ng_q.pkt_len - NG_INTERFACE_WIDTH_DWORDS;
  assign ng_pkt_done    = (ng_q.pkt_len <= NG_INTERFACE_WIDTH_DWORDS);

  always_comb begin
    unique case (ng_q.state)
      NG_IDLE: begin
        if (m_axis_rx.tvalid && m_axis_rx.tready && !m_axis_rx.tlast) begin
          ng_d.state = NG_IN_PACKET;
        end
        else begin
          ng_d.state = NG_IDLE;
        end
        ng_d.pkt_len = ng_new_pkt_len;
      end

      NG_IN_PACKET: begin
        if (m_axis_rx.tready && ng_pkt_done) begin
          ng_d.pkt_len = ng_new_pkt_len;
          ng_d.state   = NG_IDLE;
        end
        else begin
          ng_d.pkt_len = m_axis_rx.tready ? ng_pkt_len_dec : ng_q.pkt_len;
          ng_d.state   = NG_IN_PACKET;
        end
      end
    endcase
  end

  always_ff @(posedge clk62m5 or negedge core_rst_n) begin
    if (!core_rst_n) begin
      ng_q <= '{state: NG_IDLE, pkt_len: 12'h0};
    end
    else begin
      ng_q <= ng_d;
    end
  end

  assign ng_eof_tkeep  = {((ng_d.pkt_len == 12'd2) ? 4'hF : 4'h0), 4'hF};
  assign null_rx_tlast = (ng_d.pkt_len <= NG_INTERFACE_WIDTH_DWORDS);
  assign null_rx_tkeep = null_rx_tlast ? ng_eof_tkeep : 8'hFF;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
