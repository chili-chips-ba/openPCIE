module silicon_core (
	trn_td,
	trn_trem,
	trn_tsof,
	trn_teof,
	trn_tsrc_rdy,
	trn_tsrc_dsc,
	trn_terrfwd,
	trn_tecrc_gen,
	trn_tstr,
	trn_tcfg_gnt,
	trn_rdst_rdy,
	trn_rnp_req,
	trn_rfcp_ret,
	trn_rnp_ok,
	trn_fc_sel,
	trn_tdllp_data,
	trn_tdllp_src_rdy,
	ll2_tlp_rcv,
	ll2_send_enter_l1,
	ll2_send_enter_l23,
	ll2_send_as_req_l1,
	ll2_send_pm_ack,
	pl2_directed_lstate,
	ll2_suspend_now,
	tl2_ppm_suspend_req,
	tl2_aspm_suspend_credit_check,
	pl_directed_link_change,
	pl_directed_link_width,
	pl_directed_link_speed,
	pl_directed_link_auton,
	pl_upstream_prefer_deemph,
	pl_downstream_deemph_source,
	pl_directed_ltssm_new_vld,
	pl_directed_ltssm_new,
	pl_directed_ltssm_stall,
	pipe_rx0_char_is_k,
	pipe_rx1_char_is_k,
	pipe_rx2_char_is_k,
	pipe_rx3_char_is_k,
	pipe_rx4_char_is_k,
	pipe_rx5_char_is_k,
	pipe_rx6_char_is_k,
	pipe_rx7_char_is_k,
	pipe_rx0_valid,
	pipe_rx1_valid,
	pipe_rx2_valid,
	pipe_rx3_valid,
	pipe_rx4_valid,
	pipe_rx5_valid,
	pipe_rx6_valid,
	pipe_rx7_valid,
	pipe_rx0_data,
	pipe_rx1_data,
	pipe_rx2_data,
	pipe_rx3_data,
	pipe_rx4_data,
	pipe_rx5_data,
	pipe_rx6_data,
	pipe_rx7_data,
	pipe_rx0_chanisaligned,
	pipe_rx1_chanisaligned,
	pipe_rx2_chanisaligned,
	pipe_rx3_chanisaligned,
	pipe_rx4_chanisaligned,
	pipe_rx5_chanisaligned,
	pipe_rx6_chanisaligned,
	pipe_rx7_chanisaligned,
	pipe_rx0_status,
	pipe_rx1_status,
	pipe_rx2_status,
	pipe_rx3_status,
	pipe_rx4_status,
	pipe_rx5_status,
	pipe_rx6_status,
	pipe_rx7_status,
	pipe_rx0_phy_status,
	pipe_rx1_phy_status,
	pipe_rx2_phy_status,
	pipe_rx3_phy_status,
	pipe_rx4_phy_status,
	pipe_rx5_phy_status,
	pipe_rx6_phy_status,
	pipe_rx7_phy_status,
	pipe_rx0_elec_idle,
	pipe_rx1_elec_idle,
	pipe_rx2_elec_idle,
	pipe_rx3_elec_idle,
	pipe_rx4_elec_idle,
	pipe_rx5_elec_idle,
	pipe_rx6_elec_idle,
	pipe_rx7_elec_idle,
	pipe_clk,
	user_clk,
	user_clk2,
	sys_rst_n,
	cm_rst_n,
	cm_sticky_rst_n,
	func_lvl_rst_n,
	tl_rst_n,
	dl_rst_n,
	pl_rst_n,
	pl_transmit_hot_rst,
	cfg_mgmt_di,
	cfg_mgmt_byte_en_n,
	cfg_mgmt_dwaddr,
	cfg_mgmt_wr_rw1c_as_rw_n,
	cfg_mgmt_wr_readonly_n,
	cfg_mgmt_wr_en_n,
	cfg_mgmt_rd_en_n,
	cfg_err_malformed_n,
	cfg_err_cor_n,
	cfg_err_ur_n,
	cfg_err_ecrc_n,
	cfg_err_cpl_timeout_n,
	cfg_err_cpl_abort_n,
	cfg_err_cpl_unexpect_n,
	cfg_err_poisoned_n,
	cfg_err_acs_n,
	cfg_err_atomic_egress_blocked_n,
	cfg_err_mc_blocked_n,
	cfg_err_internal_uncor_n,
	cfg_err_internal_cor_n,
	cfg_err_posted_n,
	cfg_err_locked_n,
	cfg_err_norecovery_n,
	cfg_err_aer_headerlog,
	cfg_err_tlp_cpl_header,
	cfg_interrupt_n,
	cfg_interrupt_di,
	cfg_interrupt_assert_n,
	cfg_interrupt_stat_n,
	cfg_ds_bus_number,
	cfg_ds_device_number,
	cfg_ds_function_number,
	cfg_port_number,
	cfg_pm_halt_aspm_l0s_n,
	cfg_pm_halt_aspm_l1_n,
	cfg_pm_force_state_en_n,
	cfg_pm_force_state,
	cfg_pm_wake_n,
	cfg_pm_turnoff_ok_n,
	cfg_pm_send_pme_to_n,
	cfg_pciecap_interrupt_msgnum,
	cfg_trn_pending_n,
	cfg_force_mps,
	cfg_force_common_clock_off,
	cfg_force_extended_sync_on,
	cfg_dsn,
	cfg_aer_interrupt_msgnum,
	cfg_dev_id,
	cfg_vend_id,
	cfg_rev_id,
	cfg_subsys_id,
	cfg_subsys_vend_id,
	drp_clk,
	drp_en,
	drp_we,
	drp_addr,
	drp_di,
	dbg_mode,
	dbg_sub_mode,
	pl_dbg_mode,
	trn_clk,
	trn_tdst_rdy,
	trn_terr_drop,
	trn_tbuf_av,
	trn_tcfg_req,
	trn_rd,
	trn_rrem,
	trn_rsof,
	trn_reof,
	trn_rsrc_rdy,
	trn_rsrc_dsc,
	trn_recrc_err,
	trn_rerrfwd,
	trn_rbar_hit,
	trn_lnk_up,
	trn_fc_ph,
	trn_fc_pd,
	trn_fc_nph,
	trn_fc_npd,
	trn_fc_cplh,
	trn_fc_cpld,
	trn_tdllp_dst_rdy,
	trn_rdllp_data,
	trn_rdllp_src_rdy,
	ll2_tfc_init1_seq,
	ll2_tfc_init2_seq,
	pl2_suspend_ok,
	pl2_recovery,
	pl2_rx_elec_idle,
	pl2_rx_pm_state,
	pl2_l0_req,
	ll2_suspend_ok,
	ll2_tx_idle,
	ll2_link_status,
	tl2_ppm_suspend_ok,
	tl2_aspm_suspend_req,
	tl2_aspm_suspend_credit_check_ok,
	pl2_link_up,
	pl2_receiver_err,
	ll2_receiver_err,
	ll2_protocol_err,
	ll2_bad_tlp_err,
	ll2_bad_dllp_err,
	ll2_replay_ro_err,
	ll2_replay_to_err,
	tl2_err_hdr,
	tl2_err_malformed,
	tl2_err_rxoverflow,
	tl2_err_fcpe,
	pl_sel_lnk_rate,
	pl_sel_lnk_width,
	pl_ltssm_state,
	pl_lane_reversal_mode,
	pl_phy_lnk_up_n,
	pl_tx_pm_state,
	pl_rx_pm_state,
	pl_link_upcfg_cap,
	pl_link_gen2_cap,
	pl_link_partner_gen2_supported,
	pl_initial_link_width,
	pl_directed_change_done,
	pipe_tx_rcvr_det,
	pipe_tx_reset,
	pipe_tx_rate,
	pipe_tx_deemph,
	pipe_tx_margin,
	pipe_rx0_polarity,
	pipe_rx1_polarity,
	pipe_rx2_polarity,
	pipe_rx3_polarity,
	pipe_rx4_polarity,
	pipe_rx5_polarity,
	pipe_rx6_polarity,
	pipe_rx7_polarity,
	pipe_tx0_compliance,
	pipe_tx1_compliance,
	pipe_tx2_compliance,
	pipe_tx3_compliance,
	pipe_tx4_compliance,
	pipe_tx5_compliance,
	pipe_tx6_compliance,
	pipe_tx7_compliance,
	pipe_tx0_char_is_k,
	pipe_tx1_char_is_k,
	pipe_tx2_char_is_k,
	pipe_tx3_char_is_k,
	pipe_tx4_char_is_k,
	pipe_tx5_char_is_k,
	pipe_tx6_char_is_k,
	pipe_tx7_char_is_k,
	pipe_tx0_data,
	pipe_tx1_data,
	pipe_tx2_data,
	pipe_tx3_data,
	pipe_tx4_data,
	pipe_tx5_data,
	pipe_tx6_data,
	pipe_tx7_data,
	pipe_tx0_elec_idle,
	pipe_tx1_elec_idle,
	pipe_tx2_elec_idle,
	pipe_tx3_elec_idle,
	pipe_tx4_elec_idle,
	pipe_tx5_elec_idle,
	pipe_tx6_elec_idle,
	pipe_tx7_elec_idle,
	pipe_tx0_powerdown,
	pipe_tx1_powerdown,
	pipe_tx2_powerdown,
	pipe_tx3_powerdown,
	pipe_tx4_powerdown,
	pipe_tx5_powerdown,
	pipe_tx6_powerdown,
	pipe_tx7_powerdown,
	user_rst_n,
	pl_received_hot_rst,
	received_func_lvl_rst_n,
	lnk_clk_en,
	cfg_mgmt_do,
	cfg_mgmt_rd_wr_done_n,
	cfg_err_aer_headerlog_set_n,
	cfg_err_cpl_rdy_n,
	cfg_interrupt_rdy_n,
	cfg_interrupt_mmenable,
	cfg_interrupt_msienable,
	cfg_interrupt_do,
	cfg_interrupt_msixenable,
	cfg_interrupt_msixfm,
	cfg_msg_received,
	cfg_msg_data,
	cfg_msg_received_err_cor,
	cfg_msg_received_err_non_fatal,
	cfg_msg_received_err_fatal,
	cfg_msg_received_assert_int_a,
	cfg_msg_received_deassert_int_a,
	cfg_msg_received_assert_int_b,
	cfg_msg_received_deassert_int_b,
	cfg_msg_received_assert_int_c,
	cfg_msg_received_deassert_int_c,
	cfg_msg_received_assert_int_d,
	cfg_msg_received_deassert_int_d,
	cfg_msg_received_pm_pme,
	cfg_msg_received_pme_to_ack,
	cfg_msg_received_pme_to,
	cfg_msg_received_setslotpowerlimit,
	cfg_msg_received_unlock,
	cfg_msg_received_pm_as_nak,
	cfg_pcie_link_state,
	cfg_pm_rcv_as_req_l1_n,
	cfg_pm_rcv_enter_l1_n,
	cfg_pm_rcv_enter_l23_n,
	cfg_pm_rcv_req_ack_n,
	cfg_pmcsr_powerstate,
	cfg_pmcsr_pme_en,
	cfg_pmcsr_pme_status,
	cfg_transaction,
	cfg_transaction_type,
	cfg_transaction_addr,
	cfg_command_io_enable,
	cfg_command_mem_enable,
	cfg_command_bus_master_enable,
	cfg_command_interrupt_disable,
	cfg_command_serr_en,
	cfg_bridge_serr_en,
	cfg_dev_status_corr_err_detected,
	cfg_dev_status_non_fatal_err_detected,
	cfg_dev_status_fatal_err_detected,
	cfg_dev_status_ur_detected,
	cfg_dev_control_corr_err_reporting_en,
	cfg_dev_control_non_fatal_reporting_en,
	cfg_dev_control_fatal_err_reporting_en,
	cfg_dev_control_ur_err_reporting_en,
	cfg_dev_control_enable_ro,
	cfg_dev_control_max_payload,
	cfg_dev_control_ext_tag_en,
	cfg_dev_control_phantom_en,
	cfg_dev_control_aux_power_en,
	cfg_dev_control_no_snoop_en,
	cfg_dev_control_max_read_req,
	cfg_link_status_current_speed,
	cfg_link_status_negotiated_width,
	cfg_link_status_link_training,
	cfg_link_status_dll_active,
	cfg_link_status_bandwidth_status,
	cfg_link_status_auto_bandwidth_status,
	cfg_link_control_aspm_control,
	cfg_link_control_rcb,
	cfg_link_control_link_disable,
	cfg_link_control_retrain_link,
	cfg_link_control_common_clock,
	cfg_link_control_extended_sync,
	cfg_link_control_clock_pm_en,
	cfg_link_control_hw_auto_width_dis,
	cfg_link_control_bandwidth_int_en,
	cfg_link_control_auto_bandwidth_int_en,
	cfg_dev_control2_cpl_timeout_val,
	cfg_dev_control2_cpl_timeout_dis,
	cfg_dev_control2_ari_forward_en,
	cfg_dev_control2_atomic_requester_en,
	cfg_dev_control2_atomic_egress_block,
	cfg_dev_control2_ido_req_en,
	cfg_dev_control2_ido_cpl_en,
	cfg_dev_control2_ltr_en,
	cfg_dev_control2_tlp_prefix_block,
	cfg_slot_control_electromech_il_ctl_pulse,
	cfg_root_control_syserr_corr_err_en,
	cfg_root_control_syserr_non_fatal_err_en,
	cfg_root_control_syserr_fatal_err_en,
	cfg_root_control_pme_int_en,
	cfg_aer_ecrc_check_en,
	cfg_aer_ecrc_gen_en,
	cfg_aer_rooterr_corr_err_reporting_en,
	cfg_aer_rooterr_non_fatal_err_reporting_en,
	cfg_aer_rooterr_fatal_err_reporting_en,
	cfg_aer_rooterr_corr_err_received,
	cfg_aer_rooterr_non_fatal_err_received,
	cfg_aer_rooterr_fatal_err_received,
	cfg_vc_tcvc_map,
	drp_rdy,
	drp_do,
	dbg_vec_a,
	dbg_vec_b,
	dbg_vec_c,
	dbg_sclr_a,
	dbg_sclr_b,
	dbg_sclr_c,
	dbg_sclr_d,
	dbg_sclr_e,
	dbg_sclr_f,
	dbg_sclr_g,
	dbg_sclr_h,
	dbg_sclr_i,
	dbg_sclr_j,
	dbg_sclr_k,
	pl_dbg_vec
);
	localparam [11:0] AER_BASE_PTR = 12'h000;
	localparam AER_CAP_ECRC_CHECK_CAPABLE = "FALSE";
	localparam AER_CAP_ECRC_GEN_CAPABLE = "FALSE";
	localparam [15:0] AER_CAP_ID = 16'h0001;
	localparam AER_CAP_MULTIHEADER = "FALSE";
	localparam [11:0] AER_CAP_NEXTPTR = 12'h000;
	localparam AER_CAP_ON = "FALSE";
	localparam [23:0] AER_CAP_OPTIONAL_ERR_SUPPORT = 24'h000000;
	localparam AER_CAP_PERMIT_ROOTERR_UPDATE = "FALSE";
	localparam [3:0] AER_CAP_VERSION = 4'h1;
	localparam ALLOW_X8_GEN2 = "FALSE";
	localparam [31:0] BAR0 = 32'hfffff800;
	localparam [31:0] BAR1 = 32'h00000000;
	localparam [31:0] BAR2 = 32'h00ff00ff;
	localparam [31:0] BAR3 = 32'hffff0000;
	localparam [31:0] BAR4 = 32'hff00ff00;
	localparam [31:0] BAR5 = 32'h00000000;
	localparam [7:0] CAPABILITIES_PTR = 8'h40;
	localparam [31:0] CARDBUS_CIS_POINTER = 32'h00000000;
	localparam CFG_ECRC_ERR_CPLSTAT = 0;
	localparam [23:0] CLASS_CODE = 24'h060000;
	localparam CMD_INTX_IMPLEMENTED = "TRUE";
	localparam CPL_TIMEOUT_DISABLE_SUPPORTED = "FALSE";
	localparam [3:0] CPL_TIMEOUT_RANGES_SUPPORTED = 4'h2;
	localparam [6:0] CRM_MODULE_RSTS = 7'h00;
	localparam C_DATA_WIDTH = 64;
	localparam REM_WIDTH = 1;
	localparam DEV_CAP2_ARI_FORWARDING_SUPPORTED = "FALSE";
	localparam DEV_CAP2_ATOMICOP32_COMPLETER_SUPPORTED = "FALSE";
	localparam DEV_CAP2_ATOMICOP64_COMPLETER_SUPPORTED = "FALSE";
	localparam DEV_CAP2_ATOMICOP_ROUTING_SUPPORTED = "FALSE";
	localparam DEV_CAP2_CAS128_COMPLETER_SUPPORTED = "FALSE";
	localparam DEV_CAP2_ENDEND_TLP_PREFIX_SUPPORTED = "FALSE";
	localparam DEV_CAP2_EXTENDED_FMT_FIELD_SUPPORTED = "FALSE";
	localparam DEV_CAP2_LTR_MECHANISM_SUPPORTED = "FALSE";
	localparam [1:0] DEV_CAP2_MAX_ENDEND_TLP_PREFIXES = 2'h0;
	localparam DEV_CAP2_NO_RO_ENABLED_PRPR_PASSING = "FALSE";
	localparam [1:0] DEV_CAP2_TPH_COMPLETER_SUPPORTED = 2'b00;
	localparam DEV_CAP_ENABLE_SLOT_PWR_LIMIT_SCALE = "TRUE";
	localparam DEV_CAP_ENABLE_SLOT_PWR_LIMIT_VALUE = "TRUE";
	localparam integer DEV_CAP_ENDPOINT_L0S_LATENCY = 0;
	localparam integer DEV_CAP_ENDPOINT_L1_LATENCY = 0;
	localparam DEV_CAP_EXT_TAG_SUPPORTED = "FALSE";
	localparam DEV_CAP_FUNCTION_LEVEL_RESET_CAPABLE = "FALSE";
	localparam integer DEV_CAP_MAX_PAYLOAD_SUPPORTED = 2;
	localparam integer DEV_CAP_PHANTOM_FUNCTIONS_SUPPORT = 0;
	localparam DEV_CAP_ROLE_BASED_ERROR = "TRUE";
	localparam integer DEV_CAP_RSVD_14_12 = 0;
	localparam integer DEV_CAP_RSVD_17_16 = 0;
	localparam integer DEV_CAP_RSVD_31_29 = 0;
	localparam DEV_CONTROL_AUX_POWER_SUPPORTED = "FALSE";
	localparam DEV_CONTROL_EXT_TAG_DEFAULT = "FALSE";
	localparam DISABLE_ASPM_L1_TIMER = "FALSE";
	localparam DISABLE_BAR_FILTERING = "FALSE";
	localparam DISABLE_ERR_MSG = "FALSE";
	localparam DISABLE_ID_CHECK = "FALSE";
	localparam DISABLE_LANE_REVERSAL = "TRUE";
	localparam DISABLE_LOCKED_FILTER = "FALSE";
	localparam DISABLE_PPM_FILTER = "FALSE";
	localparam DISABLE_RX_POISONED_RESP = "FALSE";
	localparam DISABLE_RX_TC_FILTER = "FALSE";
	localparam DISABLE_SCRAMBLING = "FALSE";
	localparam [7:0] DNSTREAM_LINK_NUM = 8'h00;
	localparam [11:0] DSN_BASE_PTR = 12'h100;
	localparam [15:0] DSN_CAP_ID = 16'h0003;
	localparam [11:0] DSN_CAP_NEXTPTR = 12'h000;
	localparam DSN_CAP_ON = "TRUE";
	localparam [3:0] DSN_CAP_VERSION = 4'h1;
	localparam [10:0] ENABLE_MSG_ROUTE = 11'b00000000000;
	localparam ENABLE_RX_TD_ECRC_TRIM = "FALSE";
	localparam ENDEND_TLP_PREFIX_FORWARDING_SUPPORTED = "FALSE";
	localparam ENTER_RVRY_EI_L0 = "TRUE";
	localparam EXIT_LOOPBACK_ON_EI = "TRUE";
	localparam [31:0] EXPANSION_ROM = 32'h00000000;
	localparam [5:0] EXT_CFG_CAP_PTR = 6'h3f;
	localparam [9:0] EXT_CFG_XP_CAP_PTR = 10'h3ff;
	localparam [7:0] HEADER_TYPE = 8'h01;
	localparam [4:0] INFER_EI = 5'h00;
	localparam [7:0] INTERRUPT_PIN = 8'h01;
	localparam INTERRUPT_STAT_AUTO = "TRUE";
	localparam IS_SWITCH = "FALSE";
	localparam [9:0] LAST_CONFIG_DWORD = 10'h3ff;
	localparam LINK_CAP_ASPM_OPTIONALITY = "FALSE";
	localparam integer LINK_CAP_ASPM_SUPPORT = 1;
	localparam LINK_CAP_CLOCK_POWER_MANAGEMENT = "FALSE";
	localparam LINK_CAP_DLL_LINK_ACTIVE_REPORTING_CAP = "FALSE";
	localparam integer LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN1 = 7;
	localparam integer LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN2 = 7;
	localparam integer LINK_CAP_L0S_EXIT_LATENCY_GEN1 = 7;
	localparam integer LINK_CAP_L0S_EXIT_LATENCY_GEN2 = 7;
	localparam integer LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN1 = 7;
	localparam integer LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN2 = 7;
	localparam integer LINK_CAP_L1_EXIT_LATENCY_GEN1 = 7;
	localparam integer LINK_CAP_L1_EXIT_LATENCY_GEN2 = 7;
	localparam LINK_CAP_LINK_BANDWIDTH_NOTIFICATION_CAP = "FALSE";
	localparam integer LINK_CAP_RSVD_23 = 0;
	localparam LINK_CAP_SURPRISE_DOWN_ERROR_CAPABLE = "FALSE";
	localparam integer LINK_CONTROL_RCB = 0;
	localparam LINK_CTRL2_DEEMPHASIS = "FALSE";
	localparam LINK_CTRL2_HW_AUTONOMOUS_SPEED_DISABLE = "FALSE";
	localparam LINK_STATUS_SLOT_CLOCK_CONFIG = "TRUE";
	localparam [14:0] LL_ACK_TIMEOUT = 15'h0000;
	localparam LL_ACK_TIMEOUT_EN = "FALSE";
	localparam integer LL_ACK_TIMEOUT_FUNC = 0;
	localparam [14:0] LL_REPLAY_TIMEOUT = 15'h0000;
	localparam LL_REPLAY_TIMEOUT_EN = "FALSE";
	localparam integer LL_REPLAY_TIMEOUT_FUNC = 1;
	localparam MPS_FORCE = "FALSE";
	localparam [7:0] MSIX_BASE_PTR = 8'h9c;
	localparam [7:0] MSIX_CAP_ID = 8'h11;
	localparam [7:0] MSIX_CAP_NEXTPTR = 8'h00;
	localparam MSIX_CAP_ON = "FALSE";
	localparam integer MSIX_CAP_PBA_BIR = 0;
	localparam [28:0] MSIX_CAP_PBA_OFFSET = 29'h00000000;
	localparam integer MSIX_CAP_TABLE_BIR = 0;
	localparam [28:0] MSIX_CAP_TABLE_OFFSET = 29'h00000000;
	localparam [10:0] MSIX_CAP_TABLE_SIZE = 11'h000;
	localparam [7:0] MSI_BASE_PTR = 8'h48;
	localparam MSI_CAP_64_BIT_ADDR_CAPABLE = "TRUE";
	localparam [7:0] MSI_CAP_ID = 8'h05;
	localparam integer MSI_CAP_MULTIMSGCAP = 0;
	localparam integer MSI_CAP_MULTIMSG_EXTENSION = 0;
	localparam [7:0] MSI_CAP_NEXTPTR = 8'h60;
	localparam MSI_CAP_ON = "TRUE";
	localparam MSI_CAP_PER_VECTOR_MASKING_CAPABLE = "FALSE";
	localparam integer N_FTS_COMCLK_GEN1 = 255;
	localparam integer N_FTS_COMCLK_GEN2 = 255;
	localparam integer N_FTS_GEN1 = 255;
	localparam integer N_FTS_GEN2 = 255;
	localparam [7:0] PCIE_BASE_PTR = 8'h60;
	localparam [7:0] PCIE_CAP_CAPABILITY_ID = 8'h10;
	localparam [3:0] PCIE_CAP_CAPABILITY_VERSION = 4'h2;
	localparam [3:0] PCIE_CAP_DEVICE_PORT_TYPE = 4'h4;
	localparam [7:0] PCIE_CAP_NEXTPTR = 8'h00;
	localparam PCIE_CAP_ON = "TRUE";
	localparam integer PCIE_CAP_RSVD_15_14 = 0;
	localparam PCIE_CAP_SLOT_IMPLEMENTED = "FALSE";
	localparam integer PCIE_REVISION = 2;
	localparam integer PL_AUTO_CONFIG = 0;
	localparam PL_FAST_TRAIN = "FALSE";
	localparam [14:0] PM_ASPML0S_TIMEOUT = 15'h0000;
	localparam PM_ASPML0S_TIMEOUT_EN = "FALSE";
	localparam integer PM_ASPML0S_TIMEOUT_FUNC = 0;
	localparam PM_ASPM_FASTEXIT = "FALSE";
	localparam [7:0] PM_BASE_PTR = 8'h40;
	localparam integer PM_CAP_AUXCURRENT = 0;
	localparam PM_CAP_D1SUPPORT = "FALSE";
	localparam PM_CAP_D2SUPPORT = "FALSE";
	localparam PM_CAP_DSI = "FALSE";
	localparam [7:0] PM_CAP_ID = 8'h01;
	localparam [7:0] PM_CAP_NEXTPTR = 8'h48;
	localparam PM_CAP_ON = "TRUE";
	localparam [4:0] PM_CAP_PMESUPPORT = 5'h0f;
	localparam PM_CAP_PME_CLOCK = "FALSE";
	localparam integer PM_CAP_RSVD_04 = 0;
	localparam integer PM_CAP_VERSION = 3;
	localparam PM_CSR_B2B3 = "FALSE";
	localparam PM_CSR_BPCCEN = "FALSE";
	localparam PM_CSR_NOSOFTRST = "TRUE";
	localparam [7:0] PM_DATA0 = 8'h00;
	localparam [7:0] PM_DATA1 = 8'h00;
	localparam [7:0] PM_DATA2 = 8'h00;
	localparam [7:0] PM_DATA3 = 8'h00;
	localparam [7:0] PM_DATA4 = 8'h00;
	localparam [7:0] PM_DATA5 = 8'h00;
	localparam [7:0] PM_DATA6 = 8'h00;
	localparam [7:0] PM_DATA7 = 8'h00;
	localparam [1:0] PM_DATA_SCALE0 = 2'h0;
	localparam [1:0] PM_DATA_SCALE1 = 2'h0;
	localparam [1:0] PM_DATA_SCALE2 = 2'h0;
	localparam [1:0] PM_DATA_SCALE3 = 2'h0;
	localparam [1:0] PM_DATA_SCALE4 = 2'h0;
	localparam [1:0] PM_DATA_SCALE5 = 2'h0;
	localparam [1:0] PM_DATA_SCALE6 = 2'h0;
	localparam [1:0] PM_DATA_SCALE7 = 2'h0;
	localparam PM_MF = "FALSE";
	localparam [11:0] RBAR_BASE_PTR = 12'h000;
	localparam [4:0] RBAR_CAP_CONTROL_ENCODEDBAR0 = 5'h00;
	localparam [4:0] RBAR_CAP_CONTROL_ENCODEDBAR1 = 5'h00;
	localparam [4:0] RBAR_CAP_CONTROL_ENCODEDBAR2 = 5'h00;
	localparam [4:0] RBAR_CAP_CONTROL_ENCODEDBAR3 = 5'h00;
	localparam [4:0] RBAR_CAP_CONTROL_ENCODEDBAR4 = 5'h00;
	localparam [4:0] RBAR_CAP_CONTROL_ENCODEDBAR5 = 5'h00;
	localparam [15:0] RBAR_CAP_ID = 16'h0015;
	localparam [2:0] RBAR_CAP_INDEX0 = 3'h0;
	localparam [2:0] RBAR_CAP_INDEX1 = 3'h0;
	localparam [2:0] RBAR_CAP_INDEX2 = 3'h0;
	localparam [2:0] RBAR_CAP_INDEX3 = 3'h0;
	localparam [2:0] RBAR_CAP_INDEX4 = 3'h0;
	localparam [2:0] RBAR_CAP_INDEX5 = 3'h0;
	localparam [11:0] RBAR_CAP_NEXTPTR = 12'h000;
	localparam RBAR_CAP_ON = "FALSE";
	localparam [31:0] RBAR_CAP_SUP0 = 32'h00000001;
	localparam [31:0] RBAR_CAP_SUP1 = 32'h00000001;
	localparam [31:0] RBAR_CAP_SUP2 = 32'h00000001;
	localparam [31:0] RBAR_CAP_SUP3 = 32'h00000001;
	localparam [31:0] RBAR_CAP_SUP4 = 32'h00000001;
	localparam [31:0] RBAR_CAP_SUP5 = 32'h00000001;
	localparam [3:0] RBAR_CAP_VERSION = 4'h1;
	localparam [2:0] RBAR_NUM = 3'h0;
	localparam integer RECRC_CHK = 0;
	localparam RECRC_CHK_TRIM = "FALSE";
	localparam ROOT_CAP_CRS_SW_VISIBILITY = "FALSE";
	localparam [1:0] RP_AUTO_SPD = 2'h1;
	localparam [4:0] RP_AUTO_SPD_LOOPCNT = 5'h1f;
	localparam SELECT_DLL_IF = "FALSE";
	localparam SLOT_CAP_ATT_BUTTON_PRESENT = "FALSE";
	localparam SLOT_CAP_ATT_INDICATOR_PRESENT = "FALSE";
	localparam SLOT_CAP_ELEC_INTERLOCK_PRESENT = "FALSE";
	localparam SLOT_CAP_HOTPLUG_CAPABLE = "FALSE";
	localparam SLOT_CAP_HOTPLUG_SURPRISE = "FALSE";
	localparam SLOT_CAP_MRL_SENSOR_PRESENT = "FALSE";
	localparam SLOT_CAP_NO_CMD_COMPLETED_SUPPORT = "FALSE";
	localparam [12:0] SLOT_CAP_PHYSICAL_SLOT_NUM = 13'h0000;
	localparam SLOT_CAP_POWER_CONTROLLER_PRESENT = "FALSE";
	localparam SLOT_CAP_POWER_INDICATOR_PRESENT = "FALSE";
	localparam integer SLOT_CAP_SLOT_POWER_LIMIT_SCALE = 0;
	localparam [7:0] SLOT_CAP_SLOT_POWER_LIMIT_VALUE = 8'h00;
	localparam integer SPARE_BIT0 = 0;
	localparam integer SPARE_BIT1 = 0;
	localparam integer SPARE_BIT2 = 0;
	localparam integer SPARE_BIT3 = 0;
	localparam integer SPARE_BIT4 = 0;
	localparam integer SPARE_BIT5 = 0;
	localparam integer SPARE_BIT6 = 0;
	localparam integer SPARE_BIT7 = 0;
	localparam integer SPARE_BIT8 = 0;
	localparam [7:0] SPARE_BYTE0 = 8'h00;
	localparam [7:0] SPARE_BYTE1 = 8'h00;
	localparam [7:0] SPARE_BYTE2 = 8'h00;
	localparam [7:0] SPARE_BYTE3 = 8'h00;
	localparam [31:0] SPARE_WORD0 = 32'h00000000;
	localparam [31:0] SPARE_WORD1 = 32'h00000000;
	localparam [31:0] SPARE_WORD2 = 32'h00000000;
	localparam [31:0] SPARE_WORD3 = 32'h00000000;
	localparam SSL_MESSAGE_AUTO = "FALSE";
	localparam TECRC_EP_INV = "FALSE";
	localparam TL_RBYPASS = "FALSE";
	localparam integer TL_RX_RAM_RADDR_LATENCY = 0;
	localparam integer TL_RX_RAM_RDATA_LATENCY = 2;
	localparam integer TL_RX_RAM_WRITE_LATENCY = 0;
	localparam TL_TFC_DISABLE = "FALSE";
	localparam TL_TX_CHECKS_DISABLE = "FALSE";
	localparam integer TL_TX_RAM_RADDR_LATENCY = 0;
	localparam integer TL_TX_RAM_RDATA_LATENCY = 2;
	localparam integer TL_TX_RAM_WRITE_LATENCY = 0;
	localparam TRN_DW = "FALSE";
	localparam TRN_NP_FC = "TRUE";
	localparam UPCONFIG_CAPABLE = "TRUE";
	localparam UPSTREAM_FACING = "FALSE";
	localparam UR_ATOMIC = "FALSE";
	localparam UR_CFG1 = "TRUE";
	localparam UR_INV_REQ = "TRUE";
	localparam UR_PRS_RESPONSE = "TRUE";
	localparam USER_CLK2_DIV2 = "FALSE";
	localparam integer USER_CLK_FREQ = 1;
	localparam USE_RID_PINS = "FALSE";
	localparam VC0_CPL_INFINITE = "TRUE";
	localparam [12:0] VC0_RX_RAM_LIMIT = 13'h07ff;
	localparam integer VC0_TOTAL_CREDITS_CD = 461;
	localparam integer VC0_TOTAL_CREDITS_CH = 36;
	localparam integer VC0_TOTAL_CREDITS_NPD = 24;
	localparam integer VC0_TOTAL_CREDITS_NPH = 12;
	localparam integer VC0_TOTAL_CREDITS_PD = 437;
	localparam integer VC0_TOTAL_CREDITS_PH = 32;
	localparam integer VC0_TX_LASTPACKET = 29;
	localparam [11:0] VC_BASE_PTR = 12'h000;
	localparam [15:0] VC_CAP_ID = 16'h0002;
	localparam [11:0] VC_CAP_NEXTPTR = 12'h000;
	localparam VC_CAP_ON = "FALSE";
	localparam VC_CAP_REJECT_SNOOP_TRANSACTIONS = "FALSE";
	localparam [3:0] VC_CAP_VERSION = 4'h1;
	localparam [11:0] VSEC_BASE_PTR = 12'h000;
	localparam [15:0] VSEC_CAP_HDR_ID = 16'h1234;
	localparam [3:0] VSEC_CAP_HDR_REVISION = 4'h1;
	localparam [15:0] VSEC_CAP_ID = 16'h000b;
	localparam VSEC_CAP_IS_LINK_VISIBLE = "TRUE";
	localparam [11:0] VSEC_CAP_NEXTPTR = 12'h000;
	localparam VSEC_CAP_ON = "FALSE";
	localparam [3:0] VSEC_CAP_VERSION = 4'h1;
	input wire [63:0] trn_td;
	input wire [0:0] trn_trem;
	input wire trn_tsof;
	input wire trn_teof;
	input wire trn_tsrc_rdy;
	input wire trn_tsrc_dsc;
	input wire trn_terrfwd;
	input wire trn_tecrc_gen;
	input wire trn_tstr;
	input wire trn_tcfg_gnt;
	input wire trn_rdst_rdy;
	input wire trn_rnp_req;
	input wire trn_rfcp_ret;
	input wire trn_rnp_ok;
	input wire [2:0] trn_fc_sel;
	input wire [31:0] trn_tdllp_data;
	input wire trn_tdllp_src_rdy;
	input wire ll2_tlp_rcv;
	input wire ll2_send_enter_l1;
	input wire ll2_send_enter_l23;
	input wire ll2_send_as_req_l1;
	input wire ll2_send_pm_ack;
	input wire [4:0] pl2_directed_lstate;
	input wire ll2_suspend_now;
	input wire tl2_ppm_suspend_req;
	input wire tl2_aspm_suspend_credit_check;
	input wire [1:0] pl_directed_link_change;
	input wire [1:0] pl_directed_link_width;
	input wire pl_directed_link_speed;
	input wire pl_directed_link_auton;
	input wire pl_upstream_prefer_deemph;
	input wire pl_downstream_deemph_source;
	input wire pl_directed_ltssm_new_vld;
	input wire [5:0] pl_directed_ltssm_new;
	input wire pl_directed_ltssm_stall;
	input wire [1:0] pipe_rx0_char_is_k;
	input wire [1:0] pipe_rx1_char_is_k;
	input wire [1:0] pipe_rx2_char_is_k;
	input wire [1:0] pipe_rx3_char_is_k;
	input wire [1:0] pipe_rx4_char_is_k;
	input wire [1:0] pipe_rx5_char_is_k;
	input wire [1:0] pipe_rx6_char_is_k;
	input wire [1:0] pipe_rx7_char_is_k;
	input wire pipe_rx0_valid;
	input wire pipe_rx1_valid;
	input wire pipe_rx2_valid;
	input wire pipe_rx3_valid;
	input wire pipe_rx4_valid;
	input wire pipe_rx5_valid;
	input wire pipe_rx6_valid;
	input wire pipe_rx7_valid;
	input wire [15:0] pipe_rx0_data;
	input wire [15:0] pipe_rx1_data;
	input wire [15:0] pipe_rx2_data;
	input wire [15:0] pipe_rx3_data;
	input wire [15:0] pipe_rx4_data;
	input wire [15:0] pipe_rx5_data;
	input wire [15:0] pipe_rx6_data;
	input wire [15:0] pipe_rx7_data;
	input wire pipe_rx0_chanisaligned;
	input wire pipe_rx1_chanisaligned;
	input wire pipe_rx2_chanisaligned;
	input wire pipe_rx3_chanisaligned;
	input wire pipe_rx4_chanisaligned;
	input wire pipe_rx5_chanisaligned;
	input wire pipe_rx6_chanisaligned;
	input wire pipe_rx7_chanisaligned;
	input wire [2:0] pipe_rx0_status;
	input wire [2:0] pipe_rx1_status;
	input wire [2:0] pipe_rx2_status;
	input wire [2:0] pipe_rx3_status;
	input wire [2:0] pipe_rx4_status;
	input wire [2:0] pipe_rx5_status;
	input wire [2:0] pipe_rx6_status;
	input wire [2:0] pipe_rx7_status;
	input wire pipe_rx0_phy_status;
	input wire pipe_rx1_phy_status;
	input wire pipe_rx2_phy_status;
	input wire pipe_rx3_phy_status;
	input wire pipe_rx4_phy_status;
	input wire pipe_rx5_phy_status;
	input wire pipe_rx6_phy_status;
	input wire pipe_rx7_phy_status;
	input wire pipe_rx0_elec_idle;
	input wire pipe_rx1_elec_idle;
	input wire pipe_rx2_elec_idle;
	input wire pipe_rx3_elec_idle;
	input wire pipe_rx4_elec_idle;
	input wire pipe_rx5_elec_idle;
	input wire pipe_rx6_elec_idle;
	input wire pipe_rx7_elec_idle;
	input wire pipe_clk;
	input wire user_clk;
	input wire user_clk2;
	input wire sys_rst_n;
	input wire cm_rst_n;
	input wire cm_sticky_rst_n;
	input wire func_lvl_rst_n;
	input wire tl_rst_n;
	input wire dl_rst_n;
	input wire pl_rst_n;
	input wire pl_transmit_hot_rst;
	input wire [31:0] cfg_mgmt_di;
	input wire [3:0] cfg_mgmt_byte_en_n;
	input wire [9:0] cfg_mgmt_dwaddr;
	input wire cfg_mgmt_wr_rw1c_as_rw_n;
	input wire cfg_mgmt_wr_readonly_n;
	input wire cfg_mgmt_wr_en_n;
	input wire cfg_mgmt_rd_en_n;
	input wire cfg_err_malformed_n;
	input wire cfg_err_cor_n;
	input wire cfg_err_ur_n;
	input wire cfg_err_ecrc_n;
	input wire cfg_err_cpl_timeout_n;
	input wire cfg_err_cpl_abort_n;
	input wire cfg_err_cpl_unexpect_n;
	input wire cfg_err_poisoned_n;
	input wire cfg_err_acs_n;
	input wire cfg_err_atomic_egress_blocked_n;
	input wire cfg_err_mc_blocked_n;
	input wire cfg_err_internal_uncor_n;
	input wire cfg_err_internal_cor_n;
	input wire cfg_err_posted_n;
	input wire cfg_err_locked_n;
	input wire cfg_err_norecovery_n;
	input wire [127:0] cfg_err_aer_headerlog;
	input wire [47:0] cfg_err_tlp_cpl_header;
	input wire cfg_interrupt_n;
	input wire [7:0] cfg_interrupt_di;
	input wire cfg_interrupt_assert_n;
	input wire cfg_interrupt_stat_n;
	input wire [7:0] cfg_ds_bus_number;
	input wire [4:0] cfg_ds_device_number;
	input wire [2:0] cfg_ds_function_number;
	input wire [7:0] cfg_port_number;
	input wire cfg_pm_halt_aspm_l0s_n;
	input wire cfg_pm_halt_aspm_l1_n;
	input wire cfg_pm_force_state_en_n;
	input wire [1:0] cfg_pm_force_state;
	input wire cfg_pm_wake_n;
	input wire cfg_pm_turnoff_ok_n;
	input wire cfg_pm_send_pme_to_n;
	input wire [4:0] cfg_pciecap_interrupt_msgnum;
	input wire cfg_trn_pending_n;
	input wire [2:0] cfg_force_mps;
	input wire cfg_force_common_clock_off;
	input wire cfg_force_extended_sync_on;
	input wire [63:0] cfg_dsn;
	input wire [4:0] cfg_aer_interrupt_msgnum;
	input wire [15:0] cfg_dev_id;
	input wire [15:0] cfg_vend_id;
	input wire [7:0] cfg_rev_id;
	input wire [15:0] cfg_subsys_id;
	input wire [15:0] cfg_subsys_vend_id;
	input wire drp_clk;
	input wire drp_en;
	input wire drp_we;
	input wire [8:0] drp_addr;
	input wire [15:0] drp_di;
	input wire [1:0] dbg_mode;
	input wire dbg_sub_mode;
	input wire [2:0] pl_dbg_mode;
	output wire trn_clk;
	output wire trn_tdst_rdy;
	output wire trn_terr_drop;
	output wire [5:0] trn_tbuf_av;
	output wire trn_tcfg_req;
	output wire [127:0] trn_rd;
	output wire [1:0] trn_rrem;
	output wire trn_rsof;
	output wire trn_reof;
	output wire trn_rsrc_rdy;
	output wire trn_rsrc_dsc;
	output wire trn_recrc_err;
	output wire trn_rerrfwd;
	output wire [7:0] trn_rbar_hit;
	output wire trn_lnk_up;
	output wire [7:0] trn_fc_ph;
	output wire [11:0] trn_fc_pd;
	output wire [7:0] trn_fc_nph;
	output wire [11:0] trn_fc_npd;
	output wire [7:0] trn_fc_cplh;
	output wire [11:0] trn_fc_cpld;
	output wire trn_tdllp_dst_rdy;
	output wire [63:0] trn_rdllp_data;
	output wire [1:0] trn_rdllp_src_rdy;
	output wire ll2_tfc_init1_seq;
	output wire ll2_tfc_init2_seq;
	output wire pl2_suspend_ok;
	output wire pl2_recovery;
	output wire pl2_rx_elec_idle;
	output wire [1:0] pl2_rx_pm_state;
	output wire pl2_l0_req;
	output wire ll2_suspend_ok;
	output wire ll2_tx_idle;
	output wire [4:0] ll2_link_status;
	output wire tl2_ppm_suspend_ok;
	output wire tl2_aspm_suspend_req;
	output wire tl2_aspm_suspend_credit_check_ok;
	output wire pl2_link_up;
	output wire pl2_receiver_err;
	output wire ll2_receiver_err;
	output wire ll2_protocol_err;
	output wire ll2_bad_tlp_err;
	output wire ll2_bad_dllp_err;
	output wire ll2_replay_ro_err;
	output wire ll2_replay_to_err;
	output wire [63:0] tl2_err_hdr;
	output wire tl2_err_malformed;
	output wire tl2_err_rxoverflow;
	output wire tl2_err_fcpe;
	output wire pl_sel_lnk_rate;
	output wire [1:0] pl_sel_lnk_width;
	output wire [5:0] pl_ltssm_state;
	output wire [1:0] pl_lane_reversal_mode;
	output wire pl_phy_lnk_up_n;
	output wire [2:0] pl_tx_pm_state;
	output wire [1:0] pl_rx_pm_state;
	output wire pl_link_upcfg_cap;
	output wire pl_link_gen2_cap;
	output wire pl_link_partner_gen2_supported;
	output wire [2:0] pl_initial_link_width;
	output wire pl_directed_change_done;
	output wire pipe_tx_rcvr_det;
	output wire pipe_tx_reset;
	output wire pipe_tx_rate;
	output wire pipe_tx_deemph;
	output wire [2:0] pipe_tx_margin;
	output wire pipe_rx0_polarity;
	output wire pipe_rx1_polarity;
	output wire pipe_rx2_polarity;
	output wire pipe_rx3_polarity;
	output wire pipe_rx4_polarity;
	output wire pipe_rx5_polarity;
	output wire pipe_rx6_polarity;
	output wire pipe_rx7_polarity;
	output wire pipe_tx0_compliance;
	output wire pipe_tx1_compliance;
	output wire pipe_tx2_compliance;
	output wire pipe_tx3_compliance;
	output wire pipe_tx4_compliance;
	output wire pipe_tx5_compliance;
	output wire pipe_tx6_compliance;
	output wire pipe_tx7_compliance;
	output wire [1:0] pipe_tx0_char_is_k;
	output wire [1:0] pipe_tx1_char_is_k;
	output wire [1:0] pipe_tx2_char_is_k;
	output wire [1:0] pipe_tx3_char_is_k;
	output wire [1:0] pipe_tx4_char_is_k;
	output wire [1:0] pipe_tx5_char_is_k;
	output wire [1:0] pipe_tx6_char_is_k;
	output wire [1:0] pipe_tx7_char_is_k;
	output wire [15:0] pipe_tx0_data;
	output wire [15:0] pipe_tx1_data;
	output wire [15:0] pipe_tx2_data;
	output wire [15:0] pipe_tx3_data;
	output wire [15:0] pipe_tx4_data;
	output wire [15:0] pipe_tx5_data;
	output wire [15:0] pipe_tx6_data;
	output wire [15:0] pipe_tx7_data;
	output wire pipe_tx0_elec_idle;
	output wire pipe_tx1_elec_idle;
	output wire pipe_tx2_elec_idle;
	output wire pipe_tx3_elec_idle;
	output wire pipe_tx4_elec_idle;
	output wire pipe_tx5_elec_idle;
	output wire pipe_tx6_elec_idle;
	output wire pipe_tx7_elec_idle;
	output wire [1:0] pipe_tx0_powerdown;
	output wire [1:0] pipe_tx1_powerdown;
	output wire [1:0] pipe_tx2_powerdown;
	output wire [1:0] pipe_tx3_powerdown;
	output wire [1:0] pipe_tx4_powerdown;
	output wire [1:0] pipe_tx5_powerdown;
	output wire [1:0] pipe_tx6_powerdown;
	output wire [1:0] pipe_tx7_powerdown;
	output wire user_rst_n;
	output wire pl_received_hot_rst;
	output wire received_func_lvl_rst_n;
	output wire lnk_clk_en;
	output wire [31:0] cfg_mgmt_do;
	output wire cfg_mgmt_rd_wr_done_n;
	output wire cfg_err_aer_headerlog_set_n;
	output wire cfg_err_cpl_rdy_n;
	output wire cfg_interrupt_rdy_n;
	output wire [2:0] cfg_interrupt_mmenable;
	output wire cfg_interrupt_msienable;
	output wire [7:0] cfg_interrupt_do;
	output wire cfg_interrupt_msixenable;
	output wire cfg_interrupt_msixfm;
	output wire cfg_msg_received;
	output wire [15:0] cfg_msg_data;
	output wire cfg_msg_received_err_cor;
	output wire cfg_msg_received_err_non_fatal;
	output wire cfg_msg_received_err_fatal;
	output wire cfg_msg_received_assert_int_a;
	output wire cfg_msg_received_deassert_int_a;
	output wire cfg_msg_received_assert_int_b;
	output wire cfg_msg_received_deassert_int_b;
	output wire cfg_msg_received_assert_int_c;
	output wire cfg_msg_received_deassert_int_c;
	output wire cfg_msg_received_assert_int_d;
	output wire cfg_msg_received_deassert_int_d;
	output wire cfg_msg_received_pm_pme;
	output wire cfg_msg_received_pme_to_ack;
	output wire cfg_msg_received_pme_to;
	output wire cfg_msg_received_setslotpowerlimit;
	output wire cfg_msg_received_unlock;
	output wire cfg_msg_received_pm_as_nak;
	output wire [2:0] cfg_pcie_link_state;
	output wire cfg_pm_rcv_as_req_l1_n;
	output wire cfg_pm_rcv_enter_l1_n;
	output wire cfg_pm_rcv_enter_l23_n;
	output wire cfg_pm_rcv_req_ack_n;
	output wire [1:0] cfg_pmcsr_powerstate;
	output wire cfg_pmcsr_pme_en;
	output wire cfg_pmcsr_pme_status;
	output wire cfg_transaction;
	output wire cfg_transaction_type;
	output wire [6:0] cfg_transaction_addr;
	output wire cfg_command_io_enable;
	output wire cfg_command_mem_enable;
	output wire cfg_command_bus_master_enable;
	output wire cfg_command_interrupt_disable;
	output wire cfg_command_serr_en;
	output wire cfg_bridge_serr_en;
	output wire cfg_dev_status_corr_err_detected;
	output wire cfg_dev_status_non_fatal_err_detected;
	output wire cfg_dev_status_fatal_err_detected;
	output wire cfg_dev_status_ur_detected;
	output wire cfg_dev_control_corr_err_reporting_en;
	output wire cfg_dev_control_non_fatal_reporting_en;
	output wire cfg_dev_control_fatal_err_reporting_en;
	output wire cfg_dev_control_ur_err_reporting_en;
	output wire cfg_dev_control_enable_ro;
	output wire [2:0] cfg_dev_control_max_payload;
	output wire cfg_dev_control_ext_tag_en;
	output wire cfg_dev_control_phantom_en;
	output wire cfg_dev_control_aux_power_en;
	output wire cfg_dev_control_no_snoop_en;
	output wire [2:0] cfg_dev_control_max_read_req;
	output wire [1:0] cfg_link_status_current_speed;
	output wire [3:0] cfg_link_status_negotiated_width;
	output wire cfg_link_status_link_training;
	output wire cfg_link_status_dll_active;
	output wire cfg_link_status_bandwidth_status;
	output wire cfg_link_status_auto_bandwidth_status;
	output wire [1:0] cfg_link_control_aspm_control;
	output wire cfg_link_control_rcb;
	output wire cfg_link_control_link_disable;
	output wire cfg_link_control_retrain_link;
	output wire cfg_link_control_common_clock;
	output wire cfg_link_control_extended_sync;
	output wire cfg_link_control_clock_pm_en;
	output wire cfg_link_control_hw_auto_width_dis;
	output wire cfg_link_control_bandwidth_int_en;
	output wire cfg_link_control_auto_bandwidth_int_en;
	output wire [3:0] cfg_dev_control2_cpl_timeout_val;
	output wire cfg_dev_control2_cpl_timeout_dis;
	output wire cfg_dev_control2_ari_forward_en;
	output wire cfg_dev_control2_atomic_requester_en;
	output wire cfg_dev_control2_atomic_egress_block;
	output wire cfg_dev_control2_ido_req_en;
	output wire cfg_dev_control2_ido_cpl_en;
	output wire cfg_dev_control2_ltr_en;
	output wire cfg_dev_control2_tlp_prefix_block;
	output wire cfg_slot_control_electromech_il_ctl_pulse;
	output wire cfg_root_control_syserr_corr_err_en;
	output wire cfg_root_control_syserr_non_fatal_err_en;
	output wire cfg_root_control_syserr_fatal_err_en;
	output wire cfg_root_control_pme_int_en;
	output wire cfg_aer_ecrc_check_en;
	output wire cfg_aer_ecrc_gen_en;
	output wire cfg_aer_rooterr_corr_err_reporting_en;
	output wire cfg_aer_rooterr_non_fatal_err_reporting_en;
	output wire cfg_aer_rooterr_fatal_err_reporting_en;
	output wire cfg_aer_rooterr_corr_err_received;
	output wire cfg_aer_rooterr_non_fatal_err_received;
	output wire cfg_aer_rooterr_fatal_err_received;
	output wire [6:0] cfg_vc_tcvc_map;
	output wire drp_rdy;
	output wire [15:0] drp_do;
	output wire [63:0] dbg_vec_a;
	output wire [63:0] dbg_vec_b;
	output wire [11:0] dbg_vec_c;
	output wire dbg_sclr_a;
	output wire dbg_sclr_b;
	output wire dbg_sclr_c;
	output wire dbg_sclr_d;
	output wire dbg_sclr_e;
	output wire dbg_sclr_f;
	output wire dbg_sclr_g;
	output wire dbg_sclr_h;
	output wire dbg_sclr_i;
	output wire dbg_sclr_j;
	output wire dbg_sclr_k;
	output wire [11:0] pl_dbg_vec;
	wire [3:0] trn_tdst_rdy_bus;
	assign trn_clk = user_clk2;
	assign trn_tdst_rdy = trn_tdst_rdy_bus[0];
	wire mim_tx_wen;
	wire [12:0] mim_tx_waddr;
	wire [68:0] mim_tx_wdata;
	wire mim_tx_ren;
	wire mim_tx_rce;
	wire [12:0] mim_tx_raddr;
	wire [68:0] mim_tx_rdata;
	wire [2:0] unused_mim_tx_rdata;
	wire mim_rx_wen;
	wire [12:0] mim_rx_waddr;
	wire [67:0] mim_rx_wdata;
	wire mim_rx_ren;
	wire mim_rx_rce;
	wire [12:0] mim_rx_raddr;
	wire [67:0] mim_rx_rdata;
	wire [3:0] unused_mim_rx_rdata;
	localparam BRT_TLM_TX_OVERHEAD = 24;
	localparam BRT_MPS_BYTES = (DEV_CAP_MAX_PAYLOAD_SUPPORTED == 0 ? 128 : (DEV_CAP_MAX_PAYLOAD_SUPPORTED == 1 ? 256 : (DEV_CAP_MAX_PAYLOAD_SUPPORTED == 2 ? 512 : 1024)));
	localparam BRT_BYTES_TX = (VC0_TX_LASTPACKET + 1) * (BRT_MPS_BYTES + BRT_TLM_TX_OVERHEAD);
	localparam BRT_COLS_TX = (BRT_BYTES_TX <= 4096 ? 1 : (BRT_BYTES_TX <= 8192 ? 2 : (BRT_BYTES_TX <= 16384 ? 4 : (BRT_BYTES_TX <= 32768 ? 8 : 18))));
	localparam BRT_COLS_RX = 4;
	localparam signed [31:0] link_pkg_PCIE_GEN = 2;
	localparam [3:0] link_pkg_LINK_CAP_MAX_LINK_SPEED = link_pkg_PCIE_GEN;
	localparam signed [31:0] link_pkg_PCIE_LANES = 1;
	localparam [5:0] link_pkg_LINK_CAP_MAX_LINK_WIDTH = link_pkg_PCIE_LANES;
	buffer_bank #(
		.LINK_CAP_MAX_LINK_WIDTH(link_pkg_LINK_CAP_MAX_LINK_WIDTH),
		.LINK_CAP_MAX_LINK_SPEED(link_pkg_LINK_CAP_MAX_LINK_SPEED),
		.NUM_BRAMS(BRT_COLS_TX),
		.RAM_RADDR_LATENCY(TL_TX_RAM_RADDR_LATENCY),
		.RAM_RDATA_LATENCY(TL_TX_RAM_RDATA_LATENCY),
		.RAM_WRITE_LATENCY(TL_TX_RAM_WRITE_LATENCY)
	) tx_buf_bank(
		.user_clk_i(user_clk),
		.reset_i(1'b0),
		.waddr(mim_tx_waddr),
		.wen(mim_tx_wen),
		.ren(mim_tx_ren),
		.rce(1'b1),
		.wdata({3'b000, mim_tx_wdata}),
		.raddr(mim_tx_raddr),
		.rdata({unused_mim_tx_rdata, mim_tx_rdata})
	);
	buffer_bank #(
		.LINK_CAP_MAX_LINK_WIDTH(link_pkg_LINK_CAP_MAX_LINK_WIDTH),
		.LINK_CAP_MAX_LINK_SPEED(link_pkg_LINK_CAP_MAX_LINK_SPEED),
		.NUM_BRAMS(BRT_COLS_RX),
		.RAM_RADDR_LATENCY(TL_RX_RAM_RADDR_LATENCY),
		.RAM_RDATA_LATENCY(TL_RX_RAM_RDATA_LATENCY),
		.RAM_WRITE_LATENCY(TL_RX_RAM_WRITE_LATENCY)
	) rx_buf_bank(
		.user_clk_i(user_clk),
		.reset_i(1'b0),
		.waddr(mim_rx_waddr),
		.wen(mim_rx_wen),
		.ren(mim_rx_ren),
		.rce(1'b1),
		.wdata({4'b0000, mim_rx_wdata}),
		.raddr(mim_rx_raddr),
		.rdata({unused_mim_rx_rdata, mim_rx_rdata})
	);
	localparam [3:0] link_pkg_LINK_CTRL2_TARGET_LINK_SPEED = link_pkg_PCIE_GEN;
	localparam [5:0] link_pkg_LTSSM_MAX_LINK_WIDTH = link_pkg_PCIE_LANES;
	PCIE_2_1 #(
		.AER_BASE_PTR(AER_BASE_PTR),
		.AER_CAP_ECRC_CHECK_CAPABLE(AER_CAP_ECRC_CHECK_CAPABLE),
		.AER_CAP_ECRC_GEN_CAPABLE(AER_CAP_ECRC_GEN_CAPABLE),
		.AER_CAP_ID(AER_CAP_ID),
		.AER_CAP_MULTIHEADER(AER_CAP_MULTIHEADER),
		.AER_CAP_NEXTPTR(AER_CAP_NEXTPTR),
		.AER_CAP_ON(AER_CAP_ON),
		.AER_CAP_OPTIONAL_ERR_SUPPORT(AER_CAP_OPTIONAL_ERR_SUPPORT),
		.AER_CAP_PERMIT_ROOTERR_UPDATE(AER_CAP_PERMIT_ROOTERR_UPDATE),
		.AER_CAP_VERSION(AER_CAP_VERSION),
		.ALLOW_X8_GEN2(ALLOW_X8_GEN2),
		.BAR0(BAR0),
		.BAR1(BAR1),
		.BAR2(BAR2),
		.BAR3(BAR3),
		.BAR4(BAR4),
		.BAR5(BAR5),
		.CAPABILITIES_PTR(CAPABILITIES_PTR),
		.CARDBUS_CIS_POINTER(CARDBUS_CIS_POINTER),
		.CFG_ECRC_ERR_CPLSTAT(CFG_ECRC_ERR_CPLSTAT),
		.CLASS_CODE(CLASS_CODE),
		.CMD_INTX_IMPLEMENTED(CMD_INTX_IMPLEMENTED),
		.CPL_TIMEOUT_DISABLE_SUPPORTED(CPL_TIMEOUT_DISABLE_SUPPORTED),
		.CPL_TIMEOUT_RANGES_SUPPORTED(CPL_TIMEOUT_RANGES_SUPPORTED),
		.CRM_MODULE_RSTS(CRM_MODULE_RSTS),
		.DEV_CAP_ENABLE_SLOT_PWR_LIMIT_SCALE(DEV_CAP_ENABLE_SLOT_PWR_LIMIT_SCALE),
		.DEV_CAP_ENABLE_SLOT_PWR_LIMIT_VALUE(DEV_CAP_ENABLE_SLOT_PWR_LIMIT_VALUE),
		.DEV_CAP_ENDPOINT_L0S_LATENCY(DEV_CAP_ENDPOINT_L0S_LATENCY),
		.DEV_CAP_ENDPOINT_L1_LATENCY(DEV_CAP_ENDPOINT_L1_LATENCY),
		.DEV_CAP_EXT_TAG_SUPPORTED(DEV_CAP_EXT_TAG_SUPPORTED),
		.DEV_CAP_FUNCTION_LEVEL_RESET_CAPABLE(DEV_CAP_FUNCTION_LEVEL_RESET_CAPABLE),
		.DEV_CAP_MAX_PAYLOAD_SUPPORTED(DEV_CAP_MAX_PAYLOAD_SUPPORTED),
		.DEV_CAP_PHANTOM_FUNCTIONS_SUPPORT(DEV_CAP_PHANTOM_FUNCTIONS_SUPPORT),
		.DEV_CAP_ROLE_BASED_ERROR(DEV_CAP_ROLE_BASED_ERROR),
		.DEV_CAP_RSVD_14_12(DEV_CAP_RSVD_14_12),
		.DEV_CAP_RSVD_17_16(DEV_CAP_RSVD_17_16),
		.DEV_CAP_RSVD_31_29(DEV_CAP_RSVD_31_29),
		.DEV_CAP2_ARI_FORWARDING_SUPPORTED(DEV_CAP2_ARI_FORWARDING_SUPPORTED),
		.DEV_CAP2_ATOMICOP_ROUTING_SUPPORTED(DEV_CAP2_ATOMICOP_ROUTING_SUPPORTED),
		.DEV_CAP2_ATOMICOP32_COMPLETER_SUPPORTED(DEV_CAP2_ATOMICOP32_COMPLETER_SUPPORTED),
		.DEV_CAP2_ATOMICOP64_COMPLETER_SUPPORTED(DEV_CAP2_ATOMICOP64_COMPLETER_SUPPORTED),
		.DEV_CAP2_CAS128_COMPLETER_SUPPORTED(DEV_CAP2_CAS128_COMPLETER_SUPPORTED),
		.DEV_CAP2_ENDEND_TLP_PREFIX_SUPPORTED(DEV_CAP2_ENDEND_TLP_PREFIX_SUPPORTED),
		.DEV_CAP2_EXTENDED_FMT_FIELD_SUPPORTED(DEV_CAP2_EXTENDED_FMT_FIELD_SUPPORTED),
		.DEV_CAP2_LTR_MECHANISM_SUPPORTED(DEV_CAP2_LTR_MECHANISM_SUPPORTED),
		.DEV_CAP2_MAX_ENDEND_TLP_PREFIXES(DEV_CAP2_MAX_ENDEND_TLP_PREFIXES),
		.DEV_CAP2_NO_RO_ENABLED_PRPR_PASSING(DEV_CAP2_NO_RO_ENABLED_PRPR_PASSING),
		.DEV_CAP2_TPH_COMPLETER_SUPPORTED(DEV_CAP2_TPH_COMPLETER_SUPPORTED),
		.DEV_CONTROL_AUX_POWER_SUPPORTED(DEV_CONTROL_AUX_POWER_SUPPORTED),
		.DEV_CONTROL_EXT_TAG_DEFAULT(DEV_CONTROL_EXT_TAG_DEFAULT),
		.DISABLE_ASPM_L1_TIMER(DISABLE_ASPM_L1_TIMER),
		.DISABLE_BAR_FILTERING(DISABLE_BAR_FILTERING),
		.DISABLE_ERR_MSG(DISABLE_ERR_MSG),
		.DISABLE_ID_CHECK(DISABLE_ID_CHECK),
		.DISABLE_LANE_REVERSAL(DISABLE_LANE_REVERSAL),
		.DISABLE_LOCKED_FILTER(DISABLE_LOCKED_FILTER),
		.DISABLE_PPM_FILTER(DISABLE_PPM_FILTER),
		.DISABLE_RX_POISONED_RESP(DISABLE_RX_POISONED_RESP),
		.DISABLE_RX_TC_FILTER(DISABLE_RX_TC_FILTER),
		.DISABLE_SCRAMBLING(DISABLE_SCRAMBLING),
		.DNSTREAM_LINK_NUM(DNSTREAM_LINK_NUM),
		.DSN_BASE_PTR(DSN_BASE_PTR),
		.DSN_CAP_ID(DSN_CAP_ID),
		.DSN_CAP_NEXTPTR(DSN_CAP_NEXTPTR),
		.DSN_CAP_ON(DSN_CAP_ON),
		.DSN_CAP_VERSION(DSN_CAP_VERSION),
		.ENABLE_MSG_ROUTE(ENABLE_MSG_ROUTE),
		.ENABLE_RX_TD_ECRC_TRIM(ENABLE_RX_TD_ECRC_TRIM),
		.ENDEND_TLP_PREFIX_FORWARDING_SUPPORTED(ENDEND_TLP_PREFIX_FORWARDING_SUPPORTED),
		.ENTER_RVRY_EI_L0(ENTER_RVRY_EI_L0),
		.EXIT_LOOPBACK_ON_EI(EXIT_LOOPBACK_ON_EI),
		.EXPANSION_ROM(EXPANSION_ROM),
		.EXT_CFG_CAP_PTR(EXT_CFG_CAP_PTR),
		.EXT_CFG_XP_CAP_PTR(EXT_CFG_XP_CAP_PTR),
		.HEADER_TYPE(HEADER_TYPE),
		.INFER_EI(INFER_EI),
		.INTERRUPT_PIN(INTERRUPT_PIN),
		.INTERRUPT_STAT_AUTO(INTERRUPT_STAT_AUTO),
		.IS_SWITCH(IS_SWITCH),
		.LAST_CONFIG_DWORD(LAST_CONFIG_DWORD),
		.LINK_CAP_ASPM_OPTIONALITY(LINK_CAP_ASPM_OPTIONALITY),
		.LINK_CAP_ASPM_SUPPORT(LINK_CAP_ASPM_SUPPORT),
		.LINK_CAP_CLOCK_POWER_MANAGEMENT(LINK_CAP_CLOCK_POWER_MANAGEMENT),
		.LINK_CAP_DLL_LINK_ACTIVE_REPORTING_CAP(LINK_CAP_DLL_LINK_ACTIVE_REPORTING_CAP),
		.LINK_CAP_LINK_BANDWIDTH_NOTIFICATION_CAP(LINK_CAP_LINK_BANDWIDTH_NOTIFICATION_CAP),
		.LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN1(LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN1),
		.LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN2(LINK_CAP_L0S_EXIT_LATENCY_COMCLK_GEN2),
		.LINK_CAP_L0S_EXIT_LATENCY_GEN1(LINK_CAP_L0S_EXIT_LATENCY_GEN1),
		.LINK_CAP_L0S_EXIT_LATENCY_GEN2(LINK_CAP_L0S_EXIT_LATENCY_GEN2),
		.LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN1(LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN1),
		.LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN2(LINK_CAP_L1_EXIT_LATENCY_COMCLK_GEN2),
		.LINK_CAP_L1_EXIT_LATENCY_GEN1(LINK_CAP_L1_EXIT_LATENCY_GEN1),
		.LINK_CAP_L1_EXIT_LATENCY_GEN2(LINK_CAP_L1_EXIT_LATENCY_GEN2),
		.LINK_CAP_MAX_LINK_SPEED(link_pkg_LINK_CAP_MAX_LINK_SPEED),
		.LINK_CAP_MAX_LINK_WIDTH(link_pkg_LINK_CAP_MAX_LINK_WIDTH),
		.LINK_CAP_RSVD_23(LINK_CAP_RSVD_23),
		.LINK_CAP_SURPRISE_DOWN_ERROR_CAPABLE(LINK_CAP_SURPRISE_DOWN_ERROR_CAPABLE),
		.LINK_CONTROL_RCB(LINK_CONTROL_RCB),
		.LINK_CTRL2_DEEMPHASIS(LINK_CTRL2_DEEMPHASIS),
		.LINK_CTRL2_HW_AUTONOMOUS_SPEED_DISABLE(LINK_CTRL2_HW_AUTONOMOUS_SPEED_DISABLE),
		.LINK_CTRL2_TARGET_LINK_SPEED(link_pkg_LINK_CTRL2_TARGET_LINK_SPEED),
		.LINK_STATUS_SLOT_CLOCK_CONFIG(LINK_STATUS_SLOT_CLOCK_CONFIG),
		.LL_ACK_TIMEOUT(LL_ACK_TIMEOUT),
		.LL_ACK_TIMEOUT_EN(LL_ACK_TIMEOUT_EN),
		.LL_ACK_TIMEOUT_FUNC(LL_ACK_TIMEOUT_FUNC),
		.LL_REPLAY_TIMEOUT(LL_REPLAY_TIMEOUT),
		.LL_REPLAY_TIMEOUT_EN(LL_REPLAY_TIMEOUT_EN),
		.LL_REPLAY_TIMEOUT_FUNC(LL_REPLAY_TIMEOUT_FUNC),
		.LTSSM_MAX_LINK_WIDTH(link_pkg_LTSSM_MAX_LINK_WIDTH),
		.MPS_FORCE(MPS_FORCE),
		.MSI_BASE_PTR(MSI_BASE_PTR),
		.MSI_CAP_ID(MSI_CAP_ID),
		.MSI_CAP_MULTIMSG_EXTENSION(MSI_CAP_MULTIMSG_EXTENSION),
		.MSI_CAP_MULTIMSGCAP(MSI_CAP_MULTIMSGCAP),
		.MSI_CAP_NEXTPTR(MSI_CAP_NEXTPTR),
		.MSI_CAP_ON(MSI_CAP_ON),
		.MSI_CAP_PER_VECTOR_MASKING_CAPABLE(MSI_CAP_PER_VECTOR_MASKING_CAPABLE),
		.MSI_CAP_64_BIT_ADDR_CAPABLE(MSI_CAP_64_BIT_ADDR_CAPABLE),
		.MSIX_BASE_PTR(MSIX_BASE_PTR),
		.MSIX_CAP_ID(MSIX_CAP_ID),
		.MSIX_CAP_NEXTPTR(MSIX_CAP_NEXTPTR),
		.MSIX_CAP_ON(MSIX_CAP_ON),
		.MSIX_CAP_PBA_BIR(MSIX_CAP_PBA_BIR),
		.MSIX_CAP_PBA_OFFSET(MSIX_CAP_PBA_OFFSET),
		.MSIX_CAP_TABLE_BIR(MSIX_CAP_TABLE_BIR),
		.MSIX_CAP_TABLE_OFFSET(MSIX_CAP_TABLE_OFFSET),
		.MSIX_CAP_TABLE_SIZE(MSIX_CAP_TABLE_SIZE),
		.N_FTS_COMCLK_GEN1(N_FTS_COMCLK_GEN1),
		.N_FTS_COMCLK_GEN2(N_FTS_COMCLK_GEN2),
		.N_FTS_GEN1(N_FTS_GEN1),
		.N_FTS_GEN2(N_FTS_GEN2),
		.PCIE_BASE_PTR(PCIE_BASE_PTR),
		.PCIE_CAP_CAPABILITY_ID(PCIE_CAP_CAPABILITY_ID),
		.PCIE_CAP_CAPABILITY_VERSION(PCIE_CAP_CAPABILITY_VERSION),
		.PCIE_CAP_DEVICE_PORT_TYPE(PCIE_CAP_DEVICE_PORT_TYPE),
		.PCIE_CAP_NEXTPTR(PCIE_CAP_NEXTPTR),
		.PCIE_CAP_ON(PCIE_CAP_ON),
		.PCIE_CAP_RSVD_15_14(PCIE_CAP_RSVD_15_14),
		.PCIE_CAP_SLOT_IMPLEMENTED(PCIE_CAP_SLOT_IMPLEMENTED),
		.PCIE_REVISION(PCIE_REVISION),
		.PL_AUTO_CONFIG(PL_AUTO_CONFIG),
		.PL_FAST_TRAIN(PL_FAST_TRAIN),
		.PM_ASPML0S_TIMEOUT(PM_ASPML0S_TIMEOUT),
		.PM_ASPML0S_TIMEOUT_EN(PM_ASPML0S_TIMEOUT_EN),
		.PM_ASPML0S_TIMEOUT_FUNC(PM_ASPML0S_TIMEOUT_FUNC),
		.PM_ASPM_FASTEXIT(PM_ASPM_FASTEXIT),
		.PM_BASE_PTR(PM_BASE_PTR),
		.PM_CAP_AUXCURRENT(PM_CAP_AUXCURRENT),
		.PM_CAP_DSI(PM_CAP_DSI),
		.PM_CAP_D1SUPPORT(PM_CAP_D1SUPPORT),
		.PM_CAP_D2SUPPORT(PM_CAP_D2SUPPORT),
		.PM_CAP_ID(PM_CAP_ID),
		.PM_CAP_NEXTPTR(PM_CAP_NEXTPTR),
		.PM_CAP_ON(PM_CAP_ON),
		.PM_CAP_PME_CLOCK(PM_CAP_PME_CLOCK),
		.PM_CAP_PMESUPPORT(PM_CAP_PMESUPPORT),
		.PM_CAP_RSVD_04(PM_CAP_RSVD_04),
		.PM_CAP_VERSION(PM_CAP_VERSION),
		.PM_CSR_BPCCEN(PM_CSR_BPCCEN),
		.PM_CSR_B2B3(PM_CSR_B2B3),
		.PM_CSR_NOSOFTRST(PM_CSR_NOSOFTRST),
		.PM_DATA_SCALE0(PM_DATA_SCALE0),
		.PM_DATA_SCALE1(PM_DATA_SCALE1),
		.PM_DATA_SCALE2(PM_DATA_SCALE2),
		.PM_DATA_SCALE3(PM_DATA_SCALE3),
		.PM_DATA_SCALE4(PM_DATA_SCALE4),
		.PM_DATA_SCALE5(PM_DATA_SCALE5),
		.PM_DATA_SCALE6(PM_DATA_SCALE6),
		.PM_DATA_SCALE7(PM_DATA_SCALE7),
		.PM_DATA0(PM_DATA0),
		.PM_DATA1(PM_DATA1),
		.PM_DATA2(PM_DATA2),
		.PM_DATA3(PM_DATA3),
		.PM_DATA4(PM_DATA4),
		.PM_DATA5(PM_DATA5),
		.PM_DATA6(PM_DATA6),
		.PM_DATA7(PM_DATA7),
		.PM_MF(PM_MF),
		.RBAR_BASE_PTR(RBAR_BASE_PTR),
		.RBAR_CAP_CONTROL_ENCODEDBAR0(RBAR_CAP_CONTROL_ENCODEDBAR0),
		.RBAR_CAP_CONTROL_ENCODEDBAR1(RBAR_CAP_CONTROL_ENCODEDBAR1),
		.RBAR_CAP_CONTROL_ENCODEDBAR2(RBAR_CAP_CONTROL_ENCODEDBAR2),
		.RBAR_CAP_CONTROL_ENCODEDBAR3(RBAR_CAP_CONTROL_ENCODEDBAR3),
		.RBAR_CAP_CONTROL_ENCODEDBAR4(RBAR_CAP_CONTROL_ENCODEDBAR4),
		.RBAR_CAP_CONTROL_ENCODEDBAR5(RBAR_CAP_CONTROL_ENCODEDBAR5),
		.RBAR_CAP_ID(RBAR_CAP_ID),
		.RBAR_CAP_INDEX0(RBAR_CAP_INDEX0),
		.RBAR_CAP_INDEX1(RBAR_CAP_INDEX1),
		.RBAR_CAP_INDEX2(RBAR_CAP_INDEX2),
		.RBAR_CAP_INDEX3(RBAR_CAP_INDEX3),
		.RBAR_CAP_INDEX4(RBAR_CAP_INDEX4),
		.RBAR_CAP_INDEX5(RBAR_CAP_INDEX5),
		.RBAR_CAP_NEXTPTR(RBAR_CAP_NEXTPTR),
		.RBAR_CAP_ON(RBAR_CAP_ON),
		.RBAR_CAP_SUP0(RBAR_CAP_SUP0),
		.RBAR_CAP_SUP1(RBAR_CAP_SUP1),
		.RBAR_CAP_SUP2(RBAR_CAP_SUP2),
		.RBAR_CAP_SUP3(RBAR_CAP_SUP3),
		.RBAR_CAP_SUP4(RBAR_CAP_SUP4),
		.RBAR_CAP_SUP5(RBAR_CAP_SUP5),
		.RBAR_CAP_VERSION(RBAR_CAP_VERSION),
		.RBAR_NUM(RBAR_NUM),
		.RECRC_CHK(RECRC_CHK),
		.RECRC_CHK_TRIM(RECRC_CHK_TRIM),
		.ROOT_CAP_CRS_SW_VISIBILITY(ROOT_CAP_CRS_SW_VISIBILITY),
		.RP_AUTO_SPD(RP_AUTO_SPD),
		.RP_AUTO_SPD_LOOPCNT(RP_AUTO_SPD_LOOPCNT),
		.SELECT_DLL_IF(SELECT_DLL_IF),
		.SLOT_CAP_ATT_BUTTON_PRESENT(SLOT_CAP_ATT_BUTTON_PRESENT),
		.SLOT_CAP_ATT_INDICATOR_PRESENT(SLOT_CAP_ATT_INDICATOR_PRESENT),
		.SLOT_CAP_ELEC_INTERLOCK_PRESENT(SLOT_CAP_ELEC_INTERLOCK_PRESENT),
		.SLOT_CAP_HOTPLUG_CAPABLE(SLOT_CAP_HOTPLUG_CAPABLE),
		.SLOT_CAP_HOTPLUG_SURPRISE(SLOT_CAP_HOTPLUG_SURPRISE),
		.SLOT_CAP_MRL_SENSOR_PRESENT(SLOT_CAP_MRL_SENSOR_PRESENT),
		.SLOT_CAP_NO_CMD_COMPLETED_SUPPORT(SLOT_CAP_NO_CMD_COMPLETED_SUPPORT),
		.SLOT_CAP_PHYSICAL_SLOT_NUM(SLOT_CAP_PHYSICAL_SLOT_NUM),
		.SLOT_CAP_POWER_CONTROLLER_PRESENT(SLOT_CAP_POWER_CONTROLLER_PRESENT),
		.SLOT_CAP_POWER_INDICATOR_PRESENT(SLOT_CAP_POWER_INDICATOR_PRESENT),
		.SLOT_CAP_SLOT_POWER_LIMIT_SCALE(SLOT_CAP_SLOT_POWER_LIMIT_SCALE),
		.SLOT_CAP_SLOT_POWER_LIMIT_VALUE(SLOT_CAP_SLOT_POWER_LIMIT_VALUE),
		.SPARE_BIT0(SPARE_BIT0),
		.SPARE_BIT1(SPARE_BIT1),
		.SPARE_BIT2(SPARE_BIT2),
		.SPARE_BIT3(SPARE_BIT3),
		.SPARE_BIT4(SPARE_BIT4),
		.SPARE_BIT5(SPARE_BIT5),
		.SPARE_BIT6(SPARE_BIT6),
		.SPARE_BIT7(SPARE_BIT7),
		.SPARE_BIT8(SPARE_BIT8),
		.SPARE_BYTE0(SPARE_BYTE0),
		.SPARE_BYTE1(SPARE_BYTE1),
		.SPARE_BYTE2(SPARE_BYTE2),
		.SPARE_BYTE3(SPARE_BYTE3),
		.SPARE_WORD0(SPARE_WORD0),
		.SPARE_WORD1(SPARE_WORD1),
		.SPARE_WORD2(SPARE_WORD2),
		.SPARE_WORD3(SPARE_WORD3),
		.SSL_MESSAGE_AUTO(SSL_MESSAGE_AUTO),
		.TECRC_EP_INV(TECRC_EP_INV),
		.TL_RBYPASS(TL_RBYPASS),
		.TL_RX_RAM_RADDR_LATENCY(TL_RX_RAM_RADDR_LATENCY),
		.TL_RX_RAM_RDATA_LATENCY(TL_RX_RAM_RDATA_LATENCY),
		.TL_RX_RAM_WRITE_LATENCY(TL_RX_RAM_WRITE_LATENCY),
		.TL_TFC_DISABLE(TL_TFC_DISABLE),
		.TL_TX_CHECKS_DISABLE(TL_TX_CHECKS_DISABLE),
		.TL_TX_RAM_RADDR_LATENCY(TL_TX_RAM_RADDR_LATENCY),
		.TL_TX_RAM_RDATA_LATENCY(TL_TX_RAM_RDATA_LATENCY),
		.TL_TX_RAM_WRITE_LATENCY(TL_TX_RAM_WRITE_LATENCY),
		.TRN_DW(TRN_DW),
		.TRN_NP_FC(TRN_NP_FC),
		.UPCONFIG_CAPABLE(UPCONFIG_CAPABLE),
		.UPSTREAM_FACING(UPSTREAM_FACING),
		.UR_ATOMIC(UR_ATOMIC),
		.UR_CFG1(UR_CFG1),
		.UR_INV_REQ(UR_INV_REQ),
		.UR_PRS_RESPONSE(UR_PRS_RESPONSE),
		.USE_RID_PINS(USE_RID_PINS),
		.USER_CLK_FREQ(USER_CLK_FREQ),
		.USER_CLK2_DIV2(USER_CLK2_DIV2),
		.VC_BASE_PTR(VC_BASE_PTR),
		.VC_CAP_ID(VC_CAP_ID),
		.VC_CAP_NEXTPTR(VC_CAP_NEXTPTR),
		.VC_CAP_ON(VC_CAP_ON),
		.VC_CAP_REJECT_SNOOP_TRANSACTIONS(VC_CAP_REJECT_SNOOP_TRANSACTIONS),
		.VC_CAP_VERSION(VC_CAP_VERSION),
		.VC0_CPL_INFINITE(VC0_CPL_INFINITE),
		.VC0_RX_RAM_LIMIT(VC0_RX_RAM_LIMIT),
		.VC0_TOTAL_CREDITS_CD(VC0_TOTAL_CREDITS_CD),
		.VC0_TOTAL_CREDITS_CH(VC0_TOTAL_CREDITS_CH),
		.VC0_TOTAL_CREDITS_NPD(VC0_TOTAL_CREDITS_NPD),
		.VC0_TOTAL_CREDITS_NPH(VC0_TOTAL_CREDITS_NPH),
		.VC0_TOTAL_CREDITS_PD(VC0_TOTAL_CREDITS_PD),
		.VC0_TOTAL_CREDITS_PH(VC0_TOTAL_CREDITS_PH),
		.VC0_TX_LASTPACKET(VC0_TX_LASTPACKET),
		.VSEC_BASE_PTR(VSEC_BASE_PTR),
		.VSEC_CAP_HDR_ID(VSEC_CAP_HDR_ID),
		.VSEC_CAP_HDR_REVISION(VSEC_CAP_HDR_REVISION),
		.VSEC_CAP_ID(VSEC_CAP_ID),
		.VSEC_CAP_IS_LINK_VISIBLE(VSEC_CAP_IS_LINK_VISIBLE),
		.VSEC_CAP_NEXTPTR(VSEC_CAP_NEXTPTR),
		.VSEC_CAP_ON(VSEC_CAP_ON),
		.VSEC_CAP_VERSION(VSEC_CAP_VERSION)
	) pcie_block_i(
		.TRNTD({{64 {1'b0}}, trn_td}),
		.TRNTREM({1'b0, trn_trem}),
		.TRNTSOF(trn_tsof),
		.TRNTEOF(trn_teof),
		.TRNTSRCRDY(trn_tsrc_rdy),
		.TRNTSRCDSC(trn_tsrc_dsc),
		.TRNTERRFWD(trn_terrfwd),
		.TRNTECRCGEN(trn_tecrc_gen),
		.TRNTSTR(trn_tstr),
		.TRNTCFGGNT(trn_tcfg_gnt),
		.TRNRDSTRDY(trn_rdst_rdy),
		.TRNRNPREQ(trn_rnp_req),
		.TRNRFCPRET(trn_rfcp_ret),
		.TRNRNPOK(trn_rnp_ok),
		.TRNFCSEL(trn_fc_sel),
		.MIMTXRDATA(mim_tx_rdata),
		.MIMRXRDATA(mim_rx_rdata),
		.TRNTDLLPDATA(trn_tdllp_data),
		.TRNTDLLPSRCRDY(trn_tdllp_src_rdy),
		.LL2TLPRCV(ll2_tlp_rcv),
		.LL2SENDENTERL1(ll2_send_enter_l1),
		.LL2SENDENTERL23(ll2_send_enter_l23),
		.LL2SENDASREQL1(ll2_send_as_req_l1),
		.LL2SENDPMACK(ll2_send_pm_ack),
		.PL2DIRECTEDLSTATE(pl2_directed_lstate),
		.LL2SUSPENDNOW(ll2_suspend_now),
		.TL2PPMSUSPENDREQ(tl2_ppm_suspend_req),
		.TL2ASPMSUSPENDCREDITCHECK(tl2_aspm_suspend_credit_check),
		.PLDIRECTEDLINKCHANGE(pl_directed_link_change),
		.PLDIRECTEDLINKWIDTH(pl_directed_link_width),
		.PLDIRECTEDLINKSPEED(pl_directed_link_speed),
		.PLDIRECTEDLINKAUTON(pl_directed_link_auton),
		.PLUPSTREAMPREFERDEEMPH(pl_upstream_prefer_deemph),
		.PLDOWNSTREAMDEEMPHSOURCE(pl_downstream_deemph_source),
		.PLDIRECTEDLTSSMNEW(pl_directed_ltssm_new),
		.PLDIRECTEDLTSSMNEWVLD(pl_directed_ltssm_new_vld),
		.PLDIRECTEDLTSSMSTALL(pl_directed_ltssm_stall),
		.PIPERX0CHARISK(pipe_rx0_char_is_k),
		.PIPERX1CHARISK(pipe_rx1_char_is_k),
		.PIPERX2CHARISK(pipe_rx2_char_is_k),
		.PIPERX3CHARISK(pipe_rx3_char_is_k),
		.PIPERX4CHARISK(pipe_rx4_char_is_k),
		.PIPERX5CHARISK(pipe_rx5_char_is_k),
		.PIPERX6CHARISK(pipe_rx6_char_is_k),
		.PIPERX7CHARISK(pipe_rx7_char_is_k),
		.PIPERX0VALID(pipe_rx0_valid),
		.PIPERX1VALID(pipe_rx1_valid),
		.PIPERX2VALID(pipe_rx2_valid),
		.PIPERX3VALID(pipe_rx3_valid),
		.PIPERX4VALID(pipe_rx4_valid),
		.PIPERX5VALID(pipe_rx5_valid),
		.PIPERX6VALID(pipe_rx6_valid),
		.PIPERX7VALID(pipe_rx7_valid),
		.PIPERX0DATA(pipe_rx0_data),
		.PIPERX1DATA(pipe_rx1_data),
		.PIPERX2DATA(pipe_rx2_data),
		.PIPERX3DATA(pipe_rx3_data),
		.PIPERX4DATA(pipe_rx4_data),
		.PIPERX5DATA(pipe_rx5_data),
		.PIPERX6DATA(pipe_rx6_data),
		.PIPERX7DATA(pipe_rx7_data),
		.PIPERX0CHANISALIGNED(pipe_rx0_chanisaligned),
		.PIPERX1CHANISALIGNED(pipe_rx1_chanisaligned),
		.PIPERX2CHANISALIGNED(pipe_rx2_chanisaligned),
		.PIPERX3CHANISALIGNED(pipe_rx3_chanisaligned),
		.PIPERX4CHANISALIGNED(pipe_rx4_chanisaligned),
		.PIPERX5CHANISALIGNED(pipe_rx5_chanisaligned),
		.PIPERX6CHANISALIGNED(pipe_rx6_chanisaligned),
		.PIPERX7CHANISALIGNED(pipe_rx7_chanisaligned),
		.PIPERX0STATUS(pipe_rx0_status),
		.PIPERX1STATUS(pipe_rx1_status),
		.PIPERX2STATUS(pipe_rx2_status),
		.PIPERX3STATUS(pipe_rx3_status),
		.PIPERX4STATUS(pipe_rx4_status),
		.PIPERX5STATUS(pipe_rx5_status),
		.PIPERX6STATUS(pipe_rx6_status),
		.PIPERX7STATUS(pipe_rx7_status),
		.PIPERX0PHYSTATUS(pipe_rx0_phy_status),
		.PIPERX1PHYSTATUS(pipe_rx1_phy_status),
		.PIPERX2PHYSTATUS(pipe_rx2_phy_status),
		.PIPERX3PHYSTATUS(pipe_rx3_phy_status),
		.PIPERX4PHYSTATUS(pipe_rx4_phy_status),
		.PIPERX5PHYSTATUS(pipe_rx5_phy_status),
		.PIPERX6PHYSTATUS(pipe_rx6_phy_status),
		.PIPERX7PHYSTATUS(pipe_rx7_phy_status),
		.PIPERX0ELECIDLE(pipe_rx0_elec_idle),
		.PIPERX1ELECIDLE(pipe_rx1_elec_idle),
		.PIPERX2ELECIDLE(pipe_rx2_elec_idle),
		.PIPERX3ELECIDLE(pipe_rx3_elec_idle),
		.PIPERX4ELECIDLE(pipe_rx4_elec_idle),
		.PIPERX5ELECIDLE(pipe_rx5_elec_idle),
		.PIPERX6ELECIDLE(pipe_rx6_elec_idle),
		.PIPERX7ELECIDLE(pipe_rx7_elec_idle),
		.PIPECLK(pipe_clk),
		.USERCLK(user_clk),
		.USERCLK2(user_clk2),
		.SYSRSTN(sys_rst_n),
		.CMRSTN(cm_rst_n),
		.CMSTICKYRSTN(cm_sticky_rst_n),
		.FUNCLVLRSTN(func_lvl_rst_n),
		.TLRSTN(tl_rst_n),
		.DLRSTN(dl_rst_n),
		.PLRSTN(pl_rst_n),
		.PLTRANSMITHOTRST(pl_transmit_hot_rst),
		.CFGMGMTDI(cfg_mgmt_di),
		.CFGMGMTBYTEENN(cfg_mgmt_byte_en_n),
		.CFGMGMTDWADDR(cfg_mgmt_dwaddr),
		.CFGMGMTWRRW1CASRWN(cfg_mgmt_wr_rw1c_as_rw_n),
		.CFGMGMTWRREADONLYN(cfg_mgmt_wr_readonly_n),
		.CFGMGMTWRENN(cfg_mgmt_wr_en_n),
		.CFGMGMTRDENN(cfg_mgmt_rd_en_n),
		.CFGERRMALFORMEDN(cfg_err_malformed_n),
		.CFGERRCORN(cfg_err_cor_n),
		.CFGERRURN(cfg_err_ur_n),
		.CFGERRECRCN(cfg_err_ecrc_n),
		.CFGERRCPLTIMEOUTN(cfg_err_cpl_timeout_n),
		.CFGERRCPLABORTN(cfg_err_cpl_abort_n),
		.CFGERRCPLUNEXPECTN(cfg_err_cpl_unexpect_n),
		.CFGERRPOISONEDN(cfg_err_poisoned_n),
		.CFGERRACSN(cfg_err_acs_n),
		.CFGERRATOMICEGRESSBLOCKEDN(cfg_err_atomic_egress_blocked_n),
		.CFGERRMCBLOCKEDN(cfg_err_mc_blocked_n),
		.CFGERRINTERNALUNCORN(cfg_err_internal_uncor_n),
		.CFGERRINTERNALCORN(cfg_err_internal_cor_n),
		.CFGERRPOSTEDN(cfg_err_posted_n),
		.CFGERRLOCKEDN(cfg_err_locked_n),
		.CFGERRNORECOVERYN(cfg_err_norecovery_n),
		.CFGERRAERHEADERLOG(cfg_err_aer_headerlog),
		.CFGERRTLPCPLHEADER(cfg_err_tlp_cpl_header),
		.CFGINTERRUPTN(cfg_interrupt_n),
		.CFGINTERRUPTDI(cfg_interrupt_di),
		.CFGINTERRUPTASSERTN(cfg_interrupt_assert_n),
		.CFGINTERRUPTSTATN(cfg_interrupt_stat_n),
		.CFGDSBUSNUMBER(cfg_ds_bus_number),
		.CFGDSDEVICENUMBER(cfg_ds_device_number),
		.CFGDSFUNCTIONNUMBER(cfg_ds_function_number),
		.CFGPORTNUMBER(cfg_port_number),
		.CFGPMHALTASPML0SN(cfg_pm_halt_aspm_l0s_n),
		.CFGPMHALTASPML1N(cfg_pm_halt_aspm_l1_n),
		.CFGPMFORCESTATEENN(cfg_pm_force_state_en_n),
		.CFGPMFORCESTATE(cfg_pm_force_state),
		.CFGPMWAKEN(cfg_pm_wake_n),
		.CFGPMTURNOFFOKN(cfg_pm_turnoff_ok_n),
		.CFGPMSENDPMETON(cfg_pm_send_pme_to_n),
		.CFGPCIECAPINTERRUPTMSGNUM(cfg_pciecap_interrupt_msgnum),
		.CFGTRNPENDINGN(cfg_trn_pending_n),
		.CFGFORCEMPS(cfg_force_mps),
		.CFGFORCECOMMONCLOCKOFF(cfg_force_common_clock_off),
		.CFGFORCEEXTENDEDSYNCON(cfg_force_extended_sync_on),
		.CFGDSN(cfg_dsn),
		.CFGDEVID(cfg_dev_id),
		.CFGVENDID(cfg_vend_id),
		.CFGREVID(cfg_rev_id),
		.CFGSUBSYSID(cfg_subsys_id),
		.CFGSUBSYSVENDID(cfg_subsys_vend_id),
		.CFGAERINTERRUPTMSGNUM(cfg_aer_interrupt_msgnum),
		.DRPCLK(drp_clk),
		.DRPEN(drp_en),
		.DRPWE(drp_we),
		.DRPADDR(drp_addr),
		.DRPDI(drp_di),
		.DBGMODE(dbg_mode),
		.DBGSUBMODE(dbg_sub_mode),
		.PLDBGMODE(pl_dbg_mode),
		.TRNTDSTRDY(trn_tdst_rdy_bus),
		.TRNTERRDROP(trn_terr_drop),
		.TRNTBUFAV(trn_tbuf_av),
		.TRNTCFGREQ(trn_tcfg_req),
		.TRNRD(trn_rd),
		.TRNRREM(trn_rrem),
		.TRNRSOF(trn_rsof),
		.TRNREOF(trn_reof),
		.TRNRSRCRDY(trn_rsrc_rdy),
		.TRNRSRCDSC(trn_rsrc_dsc),
		.TRNRECRCERR(trn_recrc_err),
		.TRNRERRFWD(trn_rerrfwd),
		.TRNRBARHIT(trn_rbar_hit),
		.TRNLNKUP(trn_lnk_up),
		.TRNFCPH(trn_fc_ph),
		.TRNFCPD(trn_fc_pd),
		.TRNFCNPH(trn_fc_nph),
		.TRNFCNPD(trn_fc_npd),
		.TRNFCCPLH(trn_fc_cplh),
		.TRNFCCPLD(trn_fc_cpld),
		.MIMTXWDATA(mim_tx_wdata),
		.MIMTXWADDR(mim_tx_waddr),
		.MIMTXWEN(mim_tx_wen),
		.MIMTXRADDR(mim_tx_raddr),
		.MIMTXREN(mim_tx_ren),
		.MIMRXWDATA(mim_rx_wdata),
		.MIMRXWADDR(mim_rx_waddr),
		.MIMRXWEN(mim_rx_wen),
		.MIMRXRADDR(mim_rx_raddr),
		.MIMRXREN(mim_rx_ren),
		.TRNTDLLPDSTRDY(trn_tdllp_dst_rdy),
		.TRNRDLLPDATA(trn_rdllp_data),
		.TRNRDLLPSRCRDY(trn_rdllp_src_rdy),
		.LL2TFCINIT1SEQ(ll2_tfc_init1_seq),
		.LL2TFCINIT2SEQ(ll2_tfc_init2_seq),
		.PL2SUSPENDOK(pl2_suspend_ok),
		.PL2RECOVERY(pl2_recovery),
		.PL2RXELECIDLE(pl2_rx_elec_idle),
		.PL2RXPMSTATE(pl2_rx_pm_state),
		.PL2L0REQ(pl2_l0_req),
		.LL2SUSPENDOK(ll2_suspend_ok),
		.LL2TXIDLE(ll2_tx_idle),
		.LL2LINKSTATUS(ll2_link_status),
		.TL2PPMSUSPENDOK(tl2_ppm_suspend_ok),
		.TL2ASPMSUSPENDREQ(tl2_aspm_suspend_req),
		.TL2ASPMSUSPENDCREDITCHECKOK(tl2_aspm_suspend_credit_check_ok),
		.PL2LINKUP(pl2_link_up),
		.PL2RECEIVERERR(pl2_receiver_err),
		.LL2RECEIVERERR(ll2_receiver_err),
		.LL2PROTOCOLERR(ll2_protocol_err),
		.LL2BADTLPERR(ll2_bad_tlp_err),
		.LL2BADDLLPERR(ll2_bad_dllp_err),
		.LL2REPLAYROERR(ll2_replay_ro_err),
		.LL2REPLAYTOERR(ll2_replay_to_err),
		.TL2ERRHDR(tl2_err_hdr),
		.TL2ERRMALFORMED(tl2_err_malformed),
		.TL2ERRRXOVERFLOW(tl2_err_rxoverflow),
		.TL2ERRFCPE(tl2_err_fcpe),
		.PLSELLNKRATE(pl_sel_lnk_rate),
		.PLSELLNKWIDTH(pl_sel_lnk_width),
		.PLLTSSMSTATE(pl_ltssm_state),
		.PLLANEREVERSALMODE(pl_lane_reversal_mode),
		.PLPHYLNKUPN(pl_phy_lnk_up_n),
		.PLTXPMSTATE(pl_tx_pm_state),
		.PLRXPMSTATE(pl_rx_pm_state),
		.PLLINKUPCFGCAP(pl_link_upcfg_cap),
		.PLLINKGEN2CAP(pl_link_gen2_cap),
		.PLLINKPARTNERGEN2SUPPORTED(pl_link_partner_gen2_supported),
		.PLINITIALLINKWIDTH(pl_initial_link_width),
		.PLDIRECTEDCHANGEDONE(pl_directed_change_done),
		.PIPETXRCVRDET(pipe_tx_rcvr_det),
		.PIPETXRESET(pipe_tx_reset),
		.PIPETXRATE(pipe_tx_rate),
		.PIPETXDEEMPH(pipe_tx_deemph),
		.PIPETXMARGIN(pipe_tx_margin),
		.PIPERX0POLARITY(pipe_rx0_polarity),
		.PIPERX1POLARITY(pipe_rx1_polarity),
		.PIPERX2POLARITY(pipe_rx2_polarity),
		.PIPERX3POLARITY(pipe_rx3_polarity),
		.PIPERX4POLARITY(pipe_rx4_polarity),
		.PIPERX5POLARITY(pipe_rx5_polarity),
		.PIPERX6POLARITY(pipe_rx6_polarity),
		.PIPERX7POLARITY(pipe_rx7_polarity),
		.PIPETX0COMPLIANCE(pipe_tx0_compliance),
		.PIPETX1COMPLIANCE(pipe_tx1_compliance),
		.PIPETX2COMPLIANCE(pipe_tx2_compliance),
		.PIPETX3COMPLIANCE(pipe_tx3_compliance),
		.PIPETX4COMPLIANCE(pipe_tx4_compliance),
		.PIPETX5COMPLIANCE(pipe_tx5_compliance),
		.PIPETX6COMPLIANCE(pipe_tx6_compliance),
		.PIPETX7COMPLIANCE(pipe_tx7_compliance),
		.PIPETX0CHARISK(pipe_tx0_char_is_k),
		.PIPETX1CHARISK(pipe_tx1_char_is_k),
		.PIPETX2CHARISK(pipe_tx2_char_is_k),
		.PIPETX3CHARISK(pipe_tx3_char_is_k),
		.PIPETX4CHARISK(pipe_tx4_char_is_k),
		.PIPETX5CHARISK(pipe_tx5_char_is_k),
		.PIPETX6CHARISK(pipe_tx6_char_is_k),
		.PIPETX7CHARISK(pipe_tx7_char_is_k),
		.PIPETX0DATA(pipe_tx0_data),
		.PIPETX1DATA(pipe_tx1_data),
		.PIPETX2DATA(pipe_tx2_data),
		.PIPETX3DATA(pipe_tx3_data),
		.PIPETX4DATA(pipe_tx4_data),
		.PIPETX5DATA(pipe_tx5_data),
		.PIPETX6DATA(pipe_tx6_data),
		.PIPETX7DATA(pipe_tx7_data),
		.PIPETX0ELECIDLE(pipe_tx0_elec_idle),
		.PIPETX1ELECIDLE(pipe_tx1_elec_idle),
		.PIPETX2ELECIDLE(pipe_tx2_elec_idle),
		.PIPETX3ELECIDLE(pipe_tx3_elec_idle),
		.PIPETX4ELECIDLE(pipe_tx4_elec_idle),
		.PIPETX5ELECIDLE(pipe_tx5_elec_idle),
		.PIPETX6ELECIDLE(pipe_tx6_elec_idle),
		.PIPETX7ELECIDLE(pipe_tx7_elec_idle),
		.PIPETX0POWERDOWN(pipe_tx0_powerdown),
		.PIPETX1POWERDOWN(pipe_tx1_powerdown),
		.PIPETX2POWERDOWN(pipe_tx2_powerdown),
		.PIPETX3POWERDOWN(pipe_tx3_powerdown),
		.PIPETX4POWERDOWN(pipe_tx4_powerdown),
		.PIPETX5POWERDOWN(pipe_tx5_powerdown),
		.PIPETX6POWERDOWN(pipe_tx6_powerdown),
		.PIPETX7POWERDOWN(pipe_tx7_powerdown),
		.USERRSTN(user_rst_n),
		.PLRECEIVEDHOTRST(pl_received_hot_rst),
		.RECEIVEDFUNCLVLRSTN(received_func_lvl_rst_n),
		.LNKCLKEN(lnk_clk_en),
		.CFGMGMTDO(cfg_mgmt_do),
		.CFGMGMTRDWRDONEN(cfg_mgmt_rd_wr_done_n),
		.CFGERRAERHEADERLOGSETN(cfg_err_aer_headerlog_set_n),
		.CFGERRCPLRDYN(cfg_err_cpl_rdy_n),
		.CFGINTERRUPTRDYN(cfg_interrupt_rdy_n),
		.CFGINTERRUPTMMENABLE(cfg_interrupt_mmenable),
		.CFGINTERRUPTMSIENABLE(cfg_interrupt_msienable),
		.CFGINTERRUPTDO(cfg_interrupt_do),
		.CFGINTERRUPTMSIXENABLE(cfg_interrupt_msixenable),
		.CFGINTERRUPTMSIXFM(cfg_interrupt_msixfm),
		.CFGMSGRECEIVED(cfg_msg_received),
		.CFGMSGDATA(cfg_msg_data),
		.CFGMSGRECEIVEDERRCOR(cfg_msg_received_err_cor),
		.CFGMSGRECEIVEDERRNONFATAL(cfg_msg_received_err_non_fatal),
		.CFGMSGRECEIVEDERRFATAL(cfg_msg_received_err_fatal),
		.CFGMSGRECEIVEDASSERTINTA(cfg_msg_received_assert_int_a),
		.CFGMSGRECEIVEDDEASSERTINTA(cfg_msg_received_deassert_int_a),
		.CFGMSGRECEIVEDASSERTINTB(cfg_msg_received_assert_int_b),
		.CFGMSGRECEIVEDDEASSERTINTB(cfg_msg_received_deassert_int_b),
		.CFGMSGRECEIVEDASSERTINTC(cfg_msg_received_assert_int_c),
		.CFGMSGRECEIVEDDEASSERTINTC(cfg_msg_received_deassert_int_c),
		.CFGMSGRECEIVEDASSERTINTD(cfg_msg_received_assert_int_d),
		.CFGMSGRECEIVEDDEASSERTINTD(cfg_msg_received_deassert_int_d),
		.CFGMSGRECEIVEDPMPME(cfg_msg_received_pm_pme),
		.CFGMSGRECEIVEDPMETOACK(cfg_msg_received_pme_to_ack),
		.CFGMSGRECEIVEDPMETO(cfg_msg_received_pme_to),
		.CFGMSGRECEIVEDSETSLOTPOWERLIMIT(cfg_msg_received_setslotpowerlimit),
		.CFGMSGRECEIVEDUNLOCK(cfg_msg_received_unlock),
		.CFGMSGRECEIVEDPMASNAK(cfg_msg_received_pm_as_nak),
		.CFGPCIELINKSTATE(cfg_pcie_link_state),
		.CFGPMRCVASREQL1N(cfg_pm_rcv_as_req_l1_n),
		.CFGPMRCVREQACKN(cfg_pm_rcv_req_ack_n),
		.CFGPMRCVENTERL1N(cfg_pm_rcv_enter_l1_n),
		.CFGPMRCVENTERL23N(cfg_pm_rcv_enter_l23_n),
		.CFGPMCSRPOWERSTATE(cfg_pmcsr_powerstate),
		.CFGPMCSRPMEEN(cfg_pmcsr_pme_en),
		.CFGPMCSRPMESTATUS(cfg_pmcsr_pme_status),
		.CFGTRANSACTION(cfg_transaction),
		.CFGTRANSACTIONTYPE(cfg_transaction_type),
		.CFGTRANSACTIONADDR(cfg_transaction_addr),
		.CFGCOMMANDIOENABLE(cfg_command_io_enable),
		.CFGCOMMANDMEMENABLE(cfg_command_mem_enable),
		.CFGCOMMANDBUSMASTERENABLE(cfg_command_bus_master_enable),
		.CFGCOMMANDINTERRUPTDISABLE(cfg_command_interrupt_disable),
		.CFGCOMMANDSERREN(cfg_command_serr_en),
		.CFGBRIDGESERREN(cfg_bridge_serr_en),
		.CFGDEVSTATUSCORRERRDETECTED(cfg_dev_status_corr_err_detected),
		.CFGDEVSTATUSNONFATALERRDETECTED(cfg_dev_status_non_fatal_err_detected),
		.CFGDEVSTATUSFATALERRDETECTED(cfg_dev_status_fatal_err_detected),
		.CFGDEVSTATUSURDETECTED(cfg_dev_status_ur_detected),
		.CFGDEVCONTROLCORRERRREPORTINGEN(cfg_dev_control_corr_err_reporting_en),
		.CFGDEVCONTROLNONFATALREPORTINGEN(cfg_dev_control_non_fatal_reporting_en),
		.CFGDEVCONTROLFATALERRREPORTINGEN(cfg_dev_control_fatal_err_reporting_en),
		.CFGDEVCONTROLURERRREPORTINGEN(cfg_dev_control_ur_err_reporting_en),
		.CFGDEVCONTROLENABLERO(cfg_dev_control_enable_ro),
		.CFGDEVCONTROLMAXPAYLOAD(cfg_dev_control_max_payload),
		.CFGDEVCONTROLEXTTAGEN(cfg_dev_control_ext_tag_en),
		.CFGDEVCONTROLPHANTOMEN(cfg_dev_control_phantom_en),
		.CFGDEVCONTROLAUXPOWEREN(cfg_dev_control_aux_power_en),
		.CFGDEVCONTROLNOSNOOPEN(cfg_dev_control_no_snoop_en),
		.CFGDEVCONTROLMAXREADREQ(cfg_dev_control_max_read_req),
		.CFGLINKSTATUSCURRENTSPEED(cfg_link_status_current_speed),
		.CFGLINKSTATUSNEGOTIATEDWIDTH(cfg_link_status_negotiated_width),
		.CFGLINKSTATUSLINKTRAINING(cfg_link_status_link_training),
		.CFGLINKSTATUSDLLACTIVE(cfg_link_status_dll_active),
		.CFGLINKSTATUSBANDWIDTHSTATUS(cfg_link_status_bandwidth_status),
		.CFGLINKSTATUSAUTOBANDWIDTHSTATUS(cfg_link_status_auto_bandwidth_status),
		.CFGLINKCONTROLASPMCONTROL(cfg_link_control_aspm_control),
		.CFGLINKCONTROLRCB(cfg_link_control_rcb),
		.CFGLINKCONTROLLINKDISABLE(cfg_link_control_link_disable),
		.CFGLINKCONTROLRETRAINLINK(cfg_link_control_retrain_link),
		.CFGLINKCONTROLCOMMONCLOCK(cfg_link_control_common_clock),
		.CFGLINKCONTROLEXTENDEDSYNC(cfg_link_control_extended_sync),
		.CFGLINKCONTROLCLOCKPMEN(cfg_link_control_clock_pm_en),
		.CFGLINKCONTROLHWAUTOWIDTHDIS(cfg_link_control_hw_auto_width_dis),
		.CFGLINKCONTROLBANDWIDTHINTEN(cfg_link_control_bandwidth_int_en),
		.CFGLINKCONTROLAUTOBANDWIDTHINTEN(cfg_link_control_auto_bandwidth_int_en),
		.CFGDEVCONTROL2CPLTIMEOUTVAL(cfg_dev_control2_cpl_timeout_val),
		.CFGDEVCONTROL2CPLTIMEOUTDIS(cfg_dev_control2_cpl_timeout_dis),
		.CFGDEVCONTROL2ARIFORWARDEN(cfg_dev_control2_ari_forward_en),
		.CFGDEVCONTROL2ATOMICREQUESTEREN(cfg_dev_control2_atomic_requester_en),
		.CFGDEVCONTROL2ATOMICEGRESSBLOCK(cfg_dev_control2_atomic_egress_block),
		.CFGDEVCONTROL2IDOREQEN(cfg_dev_control2_ido_req_en),
		.CFGDEVCONTROL2IDOCPLEN(cfg_dev_control2_ido_cpl_en),
		.CFGDEVCONTROL2LTREN(cfg_dev_control2_ltr_en),
		.CFGDEVCONTROL2TLPPREFIXBLOCK(cfg_dev_control2_tlp_prefix_block),
		.CFGSLOTCONTROLELECTROMECHILCTLPULSE(cfg_slot_control_electromech_il_ctl_pulse),
		.CFGROOTCONTROLSYSERRCORRERREN(cfg_root_control_syserr_corr_err_en),
		.CFGROOTCONTROLSYSERRNONFATALERREN(cfg_root_control_syserr_non_fatal_err_en),
		.CFGROOTCONTROLSYSERRFATALERREN(cfg_root_control_syserr_fatal_err_en),
		.CFGROOTCONTROLPMEINTEN(cfg_root_control_pme_int_en),
		.CFGAERECRCCHECKEN(cfg_aer_ecrc_check_en),
		.CFGAERECRCGENEN(cfg_aer_ecrc_gen_en),
		.CFGAERROOTERRCORRERRREPORTINGEN(cfg_aer_rooterr_corr_err_reporting_en),
		.CFGAERROOTERRNONFATALERRREPORTINGEN(cfg_aer_rooterr_non_fatal_err_reporting_en),
		.CFGAERROOTERRFATALERRREPORTINGEN(cfg_aer_rooterr_fatal_err_reporting_en),
		.CFGAERROOTERRCORRERRRECEIVED(cfg_aer_rooterr_corr_err_received),
		.CFGAERROOTERRNONFATALERRRECEIVED(cfg_aer_rooterr_non_fatal_err_received),
		.CFGAERROOTERRFATALERRRECEIVED(cfg_aer_rooterr_fatal_err_received),
		.CFGVCTCVCMAP(cfg_vc_tcvc_map),
		.DRPRDY(drp_rdy),
		.DRPDO(drp_do),
		.DBGVECA(dbg_vec_a),
		.DBGVECB(dbg_vec_b),
		.DBGVECC(dbg_vec_c),
		.DBGSCLRA(dbg_sclr_a),
		.DBGSCLRB(dbg_sclr_b),
		.DBGSCLRC(dbg_sclr_c),
		.DBGSCLRD(dbg_sclr_d),
		.DBGSCLRE(dbg_sclr_e),
		.DBGSCLRF(dbg_sclr_f),
		.DBGSCLRG(dbg_sclr_g),
		.DBGSCLRH(dbg_sclr_h),
		.DBGSCLRI(dbg_sclr_i),
		.DBGSCLRJ(dbg_sclr_j),
		.DBGSCLRK(dbg_sclr_k),
		.PLDBGVEC(pl_dbg_vec)
	);
endmodule
