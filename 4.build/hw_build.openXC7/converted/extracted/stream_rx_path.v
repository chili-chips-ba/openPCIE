module stream_rx_path (
	m_axis_rx_tdata,
	m_axis_rx_tvalid,
	m_axis_rx_tready,
	m_axis_rx_tkeep,
	m_axis_rx_tlast,
	m_axis_rx_tuser,
	trn_rd,
	trn_rsof,
	trn_reof,
	trn_rsrc_rdy,
	trn_rdst_rdy,
	trn_rsrc_dsc,
	trn_rrem,
	trn_rerrfwd,
	trn_rbar_hit,
	trn_recrc_err,
	null_rx_tvalid,
	null_rx_tlast,
	null_rx_tkeep,
	null_rdst_rdy,
	null_is_eof,
	np_counter,
	user_clk,
	user_rst
);
	localparam signed [31:0] C_DATA_WIDTH = 64;
	localparam signed [31:0] KEEP_WIDTH = 8;
	localparam signed [31:0] REM_WIDTH = 1;
	output reg [63:0] m_axis_rx_tdata;
	output reg m_axis_rx_tvalid;
	input m_axis_rx_tready;
	output wire [7:0] m_axis_rx_tkeep;
	output wire m_axis_rx_tlast;
	output reg [21:0] m_axis_rx_tuser;
	input [63:0] trn_rd;
	input trn_rsof;
	input trn_reof;
	input trn_rsrc_rdy;
	output reg trn_rdst_rdy;
	input trn_rsrc_dsc;
	input [0:0] trn_rrem;
	input trn_rerrfwd;
	input [6:0] trn_rbar_hit;
	input trn_recrc_err;
	input null_rx_tvalid;
	input null_rx_tlast;
	input [7:0] null_rx_tkeep;
	input null_rdst_rdy;
	input [4:0] null_is_eof;
	output wire [2:0] np_counter;
	input user_clk;
	input user_rst;
	wire [4:0] is_sof;
	wire [4:0] is_sof_prev;
	wire [4:0] is_eof;
	wire [4:0] is_eof_prev;
	reg [7:0] reg_tkeep;
	wire [7:0] tkeep;
	wire [7:0] tkeep_prev;
	reg reg_tlast;
	wire rsrc_rdy_filtered;
	wire [63:0] trn_rd_DW_swapped;
	reg [63:0] trn_rd_prev;
	wire data_hold;
	reg data_prev;
	reg trn_reof_prev;
	reg [0:0] trn_rrem_prev;
	reg trn_rsrc_rdy_prev;
	reg trn_rsrc_dsc_prev;
	reg trn_rsof_prev;
	reg [6:0] trn_rbar_hit_prev;
	reg trn_rerrfwd_prev;
	reg trn_recrc_err_prev;
	reg null_mux_sel;
	reg trn_in_packet;
	wire dsc_flag;
	wire dsc_detect;
	reg reg_dsc_detect;
	reg trn_rsrc_dsc_d;
	assign rsrc_rdy_filtered = trn_rsrc_rdy && (trn_in_packet || (trn_rsof && !trn_rsrc_dsc));
	always @(posedge user_clk)
		if (user_rst) begin
			trn_rd_prev <= {C_DATA_WIDTH {1'b0}};
			trn_rsof_prev <= 1'b0;
			trn_rrem_prev <= {REM_WIDTH {1'b0}};
			trn_rsrc_rdy_prev <= 1'b0;
			trn_rbar_hit_prev <= 7'h00;
			trn_rerrfwd_prev <= 1'b0;
			trn_recrc_err_prev <= 1'b0;
			trn_reof_prev <= 1'b0;
			trn_rsrc_dsc_prev <= 1'b0;
		end
		else if (trn_rdst_rdy) begin
			trn_rd_prev <= trn_rd_DW_swapped;
			trn_rsof_prev <= trn_rsof;
			trn_rrem_prev <= trn_rrem;
			trn_rbar_hit_prev <= trn_rbar_hit;
			trn_rerrfwd_prev <= trn_rerrfwd;
			trn_recrc_err_prev <= trn_recrc_err;
			trn_rsrc_rdy_prev <= rsrc_rdy_filtered;
			trn_reof_prev <= trn_reof;
			trn_rsrc_dsc_prev <= trn_rsrc_dsc || dsc_flag;
		end
	assign trn_rd_DW_swapped = {trn_rd[31:0], trn_rd[63:32]};
	always @(posedge user_clk)
		if (user_rst)
			m_axis_rx_tdata <= {C_DATA_WIDTH {1'b0}};
		else if (!data_hold) begin
			if (data_prev)
				m_axis_rx_tdata <= trn_rd_prev;
			else
				m_axis_rx_tdata <= trn_rd_DW_swapped;
		end
	assign data_hold = !m_axis_rx_tready && m_axis_rx_tvalid;
	always @(posedge user_clk)
		if (user_rst)
			data_prev <= 1'b0;
		else
			data_prev <= data_hold;
	always @(posedge user_clk)
		if (user_rst) begin
			m_axis_rx_tvalid <= 1'b0;
			reg_tlast <= 1'b0;
			reg_tkeep <= {KEEP_WIDTH {1'b1}};
			m_axis_rx_tuser <= 22'h000000;
		end
		else if (!data_hold) begin
			if (null_mux_sel) begin
				m_axis_rx_tvalid <= null_rx_tvalid;
				reg_tlast <= null_rx_tlast;
				reg_tkeep <= null_rx_tkeep;
				m_axis_rx_tuser <= {null_is_eof, 17'h00000};
			end
			else if (data_prev) begin
				m_axis_rx_tvalid <= trn_rsrc_rdy_prev || dsc_flag;
				reg_tlast <= trn_reof_prev;
				reg_tkeep <= tkeep_prev;
				m_axis_rx_tuser <= {is_eof_prev, 2'b00, is_sof_prev, 1'b0, trn_rbar_hit_prev, trn_rerrfwd_prev, trn_recrc_err_prev};
			end
			else begin
				m_axis_rx_tvalid <= rsrc_rdy_filtered || dsc_flag;
				reg_tlast <= trn_reof;
				reg_tkeep <= tkeep;
				m_axis_rx_tuser <= {is_eof, 2'b00, is_sof, 1'b0, trn_rbar_hit, trn_rerrfwd, trn_recrc_err};
			end
		end
	assign m_axis_rx_tlast = reg_tlast;
	assign m_axis_rx_tkeep = reg_tkeep;
	assign tkeep = (trn_rrem ? 8'hff : 8'h0f);
	assign tkeep_prev = (trn_rrem_prev ? 8'hff : 8'h0f);
	assign is_sof = {trn_rsof && !trn_rsrc_dsc, 4'b0000};
	assign is_sof_prev = {trn_rsof_prev && !trn_rsrc_dsc_prev, 4'b0000};
	assign is_eof = {trn_reof, 1'b0, trn_rrem, 2'b11};
	assign is_eof_prev = {trn_reof_prev, 1'b0, trn_rrem_prev, 2'b11};
	always @(posedge user_clk)
		if (user_rst)
			trn_rdst_rdy <= 1'b0;
		else if (null_mux_sel && m_axis_rx_tready)
			trn_rdst_rdy <= null_rdst_rdy;
		else if (dsc_flag)
			trn_rdst_rdy <= 1'b0;
		else if (m_axis_rx_tvalid)
			trn_rdst_rdy <= m_axis_rx_tready;
		else
			trn_rdst_rdy <= 1'b1;
	always @(posedge user_clk)
		if (user_rst)
			null_mux_sel <= 1'b0;
		else if ((null_mux_sel && null_rx_tlast) && m_axis_rx_tready)
			null_mux_sel <= 1'b0;
		else if (dsc_flag && !data_hold)
			null_mux_sel <= 1'b1;
	always @(posedge user_clk)
		if (user_rst)
			trn_in_packet <= 1'b0;
		else if (((trn_rsof && !trn_reof) && rsrc_rdy_filtered) && trn_rdst_rdy)
			trn_in_packet <= 1'b1;
		else if (trn_rsrc_dsc)
			trn_in_packet <= 1'b0;
		else if (((trn_reof && !trn_rsof) && trn_rsrc_rdy) && trn_rdst_rdy)
			trn_in_packet <= 1'b0;
	assign dsc_detect = (((trn_rsrc_dsc && !trn_rsrc_dsc_d) && trn_in_packet) && (!trn_rsof || trn_reof)) && !(trn_rdst_rdy && trn_reof);
	always @(posedge user_clk)
		if (user_rst) begin
			reg_dsc_detect <= 1'b0;
			trn_rsrc_dsc_d <= 1'b0;
		end
		else begin
			if (dsc_detect)
				reg_dsc_detect <= 1'b1;
			else if (null_mux_sel)
				reg_dsc_detect <= 1'b0;
			trn_rsrc_dsc_d <= trn_rsrc_dsc;
		end
	assign dsc_flag = dsc_detect || reg_dsc_detect;
	assign np_counter = 3'h0;
endmodule
