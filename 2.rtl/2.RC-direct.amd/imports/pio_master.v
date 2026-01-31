
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
// File       : pio_master.v
// Version    : 3.3
//
// Description : PIO Master Example Design - performs write/read test on
//               a PIO design instantiated in a connected Endpoint. This
//               block can address up to four separate memory apertures,
//               designated as BAR A, B, C, and D to differentiate them from
//               the BAR0-5 registers defined in the PCI Specification. The
//               block performs a write to each aperture, followed by a read
//               from each space. The results of the read are compared with the
//               data written to each aperture, and if all data matches the
//               block declares success. The write/read/verify process can be
//               restarted by pulsing the pio_test_restart input. The block is
//               designed to interface with the Configurator block - when the
//               user_lnk_up input is asserted (signifying that the link has
//               reached L0 and DL_UP) then this block instructs the
//               Configurator to configure the attached endpoint. When the
//               Configurator finished successfully, this block begins its
//               write/read/verify cycle.
//
// Hierarchy   : xilinx_pcie_2_1_rport_7x
//               |
//               |--cgator_wrapper
//               |  |
//               |  |--pcie_2_1_rport_7x (in source directory)
//               |  |  |
//               |  |  |--<various>
//               |  |
//               |  |--cgator
//               |     |
//               |     |--cgator_cpl_decoder
//               |     |--cgator_pkt_generator
//               |     |--cgator_tx_mux
//               |     |--cgator_controller
//               |        |--<cgator_cfg_rom.data> (specified by ROM_FILE)
//               |
//               |--pio_master
//                  |
//                  |--pio_master_controller
//                  |--pio_master_checker
//                  |--pio_master_pkt_generator
//-----------------------------------------------------------------------------

