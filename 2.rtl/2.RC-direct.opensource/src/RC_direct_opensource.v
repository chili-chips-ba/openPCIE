`timescale 1ns/1ns

(* DowngradeIPIdentifiedWarnings = "yes" *)
module RC_direct_opensource
  #(
    parameter TCQ                = 1,
    parameter SIMULATION         = 0,
    parameter PL_FAST_TRAIN      = "FALSE",
    parameter EXT_PIPE_SIM       = "FALSE",
    parameter REF_CLK_FREQ       = 0,
    parameter USER_CLK_FREQ      = 1,
    parameter C_DATA_WIDTH       = 64,
    parameter KEEP_WIDTH         = C_DATA_WIDTH / 8  
  ) (
    input wire          sys_clk_p,
    input wire          sys_clk_n,  

    input wire  [0:0]   RXN,
    input wire  [0:0]   RXP,
    output wire [0:0]   TXN,
    output wire [0:0]   TXP,

    input wire  sys_rst_n,
    
    output wire led_link_up,
    output wire clk_req
  );

  wire   user_clk;           
  wire   user_reset;         
  wire   user_lnk_up;
  
  wire   sys_clk;
  wire   rp_reset_n;
  
  IBUFDS_GTE2 refclk_ibuf (.O(sys_clk), .ODIV2(), .I(sys_clk_p), .CEB(1'b0), .IB(sys_clk_n));
 
  assign rp_reset_n = sys_rst_n;

  wire                      s_axis_tx_tready;
  wire [C_DATA_WIDTH-1:0]   s_axis_tx_tdata; 
  wire [KEEP_WIDTH-1:0]     s_axis_tx_tkeep;
  wire                      s_axis_tx_tlast;
  wire                      s_axis_tx_tvalid;
  wire [3:0]                s_axis_tx_tuser; 

  wire [C_DATA_WIDTH-1:0]   m_axis_rx_tdata; 
  wire [KEEP_WIDTH-1:0]     m_axis_rx_tkeep;
  wire                      m_axis_rx_tlast;
  wire                      m_axis_rx_tvalid;
  wire [21:0]               m_axis_rx_tuser;
  wire                      m_axis_rx_tready; 

  wire [15:0]               cfg_status_wire;
  wire                      cfg_msg_err_fatal_wire;
  wire                      tx_cfg_gnt;
  wire                      cfg_trn_pending;
  wire                      cfg_pm_send_pme_to;
  wire  [7:0]               cfg_ds_bus_number;
  wire  [4:0]               cfg_ds_device_number;
  wire [63:0]               cfg_dsn;
  wire  [2:0]               fc_sel = 3'b0;
  wire  [5:0]               rport_tx_buf_av;
  wire                      tx_err_drop;
  
  wire                      cfg_interrupt           = 1'b0;
  wire                      cfg_interrupt_assert    = 1'b0;  
  wire [7:0]                cfg_interrupt_di        = 8'd0;

  wire                      pl_directed_link_auton    = 1'b0;
  wire [1:0]                pl_directed_link_change   = 2'd0;
  wire                      pl_directed_link_speed    = 1'b0;
  wire [1:0]                pl_directed_link_width    = 2'b0;
  wire                      pl_upstream_prefer_deemph = 1'b0;
  wire                      pl_transmit_hot_rst       = 1'b0;

  localparam USER_CLK2_DIV2 = "FALSE";
  localparam USERCLK2_FREQ  = (USER_CLK2_DIV2 == "TRUE") ? 
                              (USER_CLK_FREQ == 4) ? 3 : 
                              (USER_CLK_FREQ == 3) ? 2 : 
                              USER_CLK_FREQ : 
                              USER_CLK_FREQ;

  pcie_7x_0_support #(
    .TCQ                            ( TCQ ),
    .LINK_CAP_MAX_LINK_WIDTH        ( 1 ),           
    .C_DATA_WIDTH                   ( C_DATA_WIDTH ),
    .KEEP_WIDTH                     ( KEEP_WIDTH ),
    .PCIE_REFCLK_FREQ               ( REF_CLK_FREQ ),
    .PCIE_USERCLK1_FREQ             ( USER_CLK_FREQ + 1 ),
    .PCIE_USERCLK2_FREQ             ( USERCLK2_FREQ + 1 ),             
    .PCIE_USE_MODE                  ( "1.0" ),       
    .PCIE_GT_DEVICE                 ( "GTP" )        
  ) pcie_inst (

    .pci_exp_txp                    ( TXP[0:0] ),
    .pci_exp_txn                    ( TXN[0:0] ),
    .pci_exp_rxp                    ( RXP[0:0] ),
    .pci_exp_rxn                    ( RXN[0:0] ),


    .sys_clk                        ( sys_clk ),
    .sys_rst_n                      ( rp_reset_n ),
    .pipe_mmcm_rst_n                ( 1'b1 ),        
    

    .user_clk_out                   ( user_clk ),
    .user_reset_out                 ( user_reset ),
    .user_lnk_up                    ( user_lnk_up ),
    
    .pipe_pclk_out_slave            (),
    .pipe_rxusrclk_out              (),
    .pipe_rxoutclk_out              (),
    .pipe_dclk_out                  (),
    .pipe_userclk1_out              (),
    .pipe_oobclk_out                (),
    .pipe_userclk2_out              (),
    .pipe_mmcm_lock_out             (),
    .pipe_pclk_sel_slave            ( 1'b0 ),        

    .s_axis_tx_tready               ( s_axis_tx_tready ),
    .s_axis_tx_tdata                ( s_axis_tx_tdata ),
    .s_axis_tx_tkeep                ( s_axis_tx_tkeep ),
    .s_axis_tx_tuser                ( s_axis_tx_tuser ),
    .s_axis_tx_tlast                ( s_axis_tx_tlast ),
    .s_axis_tx_tvalid               ( s_axis_tx_tvalid ),

    .m_axis_rx_tdata                ( m_axis_rx_tdata ),
    .m_axis_rx_tkeep                ( m_axis_rx_tkeep ),
    .m_axis_rx_tlast                ( m_axis_rx_tlast ),
    .m_axis_rx_tvalid               ( m_axis_rx_tvalid ),
    .m_axis_rx_tready               ( m_axis_rx_tready ), 
    .m_axis_rx_tuser                ( m_axis_rx_tuser ),

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
    
    .tx_buf_av                      ( rport_tx_buf_av ),
    .tx_err_drop                    ( tx_err_drop ),
    .tx_cfg_req                     ( ),             
    .cfg_status                     ( cfg_status_wire ),
    .cfg_msg_received_err_fatal     ( cfg_msg_err_fatal_wire ),
    
    .user_app_rdy                   (),
    .cfg_command                    (),
    .cfg_dstatus                    (),
    .cfg_dcommand                   (),
    .cfg_lstatus                    (),
    .cfg_lcommand                   (),
    .cfg_dcommand2                  (),
    .cfg_pcie_link_state            (),
    .cfg_pmcsr_pme_en               (),
    .cfg_pmcsr_powerstate           (),
    .cfg_pmcsr_pme_status           (),
    .cfg_received_func_lvl_rst      (),
    .cfg_vc_tcvc_map                (),
    .cfg_to_turnoff                 (),
    .cfg_bus_number                 (),
    .cfg_device_number              (),
    .cfg_function_number            (),
    .cfg_bridge_serr_en             (),
    .cfg_slot_control_electromech_il_ctl_pulse (),
    .cfg_root_control_syserr_corr_err_en       (),
    .cfg_root_control_syserr_non_fatal_err_en  (),
    .cfg_root_control_syserr_fatal_err_en      (),
    .cfg_root_control_pme_int_en               (),
    .cfg_aer_rooterr_corr_err_reporting_en     (),
    .cfg_aer_rooterr_non_fatal_err_reporting_en(),
    .cfg_aer_rooterr_fatal_err_reporting_en    (),
    .cfg_aer_rooterr_corr_err_received         (),
    .cfg_aer_rooterr_non_fatal_err_received    (),
    .cfg_aer_rooterr_fatal_err_received        (),

    .fc_sel                         ( fc_sel ),
    .fc_cpld                        (),
    .fc_cplh                        (),
    .fc_npd                         (),
    .fc_nph                         (),
    .fc_pd                          (),
    .fc_ph                          (),

    .cfg_mgmt_di                    ( 32'd0 ),
    .cfg_mgmt_byte_en               ( 4'h0 ),
    .cfg_mgmt_dwaddr                ( 10'd0 ),
    .cfg_mgmt_wr_en                 ( 1'b0 ),
    .cfg_mgmt_rd_en                 ( 1'b0 ),
    .cfg_mgmt_wr_rw1c_as_rw         ( 1'b0 ),
    .cfg_mgmt_wr_readonly           ( 1'b0 ),
    .cfg_mgmt_do                    (),
    .cfg_mgmt_rd_wr_done            (),

    .cfg_err_ecrc                   ( 1'b0 ),
    .cfg_err_ur                     ( 1'b0 ),
    .cfg_err_cpl_timeout            ( 1'b0 ),
    .cfg_err_cpl_unexpect           ( 1'b0 ),
    .cfg_err_cpl_abort              ( 1'b0 ),
    .cfg_err_posted                 ( 1'b0 ),
    .cfg_err_cor                    ( 1'b0 ),
    .cfg_err_atomic_egress_blocked  ( 1'b0 ),
    .cfg_err_internal_cor           ( 1'b0 ),
    .cfg_err_malformed              ( 1'b0 ),
    .cfg_err_mc_blocked             ( 1'b0 ),
    .cfg_err_poisoned               ( 1'b0 ),
    .cfg_err_norecovery             ( 1'b0 ),
    .cfg_err_tlp_cpl_header         ( 48'd0 ),
    .cfg_err_cpl_rdy                (),
    .cfg_err_locked                 ( 1'b0 ),
    .cfg_err_acs                    ( 1'b0 ),
    .cfg_err_internal_uncor         ( 1'b0 ),
    .cfg_err_aer_headerlog          ( 128'd0 ),
    .cfg_aer_interrupt_msgnum       ( 5'd0 ),
    .cfg_err_aer_headerlog_set      (),
    .cfg_aer_ecrc_check_en          (),
    .cfg_aer_ecrc_gen_en            (),

    .cfg_interrupt                  ( cfg_interrupt ),
    .cfg_interrupt_rdy              (),
    .cfg_interrupt_assert           ( cfg_interrupt_assert ),
    .cfg_interrupt_di               ( cfg_interrupt_di ),
    .cfg_interrupt_do               (),
    .cfg_interrupt_mmenable         (),
    .cfg_interrupt_msienable        (),
    .cfg_interrupt_msixenable       (),
    .cfg_interrupt_msixfm           (),
    .cfg_interrupt_stat             ( 1'b0 ),
    .cfg_pciecap_interrupt_msgnum   ( 5'd0 ),
    
    .cfg_msg_received               (),
    .cfg_msg_data                   (),
    .cfg_msg_received_pm_as_nak     (),
    .cfg_msg_received_setslotpowerlimit(),
    .cfg_msg_received_err_cor       (),
    .cfg_msg_received_err_non_fatal (),
    .cfg_msg_received_pm_pme        (),
    .cfg_msg_received_pme_to_ack    (),
    .cfg_msg_received_assert_int_a  (),
    .cfg_msg_received_assert_int_b  (),
    .cfg_msg_received_assert_int_c  (),
    .cfg_msg_received_assert_int_d  (),
    .cfg_msg_received_deassert_int_a(),
    .cfg_msg_received_deassert_int_b(),
    .cfg_msg_received_deassert_int_c(),
    .cfg_msg_received_deassert_int_d(),

    .pl_directed_link_change        ( pl_directed_link_change ),
    .pl_directed_link_width         ( pl_directed_link_width ),
    .pl_directed_link_speed         ( pl_directed_link_speed ),
    .pl_directed_link_auton         ( pl_directed_link_auton ),
    .pl_upstream_prefer_deemph      ( pl_upstream_prefer_deemph ),
    .pl_sel_lnk_rate                (),
    .pl_sel_lnk_width               (),
    .pl_ltssm_state                 (),
    .pl_lane_reversal_mode          (),
    .pl_phy_lnk_up                  (),
    .pl_tx_pm_state                 (),
    .pl_rx_pm_state                 (),
    .pl_link_upcfg_cap              (),
    .pl_link_gen2_cap               (),
    .pl_link_partner_gen2_supported (),
    .pl_initial_link_width          (),
    .pl_directed_change_done        (),
    .pl_received_hot_rst            (),
    .pl_transmit_hot_rst            ( pl_transmit_hot_rst ),
    .pl_downstream_deemph_source    ( 1'b0 ), 

    .pcie_drp_clk                   ( 1'b1 ), 
    .pcie_drp_en                    ( 1'b0 ),
    .pcie_drp_we                    ( 1'b0 ),
    .pcie_drp_addr                  ( 9'd0 ),
    .pcie_drp_di                    ( 16'd0 ),
    .pcie_drp_rdy                   (),
    .pcie_drp_do                    ()
  );

  riscv_pcie_soc soc_inst (
    .clk                        ( user_clk ),          
    .resetn                     ( ~user_reset && user_lnk_up ),       

    .s_axis_tx_tdata            ( s_axis_tx_tdata ),
    .s_axis_tx_tkeep            ( s_axis_tx_tkeep ),
    .s_axis_tx_tlast            ( s_axis_tx_tlast ),
    .s_axis_tx_tvalid           ( s_axis_tx_tvalid ),
    .s_axis_tx_tready           ( s_axis_tx_tready ),

    .m_axis_rx_tdata            ( m_axis_rx_tdata ),
    .m_axis_rx_tkeep            ( m_axis_rx_tkeep ),
    .m_axis_rx_tlast            ( m_axis_rx_tlast ),
    .m_axis_rx_tvalid           ( m_axis_rx_tvalid ),
    .m_axis_rx_tready           ( m_axis_rx_tready ),
    
    .cfg_status                 ( cfg_status_wire ),        
    .cfg_msg_received_err_fatal ( cfg_msg_err_fatal_wire ),  
    
    .tx_buf_av                  ( rport_tx_buf_av ) 
  );
  
  assign led_link_up = user_lnk_up;
  assign clk_req = 1'b0;

endmodule