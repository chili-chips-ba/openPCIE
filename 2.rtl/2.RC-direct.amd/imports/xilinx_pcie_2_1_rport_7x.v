
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
// File       : xilinx_pcie_2_1_rport_7x.v
// Version    : 3.3
// Description : Configurator Controller module - directs configuration of
//               Endpoint connected to the local Root Port. Configuration
//               steps are read from the file specified by the ROM_FILE
//               parameter. This module directs the Packet Generator module to
//               create downstream TLPs and receives decoded Completion TLP
//               information from the Completion Decoder module.
//
// Hierarchy   : xilinx_pcie_2_1_rport_7x
//               |
//               |--cgator_wrapper
//               |  |
//               |  |--pcie_2_1_rport_7x (Core Top Level, in source directory)
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
module xilinx_pcie_2_1_rport_7x
  #(
    parameter TCQ                = 1,
    parameter SIMULATION         = 0,
    parameter PL_FAST_TRAIN      = "FALSE",
    parameter EXT_PIPE_SIM       = "FALSE",  // This Parameter has effect on selecting Enable External PIPE Interface in GUI.
    parameter ROM_FILE           = "cgator_cfg_rom.data",
    parameter ROM_SIZE           = 32,
    parameter REF_CLK_FREQ       = 0,        // 0 - 100 MHz, 1 - 125 MHz, 2 - 250 MHz
    parameter USER_CLK_FREQ      = 1,
    parameter C_DATA_WIDTH       = 64,
    parameter KEEP_WIDTH         = C_DATA_WIDTH / 8
  ) (
    // Board-level reference clock
    input wire          sys_clk_p,
    input wire          sys_clk_n,

    // PCI Express interface
    input wire  [0:0]   RXN,
    input wire  [0:0]   RXP,
    output wire [0:0]   TXN,
    output wire [0:0]   TXP,

    // System-level reset input
    input wire  sys_rst_n,
    
    output wire led_link_up,
    
    output wire clk_req
  );

  //-------------------------------------------------------
  // 0. Configurator Control/Status Interface
  //-------------------------------------------------------
  
  

  wire                      start_config;    // in
  wire                      finished_config; // out
  wire                      failed_config;   // out

  //-------------------------------------------------------
  // 2. Transaction (AXIS) Interface
  //-------------------------------------------------------

  // Common
  wire   user_clk;           // out
  wire   user_reset;         // out
  wire   user_lnk_up;        // out

  // Tx
  wire [5:0]                tx_buf_av;
  wire                      tx_cfg_req;
  wire                      tx_err_drop;
  wire                      s_axis_tx_tready;
  wire [3:0]                s_axis_tx_tuser;
  wire [C_DATA_WIDTH-1:0]   s_axis_tx_tdata;
  wire [KEEP_WIDTH-1:0]     s_axis_tx_tkeep;
  wire                      s_axis_tx_tlast;
  wire                      s_axis_tx_tvalid;

  // Rx
  wire [C_DATA_WIDTH-1:0]   m_axis_rx_tdata;
  wire [KEEP_WIDTH-1:0]     m_axis_rx_tkeep;
  wire                      m_axis_rx_tlast;
  wire                      m_axis_rx_tvalid;
  wire [21:0]               m_axis_rx_tuser;

  wire                      tx_cfg_gnt;
  wire                      cfg_trn_pending;              // in
  wire                      cfg_pm_send_pme_to;           // in
  wire  [7:0]               cfg_ds_bus_number;            // in
  wire  [4:0]               cfg_ds_device_number;         // in
  wire [63:0]               cfg_dsn;                      // in
  // Flow Control
  wire  [2:0]               fc_sel = 3'b0;                // in

  //-------------------------------------------------------
  // 3. Configuration (CFG) Interface
  //-------------------------------------------------------
  wire [31:0]               cfg_di              = 32'd0;  // in
  wire  [3:0]               cfg_byte_en         = 4'h0;   // in
  wire  [9:0]               cfg_dwaddr          = 10'd0;  // in
  wire                      cfg_wr_en           = 1'b0;   // in
  wire                      cfg_wr_rw1c_as_rw   = 1'b0;   // in
  wire                      cfg_rd_en           = 1'b0;   // in

  wire                      cfg_err_cor;                  // in
  wire                      cfg_err_ur;                   // in
  wire                      cfg_err_ecrc;                 // in
  wire                      cfg_err_cpl_timeout;          // in
  wire                      cfg_err_cpl_abort;            // in
  wire                      cfg_err_cpl_unexpect;         // in
  wire                      cfg_err_posted;               // in
  wire                      cfg_err_locked;               // in
  wire [47:0]               cfg_err_tlp_cpl_header;       // in

  wire                      cfg_interrupt;                // in
  wire                      cfg_interrupt_assert;         // in
  wire [7:0]                cfg_interrupt_di;             // in


  //-------------------------------------------------------
  // 4. Physical Layer Control and Status (PL) Interface
  //-------------------------------------------------------
  wire                      pl_link_gen2_capable;            // out
  wire                      pl_link_partner_gen2_supported;  // out
  wire [5:0]                pl_ltssm_state;                  // out
  wire                      pl_sel_link_rate;                // out
  wire                      pl_directed_link_auton;          // in
  wire [1:0]                pl_directed_link_change;         // in
  wire                      pl_directed_link_speed;          // in
  wire [1:0]                pl_directed_link_width;          // in
  wire                      pl_upstream_prefer_deemph;       // in
  wire                      pl_transmit_hot_rst;             // in
  //-------------------------------------------------------
  // Local signals
  //-------------------------------------------------------

  // Button sampling
  reg                       pio_test_restart    = 1'b0;

  wire                      error_led_reg;

  // Local reset
  wire                      rp_reset_n;

  // PIO I/Os
  wire                      pio_test_finished;
  wire                      pio_test_failed;
  reg                       link_gen2_capable_i0;
  reg                       link_gen2_capable_i1;
  reg                       link_gen2_capable_i2;
  reg                       link_gen2_i0;
  reg                       link_gen2_i1;
  reg                       link_gen2_i2;

  wire [3:0]                target_link_speed = 4'h2;       // LINK_CTRL2_TARGET_LINK_SPEED

  wire                      sys_clk;

  IBUFDS_GTE2 refclk_ibuf (.O(sys_clk), .ODIV2(), .I(sys_clk_p), .CEB(1'b0), .IB(sys_clk_n));
 


  // Instantiate the Configurator wrapper, which includes the configurator
  // block and the Integrated Root Port Block for PCI Express wrapper
  cgator_wrapper #(
    .TCQ                            (TCQ),
    .EXTRA_PIPELINE                 (0),
    .ROM_FILE                       (ROM_FILE),
    .ROM_SIZE                       (ROM_SIZE),
    .PL_FAST_TRAIN                  (PL_FAST_TRAIN),
    .C_DATA_WIDTH                   (C_DATA_WIDTH),
    .KEEP_WIDTH                     (KEEP_WIDTH)
  ) cgator_wrapper_i
  (
    //-------------------------------------------------------
    // Configurator I/Os
    //-------------------------------------------------------
    .start_config                   (start_config),
    .finished_config                (finished_config),
    .failed_config                  (failed_config),

    //-------------------------------------------------------
    // PCI Express (pci_exp) Interface
    //-------------------------------------------------------
    // Tx
    .pci_exp_txp                    (TXP[0:0]),
    .pci_exp_txn                    (TXN[0:0]),

    // Rx
    .pci_exp_rxp                    (RXP[0:0]),
    .pci_exp_rxn                    (RXN[0:0]),

    //-------------------------------------------------------
    // Transaction (AXIS) Interface
    //-------------------------------------------------------
    // Common
    .user_clk_out                   (user_clk),
    .user_reset_out                 (user_reset),
    .user_lnk_up                    (user_lnk_up),

    // Tx
    .s_axis_tx_tready               ( s_axis_tx_tready ),
    .s_axis_tx_tdata                ( s_axis_tx_tdata ),
    .s_axis_tx_tkeep                ( s_axis_tx_tkeep ),
    .s_axis_tx_tuser                ( s_axis_tx_tuser ),
    .s_axis_tx_tlast                ( s_axis_tx_tlast ),
    .s_axis_tx_tvalid               ( s_axis_tx_tvalid ),
  
    // Rx
    .m_axis_rx_tdata                ( m_axis_rx_tdata ),
    .m_axis_rx_tkeep                ( m_axis_rx_tkeep ),
    .m_axis_rx_tlast                ( m_axis_rx_tlast ),
    .m_axis_rx_tvalid               ( m_axis_rx_tvalid ),
    .m_axis_rx_tuser                ( m_axis_rx_tuser ),

    .tx_cfg_gnt                     ( tx_cfg_gnt ),
    .cfg_trn_pending                ( cfg_trn_pending),
    .cfg_pm_send_pme_to             ( cfg_pm_send_pme_to),
    .cfg_ds_bus_number              ( cfg_ds_bus_number),
    .cfg_ds_device_number           ( cfg_ds_device_number),
    .cfg_dsn                        ( cfg_dsn),
    .tx_buf_av                      ( tx_buf_av ),
    .tx_cfg_req                     ( tx_cfg_req ),
    .tx_err_drop                    ( tx_err_drop ),
    .cfg_dcommand                   ( ),
    .cfg_status                     ( ),
    .cfg_command                    ( ),
    .cfg_dstatus                    ( ),
    .cfg_lstatus                    ( ),
    .cfg_lcommand                   ( ),
    .cfg_dcommand2                  ( ),
    .cfg_pcie_link_state            ( ),
    .cfg_pmcsr_pme_en               ( ),
    .cfg_pmcsr_pme_status           ( ),
    .cfg_pmcsr_powerstate           ( ),
    // Flow Control
    .fc_cpld                        ( ),
    .fc_cplh                        ( ),
    .fc_npd                         ( ),
    .fc_nph                         ( ),
    .fc_pd                          ( ),
    .fc_ph                          ( ),
    .fc_sel                         (fc_sel),
    .cfg_do                         ( ),
    .cfg_rd_wr_done                 ( ),
    .cfg_di                         (cfg_di),
    .cfg_byte_en                    (cfg_byte_en),
    .cfg_dwaddr                     (cfg_dwaddr),
    .cfg_wr_en                      (cfg_wr_en),
    .cfg_wr_rw1c_as_rw              (cfg_wr_rw1c_as_rw),
    .cfg_rd_en                      (cfg_rd_en),
    .cfg_err_cor                    (cfg_err_cor),
    .cfg_err_ur                     (cfg_err_ur),
    .cfg_err_ecrc                   (cfg_err_ecrc),
    .cfg_err_cpl_timeout            (cfg_err_cpl_timeout),
    .cfg_err_cpl_abort              (cfg_err_cpl_abort),
    .cfg_err_cpl_unexpect           (cfg_err_cpl_unexpect),
    .cfg_err_posted                 (cfg_err_posted),
    .cfg_err_locked                 (cfg_err_locked),
    .cfg_err_tlp_cpl_header         (cfg_err_tlp_cpl_header),
    .cfg_err_cpl_rdy                ( ),
    .cfg_interrupt                  (cfg_interrupt),
    .cfg_interrupt_rdy              ( ),
    .cfg_interrupt_assert           (cfg_interrupt_assert),
    .cfg_interrupt_di               (cfg_interrupt_di),
    .cfg_interrupt_do               ( ),
    .cfg_interrupt_mmenable         ( ),
    .cfg_interrupt_msienable        ( ),
    .cfg_interrupt_msixenable       ( ),
    .cfg_interrupt_msixfm           ( ),
    .cfg_msg_received               ( ),
    .cfg_msg_data                   ( ),
    .cfg_msg_received_err_cor       ( ),
    .cfg_msg_received_err_non_fatal ( ),
    .cfg_msg_received_err_fatal     ( ),
    .cfg_msg_received_pme_to_ack    ( ),
    .cfg_msg_received_assert_inta   ( ),
    .cfg_msg_received_assert_intb   ( ),
    .cfg_msg_received_assert_intc   ( ),
    .cfg_msg_received_assert_intd   ( ),
    .cfg_msg_received_deassert_inta ( ),
    .cfg_msg_received_deassert_intb ( ),
    .cfg_msg_received_deassert_intc ( ),
    .cfg_msg_received_deassert_intd ( ),
    //-------------------------------------------------------
    // Physical Layer Control and Status (PL) Interface
    //-------------------------------------------------------
    .pl_initial_link_width          (),
    .pl_lane_reversal_mode          (),
    .pl_link_gen2_capable           (pl_link_gen2_capable),
    .pl_link_partner_gen2_supported (pl_link_partner_gen2_supported),
    .pl_link_upcfg_capable          (),
    .pl_ltssm_state                 (pl_ltssm_state),
    .pl_sel_link_rate               (pl_sel_link_rate),
    .pl_sel_link_width              (),
    .pl_directed_change_done        (),
    .pl_directed_link_auton         (pl_directed_link_auton),
    .pl_directed_link_change        (pl_directed_link_change),
    .pl_directed_link_speed         (pl_directed_link_speed),
    .pl_directed_link_width         (pl_directed_link_width),
    .pl_upstream_prefer_deemph      (pl_upstream_prefer_deemph),
    .pl_transmit_hot_rst            (pl_transmit_hot_rst),
    //----------------------------------------------------------------------------------------------------------------//
    // PCIe DRP (PCIe DRP) Interface                                                                                  //
    //----------------------------------------------------------------------------------------------------------------//
    .pcie_drp_clk                               ( 1'b1 ),
    .pcie_drp_en                                ( 1'b0 ),
    .pcie_drp_we                                ( 1'b0 ),
    .pcie_drp_addr                              ( 9'h0 ),
    .pcie_drp_di                                ( 16'h0 ),
    .pcie_drp_rdy                               ( ),
    .pcie_drp_do                                ( ),

    //-------------------------------------------------------
    // System  (SYS) Interface
    //-------------------------------------------------------
    .pipe_mmcm_rst_n                ( 1'b1 ),        // Async      | Async
    .sys_clk                        (sys_clk),
    .sys_rst_n                      (rp_reset_n)
  );

  //
  // Instantiate PIO Master example design
  // BARs in Endpoint are set by the Configurator. Settings are
  // mirrored here
  //
  pio_master #(
    .TCQ            (TCQ),

    // BAR A: 2 MB, 64-bit Memory BAR using BAR0-1
    .BAR_A_ENABLED  (1),
    .BAR_A_64BIT    (0),
    .BAR_A_IO       (0),
    .BAR_A_BASE     (64'h0000_0000_8000_0000),
    .BAR_A_SIZE     (2*1024*1024/4),

    // BAR B: 512 kB, 32-bit Memory BAR using BAR2
    .BAR_B_ENABLED  (0),
    .BAR_B_64BIT    (0),
    .BAR_B_IO       (0),
    .BAR_B_BASE     (64'h0000_0000_2000_0000),
    .BAR_B_SIZE     (512*1024/4),

    // BAR B: 32 MB, 32-bit Memory BAR using Expansion ROM BAR
    .BAR_C_ENABLED  (0),
    .BAR_C_64BIT    (0),
    .BAR_C_IO       (0),
    .BAR_C_BASE     (64'h0000_0000_8000_0000),
    .BAR_C_SIZE     (32*1024*1024/4),

    // BAR D: Unused
    .BAR_D_ENABLED  (0),
    .BAR_D_64BIT    (0),
    .BAR_D_IO       (0),
    .BAR_D_BASE     (64'h0000_0000_0000_0000),
    .BAR_D_SIZE     (0),

    .C_DATA_WIDTH   (C_DATA_WIDTH),
    .KEEP_WIDTH     (KEEP_WIDTH)
  ) pio_master_i
  (
    // System inputs
    .user_clk               (user_clk),
    .reset                  (user_reset),
    .user_lnk_up            (user_lnk_up),

    // Board-level control/status
    .pio_test_restart       (pio_test_restart),
    .pio_test_long          ( 1'b0 ),
    .pio_test_finished      (pio_test_finished),
    .pio_test_failed        (pio_test_failed),

    // Control of Configurator
    .start_config           (start_config),
    .finished_config        (finished_config),
    .failed_config          (failed_config),

    .link_gen2_capable      (link_gen2_capable_i2),
    .link_gen2              (link_gen2_i2),

    // Transaction interfaces
    //TX
    .s_axis_tx_tready       (s_axis_tx_tready ),
    .s_axis_tx_tdata        (s_axis_tx_tdata ),
    .s_axis_tx_tkeep        (s_axis_tx_tkeep ),
    .s_axis_tx_tuser        (s_axis_tx_tuser ),
    .s_axis_tx_tlast        (s_axis_tx_tlast ),
    .s_axis_tx_tvalid       (s_axis_tx_tvalid ),
    .tx_cfg_gnt             (tx_cfg_gnt ),
    .tx_cfg_req             (tx_cfg_req ),
    .tx_buf_av              (tx_buf_av ),
    .tx_err_drop            (tx_err_drop ),

    // Rx
    .m_axis_rx_tdata        (m_axis_rx_tdata ),
    .m_axis_rx_tkeep        (m_axis_rx_tkeep ),
    .m_axis_rx_tlast        (m_axis_rx_tlast ),
    .m_axis_rx_tvalid       (m_axis_rx_tvalid ),
    .m_axis_rx_tuser        (m_axis_rx_tuser )
  );
  //-----------------------------------------------------------------------------------------------------------------------------//
  always @(posedge user_clk) begin
    if (user_reset) begin
        link_gen2_capable_i0   <= #TCQ 1'b0;
        link_gen2_i0           <= #TCQ 1'b0;
        link_gen2_capable_i1   <= #TCQ 1'b0;
        link_gen2_i1           <= #TCQ 1'b0;
        link_gen2_capable_i2   <= #TCQ 1'b0;
        link_gen2_i2           <= #TCQ 1'b0;
    end else begin
      if (pl_sel_link_rate && (pl_ltssm_state == 5'h16))
          link_gen2_i0           <= #TCQ 1'b1;
        link_gen2_capable_i0   <= #TCQ (pl_link_gen2_capable && pl_link_partner_gen2_supported && (target_link_speed == 4'h2));
        link_gen2_capable_i1   <= #TCQ link_gen2_capable_i0;
        link_gen2_i1           <= #TCQ link_gen2_i0;
        link_gen2_capable_i2   <= #TCQ link_gen2_capable_i1;
        link_gen2_i2           <= #TCQ link_gen2_i1;
    end
  end
  
  //-----------------------------------------------------------------------------------------------------------------------------//
  //
  // Static assignments to core I/Os
  //

  // Configuration signals which are unused
  assign cfg_err_cor              = 1'b0;
  assign cfg_err_ur               = 1'b0;
  assign cfg_err_ecrc             = 1'b0;
  assign cfg_err_cpl_timeout      = 1'b0;
  assign cfg_err_cpl_abort        = 1'b0;
  assign cfg_err_cpl_unexpect     = 1'b0;
  assign cfg_err_posted           = 1'b0;
  assign cfg_err_locked           = 1'b0;
  assign cfg_err_tlp_cpl_header   = 48'd0;

  assign cfg_interrupt            = 1'b0;
  assign cfg_interrupt_assert     = 1'b0;
  assign cfg_interrupt_di          = 8'd0;

  assign cfg_trn_pending          = 1'b0;
  assign cfg_pm_send_pme_to       = 1'b0;
  assign cfg_dsn                  = 64'd0;
  assign cfg_ds_bus_number        = 8'd0;
  assign cfg_ds_device_number     = 5'd0;

  // Physical Layer signals which are unused
  assign pl_directed_link_auton     = 1'b0;
  assign pl_directed_link_change    = 2'd0;
  assign pl_directed_link_speed     = 1'b0;
  assign pl_directed_link_width     = 2'b0;
  assign pl_upstream_prefer_deemph  = 1'b0;
  assign pl_transmit_hot_rst        = 1'b0;

  // Create reset to Root Port core
  // This is a combination of the board-level reset input and the
  // link-retrain button
 
  assign rp_reset_n = sys_rst_n;
  
  assign led_link_up = user_lnk_up;
  
  assign clk_req = 1'b0;

endmodule // xilinx_pcie_2_1_rport_7x
