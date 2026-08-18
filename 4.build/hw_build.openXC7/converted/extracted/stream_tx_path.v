module stream_tx_path (
	s_axis_tx_tdata,
	s_axis_tx_tvalid,
	s_axis_tx_tready,
	s_axis_tx_tkeep,
	s_axis_tx_tlast,
	s_axis_tx_tuser,
	trn_td,
	trn_tsof,
	trn_teof,
	trn_tsrc_rdy,
	trn_tdst_rdy,
	trn_tsrc_dsc,
	trn_trem,
	trn_terrfwd,
	trn_tstr,
	trn_tecrc_gen,
	trn_lnk_up,
	tready_thrtl,
	user_clk,
	user_rst
);
	localparam signed [31:0] C_DATA_WIDTH = 64;
	localparam signed [31:0] KEEP_WIDTH = 8;
	localparam signed [31:0] REM_WIDTH = 1;
	input [63:0] s_axis_tx_tdata;
	input s_axis_tx_tvalid;
	output wire s_axis_tx_tready;
	input [7:0] s_axis_tx_tkeep;
	input s_axis_tx_tlast;
	input [3:0] s_axis_tx_tuser;
	output wire [63:0] trn_td;
	output wire trn_tsof;
	output wire trn_teof;
	output wire trn_tsrc_rdy;
	input trn_tdst_rdy;
	output wire trn_tsrc_dsc;
	output wire [0:0] trn_trem;
	output wire trn_terrfwd;
	output wire trn_tstr;
	output wire trn_tecrc_gen;
	input trn_lnk_up;
	input tready_thrtl;
	input user_clk;
	input user_rst;
	reg [63:0] reg_tdata;
	reg reg_tvalid;
	reg [7:0] reg_tkeep;
	reg [3:0] reg_tuser;
	reg reg_tlast;
	reg trn_in_packet;
	reg axi_in_packet;
	wire disable_trn;
	reg reg_disable_trn;
	reg reg_tsrc_rdy;
	wire axi_beat_live = s_axis_tx_tvalid && s_axis_tx_tready;
	wire axi_end_packet = axi_beat_live && s_axis_tx_tlast;
	assign trn_td = {reg_tdata[31:0], reg_tdata[63:32]};
	assign trn_tsof = reg_tvalid && !trn_in_packet;
	always @(posedge user_clk)
		if (user_rst)
			trn_in_packet <= 1'b0;
		else if (((trn_tsof && trn_tsrc_rdy) && trn_tdst_rdy) && !trn_teof)
			trn_in_packet <= 1'b1;
		else if (((trn_in_packet && trn_teof) && trn_tsrc_rdy) || !trn_lnk_up)
			trn_in_packet <= 1'b0;
	always @(posedge user_clk)
		if (user_rst)
			axi_in_packet <= 1'b0;
		else if (axi_beat_live && !s_axis_tx_tlast)
			axi_in_packet <= 1'b1;
		else if (axi_beat_live)
			axi_in_packet <= 1'b0;
	always @(posedge user_clk)
		if (user_rst)
			reg_disable_trn <= 1'b0;
		else if ((axi_in_packet && !trn_lnk_up) && !axi_end_packet)
			reg_disable_trn <= 1'b1;
		else if (axi_end_packet)
			reg_disable_trn <= 1'b0;
	assign disable_trn = reg_disable_trn || !trn_lnk_up;
	assign trn_trem = reg_tkeep[7];
	assign trn_teof = reg_tlast;
	assign trn_tecrc_gen = reg_tuser[0];
	assign trn_terrfwd = reg_tuser[1];
	assign trn_tstr = reg_tuser[2];
	assign trn_tsrc_dsc = reg_tuser[3];
	always @(posedge user_clk)
		if (user_rst) begin
			reg_tdata <= {C_DATA_WIDTH {1'b0}};
			reg_tvalid <= 1'b0;
			reg_tkeep <= {KEEP_WIDTH {1'b0}};
			reg_tlast <= 1'b0;
			reg_tuser <= 4'h0;
			reg_tsrc_rdy <= 1'b0;
		end
		else begin
			reg_tdata <= s_axis_tx_tdata;
			reg_tvalid <= s_axis_tx_tvalid;
			reg_tkeep <= s_axis_tx_tkeep;
			reg_tlast <= s_axis_tx_tlast;
			reg_tuser <= s_axis_tx_tuser;
			reg_tsrc_rdy <= axi_beat_live && !disable_trn;
		end
	assign trn_tsrc_rdy = reg_tsrc_rdy;
	assign s_axis_tx_tready = tready_thrtl;
endmodule
