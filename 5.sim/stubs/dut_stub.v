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
// Description:
//   Stub in lieu openpcie2-rc DUT for initial TB testing
//==========================================================================

`timescale 1ps/1ps

module top  (
   // Clocks and reset
   input          clk_p,
   input          clk_n,
   input          rst_n,

   input          pcieclk,

   // PCie PIPE data
   output [7:0]   txdata,
   output         txdatak,
   input  [7:0]   rxdata,
   input          rxdatak,

   // UART
   input          uart_rx,
   output         uart_tx,

   // Keys
   input  [1:0]   key_in,

   // LEDs
   output  [1:0]  led
);

//--------------------------------------------------------------
// Internal signals
//--------------------------------------------------------------

soc_if            bus_cpu (.arst_n(rst_n), .clk(clk_p));

//--------------------------------------------------------------
// Combinatorial logic
//--------------------------------------------------------------

assign bus_cpu.rdy                     = 1'b1;
assign bus_cpu.rdat                    = 32'h900dc0de;
assign led                             = 2'b00;

//--------------------------------------------------------------
// soc_cpu.VPROC
//--------------------------------------------------------------

  soc_cpu #(
     .ADDR_RESET                       (32'h 0000_0000),  // Unused
     .NUM_WORDS_IMEM                   (8192),            // Unused
     .NODE                             (0)                // CPU is node 0
  )
  u_cpu (
     .bus                              (bus_cpu),

    // access point for reloading CPU program memory
    .imem_cpu_rstn                     (1'b0),
    .imem_we                           (1'b0),
    .imem_waddr                        (30'h00000000),
    .imem_wdat                         (32'h00000000)
  );

//--------------------------------------------------------------
// PCIe RC model at VProc node 2
//--------------------------------------------------------------

  pcieVHostPipex1 #(
    .NodeNum                           (2),
    .EndPoint                          (0)
  ) bfm_pcie
  (
    .pclk                              (pcieclk),
    .nreset                            (rst_n),

    .TxData                            (txdata),
    .TxDataK                           (txdatak),

    .RxData                            (rxdata),
    .RxDataK                           (rxdatak)
   );

endmodule