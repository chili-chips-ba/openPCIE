//==========================================================================
// Copyright (C) 2025 Chili.CHIPS*ba
//--------------------------------------------------------------------------
//                      PROPRIETARY INFORMATION
//
// The information contained in this file is the property of CHILI CHIPS LLC.
// Except as specifically authorized in writing by CHILI CHIPS LLC, the holder
// of this file: (1) shall keep all information contained herein confidential;
// and (2) shall protect the same in whole or in part from disclosure and
// dissemination to all third parties; and (3) shall use the same for operation
// and maintenance purposes only.
//--------------------------------------------------------------------------
// Description: Simulation testbench for FPGA. It provides models of
//              external resources, as connected on the actual board
//==========================================================================

`timescale 1ps/1ps

module tb #(
   parameter int RUN_SIM_US     = 10000
)();

   // glbl glbl();

//--------------------------------------------------------------
// Clock and reset generation
//--------------------------------------------------------------

  // Generate clocks and run sim for the specified amount of time
  localparam  HALF_CLK_P_PERIOD_PS      = 2_500; // 200MHz
  localparam  HALF_PCIE_PERIOD_PS       = 1_000; // 500MHz
  localparam  RST_CYLES                 = 10;

  logic       clk_p;
  wire        clk_n;
  logic       rst_n;
  logic       pcieclk;
  logic [2:1] key;

  initial begin
    clk_p      = 1'b0;
    //clk_n      = 1'b0;
    rst_n      = 1'b0;
    pcieclk    = 1'b0;

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

  logic [7:0]  downdata;
  logic        downdatak;
  logic [7:0]  updata;
  logic        updatak;

  top dut (
    .clk_p                             (clk_p),
    .clk_n                             (clk_n),
    .rst_n                             (rst_n),

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
    .NodeNum                           (1),
    .EndPoint                          (1)
  ) bfm_pcie
  (
    .pclk                              (pcieclk),
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
