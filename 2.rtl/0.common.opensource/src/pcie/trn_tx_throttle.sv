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

module trn_tx_throttle
  import pcie_pkg::*;
(
    axis_if.slave s_axis_tx,  // reads the header and the handshake
    trn_if.user   trn,        // tbuf_av, tdst_rdy, link_up

    input logic [2:0] cfg_pcie_link_state,


    output logic tready_thrtl,
    input  logic user_clk,
    input  logic core_rst_n
);

  pcie_tlp_dw0_t  tx_dw0;  // header DW0 of the TX beat
  pcie_tx_tuser_t tx_tuser;
  assign tx_dw0   = s_axis_tx.tdata[31:0];
  assign tx_tuser = s_axis_tx.tuser;

  localparam logic [5:0] TBUF_AV_MIN   = (TRN_DATA_W == 128) ? 5 : (TRN_DATA_W == 64) ? 1 : 0;

  localparam logic [5:0] TBUF_AV_GAP   = TBUF_AV_MIN + 1;

  localparam logic [2:0] TBUF_GAP_TIME = (TRN_DATA_W == 128) ? 4 : 1;

  logic       lnk_up_thrtl;
  logic       lnk_up_trig;
  logic       lnk_up_exit;

  logic       tbuf_av_min_thrtl;
  logic       tbuf_av_min_trig;

  logic       tbuf_av_gap_thrtl;
  logic [2:0] tbuf_gap_cnt;
  logic       tbuf_av_gap_trig;
  logic       tbuf_av_gap_exit;
  logic       gap_trig_tlast;
  logic       gap_trig_decr;
  logic [5:0] tbuf_av_d;


  logic       pre_throttle;
  logic       reg_throttle;
  logic       exit_crit;

  logic       tready_thrtl_mux;

  localparam logic [2:0] LINKSTATE_L0           = 3'b000;
  localparam logic [2:0] LINKSTATE_PPM_L1_TRANS = 3'b101;

  logic       ppm_l1_thrtl;
  logic       ppm_l1_trig;
  logic       ppm_l1_exit;
  logic [2:0] cfg_pcie_link_state_d;


  localparam logic IDLE     = 1'b0;
  localparam logic THROTTLE = 1'b1;
  logic cur_state;
  logic next_state;

  logic reg_axi_in_pkt;
  logic axi_in_pkt;
  logic axi_pkt_ending;
  logic axi_throttled;
  logic axi_thrtl_ok;
  logic tx_ecrc_pause;

  assign lnk_up_trig = !trn.link_up;
  assign lnk_up_exit = trn.tdst_rdy;

  always_ff @(posedge user_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      lnk_up_thrtl <= 1'b1;
    end
    else begin
      if (lnk_up_trig) begin
        lnk_up_thrtl <= 1'b1;
      end
      else if (lnk_up_exit) begin
        lnk_up_thrtl <= 1'b0;
      end
    end
  end

  assign tbuf_av_min_trig = (trn.tbuf_av <= TBUF_AV_MIN);

  always_ff @(posedge user_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      tbuf_av_min_thrtl <= 1'b0;
    end
    else begin
      if (tbuf_av_min_trig) begin
        tbuf_av_min_thrtl <= 1'b1;
      end
      else begin
        tbuf_av_min_thrtl <= 1'b0;
      end
    end
  end

  assign gap_trig_tlast = (trn.tbuf_av <= TBUF_AV_GAP) &&
                            s_axis_tx.tvalid && tready_thrtl && s_axis_tx.tlast;

  assign gap_trig_decr = (trn.tbuf_av == (TBUF_AV_GAP)) && (tbuf_av_d == (TBUF_AV_GAP + 1));

  assign tbuf_av_gap_trig = gap_trig_tlast || gap_trig_decr;
  assign tbuf_av_gap_exit = (tbuf_gap_cnt == 0);

  always_ff @(posedge user_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      tbuf_av_gap_thrtl <= 1'b0;
      tbuf_gap_cnt      <= 3'h0;
      tbuf_av_d         <= 6'h00;
    end
    else begin
      if (tbuf_av_gap_trig) begin
        tbuf_av_gap_thrtl <= 1'b1;
      end
      else if (tbuf_av_gap_exit) begin
        tbuf_av_gap_thrtl <= 1'b0;
      end

      if (tbuf_av_gap_thrtl && (cur_state == THROTTLE)) begin
        if (tbuf_gap_cnt > 0) begin
          tbuf_gap_cnt <= tbuf_gap_cnt - 3'd1;
        end
      end
      else begin
        tbuf_gap_cnt <= TBUF_GAP_TIME;
      end

      tbuf_av_d <= trn.tbuf_av;
    end
  end

  assign ppm_l1_trig = (cfg_pcie_link_state_d == LINKSTATE_L0) &&
                       (cfg_pcie_link_state == LINKSTATE_PPM_L1_TRANS);
  assign ppm_l1_exit = cfg_pcie_link_state == LINKSTATE_L0;

  always_ff @(posedge user_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      ppm_l1_thrtl          <= 1'b0;
      cfg_pcie_link_state_d <= 3'b0;
    end
    else begin
      if (ppm_l1_trig) begin
        ppm_l1_thrtl <= 1'b1;
      end
      else if (ppm_l1_exit) begin
        ppm_l1_thrtl <= 1'b0;
      end
      cfg_pcie_link_state_d <= cfg_pcie_link_state;
    end
  end

  always_ff @(posedge user_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      reg_axi_in_pkt <= 1'b0;
    end
    else begin
      if (s_axis_tx.tvalid && s_axis_tx.tlast) begin
        reg_axi_in_pkt <= 1'b0;
      end
      else if (tready_thrtl && s_axis_tx.tvalid) begin
        reg_axi_in_pkt <= 1'b1;
      end
    end
  end

  assign axi_in_pkt = s_axis_tx.tvalid || reg_axi_in_pkt;
  assign axi_pkt_ending = s_axis_tx.tvalid && s_axis_tx.tlast;
  assign axi_throttled = !tready_thrtl;
  assign axi_thrtl_ok = !axi_in_pkt || axi_pkt_ending || axi_throttled;

  assign pre_throttle = tbuf_av_min_trig || tbuf_av_gap_trig || lnk_up_trig || ppm_l1_trig;

  assign reg_throttle = tbuf_av_min_thrtl || tbuf_av_gap_thrtl || lnk_up_thrtl || ppm_l1_thrtl;

  assign exit_crit = !tbuf_av_min_thrtl && !tbuf_av_gap_thrtl && !lnk_up_thrtl && !ppm_l1_thrtl;

  always_comb begin
    unique case (cur_state)
      IDLE: begin
        if (reg_throttle && axi_thrtl_ok) begin
          tready_thrtl_mux = 1'b0;
          next_state       = THROTTLE;
        end
        else begin
          tready_thrtl_mux = !(axi_thrtl_ok && pre_throttle);
          next_state       = IDLE;
        end
      end

      THROTTLE: begin
        if (exit_crit) begin
          tready_thrtl_mux = !pre_throttle;
          next_state       = IDLE;
        end
        else begin
          tready_thrtl_mux = 1'b0;
          next_state       = THROTTLE;
        end

      end
    endcase
  end

  always_ff @(posedge user_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      cur_state    <= THROTTLE;

      tready_thrtl <= 1'b0;
    end
    else begin
      cur_state    <= next_state;

      tready_thrtl <= tready_thrtl_mux && !tx_ecrc_pause;
    end
  end

  logic tx_ecrc_pkt;
  logic reg_tx_ecrc_pkt;
  logic packet_len_odd;
  logic pause_needed;

  // packet length in DW = header (3 or 4) + payload (if any); only its parity
  // matters: an even-length TLP without digest needs the ECRC pause
  assign packet_len_odd = !tx_dw0.fmt[0] ^ (tx_dw0.fmt[1] & tx_dw0.length[0]);
  assign pause_needed = !packet_len_odd && !tx_dw0.td;

  assign tx_ecrc_pkt = tx_tuser.ecrc_gen && pause_needed &&
                        tready_thrtl && s_axis_tx.tvalid && !reg_axi_in_pkt;

  always_ff @(posedge user_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      reg_tx_ecrc_pkt <= 1'b0;
    end
    else begin
      if (tx_ecrc_pkt && !s_axis_tx.tlast) begin
        reg_tx_ecrc_pkt <= 1'b1;
      end
      else if (tready_thrtl && s_axis_tx.tvalid && s_axis_tx.tlast) begin
        reg_tx_ecrc_pkt <= 1'b0;
      end
    end
  end

  assign tx_ecrc_pause = ((tx_ecrc_pkt || reg_tx_ecrc_pkt) &&
                       s_axis_tx.tlast && s_axis_tx.tvalid && tready_thrtl);


endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
