//-----------------------------------------------------------------------------
// Project    : Series-7 Integrated Block for PCI Express
// File       : cgator_wrapper.v
// Version    : 3.3
// Description : Modified wrapper. CGATOR (Driver) removed. 
//               Direct pass-through for RISC-V SoC.
//-----------------------------------------------------------------------------

`timescale 1ns/1ns

(* DowngradeIPIdentifiedWarnings = "yes" *)
module cgator_wrapper
  #(
    // Configurator parameters (Keep for compatibility, though mostly unused now)
    parameter        TCQ                 = 1,
    parameter        EXTRA_PIPELINE      = 1,
    parameter        ROM_FILE            = "cgator_cfg_rom.data",
    parameter        ROM_SIZE            = 32,
    parameter [15:0] REQUESTER_ID        = 16'h10EE,
    parameter        PL_FAST_TRAIN       = "FALSE",
    parameter        C_DATA_WIDTH        = 64,
    parameter        KEEP_WIDTH          = C_DATA_WIDTH / 8,
    parameter        INIT_PATTERN_WIDTH  = 8
  )
  (
    //-------------------------------------------------------
    // Configurator I/Os - VISE SE NE KORISTE (Dummy)
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
    // Transaction (AXIS) Interface - SPOJENI NA RISC-V
    //-------------------------------------------------------
    // Common
    output                                        user_clk_out,
    output                                        user_reset_out,
    output                                        user_lnk_up,

    // Tx AXIS (Input from RISC-V)
    output                                        s_axis_tx_tready,
    input  [C_DATA_WIDTH-1:0]                     s_axis_tx_tdata,
    input  [KEEP_WIDTH-1:0]                       s_axis_tx_tkeep,
    input  [3:0]                                  s_axis_tx_tuser,
    input                                         s_axis_tx_tlast,
    input                                         s_axis_tx_tvalid,

    // Rx AXIS (Output to RISC-V)
    output  [C_DATA_WIDTH-1:0]                    m_axis_rx_tdata,
    output  [KEEP_WIDTH-1:0]                      m_axis_rx_tkeep,
    output                                        m_axis_rx_tlast,
    output                                        m_axis_rx_tvalid,
    output  [21:0]                                m_axis_rx_tuser,

    // Configuration signals (Inputs tied to 0, Outputs floating/unused)
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

    // Config Interface (Mostly unused by RISC-V currently)
    output [31:0]                                 cfg_do,
    output                                        cfg_rd_wr_done,
    input  [31:0]                                 cfg_di,
    input   [3:0]                                 cfg_byte_en,
    input   [9:0]                                 cfg_dwaddr,
    input                                         cfg_wr_en,
    input                                         cfg_wr_rw1c_as_rw,
    input                                         cfg_rd_en,

    // Error reporting
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

    // Interrupts
    input                                         cfg_interrupt,
    output                                        cfg_interrupt_rdy,
    input                                         cfg_interrupt_assert,
    input  [7:0]                                  cfg_interrupt_di,
    output [7:0]                                  cfg_interrupt_do,
    output [2:0]                                  cfg_interrupt_mmenable,
    output                                        cfg_interrupt_msienable,
    output                                        cfg_interrupt_msixenable,
    output                                        cfg_interrupt_msixfm,

    // Status outputs
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
    
    // PL Interface
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

    // DRP
    input                 pcie_drp_clk,
    input                 pcie_drp_en,
    input                 pcie_drp_we,
    input     [8:0]       pcie_drp_addr,
    input    [15:0]       pcie_drp_di,
    output                pcie_drp_rdy,
    output   [15:0]       pcie_drp_do, 

    // System
    input                 sys_clk,
    input                 sys_rst_n,
    input                 pipe_mmcm_rst_n
);

  // Tie-offs for dummy outputs (since Cgator is gone)
  assign finished_config = 1'b0;
  assign failed_config   = 1'b0;

  // Configuration management signals - Tying to 0 as RISC-V uses TLPs for config
  wire [31:0] rport_cfg_di        = 32'b0;
  wire [3:0]  rport_cfg_byte_en   = 4'b0;
  wire [9:0]  rport_cfg_dwaddr    = 10'b0;
  wire        rport_cfg_wr_en     = 1'b0;
  wire        rport_cfg_rd_en     = 1'b0;

  // We are not generating internal config requests anymore
  assign tx_cfg_req = 1'b0; 

  localparam REF_CLK_FREQ  = 0;
  localparam USER_CLK_FREQ = 1;
  localparam USER_CLK2_DIV2= "FALSE";
  localparam USERCLK2_FREQ = (USER_CLK2_DIV2 == "TRUE") ? (USER_CLK_FREQ == 4) ? 3 : (USER_CLK_FREQ == 3) ? 2 : USER_CLK_FREQ: USER_CLK_FREQ;

  //--------------------------------------------------------------------------------//
  // PCIe CORE INSTANTIATION
  //--------------------------------------------------------------------------------//
  pcie_7x_0_support #
   (	 
    .TCQ                            ( TCQ ),
    .LINK_CAP_MAX_LINK_WIDTH        ( 1 ),
    .C_DATA_WIDTH                   ( C_DATA_WIDTH ),
    .KEEP_WIDTH                     ( KEEP_WIDTH ),
    .PCIE_REFCLK_FREQ               ( REF_CLK_FREQ ),
    .PCIE_USERCLK1_FREQ             ( USER_CLK_FREQ +1 ),
    .PCIE_USERCLK2_FREQ             ( USERCLK2_FREQ +1 ),             
    .PCIE_USE_MODE                  ("1.0"),
    .PCIE_GT_DEVICE                 ("GTP")
   ) 
  pcie_7x_0_support_i
  (
    // PCIe IO
    .pci_exp_txn                    ( pci_exp_txn ),
    .pci_exp_txp                    ( pci_exp_txp ),
    .pci_exp_rxn                    ( pci_exp_rxn ),
    .pci_exp_rxp                    ( pci_exp_rxp ),

    // Clocking
    .pipe_pclk_out_slave            ( ),
    .pipe_rxusrclk_out              ( ),
    .pipe_rxoutclk_out              ( ),
    .pipe_dclk_out                  ( ),
    .pipe_userclk1_out              ( ),
    .pipe_oobclk_out                ( ),
    .pipe_userclk2_out              ( ),
    .pipe_mmcm_lock_out             ( ),
    .pipe_pclk_sel_slave            ( 1'b0),
    .pipe_mmcm_rst_n                ( pipe_mmcm_rst_n ),

    // Common
    .user_clk_out                   ( user_clk_out ),
    .user_reset_out                 ( user_reset_out ),
    .user_lnk_up                    ( user_lnk_up ),
    .user_app_rdy                   ( ),

    // TX - CONNECTED DIRECTLY TO WRAPPER PORTS (RISC-V)
    .s_axis_tx_tready               ( s_axis_tx_tready ),
    .s_axis_tx_tdata                ( s_axis_tx_tdata ),
    .s_axis_tx_tkeep                ( s_axis_tx_tkeep ),
    .s_axis_tx_tuser                ( s_axis_tx_tuser ),
    .s_axis_tx_tlast                ( s_axis_tx_tlast ),
    .s_axis_tx_tvalid               ( s_axis_tx_tvalid ),

    // RX - CONNECTED DIRECTLY TO WRAPPER PORTS (RISC-V)
    .m_axis_rx_tdata                ( m_axis_rx_tdata ),
    .m_axis_rx_tkeep                ( m_axis_rx_tkeep ),
    .m_axis_rx_tlast                ( m_axis_rx_tlast ),
    .m_axis_rx_tvalid               ( m_axis_rx_tvalid ),
    .m_axis_rx_tready               ( 1'b1 ), // Always ready to receive in this simpler wrapper
    .m_axis_rx_tuser                ( m_axis_rx_tuser ),

    // Config / Status Pass-through
    .tx_cfg_gnt                     ( tx_cfg_gnt ),
    .rx_np_ok                       ( 1'b1 ),
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
    .tx_cfg_req                     ( ), // Internal output, unused since we disabled internal requests
    .tx_err_drop                    ( tx_err_drop ),
    .tx_buf_av                      ( tx_buf_av ),
    .cfg_status                     ( cfg_status ),
    .cfg_command                    ( cfg_command ),
    .cfg_dstatus                    ( cfg_dstatus ),
    .cfg_dcommand                   ( cfg_dcommand ),
    .cfg_lstatus                    ( cfg_lstatus ),
    .cfg_lcommand                   ( cfg_lcommand ),
    .cfg_dcommand2                  ( cfg_dcommand2 ),
    .cfg_pcie_link_state            ( cfg_pcie_link_state ),
    .cfg_pmcsr_pme_en               ( cfg_pmcsr_pme_en ),
    .cfg_pmcsr_powerstate           ( cfg_pmcsr_powerstate),
    .cfg_pmcsr_pme_status           ( cfg_pmcsr_pme_status ),
    
    // Flow Control
    .fc_cpld                        ( fc_cpld ),
    .fc_cplh                        ( fc_cplh ),
    .fc_npd                         ( fc_npd ),
    .fc_nph                         ( fc_nph ),
    .fc_pd                          ( fc_pd ),
    .fc_ph                          ( fc_ph ),
    .fc_sel                         ( fc_sel ),

    // Config Management (Driven by local signals tied to 0)
    .cfg_mgmt_do                    ( cfg_do ),
    .cfg_mgmt_rd_wr_done            ( cfg_rd_wr_done ),
    .cfg_mgmt_di                    ( rport_cfg_di ),
    .cfg_mgmt_byte_en               ( rport_cfg_byte_en ),
    .cfg_mgmt_dwaddr                ( rport_cfg_dwaddr ),
    .cfg_mgmt_wr_en                 ( rport_cfg_wr_en ),
    .cfg_mgmt_rd_en                 ( rport_cfg_rd_en ),
    .cfg_mgmt_wr_rw1c_as_rw         ( 1'b0 ),
    .cfg_mgmt_wr_readonly           ( 1'b0 ),

    // Error Signals
    .cfg_err_ecrc                   ( cfg_err_ecrc),
    .cfg_err_ur                     ( cfg_err_ur),
    .cfg_err_cpl_timeout            ( cfg_err_cpl_timeout),
    .cfg_err_cpl_unexpect           ( cfg_err_cpl_unexpect),
    .cfg_err_cpl_abort              ( cfg_err_cpl_abort),
    .cfg_err_posted                 ( cfg_err_posted),
    .cfg_err_cor                    ( cfg_err_cor),
    .cfg_err_atomic_egress_blocked  ( 1'b0 ),
    .cfg_err_internal_cor           ( 1'b0 ),
    .cfg_err_malformed              ( 1'b0 ),
    .cfg_err_mc_blocked             ( 1'b0 ),
    .cfg_err_poisoned               ( 1'b0 ),
    .cfg_err_norecovery             ( 1'b0 ),
    .cfg_err_tlp_cpl_header         ( cfg_err_tlp_cpl_header ),
    .cfg_err_cpl_rdy                ( cfg_err_cpl_rdy ),
    .cfg_err_locked                 ( cfg_err_locked ),
    .cfg_err_acs                    ( 1'b0 ),
    .cfg_err_internal_uncor         ( 1'b0 ),
    .cfg_err_aer_headerlog          ( 128'b0 ),
    .cfg_aer_interrupt_msgnum       ( 5'b0 ),

    // Interrupts
    .cfg_interrupt                  ( cfg_interrupt ),
    .cfg_interrupt_rdy              ( cfg_interrupt_rdy ),
    .cfg_interrupt_assert           ( cfg_interrupt_assert ),
    .cfg_interrupt_di               ( cfg_interrupt_di ),
    .cfg_interrupt_do               ( cfg_interrupt_do ),
    .cfg_interrupt_mmenable         ( cfg_interrupt_mmenable ),
    .cfg_interrupt_msienable        ( cfg_interrupt_msienable ),
    .cfg_interrupt_msixenable       ( cfg_interrupt_msixenable ),
    .cfg_interrupt_msixfm           ( cfg_interrupt_msixfm ),
    .cfg_interrupt_stat             ( 1'b0 ),
    .cfg_pciecap_interrupt_msgnum   ( 5'h00 ),
    .cfg_msg_received               ( cfg_msg_received ),
    .cfg_msg_data                   ( cfg_msg_data ),
    .cfg_msg_received_err_cor       ( cfg_msg_received_err_cor ),
    .cfg_msg_received_err_non_fatal ( cfg_msg_received_err_non_fatal ),
    .cfg_msg_received_err_fatal     ( cfg_msg_received_err_fatal ),
    .cfg_msg_received_pme_to_ack    ( cfg_msg_received_pme_to_ack ),
    .cfg_msg_received_assert_int_a  ( cfg_msg_received_assert_inta ),
    .cfg_msg_received_assert_int_b  ( cfg_msg_received_assert_intb ),
    .cfg_msg_received_assert_int_c  ( cfg_msg_received_assert_intc ),
    .cfg_msg_received_assert_int_d  ( cfg_msg_received_assert_intd ),
    .cfg_msg_received_deassert_int_a( cfg_msg_received_deassert_inta ),
    .cfg_msg_received_deassert_int_b( cfg_msg_received_deassert_intb ),
    .cfg_msg_received_deassert_int_c( cfg_msg_received_deassert_intc ),
    .cfg_msg_received_deassert_int_d( cfg_msg_received_deassert_intd ),

    // PL Interface
    .pl_directed_link_change        ( pl_directed_link_change ),
    .pl_directed_link_speed         ( pl_directed_link_speed ),
    .pl_directed_link_width         ( pl_directed_link_width ),
    .pl_directed_link_auton         ( pl_directed_link_auton ),
    .pl_upstream_prefer_deemph      ( pl_upstream_prefer_deemph ),
    .pl_sel_lnk_rate                ( pl_sel_link_rate ),
    .pl_sel_lnk_width               ( pl_sel_link_width ),
    .pl_ltssm_state                 ( pl_ltssm_state ),
    .pl_lane_reversal_mode          ( pl_lane_reversal_mode ),
    .pl_link_upcfg_cap              ( pl_link_upcfg_capable ),
    .pl_link_gen2_cap               ( pl_link_gen2_capable ),
    .pl_link_partner_gen2_supported ( pl_link_partner_gen2_supported ),
    .pl_initial_link_width          ( pl_initial_link_width ),
    .pl_directed_change_done        ( pl_directed_change_done ),
    .pl_transmit_hot_rst            ( pl_transmit_hot_rst ),
    .pl_downstream_deemph_source    ( 1'b0 ),

    // DRP
    .pcie_drp_clk                   ( pcie_drp_clk ),
    .pcie_drp_do                    ( pcie_drp_do ),
    .pcie_drp_rdy                   ( pcie_drp_rdy ),
    .pcie_drp_addr                  ( pcie_drp_addr ),
    .pcie_drp_en                    ( pcie_drp_en ),
    .pcie_drp_di                    ( pcie_drp_di ),
    .pcie_drp_we                    ( pcie_drp_we ),

    // SYS
    .sys_clk                        ( sys_clk ),
    .sys_rst_n                      ( sys_rst_n ) 
);

  // We have removed cgator_i, cgator_controller, etc.
  // The connections above simply wire the external ports directly to the PCIe core.

endmodule // cgator_wrapper