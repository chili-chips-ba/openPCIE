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

module eios_squelch (
  output logic [1:0]   USER_RXCHARISK,
  output logic [15:0]  USER_RXDATA,
  output logic         USER_RXVALID,
  output logic         USER_RXELECIDLE,
  output logic [2:0]   USER_RX_STATUS,
  output logic         USER_RX_PHY_STATUS,
  input  logic [1:0]   GT_RXCHARISK,
  input  logic [15:0]  GT_RXDATA,
  input  logic         GT_RXVALID,
  input  logic         GT_RXELECIDLE,
  input  logic [2:0]   GT_RX_STATUS,
  input  logic         GT_RX_PHY_STATUS,

  input  logic         PLM_IN_L0,
  input  logic         PLM_IN_RS,

  input  logic         USER_CLK,
  input  logic         RESET
);

  localparam logic [4:0] EIOS_DET_IDL     = 5'b00001;
  localparam logic [4:0] EIOS_DET_NO_STR0 = 5'b00010;
  localparam logic [4:0] EIOS_DET_STR0    = 5'b00100;
  localparam logic [4:0] EIOS_DET_STR1    = 5'b01000;
  localparam logic [4:0] EIOS_DET_DONE    = 5'b10000;

  localparam logic [7:0] EIOS_COM = 8'hBC;
  localparam logic [7:0] EIOS_IDL = 8'h7C;

  logic [4:0] reg_state_eios_det;
  logic       reg_symbol_after_eios;

  logic [1:0]  gt_rxcharisk_q;
  logic [15:0] gt_rxdata_q;
  logic        gt_rxvalid_q;
  logic        gt_rxelecidle_q;
  logic [2:0]  gt_rx_status_q;
  logic        gt_rx_phy_status_q;

  always_ff @(posedge USER_CLK) begin
    if (RESET) begin
      reg_state_eios_det    <= EIOS_DET_IDL;
      reg_symbol_after_eios <= 1'b0;
      gt_rxcharisk_q        <= 2'b00;
      gt_rxdata_q           <= 16'h0;
      gt_rxvalid_q          <= 1'b0;
      gt_rxelecidle_q       <= 1'b0;
      gt_rx_status_q        <= 3'b000;
      gt_rx_phy_status_q    <= 1'b0;
    end else begin
      reg_symbol_after_eios <= 1'b0;
      gt_rxcharisk_q        <= GT_RXCHARISK;
      gt_rxelecidle_q       <= GT_RXELECIDLE;
      gt_rxdata_q           <= GT_RXDATA;
      gt_rx_phy_status_q    <= GT_RX_PHY_STATUS;

      if ((reg_state_eios_det == EIOS_DET_DONE) && PLM_IN_L0)
        gt_rxvalid_q <= 1'b0;
      else if (GT_RXELECIDLE && !gt_rxvalid_q)
        gt_rxvalid_q <= 1'b0;
      else
        gt_rxvalid_q <= GT_RXVALID;

      if (gt_rxvalid_q)
        gt_rx_status_q <= GT_RX_STATUS;
      else if (!gt_rxvalid_q && PLM_IN_L0)
        gt_rx_status_q <= 3'b0;
      else
        gt_rx_status_q <= GT_RX_STATUS;

      case (reg_state_eios_det)
        EIOS_DET_IDL: begin
          if (gt_rxcharisk_q[0] && (gt_rxdata_q[7:0]  == EIOS_COM) &&
              gt_rxcharisk_q[1] && (gt_rxdata_q[15:8] == EIOS_IDL))
            reg_state_eios_det <= EIOS_DET_NO_STR0;
          else if (gt_rxcharisk_q[1] && (gt_rxdata_q[15:8] == EIOS_COM))
            reg_state_eios_det <= EIOS_DET_STR0;
          else
            reg_state_eios_det <= EIOS_DET_IDL;
        end

        EIOS_DET_NO_STR0: begin
          if ((gt_rxcharisk_q[0] && (gt_rxdata_q[7:0]  == EIOS_IDL)) &&
              (gt_rxcharisk_q[1] && (gt_rxdata_q[15:8] == EIOS_IDL))) begin
            reg_state_eios_det <= EIOS_DET_DONE;
            gt_rxvalid_q       <= 1'b0;
          end else if (gt_rxcharisk_q[0] && (gt_rxdata_q[7:0] == EIOS_IDL)) begin
            reg_state_eios_det <= EIOS_DET_DONE;
            gt_rxvalid_q       <= 1'b0;
          end else
            reg_state_eios_det <= EIOS_DET_IDL;
        end

        EIOS_DET_STR0: begin
          if ((gt_rxcharisk_q[0] && (gt_rxdata_q[7:0]  == EIOS_IDL)) &&
              (gt_rxcharisk_q[1] && (gt_rxdata_q[15:8] == EIOS_IDL))) begin
            reg_state_eios_det    <= EIOS_DET_STR1;
            gt_rxvalid_q          <= 1'b0;
            reg_symbol_after_eios <= 1'b1;
          end else
            reg_state_eios_det <= EIOS_DET_IDL;
        end

        EIOS_DET_STR1: begin
          if (gt_rxcharisk_q[0] && (gt_rxdata_q[7:0] == EIOS_IDL)) begin
            reg_state_eios_det <= EIOS_DET_DONE;
            gt_rxvalid_q       <= 1'b0;
          end else
            reg_state_eios_det <= EIOS_DET_IDL;
        end

        EIOS_DET_DONE:
          reg_state_eios_det <= EIOS_DET_IDL;

        default:
          reg_state_eios_det <= EIOS_DET_IDL;
      endcase
    end
  end

  assign USER_RXVALID       = gt_rxvalid_q;
  assign USER_RXCHARISK[0]  = gt_rxvalid_q ? gt_rxcharisk_q[0] : 1'b0;
  assign USER_RXCHARISK[1]  = (gt_rxvalid_q && !reg_symbol_after_eios) ? gt_rxcharisk_q[1] : 1'b0;
  assign USER_RXDATA[7:0]   = gt_rxdata_q[7:0];
  assign USER_RXDATA[15:8]  = gt_rxdata_q[15:8];
  assign USER_RX_STATUS     = gt_rx_status_q;
  assign USER_RX_PHY_STATUS = gt_rx_phy_status_q;
  assign USER_RXELECIDLE    = gt_rxelecidle_q;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
