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

module lane_status #(
  localparam RXCDRLOCK_MAX = 4'd15,
  localparam RXVALID_MAX   = 4'd15) (
  input               USER_TXUSRCLK,
  input               USER_RXUSRCLK,
  input               USER_OOBCLK_IN,
  input               USER_RST_N,
  input               USER_RXUSRCLK_RST_N,
  input               USER_PCLK_SEL,
  input               USER_TXRESETDONE,
  input               USER_RXRESETDONE,
  input               USER_TXELECIDLE,
  input               USER_TXCOMPLIANCE,
  input               USER_RXCDRLOCK_IN,
  input               USER_RXVALID_IN,
  input               USER_RXSTATUS_IN,
  input               USER_PHYSTATUS_IN,
  input               USER_RATE_DONE,
  input               USER_RST_IDLE,
  input               USER_RATE_IDLE,

  output              USER_OOBCLK,
  output              USER_RESETDONE,
  output              USER_ACTIVE_LANE,
  output              USER_RXCDRLOCK_OUT,
  output              USER_RXVALID_OUT,
  output              USER_PHYSTATUS_OUT,
  output              USER_PHYSTATUS_RST
);

  wire [5:0] tx_async = { USER_RXCDRLOCK_IN, USER_TXCOMPLIANCE, USER_TXELECIDLE,
                          USER_RXRESETDONE, USER_TXRESETDONE, USER_PCLK_SEL };
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [5:0] tx_s1 = 6'd0, tx_s2 = 6'd0;

  always_ff @(posedge USER_TXUSRCLK)
    if (!USER_RST_N) begin tx_s1 <= 6'd0; tx_s2 <= 6'd0; end
    else             begin tx_s1 <= tx_async; tx_s2 <= tx_s1; end

  wire pclk_sel_2      = tx_s2[0];
  wire txresetdone_2   = tx_s2[1];
  wire rxresetdone_2   = tx_s2[2];
  wire txelecidle_2    = tx_s2[3];
  wire txcompliance_2  = tx_s2[4];
  wire rxcdrlock_2     = tx_s2[5];

  wire [4:0] rx_async = { USER_RATE_IDLE, USER_RATE_DONE, USER_RST_IDLE,
                          USER_RXSTATUS_IN, USER_RXVALID_IN };
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [4:0] rx_s1 = 5'd0, rx_s2 = 5'd0;

  always_ff @(posedge USER_RXUSRCLK)
    if (!USER_RXUSRCLK_RST_N) begin rx_s1 <= 5'd0; rx_s2 <= 5'd0; end
    else                      begin rx_s1 <= rx_async; rx_s2 <= rx_s1; end

  wire rxvalid_2     = rx_s2[0];
  wire rxstatus_2    = rx_s2[1];
  wire rst_idle_2    = rx_s2[2];
  wire rate_done_2   = rx_s2[3];
  wire rate_idle_2   = rx_s2[4];

  // SIGVALIDCLK for the OOB detector: USER_OOBCLK_IN / 2, or / 4 with USER_PCLK_SEL
  logic [1:0] oobclk_cnt = 2'd0;
  logic       oobclk     = 1'b0;

  always_ff @(posedge USER_OOBCLK_IN)
    if (!USER_RST_N) begin oobclk_cnt <= 2'd0; oobclk <= 1'b0; end
    else begin
      oobclk_cnt <= oobclk_cnt + 2'd1;
      oobclk     <= pclk_sel_2 ? oobclk_cnt[1] : oobclk_cnt[0];
    end

  logic [3:0] rxcdrlock_cnt = 4'd0;
  always_ff @(posedge USER_TXUSRCLK)
    if      (!USER_RST_N)                         rxcdrlock_cnt <= 4'd0;
    else if (!rxcdrlock_2)                        rxcdrlock_cnt <= 4'd0;
    else if (rxcdrlock_cnt != RXCDRLOCK_MAX)      rxcdrlock_cnt <= rxcdrlock_cnt + 4'd1;

  logic [3:0] rxvalid_cnt = 4'd0;
  always_ff @(posedge USER_RXUSRCLK)
    if      (!USER_RXUSRCLK_RST_N)                       rxvalid_cnt <= 4'd0;
    else if (rxvalid_2 && (rxvalid_cnt == RXVALID_MAX))  rxvalid_cnt <= rxvalid_cnt;
    else if (rxvalid_2 && !rxstatus_2)                   rxvalid_cnt <= rxvalid_cnt + 4'd1;
    else                                                 rxvalid_cnt <= 4'd0;

  assign USER_OOBCLK         = oobclk;
  assign USER_RESETDONE      = txresetdone_2 && rxresetdone_2;
  assign USER_ACTIVE_LANE    = !(txelecidle_2 && txcompliance_2);
  assign USER_RXCDRLOCK_OUT  = USER_RXCDRLOCK_IN && (rxcdrlock_cnt == RXCDRLOCK_MAX);
  assign USER_RXVALID_OUT    = USER_RXVALID_IN && (rxvalid_cnt == RXVALID_MAX) && rst_idle_2 && rate_idle_2;
  assign USER_PHYSTATUS_OUT  = (!rst_idle_2) || (rate_idle_2 && USER_PHYSTATUS_IN) || rate_done_2;
  assign USER_PHYSTATUS_RST  = !rst_idle_2;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
