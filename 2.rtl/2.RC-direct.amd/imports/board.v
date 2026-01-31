
//-----------------------------------------------------------------------------
//
// (c) Copyright 2020-2026 Advanced Micro Devices, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of AMD and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
// Project    : Series-7 Integrated Block for PCI Express
// File       : board.v
// Version    : 3.3
// Description : Top-level testbench file
//
// Hierarchy   : board
//               |
//               |--xilinx_pcie_2_1_rport_7x
//               |  |
//               |  |--cgator_wrapper
//               |  |  |
//               |  |  |--pcie_2_1_rport_7x (in source directory)
//               |  |  |  |
//               |  |  |  |--<various>
//               |  |  |
//               |  |  |--cgator
//               |  |     |
//               |  |     |--cgator_cpl_decoder
//               |  |     |--cgator_pkt_generator
//               |  |     |--cgator_tx_mux
//               |  |     |--cgator_controller
//               |  |        |--<cgator_cfg_rom.data> (specified by ROM_FILE)
//               |  |
//               |  |--pio_master
//               |     |
//               |     |--pio_master_controller
//               |     |--pio_master_checker
//               |     |--pio_master_pkt_generator
//               |
//               |--xilinx_pcie_2_1_ep_7x
//                  |
//                  |--<various>
//-----------------------------------------------------------------------------

`timescale 1ns/1ns

module board;

  parameter  REF_CLK_FREQ          = 0;      // 0 - 100 MHz, 1 - 125 MHz,  2 - 250 MHz
  localparam REF_CLK_HALF_CYCLE    = (REF_CLK_FREQ == 0) ? 5000 :
                                     (REF_CLK_FREQ == 1) ? 4000 :
                                     (REF_CLK_FREQ == 2) ? 2000 : 0;

  // System-level clock and reset
  wire               sys_clk;
  reg                sys_rst_n;


localparam EXT_PIPE_SIM = "FALSE";

  

// PCI-Express Serial Interconnect
  wire  [0:0]  ep_pci_exp_txn;
  wire  [0:0]  ep_pci_exp_txp;
  wire  [0:0]  rp_pci_exp_txn;
  wire  [0:0]  rp_pci_exp_txp;

 
  //
  // Simulation endpoint with PIO Slave
  //
  xilinx_pcie_2_1_ep_7x
  #(
    .REF_CLK_FREQ(0),
    .PL_FAST_TRAIN("TRUE"),
    .ALLOW_X8_GEN2("FALSE"),
    .C_DATA_WIDTH(64),
    .LINK_CAP_MAX_LINK_WIDTH(6'h1),
    .DEVICE_ID(16'h7100),
    .LINK_CAP_MAX_LINK_SPEED(4'h2),
    .LINK_CTRL2_TARGET_LINK_SPEED(4'h2),
    .DEV_CAP_MAX_PAYLOAD_SUPPORTED(2),
    .TRN_DW("FALSE"),
    .VC0_TX_LASTPACKET(29),
    .VC0_RX_RAM_LIMIT(13'h7FF),
    .VC0_CPL_INFINITE("TRUE"),
    .VC0_TOTAL_CREDITS_PD(437),
    .VC0_TOTAL_CREDITS_CD(461),
    .USER_CLK_FREQ(1),
    .USER_CLK2_DIV2("FALSE")
  ) EP (


      // SYS Inteface
      .sys_clk_p                    (sys_clk),
      .sys_clk_n                    (sys_clk),
      .sys_rst_n                    (sys_rst_n),

      // PCI-Express Interface
      .pci_exp_txn                  (ep_pci_exp_txn),
      .pci_exp_txp                  (ep_pci_exp_txp),
      .pci_exp_rxn                  (rp_pci_exp_txn),
      .pci_exp_rxp                  (rp_pci_exp_txp)
);

 //
  // PCI-Express Root Port FPGA Instantiation
  //
  xilinx_pcie_2_1_rport_7x
  #(
    .SIMULATION         (1),
    .EXT_PIPE_SIM       (EXT_PIPE_SIM),
    .REF_CLK_FREQ       (REF_CLK_FREQ),
    .ROM_FILE           ("./cgator_cfg_rom.data"),
    .ROM_SIZE           (32),
    .PL_FAST_TRAIN("TRUE")
  ) RP (
    // Reference clock
    .sys_clk_p       (sys_clk),
    .sys_clk_n       (~sys_clk),


   

 // PCI Express interface
    .RXN             (ep_pci_exp_txn),
    .RXP             (ep_pci_exp_txp),
    .TXN             (rp_pci_exp_txn),
    .TXP             (rp_pci_exp_txp),
    // System-level reset input
    .sys_rst_n     (sys_rst_n)
  );

  //
  // Generate system-level reference clock
  //
  sys_clk_gen
  #(
    .halfcycle (REF_CLK_HALF_CYCLE),
    .offset    (0)
  ) CLK_GEN (
    .sys_clk (sys_clk)
  );

  //
  // Generate system-level reset
  //
  initial begin
    $display("[%t] : System Reset Asserted...", $realtime);
    sys_rst_n = 1'b0;
    repeat (500) @(posedge sys_clk);
    $display("[%t] : System Reset De-asserted...", $realtime);
    sys_rst_n = 1'b1;
  end

  // Messages and simulation control
  initial begin
    #200;
    @(negedge RP.user_reset);
    $display("[%t] : TRN Reset deasserted", $realtime);
  end
  initial begin
    #200;
    @(posedge RP.user_lnk_up);
    $display("[%t] : Link up", $realtime);
  end
  initial begin
    #200;
    @(posedge RP.pl_sel_link_rate);
    $display("[%t] : Link trained up to 5.0 GT/s", $realtime);
  end
  initial begin
    #200;
    @(posedge RP.finished_config);
    $display("[%t] : Configuration succeeded", $realtime);
  end
  initial begin
    #200;
    @(posedge RP.failed_config);
    $display("[%t] : Configuration failed. TEST FAILED.", $realtime);
  end
  initial begin
    #200;
    @(posedge RP.pio_test_finished);
    $display("[%t] : PIO TEST PASSED", $realtime);
    $display("Test Completed Successfully");
    #100;
    $finish;
  end
  initial begin
    #200;
    @(posedge RP.pio_test_failed);
    $display("[%t] : PIO TEST FAILED", $realtime);
    #100;
    $finish;
  end
  initial begin
    #2500000;  // 200us timeout
    $display("[%t] : Simulation timeout. TEST FAILED", $realtime);
    #100;
    $finish;
  end



initial begin

  if ($test$plusargs ("dump_all")) begin

`ifdef NCV // Cadence TRN dump

    $recordsetup("design=board",
                 "compress",
                 "wrapsize=100M",
                 "version=1",
                 "run=1");
    $recordvars();

`elsif VCS //Synopsys VPD dump

    $vcdplusfile("board.vpd");
    $vcdpluson;
    $vcdplusglitchon;
    $vcdplusflush;

`else

    // Verilog VC dump
    $dumpfile("board.vcd");
    $dumpvars(0, board);

`endif

  end

end


endmodule // BOARD
