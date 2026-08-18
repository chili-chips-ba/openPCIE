module buffer_tile (
	user_clk_i,
	reset_i,
	wen_i,
	waddr_i,
	wdata_i,
	ren_i,
	rce_i,
	raddr_i,
	rdata_o
);
	parameter IMPL_TARGET = "HARD";
	parameter DOB_REG = 0;
	parameter WIDTH = 0;
	parameter [3:0] LINK_CAP_MAX_LINK_SPEED = 4'h1;
	parameter [5:0] LINK_CAP_MAX_LINK_WIDTH = 6'h08;
	input user_clk_i;
	input reset_i;
	input wen_i;
	input [12:0] waddr_i;
	input [WIDTH - 1:0] wdata_i;
	input ren_i;
	input rce_i;
	input [12:0] raddr_i;
	output wire [WIDTH - 1:0] rdata_o;
	localparam ADDR_MSB = (WIDTH == 4 ? 12 : (WIDTH == 9 ? 11 : (WIDTH == 18 ? 10 : (WIDTH == 36 ? 9 : 8))));
	localparam WE_WIDTH = (WIDTH <= 9 ? 1 : (WIDTH <= 18 ? 2 : (WIDTH <= 36 ? 4 : 8)));
	localparam WRITE_MODE = ((LINK_CAP_MAX_LINK_SPEED == 4'h2) && (LINK_CAP_MAX_LINK_WIDTH == 6'h08) ? "WRITE_FIRST" : "NO_CHANGE");
	localparam DEVICE = (IMPL_TARGET == "HARD" ? "7SERIES" : "VIRTEX6");
	generate
		if (WIDTH <= 36) begin : use_tdp
			BRAM_TDP_MACRO #(
				.DEVICE(DEVICE),
				.BRAM_SIZE("36Kb"),
				.DOA_REG(0),
				.DOB_REG(DOB_REG),
				.READ_WIDTH_A(WIDTH),
				.READ_WIDTH_B(WIDTH),
				.WRITE_WIDTH_A(WIDTH),
				.WRITE_WIDTH_B(WIDTH),
				.WRITE_MODE_A(WRITE_MODE)
			) ramb36(
				.DOA(),
				.DOB(rdata_o[WIDTH - 1:0]),
				.ADDRA(waddr_i[ADDR_MSB:0]),
				.ADDRB(raddr_i[ADDR_MSB:0]),
				.CLKA(user_clk_i),
				.CLKB(user_clk_i),
				.DIA(wdata_i[WIDTH - 1:0]),
				.DIB({WIDTH {1'b0}}),
				.ENA(wen_i),
				.ENB(ren_i),
				.REGCEA(1'b0),
				.REGCEB(rce_i),
				.RSTA(reset_i),
				.RSTB(reset_i),
				.WEA({WE_WIDTH {1'b1}}),
				.WEB({WE_WIDTH {1'b0}})
			);
		end
	endgenerate
endmodule
