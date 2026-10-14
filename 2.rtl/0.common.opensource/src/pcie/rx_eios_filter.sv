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

module rx_eios_filter
  import link_pkg::*;
(
    output pipe_rx_lane_t user_rx,  // filtered lane, to the MAC
    input  pipe_rx_lane_t gt_rx,    // lane from the GTP, 16 bits used

    input logic plm_in_l0,

    input logic pipe_clk,
    input logic reset
);

  typedef enum logic [4:0] {
    EIOS_DET_IDL     = 5'b00001,
    EIOS_DET_NO_STR0 = 5'b00010,
    EIOS_DET_STR0    = 5'b00100,
    EIOS_DET_STR1    = 5'b01000,
    EIOS_DET_DONE    = 5'b10000
  } eios_det_e;

  localparam logic [7:0] EIOS_COM = 8'hBC;
  localparam logic [7:0] EIOS_IDL = 8'h7C;

  eios_det_e        reg_state_eios_det;
  logic             reg_symbol_after_eios;

  logic      [ 1:0] gt_rxcharisk_q;
  logic      [15:0] gt_rxdata_q;
  logic             gt_rxvalid_q;
  logic             gt_rxelecidle_q;
  logic      [ 2:0] gt_rx_status_q;
  logic             gt_rx_phy_status_q;

  always_ff @(posedge pipe_clk) begin
    if (reset) begin
      reg_state_eios_det    <= EIOS_DET_IDL;
      reg_symbol_after_eios <= 1'b0;
      gt_rxcharisk_q        <= 2'b00;
      gt_rxdata_q           <= 16'h0;
      gt_rxvalid_q          <= 1'b0;
      gt_rxelecidle_q       <= 1'b0;
      gt_rx_status_q        <= 3'b000;
      gt_rx_phy_status_q    <= 1'b0;
    end
    else begin
      reg_symbol_after_eios <= 1'b0;
      gt_rxcharisk_q        <= gt_rx.char_is_k;
      gt_rxelecidle_q       <= gt_rx.elec_idle;
      gt_rxdata_q           <= gt_rx.data;
      gt_rx_phy_status_q    <= gt_rx.phy_status;

      if ((reg_state_eios_det == EIOS_DET_DONE) && plm_in_l0) begin
        gt_rxvalid_q <= 1'b0;
      end
      else if (gt_rx.elec_idle && !gt_rxvalid_q) begin
        gt_rxvalid_q <= 1'b0;
      end
      else begin
        gt_rxvalid_q <= gt_rx.valid;
      end

      if (gt_rxvalid_q) begin
        gt_rx_status_q <= gt_rx.status;
      end
      else if (!gt_rxvalid_q && plm_in_l0) begin
        gt_rx_status_q <= 3'b0;
      end
      else begin
        gt_rx_status_q <= gt_rx.status;
      end

      unique case (reg_state_eios_det)
        EIOS_DET_IDL: begin
          if (gt_rxcharisk_q[0] && (gt_rxdata_q[7:0]  == EIOS_COM) &&
              gt_rxcharisk_q[1] && (gt_rxdata_q[15:8] == EIOS_IDL))
            begin
            reg_state_eios_det <= EIOS_DET_NO_STR0;
          end
          else if (gt_rxcharisk_q[1] && (gt_rxdata_q[15:8] == EIOS_COM)) begin
            reg_state_eios_det <= EIOS_DET_STR0;
          end
          else begin
            reg_state_eios_det <= EIOS_DET_IDL;
          end
        end

        EIOS_DET_NO_STR0: begin
          if ((gt_rxcharisk_q[0] && (gt_rxdata_q[7:0]  == EIOS_IDL)) &&
              (gt_rxcharisk_q[1] && (gt_rxdata_q[15:8] == EIOS_IDL))) begin
            reg_state_eios_det <= EIOS_DET_DONE;
            gt_rxvalid_q       <= 1'b0;
          end
          else if (gt_rxcharisk_q[0] && (gt_rxdata_q[7:0] == EIOS_IDL)) begin
            reg_state_eios_det <= EIOS_DET_DONE;
            gt_rxvalid_q       <= 1'b0;
          end
          else begin
            reg_state_eios_det <= EIOS_DET_IDL;
          end
        end

        EIOS_DET_STR0: begin
          if ((gt_rxcharisk_q[0] && (gt_rxdata_q[7:0]  == EIOS_IDL)) &&
              (gt_rxcharisk_q[1] && (gt_rxdata_q[15:8] == EIOS_IDL))) begin
            reg_state_eios_det    <= EIOS_DET_STR1;
            gt_rxvalid_q          <= 1'b0;
            reg_symbol_after_eios <= 1'b1;
          end
          else begin
            reg_state_eios_det <= EIOS_DET_IDL;
          end
        end

        EIOS_DET_STR1: begin
          if (gt_rxcharisk_q[0] && (gt_rxdata_q[7:0] == EIOS_IDL)) begin
            reg_state_eios_det <= EIOS_DET_DONE;
            gt_rxvalid_q       <= 1'b0;
          end
          else begin
            reg_state_eios_det <= EIOS_DET_IDL;
          end
        end

        EIOS_DET_DONE: reg_state_eios_det <= EIOS_DET_IDL;

      endcase
    end
  end

  assign user_rx.valid = gt_rxvalid_q;
  assign user_rx.char_is_k[0] = gt_rxvalid_q ? gt_rxcharisk_q[0] : 1'b0;
  assign user_rx.char_is_k[1] = (gt_rxvalid_q && !reg_symbol_after_eios) ? gt_rxcharisk_q[1] : 1'b0;
  assign user_rx.data = gt_rxdata_q;
  assign user_rx.status = gt_rx_status_q;
  assign user_rx.phy_status = gt_rx_phy_status_q;
  assign user_rx.elec_idle = gt_rxelecidle_q;
  assign user_rx.chanisaligned = gt_rx.chanisaligned;  // not filtered

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
