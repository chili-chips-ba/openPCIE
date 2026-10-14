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

module clk_rst_gen
  import link_pkg::*;
(
    input logic txoutclk,     // GT TXOUTCLK: the 100 MHz refclk, passed through
    input logic perst_n,      // PERST# from the connector, active low
    input logic pipe_clk_sel, // 1 = 250 MHz (Gen2), voted by all lanes (gtp_wrapper)

    output logic clk125,   // 125 MHz: GT DRP, PLL0 power-up, reset release
    output logic rst125_n, // the design's reset, released on clk125

    output logic clk62m5,   // 62.5 MHz: PCIE_2_1 USERCLK, TRN bridge, SOC
    output logic rst62m5_n, // rst125_n, released on clk62m5

    output logic pipe_clk,    // PIPE clock: 125 MHz Gen1, 250 MHz Gen2
    output logic pipe_rst_n,  // rst125_n, released on pipe_clk
    output logic mmcm_lock
);

  localparam int DIVCLK_DIVIDE    = 1;
  localparam int CLKFBOUT_MULT_F  = 10;  // 100 MHz refclk -> 1 GHz VCO
  localparam int CLKIN1_PERIOD    = 10;
  localparam int CLKOUT0_DIVIDE_F = 8;   // 125 MHz
  localparam int CLKOUT1_DIVIDE   = 4;   // 250 MHz
  localparam int CLKOUT2_DIVIDE   = 16;  // 62.5 MHz user clock (USERCLK and USERCLK2 of PCIE_2_1)
  localparam int CLKOUT3_DIVIDE   = 16;  // CLKOUT3 unused
  localparam int CLKOUT4_DIVIDE   = 20;

  logic       refclk;
  logic       mmcm_fb;
  logic       clk_125mhz;
  logic       clk_250mhz;
  logic       clk62m5_mmcm;


  // ---- The design's one reset source: power-on reset + PERST#
  //
  // Every reset in this design derives from rst125_n. It is asserted by:
  //   1. FPGA configuration: the INIT = 0 of the two FDCE flops below holds
  //      the reset from the end of configuration until two clk125 edges
  //      later. Configuration (from flash, or from JTAG at any time) can end
  //      long after PERST# was released, so PERST# alone cannot reset the
  //      design.
  //   2. PERST# (perst_n), asynchronously, at any time after configuration.
  //      PERST# also resets the MMCM, so the MMCM re-locks on a stable refclk.
  //   3. Loss of MMCM lock (mmcm_lock): the design stays in reset until the
  //      MMCM is locked, after PERST# and after a refclk glitch alike.
  // The release is synchronous to clk125, two stages deep, so the release
  // of PERST# cannot go metastable.
  //
  // These are the only flops in the design with an INIT value, and the only
  // ones built from primitive instances. The instances are deliberate:
  //   - they make this one exception to the "no initial values" rule
  //     (2.rtl/README.md, RTL coding rules) stand out;
  //   - the INIT parameter is explicit and reaches the bitstream the same way
  //     in Vivado and openXC7, instead of relying on how each tool maps a
  //     declaration initializer.
  // clk125 runs before the GT PLL is powered up (refclk -> MMCM, see below),
  // so this reset works before the PLL0 power-up sequence in init_ctrl.
  logic [1:0] rst_sync;

  (* ASYNC_REG = "TRUE" *)
  FDCE #(
      .INIT(1'b0)
  ) u_rst_sync0 (  // INIT = 0: reset asserted after configuration
      .C  (clk125),
      .CE (1'b1),
      .CLR(~(perst_n & mmcm_lock)),  // PERST# or no MMCM lock: reset, asynchronously
      .D  (1'b1),
      .Q  (rst_sync[0])
  );

  (* ASYNC_REG = "TRUE" *)
  FDCE #(
      .INIT(1'b0)
  ) u_rst_sync1 (  // INIT = 0: reset asserted after configuration
      .C  (clk125),
      .CE (1'b1),
      .CLR(~(perst_n & mmcm_lock)),
      .D  (rst_sync[0]),
      .Q  (rst_sync[1])
  );

  assign rst125_n = rst_sync[1];

  // ---- rst125_n for the clk62m5 domain: asserted with rst125_n,
  // released on clk62m5
  (* ASYNC_REG = "TRUE" *) logic rst62m5_meta, rst62m5_q;

  always_ff @(posedge clk62m5 or negedge rst125_n) begin
    if (!rst125_n) begin
      rst62m5_meta <= 1'b0;
      rst62m5_q    <= 1'b0;
    end
    else begin
      rst62m5_meta <= 1'b1;
      rst62m5_q    <= rst62m5_meta;
    end
  end

  assign rst62m5_n = rst62m5_q;

  // ---- rst125_n for the pipe_clk domain: asserted with rst125_n,
  // released on pipe_clk. Asserting it needs no clock, so it also resets the
  // pipe_clk select vote (gtp_wrapper), which picks the clock it runs on.
  (* ASYNC_REG = "TRUE" *) logic pipe_rst_meta, pipe_rst_q;

  always_ff @(posedge pipe_clk or negedge rst125_n) begin
    if (!rst125_n) begin
      pipe_rst_meta <= 1'b0;
      pipe_rst_q    <= 1'b0;
    end
    else begin
      pipe_rst_meta <= 1'b1;
      pipe_rst_q    <= pipe_rst_meta;
    end
  end

  assign pipe_rst_n = pipe_rst_q;

  BUFG u_txoutclk (
      .I(txoutclk),
      .O(refclk)
  );

  MMCME2_ADV #(
      .BANDWIDTH           ("OPTIMIZED"),
      .CLKOUT4_CASCADE     ("FALSE"),
      .COMPENSATION        ("ZHOLD"),
      .STARTUP_WAIT        ("FALSE"),
      .DIVCLK_DIVIDE       (DIVCLK_DIVIDE),
      .CLKFBOUT_MULT_F     (CLKFBOUT_MULT_F),
      .CLKFBOUT_USE_FINE_PS("FALSE"),
      .CLKOUT0_DIVIDE_F    (CLKOUT0_DIVIDE_F),
      .CLKOUT0_USE_FINE_PS ("FALSE"),
      .CLKOUT1_DIVIDE      (CLKOUT1_DIVIDE),
      .CLKOUT1_USE_FINE_PS ("FALSE"),
      .CLKOUT2_DIVIDE      (CLKOUT2_DIVIDE),
      .CLKOUT2_USE_FINE_PS ("FALSE"),
      .CLKOUT3_DIVIDE      (CLKOUT3_DIVIDE),
      .CLKOUT3_USE_FINE_PS ("FALSE"),
      .CLKOUT4_DIVIDE      (CLKOUT4_DIVIDE),
      .CLKOUT4_USE_FINE_PS ("FALSE"),
      // FIXME SYN_YOSYS_BUG (openPCIE #20): Yosys's SystemVerilog front end (read_slang / sv-elab)
      // cannot pass real-valued parameters to a primitive -- see
      // https://github.com/povik/sv-elab/issues/282 . The values below are all
      // MMCME2_ADV defaults, so leaving them out builds the same MMCM. Only the
      // openXC7 slang flow defines SYN_YOSYS_BUG; Vivado and sv2v use the block.
`ifndef SYN_YOSYS_BUG
      .CLKFBOUT_PHASE      (0.000),
      .CLKOUT0_PHASE       (0.000),
      .CLKOUT0_DUTY_CYCLE  (0.500),
      .CLKOUT1_PHASE       (0.000),
      .CLKOUT1_DUTY_CYCLE  (0.500),
      .CLKOUT2_PHASE       (0.000),
      .CLKOUT2_DUTY_CYCLE  (0.500),
      .CLKOUT3_PHASE       (0.000),
      .CLKOUT3_DUTY_CYCLE  (0.500),
      .CLKOUT4_PHASE       (0.000),
      .CLKOUT4_DUTY_CYCLE  (0.500),
      .REF_JITTER1         (0.010),
`endif
      .CLKIN1_PERIOD       (CLKIN1_PERIOD)
  ) u_mmcm (
      .CLKIN1      (refclk),
      .CLKIN2      (1'd0),
      .CLKINSEL    (1'd1),
      .CLKFBIN     (mmcm_fb),
      .RST         (~perst_n),       // PERST#: re-lock on a stable refclk
      .PWRDWN      (1'd0),
      .CLKFBOUT    (mmcm_fb),
      .CLKFBOUTB   (  /*LINT:OK*/),
      .CLKOUT0     (clk_125mhz),
      .CLKOUT0B    (  /*LINT:OK*/),
      .CLKOUT1     (clk_250mhz),
      .CLKOUT1B    (  /*LINT:OK*/),
      .CLKOUT2     (clk62m5_mmcm),
      .CLKOUT2B    (  /*LINT:OK*/),
      .CLKOUT3     (  /*LINT:OK*/),
      .CLKOUT3B    (  /*LINT:OK*/),
      .CLKOUT4     (  /*LINT:OK*/),
      .CLKOUT5     (  /*LINT:OK*/),
      .CLKOUT6     (  /*LINT:OK*/),
      .LOCKED      (mmcm_lock),
      .DCLK        (1'd0),
      .DADDR       ('0),
      .DEN         (1'd0),
      .DWE         (1'd0),
      .DI          ('0),
      .DO          (  /*LINT:OK*/),
      .DRDY        (  /*LINT:OK*/),
      .PSCLK       (1'd0),
      .PSEN        (1'd0),
      .PSINCDEC    (1'd0),
      .PSDONE      (  /*LINT:OK*/),
      .CLKINSTOPPED(  /*LINT:OK*/),
      .CLKFBSTOPPED(  /*LINT:OK*/)
  );

  BUFGCTRL u_pipe_clk (
      .CE0    (1'd1),
      .CE1    (1'd1),
      .I0     (clk_125mhz),
      .I1     (clk_250mhz),
      .IGNORE0(1'd0),
      .IGNORE1(1'd0),
      .S0     (~pipe_clk_sel),
      .S1     (pipe_clk_sel),
      .O      (pipe_clk)
  );

  BUFG u_clk125 (
      .I(clk_125mhz),
      .O(clk125)
  );

  BUFG u_clk62m5 (
      .I(clk62m5_mmcm),
      .O(clk62m5)
  );



endmodule
// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
