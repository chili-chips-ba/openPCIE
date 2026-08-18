module buffer_bank (
	user_clk_i,
	reset_i,
	wen,
	waddr,
	wdata,
	ren,
	rce,
	raddr,
	rdata
);
	parameter [3:0] LINK_CAP_MAX_LINK_SPEED = 4'h1;
	parameter [5:0] LINK_CAP_MAX_LINK_WIDTH = 6'h08;
	parameter IMPL_TARGET = "HARD";
	parameter NUM_BRAMS = 0;
	parameter RAM_RADDR_LATENCY = 1;
	parameter RAM_RDATA_LATENCY = 1;
	parameter RAM_WRITE_LATENCY = 1;
	input user_clk_i;
	input reset_i;
	input wen;
	input [12:0] waddr;
	input [71:0] wdata;
	input ren;
	input rce;
	input [12:0] raddr;
	output wire [71:0] rdata;
	localparam DOB_REG = (RAM_RDATA_LATENCY > 1 ? 1 : 0);
	localparam [6:0] WIDTH = (NUM_BRAMS == 1 ? 72 : (NUM_BRAMS == 2 ? 36 : (NUM_BRAMS == 4 ? 18 : (NUM_BRAMS == 8 ? 9 : 4))));
	wire wen_int;
	wire [12:0] waddr_int;
	wire [71:0] wdata_int;
	wire ren_int;
	wire [12:0] raddr_int;
	wire [71:0] rdata_int;
	generate
		if (RAM_WRITE_LATENCY == 1) begin : wr_lat_2
			reg wen_q;
			reg [12:0] waddr_q;
			reg [71:0] wdata_q;
			always @(posedge user_clk_i) begin
				if (reset_i) begin
					wen_q <= 1'b0;
					waddr_q <= 13'b0000000000000;
				end
				else begin
					wen_q <= wen;
					waddr_q <= waddr;
				end
				wdata_q <= wdata;
			end
			assign wen_int = wen_q;
			assign waddr_int = waddr_q;
			assign wdata_int = wdata_q;
		end
		else begin : wr_lat_1
			assign wen_int = wen;
			assign waddr_int = waddr;
			assign wdata_int = wdata;
		end
		if (RAM_RADDR_LATENCY == 1) begin : raddr_lat_2
			reg ren_q;
			reg [12:0] raddr_q;
			always @(posedge user_clk_i)
				if (reset_i) begin
					ren_q <= 1'b0;
					raddr_q <= 13'b0000000000000;
				end
				else begin
					ren_q <= ren;
					raddr_q <= raddr;
				end
			assign ren_int = ren_q;
			assign raddr_int = raddr_q;
		end
		else begin : raddr_lat_1
			assign ren_int = ren;
			assign raddr_int = raddr;
		end
		if (RAM_RDATA_LATENCY == 3) begin : rdata_lat_3
			reg [71:0] rdata_q;
			always @(posedge user_clk_i) rdata_q <= rdata_int;
			assign rdata = rdata_q;
		end
		else begin : rdata_lat_1_2
			assign rdata = rdata_int;
		end
	endgenerate
	genvar _gv_ii_1;
	generate
		for (_gv_ii_1 = 0; _gv_ii_1 < NUM_BRAMS; _gv_ii_1 = _gv_ii_1 + 1) begin : tiles
			localparam ii = _gv_ii_1;
			buffer_tile #(
				.LINK_CAP_MAX_LINK_WIDTH(LINK_CAP_MAX_LINK_WIDTH),
				.LINK_CAP_MAX_LINK_SPEED(LINK_CAP_MAX_LINK_SPEED),
				.IMPL_TARGET(IMPL_TARGET),
				.DOB_REG(DOB_REG),
				.WIDTH(WIDTH)
			) tile(
				.user_clk_i(user_clk_i),
				.reset_i(reset_i),
				.wen_i(wen_int),
				.waddr_i(waddr_int),
				.wdata_i(wdata_int[ii * WIDTH+:WIDTH]),
				.ren_i(ren_int),
				.raddr_i(raddr_int),
				.rdata_o(rdata_int[ii * WIDTH+:WIDTH]),
				.rce_i(rce)
			);
		end
	endgenerate
endmodule