`timescale 1ns/1ns

(* DowngradeIPIdentifiedWarnings = "yes" *)
module pio_master
  #(
    parameter           TCQ = 1,

    // BAR A settings
    parameter [15:0]    REQUESTER_ID = 16'hFACE,
    parameter           BAR_A_ENABLED = 1,
    parameter           BAR_A_64BIT = 1,
    parameter           BAR_A_IO = 0,
    parameter [63:0]    BAR_A_BASE = 64'h1000_0000_0000_0000,
    parameter           BAR_A_SIZE = 1024, // Size in DW

    // BAR B settings
    parameter           BAR_B_ENABLED = 0,
    parameter           BAR_B_64BIT = 0,
    parameter           BAR_B_IO = 0,
    parameter [63:0]    BAR_B_BASE = 64'h0000_0000_2000_0000,
    parameter           BAR_B_SIZE = 1024, // Size in DW

    // BAR C settings
    parameter           BAR_C_ENABLED = 0,
    parameter           BAR_C_64BIT = 0,
    parameter           BAR_C_IO = 0,
    parameter [63:0]    BAR_C_BASE = 64'h0000_0000_4000_0000,
    parameter           BAR_C_SIZE = 1024, // Size in DW

    // BAR D settings
    parameter           BAR_D_ENABLED = 0,
    parameter           BAR_D_64BIT = 0,
    parameter           BAR_D_IO = 0,
    parameter [63:0]    BAR_D_BASE = 64'h0000_0000_8000_0000,
    parameter           BAR_D_SIZE = 1024, // Size in DW

    parameter C_DATA_WIDTH = 64,
    parameter KEEP_WIDTH = C_DATA_WIDTH / 8
  )
  (
    // globals
    input wire                user_clk,
    input wire                reset,
    input wire                user_lnk_up,

    // System information
    input wire                pio_test_restart,
    input wire                pio_test_long, // Unused for now
    output wire               pio_test_finished,
    output wire               pio_test_failed,

    // Control configuration process
    output wire               start_config,
    input wire                finished_config,
    input wire                failed_config,

    // Link Gen2
    input wire                link_gen2_capable,
    input wire                link_gen2,

    // AXIS interfaces
    // Tx
    input [5:0]               tx_buf_av,
    input                     tx_cfg_req,
    input                     tx_err_drop,
    output                    tx_cfg_gnt,
    input                     s_axis_tx_tready,
    output [C_DATA_WIDTH-1:0] s_axis_tx_tdata,
    output [KEEP_WIDTH-1:0]   s_axis_tx_tkeep,
    output [3:0]              s_axis_tx_tuser,
    output                    s_axis_tx_tlast,
    output                    s_axis_tx_tvalid,

    // RX
    input  [C_DATA_WIDTH-1:0] m_axis_rx_tdata,
    input  [KEEP_WIDTH-1:0]   m_axis_rx_tkeep,
    input                     m_axis_rx_tlast,
    input                     m_axis_rx_tvalid,
    input    [21:0]           m_axis_rx_tuser
  );

  // Controller <-> Packet Generator
  wire [2:0]    tx_type;
  wire [7:0]    tx_tag;
  wire [63:0]   tx_addr;
  wire [31:0]   tx_data;
  wire          tx_start;
  wire          tx_done;

  // Controller <-> Checker
  wire          rx_type;
  wire [7:0]    rx_tag;
  wire [31:0]   rx_data;
  wire          rx_good;
  wire          rx_bad;

  // Static output
  assign        tx_cfg_gnt = 1'b0;

  //
  // PIO Master Controller - controls the read/write/verify process
  //
  pio_master_controller #(
    .TCQ           (TCQ),
    .BAR_A_ENABLED (BAR_A_ENABLED),
    .BAR_A_64BIT   (BAR_A_64BIT),
    .BAR_A_IO      (BAR_A_IO),
    .BAR_A_BASE    (BAR_A_BASE),
    .BAR_A_SIZE    (BAR_A_SIZE),
    .BAR_B_ENABLED (BAR_B_ENABLED),
    .BAR_B_64BIT   (BAR_B_64BIT),
    .BAR_B_IO      (BAR_B_IO),
    .BAR_B_BASE    (BAR_B_BASE),
    .BAR_B_SIZE    (BAR_B_SIZE),
    .BAR_C_ENABLED (BAR_C_ENABLED),
    .BAR_C_64BIT   (BAR_C_64BIT),
    .BAR_C_IO      (BAR_C_IO),
    .BAR_C_BASE    (BAR_C_BASE),
    .BAR_C_SIZE    (BAR_C_SIZE),
    .BAR_D_ENABLED (BAR_D_ENABLED),
    .BAR_D_64BIT   (BAR_D_64BIT),
    .BAR_D_IO      (BAR_D_IO),
    .BAR_D_BASE    (BAR_D_BASE),
    .BAR_D_SIZE    (BAR_D_SIZE)
  ) pio_master_controller_i (
    // System inputs
    .user_clk           (user_clk),
    .reset              (reset),
    .user_lnk_up        (user_lnk_up),

    // Board-level control/status
    .pio_test_restart   (pio_test_restart),
    .pio_test_long      (pio_test_long),
    .pio_test_finished  (pio_test_finished),
    .pio_test_failed    (pio_test_failed),

    // Control of Configurator
    .start_config       (start_config),
    .finished_config    (finished_config),
    .failed_config      (failed_config),

    .link_gen2_capable  (link_gen2_capable),
    .link_gen2          (link_gen2),

    // Packet generator interface
    .tx_type            (tx_type),
    .tx_tag             (tx_tag),
    .tx_addr            (tx_addr),
    .tx_data            (tx_data),
    .tx_start           (tx_start),
    .tx_done            (tx_done),

    // Checker interface
    .rx_type            (rx_type),
    .rx_tag             (rx_tag),
    .rx_data            (rx_data),
    .rx_good            (rx_good),
    .rx_bad             (rx_bad)
  );

  //
  // PIO Master Packet Generator - Generates downstream packets as directed by
  // the PIO Master Controller module
  //
  pio_master_pkt_generator #(
    .TCQ            (TCQ),
    .REQUESTER_ID   (REQUESTER_ID),
    .C_DATA_WIDTH   (C_DATA_WIDTH),
    .KEEP_WIDTH     (KEEP_WIDTH)
  ) pio_master_pkt_generator_i (
    // globals
    .user_clk               (user_clk),
    .reset                  (reset),

    // Tx AXIS interface
    .s_axis_tx_tready       (s_axis_tx_tready ),
    .s_axis_tx_tdata        (s_axis_tx_tdata ),
    .s_axis_tx_tkeep        (s_axis_tx_tkeep ),
    .s_axis_tx_tuser        (s_axis_tx_tuser ),
    .s_axis_tx_tlast        (s_axis_tx_tlast ),
    .s_axis_tx_tvalid       (s_axis_tx_tvalid ),


    // Controller interface
    .tx_type                (tx_type),
    .tx_tag                 (tx_tag),
    .tx_addr                (tx_addr),
    .tx_data                (tx_data),
    .tx_start               (tx_start),
    .tx_done                (tx_done)
  );

  //
  // PIO Master Checker - Checks that incoming Completion TLPs match the
  // parameters imposed by the Controller
  //
  pio_master_checker #(    
    .TCQ(TCQ),
    .REQUESTER_ID   (REQUESTER_ID),
    .C_DATA_WIDTH   (C_DATA_WIDTH),
    .KEEP_WIDTH     (KEEP_WIDTH)
  ) pio_master_checker_i (
    // globals
    .user_clk               (user_clk),
    .reset                  (reset),

    //AXIS interface
    .m_axis_rx_tdata        (m_axis_rx_tdata ),
    .m_axis_rx_tkeep        (m_axis_rx_tkeep ),
    .m_axis_rx_tlast        (m_axis_rx_tlast ),
    .m_axis_rx_tvalid       (m_axis_rx_tvalid ),
    .m_axis_rx_tuser        (m_axis_rx_tuser ),

    // Controller interface
    .rx_type                (rx_type),
    .rx_tag                 (rx_tag),
    .rx_data                (rx_data),
    .rx_good                (rx_good),
    .rx_bad                 (rx_bad)
  );

endmodule // pio_master

