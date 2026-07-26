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
module stream_tx_gate #(
  localparam int C_DATA_WIDTH = 64
  ) (

  input  [C_DATA_WIDTH-1:0] s_axis_tx_tdata,
  input                     s_axis_tx_tvalid,
  input               [3:0] s_axis_tx_tuser,
  input                     s_axis_tx_tlast,

  input                     user_turnoff_ok,
  input                     user_tcfg_gnt,

  input               [5:0] trn_tbuf_av,
  input                     trn_tdst_rdy,

  input                     trn_tcfg_req,
  output                    trn_tcfg_gnt,
  input                     trn_lnk_up,

  input               [2:0] cfg_pcie_link_state,

  input                     cfg_pm_send_pme_to,
  input               [1:0] cfg_pmcsr_powerstate,
  input              [31:0] trn_rdllp_data,
  input                     trn_rdllp_src_rdy,

  input                     cfg_to_turnoff,
  output logic                cfg_turnoff_ok,

  output logic                tready_thrtl,
  input                     user_clk,
  input                     user_rst
);

localparam TBUF_AV_MIN = (C_DATA_WIDTH == 128) ? 5 :
                                                   (C_DATA_WIDTH == 64) ? 1 : 0;

localparam TBUF_AV_GAP = TBUF_AV_MIN + 1;

localparam TBUF_GAP_TIME = (C_DATA_WIDTH == 128) ? 4 : 1;

localparam TCFG_LATENCY_TIME = 2'd2;

localparam TCFG_GNT_PIPE_STAGES = 3;

logic        lnk_up_thrtl;
wire       lnk_up_trig;
wire       lnk_up_exit;

logic        tbuf_av_min_thrtl;
wire       tbuf_av_min_trig;

logic        tbuf_av_gap_thrtl;
logic  [2:0] tbuf_gap_cnt;
wire       tbuf_av_gap_trig;
wire       tbuf_av_gap_exit;
wire       gap_trig_tlast;
wire       gap_trig_decr;
wire       gap_trig_tcfg;
logic  [5:0] tbuf_av_d;

logic        tcfg_req_thrtl;
logic  [1:0] tcfg_req_cnt;
logic        trn_tdst_rdy_d;
wire       tcfg_req_trig;
wire       tcfg_req_exit;
logic        tcfg_gnt_log;

wire       pre_throttle;
wire       reg_throttle;
wire       exit_crit;
logic        reg_tcfg_gnt;
logic        trn_tcfg_req_d;
logic        tcfg_gnt_pending;
wire       wire_to_turnoff;
logic        reg_turnoff_ok;

logic        tready_thrtl_mux;

localparam LINKSTATE_L0             = 3'b000;
localparam LINKSTATE_PPM_L1         = 3'b001;
localparam LINKSTATE_PPM_L1_TRANS   = 3'b101;
localparam LINKSTATE_PPM_L23R_TRANS = 3'b110;
localparam PM_ENTER_L1              = 8'h20;
localparam POWERSTATE_D0            = 2'b00;

logic        ppm_L1_thrtl;
wire       ppm_L1_trig;
wire       ppm_L1_exit;
logic  [2:0] cfg_pcie_link_state_d;
logic        trn_rdllp_src_rdy_d;

logic        ppm_L23_thrtl;
wire       ppm_L23_trig;
logic        cfg_turnoff_ok_pending;

logic        reg_tlast;

localparam IDLE       = 0;
localparam THROTTLE   = 1;
logic        cur_state;
logic        next_state;

logic        reg_axi_in_pkt;
wire       axi_in_pkt;
wire       axi_pkt_ending;
wire       axi_throttled;
wire       axi_thrtl_ok;
wire       tx_ecrc_pause;

assign lnk_up_trig = !trn_lnk_up;
assign lnk_up_exit = trn_tdst_rdy;

always_ff @(posedge user_clk) begin
  if(user_rst) begin
    lnk_up_thrtl <= 1'b1;
  end
  else begin
    if(lnk_up_trig) begin
      lnk_up_thrtl <= 1'b1;
    end
    else if(lnk_up_exit) begin
      lnk_up_thrtl <= 1'b0;
    end
  end
end


assign tbuf_av_min_trig = (trn_tbuf_av <= TBUF_AV_MIN);

always_ff @(posedge user_clk) begin
  if(user_rst) begin
    tbuf_av_min_thrtl <= 1'b0;
  end
  else begin
    if(tbuf_av_min_trig) begin
      tbuf_av_min_thrtl <= 1'b1;
    end

    else begin
      tbuf_av_min_thrtl <= 1'b0;
    end
  end
end



assign gap_trig_tlast = (trn_tbuf_av <= TBUF_AV_GAP) &&
                            s_axis_tx_tvalid && tready_thrtl && s_axis_tx_tlast;

assign gap_trig_decr  = (trn_tbuf_av == (TBUF_AV_GAP)) &&
                                                 (tbuf_av_d == (TBUF_AV_GAP+1));

