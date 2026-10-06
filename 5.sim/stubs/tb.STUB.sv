// SPDX-FileCopyrightText: 2025 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// Copyright (C) 2025 Chili.CHIPS
//--------------------------------------------------------------------------
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
// Description: Simulation testbench for FPGA. It provides models of
//              external resources, as connected on the actual board
//==========================================================================

`timescale 1ps/1ps

module tb #(
   parameter RUN_SIM_US     = 10000,
             PIPE_DATAWIDTH = 64   
   
)();

   // glbl glbl();

//--------------------------------------------------------------
// Clock and reset generation
//--------------------------------------------------------------

  // Generate clocks and run sim for the specified amount of time
  localparam  HALF_CLK_P_PERIOD_PS      = 2_500; // 200MHz
  localparam  HALF_PCIE_PERIOD_PS       = 2_000; // 250MHz (GEN1)
  localparam  HALF_PIPE_PERIOD_PS       = HALF_PCIE_PERIOD_PS*8;
  localparam  RST_CYLES                 = 10;

  logic       clk_p;
  wire        clk_n;
  logic       rst_n;
  logic       pcieclk;
  logic       pclk;
  logic [2:1] key;

  initial begin
    clk_p      = 1'b0;
    //clk_n      = 1'b0;
    rst_n      = 1'b0;
    pcieclk    = 1'b0;
    pclk        = 1'b0;

    key        = 2'b0;

    fork
      begin : board_rst_n
        #(HALF_CLK_P_PERIOD_PS*RST_CYLES * 1ps)
          rst_n = 1'b1;
      end

      forever begin: clk_p_gen
        #(HALF_CLK_P_PERIOD_PS * 1ps)
          clk_p  = ~clk_p;
      end

      forever begin: pcie_clock_gen
        #(HALF_PCIE_PERIOD_PS * 1ps)
          pcieclk = ~pcieclk;
      end
      
      forever begin: pipe_clock_gen
        #(HALF_PIPE_PERIOD_PS * 1ps)
          pclk = ~pclk;
      end

      begin: run_sim
        #(RUN_SIM_US * 1us);
          $finish(2);
      end
    join
  end

  assign clk_n = ~clk_p;


//--------------------------------------------------------------
// DUT
//--------------------------------------------------------------

  logic        uart_rx, uart_tx;
  logic [3:2]  led;

  logic [PIPE_DATAWIDTH-1:0]           downdata;
  logic [PIPE_DATAWIDTH/8-1:0]         downdatak;
  logic [PIPE_DATAWIDTH-1:0]           updata;
  logic [PIPE_DATAWIDTH/8-1:0]         updatak;

  top #(
    .DataWidth                         (PIPE_DATAWIDTH)
  ) dut
  (
    .clk_p                             (clk_p),
    .clk_n                             (clk_n),
    .rst_n                             (rst_n),

    .pclk                              (pclk),
    
    // Test purposes only, whilst pcievhost component in stub DUT stand-in
    .pcieclk                           (pcieclk),
 
    // PCie PIPE data
    .txdata                            (downdata),
    .txdatak                           (downdatak),
    .rxdata                            (updata),
    .rxdatak                           (updatak),

    // UART
    .uart_rx                           (uart_rx),
    .uart_tx                           (uart_tx),

    // Keys
    .key_in                            (key),

    // LEDs
    .led                               (led)
  );

//--------------------------------------------------------------
// PCIe endpoint model
//--------------------------------------------------------------

  pcieVHostPipex1 #(
    .NodeNum                           (2),
    .EndPoint                          (0),
    .DataWidth                         (PIPE_DATAWIDTH)
  ) bfm_pcie
  (
    .pcieclk                           (pcieclk),
    .pclk                              (pclk),
    .nreset                            (rst_n),

    .TxData                            (updata),
    .TxDataK                           (updatak),

    .RxData                            (downdata),
    .RxDataK                           (downdatak)
  );

//--------------------------------------------------------------
// model of external UART
//--------------------------------------------------------------
  bfm_uart bfm_uart (
    .uart_rx                           (uart_tx), //i
    .uart_tx                           (uart_rx)  //o
  );


// Top level fatal task, which can be called from anywhere in verilog code.
// via the `fatal definition in pciedispheader.v. Any data logging, error
// message displays etc., on a fatal, should be placed in here.
task Fatal;
begin
    $display("***FATAL ERROR...calling $finish!");
    $finish;
end
endtask

endmodule: tb

/*
------------------------------------------------------------------------------
Version History:
------------------------------------------------------------------------------
 2025/08/19 SS: initial creation

*/
