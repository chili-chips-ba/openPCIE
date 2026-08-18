module RC_direct_opensource (
	sys_clk_p,
	sys_clk_n,
	RXN,
	RXP,
	TXN,
	TXP,
	sys_rst_n,
	led_link_up,
	clk_req
);
	input wire sys_clk_p;
	input wire sys_clk_n;
	localparam signed [31:0] link_pkg_PCIE_LANES = 1;
	input wire [0:0] RXN;
	input wire [0:0] RXP;
	output wire [0:0] TXN;
	output wire [0:0] TXP;
	input wire sys_rst_n;
	output wire [3:0] led_link_up;
	output wire clk_req;
	localparam signed [31:0] C_DATA_WIDTH = 64;
	localparam signed [31:0] KEEP_WIDTH = 8;
	wire user_clk;
	wire user_reset;
	wire user_lnk_up;
	wire sys_clk;
	wire rp_reset_n;
	IBUFDS_GTE2 refclk_ibuf(
		.O(sys_clk),
		.ODIV2(),
		.I(sys_clk_p),
		.CEB(1'b0),
		.IB(sys_clk_n)
	);
	assign rp_reset_n = sys_rst_n;
	wire s_axis_tx_tready;
	wire [63:0] s_axis_tx_tdata;
	wire [7:0] s_axis_tx_tkeep;
	wire s_axis_tx_tlast;
	wire s_axis_tx_tvalid;
	wire [3:0] s_axis_tx_tuser;
	assign s_axis_tx_tuser = 4'b0000;
	wire [63:0] m_axis_rx_tdata;
	wire [7:0] m_axis_rx_tkeep;
	wire m_axis_rx_tlast;
	wire m_axis_rx_tvalid;
	wire [21:0] m_axis_rx_tuser;
	wire m_axis_rx_tready;
	wire [15:0] cfg_status_wire;
	wire cfg_msg_err_fatal_wire;
	wire [5:0] rport_tx_buf_av;
	host_bridge pcie_inst(
		.pci_exp_txp(TXP),
		.pci_exp_txn(TXN),
		.pci_exp_rxp(RXP),
		.pci_exp_rxn(RXN),
		.sys_clk(sys_clk),
		.sys_rst_n(rp_reset_n),
		.pipe_mmcm_rst_n(1'b1),
		.user_clk_out(user_clk),
		.user_reset_out(user_reset),
		.user_lnk_up(user_lnk_up),
		.s_axis_tx_tready(s_axis_tx_tready),
		.s_axis_tx_tdata(s_axis_tx_tdata),
		.s_axis_tx_tkeep(s_axis_tx_tkeep),
		.s_axis_tx_tuser(s_axis_tx_tuser),
		.s_axis_tx_tlast(s_axis_tx_tlast),
		.s_axis_tx_tvalid(s_axis_tx_tvalid),
		.m_axis_rx_tdata(m_axis_rx_tdata),
		.m_axis_rx_tkeep(m_axis_rx_tkeep),
		.m_axis_rx_tlast(m_axis_rx_tlast),
		.m_axis_rx_tvalid(m_axis_rx_tvalid),
		.m_axis_rx_tready(m_axis_rx_tready),
		.m_axis_rx_tuser(m_axis_rx_tuser),
		.tx_buf_av(rport_tx_buf_av),
		.cfg_status(cfg_status_wire),
		.cfg_msg_received_err_fatal(cfg_msg_err_fatal_wire)
	);
	riscv_pcie_soc soc_inst(
		.clk(user_clk),
		.resetn(~user_reset && user_lnk_up),
		.s_axis_tx_tdata(s_axis_tx_tdata),
		.s_axis_tx_tkeep(s_axis_tx_tkeep),
		.s_axis_tx_tlast(s_axis_tx_tlast),
		.s_axis_tx_tvalid(s_axis_tx_tvalid),
		.s_axis_tx_tready(s_axis_tx_tready),
		.m_axis_rx_tdata(m_axis_rx_tdata),
		.m_axis_rx_tkeep(m_axis_rx_tkeep),
		.m_axis_rx_tlast(m_axis_rx_tlast),
		.m_axis_rx_tvalid(m_axis_rx_tvalid),
		.m_axis_rx_tready(m_axis_rx_tready),
		.cfg_status(cfg_status_wire),
		.cfg_msg_received_err_fatal(cfg_msg_err_fatal_wire),
		.tx_buf_av(rport_tx_buf_av)
	);
	assign led_link_up = {1'b1, ~user_lnk_up, 2'b11};
	assign clk_req = 1'b0;
endmodule