assign gap_trig_tcfg  = (tcfg_req_thrtl && tcfg_req_exit);
assign tbuf_av_gap_trig = gap_trig_tlast || gap_trig_decr || gap_trig_tcfg;
assign tbuf_av_gap_exit = (tbuf_gap_cnt == 0);

always_ff @(posedge user_clk) begin
  if(user_rst) begin
    tbuf_av_gap_thrtl <= 1'b0;
    tbuf_gap_cnt      <= 3'h0;
    tbuf_av_d         <= 6'h00;
  end
  else begin
    if(tbuf_av_gap_trig) begin
      tbuf_av_gap_thrtl <= 1'b1;
    end
    else if(tbuf_av_gap_exit) begin
      tbuf_av_gap_thrtl <= 1'b0;
    end

    if(tbuf_av_gap_thrtl && (cur_state == THROTTLE)) begin
      if(tbuf_gap_cnt > 0) begin
        tbuf_gap_cnt <= tbuf_gap_cnt - 3'd1;
      end
    end
    else begin
      tbuf_gap_cnt <= TBUF_GAP_TIME;
    end

    tbuf_av_d <= trn_tbuf_av;
  end
end


assign tcfg_req_trig = trn_tcfg_req && reg_tcfg_gnt;
assign tcfg_req_exit = (tcfg_req_cnt == 2'd0) && !trn_tdst_rdy_d &&
                                                                   trn_tdst_rdy;
always_ff @(posedge user_clk) begin
  if(user_rst) begin
    tcfg_req_thrtl   <= 1'b0;
    trn_tcfg_req_d   <= 1'b0;
    trn_tdst_rdy_d   <= 1'b1;
    reg_tcfg_gnt     <= 1'b0;
    tcfg_req_cnt     <= 2'd0;
    tcfg_gnt_pending <= 1'b0;
  end
  else begin
    if(tcfg_req_trig) begin
      tcfg_req_thrtl <= 1'b1;
    end
    else if(tcfg_req_exit) begin
      tcfg_req_thrtl <= 1'b0;
    end

    if((trn_tcfg_req && !trn_tcfg_req_d) || tcfg_gnt_pending) begin
      tcfg_req_cnt <= TCFG_LATENCY_TIME;
    end
    else begin
      if(tcfg_req_cnt > 0) begin
        tcfg_req_cnt <= tcfg_req_cnt - 2'd1;
      end
    end

    if(trn_tcfg_req && !trn_tcfg_req_d) begin
      tcfg_gnt_pending <= 1'b1;
    end
    else if(tcfg_gnt_log) begin
      tcfg_gnt_pending <= 1'b0;
    end

    trn_tcfg_req_d <= trn_tcfg_req;
    trn_tdst_rdy_d <= trn_tdst_rdy;
    reg_tcfg_gnt   <= user_tcfg_gnt;
  end
end


assign ppm_L1_trig = (cfg_pcie_link_state_d == LINKSTATE_L0) &&
                       (cfg_pcie_link_state == LINKSTATE_PPM_L1_TRANS);
assign ppm_L1_exit = cfg_pcie_link_state == LINKSTATE_L0;

always_ff @(posedge user_clk) begin
  if(user_rst) begin
    ppm_L1_thrtl          <= 1'b0;
    cfg_pcie_link_state_d <= 3'b0;
    trn_rdllp_src_rdy_d   <= 1'b0;
  end
  else begin
    if(ppm_L1_trig) begin
      ppm_L1_thrtl <= 1'b1;
    end
    else if(ppm_L1_exit) begin
      ppm_L1_thrtl <= 1'b0;
    end
    cfg_pcie_link_state_d <= cfg_pcie_link_state;
    trn_rdllp_src_rdy_d   <= trn_rdllp_src_rdy;
  end
end


assign ppm_L23_trig = wire_to_turnoff && reg_turnoff_ok;

logic reg_to_turnoff;
always_ff @(posedge user_clk) begin
  if(user_rst)            reg_to_turnoff <= 1'b0;
  else if(cfg_to_turnoff) reg_to_turnoff <= 1'b1;
end
assign wire_to_turnoff = reg_to_turnoff;

always_ff @(posedge user_clk) begin
  if(user_rst) reg_turnoff_ok <= 1'b0;
  else         reg_turnoff_ok <= user_turnoff_ok;
end

always_ff @(posedge user_clk) begin
  if(user_rst) begin
    ppm_L23_thrtl   <= 1'b0;
    cfg_turnoff_ok_pending <= 1'b0;
  end
  else begin
    if(ppm_L23_trig) begin
      ppm_L23_thrtl <= 1'b1;
    end

    if(ppm_L23_trig && !ppm_L23_thrtl) begin
      cfg_turnoff_ok_pending <= 1'b1;
    end
    else if(cfg_turnoff_ok) begin
      cfg_turnoff_ok_pending <= 1'b0;
    end
  end
end


always_ff @(posedge user_clk) begin
  if(user_rst) begin
    reg_axi_in_pkt <= 1'b0;
  end
  else begin
    if(s_axis_tx_tvalid && s_axis_tx_tlast) begin
      reg_axi_in_pkt <= 1'b0;
    end
    else if(tready_thrtl && s_axis_tx_tvalid) begin
      reg_axi_in_pkt <= 1'b1;
    end
  end
end

assign axi_in_pkt     = s_axis_tx_tvalid || reg_axi_in_pkt;
assign axi_pkt_ending = s_axis_tx_tvalid && s_axis_tx_tlast;
assign axi_throttled  = !tready_thrtl;
assign axi_thrtl_ok   = !axi_in_pkt || axi_pkt_ending || axi_throttled;



assign pre_throttle = tbuf_av_min_trig || tbuf_av_gap_trig || lnk_up_trig
                                || tcfg_req_trig || ppm_L1_trig || ppm_L23_trig;


assign reg_throttle = tbuf_av_min_thrtl || tbuf_av_gap_thrtl || lnk_up_thrtl
                             || tcfg_req_thrtl || ppm_L1_thrtl || ppm_L23_thrtl;

assign exit_crit = !tbuf_av_min_thrtl && !tbuf_av_gap_thrtl && !lnk_up_thrtl
                          && !tcfg_req_thrtl && !ppm_L1_thrtl && !ppm_L23_thrtl;

always_comb begin
  case(cur_state)
    IDLE: begin
      if(reg_throttle && axi_thrtl_ok) begin
        tready_thrtl_mux = 1'b0;
        next_state       = THROTTLE;

        if(tcfg_req_thrtl) begin
          tcfg_gnt_log   = 1'b1;
          cfg_turnoff_ok = 1'b0;
        end
        else if(ppm_L23_thrtl) begin
          tcfg_gnt_log   = 1'b0;
          cfg_turnoff_ok = 1'b1;
        end
        else begin
          tcfg_gnt_log   = 1'b0;
          cfg_turnoff_ok = 1'b0;
        end
      end

      else begin
        tready_thrtl_mux = !(axi_thrtl_ok && pre_throttle);
        next_state       = IDLE;

        tcfg_gnt_log     = 1'b0;
        cfg_turnoff_ok   = 1'b0;
      end
    end

    THROTTLE: begin
      if(exit_crit) begin
        tready_thrtl_mux = !pre_throttle;
        next_state       = IDLE;
      end
      else begin
        tready_thrtl_mux = 1'b0;
        next_state       = THROTTLE;
      end

      if(tcfg_req_thrtl && tcfg_gnt_pending) begin
        tcfg_gnt_log   = 1'b1;
        cfg_turnoff_ok = 1'b0;
      end
      else if(cfg_turnoff_ok_pending) begin
        tcfg_gnt_log   = 1'b0;
        cfg_turnoff_ok = 1'b1;
      end
      else begin
        tcfg_gnt_log   = 1'b0;
        cfg_turnoff_ok = 1'b0;
      end
    end

    default: begin
      tready_thrtl_mux = 1'b0;
      next_state       = IDLE;
      tcfg_gnt_log     = 1'b0;
      cfg_turnoff_ok   = 1'b0;
    end
  endcase
end

always_ff @(posedge user_clk) begin
  if(user_rst) begin
    cur_state        <= THROTTLE;

    reg_tlast        <= 1'b0;

    tready_thrtl     <= 1'b0;
  end
  else begin
    cur_state        <= next_state;

    tready_thrtl     <= tready_thrtl_mux && !tx_ecrc_pause;
    reg_tlast        <= s_axis_tx_tlast;
  end
end

wire        tx_ecrc_pkt;
logic       reg_tx_ecrc_pkt;
wire  [1:0] packet_fmt;
wire        packet_td;
wire  [2:0] header_len;
wire  [9:0] payload_len;
wire [13:0] packet_len;
wire        pause_needed;

assign packet_fmt   = s_axis_tx_tdata[30:29];
assign packet_td    = s_axis_tx_tdata[15];
assign header_len   = packet_fmt[0] ? 3'd4 : 3'd3;
assign payload_len  = packet_fmt[1] ? s_axis_tx_tdata[9:0] : 10'h0;
assign packet_len   = {10'h000, header_len} + {4'h0, payload_len};
assign pause_needed = (packet_len[0] == 1'b0) && !packet_td;

assign tx_ecrc_pkt = s_axis_tx_tuser[0] && pause_needed &&
                        tready_thrtl && s_axis_tx_tvalid && !reg_axi_in_pkt;

always_ff @(posedge user_clk) begin
  if(user_rst) begin
    reg_tx_ecrc_pkt <= 1'b0;
  end else begin
    if(tx_ecrc_pkt && !s_axis_tx_tlast)
      reg_tx_ecrc_pkt <= 1'b1;
    else if(tready_thrtl && s_axis_tx_tvalid && s_axis_tx_tlast)
      reg_tx_ecrc_pkt <= 1'b0;
  end
end

assign tx_ecrc_pause = ((tx_ecrc_pkt || reg_tx_ecrc_pkt) &&
                       s_axis_tx_tlast && s_axis_tx_tvalid && tready_thrtl);


assign trn_tcfg_gnt = tcfg_gnt_log;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
