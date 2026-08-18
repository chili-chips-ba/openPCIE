module host_bridge (
	pci_exp_txp,
	pci_exp_txn,
	pci_exp_rxp,
	pci_exp_rxn,
	pipe_mmcm_rst_n,
	user_clk_out,
	user_reset_out,
	user_lnk_up,
	s_axis_tx_tready,
	s_axis_tx_tdata,
	s_axis_tx_tkeep,
	s_axis_tx_tuser,
	s_axis_tx_tlast,
	s_axis_tx_tvalid,
	m_axis_rx_tdata,
	m_axis_rx_tkeep,
	m_axis_rx_tlast,
	m_axis_rx_tvalid,
	m_axis_rx_tuser,
	m_axis_rx_tready,
	tx_buf_av,
	cfg_status,
	cfg_msg_received_err_fatal,
	sys_clk,
	sys_rst_n
);
	localparam signed [31:0] C_DATA_WIDTH = 64;
	localparam signed [31:0] KEEP_WIDTH = 8;
	localparam signed [31:0] link_pkg_PCIE_LANES = 1;
	output wire [0:0] pci_exp_txp;
	output wire [0:0] pci_exp_txn;
	input [0:0] pci_exp_rxp;
	input [0:0] pci_exp_rxn;
	input pipe_mmcm_rst_n;
	output wire user_clk_out;
	output reg user_reset_out;
	output wire user_lnk_up;
	output wire s_axis_tx_tready;
	input [63:0] s_axis_tx_tdata;
	input [7:0] s_axis_tx_tkeep;
	input [3:0] s_axis_tx_tuser;
	input s_axis_tx_tlast;
	input s_axis_tx_tvalid;
	output wire [63:0] m_axis_rx_tdata;
	output wire [7:0] m_axis_rx_tkeep;
	output wire m_axis_rx_tlast;
	output wire m_axis_rx_tvalid;
	output wire [21:0] m_axis_rx_tuser;
	input m_axis_rx_tready;
	output wire [5:0] tx_buf_av;
	output wire [15:0] cfg_status;
	output wire cfg_msg_received_err_fatal;
	input sys_clk;
	input sys_rst_n;
	localparam [15:0] CFG_VEND_ID = 16'h10ee;
	localparam [15:0] CFG_DEV_ID = 16'h7121;
	localparam [7:0] CFG_REV_ID = 8'h00;
	localparam [15:0] CFG_SUBSYS_VEND_ID = 16'h10ee;
	localparam [15:0] CFG_SUBSYS_ID = 16'h0007;
	wire pipe_clk;
	wire user_clk;
	wire user_clk2;
	wire phy_rdy_n;
	wire user_rst_n;
	wire trn_lnk_up;
	wire clk_pclk;
	wire clk_rxusrclk;
	wire clk_dclk;
	wire clk_userclk1;
	wire clk_userclk2;
	wire clk_oobclk;
	wire clk_mmcm_lock;
	localparam [5:0] link_pkg_LINK_CAP_MAX_LINK_WIDTH = link_pkg_PCIE_LANES;
	wire [link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0] clk_rxoutclk;
	wire pipe_txoutclk;
	wire [link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0] pipe_rxoutclk;
	wire [link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0] pipe_pclk_sel;
	wire pipe_gen3;
	wire [5:0] pl_ltssm_state_int;
	wire pl_phy_lnk_up_wire;
	wire pl_received_hot_rst_wire;
	generate
		if (1) begin : pipe
			wire [7:0] tx_ctrl;
			localparam signed [31:0] link_pkg_PIPE_MAX_LANES = 8;
			wire [175:0] tx;
			wire [7:0] rx_polarity;
			wire [199:0] rx;
		end
	endgenerate
	localparam _param_F7E9E_DATA_W = C_DATA_WIDTH;
	localparam _param_F7E9E_USER_W = 4;
	generate
		if (1) begin : s_axis_tx_if
			localparam signed [31:0] DATA_W = _param_F7E9E_DATA_W;
			localparam signed [31:0] USER_W = _param_F7E9E_USER_W;
			localparam signed [31:0] KEEP_W = 8;
			wire [63:0] tdata;
			wire [7:0] tkeep;
			wire [3:0] tuser;
			wire tlast;
			wire tvalid;
			wire tready;
		end
	endgenerate
	localparam _param_3C406_DATA_W = C_DATA_WIDTH;
	localparam _param_3C406_USER_W = 22;
	generate
		if (1) begin : m_axis_rx_if
			localparam signed [31:0] DATA_W = _param_3C406_DATA_W;
			localparam signed [31:0] USER_W = _param_3C406_USER_W;
			localparam signed [31:0] KEEP_W = 8;
			wire [63:0] tdata;
			wire [7:0] tkeep;
			wire [21:0] tuser;
			wire tlast;
			wire tvalid;
			wire tready;
		end
	endgenerate
	assign s_axis_tx_if.tdata = s_axis_tx_tdata;
	assign s_axis_tx_if.tkeep = s_axis_tx_tkeep;
	assign s_axis_tx_if.tuser = s_axis_tx_tuser;
	assign s_axis_tx_if.tlast = s_axis_tx_tlast;
	assign s_axis_tx_if.tvalid = s_axis_tx_tvalid;
	assign s_axis_tx_tready = s_axis_tx_if.tready;
	assign m_axis_rx_tdata = m_axis_rx_if.tdata;
	assign m_axis_rx_tkeep = m_axis_rx_if.tkeep;
	assign m_axis_rx_tuser = m_axis_rx_if.tuser;
	assign m_axis_rx_tlast = m_axis_rx_if.tlast;
	assign m_axis_rx_tvalid = m_axis_rx_if.tvalid;
	assign m_axis_rx_if.tready = m_axis_rx_tready;
	clk_synth clk_synth_i(
		.CLK_CLK(sys_clk),
		.CLK_TXOUTCLK(pipe_txoutclk),
		.CLK_RXOUTCLK_IN(pipe_rxoutclk),
		.CLK_RST_N(pipe_mmcm_rst_n),
		.CLK_PCLK_SEL(pipe_pclk_sel),
		.CLK_PCLK_SEL_SLAVE(1'b0),
		.CLK_GEN3(pipe_gen3),
		.CLK_PCLK(clk_pclk),
		.CLK_PCLK_SLAVE(),
		.CLK_RXUSRCLK(clk_rxusrclk),
		.CLK_RXOUTCLK_OUT(clk_rxoutclk),
		.CLK_DCLK(clk_dclk),
		.CLK_OOBCLK(clk_oobclk),
		.CLK_USERCLK1(clk_userclk1),
		.CLK_USERCLK2(clk_userclk2),
		.CLK_MMCM_LOCK(clk_mmcm_lock)
	);
	generate
		if (1) begin : serdes_front_i
			wire [5:0] pl_ltssm_state;
			localparam signed [31:0] link_pkg_PCIE_LANES = 1;
			localparam [5:0] link_pkg_LINK_CAP_MAX_LINK_WIDTH = link_pkg_PCIE_LANES;
			wire [link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0] pci_exp_txn;
			wire [link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0] pci_exp_txp;
			wire [link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0] pci_exp_rxn;
			wire [link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0] pci_exp_rxp;
			wire sys_clk;
			wire sys_rst_n;
			wire PIPE_MMCM_RST_N;
			wire pipe_clk;
			wire user_clk;
			wire user_clk2;
			wire PIPE_PCLK_IN;
			wire PIPE_RXUSRCLK_IN;
			wire [link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0] PIPE_RXOUTCLK_IN;
			wire PIPE_DCLK_IN;
			wire PIPE_USERCLK1_IN;
			wire PIPE_USERCLK2_IN;
			wire PIPE_OOBCLK_IN;
			wire PIPE_MMCM_LOCK_IN;
			wire PIPE_TXOUTCLK_OUT;
			wire [link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0] PIPE_RXOUTCLK_OUT;
			wire [link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0] PIPE_PCLK_SEL_OUT;
			wire PIPE_GEN3_OUT;
			wire phy_rdy_n;
			wire [7:0] gt_rx_phy_status_wire;
			wire [7:0] gt_rxchanisaligned_wire;
			wire [31:0] gt_rx_data_k_wire;
			wire [255:0] gt_rx_data_wire;
			wire [7:0] gt_rx_elec_idle_wire;
			wire [23:0] gt_rx_status_wire;
			wire [7:0] gt_rx_valid_wire;
			wire [7:0] gt_rx_polarity;
			wire [15:0] gt_power_down;
			wire [7:0] gt_tx_char_disp_mode;
			wire [31:0] gt_tx_data_k;
			wire [255:0] gt_tx_data;
			wire gt_tx_detect_rx_loopback;
			wire [7:0] gt_tx_elec_idle;
			wire [link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0] phystatus_rst;
			wire clock_locked;
			wire [7:0] gt_rx_phy_status_wire_filter;
			wire [31:0] gt_rx_data_k_wire_filter;
			wire [255:0] gt_rx_data_wire_filter;
			wire [7:0] gt_rx_elec_idle_wire_filter;
			wire [23:0] gt_rx_status_wire_filter;
			wire [7:0] gt_rx_valid_wire_filter;
			wire pipe_clk_int;
			reg phy_rdy_n_int;
			reg reg_clock_locked;
			wire all_phystatus_rst;
			assign pipe_clk = pipe_clk_int;
			reg [5:0] pl_ltssm_state_q;
			always @(posedge pipe_clk_int or negedge clock_locked)
				if (!clock_locked)
					pl_ltssm_state_q <= 6'b000000;
				else
					pl_ltssm_state_q <= pl_ltssm_state;
			wire plm_in_l0 = pl_ltssm_state_q == 6'h16;
			wire plm_in_rs = pl_ltssm_state_q == 6'h1f;
			genvar _gv_i_2;
			for (_gv_i_2 = 0; _gv_i_2 < link_pkg_LINK_CAP_MAX_LINK_WIDTH; _gv_i_2 = _gv_i_2 + 1) begin : squelch_gen
				localparam i = _gv_i_2;
				eios_squelch squelch_i(
					.USER_RXCHARISK(gt_rx_data_k_wire[4 * i+:2]),
					.USER_RXDATA(gt_rx_data_wire[32 * i+:16]),
					.USER_RXVALID(gt_rx_valid_wire[i]),
					.USER_RXELECIDLE(gt_rx_elec_idle_wire[i]),
					.USER_RX_STATUS(gt_rx_status_wire[3 * i+:3]),
					.USER_RX_PHY_STATUS(gt_rx_phy_status_wire[i]),
					.GT_RXCHARISK(gt_rx_data_k_wire_filter[4 * i+:2]),
					.GT_RXDATA(gt_rx_data_wire_filter[32 * i+:16]),
					.GT_RXVALID(gt_rx_valid_wire_filter[i]),
					.GT_RXELECIDLE(gt_rx_elec_idle_wire_filter[i]),
					.GT_RX_STATUS(gt_rx_status_wire_filter[3 * i+:3]),
					.GT_RX_PHY_STATUS(gt_rx_phy_status_wire_filter[i]),
					.PLM_IN_L0(plm_in_l0),
					.PLM_IN_RS(plm_in_rs),
					.USER_CLK(pipe_clk_int),
					.RESET(phy_rdy_n_int)
				);
			end
			localparam signed [31:0] link_pkg_PIPE_MAX_LANES = 8;
			localparam [24:0] link_pkg_PIPE_RX_LANE_TIE = 25'h0000001;
			for (_gv_i_2 = 0; _gv_i_2 < link_pkg_PIPE_MAX_LANES; _gv_i_2 = _gv_i_2 + 1) begin : lane_map
				localparam i = _gv_i_2;
				assign gt_tx_data[32 * i+:32] = {16'd0, host_bridge.pipe.tx[(i * 22) + 19-:16]};
				assign gt_tx_data_k[4 * i+:4] = {2'd0, host_bridge.pipe.tx[(i * 22) + 21-:2]};
				assign gt_power_down[2 * i+:2] = host_bridge.pipe.tx[(i * 22) + 1-:2];
				assign gt_tx_char_disp_mode[i] = host_bridge.pipe.tx[(i * 22) + 3];
				assign gt_tx_elec_idle[i] = host_bridge.pipe.tx[(i * 22) + 2];
				assign gt_rx_polarity[i] = host_bridge.pipe.rx_polarity[i];
				if (i < link_pkg_LINK_CAP_MAX_LINK_WIDTH) begin : active
					assign host_bridge.pipe.rx[(i * 25) + 24-:2] = gt_rx_data_k_wire[4 * i+:2];
					assign host_bridge.pipe.rx[(i * 25) + 22-:16] = gt_rx_data_wire[32 * i+:16];
					assign host_bridge.pipe.rx[(i * 25) + 6] = gt_rx_valid_wire[i];
					assign host_bridge.pipe.rx[(i * 25) + 5] = gt_rxchanisaligned_wire[i];
					assign host_bridge.pipe.rx[(i * 25) + 4-:3] = gt_rx_status_wire[3 * i+:3];
					assign host_bridge.pipe.rx[(i * 25) + 1] = gt_rx_phy_status_wire[i];
					assign host_bridge.pipe.rx[i * 25] = gt_rx_elec_idle_wire[i];
					assign gt_rx_data_wire[(32 * i) + 16+:16] = 16'b0000000000000000;
					assign gt_rx_data_k_wire[(4 * i) + 2+:2] = 2'b00;
				end
				else begin : unused
					assign host_bridge.pipe.rx[i * 25+:25] = link_pkg_PIPE_RX_LANE_TIE;
					assign gt_rx_data_wire[32 * i+:32] = 32'b00000000000000000000000000000000;
					assign gt_rx_data_k_wire[4 * i+:4] = 4'b0000;
				end
			end
			assign gt_tx_detect_rx_loopback = host_bridge.pipe.tx_ctrl[7];
			serdes_ctrl serdes_ctrl_i(
				.PIPE_CLK(sys_clk),
				.PIPE_RESET_N(sys_rst_n),
				.PIPE_PCLK(pipe_clk_int),
				.PIPE_TXDATA(gt_tx_data[(32 * link_pkg_LINK_CAP_MAX_LINK_WIDTH) - 1:0]),
				.PIPE_TXDATAK(gt_tx_data_k[(4 * link_pkg_LINK_CAP_MAX_LINK_WIDTH) - 1:0]),
				.PIPE_TXP(pci_exp_txp),
				.PIPE_TXN(pci_exp_txn),
				.PIPE_RXP(pci_exp_rxp),
				.PIPE_RXN(pci_exp_rxn),
				.PIPE_RXDATA(gt_rx_data_wire_filter[(32 * link_pkg_LINK_CAP_MAX_LINK_WIDTH) - 1:0]),
				.PIPE_RXDATAK(gt_rx_data_k_wire_filter[(4 * link_pkg_LINK_CAP_MAX_LINK_WIDTH) - 1:0]),
				.PIPE_TXDETECTRX(gt_tx_detect_rx_loopback),
				.PIPE_TXELECIDLE(gt_tx_elec_idle[link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0]),
				.PIPE_TXCOMPLIANCE(gt_tx_char_disp_mode[link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0]),
				.PIPE_RXPOLARITY(gt_rx_polarity[link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0]),
				.PIPE_POWERDOWN(gt_power_down[(2 * link_pkg_LINK_CAP_MAX_LINK_WIDTH) - 1:0]),
				.PIPE_RATE({1'b0, host_bridge.pipe.tx_ctrl[5]}),
				.PIPE_TXMARGIN(host_bridge.pipe.tx_ctrl[3-:3]),
				.PIPE_TXSWING(1'b0),
				.PIPE_TXDEEMPH({link_pkg_LINK_CAP_MAX_LINK_WIDTH {host_bridge.pipe.tx_ctrl[4]}}),
				.PIPE_TXEQ_CONTROL({2 * link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.PIPE_TXEQ_PRESET({4 * link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.PIPE_TXEQ_PRESET_DEFAULT({4 * link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.PIPE_RXEQ_CONTROL({2 * link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.PIPE_RXEQ_PRESET({3 * link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.PIPE_RXEQ_LFFS({6 * link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.PIPE_RXEQ_TXPRESET({4 * link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.PIPE_RXEQ_USER_EN({1 * link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.PIPE_RXEQ_USER_TXCOEFF({18 * link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.PIPE_RXEQ_USER_MODE({1 * link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.PIPE_TXEQ_COEFF(),
				.PIPE_TXEQ_DEEMPH({6 * link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.PIPE_TXEQ_FS(),
				.PIPE_TXEQ_LF(),
				.PIPE_TXEQ_DONE(),
				.PIPE_RXEQ_NEW_TXCOEFF(),
				.PIPE_RXEQ_LFFS_SEL(),
				.PIPE_RXEQ_ADAPT_DONE(),
				.PIPE_RXEQ_DONE(),
				.PIPE_RXVALID(gt_rx_valid_wire_filter[link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0]),
				.PIPE_PHYSTATUS(gt_rx_phy_status_wire_filter[link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0]),
				.PIPE_PHYSTATUS_RST(phystatus_rst),
				.PIPE_RXELECIDLE(gt_rx_elec_idle_wire_filter[link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0]),
				.PIPE_EYESCANDATAERROR(),
				.PIPE_RXSTATUS(gt_rx_status_wire_filter[(3 * link_pkg_LINK_CAP_MAX_LINK_WIDTH) - 1:0]),
				.INT_PCLK_OUT_SLAVE(),
				.INT_RXUSRCLK_OUT(),
				.INT_RXOUTCLK_OUT(),
				.INT_DCLK_OUT(),
				.INT_USERCLK1_OUT(),
				.INT_USERCLK2_OUT(),
				.INT_OOBCLK_OUT(),
				.INT_MMCM_LOCK_OUT(),
				.INT_QPLLLOCK_OUT(),
				.INT_QPLLOUTCLK_OUT(),
				.INT_QPLLOUTREFCLK_OUT(),
				.INT_PCLK_SEL_SLAVE({link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.PIPE_MMCM_RST_N(PIPE_MMCM_RST_N),
				.PIPE_RXSLIDE({link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.PIPE_PCLK_LOCK(clock_locked),
				.PIPE_RXCDRLOCK(),
				.PIPE_USERCLK1(user_clk),
				.PIPE_USERCLK2(user_clk2),
				.PIPE_RXUSRCLK(),
				.PIPE_RXOUTCLK(),
				.PIPE_TXSYNC_DONE(),
				.PIPE_RXSYNC_DONE(),
				.PIPE_GEN3_RDY(),
				.PIPE_RXCHANISALIGNED(gt_rxchanisaligned_wire[link_pkg_LINK_CAP_MAX_LINK_WIDTH - 1:0]),
				.PIPE_ACTIVE_LANE(),
				.PIPE_PCLK_IN(PIPE_PCLK_IN),
				.PIPE_RXUSRCLK_IN(PIPE_RXUSRCLK_IN),
				.PIPE_RXOUTCLK_IN(PIPE_RXOUTCLK_IN),
				.PIPE_DCLK_IN(PIPE_DCLK_IN),
				.PIPE_USERCLK1_IN(PIPE_USERCLK1_IN),
				.PIPE_USERCLK2_IN(PIPE_USERCLK2_IN),
				.PIPE_OOBCLK_IN(PIPE_OOBCLK_IN),
				.PIPE_JTAG_EN(1'b0),
				.PIPE_JTAG_RDY(),
				.PIPE_MMCM_LOCK_IN(PIPE_MMCM_LOCK_IN),
				.PIPE_TXOUTCLK_OUT(PIPE_TXOUTCLK_OUT),
				.PIPE_RXOUTCLK_OUT(PIPE_RXOUTCLK_OUT),
				.PIPE_PCLK_SEL_OUT(PIPE_PCLK_SEL_OUT),
				.PIPE_GEN3_OUT(PIPE_GEN3_OUT),
				.EXT_CH_GT_DRPCLK(),
				.EXT_CH_GT_DRPADDR({9 * link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.EXT_CH_GT_DRPEN({link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.EXT_CH_GT_DRPDI({16 * link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.EXT_CH_GT_DRPWE({link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.EXT_CH_GT_DRPDO(),
				.EXT_CH_GT_DRPRDY(),
				.QPLL_DRP_CRSCODE(12'b000000000000),
				.QPLL_DRP_FSM(18'b000000000000000000),
				.QPLL_DRP_DONE(2'b00),
				.QPLL_DRP_RESET(2'b00),
				.QPLL_QPLLLOCK(2'b00),
				.QPLL_QPLLOUTCLK(2'b00),
				.QPLL_QPLLOUTREFCLK(2'b00),
				.QPLL_QPLLPD(),
				.QPLL_QPLLRESET(),
				.QPLL_DRP_CLK(),
				.QPLL_DRP_RST_N(),
				.QPLL_DRP_OVRD(),
				.QPLL_DRP_GEN3(),
				.QPLL_DRP_START(),
				.PIPE_TXPRBSSEL(3'b000),
				.PIPE_RXPRBSSEL(3'b000),
				.PIPE_TXPRBSFORCEERR(1'b0),
				.PIPE_RXPRBSCNTRESET(1'b0),
				.PIPE_LOOPBACK(3'b000),
				.PIPE_RXPRBSERR(),
				.PIPE_TXINHIBIT({link_pkg_LINK_CAP_MAX_LINK_WIDTH {1'b0}}),
				.PIPE_RST_FSM(),
				.PIPE_QRST_FSM(),
				.PIPE_RATE_FSM(),
				.PIPE_SYNC_FSM_TX(),
				.PIPE_SYNC_FSM_RX(),
				.PIPE_QDRP_FSM(),
				.PIPE_RXEQ_FSM(),
				.PIPE_TXEQ_FSM(),
				.PIPE_DRP_FSM(),
				.PIPE_RST_IDLE(),
				.PIPE_QRST_IDLE(),
				.PIPE_RATE_IDLE(),
				.PIPE_CPLL_LOCK(),
				.PIPE_QPLL_LOCK(),
				.PIPE_RXPMARESETDONE(),
				.PIPE_RXBUFSTATUS(),
				.PIPE_TXPHALIGNDONE(),
				.PIPE_TXPHINITDONE(),
				.PIPE_TXDLYSRESETDONE(),
				.PIPE_RXPHALIGNDONE(),
				.PIPE_RXDLYSRESETDONE(),
				.PIPE_RXSYNCDONE(),
				.PIPE_RXDISPERR(),
				.PIPE_RXNOTINTABLE(),
				.PIPE_RXCOMMADET(),
				.PIPE_DEBUG_0(),
				.PIPE_DEBUG_1(),
				.PIPE_DEBUG_2(),
				.PIPE_DEBUG_3(),
				.PIPE_DEBUG_4(),
				.PIPE_DEBUG_5(),
				.PIPE_DEBUG_6(),
				.PIPE_DEBUG_7(),
				.PIPE_DEBUG_8(),
				.PIPE_DEBUG_9(),
				.PIPE_DEBUG(),
				.PIPE_DMONITOROUT()
			);
			always @(posedge pipe_clk_int or negedge clock_locked)
				if (!clock_locked)
					reg_clock_locked <= 1'b0;
				else
					reg_clock_locked <= 1'b1;
			assign all_phystatus_rst = &phystatus_rst;
			always @(posedge pipe_clk_int)
				if (!reg_clock_locked)
					phy_rdy_n_int <= 1'b0;
				else
					phy_rdy_n_int <= all_phystatus_rst;
			assign phy_rdy_n = phy_rdy_n_int;
		end
	endgenerate
	assign serdes_front_i.pl_ltssm_state = pl_ltssm_state_int;
	assign pci_exp_txn = serdes_front_i.pci_exp_txn;
	assign pci_exp_txp = serdes_front_i.pci_exp_txp;
	assign serdes_front_i.pci_exp_rxn = pci_exp_rxn;
	assign serdes_front_i.pci_exp_rxp = pci_exp_rxp;
	assign serdes_front_i.sys_clk = sys_clk;
	assign serdes_front_i.sys_rst_n = sys_rst_n;
	assign serdes_front_i.PIPE_MMCM_RST_N = pipe_mmcm_rst_n;
	assign pipe_clk = serdes_front_i.pipe_clk;
	assign user_clk = serdes_front_i.user_clk;
	assign user_clk2 = serdes_front_i.user_clk2;
	assign serdes_front_i.PIPE_PCLK_IN = clk_pclk;
	assign serdes_front_i.PIPE_RXUSRCLK_IN = clk_rxusrclk;
	assign serdes_front_i.PIPE_RXOUTCLK_IN = clk_rxoutclk;
	assign serdes_front_i.PIPE_DCLK_IN = clk_dclk;
	assign serdes_front_i.PIPE_USERCLK1_IN = clk_userclk1;
	assign serdes_front_i.PIPE_USERCLK2_IN = clk_userclk2;
	assign serdes_front_i.PIPE_OOBCLK_IN = clk_oobclk;
	assign serdes_front_i.PIPE_MMCM_LOCK_IN = clk_mmcm_lock;
	assign pipe_txoutclk = serdes_front_i.PIPE_TXOUTCLK_OUT;
	assign pipe_rxoutclk = serdes_front_i.PIPE_RXOUTCLK_OUT;
	assign pipe_pclk_sel = serdes_front_i.PIPE_PCLK_SEL_OUT;
	assign pipe_gen3 = serdes_front_i.PIPE_GEN3_OUT;
	assign phy_rdy_n = serdes_front_i.phy_rdy_n;
	wire [111:0] cfg_regs;
	assign cfg_status = cfg_regs[111-:16];
	generate
		if (1) begin : txn_engine_i
			localparam signed [31:0] C_DATA_WIDTH = 64;
			localparam signed [31:0] REM_WIDTH = 1;
			wire user_clk_out;
			wire user_reset;
			wire user_lnk_up;
			wire trn_lnk_up;
			wire user_rst_n;
			wire [5:0] tx_buf_av;
			wire tx_err_drop;
			wire tx_cfg_req;
			wire tx_cfg_gnt;
			wire rx_np_ok;
			wire rx_np_req;
			wire [11:0] fc_cpld;
			wire [7:0] fc_cplh;
			wire [11:0] fc_npd;
			wire [7:0] fc_nph;
			wire [11:0] fc_pd;
			wire [7:0] fc_ph;
			wire [2:0] fc_sel;
			wire [111:0] cfg_regs;
			wire [31:0] cfg_mgmt_do;
			wire cfg_mgmt_rd_wr_done;
			wire [31:0] cfg_mgmt_di;
			wire [3:0] cfg_mgmt_byte_en;
			wire [9:0] cfg_mgmt_dwaddr;
			wire cfg_mgmt_wr_en;
			wire cfg_mgmt_rd_en;
			wire cfg_mgmt_wr_readonly;
			wire cfg_mgmt_wr_rw1c_as_rw;
			wire cfg_err_ecrc;
			wire cfg_err_ur;
			wire cfg_err_cpl_timeout;
			wire cfg_err_cpl_unexpect;
			wire cfg_err_cpl_abort;
			wire cfg_err_posted;
			wire cfg_err_cor;
			wire cfg_err_atomic_egress_blocked;
			wire cfg_err_internal_cor;
			wire cfg_err_malformed;
			wire cfg_err_mc_blocked;
			wire cfg_err_poisoned;
			wire cfg_err_norecovery;
			wire cfg_err_locked;
			wire cfg_err_internal_uncor;
			wire [47:0] cfg_err_tlp_cpl_header;
			wire cfg_err_cpl_rdy;
			wire [127:0] cfg_err_aer_headerlog;
			wire [4:0] cfg_aer_interrupt_msgnum;
			wire cfg_err_aer_headerlog_set;
			wire cfg_aer_ecrc_check_en;
			wire cfg_aer_ecrc_gen_en;
			wire cfg_interrupt;
			wire cfg_interrupt_rdy;
			wire cfg_interrupt_assert;
			wire [7:0] cfg_interrupt_di;
			wire [7:0] cfg_interrupt_do;
			wire [2:0] cfg_interrupt_mmenable;
			wire cfg_interrupt_msienable;
			wire cfg_interrupt_msixenable;
			wire cfg_interrupt_msixfm;
			wire cfg_interrupt_stat;
			wire [4:0] cfg_pciecap_interrupt_msgnum;
			wire cfg_trn_pending;
			wire cfg_pm_halt_aspm_l0s;
			wire cfg_pm_halt_aspm_l1;
			wire cfg_pm_force_state_en;
			wire [1:0] cfg_pm_force_state;
			wire cfg_pm_wake;
			wire [63:0] cfg_dsn;
			wire [7:0] cfg_ds_bus_number;
			wire [4:0] cfg_ds_device_number;
			wire [2:0] cfg_ds_function_number;
			wire cfg_turnoff_ok;
			wire cfg_to_turnoff;
			wire [7:0] cfg_bus_number;
			wire [4:0] cfg_device_number;
			wire [2:0] cfg_function_number;
			wire [2:0] cfg_pcie_link_state;
			wire cfg_pmcsr_pme_en;
			wire [1:0] cfg_pmcsr_powerstate;
			wire cfg_pmcsr_pme_status;
			wire cfg_received_func_lvl_rst;
			wire [15:0] cfg_dev_id;
			wire [15:0] cfg_vend_id;
			wire [7:0] cfg_rev_id;
			wire [15:0] cfg_subsys_id;
			wire [15:0] cfg_subsys_vend_id;
			wire cfg_msg_received;
			wire [15:0] cfg_msg_data;
			wire cfg_msg_received_pm_as_nak;
			wire cfg_msg_received_setslotpowerlimit;
			wire cfg_msg_received_err_cor;
			wire cfg_msg_received_err_non_fatal;
			wire cfg_msg_received_err_fatal;
			wire cfg_msg_received_pm_pme;
			wire cfg_msg_received_pme_to_ack;
			wire cfg_msg_received_assert_int_a;
			wire cfg_msg_received_assert_int_b;
			wire cfg_msg_received_assert_int_c;
			wire cfg_msg_received_assert_int_d;
			wire cfg_msg_received_deassert_int_a;
			wire cfg_msg_received_deassert_int_b;
			wire cfg_msg_received_deassert_int_c;
			wire cfg_msg_received_deassert_int_d;
			wire cfg_bridge_serr_en;
			wire cfg_slot_control_electromech_il_ctl_pulse;
			wire cfg_root_control_syserr_corr_err_en;
			wire cfg_root_control_syserr_non_fatal_err_en;
			wire cfg_root_control_syserr_fatal_err_en;
			wire cfg_root_control_pme_int_en;
			wire cfg_aer_rooterr_corr_err_reporting_en;
			wire cfg_aer_rooterr_non_fatal_err_reporting_en;
			wire cfg_aer_rooterr_fatal_err_reporting_en;
			wire cfg_aer_rooterr_corr_err_received;
			wire cfg_aer_rooterr_non_fatal_err_received;
			wire cfg_aer_rooterr_fatal_err_received;
			wire [6:0] cfg_vc_tcvc_map;
			wire [1:0] pl_directed_link_change;
			wire [1:0] pl_directed_link_width;
			wire pl_directed_link_speed;
			wire pl_directed_link_auton;
			wire pl_upstream_prefer_deemph;
			wire pl_downstream_deemph_source;
			wire pl_transmit_hot_rst;
			wire pl_sel_lnk_rate;
			wire [1:0] pl_sel_lnk_width;
			wire [5:0] pl_ltssm_state;
			wire [1:0] pl_lane_reversal_mode;
			wire pl_phy_lnk_up;
			wire [2:0] pl_tx_pm_state;
			wire [1:0] pl_rx_pm_state;
			wire pl_link_upcfg_cap;
			wire pl_link_gen2_cap;
			wire pl_link_partner_gen2_supported;
			wire [2:0] pl_initial_link_width;
			wire pl_directed_change_done;
			wire pl_received_hot_rst;
			wire pcie_drp_clk;
			wire pcie_drp_en;
			wire pcie_drp_we;
			wire [8:0] pcie_drp_addr;
			wire [15:0] pcie_drp_di;
			wire pcie_drp_rdy;
			wire [15:0] pcie_drp_do;
			wire phy_rdy_n;
			wire pipe_clk;
			wire user_clk;
			wire user_clk2;
			assign user_clk_out = user_clk;
			wire [63:0] trn_td;
			wire [0:0] trn_trem;
			wire trn_tsof;
			wire trn_teof;
			wire trn_tsrc_rdy;
			wire trn_tdst_rdy;
			wire trn_tsrc_dsc;
			wire trn_terrfwd;
			wire trn_tecrc_gen;
			wire trn_tstr;
			wire trn_tcfg_gnt;
			wire [127:0] trn_rd;
			wire [1:0] trn_rrem;
			wire trn_rdst_rdy;
			wire trn_rsof;
			wire trn_reof;
			wire trn_rsrc_rdy;
			wire trn_rsrc_dsc;
			wire trn_rerrfwd;
			wire trn_recrc_err;
			wire [7:0] trn_rbar_hit;
			localparam signed [31:0] link_pkg_PIPE_MAX_LANES = 8;
			wire [1:0] tx_char_is_k_blk [0:7];
			wire [15:0] tx_data_blk [0:7];
			wire tx_compliance_blk [0:7];
			wire tx_elec_idle_blk [0:7];
			wire [1:0] tx_powerdown_blk [0:7];
			wire rx_polarity_flat [0:7];
			wire tx_rcvr_det_blk;
			wire tx_reset_blk;
			wire tx_rate_blk;
			wire tx_deemph_blk;
			wire [2:0] tx_margin_blk;
			wire [7:0] tx_ctrl_blk;
			wire [175:0] tx_blk;
			wire [7:0] rx_polarity_blk;
			wire [199:0] rx_blk;
			reg [7:0] tx_ctrl_q;
			reg [175:0] tx_q;
			reg [7:0] rx_polarity_q;
			reg [199:0] rx_q;
			assign tx_ctrl_blk = {tx_rcvr_det_blk, tx_reset_blk, tx_rate_blk, tx_deemph_blk, tx_margin_blk, 1'b0};
			genvar _gv_l_1;
			for (_gv_l_1 = 0; _gv_l_1 < link_pkg_PIPE_MAX_LANES; _gv_l_1 = _gv_l_1 + 1) begin : tx_pack
				localparam l = _gv_l_1;
				assign tx_blk[l * 22+:22] = {tx_char_is_k_blk[l], tx_data_blk[l], tx_compliance_blk[l], tx_elec_idle_blk[l], tx_powerdown_blk[l]};
				assign rx_polarity_blk[l] = rx_polarity_flat[l];
			end
			localparam [24:0] link_pkg_PIPE_RX_LANE_RST = 25'h0000000;
			localparam [7:0] link_pkg_PIPE_TX_CTRL_RST = 8'b01010000;
			localparam [21:0] link_pkg_PIPE_TX_LANE_RST = 22'h000006;
			always @(posedge pipe_clk)
				if (phy_rdy_n) begin
					tx_ctrl_q <= link_pkg_PIPE_TX_CTRL_RST;
					rx_polarity_q <= 1'sb0;
					begin : sv2v_autoblock_1
						reg signed [31:0] l;
						for (l = 0; l < link_pkg_PIPE_MAX_LANES; l = l + 1)
							begin
								tx_q[l * 22+:22] <= link_pkg_PIPE_TX_LANE_RST;
								rx_q[l * 25+:25] <= link_pkg_PIPE_RX_LANE_RST;
							end
					end
				end
				else begin
					tx_ctrl_q <= tx_ctrl_blk;
					rx_polarity_q <= rx_polarity_blk;
					tx_q <= tx_blk;
					rx_q <= host_bridge.pipe.rx;
				end
			assign host_bridge.pipe.tx_ctrl = tx_ctrl_q;
			genvar _gv_l_2;
			localparam signed [31:0] link_pkg_PCIE_LANES = 1;
			localparam [24:0] link_pkg_PIPE_RX_LANE_TIE = 25'h0000001;
			localparam [21:0] link_pkg_PIPE_TX_LANE_TIE = 22'h000004;
			for (_gv_l_2 = 0; _gv_l_2 < link_pkg_PIPE_MAX_LANES; _gv_l_2 = _gv_l_2 + 1) begin : pipe_lane_sel
				localparam l = _gv_l_2;
				if (l < link_pkg_PCIE_LANES) begin : active
					assign host_bridge.pipe.tx[l * 22+:22] = tx_q[l * 22+:22];
					assign host_bridge.pipe.rx_polarity[l] = rx_polarity_q[l];
					assign rx_blk[l * 25+:25] = rx_q[l * 25+:25];
				end
				else begin : unused
					assign host_bridge.pipe.tx[l * 22+:22] = link_pkg_PIPE_TX_LANE_TIE;
					assign host_bridge.pipe.rx_polarity[l] = 1'b0;
					assign rx_blk[l * 25+:25] = link_pkg_PIPE_RX_LANE_TIE;
				end
			end
			wire cfg_received_func_lvl_rst_n;
			wire cfg_err_cpl_rdy_n;
			wire cfg_interrupt_rdy_n;
			wire cfg_mgmt_rd_wr_done_n;
			wire pl_phy_lnk_up_n;
			wire cfg_err_aer_headerlog_set_n;
			wire cfg_msg_received_pme_to;
			wire cfg_turnoff_ok_w;
			assign cfg_received_func_lvl_rst = ~cfg_received_func_lvl_rst_n;
			assign cfg_err_cpl_rdy = ~cfg_err_cpl_rdy_n;
			assign cfg_interrupt_rdy = ~cfg_interrupt_rdy_n;
			assign cfg_mgmt_rd_wr_done = ~cfg_mgmt_rd_wr_done_n;
			assign pl_phy_lnk_up = ~pl_phy_lnk_up_n;
			assign cfg_err_aer_headerlog_set = ~cfg_err_aer_headerlog_set_n;
			assign cfg_to_turnoff = cfg_msg_received_pme_to;
			wire cfg_command_interrupt_disable;
			wire cfg_command_serr_en;
			wire cfg_command_bus_master_enable;
			wire cfg_command_mem_enable;
			wire cfg_command_io_enable;
			wire cfg_dev_status_ur_detected;
			wire cfg_dev_status_fatal_err_detected;
			wire cfg_dev_status_non_fatal_err_detected;
			wire cfg_dev_status_corr_err_detected;
			wire [2:0] cfg_dev_control_max_read_req;
			wire cfg_dev_control_no_snoop_en;
			wire cfg_dev_control_aux_power_en;
			wire cfg_dev_control_phantom_en;
			wire cfg_dev_control_ext_tag_en;
			wire [2:0] cfg_dev_control_max_payload;
			wire cfg_dev_control_enable_ro;
			wire cfg_dev_control_ur_err_reporting_en;
			wire cfg_dev_control_fatal_err_reporting_en;
			wire cfg_dev_control_non_fatal_reporting_en;
			wire cfg_dev_control_corr_err_reporting_en;
			wire cfg_link_status_auto_bandwidth_status;
			wire cfg_link_status_bandwidth_status;
			wire cfg_link_status_dll_active;
			wire cfg_link_status_link_training;
			wire [3:0] cfg_link_status_negotiated_width;
			wire [1:0] cfg_link_status_current_speed;
			wire cfg_link_control_auto_bandwidth_int_en;
			wire cfg_link_control_bandwidth_int_en;
			wire cfg_link_control_hw_auto_width_dis;
			wire cfg_link_control_clock_pm_en;
			wire cfg_link_control_extended_sync;
			wire cfg_link_control_common_clock;
			wire cfg_link_control_retrain_link;
			wire cfg_link_control_link_disable;
			wire cfg_link_control_rcb;
			wire [1:0] cfg_link_control_aspm_control;
			wire cfg_dev_control2_tlp_prefix_block;
			wire cfg_dev_control2_ltr_en;
			wire cfg_dev_control2_ido_cpl_en;
			wire cfg_dev_control2_ido_req_en;
			wire cfg_dev_control2_atomic_egress_block;
			wire cfg_dev_control2_atomic_requester_en;
			wire cfg_dev_control2_ari_forward_en;
			wire cfg_dev_control2_cpl_timeout_dis;
			wire [3:0] cfg_dev_control2_cpl_timeout_val;
			assign cfg_regs[111-:16] = 16'b0000000000000000;
			assign cfg_regs[95-:16] = {5'b00000, cfg_command_interrupt_disable, 1'b0, cfg_command_serr_en, 5'b00000, cfg_command_bus_master_enable, cfg_command_mem_enable, cfg_command_io_enable};
			assign cfg_regs[79-:16] = {10'h000, cfg_trn_pending, 1'b0, cfg_dev_status_ur_detected, cfg_dev_status_fatal_err_detected, cfg_dev_status_non_fatal_err_detected, cfg_dev_status_corr_err_detected};
			assign cfg_regs[63-:16] = {1'b0, cfg_dev_control_max_read_req, cfg_dev_control_no_snoop_en, cfg_dev_control_aux_power_en, cfg_dev_control_phantom_en, cfg_dev_control_ext_tag_en, cfg_dev_control_max_payload, cfg_dev_control_enable_ro, cfg_dev_control_ur_err_reporting_en, cfg_dev_control_fatal_err_reporting_en, cfg_dev_control_non_fatal_reporting_en, cfg_dev_control_corr_err_reporting_en};
			assign cfg_regs[47-:16] = {cfg_link_status_auto_bandwidth_status, cfg_link_status_bandwidth_status, cfg_link_status_dll_active, 1'b1, cfg_link_status_link_training, 3'b000, cfg_link_status_negotiated_width, 2'b00, cfg_link_status_current_speed};
			assign cfg_regs[31-:16] = {4'b0000, cfg_link_control_auto_bandwidth_int_en, cfg_link_control_bandwidth_int_en, cfg_link_control_hw_auto_width_dis, cfg_link_control_clock_pm_en, cfg_link_control_extended_sync, cfg_link_control_common_clock, cfg_link_control_retrain_link, cfg_link_control_link_disable, cfg_link_control_rcb, 1'b0, cfg_link_control_aspm_control};
			assign cfg_regs[15-:16] = {4'b0000, cfg_dev_control2_tlp_prefix_block, cfg_dev_control2_ltr_en, cfg_dev_control2_ido_cpl_en, cfg_dev_control2_ido_req_en, cfg_dev_control2_atomic_egress_block, cfg_dev_control2_atomic_requester_en, cfg_dev_control2_ari_forward_en, cfg_dev_control2_cpl_timeout_dis, cfg_dev_control2_cpl_timeout_val};
			reg [7:0] cfg_bus_number_d;
			reg [4:0] cfg_device_number_d;
			reg [2:0] cfg_function_number_d;
			assign cfg_bus_number = cfg_bus_number_d;
			assign cfg_device_number = cfg_device_number_d;
			assign cfg_function_number = cfg_function_number_d;
			always @(posedge user_clk_out)
				if (~user_lnk_up) begin
					cfg_bus_number_d <= 8'b00000000;
					cfg_device_number_d <= 5'b00000;
					cfg_function_number_d <= 3'b000;
				end
				else if (~cfg_msg_received) begin
					cfg_bus_number_d <= cfg_msg_data[15:8];
					cfg_device_number_d <= cfg_msg_data[7:3];
					cfg_function_number_d <= cfg_msg_data[2:0];
				end
			if (1) begin : stream_bridge_i
				reg _sv2v_0;
				localparam signed [31:0] C_DATA_WIDTH = 64;
				localparam signed [31:0] KEEP_WIDTH = 8;
				localparam signed [31:0] REM_WIDTH = 1;
				wire user_turnoff_ok;
				wire user_tcfg_gnt;
				wire [63:0] trn_td;
				wire trn_tsof;
				wire trn_teof;
				wire trn_tsrc_rdy;
				wire trn_tdst_rdy;
				wire trn_tsrc_dsc;
				wire [0:0] trn_trem;
				wire trn_terrfwd;
				wire trn_tstr;
				wire [5:0] trn_tbuf_av;
				wire trn_tecrc_gen;
				wire [63:0] trn_rd;
				wire trn_rsof;
				wire trn_reof;
				wire trn_rsrc_rdy;
				wire trn_rdst_rdy;
				wire trn_rsrc_dsc;
				wire [0:0] trn_rrem;
				wire trn_rerrfwd;
				wire [6:0] trn_rbar_hit;
				wire trn_recrc_err;
				wire trn_tcfg_req;
				wire trn_tcfg_gnt;
				wire trn_lnk_up;
				wire [2:0] cfg_pcie_link_state;
				wire cfg_pm_send_pme_to;
				wire [1:0] cfg_pmcsr_powerstate;
				wire [31:0] trn_rdllp_data;
				wire trn_rdllp_src_rdy;
				wire cfg_to_turnoff;
				wire cfg_turnoff_ok;
				wire [2:0] np_counter;
				wire user_clk;
				wire user_rst;
				wire tready_thrtl;
				wire null_rx_tvalid;
				wire null_rx_tlast;
				wire [7:0] null_rx_tkeep;
				wire null_rdst_rdy;
				reg [4:0] null_is_eof;
				stream_rx_path rx_path_i(
					.m_axis_rx_tdata(host_bridge.m_axis_rx_if.tdata),
					.m_axis_rx_tvalid(host_bridge.m_axis_rx_if.tvalid),
					.m_axis_rx_tready(host_bridge.m_axis_rx_if.tready),
					.m_axis_rx_tkeep(host_bridge.m_axis_rx_if.tkeep),
					.m_axis_rx_tlast(host_bridge.m_axis_rx_if.tlast),
					.m_axis_rx_tuser(host_bridge.m_axis_rx_if.tuser),
					.trn_rd(trn_rd),
					.trn_rsof(trn_rsof),
					.trn_reof(trn_reof),
					.trn_rsrc_rdy(trn_rsrc_rdy),
					.trn_rdst_rdy(trn_rdst_rdy),
					.trn_rsrc_dsc(trn_rsrc_dsc),
					.trn_rrem(trn_rrem),
					.trn_rerrfwd(trn_rerrfwd),
					.trn_rbar_hit(trn_rbar_hit),
					.trn_recrc_err(trn_recrc_err),
					.null_rx_tvalid(null_rx_tvalid),
					.null_rx_tlast(null_rx_tlast),
					.null_rx_tkeep(null_rx_tkeep),
					.null_rdst_rdy(null_rdst_rdy),
					.null_is_eof(null_is_eof),
					.np_counter(np_counter),
					.user_clk(user_clk),
					.user_rst(user_rst)
				);
				localparam [10:0] NG_INTERFACE_WIDTH_DWORDS = 11'd2;
				localparam [0:0] NG_IDLE = 1'b0;
				localparam [0:0] NG_IN_PACKET = 1'b1;
				reg ng_cur_state;
				reg ng_next_state;
				reg [11:0] ng_reg_pkt_len_counter;
				reg [11:0] ng_pkt_len_counter;
				wire [11:0] ng_pkt_len_counter_dec;
				wire ng_pkt_done;
				wire [11:0] ng_new_pkt_len;
				wire [9:0] ng_payload_len;
				wire [1:0] ng_packet_fmt;
				wire ng_packet_td;
				reg [1:0] ng_packet_overhead;
				wire [7:0] ng_eof_tkeep;
				wire ng_eof;
				assign ng_eof = host_bridge.m_axis_rx_if.tuser[21];
				assign ng_packet_fmt = host_bridge.m_axis_rx_if.tdata[30:29];
				assign ng_packet_td = host_bridge.m_axis_rx_if.tdata[15];
				assign ng_payload_len = (ng_packet_fmt[1] ? host_bridge.m_axis_rx_if.tdata[9:0] : 10'h000);
				always @(*) begin
					if (_sv2v_0)
						;
					case ({ng_packet_fmt[0], ng_packet_td})
						2'b00: ng_packet_overhead = 2'b01;
						2'b01: ng_packet_overhead = 2'b10;
						2'b10: ng_packet_overhead = 2'b10;
						2'b11: ng_packet_overhead = 2'b11;
						default: ng_packet_overhead = 2'b01;
					endcase
				end
				assign ng_new_pkt_len = {10'b0000000000, ng_packet_overhead} + {2'b00, ng_payload_len};
				assign ng_pkt_len_counter_dec = ng_reg_pkt_len_counter - NG_INTERFACE_WIDTH_DWORDS;
				assign ng_pkt_done = ng_reg_pkt_len_counter <= NG_INTERFACE_WIDTH_DWORDS;
				always @(*) begin
					if (_sv2v_0)
						;
					case (ng_cur_state)
						NG_IDLE: begin
							if ((host_bridge.m_axis_rx_if.tvalid && host_bridge.m_axis_rx_if.tready) && !ng_eof)
								ng_next_state = NG_IN_PACKET;
							else
								ng_next_state = NG_IDLE;
							ng_pkt_len_counter = ng_new_pkt_len;
						end
						NG_IN_PACKET:
							if (host_bridge.m_axis_rx_if.tready && ng_pkt_done) begin
								ng_pkt_len_counter = ng_new_pkt_len;
								ng_next_state = NG_IDLE;
							end
							else begin
								ng_pkt_len_counter = (host_bridge.m_axis_rx_if.tready ? ng_pkt_len_counter_dec : ng_reg_pkt_len_counter);
								ng_next_state = NG_IN_PACKET;
							end
						default: begin
							ng_pkt_len_counter = ng_reg_pkt_len_counter;
							ng_next_state = NG_IDLE;
						end
					endcase
				end
				always @(posedge user_clk)
					if (user_rst) begin
						ng_cur_state <= NG_IDLE;
						ng_reg_pkt_len_counter <= 12'h000;
					end
					else begin
						ng_cur_state <= ng_next_state;
						ng_reg_pkt_len_counter <= ng_pkt_len_counter;
					end
				always @(*) begin
					if (_sv2v_0)
						;
					case (ng_pkt_len_counter)
						12'd1: null_is_eof = 5'b10011;
						12'd2: null_is_eof = 5'b10111;
						default: null_is_eof = 5'b00011;
					endcase
				end
				assign ng_eof_tkeep = {(ng_pkt_len_counter == 12'd2 ? 4'hf : 4'h0), 4'hf};
				assign null_rx_tvalid = 1'b1;
				assign null_rx_tlast = ng_pkt_len_counter <= NG_INTERFACE_WIDTH_DWORDS;
				assign null_rx_tkeep = (null_rx_tlast ? ng_eof_tkeep : 8'hff);
				assign null_rdst_rdy = null_rx_tlast;
				stream_tx_path tx_path_i(
					.s_axis_tx_tdata(host_bridge.s_axis_tx_if.tdata),
					.s_axis_tx_tready(host_bridge.s_axis_tx_if.tready),
					.s_axis_tx_tvalid(host_bridge.s_axis_tx_if.tvalid),
					.s_axis_tx_tkeep(host_bridge.s_axis_tx_if.tkeep),
					.s_axis_tx_tlast(host_bridge.s_axis_tx_if.tlast),
					.s_axis_tx_tuser(host_bridge.s_axis_tx_if.tuser),
					.trn_td(trn_td),
					.trn_tsof(trn_tsof),
					.trn_teof(trn_teof),
					.trn_tsrc_rdy(trn_tsrc_rdy),
					.trn_tdst_rdy(trn_tdst_rdy),
					.trn_tsrc_dsc(trn_tsrc_dsc),
					.trn_trem(trn_trem),
					.trn_terrfwd(trn_terrfwd),
					.trn_tstr(trn_tstr),
					.trn_tecrc_gen(trn_tecrc_gen),
					.trn_lnk_up(trn_lnk_up),
					.tready_thrtl(tready_thrtl),
					.user_clk(user_clk),
					.user_rst(user_rst)
				);
				stream_tx_gate tx_gate_i(
					.s_axis_tx_tdata(host_bridge.s_axis_tx_if.tdata),
					.s_axis_tx_tvalid(host_bridge.s_axis_tx_if.tvalid),
					.s_axis_tx_tuser(host_bridge.s_axis_tx_if.tuser),
					.s_axis_tx_tlast(host_bridge.s_axis_tx_if.tlast),
					.user_turnoff_ok(user_turnoff_ok),
					.user_tcfg_gnt(user_tcfg_gnt),
					.trn_tbuf_av(trn_tbuf_av),
					.trn_tdst_rdy(trn_tdst_rdy),
					.trn_tcfg_req(trn_tcfg_req),
					.trn_tcfg_gnt(trn_tcfg_gnt),
					.trn_lnk_up(trn_lnk_up),
					.cfg_pcie_link_state(cfg_pcie_link_state),
					.cfg_pm_send_pme_to(cfg_pm_send_pme_to),
					.cfg_pmcsr_powerstate(cfg_pmcsr_powerstate),
					.trn_rdllp_data(trn_rdllp_data),
					.trn_rdllp_src_rdy(trn_rdllp_src_rdy),
					.cfg_to_turnoff(cfg_to_turnoff),
					.cfg_turnoff_ok(cfg_turnoff_ok),
					.tready_thrtl(tready_thrtl),
					.user_clk(user_clk),
					.user_rst(user_rst)
				);
				initial _sv2v_0 = 0;
			end
			assign stream_bridge_i.user_turnoff_ok = cfg_turnoff_ok;
			assign stream_bridge_i.user_tcfg_gnt = tx_cfg_gnt;
			assign trn_td = stream_bridge_i.trn_td;
			assign trn_tsof = stream_bridge_i.trn_tsof;
			assign trn_teof = stream_bridge_i.trn_teof;
			assign trn_tsrc_rdy = stream_bridge_i.trn_tsrc_rdy;
			assign stream_bridge_i.trn_tdst_rdy = trn_tdst_rdy;
			assign trn_tsrc_dsc = stream_bridge_i.trn_tsrc_dsc;
			assign trn_trem = stream_bridge_i.trn_trem;
			assign trn_terrfwd = stream_bridge_i.trn_terrfwd;
			assign trn_tstr = stream_bridge_i.trn_tstr;
			assign stream_bridge_i.trn_tbuf_av = tx_buf_av;
			assign trn_tecrc_gen = stream_bridge_i.trn_tecrc_gen;
			assign stream_bridge_i.trn_rd = trn_rd[63:0];
			assign stream_bridge_i.trn_rsof = trn_rsof;
			assign stream_bridge_i.trn_reof = trn_reof;
			assign stream_bridge_i.trn_rsrc_rdy = trn_rsrc_rdy;
			assign trn_rdst_rdy = stream_bridge_i.trn_rdst_rdy;
			assign stream_bridge_i.trn_rsrc_dsc = trn_rsrc_dsc;
			assign stream_bridge_i.trn_rrem = trn_rrem[0:0];
			assign stream_bridge_i.trn_rerrfwd = trn_rerrfwd;
			assign stream_bridge_i.trn_rbar_hit = trn_rbar_hit[6:0];
			assign stream_bridge_i.trn_recrc_err = trn_recrc_err;
			assign stream_bridge_i.trn_tcfg_req = tx_cfg_req;
			assign trn_tcfg_gnt = stream_bridge_i.trn_tcfg_gnt;
			assign stream_bridge_i.trn_lnk_up = user_lnk_up;
			assign stream_bridge_i.cfg_pcie_link_state = cfg_pcie_link_state;
			assign stream_bridge_i.cfg_pm_send_pme_to = 1'b0;
			assign stream_bridge_i.cfg_pmcsr_powerstate = cfg_pmcsr_powerstate;
			assign stream_bridge_i.trn_rdllp_data = 32'b00000000000000000000000000000000;
			assign stream_bridge_i.trn_rdllp_src_rdy = 1'b0;
			assign stream_bridge_i.cfg_to_turnoff = cfg_to_turnoff;
			assign cfg_turnoff_ok_w = stream_bridge_i.cfg_turnoff_ok;
			assign stream_bridge_i.user_clk = user_clk_out;
			assign stream_bridge_i.user_rst = user_reset;
			silicon_core silicon_core_i(
				.trn_lnk_up(trn_lnk_up),
				.trn_clk(user_clk_out),
				.lnk_clk_en(),
				.user_rst_n(user_rst_n),
				.received_func_lvl_rst_n(cfg_received_func_lvl_rst_n),
				.sys_rst_n(~phy_rdy_n),
				.pl_rst_n(1'b1),
				.dl_rst_n(1'b1),
				.tl_rst_n(1'b1),
				.cm_sticky_rst_n(1'b1),
				.func_lvl_rst_n(1'b1),
				.cm_rst_n(1'b1),
				.trn_rbar_hit(trn_rbar_hit),
				.trn_rd(trn_rd),
				.trn_recrc_err(trn_recrc_err),
				.trn_reof(trn_reof),
				.trn_rerrfwd(trn_rerrfwd),
				.trn_rrem(trn_rrem),
				.trn_rsof(trn_rsof),
				.trn_rsrc_dsc(trn_rsrc_dsc),
				.trn_rsrc_rdy(trn_rsrc_rdy),
				.trn_rdst_rdy(trn_rdst_rdy),
				.trn_rnp_ok(rx_np_ok),
				.trn_rnp_req(rx_np_req),
				.trn_rfcp_ret(1'b1),
				.trn_tbuf_av(tx_buf_av),
				.trn_tcfg_req(tx_cfg_req),
				.trn_tdllp_dst_rdy(),
				.trn_tdst_rdy(trn_tdst_rdy),
				.trn_terr_drop(tx_err_drop),
				.trn_tcfg_gnt(trn_tcfg_gnt),
				.trn_td(trn_td),
				.trn_tdllp_data(32'b00000000000000000000000000000000),
				.trn_tdllp_src_rdy(1'b0),
				.trn_tecrc_gen(trn_tecrc_gen),
				.trn_teof(trn_teof),
				.trn_terrfwd(trn_terrfwd),
				.trn_trem(trn_trem),
				.trn_tsof(trn_tsof),
				.trn_tsrc_dsc(trn_tsrc_dsc),
				.trn_tsrc_rdy(trn_tsrc_rdy),
				.trn_tstr(trn_tstr),
				.trn_fc_cpld(fc_cpld),
				.trn_fc_cplh(fc_cplh),
				.trn_fc_npd(fc_npd),
				.trn_fc_nph(fc_nph),
				.trn_fc_pd(fc_pd),
				.trn_fc_ph(fc_ph),
				.trn_fc_sel(fc_sel),
				.cfg_dev_id(cfg_dev_id),
				.cfg_vend_id(cfg_vend_id),
				.cfg_rev_id(cfg_rev_id),
				.cfg_subsys_id(cfg_subsys_id),
				.cfg_subsys_vend_id(cfg_subsys_vend_id),
				.cfg_pciecap_interrupt_msgnum(cfg_pciecap_interrupt_msgnum),
				.cfg_bridge_serr_en(cfg_bridge_serr_en),
				.cfg_command_bus_master_enable(cfg_command_bus_master_enable),
				.cfg_command_interrupt_disable(cfg_command_interrupt_disable),
				.cfg_command_io_enable(cfg_command_io_enable),
				.cfg_command_mem_enable(cfg_command_mem_enable),
				.cfg_command_serr_en(cfg_command_serr_en),
				.cfg_dev_control_aux_power_en(cfg_dev_control_aux_power_en),
				.cfg_dev_control_corr_err_reporting_en(cfg_dev_control_corr_err_reporting_en),
				.cfg_dev_control_enable_ro(cfg_dev_control_enable_ro),
				.cfg_dev_control_ext_tag_en(cfg_dev_control_ext_tag_en),
				.cfg_dev_control_fatal_err_reporting_en(cfg_dev_control_fatal_err_reporting_en),
				.cfg_dev_control_max_payload(cfg_dev_control_max_payload),
				.cfg_dev_control_max_read_req(cfg_dev_control_max_read_req),
				.cfg_dev_control_non_fatal_reporting_en(cfg_dev_control_non_fatal_reporting_en),
				.cfg_dev_control_no_snoop_en(cfg_dev_control_no_snoop_en),
				.cfg_dev_control_phantom_en(cfg_dev_control_phantom_en),
				.cfg_dev_control_ur_err_reporting_en(cfg_dev_control_ur_err_reporting_en),
				.cfg_dev_control2_cpl_timeout_dis(cfg_dev_control2_cpl_timeout_dis),
				.cfg_dev_control2_cpl_timeout_val(cfg_dev_control2_cpl_timeout_val),
				.cfg_dev_control2_ari_forward_en(cfg_dev_control2_ari_forward_en),
				.cfg_dev_control2_atomic_requester_en(cfg_dev_control2_atomic_requester_en),
				.cfg_dev_control2_atomic_egress_block(cfg_dev_control2_atomic_egress_block),
				.cfg_dev_control2_ido_req_en(cfg_dev_control2_ido_req_en),
				.cfg_dev_control2_ido_cpl_en(cfg_dev_control2_ido_cpl_en),
				.cfg_dev_control2_ltr_en(cfg_dev_control2_ltr_en),
				.cfg_dev_control2_tlp_prefix_block(cfg_dev_control2_tlp_prefix_block),
				.cfg_dev_status_corr_err_detected(cfg_dev_status_corr_err_detected),
				.cfg_dev_status_fatal_err_detected(cfg_dev_status_fatal_err_detected),
				.cfg_dev_status_non_fatal_err_detected(cfg_dev_status_non_fatal_err_detected),
				.cfg_dev_status_ur_detected(cfg_dev_status_ur_detected),
				.cfg_mgmt_do(cfg_mgmt_do),
				.cfg_err_aer_headerlog_set_n(cfg_err_aer_headerlog_set_n),
				.cfg_err_aer_headerlog(cfg_err_aer_headerlog),
				.cfg_err_cpl_rdy_n(cfg_err_cpl_rdy_n),
				.cfg_interrupt_do(cfg_interrupt_do),
				.cfg_interrupt_mmenable(cfg_interrupt_mmenable),
				.cfg_interrupt_msienable(cfg_interrupt_msienable),
				.cfg_interrupt_msixenable(cfg_interrupt_msixenable),
				.cfg_interrupt_msixfm(cfg_interrupt_msixfm),
				.cfg_interrupt_rdy_n(cfg_interrupt_rdy_n),
				.cfg_link_control_rcb(cfg_link_control_rcb),
				.cfg_link_control_aspm_control(cfg_link_control_aspm_control),
				.cfg_link_control_auto_bandwidth_int_en(cfg_link_control_auto_bandwidth_int_en),
				.cfg_link_control_bandwidth_int_en(cfg_link_control_bandwidth_int_en),
				.cfg_link_control_clock_pm_en(cfg_link_control_clock_pm_en),
				.cfg_link_control_common_clock(cfg_link_control_common_clock),
				.cfg_link_control_extended_sync(cfg_link_control_extended_sync),
				.cfg_link_control_hw_auto_width_dis(cfg_link_control_hw_auto_width_dis),
				.cfg_link_control_link_disable(cfg_link_control_link_disable),
				.cfg_link_control_retrain_link(cfg_link_control_retrain_link),
				.cfg_link_status_auto_bandwidth_status(cfg_link_status_auto_bandwidth_status),
				.cfg_link_status_bandwidth_status(cfg_link_status_bandwidth_status),
				.cfg_link_status_current_speed(cfg_link_status_current_speed),
				.cfg_link_status_dll_active(cfg_link_status_dll_active),
				.cfg_link_status_link_training(cfg_link_status_link_training),
				.cfg_link_status_negotiated_width(cfg_link_status_negotiated_width),
				.cfg_msg_data(cfg_msg_data),
				.cfg_msg_received(cfg_msg_received),
				.cfg_msg_received_assert_int_a(cfg_msg_received_assert_int_a),
				.cfg_msg_received_assert_int_b(cfg_msg_received_assert_int_b),
				.cfg_msg_received_assert_int_c(cfg_msg_received_assert_int_c),
				.cfg_msg_received_assert_int_d(cfg_msg_received_assert_int_d),
				.cfg_msg_received_deassert_int_a(cfg_msg_received_deassert_int_a),
				.cfg_msg_received_deassert_int_b(cfg_msg_received_deassert_int_b),
				.cfg_msg_received_deassert_int_c(cfg_msg_received_deassert_int_c),
				.cfg_msg_received_deassert_int_d(cfg_msg_received_deassert_int_d),
				.cfg_msg_received_err_cor(cfg_msg_received_err_cor),
				.cfg_msg_received_err_fatal(cfg_msg_received_err_fatal),
				.cfg_msg_received_err_non_fatal(cfg_msg_received_err_non_fatal),
				.cfg_msg_received_pm_as_nak(cfg_msg_received_pm_as_nak),
				.cfg_msg_received_pme_to(cfg_msg_received_pme_to),
				.cfg_msg_received_pme_to_ack(cfg_msg_received_pme_to_ack),
				.cfg_msg_received_pm_pme(cfg_msg_received_pm_pme),
				.cfg_msg_received_setslotpowerlimit(cfg_msg_received_setslotpowerlimit),
				.cfg_msg_received_unlock(),
				.cfg_pcie_link_state(cfg_pcie_link_state),
				.cfg_pmcsr_pme_en(cfg_pmcsr_pme_en),
				.cfg_pmcsr_powerstate(cfg_pmcsr_powerstate),
				.cfg_pmcsr_pme_status(cfg_pmcsr_pme_status),
				.cfg_pm_rcv_as_req_l1_n(),
				.cfg_pm_rcv_enter_l1_n(),
				.cfg_pm_rcv_enter_l23_n(),
				.cfg_pm_rcv_req_ack_n(),
				.cfg_mgmt_rd_wr_done_n(cfg_mgmt_rd_wr_done_n),
				.cfg_slot_control_electromech_il_ctl_pulse(cfg_slot_control_electromech_il_ctl_pulse),
				.cfg_root_control_syserr_corr_err_en(cfg_root_control_syserr_corr_err_en),
				.cfg_root_control_syserr_non_fatal_err_en(cfg_root_control_syserr_non_fatal_err_en),
				.cfg_root_control_syserr_fatal_err_en(cfg_root_control_syserr_fatal_err_en),
				.cfg_root_control_pme_int_en(cfg_root_control_pme_int_en),
				.cfg_aer_ecrc_check_en(cfg_aer_ecrc_check_en),
				.cfg_aer_ecrc_gen_en(cfg_aer_ecrc_gen_en),
				.cfg_aer_rooterr_corr_err_reporting_en(cfg_aer_rooterr_corr_err_reporting_en),
				.cfg_aer_rooterr_non_fatal_err_reporting_en(cfg_aer_rooterr_non_fatal_err_reporting_en),
				.cfg_aer_rooterr_fatal_err_reporting_en(cfg_aer_rooterr_fatal_err_reporting_en),
				.cfg_aer_rooterr_corr_err_received(cfg_aer_rooterr_corr_err_received),
				.cfg_aer_rooterr_non_fatal_err_received(cfg_aer_rooterr_non_fatal_err_received),
				.cfg_aer_rooterr_fatal_err_received(cfg_aer_rooterr_fatal_err_received),
				.cfg_aer_interrupt_msgnum(cfg_aer_interrupt_msgnum),
				.cfg_transaction(),
				.cfg_transaction_addr(),
				.cfg_transaction_type(),
				.cfg_vc_tcvc_map(cfg_vc_tcvc_map),
				.cfg_mgmt_byte_en_n(~cfg_mgmt_byte_en),
				.cfg_mgmt_di(cfg_mgmt_di),
				.cfg_ds_bus_number(cfg_ds_bus_number),
				.cfg_ds_device_number(cfg_ds_device_number),
				.cfg_ds_function_number(cfg_ds_function_number),
				.cfg_dsn(cfg_dsn),
				.cfg_mgmt_dwaddr(cfg_mgmt_dwaddr),
				.cfg_err_acs_n(1'b1),
				.cfg_err_cor_n(~cfg_err_cor),
				.cfg_err_cpl_abort_n(~cfg_err_cpl_abort),
				.cfg_err_cpl_timeout_n(~cfg_err_cpl_timeout),
				.cfg_err_cpl_unexpect_n(~cfg_err_cpl_unexpect),
				.cfg_err_ecrc_n(~cfg_err_ecrc),
				.cfg_err_locked_n(~cfg_err_locked),
				.cfg_err_posted_n(~cfg_err_posted),
				.cfg_err_tlp_cpl_header(cfg_err_tlp_cpl_header),
				.cfg_err_ur_n(~cfg_err_ur),
				.cfg_err_malformed_n(~cfg_err_malformed),
				.cfg_err_poisoned_n(~cfg_err_poisoned),
				.cfg_err_atomic_egress_blocked_n(~cfg_err_atomic_egress_blocked),
				.cfg_err_mc_blocked_n(~cfg_err_mc_blocked),
				.cfg_err_internal_uncor_n(~cfg_err_internal_uncor),
				.cfg_err_internal_cor_n(~cfg_err_internal_cor),
				.cfg_err_norecovery_n(~cfg_err_norecovery),
				.cfg_interrupt_assert_n(~cfg_interrupt_assert),
				.cfg_interrupt_di(cfg_interrupt_di),
				.cfg_interrupt_n(~cfg_interrupt),
				.cfg_interrupt_stat_n(~cfg_interrupt_stat),
				.cfg_pm_send_pme_to_n(1'b1),
				.cfg_pm_turnoff_ok_n(cfg_turnoff_ok_w),
				.cfg_pm_wake_n(~cfg_pm_wake),
				.cfg_pm_halt_aspm_l0s_n(~cfg_pm_halt_aspm_l0s),
				.cfg_pm_halt_aspm_l1_n(~cfg_pm_halt_aspm_l1),
				.cfg_pm_force_state_en_n(~cfg_pm_force_state_en),
				.cfg_pm_force_state(cfg_pm_force_state),
				.cfg_force_mps(3'b000),
				.cfg_force_common_clock_off(1'b0),
				.cfg_force_extended_sync_on(1'b0),
				.cfg_port_number(8'b00000000),
				.cfg_mgmt_rd_en_n(~cfg_mgmt_rd_en),
				.cfg_trn_pending_n(~cfg_trn_pending),
				.cfg_mgmt_wr_en_n(~cfg_mgmt_wr_en),
				.cfg_mgmt_wr_readonly_n(~cfg_mgmt_wr_readonly),
				.cfg_mgmt_wr_rw1c_as_rw_n(~cfg_mgmt_wr_rw1c_as_rw),
				.pl_initial_link_width(pl_initial_link_width),
				.pl_lane_reversal_mode(pl_lane_reversal_mode),
				.pl_link_gen2_cap(pl_link_gen2_cap),
				.pl_link_partner_gen2_supported(pl_link_partner_gen2_supported),
				.pl_link_upcfg_cap(pl_link_upcfg_cap),
				.pl_ltssm_state(pl_ltssm_state),
				.pl_phy_lnk_up_n(pl_phy_lnk_up_n),
				.pl_received_hot_rst(pl_received_hot_rst),
				.pl_rx_pm_state(pl_rx_pm_state),
				.pl_sel_lnk_rate(pl_sel_lnk_rate),
				.pl_sel_lnk_width(pl_sel_lnk_width),
				.pl_tx_pm_state(pl_tx_pm_state),
				.pl_directed_link_auton(pl_directed_link_auton),
				.pl_directed_link_change(pl_directed_link_change),
				.pl_directed_link_speed(pl_directed_link_speed),
				.pl_directed_link_width(pl_directed_link_width),
				.pl_downstream_deemph_source(pl_downstream_deemph_source),
				.pl_upstream_prefer_deemph(pl_upstream_prefer_deemph),
				.pl_transmit_hot_rst(pl_transmit_hot_rst),
				.pl_directed_ltssm_new_vld(1'b0),
				.pl_directed_ltssm_new(6'b000000),
				.pl_directed_ltssm_stall(1'b0),
				.pl_directed_change_done(pl_directed_change_done),
				.dbg_sclr_a(),
				.dbg_sclr_b(),
				.dbg_sclr_c(),
				.dbg_sclr_d(),
				.dbg_sclr_e(),
				.dbg_sclr_f(),
				.dbg_sclr_g(),
				.dbg_sclr_h(),
				.dbg_sclr_i(),
				.dbg_sclr_j(),
				.dbg_sclr_k(),
				.dbg_vec_a(),
				.dbg_vec_b(),
				.dbg_vec_c(),
				.pl_dbg_vec(),
				.trn_rdllp_data(),
				.trn_rdllp_src_rdy(),
				.dbg_mode(2'b00),
				.dbg_sub_mode(1'b0),
				.pl_dbg_mode(3'b000),
				.drp_clk(pcie_drp_clk),
				.drp_do(pcie_drp_do),
				.drp_rdy(pcie_drp_rdy),
				.drp_addr(pcie_drp_addr),
				.drp_en(pcie_drp_en),
				.drp_di(pcie_drp_di),
				.drp_we(pcie_drp_we),
				.ll2_tlp_rcv(1'b0),
				.ll2_send_enter_l1(1'b0),
				.ll2_send_enter_l23(1'b0),
				.ll2_send_as_req_l1(1'b0),
				.ll2_send_pm_ack(1'b0),
				.ll2_suspend_now(1'b0),
				.ll2_tfc_init1_seq(),
				.ll2_tfc_init2_seq(),
				.ll2_suspend_ok(),
				.ll2_tx_idle(),
				.ll2_link_status(),
				.ll2_receiver_err(),
				.ll2_protocol_err(),
				.ll2_bad_tlp_err(),
				.ll2_bad_dllp_err(),
				.ll2_replay_ro_err(),
				.ll2_replay_to_err(),
				.tl2_ppm_suspend_req(1'b0),
				.tl2_aspm_suspend_credit_check(1'b0),
				.tl2_ppm_suspend_ok(),
				.tl2_aspm_suspend_req(),
				.tl2_aspm_suspend_credit_check_ok(),
				.tl2_err_hdr(),
				.tl2_err_malformed(),
				.tl2_err_rxoverflow(),
				.tl2_err_fcpe(),
				.pl2_directed_lstate(5'b00000),
				.pl2_suspend_ok(),
				.pl2_recovery(),
				.pl2_rx_elec_idle(),
				.pl2_rx_pm_state(),
				.pl2_l0_req(),
				.pl2_link_up(),
				.pl2_receiver_err(),
				.pipe_clk(pipe_clk),
				.user_clk2(user_clk2),
				.user_clk(user_clk),
				.pipe_rx0_polarity(rx_polarity_flat[0]),
				.pipe_rx1_polarity(rx_polarity_flat[1]),
				.pipe_rx2_polarity(rx_polarity_flat[2]),
				.pipe_rx3_polarity(rx_polarity_flat[3]),
				.pipe_rx4_polarity(rx_polarity_flat[4]),
				.pipe_rx5_polarity(rx_polarity_flat[5]),
				.pipe_rx6_polarity(rx_polarity_flat[6]),
				.pipe_rx7_polarity(rx_polarity_flat[7]),
				.pipe_tx0_compliance(tx_compliance_blk[0]),
				.pipe_tx1_compliance(tx_compliance_blk[1]),
				.pipe_tx2_compliance(tx_compliance_blk[2]),
				.pipe_tx3_compliance(tx_compliance_blk[3]),
				.pipe_tx4_compliance(tx_compliance_blk[4]),
				.pipe_tx5_compliance(tx_compliance_blk[5]),
				.pipe_tx6_compliance(tx_compliance_blk[6]),
				.pipe_tx7_compliance(tx_compliance_blk[7]),
				.pipe_tx0_char_is_k(tx_char_is_k_blk[0]),
				.pipe_tx1_char_is_k(tx_char_is_k_blk[1]),
				.pipe_tx2_char_is_k(tx_char_is_k_blk[2]),
				.pipe_tx3_char_is_k(tx_char_is_k_blk[3]),
				.pipe_tx4_char_is_k(tx_char_is_k_blk[4]),
				.pipe_tx5_char_is_k(tx_char_is_k_blk[5]),
				.pipe_tx6_char_is_k(tx_char_is_k_blk[6]),
				.pipe_tx7_char_is_k(tx_char_is_k_blk[7]),
				.pipe_tx0_data(tx_data_blk[0]),
				.pipe_tx1_data(tx_data_blk[1]),
				.pipe_tx2_data(tx_data_blk[2]),
				.pipe_tx3_data(tx_data_blk[3]),
				.pipe_tx4_data(tx_data_blk[4]),
				.pipe_tx5_data(tx_data_blk[5]),
				.pipe_tx6_data(tx_data_blk[6]),
				.pipe_tx7_data(tx_data_blk[7]),
				.pipe_tx0_elec_idle(tx_elec_idle_blk[0]),
				.pipe_tx1_elec_idle(tx_elec_idle_blk[1]),
				.pipe_tx2_elec_idle(tx_elec_idle_blk[2]),
				.pipe_tx3_elec_idle(tx_elec_idle_blk[3]),
				.pipe_tx4_elec_idle(tx_elec_idle_blk[4]),
				.pipe_tx5_elec_idle(tx_elec_idle_blk[5]),
				.pipe_tx6_elec_idle(tx_elec_idle_blk[6]),
				.pipe_tx7_elec_idle(tx_elec_idle_blk[7]),
				.pipe_tx0_powerdown(tx_powerdown_blk[0]),
				.pipe_tx1_powerdown(tx_powerdown_blk[1]),
				.pipe_tx2_powerdown(tx_powerdown_blk[2]),
				.pipe_tx3_powerdown(tx_powerdown_blk[3]),
				.pipe_tx4_powerdown(tx_powerdown_blk[4]),
				.pipe_tx5_powerdown(tx_powerdown_blk[5]),
				.pipe_tx6_powerdown(tx_powerdown_blk[6]),
				.pipe_tx7_powerdown(tx_powerdown_blk[7]),
				.pipe_rx0_char_is_k(rx_blk[24-:2]),
				.pipe_rx1_char_is_k(rx_blk[49-:2]),
				.pipe_rx2_char_is_k(rx_blk[74-:2]),
				.pipe_rx3_char_is_k(rx_blk[99-:2]),
				.pipe_rx4_char_is_k(rx_blk[124-:2]),
				.pipe_rx5_char_is_k(rx_blk[149-:2]),
				.pipe_rx6_char_is_k(rx_blk[174-:2]),
				.pipe_rx7_char_is_k(rx_blk[199-:2]),
				.pipe_rx0_valid(rx_blk[6]),
				.pipe_rx1_valid(rx_blk[31]),
				.pipe_rx2_valid(rx_blk[56]),
				.pipe_rx3_valid(rx_blk[81]),
				.pipe_rx4_valid(rx_blk[106]),
				.pipe_rx5_valid(rx_blk[131]),
				.pipe_rx6_valid(rx_blk[156]),
				.pipe_rx7_valid(rx_blk[181]),
				.pipe_rx0_data(rx_blk[22-:16]),
				.pipe_rx1_data(rx_blk[47-:16]),
				.pipe_rx2_data(rx_blk[72-:16]),
				.pipe_rx3_data(rx_blk[97-:16]),
				.pipe_rx4_data(rx_blk[122-:16]),
				.pipe_rx5_data(rx_blk[147-:16]),
				.pipe_rx6_data(rx_blk[172-:16]),
				.pipe_rx7_data(rx_blk[197-:16]),
				.pipe_rx0_chanisaligned(rx_blk[5]),
				.pipe_rx1_chanisaligned(rx_blk[30]),
				.pipe_rx2_chanisaligned(rx_blk[55]),
				.pipe_rx3_chanisaligned(rx_blk[80]),
				.pipe_rx4_chanisaligned(rx_blk[105]),
				.pipe_rx5_chanisaligned(rx_blk[130]),
				.pipe_rx6_chanisaligned(rx_blk[155]),
				.pipe_rx7_chanisaligned(rx_blk[180]),
				.pipe_rx0_status(rx_blk[4-:3]),
				.pipe_rx1_status(rx_blk[29-:3]),
				.pipe_rx2_status(rx_blk[54-:3]),
				.pipe_rx3_status(rx_blk[79-:3]),
				.pipe_rx4_status(rx_blk[104-:3]),
				.pipe_rx5_status(rx_blk[129-:3]),
				.pipe_rx6_status(rx_blk[154-:3]),
				.pipe_rx7_status(rx_blk[179-:3]),
				.pipe_rx0_phy_status(rx_blk[1]),
				.pipe_rx1_phy_status(rx_blk[26]),
				.pipe_rx2_phy_status(rx_blk[51]),
				.pipe_rx3_phy_status(rx_blk[76]),
				.pipe_rx4_phy_status(rx_blk[101]),
				.pipe_rx5_phy_status(rx_blk[126]),
				.pipe_rx6_phy_status(rx_blk[151]),
				.pipe_rx7_phy_status(rx_blk[176]),
				.pipe_tx_deemph(tx_deemph_blk),
				.pipe_tx_margin(tx_margin_blk),
				.pipe_tx_reset(tx_reset_blk),
				.pipe_tx_rcvr_det(tx_rcvr_det_blk),
				.pipe_tx_rate(tx_rate_blk),
				.pipe_rx0_elec_idle(rx_blk[0]),
				.pipe_rx1_elec_idle(rx_blk[25]),
				.pipe_rx2_elec_idle(rx_blk[50]),
				.pipe_rx3_elec_idle(rx_blk[75]),
				.pipe_rx4_elec_idle(rx_blk[100]),
				.pipe_rx5_elec_idle(rx_blk[125]),
				.pipe_rx6_elec_idle(rx_blk[150]),
				.pipe_rx7_elec_idle(rx_blk[175])
			);
		end
	endgenerate
	assign user_clk_out = txn_engine_i.user_clk_out;
	assign txn_engine_i.user_reset = user_reset_out;
	assign txn_engine_i.user_lnk_up = user_lnk_up;
	assign trn_lnk_up = txn_engine_i.trn_lnk_up;
	assign user_rst_n = txn_engine_i.user_rst_n;
	assign tx_buf_av = txn_engine_i.tx_buf_av;
	assign txn_engine_i.tx_cfg_gnt = 1'b0;
	assign txn_engine_i.rx_np_ok = 1'b1;
	assign txn_engine_i.rx_np_req = 1'b1;
	assign txn_engine_i.fc_sel = 3'b000;
	assign cfg_regs = txn_engine_i.cfg_regs;
	assign txn_engine_i.cfg_mgmt_di = 32'd0;
	assign txn_engine_i.cfg_mgmt_byte_en = 4'h0;
	assign txn_engine_i.cfg_mgmt_dwaddr = 10'd0;
	assign txn_engine_i.cfg_mgmt_wr_en = 1'b0;
	assign txn_engine_i.cfg_mgmt_rd_en = 1'b0;
	assign txn_engine_i.cfg_mgmt_wr_readonly = 1'b0;
	assign txn_engine_i.cfg_mgmt_wr_rw1c_as_rw = 1'b0;
	assign txn_engine_i.cfg_err_ecrc = 1'b0;
	assign txn_engine_i.cfg_err_ur = 1'b0;
	assign txn_engine_i.cfg_err_cpl_timeout = 1'b0;
	assign txn_engine_i.cfg_err_cpl_unexpect = 1'b0;
	assign txn_engine_i.cfg_err_cpl_abort = 1'b0;
	assign txn_engine_i.cfg_err_posted = 1'b0;
	assign txn_engine_i.cfg_err_cor = 1'b0;
	assign txn_engine_i.cfg_err_atomic_egress_blocked = 1'b0;
	assign txn_engine_i.cfg_err_internal_cor = 1'b0;
	assign txn_engine_i.cfg_err_malformed = 1'b0;
	assign txn_engine_i.cfg_err_mc_blocked = 1'b0;
	assign txn_engine_i.cfg_err_poisoned = 1'b0;
	assign txn_engine_i.cfg_err_norecovery = 1'b0;
	assign txn_engine_i.cfg_err_locked = 1'b0;
	assign txn_engine_i.cfg_err_internal_uncor = 1'b0;
	assign txn_engine_i.cfg_err_tlp_cpl_header = 48'd0;
	assign txn_engine_i.cfg_err_aer_headerlog = 128'd0;
	assign txn_engine_i.cfg_aer_interrupt_msgnum = 5'd0;
	assign txn_engine_i.cfg_interrupt = 1'b0;
	assign txn_engine_i.cfg_interrupt_assert = 1'b0;
	assign txn_engine_i.cfg_interrupt_di = 8'd0;
	assign txn_engine_i.cfg_interrupt_stat = 1'b0;
	assign txn_engine_i.cfg_pciecap_interrupt_msgnum = 5'd0;
	assign txn_engine_i.cfg_trn_pending = 1'b0;
	assign txn_engine_i.cfg_pm_halt_aspm_l0s = 1'b0;
	assign txn_engine_i.cfg_pm_halt_aspm_l1 = 1'b0;
	assign txn_engine_i.cfg_pm_force_state_en = 1'b0;
	assign txn_engine_i.cfg_pm_force_state = 2'b00;
	assign txn_engine_i.cfg_pm_wake = 1'b0;
	assign txn_engine_i.cfg_dsn = 64'd0;
	assign txn_engine_i.cfg_ds_bus_number = 8'd0;
	assign txn_engine_i.cfg_ds_device_number = 5'd0;
	assign txn_engine_i.cfg_ds_function_number = 3'b000;
	assign txn_engine_i.cfg_turnoff_ok = 1'b0;
	assign txn_engine_i.cfg_dev_id = CFG_DEV_ID;
	assign txn_engine_i.cfg_vend_id = CFG_VEND_ID;
	assign txn_engine_i.cfg_rev_id = CFG_REV_ID;
	assign txn_engine_i.cfg_subsys_id = CFG_SUBSYS_ID;
	assign txn_engine_i.cfg_subsys_vend_id = CFG_SUBSYS_VEND_ID;
	assign cfg_msg_received_err_fatal = txn_engine_i.cfg_msg_received_err_fatal;
	assign txn_engine_i.pl_directed_link_change = 2'd0;
	assign txn_engine_i.pl_directed_link_width = 2'b00;
	assign txn_engine_i.pl_directed_link_speed = 1'b0;
	assign txn_engine_i.pl_directed_link_auton = 1'b0;
	assign txn_engine_i.pl_upstream_prefer_deemph = 1'b0;
	assign txn_engine_i.pl_downstream_deemph_source = 1'b0;
	assign txn_engine_i.pl_transmit_hot_rst = 1'b0;
	assign pl_ltssm_state_int = txn_engine_i.pl_ltssm_state;
	assign pl_phy_lnk_up_wire = txn_engine_i.pl_phy_lnk_up;
	assign pl_received_hot_rst_wire = txn_engine_i.pl_received_hot_rst;
	assign txn_engine_i.pcie_drp_clk = 1'b1;
	assign txn_engine_i.pcie_drp_en = 1'b0;
	assign txn_engine_i.pcie_drp_we = 1'b0;
	assign txn_engine_i.pcie_drp_addr = 9'd0;
	assign txn_engine_i.pcie_drp_di = 16'd0;
	assign txn_engine_i.phy_rdy_n = phy_rdy_n;
	assign txn_engine_i.pipe_clk = pipe_clk;
	assign txn_engine_i.user_clk = user_clk;
	assign txn_engine_i.user_clk2 = user_clk2;
	(* KEEP = "TRUE", ASYNC_REG = "TRUE" *) reg user_lnk_up_int;
	reg user_reset_int;
	reg pl_received_hot_rst_q;
	reg pl_phy_lnk_up_q;
	wire pl_received_hot_rst_sync;
	wire pl_phy_lnk_up_sync;
	wire sys_or_hot_rst;
	assign user_lnk_up = user_lnk_up_int;
	assign sys_or_hot_rst = !sys_rst_n || pl_received_hot_rst_q;
	xpm_cdc_single #(
		.DEST_SYNC_FF(2),
		.SRC_INPUT_REG(0)
	) phy_lnk_up_cdc(
		.src_clk(pipe_clk),
		.src_in(pl_phy_lnk_up_wire),
		.dest_clk(user_clk_out),
		.dest_out(pl_phy_lnk_up_sync)
	);
	xpm_cdc_single #(
		.DEST_SYNC_FF(2),
		.SRC_INPUT_REG(0)
	) pl_received_hot_rst_cdc(
		.src_clk(pipe_clk),
		.src_in(pl_received_hot_rst_wire),
		.dest_clk(user_clk_out),
		.dest_out(pl_received_hot_rst_sync)
	);
	always @(posedge user_clk_out)
		if (!sys_rst_n) begin
			pl_received_hot_rst_q <= 1'b0;
			pl_phy_lnk_up_q <= 1'b0;
		end
		else begin
			pl_received_hot_rst_q <= pl_received_hot_rst_sync;
			pl_phy_lnk_up_q <= pl_phy_lnk_up_sync;
		end
	always @(posedge user_clk_out)
		if (!sys_rst_n)
			user_lnk_up_int <= 1'b0;
		else
			user_lnk_up_int <= trn_lnk_up;
	always @(posedge user_clk_out or posedge sys_or_hot_rst)
		if (sys_or_hot_rst)
			user_reset_int <= 1'b1;
		else if (user_rst_n && pl_phy_lnk_up_q)
			user_reset_int <= 1'b0;
	always @(posedge user_clk_out or posedge sys_or_hot_rst)
		if (sys_or_hot_rst)
			user_reset_out <= 1'b1;
		else
			user_reset_out <= user_reset_int;
endmodule
