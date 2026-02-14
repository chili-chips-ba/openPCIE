
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
// File       : cgator_wrapper.v
// Version    : 3.3
//
// Description : Wrapper file for Configurator example design. Instantiates
//               Configurator example and 7-Series Root Port Block for PCI
//               Express
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
//
//-----------------------------------------------------------------------------
// Parameters for Configurator
//   TCQ                : clock-to-out delay modeled by all registers in design
//   EXTRA_PIPELINE     : whether to pipeline the received data for timing
//   ROM_FILE           : filename containing configuration steps to perform
//   ROM_SIZE           : number of lines in ROM_FILE containing data (equals
//                        number of TLPs to send / 2)
//   REQUESTER_ID       : value for the Requester ID field in outgoing TLPs
//
//   all other parameters apply directly to Root Port Block for PCI Express
//-----------------------------------------------------------------------------

`timescale 1ns/1ns

(* DowngradeIPIdentifiedWarnings = "yes" *)   
module cgator_wrapper
  #(
    // Configurator parameters
    parameter        TCQ                 = 1,
    parameter        EXTRA_PIPELINE      = 1,
    parameter        ROM_FILE            = "cgator_cfg_rom.data",
    parameter        ROM_SIZE            = 46,
    parameter [15:0] REQUESTER_ID        = 16'h10EE,
    parameter        PL_FAST_TRAIN       = "FALSE",
    parameter        C_DATA_WIDTH        = 64,
    parameter        KEEP_WIDTH          = C_DATA_WIDTH / 8,
    parameter        INIT_PATTERN_WIDTH  = 8
  )
  (
    //-------------------------------------------------------
    // Configurator I/Os
    //-------------------------------------------------------
    input                                         start_config,
    output                                        finished_config,
    output                                        failed_config,

    //-------------------------------------------------------
    // PCI Express (pci_exp) Interface
    //-------------------------------------------------------
    // Tx
    output  [0:0]     pci_exp_txp,
    output  [0:0]     pci_exp_txn,

    // Rx
    input   [0:0]     pci_exp_rxp,
    input   [0:0]     pci_exp_rxn,

    //-------------------------------------------------------
    // Transaction (AXIS) Interface
    //-------------------------------------------------------
    // Common
    output                                        user_clk_out,
    output                                        user_reset_out,
    output                                        user_lnk_up,

    // Tx AXIS
    output                                        s_axis_tx_tready,
    input  [C_DATA_WIDTH-1:0]                     s_axis_tx_tdata,
    input  [KEEP_WIDTH-1:0]                       s_axis_tx_tkeep,
    input  [3:0]                                  s_axis_tx_tuser,
    input                                         s_axis_tx_tlast,
    input                                         s_axis_tx_tvalid,

    // Rx AXIS
    output  [C_DATA_WIDTH-1:0]                    m_axis_rx_tdata,
    output  [KEEP_WIDTH-1:0]                      m_axis_rx_tkeep,
    output                                        m_axis_rx_tlast,
    output                                        m_axis_rx_tvalid,
    output  [21:0]                                m_axis_rx_tuser,

    input                                         tx_cfg_gnt,
    input   [7:0]                                 cfg_ds_bus_number,
    input   [4:0]                                 cfg_ds_device_number,
    input                                         cfg_trn_pending,
    input                                         cfg_pm_send_pme_to,
    input  [63:0]                                 cfg_dsn,

    // Flow Control
    output [11:0]                                 fc_cpld,
    output  [7:0]                                 fc_cplh,
    output [11:0]                                 fc_npd,
    output  [7:0]                                 fc_nph,
    output [11:0]                                 fc_pd,
    output  [7:0]                                 fc_ph,
    input   [2:0]                                 fc_sel,

    //-------------------------------------------------------
    // Configuration (CFG) Interface
    //-------------------------------------------------------
    output [31:0]                                 cfg_do,
    output                                        cfg_rd_wr_done,
    input  [31:0]                                 cfg_di,
    input   [3:0]                                 cfg_byte_en,
    input   [9:0]                                 cfg_dwaddr,
    input                                         cfg_wr_en,
    input                                         cfg_wr_rw1c_as_rw,
    input                                         cfg_rd_en,

    input                                         cfg_err_cor,
    input                                         cfg_err_ur,
    input                                         cfg_err_ecrc,
    input                                         cfg_err_cpl_timeout,
    input                                         cfg_err_cpl_abort,
    input                                         cfg_err_cpl_unexpect,
    input                                         cfg_err_posted,
    input                                         cfg_err_locked,
    input  [47:0]                                 cfg_err_tlp_cpl_header,
    output                                        cfg_err_cpl_rdy,

    input                                         cfg_interrupt,
    output                                        cfg_interrupt_rdy,
    input                                         cfg_interrupt_assert,
    input  [7:0]                                  cfg_interrupt_di,
    output [7:0]                                  cfg_interrupt_do,
    output [2:0]                                  cfg_interrupt_mmenable,
    output                                        cfg_interrupt_msienable,
    output                                        cfg_interrupt_msixenable,
    output                                        cfg_interrupt_msixfm,

    output  [5:0]                                 tx_buf_av,
    output                                        tx_err_drop,
    output                                        tx_cfg_req,
    output [15:0]                                 cfg_status,
    output [15:0]                                 cfg_command,
    output [15:0]                                 cfg_dstatus,
    output [15:0]                                 cfg_dcommand,
    output [15:0]                                 cfg_lstatus,
    output [15:0]                                 cfg_lcommand,
    output [15:0]                                 cfg_dcommand2,
    output  [2:0]                                 cfg_pcie_link_state,
    output                                        cfg_pmcsr_pme_en,
    output                                        cfg_pmcsr_pme_status,
    output  [1:0]                                 cfg_pmcsr_powerstate,
    output                                        cfg_msg_received,
    output [15:0]                                 cfg_msg_data,
    output                                        cfg_msg_received_err_cor,
    output                                        cfg_msg_received_err_non_fatal,
    output                                        cfg_msg_received_err_fatal,
    output                                        cfg_msg_received_pme_to_ack,
    output                                        cfg_msg_received_assert_inta,
    output                                        cfg_msg_received_assert_intb,
    output                                        cfg_msg_received_assert_intc,
    output                                        cfg_msg_received_assert_intd,
    output                                        cfg_msg_received_deassert_inta,
    output                                        cfg_msg_received_deassert_intb,
    output                                        cfg_msg_received_deassert_intc,
    output                                        cfg_msg_received_deassert_intd,
    //-------------------------------------------------------
    // Physical Layer Control and Status (PL) Interface
    //-------------------------------------------------------
    output [2:0]                                  pl_initial_link_width,
    output [1:0]                                  pl_lane_reversal_mode,
    output                                        pl_link_gen2_capable,
    output                                        pl_link_partner_gen2_supported,
    output                                        pl_link_upcfg_capable,
    output [5:0]                                  pl_ltssm_state,
    output                                        pl_sel_link_rate,
    output [1:0]                                  pl_sel_link_width,
    output                                        pl_directed_change_done,
    input                                         pl_directed_link_auton,
    input  [1:0]                                  pl_directed_link_change,
    input                                         pl_directed_link_speed,
    input  [1:0]                                  pl_directed_link_width,
    input                                         pl_upstream_prefer_deemph,
    input                                         pl_transmit_hot_rst,


    input                 pcie_drp_clk,
    input                 pcie_drp_en,
    input                 pcie_drp_we,
    input     [8:0]       pcie_drp_addr,
    input    [15:0]       pcie_drp_di,
    output                pcie_drp_rdy,
    output   [15:0]       pcie_drp_do, 

    //-------------------------------------------------------
    // System  (SYS) Interface
    //-------------------------------------------------------
    input                 sys_clk,
    input                 sys_rst_n,
    input                 pipe_mmcm_rst_n        // Async      | Async


);

  // Connections between Root Port and Configurator

  wire                    rport_tx_cfg_gnt;
  wire                    rport_rx_np_ok;
  wire [5:0]              rport_tx_buf_av;
  wire                    rport_tx_cfg_req;
  wire                    rport_tx_err_drop;

  (* mark_debug = "true" *) wire                    rport_s_axis_tx_tready;
  (* mark_debug = "true" *) wire [C_DATA_WIDTH-1:0] rport_s_axis_tx_tdata;
  wire [KEEP_WIDTH-1:0]   rport_s_axis_tx_tkeep;
  wire [3:0]              rport_s_axis_tx_tuser;
  wire                    rport_s_axis_tx_tlast;
  wire                    rport_s_axis_tx_tvalid;

  wire [C_DATA_WIDTH-1:0] rport_m_axis_rx_tdata;
  wire [KEEP_WIDTH-1:0]   rport_m_axis_rx_tkeep;
  wire                    rport_m_axis_rx_tlast;
  wire                    rport_m_axis_rx_tvalid;
  wire                    rport_m_axis_rx_tready;
  wire [21:0]             rport_m_axis_rx_tuser;

  wire [31:0]             rport_cfg_do;
  wire                    rport_cfg_rd_wr_done;
  wire [31:0]             rport_cfg_di;
  wire  [3:0]             rport_cfg_byte_en;
  wire  [9:0]             rport_cfg_dwaddr;
  wire                    rport_cfg_wr_en;
  wire                    rport_cfg_wr_rw1c_as_rw;
  wire                    rport_cfg_rd_en;


  localparam REF_CLK_FREQ  = 0;  // 0 - 100 MHz, 1 - 125 MHz, 2 - 250 MHz
  localparam USER_CLK_FREQ = 1;
  localparam USER_CLK2_DIV2= "FALSE";
  localparam USERCLK2_FREQ = (USER_CLK2_DIV2 == "TRUE") ? (USER_CLK_FREQ == 4) ? 3 : (USER_CLK_FREQ == 3) ? 2 : USER_CLK_FREQ: USER_CLK_FREQ;

pcie_7x_0_support #
   (	 
    .TCQ                   ( TCQ ),
    .LINK_CAP_MAX_LINK_WIDTH        ( 1 ),  // PCIe Lane Width
    .C_DATA_WIDTH                   ( C_DATA_WIDTH ),                       // RX/TX interface data width
    .KEEP_WIDTH                     ( KEEP_WIDTH ),                         // TSTRB width
    .PCIE_REFCLK_FREQ               ( REF_CLK_FREQ ),                       // PCIe reference clock frequency
    .PCIE_USERCLK1_FREQ             ( USER_CLK_FREQ +1 ),                   // PCIe user clock 1 frequency
    .PCIE_USERCLK2_FREQ             ( USERCLK2_FREQ +1 ),                   // PCIe user clock 2 frequency             
    .PCIE_USE_MODE                  ("1.0"),           // PCIe use mode
    .PCIE_GT_DEVICE                 ("GTP")              // PCIe GT device
   ) 
pcie_7x_0_support_i
  (

  //----------------------------------------------------------------------------------------------------------------//
  // PCI Express (pci_exp) Interface                                                                                //
  //----------------------------------------------------------------------------------------------------------------//
  // Tx
  .pci_exp_txn                               ( pci_exp_txn ),
  .pci_exp_txp                               ( pci_exp_txp ),

  // Rx
  .pci_exp_rxn                               ( pci_exp_rxn ),
  .pci_exp_rxp                               ( pci_exp_rxp ),

  //----------------------------------------------------------------------------------------------------------------//
  // Clocking Sharing Interface                                                                                     //
  //----------------------------------------------------------------------------------------------------------------//
  .pipe_pclk_out_slave                        ( ),
  .pipe_rxusrclk_out                          ( ),
  .pipe_rxoutclk_out                          ( ),
  .pipe_dclk_out                              ( ),
  .pipe_userclk1_out                          ( ),
  .pipe_oobclk_out                            ( ),
  .pipe_userclk2_out                          ( ),
  .pipe_mmcm_lock_out                         ( ),
  .pipe_pclk_sel_slave                        ( 1'b0),
  .pipe_mmcm_rst_n                            ( pipe_mmcm_rst_n ),        // Async      | Async


  //----------------------------------------------------------------------------------------------------------------//
  // AXI-S Interface                                                                                                //
  //----------------------------------------------------------------------------------------------------------------//

  // Common
  .user_clk_out                              ( user_clk_out ),
  .user_reset_out                            ( user_reset_out ),
  .user_lnk_up                               ( user_lnk_up ),
  .user_app_rdy                              ( ),

  // TX
    .s_axis_tx_tready               ( rport_s_axis_tx_tready ),
    .s_axis_tx_tdata                ( rport_s_axis_tx_tdata ),
    .s_axis_tx_tkeep                ( rport_s_axis_tx_tkeep ),
    .s_axis_tx_tuser                ( rport_s_axis_tx_tuser ),
    .s_axis_tx_tlast                ( rport_s_axis_tx_tlast ),
    .s_axis_tx_tvalid               ( rport_s_axis_tx_tvalid ),

  // Rx
    .m_axis_rx_tdata                ( rport_m_axis_rx_tdata ),
    .m_axis_rx_tkeep                ( rport_m_axis_rx_tkeep ),
    .m_axis_rx_tlast                ( rport_m_axis_rx_tlast ),
    .m_axis_rx_tvalid               ( rport_m_axis_rx_tvalid ),
    .m_axis_rx_tready               ( rport_m_axis_rx_tready ),
    .m_axis_rx_tuser                ( rport_m_axis_rx_tuser ),
    .tx_cfg_gnt                     ( rport_tx_cfg_gnt ),
    .rx_np_ok                       ( rport_rx_np_ok ),
    .rx_np_req                      ( 1'b1 ),
    .cfg_trn_pending                ( cfg_trn_pending ),
    .cfg_pm_halt_aspm_l0s           ( 1'b0 ),
    .cfg_pm_halt_aspm_l1            ( 1'b0 ),
    .cfg_pm_force_state_en          ( 1'b0 ),
    .cfg_pm_force_state             ( 2'b00 ),
    .cfg_dsn                        ( cfg_dsn ),
    .cfg_turnoff_ok                 ( 1'b0 ),
    .cfg_pm_wake                    ( 1'b0 ),
    .cfg_pm_send_pme_to             ( cfg_pm_send_pme_to ),
    .cfg_ds_bus_number              ( cfg_ds_bus_number ),
    .cfg_ds_device_number           ( cfg_ds_device_number ),
    .cfg_ds_function_number         ( 3'b000 ),
    .tx_cfg_req                     ( rport_tx_cfg_req ),
    .tx_err_drop                    ( rport_tx_err_drop ),
    .tx_buf_av                      ( rport_tx_buf_av ),
    .cfg_status                     ( cfg_status ),
    .cfg_command                    ( cfg_command ),
    .cfg_dstatus                    ( cfg_dstatus ),
    .cfg_dcommand                   ( cfg_dcommand ),
    .cfg_lstatus                    ( cfg_lstatus ),
    .cfg_lcommand                   ( cfg_lcommand ),
    .cfg_dcommand2                  ( cfg_dcommand2 ),
    .cfg_pcie_link_state            ( cfg_pcie_link_state ),
    .cfg_pmcsr_pme_en               ( cfg_pmcsr_pme_en ),
    .cfg_pmcsr_powerstate(cfg_pmcsr_powerstate),
    .cfg_pmcsr_pme_status           ( cfg_pmcsr_pme_status ),
    .cfg_received_func_lvl_rst      ( ),
    .cfg_vc_tcvc_map                           ( ),
    .cfg_to_turnoff                 ( ),
    .cfg_bus_number                 ( ),
    .cfg_device_number              ( ),
    .cfg_function_number            ( ),
    .cfg_bridge_serr_en                         ( ),
    .cfg_slot_control_electromech_il_ctl_pulse  ( ),
    .cfg_root_control_syserr_corr_err_en        ( ),
    .cfg_root_control_syserr_non_fatal_err_en   ( ),
    .cfg_root_control_syserr_fatal_err_en       ( ),
    .cfg_root_control_pme_int_en                ( ),
    .cfg_aer_rooterr_corr_err_reporting_en      ( ),
    .cfg_aer_rooterr_non_fatal_err_reporting_en ( ),
    .cfg_aer_rooterr_fatal_err_reporting_en     ( ),
    .cfg_aer_rooterr_corr_err_received          ( ),
    .cfg_aer_rooterr_non_fatal_err_received     ( ),
    .cfg_aer_rooterr_fatal_err_received         ( ),

  // Flow Control
    .fc_cpld                        ( fc_cpld ),
    .fc_cplh                        ( fc_cplh ),
    .fc_npd                         ( fc_npd ),
    .fc_nph                         ( fc_nph ),
    .fc_pd                          ( fc_pd ),
    .fc_ph                          ( fc_ph ),
    .fc_sel                         ( fc_sel ),

    .cfg_mgmt_do                                ( rport_cfg_do ),
    .cfg_mgmt_rd_wr_done                        ( rport_cfg_rd_wr_done ),
    .cfg_mgmt_di                                ( rport_cfg_di ),
    .cfg_mgmt_byte_en                           ( rport_cfg_byte_en ),
    .cfg_mgmt_dwaddr                            ( rport_cfg_dwaddr ),
    .cfg_mgmt_wr_en                             ( rport_cfg_wr_en ),
    .cfg_mgmt_rd_en                             ( rport_cfg_rd_en ),
    .cfg_mgmt_wr_rw1c_as_rw                     ( rport_cfg_wr_rw1c_as_rw ),
    .cfg_mgmt_wr_readonly                       ( 1'b0 ),

    .cfg_err_ecrc                               ( cfg_err_ecrc),
    .cfg_err_ur                                 ( cfg_err_ur),
    .cfg_err_cpl_timeout                        ( cfg_err_cpl_timeout),
    .cfg_err_cpl_unexpect                       ( cfg_err_cpl_unexpect),
    .cfg_err_cpl_abort                          ( cfg_err_cpl_abort),
    .cfg_err_posted                             ( cfg_err_posted),
    .cfg_err_cor                                ( cfg_err_cor),
    .cfg_err_atomic_egress_blocked              ( 1'b0 ),
    .cfg_err_internal_cor                       ( 1'b0 ),
    .cfg_err_malformed                          ( 1'b0 ),
    .cfg_err_mc_blocked                         ( 1'b0 ),
    .cfg_err_poisoned                           ( 1'b0 ),
    .cfg_err_norecovery                         ( 1'b0 ),
    .cfg_err_tlp_cpl_header                     ( cfg_err_tlp_cpl_header ),
    .cfg_err_cpl_rdy                            ( cfg_err_cpl_rdy ),
    .cfg_err_locked                             ( cfg_err_locked ),
    .cfg_err_acs                                ( 1'b0 ),
    .cfg_err_internal_uncor                     ( 1'b0 ),
    .cfg_err_aer_headerlog                     ( 128'b0 ),
    .cfg_aer_interrupt_msgnum                  ( 5'b0 ),
    .cfg_err_aer_headerlog_set                 ( ),
    .cfg_aer_ecrc_check_en                     ( ),
    .cfg_aer_ecrc_gen_en                       ( ),
    .cfg_interrupt                              ( cfg_interrupt ),
    .cfg_interrupt_rdy                          ( cfg_interrupt_rdy ),
    .cfg_interrupt_assert                       ( cfg_interrupt_assert ),
    .cfg_interrupt_di                           ( cfg_interrupt_di ),
    .cfg_interrupt_do                           ( cfg_interrupt_do ),
    .cfg_interrupt_mmenable                     ( cfg_interrupt_mmenable ),
    .cfg_interrupt_msienable                    ( cfg_interrupt_msienable ),
    .cfg_interrupt_msixenable                   ( cfg_interrupt_msixenable ),
    .cfg_interrupt_msixfm                       ( cfg_interrupt_msixfm ),
    .cfg_interrupt_stat                         ( 1'b0 ),
    .cfg_pciecap_interrupt_msgnum               ( 5'h00 ),
    .cfg_msg_received                           ( cfg_msg_received ),
    .cfg_msg_data                               ( cfg_msg_data ),
    .cfg_msg_received_pm_as_nak                 ( ),
    .cfg_msg_received_setslotpowerlimit         ( ),
    .cfg_msg_received_err_cor                   ( cfg_msg_received_err_cor ),
    .cfg_msg_received_err_non_fatal             ( cfg_msg_received_err_non_fatal ),
    .cfg_msg_received_err_fatal                 ( cfg_msg_received_err_fatal ),
    .cfg_msg_received_pm_pme                    ( ),
    .cfg_msg_received_pme_to_ack                ( cfg_msg_received_pme_to_ack ),
    .cfg_msg_received_assert_int_a              ( cfg_msg_received_assert_inta ),
    .cfg_msg_received_assert_int_b              ( cfg_msg_received_assert_intb ),
    .cfg_msg_received_assert_int_c              ( cfg_msg_received_assert_intc ),
    .cfg_msg_received_assert_int_d              ( cfg_msg_received_assert_intd ),
    .cfg_msg_received_deassert_int_a            ( cfg_msg_received_deassert_inta ),
    .cfg_msg_received_deassert_int_b            ( cfg_msg_received_deassert_intb ),
    .cfg_msg_received_deassert_int_c            ( cfg_msg_received_deassert_intc ),
    .cfg_msg_received_deassert_int_d            ( cfg_msg_received_deassert_intd ),
    //-------------------------------------------------------
    // Physical Layer Control and Status (PL) Interface
    //-------------------------------------------------------
    .pl_directed_link_change                    ( pl_directed_link_change ),
    .pl_directed_link_speed                     ( pl_directed_link_speed ),
    .pl_directed_link_width                     ( pl_directed_link_width ),
    .pl_directed_link_auton                     ( pl_directed_link_auton ),
    .pl_upstream_prefer_deemph                  ( pl_upstream_prefer_deemph ),
    .pl_sel_lnk_rate                            ( pl_sel_link_rate ),
    .pl_sel_lnk_width                           ( pl_sel_link_width ),
    .pl_ltssm_state                             ( pl_ltssm_state ),
    .pl_lane_reversal_mode                      ( pl_lane_reversal_mode ),
    .pl_phy_lnk_up                              ( ),
    .pl_tx_pm_state                             ( ),
    .pl_rx_pm_state                             ( ),
    .pl_link_upcfg_cap                          ( pl_link_upcfg_capable ),
    .pl_link_gen2_cap                           ( pl_link_gen2_capable ),
    .pl_link_partner_gen2_supported             ( pl_link_partner_gen2_supported ),
    .pl_initial_link_width                      ( pl_initial_link_width ),
    .pl_directed_change_done                    ( pl_directed_change_done ),
    .pl_received_hot_rst                        ( ),
    .pl_transmit_hot_rst                        ( pl_transmit_hot_rst ),
    .pl_downstream_deemph_source                ( 1'b0 ),
  //----------------------------------------------------------------------------------------------------------------//
  // PCIe DRP (PCIe DRP) Interface                                                                                  //
  //----------------------------------------------------------------------------------------------------------------//
    .pcie_drp_clk                             ( pcie_drp_clk ),
    .pcie_drp_do                              ( pcie_drp_do ),
    .pcie_drp_rdy                             ( pcie_drp_rdy ),
    .pcie_drp_addr                            ( pcie_drp_addr ),
    .pcie_drp_en                              ( pcie_drp_en ),
    .pcie_drp_di                              ( pcie_drp_di ),
    .pcie_drp_we                              ( pcie_drp_we ),


  //----------------------------------------------------------------------------------------------------------------//
  // System  (SYS) Interface                                                                                        //
  //----------------------------------------------------------------------------------------------------------------//
    .sys_clk                      ( sys_clk ),
    .sys_rst_n                    ( sys_rst_n ) 
);
  //
  // Instantiate Configurator design
  //
  cgator #(
    .TCQ                   ( TCQ ),
    .EXTRA_PIPELINE        ( EXTRA_PIPELINE ),
    .ROM_SIZE              ( ROM_SIZE ),
    .ROM_FILE              ( ROM_FILE ),
    .REQUESTER_ID          (REQUESTER_ID),
    .C_DATA_WIDTH          ( C_DATA_WIDTH ),
    .KEEP_WIDTH            ( KEEP_WIDTH )
  ) cgator_i
  (
    // globals
    .user_clk                       ( user_clk_out ),
    .reset                          ( user_reset_out ),

    // User interface for configuration
    .start_config                   ( start_config ),
    .finished_config                ( finished_config ),
    .failed_config                  ( failed_config ),

    // Rport AXIS interfaces
    .rport_s_axis_tx_tready         ( rport_s_axis_tx_tready ),
    .rport_s_axis_tx_tdata          ( rport_s_axis_tx_tdata ),
    .rport_s_axis_tx_tkeep          ( rport_s_axis_tx_tkeep ),
    .rport_s_axis_tx_tuser          ( rport_s_axis_tx_tuser ),
    .rport_s_axis_tx_tlast          ( rport_s_axis_tx_tlast ),
    .rport_s_axis_tx_tvalid         ( rport_s_axis_tx_tvalid ),

    .rport_m_axis_rx_tdata          ( rport_m_axis_rx_tdata ),
    .rport_m_axis_rx_tkeep          ( rport_m_axis_rx_tkeep ),
    .rport_m_axis_rx_tlast          ( rport_m_axis_rx_tlast ),
    .rport_m_axis_rx_tvalid         ( rport_m_axis_rx_tvalid ),
    .rport_m_axis_rx_tready         ( rport_m_axis_rx_tready ),
    .rport_m_axis_rx_tuser          ( rport_m_axis_rx_tuser ),

    // User AXIS interfaces
    .usr_s_axis_tx_tready           ( s_axis_tx_tready ),
    .usr_s_axis_tx_tdata            ( s_axis_tx_tdata ),
    .usr_s_axis_tx_tkeep            ( s_axis_tx_tkeep ),
    .usr_s_axis_tx_tuser            ( s_axis_tx_tuser ),
    .usr_s_axis_tx_tlast            ( s_axis_tx_tlast ),
    .usr_s_axis_tx_tvalid           ( s_axis_tx_tvalid ),

    .usr_m_axis_rx_tdata            ( m_axis_rx_tdata ),
    .usr_m_axis_rx_tkeep            ( m_axis_rx_tkeep ),
    .usr_m_axis_rx_tlast            ( m_axis_rx_tlast ),
    .usr_m_axis_rx_tvalid           ( m_axis_rx_tvalid ),
    .usr_m_axis_rx_tuser            ( m_axis_rx_tuser ),
    .rport_rx_np_ok                 ( rport_rx_np_ok ),
    .rport_tx_cfg_gnt               ( rport_tx_cfg_gnt ),
    .usr_tx_cfg_gnt                 ( tx_cfg_gnt ),
    .rport_tx_cfg_req               ( rport_tx_cfg_req ),
    .rport_tx_buf_av                ( rport_tx_buf_av ),
    .rport_tx_err_drop              ( rport_tx_err_drop ),
    .usr_tx_cfg_req                 ( tx_cfg_req ),
    .usr_tx_buf_av                  ( tx_buf_av ),
    .usr_tx_err_drop                ( tx_err_drop ),
    // Rport CFG interface
    .rport_cfg_do                   ( rport_cfg_do ),
    .rport_cfg_rd_wr_done           ( rport_cfg_rd_wr_done ),
    .rport_cfg_di                   ( rport_cfg_di ),
    .rport_cfg_byte_en              ( rport_cfg_byte_en ),
    .rport_cfg_dwaddr               ( rport_cfg_dwaddr ),
    .rport_cfg_wr_en                ( rport_cfg_wr_en ),
    .rport_cfg_wr_rw1c_as_rw        ( rport_cfg_wr_rw1c_as_rw ),
    .rport_cfg_rd_en                ( rport_cfg_rd_en ),

    // User CFG interface
    .usr_cfg_do                     ( cfg_do ),
    .usr_cfg_rd_wr_done             ( cfg_rd_wr_done ),
    .usr_cfg_di                     ( cfg_di ),
    .usr_cfg_byte_en                ( cfg_byte_en ),
    .usr_cfg_dwaddr                 ( cfg_dwaddr ),
    .usr_cfg_wr_en                  ( cfg_wr_en ),
    .usr_cfg_wr_rw1c_as_rw          ( cfg_wr_rw1c_as_rw ),
    .usr_cfg_rd_en                  ( cfg_rd_en ),
    // Rport PL interface
    .rport_pl_link_gen2_capable     ( pl_link_gen2_capable )

);

endmodule // cgator_wrapper
