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

module clk_synth
  import link_pkg::*;
#(
  localparam PCIE_REFCLK_FREQ = 0,
  localparam PCIE_USERCLK1_FREQ = 2,
  localparam PCIE_USERCLK2_FREQ = 2) (
  input                        CLK_CLK,
  input                        CLK_TXOUTCLK,
  input        [PCIE_LANES-1:0] CLK_RXOUTCLK_IN,
  input                        CLK_RST_N,
  input        [PCIE_LANES-1:0] CLK_PCLK_SEL,
  input        [PCIE_LANES-1:0] CLK_PCLK_SEL_SLAVE,
  input                        CLK_GEN3,

  output                       CLK_PCLK,
  output                       CLK_PCLK_SLAVE,
  output                       CLK_RXUSRCLK,
  output       [PCIE_LANES-1:0] CLK_RXOUTCLK_OUT,
  output                       CLK_DCLK,
  output                       CLK_OOBCLK,
  output                       CLK_USERCLK1,
  output                       CLK_USERCLK2,
  output                       CLK_MMCM_LOCK
);

  localparam DIVCLK_DIVIDE    = 1;
  localparam CLKFBOUT_MULT_F  = (PCIE_REFCLK_FREQ == 2) ? 4 :
                                (PCIE_REFCLK_FREQ == 1) ? 8 : 10;
  localparam CLKIN1_PERIOD    = (PCIE_REFCLK_FREQ == 2) ? 4 :
                                (PCIE_REFCLK_FREQ == 1) ? 8 : 10;
  localparam CLKOUT0_DIVIDE_F = 8;
  localparam CLKOUT1_DIVIDE   = 4;
  localparam CLKOUT2_DIVIDE   = (PCIE_USERCLK1_FREQ == 5) ?  2 :
                                (PCIE_USERCLK1_FREQ == 4) ?  4 :
                                (PCIE_USERCLK1_FREQ == 3) ?  8 :
                                (PCIE_USERCLK1_FREQ == 1) ? 32 : 16;
  localparam CLKOUT3_DIVIDE   = (PCIE_USERCLK2_FREQ == 5) ?  2 :
                                (PCIE_USERCLK2_FREQ == 4) ?  4 :
                                (PCIE_USERCLK2_FREQ == 3) ?  8 :
                                (PCIE_USERCLK2_FREQ == 1) ? 32 : 16;
  localparam CLKOUT4_DIVIDE   = 20;

  wire refclk;
  wire mmcm_fb;
  wire clk_125mhz;
  wire clk_250mhz;
  wire userclk1;
  wire userclk1_1;
  wire userclk2_1;
  wire mmcm_lock;
  wire pclk_1;
  wire pclk;

  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANES-1:0] pclk_sel_reg1 = '0;
  (* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) logic [PCIE_LANES-1:0] pclk_sel_reg2 = '0;
  logic pclk_sel = 1'b0;

  always_ff @(posedge pclk) begin
    if (!CLK_RST_N) begin
      pclk_sel_reg1 <= '0;
      pclk_sel_reg2 <= '0;
    end else begin
      pclk_sel_reg1 <= CLK_PCLK_SEL;
      pclk_sel_reg2 <= pclk_sel_reg1;
    end
  end

  always_ff @(posedge pclk) begin
    if (!CLK_RST_N)               pclk_sel <= 1'b0;
    else if (&pclk_sel_reg2)      pclk_sel <= 1'b1;
    else if (&(~pclk_sel_reg2))   pclk_sel <= 1'b0;
  end

  BUFG txoutclk_i (
    .I (CLK_TXOUTCLK),
    .O (refclk)
  );

  MMCME2_ADV #(
    .BANDWIDTH            ("OPTIMIZED"),
    .CLKOUT4_CASCADE      ("FALSE"),
    .COMPENSATION         ("ZHOLD"),
    .STARTUP_WAIT         ("FALSE"),
    .DIVCLK_DIVIDE        (DIVCLK_DIVIDE),
    .CLKFBOUT_MULT_F      (CLKFBOUT_MULT_F),
    .CLKFBOUT_PHASE       (0.000),
    .CLKFBOUT_USE_FINE_PS ("FALSE"),
    .CLKOUT0_DIVIDE_F     (CLKOUT0_DIVIDE_F),
    .CLKOUT0_PHASE        (0.000),
    .CLKOUT0_DUTY_CYCLE   (0.500),
    .CLKOUT0_USE_FINE_PS  ("FALSE"),
    .CLKOUT1_DIVIDE       (CLKOUT1_DIVIDE),
    .CLKOUT1_PHASE        (0.000),
    .CLKOUT1_DUTY_CYCLE   (0.500),
    .CLKOUT1_USE_FINE_PS  ("FALSE"),
    .CLKOUT2_DIVIDE       (CLKOUT2_DIVIDE),
    .CLKOUT2_PHASE        (0.000),
    .CLKOUT2_DUTY_CYCLE   (0.500),
    .CLKOUT2_USE_FINE_PS  ("FALSE"),
    .CLKOUT3_DIVIDE       (CLKOUT3_DIVIDE),
    .CLKOUT3_PHASE        (0.000),
    .CLKOUT3_DUTY_CYCLE   (0.500),
    .CLKOUT3_USE_FINE_PS  ("FALSE"),
    .CLKOUT4_DIVIDE       (CLKOUT4_DIVIDE),
    .CLKOUT4_PHASE        (0.000),
    .CLKOUT4_DUTY_CYCLE   (0.500),
    .CLKOUT4_USE_FINE_PS  ("FALSE"),
    .CLKIN1_PERIOD        (CLKIN1_PERIOD),
    .REF_JITTER1          (0.010)
  ) mmcm_i (
    .CLKIN1       (refclk),
    .CLKIN2       (1'd0),
    .CLKINSEL     (1'd1),
    .CLKFBIN      (mmcm_fb),
    .RST          (!CLK_RST_N),
    .PWRDWN       (1'd0),
    .CLKFBOUT     (mmcm_fb),
    .CLKFBOUTB    (),
    .CLKOUT0      (clk_125mhz),
    .CLKOUT0B     (),
    .CLKOUT1      (clk_250mhz),
    .CLKOUT1B     (),
    .CLKOUT2      (userclk1),
    .CLKOUT2B     (),
    .CLKOUT3      (),
    .CLKOUT3B     (),
    .CLKOUT4      (),
    .CLKOUT5      (),
    .CLKOUT6      (),
    .LOCKED       (mmcm_lock),
    .DCLK         (1'd0),
    .DADDR        (7'd0),
    .DEN          (1'd0),
    .DWE          (1'd0),
    .DI           (16'd0),
    .DO           (),
    .DRDY         (),
    .PSCLK        (1'd0),
    .PSEN         (1'd0),
    .PSINCDEC     (1'd0),
    .PSDONE       (),
    .CLKINSTOPPED (),
    .CLKFBSTOPPED ()
  );

  BUFGCTRL pclk_i1 (
    .CE0     (1'd1),
    .CE1     (1'd1),
    .I0      (clk_125mhz),
    .I1      (clk_250mhz),
    .IGNORE0 (1'd0),
    .IGNORE1 (1'd0),
    .S0      (~pclk_sel),
    .S1      ( pclk_sel),
    .O       (pclk_1)
  );

  BUFG dclk_i (
    .I (clk_125mhz),
    .O (CLK_DCLK)
  );

  BUFG usrclk1_i1 (
    .I (userclk1),
    .O (userclk1_1)
  );

  assign userclk2_1 = userclk1_1;

  assign pclk             = pclk_1;
  assign CLK_PCLK         = pclk;
  assign CLK_PCLK_SLAVE   = 1'b0;
  assign CLK_RXUSRCLK     = pclk_1;
  assign CLK_RXOUTCLK_OUT = {PCIE_LANES{1'b0}};
  assign CLK_OOBCLK       = pclk;
  assign CLK_USERCLK1     = userclk1_1;
  assign CLK_USERCLK2     = userclk2_1;
  assign CLK_MMCM_LOCK    = mmcm_lock;

endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
