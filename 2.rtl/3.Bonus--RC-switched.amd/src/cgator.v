
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
// File       : cgator.v
// Version    : 3.3
//
// Description : Configurator example design - configures a PCI Express
//               Endpoint via the Root Port Block for PCI Express. Endpoint is
//               configured using a pre-determined set of configuration
//               and message transactions. Transactions are specified in the
//               file indicated by the ROM_FILE parameter
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
module cgator
  #(   
    parameter           TCQ                   = 1,
    parameter           EXTRA_PIPELINE        = 1,
    parameter           ROM_FILE              = "cgator_cfg_rom.data",
    parameter           ROM_SIZE              = 46,
    parameter [15:0]    REQUESTER_ID          = 16'h10EE,
    parameter           C_DATA_WIDTH          = 64,
    parameter           KEEP_WIDTH            = C_DATA_WIDTH / 8
  ) (
    // globals
    input wire                          user_clk,
    input wire                          reset,

    // User interface for configuration
    input wire                          start_config,
    output wire                         finished_config,
    output wire                         failed_config,

    // Rport AXIS interfaces
    input [5:0]                         rport_tx_buf_av,
    input                               rport_tx_cfg_req,
    input                               rport_tx_err_drop,
    output                              rport_tx_cfg_gnt,
    input                               rport_s_axis_tx_tready,
    output [C_DATA_WIDTH-1:0]           rport_s_axis_tx_tdata,
    output [KEEP_WIDTH-1:0]             rport_s_axis_tx_tkeep,
    output [3:0]                        rport_s_axis_tx_tuser,
    output                              rport_s_axis_tx_tlast,
    output                              rport_s_axis_tx_tvalid,

    input  [C_DATA_WIDTH-1:0]           rport_m_axis_rx_tdata,
    input  [KEEP_WIDTH-1:0]             rport_m_axis_rx_tkeep,
    input                               rport_m_axis_rx_tlast,
    input                               rport_m_axis_rx_tvalid,
    output                              rport_m_axis_rx_tready,
    input    [21:0]                     rport_m_axis_rx_tuser,
    output                              rport_rx_np_ok,

    // User AXIS interfaces
    output  [5:0]                       usr_tx_buf_av,
    output                              usr_tx_err_drop,
    output                              usr_tx_cfg_req,
    output                              usr_s_axis_tx_tready,
    input  [C_DATA_WIDTH-1:0]           usr_s_axis_tx_tdata,
    input  [KEEP_WIDTH-1:0]             usr_s_axis_tx_tkeep,
    input  [3:0]                        usr_s_axis_tx_tuser,
    input                               usr_s_axis_tx_tlast,
    input                               usr_s_axis_tx_tvalid,
    input                               usr_tx_cfg_gnt,

    output  [C_DATA_WIDTH-1:0]          usr_m_axis_rx_tdata,
    output  [KEEP_WIDTH-1:0]            usr_m_axis_rx_tkeep,
    output                              usr_m_axis_rx_tlast,
    output                              usr_m_axis_rx_tvalid,
    output    [21:0]                    usr_m_axis_rx_tuser,

    // Rport CFG interface
    input  wire [31:0]                  rport_cfg_do,
    input  wire                         rport_cfg_rd_wr_done,
    output wire [31:0]                  rport_cfg_di,
    output wire  [3:0]                  rport_cfg_byte_en,
    output wire  [9:0]                  rport_cfg_dwaddr,
    output wire                         rport_cfg_wr_en,
    output wire                         rport_cfg_wr_rw1c_as_rw,
    output wire                         rport_cfg_rd_en,

    // User CFG interface
    output wire [31:0]                  usr_cfg_do,
    output wire                         usr_cfg_rd_wr_done,
    input  wire [31:0]                  usr_cfg_di,
    input  wire  [3:0]                  usr_cfg_byte_en,
    input  wire  [9:0]                  usr_cfg_dwaddr,
    input  wire                         usr_cfg_wr_en,
    input  wire                         usr_cfg_wr_rw1c_as_rw,
    input  wire                         usr_cfg_rd_en,

    // Rport PL interface
    input  wire                         rport_pl_link_gen2_capable
  );

  wire [7:0]    pkt_bus_num;
  wire [4:0]    pkt_dev_num;

  // Controller <-> All modules
  wire          config_mode;
  wire          config_mode_active;


  wire                    pg_s_axis_tx_tready;
  wire [C_DATA_WIDTH-1:0] pg_s_axis_tx_tdata;
  wire [KEEP_WIDTH-1:0]   pg_s_axis_tx_tkeep;
  wire [3:0]              pg_s_axis_tx_tuser;
  wire                    pg_s_axis_tx_tlast;
  wire                    pg_s_axis_tx_tvalid;

  assign rport_cfg_di             = 32'b0;
  assign rport_cfg_byte_en        =  4'b0;
  assign rport_cfg_dwaddr         = 10'b0;
  assign rport_cfg_wr_en          =  1'b0;
  assign rport_cfg_wr_rw1c_as_rw  =  1'b0;
  assign rport_cfg_rd_en          =  1'b0;
  assign usr_cfg_do               = 32'b0;
  assign usr_cfg_rd_wr_done       =  1'b0;


  // Controller <-> Packet Generator
  wire [1:0]    pkt_type;
  wire [1:0]    pkt_func_num;
  wire [9:0]    pkt_reg_num;
  wire [3:0]    pkt_1dw_be;
  wire [2:0]    pkt_msg_routing;
  wire [7:0]    pkt_msg_code;
  wire [31:0]   pkt_data;
  wire          pkt_start;
  wire          pkt_done;

  // Completion Decoder -> Controller
  wire          cpl_sc;
  wire          cpl_ur;
  wire          cpl_crs;
  wire          cpl_ca;
  wire [31:0]   cpl_data;
  wire          cpl_mismatch;

  // These signals are not modified internally, so are just passed through
  // this module to user logic
  assign    rport_tx_cfg_gnt = usr_tx_cfg_gnt;
  assign    usr_tx_cfg_req   = rport_tx_cfg_req;
  assign    usr_tx_buf_av    = rport_tx_buf_av;
  assign    usr_tx_err_drop  = rport_tx_err_drop;

  //
  // Configurator Controller module - controls the Endpoint configuration
  // process
  //
  cgator_controller #(
    .TCQ                  (TCQ),
    .ROM_FILE             (ROM_FILE),
    .ROM_SIZE             (ROM_SIZE)
  ) cgator_controller_i (
    // globals
    .user_clk           (user_clk),
    .reset              (reset),

    // User interface
    .start_config       (start_config),
    .finished_config    (finished_config),
    .failed_config      (failed_config),

    // Packet generator interface
    .pkt_bus_num        (pkt_bus_num), 
    .pkt_dev_num        (pkt_dev_num), 
    
    .pkt_type           (pkt_type),
    .pkt_func_num       (pkt_func_num),
    .pkt_reg_num        (pkt_reg_num),
    .pkt_1dw_be         (pkt_1dw_be),
    .pkt_msg_routing    (pkt_msg_routing),
    .pkt_msg_code       (pkt_msg_code),
    .pkt_data           (pkt_data),
    .pkt_start          (pkt_start),
    .pkt_done           (pkt_done),

    // Tx mux and completion decoder interface
    .config_mode        (config_mode),
    .config_mode_active (config_mode_active),
    .cpl_sc             (cpl_sc),
    .cpl_ur             (cpl_ur),
    .cpl_crs            (cpl_crs),
    .cpl_ca             (cpl_ca),
    .cpl_data           (cpl_data),
    .cpl_mismatch       (cpl_mismatch)
  );

  //
  // Configurator Packet Generator module - generates downstream TLPs as
  // directed by the Controller module
  //
  cgator_pkt_generator #(
    .TCQ          (TCQ),
    .REQUESTER_ID (REQUESTER_ID),
    .C_DATA_WIDTH (C_DATA_WIDTH),
    .KEEP_WIDTH   (KEEP_WIDTH)
  ) cgator_pkt_generator_i (
    // globals
    .user_clk             (user_clk),
    .reset                (reset),

    .pg_s_axis_tx_tready  (pg_s_axis_tx_tready),
    .pg_s_axis_tx_tdata   (pg_s_axis_tx_tdata),
    .pg_s_axis_tx_tkeep   (pg_s_axis_tx_tkeep),
    .pg_s_axis_tx_tuser   (pg_s_axis_tx_tuser),
    .pg_s_axis_tx_tlast   (pg_s_axis_tx_tlast),
    .pg_s_axis_tx_tvalid  (pg_s_axis_tx_tvalid),


    // Controller interface
    .pkt_bus_num          (pkt_bus_num), 
    .pkt_dev_num          (pkt_dev_num), 
    
    .pkt_type             (pkt_type),
    .pkt_func_num         (pkt_func_num),
    .pkt_reg_num          (pkt_reg_num),
    .pkt_1dw_be           (pkt_1dw_be),
    .pkt_msg_routing      (pkt_msg_routing),
    .pkt_msg_code         (pkt_msg_code),
    .pkt_data             (pkt_data),
    .pkt_start            (pkt_start),
    .pkt_done             (pkt_done)
  );

  //
  // Configurator Tx Mux module - multiplexes between internally-generated
  // TLP data and user data
  //
  cgator_tx_mux #(
    .TCQ                  (TCQ),
    .C_DATA_WIDTH         (C_DATA_WIDTH),
    .KEEP_WIDTH           (KEEP_WIDTH)
  ) cgator_tx_mux_i (
    // globals
    .user_clk                   (user_clk),
    .reset                      (reset),

    // User Tx AXIS interface

    .usr_s_axis_tx_tready       (usr_s_axis_tx_tready),
    .usr_s_axis_tx_tdata        (usr_s_axis_tx_tdata),
    .usr_s_axis_tx_tkeep        (usr_s_axis_tx_tkeep),
    .usr_s_axis_tx_tuser        (usr_s_axis_tx_tuser),
    .usr_s_axis_tx_tlast        (usr_s_axis_tx_tlast),
    .usr_s_axis_tx_tvalid       (usr_s_axis_tx_tvalid),

    // Packet Generator Tx interface
    .pg_s_axis_tx_tready        (pg_s_axis_tx_tready),
    .pg_s_axis_tx_tdata         (pg_s_axis_tx_tdata),
    .pg_s_axis_tx_tkeep         (pg_s_axis_tx_tkeep),
    .pg_s_axis_tx_tuser         (pg_s_axis_tx_tuser),
    .pg_s_axis_tx_tlast         (pg_s_axis_tx_tlast),
    .pg_s_axis_tx_tvalid        (pg_s_axis_tx_tvalid),

    // Root Port Wrapper Tx interface
    .rport_tx_cfg_req           (rport_tx_cfg_req),
    .rport_tx_cfg_gnt           (rport_tx_cfg_gnt),
    .rport_s_axis_tx_tready     (rport_s_axis_tx_tready),
    .rport_s_axis_tx_tdata      (rport_s_axis_tx_tdata),
    .rport_s_axis_tx_tkeep      (rport_s_axis_tx_tkeep),
    .rport_s_axis_tx_tuser      (rport_s_axis_tx_tuser),
    .rport_s_axis_tx_tlast      (rport_s_axis_tx_tlast),
    .rport_s_axis_tx_tvalid     (rport_s_axis_tx_tvalid),

    // Root port status interface
    .rport_tx_buf_av            (rport_tx_buf_av),

    // Controller interface
    .config_mode                (config_mode),
    .config_mode_active         (config_mode_active)
  );

  //
  // Configurator Completion Decoder module - receives upstream TLPs and
  // decodes completion status
  //
  cgator_cpl_decoder #(
    .TCQ            (TCQ),
    .EXTRA_PIPELINE (EXTRA_PIPELINE),
    .REQUESTER_ID   (REQUESTER_ID),
    .C_DATA_WIDTH   (C_DATA_WIDTH),
    .KEEP_WIDTH     (KEEP_WIDTH)
  ) cgator_cpl_decoder_i (
    // globals
    .user_clk                 (user_clk),
    .reset                    (reset),

    // Root Port Wrapper Rx interface
    .rport_m_axis_rx_tdata    (rport_m_axis_rx_tdata),
    .rport_m_axis_rx_tkeep    (rport_m_axis_rx_tkeep),
    .rport_m_axis_rx_tlast    (rport_m_axis_rx_tlast),
    .rport_m_axis_rx_tvalid   (rport_m_axis_rx_tvalid),
    .rport_m_axis_rx_tready   (rport_m_axis_rx_tready),
    .rport_m_axis_rx_tuser    (rport_m_axis_rx_tuser),
    .rport_rx_np_ok           (rport_rx_np_ok),
    // User Rx AXIS interface
    .usr_m_axis_rx_tdata      (usr_m_axis_rx_tdata),
    .usr_m_axis_rx_tkeep      (usr_m_axis_rx_tkeep),
    .usr_m_axis_rx_tlast      (usr_m_axis_rx_tlast),
    .usr_m_axis_rx_tvalid     (usr_m_axis_rx_tvalid),
    .usr_m_axis_rx_tuser      (usr_m_axis_rx_tuser),

    // Controller interface
    .config_mode              (config_mode),
    .cpl_sc                   (cpl_sc),
    .cpl_ur                   (cpl_ur),
    .cpl_crs                  (cpl_crs),
    .cpl_ca                   (cpl_ca),
    .cpl_data                 (cpl_data),
    .cpl_mismatch             (cpl_mismatch)
  );

endmodule // cgator

