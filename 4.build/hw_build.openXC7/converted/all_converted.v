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
module chan_retune (
	DRP_CLK,
	DRP_RST_N,
	DRP_X16,
	DRP_START,
	DRP_DO,
	DRP_RDY,
	DRP_ADDR,
	DRP_EN,
	DRP_DI,
	DRP_WE,
	DRP_DONE,
	DRP_FSM
);
	reg _sv2v_0;
	localparam LOAD_CNT_MAX = 2'd1;
	localparam INDEX_MAX = 1'd0;
	input DRP_CLK;
	input DRP_RST_N;
	input DRP_X16;
	input DRP_START;
	input [15:0] DRP_DO;
	input DRP_RDY;
	output wire [8:0] DRP_ADDR;
	output wire DRP_EN;
	output wire [15:0] DRP_DI;
	output wire DRP_WE;
	output wire DRP_DONE;
	output wire [2:0] DRP_FSM;
	localparam [8:0] ADDR_RX_DW = 9'h011;
	localparam [15:0] MASK_RX_DW = 16'b1111011111111111;
	localparam [15:0] X16_RX_DW = 16'b0000000000000000;
	localparam [15:0] X20_RX_DW = 16'b0000100000000000;
	reg [2:0] state = 3'd0;
	reg [2:0] state_nx;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg x16_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg x16_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg start_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg start_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [15:0] do_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [15:0] do_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg rdy_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg rdy_r2;
	always @(posedge DRP_CLK)
		if (!DRP_RST_N) begin
			x16_r1 <= 1'b0;
			start_r1 <= 1'b0;
			do_r1 <= 16'd0;
			rdy_r1 <= 1'b0;
			x16_r2 <= 1'b0;
			start_r2 <= 1'b0;
			do_r2 <= 16'd0;
			rdy_r2 <= 1'b0;
		end
		else begin
			x16_r1 <= DRP_X16;
			x16_r2 <= x16_r1;
			start_r1 <= DRP_START;
			start_r2 <= start_r1;
			do_r1 <= DRP_DO;
			do_r2 <= do_r1;
			rdy_r1 <= DRP_RDY;
			rdy_r2 <= rdy_r1;
		end
	wire [15:0] data_rx_dw = (x16_r2 ? X16_RX_DW : X20_RX_DW);
	reg [1:0] load_cnt = 2'd0;
	always @(posedge DRP_CLK)
		if (!DRP_RST_N)
			load_cnt <= 2'd0;
		else if (state != 3'd1)
			load_cnt <= 2'd0;
		else if (load_cnt < LOAD_CNT_MAX)
			load_cnt <= load_cnt + 2'd1;
	wire load_done = load_cnt == LOAD_CNT_MAX;
	reg [4:0] index = 5'd0;
	reg [4:0] index_nx;
	reg [8:0] addr_reg = 9'd0;
	reg [15:0] di_reg = 16'd0;
	always @(posedge DRP_CLK)
		if (!DRP_RST_N) begin
			addr_reg <= 9'd0;
			di_reg <= 16'd0;
		end
		else if (index == 5'd0) begin
			addr_reg <= ADDR_RX_DW;
			di_reg <= (do_r2 & MASK_RX_DW) | data_rx_dw;
		end
		else begin
			addr_reg <= 9'd0;
			di_reg <= 16'd0;
		end
	reg done = 1'b1;
	reg done_nx;
	always @(*) begin
		if (_sv2v_0)
			;
		state_nx = state;
		index_nx = index;
		done_nx = done;
		(* full_case, parallel_case *)
		case (state)
			3'd0:
				if (start_r2) begin
					state_nx = 3'd1;
					index_nx = 5'd0;
					done_nx = 1'b0;
				end
				else begin
					state_nx = 3'd0;
					index_nx = 5'd0;
					done_nx = 1'b1;
				end
			3'd1: begin
				state_nx = (load_done ? 3'd2 : 3'd1);
				done_nx = 1'b0;
			end
			3'd2: begin
				state_nx = 3'd3;
				done_nx = 1'b0;
			end
			3'd3: begin
				state_nx = (rdy_r2 ? 3'd4 : 3'd3);
				done_nx = 1'b0;
			end
			3'd4: begin
				state_nx = 3'd5;
				done_nx = 1'b0;
			end
			3'd5: begin
				state_nx = (rdy_r2 ? 3'd6 : 3'd5);
				done_nx = 1'b0;
			end
			3'd6:
				if (index == INDEX_MAX) begin
					state_nx = 3'd0;
					index_nx = 5'd0;
					done_nx = 1'b1;
				end
				else begin
					state_nx = 3'd1;
					index_nx = index + 5'd1;
					done_nx = 1'b0;
				end
			default: begin
				state_nx = 3'd0;
				index_nx = 5'd0;
				done_nx = 1'b1;
			end
		endcase
	end
	always @(posedge DRP_CLK)
		if (!DRP_RST_N) begin
			state <= 3'd0;
			index <= 5'd0;
			done <= 1'b1;
		end
		else begin
			state <= state_nx;
			index <= index_nx;
			done <= done_nx;
		end
	assign DRP_ADDR = addr_reg;
	assign DRP_EN = (state == 3'd2) || (state == 3'd4);
	assign DRP_DI = di_reg;
	assign DRP_WE = state == 3'd4;
	assign DRP_DONE = done;
	assign DRP_FSM = state;
	initial _sv2v_0 = 0;
endmodule
module clk_synth (
	CLK_CLK,
	CLK_TXOUTCLK,
	CLK_RXOUTCLK_IN,
	CLK_RST_N,
	CLK_PCLK_SEL,
	CLK_PCLK_SEL_SLAVE,
	CLK_GEN3,
	CLK_PCLK,
	CLK_PCLK_SLAVE,
	CLK_RXUSRCLK,
	CLK_RXOUTCLK_OUT,
	CLK_DCLK,
	CLK_OOBCLK,
	CLK_USERCLK1,
	CLK_USERCLK2,
	CLK_MMCM_LOCK
);
	localparam PCIE_REFCLK_FREQ = 0;
	localparam PCIE_USERCLK1_FREQ = 2;
	localparam PCIE_USERCLK2_FREQ = 2;
	input CLK_CLK;
	input CLK_TXOUTCLK;
	localparam signed [31:0] link_pkg_PCIE_LANES = 1;
	input [0:0] CLK_RXOUTCLK_IN;
	input CLK_RST_N;
	input [0:0] CLK_PCLK_SEL;
	input [0:0] CLK_PCLK_SEL_SLAVE;
	input CLK_GEN3;
	output wire CLK_PCLK;
	output wire CLK_PCLK_SLAVE;
	output wire CLK_RXUSRCLK;
	output wire [0:0] CLK_RXOUTCLK_OUT;
	output wire CLK_DCLK;
	output wire CLK_OOBCLK;
	output wire CLK_USERCLK1;
	output wire CLK_USERCLK2;
	output wire CLK_MMCM_LOCK;
	localparam DIVCLK_DIVIDE = 1;
	localparam CLKFBOUT_MULT_F = 10;
	localparam CLKIN1_PERIOD = 10;
	localparam CLKOUT0_DIVIDE_F = 8;
	localparam CLKOUT1_DIVIDE = 4;
	localparam CLKOUT2_DIVIDE = 16;
	localparam CLKOUT3_DIVIDE = 16;
	localparam CLKOUT4_DIVIDE = 20;
	wire refclk;
	wire mmcm_fb;
	wire clk_125mhz;
	wire clk_250mhz;
	wire userclk1;
	wire userclk1_1;
	wire userclk2_1;
	wire mmcm_lock;
	wire pclk_1;
	wire pclk;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] pclk_sel_reg1 = 1'sb0;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] pclk_sel_reg2 = 1'sb0;
	reg pclk_sel = 1'b0;
	always @(posedge pclk)
		if (!CLK_RST_N) begin
			pclk_sel_reg1 <= 1'sb0;
			pclk_sel_reg2 <= 1'sb0;
		end
		else begin
			pclk_sel_reg1 <= CLK_PCLK_SEL;
			pclk_sel_reg2 <= pclk_sel_reg1;
		end
	always @(posedge pclk)
		if (!CLK_RST_N)
			pclk_sel <= 1'b0;
		else if (&pclk_sel_reg2)
			pclk_sel <= 1'b1;
		else if (&(~pclk_sel_reg2))
			pclk_sel <= 1'b0;
	BUFG txoutclk_i(
		.I(CLK_TXOUTCLK),
		.O(refclk)
	);
	MMCME2_ADV #(
		.BANDWIDTH("OPTIMIZED"),
		.CLKOUT4_CASCADE("FALSE"),
		.COMPENSATION("ZHOLD"),
		.STARTUP_WAIT("FALSE"),
		.DIVCLK_DIVIDE(DIVCLK_DIVIDE),
		.CLKFBOUT_MULT_F(CLKFBOUT_MULT_F),
		.CLKFBOUT_PHASE(0.000),
		.CLKFBOUT_USE_FINE_PS("FALSE"),
		.CLKOUT0_DIVIDE_F(CLKOUT0_DIVIDE_F),
		.CLKOUT0_PHASE(0.000),
		.CLKOUT0_DUTY_CYCLE(0.500),
		.CLKOUT0_USE_FINE_PS("FALSE"),
		.CLKOUT1_DIVIDE(CLKOUT1_DIVIDE),
		.CLKOUT1_PHASE(0.000),
		.CLKOUT1_DUTY_CYCLE(0.500),
		.CLKOUT1_USE_FINE_PS("FALSE"),
		.CLKOUT2_DIVIDE(CLKOUT2_DIVIDE),
		.CLKOUT2_PHASE(0.000),
		.CLKOUT2_DUTY_CYCLE(0.500),
		.CLKOUT2_USE_FINE_PS("FALSE"),
		.CLKOUT3_DIVIDE(CLKOUT3_DIVIDE),
		.CLKOUT3_PHASE(0.000),
		.CLKOUT3_DUTY_CYCLE(0.500),
		.CLKOUT3_USE_FINE_PS("FALSE"),
		.CLKOUT4_DIVIDE(CLKOUT4_DIVIDE),
		.CLKOUT4_PHASE(0.000),
		.CLKOUT4_DUTY_CYCLE(0.500),
		.CLKOUT4_USE_FINE_PS("FALSE"),
		.CLKIN1_PERIOD(CLKIN1_PERIOD),
		.REF_JITTER1(0.010)
	) mmcm_i(
		.CLKIN1(refclk),
		.CLKIN2(1'd0),
		.CLKINSEL(1'd1),
		.CLKFBIN(mmcm_fb),
		.RST(!CLK_RST_N),
		.PWRDWN(1'd0),
		.CLKFBOUT(mmcm_fb),
		.CLKFBOUTB(),
		.CLKOUT0(clk_125mhz),
		.CLKOUT0B(),
		.CLKOUT1(clk_250mhz),
		.CLKOUT1B(),
		.CLKOUT2(userclk1),
		.CLKOUT2B(),
		.CLKOUT3(),
		.CLKOUT3B(),
		.CLKOUT4(),
		.CLKOUT5(),
		.CLKOUT6(),
		.LOCKED(mmcm_lock),
		.DCLK(1'd0),
		.DADDR(7'd0),
		.DEN(1'd0),
		.DWE(1'd0),
		.DI(16'd0),
		.DO(),
		.DRDY(),
		.PSCLK(1'd0),
		.PSEN(1'd0),
		.PSINCDEC(1'd0),
		.PSDONE(),
		.CLKINSTOPPED(),
		.CLKFBSTOPPED()
	);
	BUFGCTRL pclk_i1(
		.CE0(1'd1),
		.CE1(1'd1),
		.I0(clk_125mhz),
		.I1(clk_250mhz),
		.IGNORE0(1'd0),
		.IGNORE1(1'd0),
		.S0(~pclk_sel),
		.S1(pclk_sel),
		.O(pclk_1)
	);
	BUFG dclk_i(
		.I(clk_125mhz),
		.O(CLK_DCLK)
	);
	BUFG usrclk1_i1(
		.I(userclk1),
		.O(userclk1_1)
	);
	assign userclk2_1 = userclk1_1;
	assign pclk = pclk_1;
	assign CLK_PCLK = pclk;
	assign CLK_PCLK_SLAVE = 1'b0;
	assign CLK_RXUSRCLK = pclk_1;
	assign CLK_RXOUTCLK_OUT = {link_pkg_PCIE_LANES {1'b0}};
	assign CLK_OOBCLK = pclk;
	assign CLK_USERCLK1 = userclk1_1;
	assign CLK_USERCLK2 = userclk2_1;
	assign CLK_MMCM_LOCK = mmcm_lock;
endmodule
module eios_squelch (
	USER_RXCHARISK,
	USER_RXDATA,
	USER_RXVALID,
	USER_RXELECIDLE,
	USER_RX_STATUS,
	USER_RX_PHY_STATUS,
	GT_RXCHARISK,
	GT_RXDATA,
	GT_RXVALID,
	GT_RXELECIDLE,
	GT_RX_STATUS,
	GT_RX_PHY_STATUS,
	PLM_IN_L0,
	PLM_IN_RS,
	USER_CLK,
	RESET
);
	output wire [1:0] USER_RXCHARISK;
	output wire [15:0] USER_RXDATA;
	output wire USER_RXVALID;
	output wire USER_RXELECIDLE;
	output wire [2:0] USER_RX_STATUS;
	output wire USER_RX_PHY_STATUS;
	input wire [1:0] GT_RXCHARISK;
	input wire [15:0] GT_RXDATA;
	input wire GT_RXVALID;
	input wire GT_RXELECIDLE;
	input wire [2:0] GT_RX_STATUS;
	input wire GT_RX_PHY_STATUS;
	input wire PLM_IN_L0;
	input wire PLM_IN_RS;
	input wire USER_CLK;
	input wire RESET;
	localparam [4:0] EIOS_DET_IDL = 5'b00001;
	localparam [4:0] EIOS_DET_NO_STR0 = 5'b00010;
	localparam [4:0] EIOS_DET_STR0 = 5'b00100;
	localparam [4:0] EIOS_DET_STR1 = 5'b01000;
	localparam [4:0] EIOS_DET_DONE = 5'b10000;
	localparam [7:0] EIOS_COM = 8'hbc;
	localparam [7:0] EIOS_IDL = 8'h7c;
	reg [4:0] reg_state_eios_det;
	reg reg_symbol_after_eios;
	reg [1:0] gt_rxcharisk_q;
	reg [15:0] gt_rxdata_q;
	reg gt_rxvalid_q;
	reg gt_rxelecidle_q;
	reg [2:0] gt_rx_status_q;
	reg gt_rx_phy_status_q;
	always @(posedge USER_CLK)
		if (RESET) begin
			reg_state_eios_det <= EIOS_DET_IDL;
			reg_symbol_after_eios <= 1'b0;
			gt_rxcharisk_q <= 2'b00;
			gt_rxdata_q <= 16'h0000;
			gt_rxvalid_q <= 1'b0;
			gt_rxelecidle_q <= 1'b0;
			gt_rx_status_q <= 3'b000;
			gt_rx_phy_status_q <= 1'b0;
		end
		else begin
			reg_symbol_after_eios <= 1'b0;
			gt_rxcharisk_q <= GT_RXCHARISK;
			gt_rxelecidle_q <= GT_RXELECIDLE;
			gt_rxdata_q <= GT_RXDATA;
			gt_rx_phy_status_q <= GT_RX_PHY_STATUS;
			if ((reg_state_eios_det == EIOS_DET_DONE) && PLM_IN_L0)
				gt_rxvalid_q <= 1'b0;
			else if (GT_RXELECIDLE && !gt_rxvalid_q)
				gt_rxvalid_q <= 1'b0;
			else
				gt_rxvalid_q <= GT_RXVALID;
			if (gt_rxvalid_q)
				gt_rx_status_q <= GT_RX_STATUS;
			else if (!gt_rxvalid_q && PLM_IN_L0)
				gt_rx_status_q <= 3'b000;
			else
				gt_rx_status_q <= GT_RX_STATUS;
			case (reg_state_eios_det)
				EIOS_DET_IDL:
					if (((gt_rxcharisk_q[0] && (gt_rxdata_q[7:0] == EIOS_COM)) && gt_rxcharisk_q[1]) && (gt_rxdata_q[15:8] == EIOS_IDL))
						reg_state_eios_det <= EIOS_DET_NO_STR0;
					else if (gt_rxcharisk_q[1] && (gt_rxdata_q[15:8] == EIOS_COM))
						reg_state_eios_det <= EIOS_DET_STR0;
					else
						reg_state_eios_det <= EIOS_DET_IDL;
				EIOS_DET_NO_STR0:
					if ((gt_rxcharisk_q[0] && (gt_rxdata_q[7:0] == EIOS_IDL)) && (gt_rxcharisk_q[1] && (gt_rxdata_q[15:8] == EIOS_IDL))) begin
						reg_state_eios_det <= EIOS_DET_DONE;
						gt_rxvalid_q <= 1'b0;
					end
					else if (gt_rxcharisk_q[0] && (gt_rxdata_q[7:0] == EIOS_IDL)) begin
						reg_state_eios_det <= EIOS_DET_DONE;
						gt_rxvalid_q <= 1'b0;
					end
					else
						reg_state_eios_det <= EIOS_DET_IDL;
				EIOS_DET_STR0:
					if ((gt_rxcharisk_q[0] && (gt_rxdata_q[7:0] == EIOS_IDL)) && (gt_rxcharisk_q[1] && (gt_rxdata_q[15:8] == EIOS_IDL))) begin
						reg_state_eios_det <= EIOS_DET_STR1;
						gt_rxvalid_q <= 1'b0;
						reg_symbol_after_eios <= 1'b1;
					end
					else
						reg_state_eios_det <= EIOS_DET_IDL;
				EIOS_DET_STR1:
					if (gt_rxcharisk_q[0] && (gt_rxdata_q[7:0] == EIOS_IDL)) begin
						reg_state_eios_det <= EIOS_DET_DONE;
						gt_rxvalid_q <= 1'b0;
					end
					else
						reg_state_eios_det <= EIOS_DET_IDL;
				EIOS_DET_DONE: reg_state_eios_det <= EIOS_DET_IDL;
				default: reg_state_eios_det <= EIOS_DET_IDL;
			endcase
		end
	assign USER_RXVALID = gt_rxvalid_q;
	assign USER_RXCHARISK[0] = (gt_rxvalid_q ? gt_rxcharisk_q[0] : 1'b0);
	assign USER_RXCHARISK[1] = (gt_rxvalid_q && !reg_symbol_after_eios ? gt_rxcharisk_q[1] : 1'b0);
	assign USER_RXDATA[7:0] = gt_rxdata_q[7:0];
	assign USER_RXDATA[15:8] = gt_rxdata_q[15:8];
	assign USER_RX_STATUS = gt_rx_status_q;
	assign USER_RX_PHY_STATUS = gt_rx_phy_status_q;
	assign USER_RXELECIDLE = gt_rxelecidle_q;
endmodule
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
module init_ctrl (
	RST_CLK,
	RST_RXUSRCLK,
	RST_DCLK,
	RST_RST_N,
	RST_DRP_DONE,
	RST_RXPMARESETDONE,
	RST_PLLLOCK,
	RST_RATE_IDLE,
	RST_RXCDRLOCK,
	RST_MMCM_LOCK,
	RST_RESETDONE,
	RST_PHYSTATUS,
	RST_TXSYNC_DONE,
	RST_CPLLRESET,
	RST_CPLLPD,
	RST_DRP_START,
	RST_DRP_X16,
	RST_RXUSRCLK_RESET,
	RST_DCLK_RESET,
	RST_GTRESET,
	RST_USERRDY,
	RST_TXSYNC_START,
	RST_IDLE,
	RST_FSM
);
	reg _sv2v_0;
	localparam CFG_WAIT_MAX = 6'd63;
	localparam BYPASS_RXCDRLOCK = 1;
	input RST_CLK;
	input RST_RXUSRCLK;
	input RST_DCLK;
	input RST_RST_N;
	localparam signed [31:0] link_pkg_PCIE_LANES = 1;
	input [0:0] RST_DRP_DONE;
	input [0:0] RST_RXPMARESETDONE;
	input RST_PLLLOCK;
	input [0:0] RST_RATE_IDLE;
	input [0:0] RST_RXCDRLOCK;
	input RST_MMCM_LOCK;
	input [0:0] RST_RESETDONE;
	input [0:0] RST_PHYSTATUS;
	input [0:0] RST_TXSYNC_DONE;
	output wire RST_CPLLRESET;
	output wire RST_CPLLPD;
	output reg RST_DRP_START;
	output reg RST_DRP_X16;
	output wire RST_RXUSRCLK_RESET;
	output wire RST_DCLK_RESET;
	output wire RST_GTRESET;
	output wire RST_USERRDY;
	output wire RST_TXSYNC_START;
	output wire RST_IDLE;
	output wire [4:0] RST_FSM;
	reg [4:0] state = 5'd1;
	reg [4:0] state_nx;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] drp_done_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] drp_done_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] rxpma_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] rxpma_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg plllock_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg plllock_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] rate_idle_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] rate_idle_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] rxcdrlock_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] rxcdrlock_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg mmcmlock_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg mmcmlock_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] resetdone_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] resetdone_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] phystatus_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] phystatus_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] txsyncdone_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] txsyncdone_r2;
	always @(posedge RST_CLK)
		if (!RST_RST_N) begin
			{drp_done_r1, rxpma_r1, rate_idle_r1, rxcdrlock_r1, resetdone_r1, phystatus_r1, txsyncdone_r1} <= 1'sb0;
			{drp_done_r2, rxpma_r2, rate_idle_r2, rxcdrlock_r2, resetdone_r2, phystatus_r2, txsyncdone_r2} <= 1'sb0;
			{plllock_r1, mmcmlock_r1, plllock_r2, mmcmlock_r2} <= 1'sb0;
		end
		else begin
			drp_done_r1 <= RST_DRP_DONE;
			drp_done_r2 <= drp_done_r1;
			rxpma_r1 <= RST_RXPMARESETDONE;
			rxpma_r2 <= rxpma_r1;
			plllock_r1 <= RST_PLLLOCK;
			plllock_r2 <= plllock_r1;
			rate_idle_r1 <= RST_RATE_IDLE;
			rate_idle_r2 <= rate_idle_r1;
			rxcdrlock_r1 <= RST_RXCDRLOCK;
			rxcdrlock_r2 <= rxcdrlock_r1;
			mmcmlock_r1 <= RST_MMCM_LOCK;
			mmcmlock_r2 <= mmcmlock_r1;
			resetdone_r1 <= RST_RESETDONE;
			resetdone_r2 <= resetdone_r1;
			phystatus_r1 <= RST_PHYSTATUS;
			phystatus_r2 <= phystatus_r1;
			txsyncdone_r1 <= RST_TXSYNC_DONE;
			txsyncdone_r2 <= txsyncdone_r1;
		end
	wire pll_unlocked = ~plllock_r2;
	wire pll_locked = plllock_r2;
	wire resetdone_lo = &(~resetdone_r2);
	wire resetdone_hi = &resetdone_r2;
	wire drp_busy = &(~drp_done_r2);
	wire drp_ready = &drp_done_r2;
	wire rxpma_hi = &rxpma_r2;
	wire rxpma_lo = &(~rxpma_r2);
	wire phystatus_lo = &(~phystatus_r2);
	wire txsync_lo = &(~txsyncdone_r2);
	wire txsync_hi = &txsyncdone_r2;
	wire locks_ok = mmcmlock_r2 && (&rxcdrlock_r2 || 1'd1);
	reg [5:0] cfg_wait_cnt = 6'd0;
	always @(posedge RST_CLK)
		if (!RST_RST_N)
			cfg_wait_cnt <= 6'd0;
		else if (state != 5'd1)
			cfg_wait_cnt <= 6'd0;
		else if (cfg_wait_cnt < CFG_WAIT_MAX)
			cfg_wait_cnt <= cfg_wait_cnt + 6'd1;
	wire cfg_wait_done = cfg_wait_cnt == CFG_WAIT_MAX;
	always @(*) begin
		if (_sv2v_0)
			;
		state_nx = state;
		(* full_case, parallel_case *)
		case (state)
			5'd0: state_nx = 5'd0;
			5'd1: state_nx = (cfg_wait_done ? 5'd2 : 5'd1);
			5'd2: state_nx = (pll_unlocked && resetdone_lo ? 5'd3 : 5'd2);
			5'd3: state_nx = (drp_busy ? 5'd4 : 5'd3);
			5'd4: state_nx = (drp_ready ? 5'd5 : 5'd4);
			5'd5: state_nx = (pll_locked ? 5'd6 : 5'd5);
			5'd6: state_nx = 5'd7;
			5'd7: state_nx = (rxpma_hi ? 5'd8 : 5'd7);
			5'd8: state_nx = (rxpma_lo ? 5'd9 : 5'd8);
			5'd9: state_nx = (drp_busy ? 5'd10 : 5'd9);
			5'd10: state_nx = (drp_ready ? 5'd11 : 5'd10);
			5'd11: state_nx = (locks_ok ? 5'd12 : 5'd11);
			5'd12: state_nx = (resetdone_hi && phystatus_lo ? 5'd13 : 5'd12);
			5'd13: state_nx = (txsync_lo ? 5'd14 : 5'd13);
			5'd14: state_nx = (txsync_hi ? 5'd0 : 5'd14);
			default: state_nx = 5'd1;
		endcase
	end
	reg cpllreset_q = 1'b0;
	reg gtreset_q = 1'b0;
	reg userrdy_q = 1'b0;
	wire cpllreset_d = ((state == 5'd2) || (state == 5'd3)) || (state == 5'd4);
	wire gtreset_d = (((state == 5'd2) || (state == 5'd3)) || (state == 5'd4)) || (state == 5'd5);
	wire userrdy_d = (state == 5'd11 ? locks_ok : userrdy_q);
	always @(posedge RST_CLK)
		if (!RST_RST_N) begin
			state <= 5'd1;
			cpllreset_q <= 1'b0;
			gtreset_q <= 1'b0;
			userrdy_q <= 1'b0;
		end
		else begin
			state <= state_nx;
			cpllreset_q <= cpllreset_d;
			gtreset_q <= gtreset_d;
			userrdy_q <= userrdy_d;
		end
	always @(posedge RST_CLK)
		if (!RST_RST_N) begin
			RST_DRP_START <= 1'b0;
			RST_DRP_X16 <= 1'b0;
		end
		else begin
			RST_DRP_START <= (state == 5'd3) || (state == 5'd9);
			RST_DRP_X16 <= (state == 5'd3) || (state == 5'd4);
		end
	reg rxusrclk_rst_r1 = 1'b0;
	reg rxusrclk_rst_r2 = 1'b0;
	always @(posedge RST_RXUSRCLK)
		if (cpllreset_q) begin
			rxusrclk_rst_r1 <= 1'b1;
			rxusrclk_rst_r2 <= 1'b1;
		end
		else begin
			rxusrclk_rst_r1 <= 1'b0;
			rxusrclk_rst_r2 <= rxusrclk_rst_r1;
		end
	reg dclk_rst_r1 = 1'b0;
	reg dclk_rst_r2 = 1'b0;
	always @(posedge RST_DCLK) begin
		dclk_rst_r1 <= state == 5'd1;
		dclk_rst_r2 <= dclk_rst_r1;
	end
	assign RST_CPLLRESET = cpllreset_q;
	assign RST_CPLLPD = 1'b0;
	assign RST_RXUSRCLK_RESET = rxusrclk_rst_r2;
	assign RST_DCLK_RESET = dclk_rst_r2;
	assign RST_GTRESET = gtreset_q;
	assign RST_USERRDY = userrdy_q;
	assign RST_TXSYNC_START = state == 5'd13;
	assign RST_IDLE = state == 5'd0;
	assign RST_FSM = state;
	initial _sv2v_0 = 0;
endmodule
module lane_keeper (
	USER_TXUSRCLK,
	USER_RXUSRCLK,
	USER_OOBCLK_IN,
	USER_RST_N,
	USER_RXUSRCLK_RST_N,
	USER_PCLK_SEL,
	USER_RESETOVRD_START,
	USER_TXRESETDONE,
	USER_RXRESETDONE,
	USER_TXELECIDLE,
	USER_TXCOMPLIANCE,
	USER_RXCDRLOCK_IN,
	USER_RXVALID_IN,
	USER_RXSTATUS_IN,
	USER_PHYSTATUS_IN,
	USER_RATE_DONE,
	USER_RST_IDLE,
	USER_RATE_RXSYNC,
	USER_RATE_IDLE,
	USER_RATE_GEN3,
	USER_RXEQ_ADAPT_DONE,
	USER_OOBCLK,
	USER_RESETOVRD,
	USER_TXPMARESET,
	USER_RXPMARESET,
	USER_RXCDRRESET,
	USER_RXCDRFREQRESET,
	USER_RXDFELPMRESET,
	USER_EYESCANRESET,
	USER_TXPCSRESET,
	USER_RXPCSRESET,
	USER_RXBUFRESET,
	USER_RESETOVRD_DONE,
	USER_RESETDONE,
	USER_ACTIVE_LANE,
	USER_RXCDRLOCK_OUT,
	USER_RXVALID_OUT,
	USER_PHYSTATUS_OUT,
	USER_PHYSTATUS_RST,
	USER_GEN3_RDY,
	USER_RX_CONVERGE
);
	reg _sv2v_0;
	localparam RXCDRLOCK_MAX = 4'd15;
	localparam RXVALID_MAX = 4'd15;
	localparam CONVERGE_MAX = 22'd3125000;
	input USER_TXUSRCLK;
	input USER_RXUSRCLK;
	input USER_OOBCLK_IN;
	input USER_RST_N;
	input USER_RXUSRCLK_RST_N;
	input USER_PCLK_SEL;
	input USER_RESETOVRD_START;
	input USER_TXRESETDONE;
	input USER_RXRESETDONE;
	input USER_TXELECIDLE;
	input USER_TXCOMPLIANCE;
	input USER_RXCDRLOCK_IN;
	input USER_RXVALID_IN;
	input USER_RXSTATUS_IN;
	input USER_PHYSTATUS_IN;
	input USER_RATE_DONE;
	input USER_RST_IDLE;
	input USER_RATE_RXSYNC;
	input USER_RATE_IDLE;
	input USER_RATE_GEN3;
	input USER_RXEQ_ADAPT_DONE;
	output wire USER_OOBCLK;
	output wire USER_RESETOVRD;
	output wire USER_TXPMARESET;
	output wire USER_RXPMARESET;
	output wire USER_RXCDRRESET;
	output wire USER_RXCDRFREQRESET;
	output wire USER_RXDFELPMRESET;
	output wire USER_EYESCANRESET;
	output wire USER_TXPCSRESET;
	output wire USER_RXPCSRESET;
	output wire USER_RXBUFRESET;
	output wire USER_RESETOVRD_DONE;
	output wire USER_RESETDONE;
	output wire USER_ACTIVE_LANE;
	output wire USER_RXCDRLOCK_OUT;
	output wire USER_RXVALID_OUT;
	output wire USER_PHYSTATUS_OUT;
	output wire USER_PHYSTATUS_RST;
	output wire USER_GEN3_RDY;
	output wire USER_RX_CONVERGE;
	localparam [21:0] CONV_MAX = CONVERGE_MAX;
	wire [7:0] tx_async = {USER_RXEQ_ADAPT_DONE, USER_RXCDRLOCK_IN, USER_TXCOMPLIANCE, USER_TXELECIDLE, USER_RXRESETDONE, USER_TXRESETDONE, USER_RESETOVRD_START, USER_PCLK_SEL};
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [7:0] tx_s1 = 8'd0;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [7:0] tx_s2 = 8'd0;
	always @(posedge USER_TXUSRCLK)
		if (!USER_RST_N) begin
			tx_s1 <= 8'd0;
			tx_s2 <= 8'd0;
		end
		else begin
			tx_s1 <= tx_async;
			tx_s2 <= tx_s1;
		end
	wire pclk_sel_2 = tx_s2[0];
	wire resetovrd_st_2 = tx_s2[1];
	wire txresetdone_2 = tx_s2[2];
	wire rxresetdone_2 = tx_s2[3];
	wire txelecidle_2 = tx_s2[4];
	wire txcompliance_2 = tx_s2[5];
	wire rxcdrlock_2 = tx_s2[6];
	wire rxeq_adapt_2 = tx_s2[7];
	wire [6:0] rx_async = {USER_RATE_GEN3, USER_RATE_IDLE, USER_RATE_RXSYNC, USER_RATE_DONE, USER_RST_IDLE, USER_RXSTATUS_IN, USER_RXVALID_IN};
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [6:0] rx_s1 = 7'd0;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [6:0] rx_s2 = 7'd0;
	always @(posedge USER_RXUSRCLK)
		if (!USER_RXUSRCLK_RST_N) begin
			rx_s1 <= 7'd0;
			rx_s2 <= 7'd0;
		end
		else begin
			rx_s1 <= rx_async;
			rx_s2 <= rx_s1;
		end
	wire rxvalid_2 = rx_s2[0];
	wire rxstatus_2 = rx_s2[1];
	wire rst_idle_2 = rx_s2[2];
	wire rate_done_2 = rx_s2[3];
	wire rate_rxsync_2 = rx_s2[4];
	wire rate_idle_2 = rx_s2[5];
	wire rate_gen3_2 = rx_s2[6];
	reg [1:0] fsm = 2'd0;
	reg [1:0] fsm_nx;
	reg [7:0] reset_cnt = 8'd127;
	reg [7:0] reset_cnt_nx;
	reg [7:0] reset = 8'h00;
	reg [7:0] reset_nx;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (fsm)
			2'd0: fsm_nx = (resetovrd_st_2 ? 2'd1 : 2'd0);
			2'd1: fsm_nx = (reset_cnt == 8'd0 ? 2'd2 : 2'd1);
			2'd2: fsm_nx = 2'd3;
			2'd3: fsm_nx = ((reset == 8'd0) && rxresetdone_2 ? 2'd0 : 2'd3);
			default: fsm_nx = 2'd0;
		endcase
		if (((fsm == 2'd1) || (fsm == 2'd3)) && (reset_cnt != 8'd0))
			reset_cnt_nx = reset_cnt - 8'd1;
		else
			reset_cnt_nx = 8'd127;
		if (fsm == 2'd2)
			reset_nx = 8'hff;
		else if ((fsm == 2'd3) && (reset_cnt == 8'd0))
			reset_nx = {reset[6:0], 1'b0};
		else
			reset_nx = reset;
	end
	always @(posedge USER_TXUSRCLK)
		if (!USER_RST_N) begin
			fsm <= 2'd0;
			reset_cnt <= 8'd127;
			reset <= 8'h00;
		end
		else begin
			fsm <= fsm_nx;
			reset_cnt <= reset_cnt_nx;
			reset <= reset_nx;
		end
	reg [1:0] oobclk_cnt = 2'd0;
	reg oobclk = 1'b0;
	always @(posedge USER_OOBCLK_IN)
		if (!USER_RST_N) begin
			oobclk_cnt <= 2'd0;
			oobclk <= 1'b0;
		end
		else begin
			oobclk_cnt <= oobclk_cnt + 2'd1;
			oobclk <= (pclk_sel_2 ? oobclk_cnt[1] : oobclk_cnt[0]);
		end
	reg [3:0] rxcdrlock_cnt = 4'd0;
	always @(posedge USER_TXUSRCLK)
		if (!USER_RST_N)
			rxcdrlock_cnt <= 4'd0;
		else if (!rxcdrlock_2)
			rxcdrlock_cnt <= 4'd0;
		else if (rxcdrlock_cnt != RXCDRLOCK_MAX)
			rxcdrlock_cnt <= rxcdrlock_cnt + 4'd1;
	reg [3:0] rxvalid_cnt = 4'd0;
	always @(posedge USER_RXUSRCLK)
		if (!USER_RXUSRCLK_RST_N)
			rxvalid_cnt <= 4'd0;
		else if (rxvalid_2 && (rxvalid_cnt == RXVALID_MAX))
			rxvalid_cnt <= rxvalid_cnt;
		else if (rxvalid_2 && !rxstatus_2)
			rxvalid_cnt <= rxvalid_cnt + 4'd1;
		else
			rxvalid_cnt <= 4'd0;
	reg [21:0] converge_cnt = 22'd0;
	reg converge_gen3 = 1'b0;
	always @(posedge USER_TXUSRCLK)
		if (!USER_RST_N)
			converge_cnt <= 22'd0;
		else if ((rst_idle_2 && rate_idle_2) && !rate_gen3_2)
			converge_cnt <= (converge_cnt < CONV_MAX ? converge_cnt + 22'd1 : converge_cnt);
		else
			converge_cnt <= 22'd0;
	always @(posedge USER_TXUSRCLK)
		if (!USER_RST_N)
			converge_gen3 <= 1'b0;
		else if (rate_gen3_2)
			converge_gen3 <= (rxeq_adapt_2 ? 1'b1 : converge_gen3);
		else
			converge_gen3 <= 1'b0;
	assign USER_RESETOVRD = fsm != 2'd0;
	assign USER_TXPMARESET = 1'b0;
	assign USER_RXPMARESET = reset[0];
	assign USER_RXCDRRESET = reset[1];
	assign USER_RXCDRFREQRESET = reset[2];
	assign USER_RXDFELPMRESET = reset[3];
	assign USER_EYESCANRESET = reset[4];
	assign USER_TXPCSRESET = 1'b0;
	assign USER_RXPCSRESET = reset[5];
	assign USER_RXBUFRESET = reset[6];
	assign USER_RESETOVRD_DONE = fsm == 2'd0;
	assign USER_OOBCLK = oobclk;
	assign USER_RESETDONE = txresetdone_2 && rxresetdone_2;
	assign USER_ACTIVE_LANE = !(txelecidle_2 && txcompliance_2);
	assign USER_RXCDRLOCK_OUT = USER_RXCDRLOCK_IN && (rxcdrlock_cnt == RXCDRLOCK_MAX);
	assign USER_RXVALID_OUT = ((USER_RXVALID_IN && (rxvalid_cnt == RXVALID_MAX)) && rst_idle_2) && rate_idle_2;
	assign USER_PHYSTATUS_OUT = (!rst_idle_2 || ((rate_idle_2 || rate_rxsync_2) && USER_PHYSTATUS_IN)) || rate_done_2;
	assign USER_PHYSTATUS_RST = !rst_idle_2;
	assign USER_GEN3_RDY = 1'b0;
	assign USER_RX_CONVERGE = (converge_cnt == CONV_MAX) || converge_gen3;
	initial _sv2v_0 = 0;
endmodule
module lane_xcvr (
	GT_MASTER,
	GT_GEN3,
	GT_RX_CONVERGE,
	GT_GTREFCLK0,
	GT_QPLLCLK,
	GT_QPLLREFCLK,
	GT_TXUSRCLK,
	GT_RXUSRCLK,
	GT_TXUSRCLK2,
	GT_RXUSRCLK2,
	GT_OOBCLK,
	GT_TXSYSCLKSEL,
	GT_RXSYSCLKSEL,
	GT_CPLLPDREFCLK,
	GT_TXOUTCLK,
	GT_RXOUTCLK,
	GT_CPLLLOCK,
	GT_RXCDRLOCK,
	GT_CPLLPD,
	GT_CPLLRESET,
	GT_TXUSERRDY,
	GT_RXUSERRDY,
	GT_RESETOVRD,
	GT_GTTXRESET,
	GT_GTRXRESET,
	GT_TXPMARESET,
	GT_RXPMARESET,
	GT_RXCDRRESET,
	GT_RXCDRFREQRESET,
	GT_RXDFELPMRESET,
	GT_EYESCANRESET,
	GT_TXPCSRESET,
	GT_RXPCSRESET,
	GT_RXBUFRESET,
	GT_EYESCANDATAERROR,
	GT_TXRESETDONE,
	GT_RXRESETDONE,
	GT_RXPMARESETDONE,
	GT_TXDATA,
	GT_TXDATAK,
	GT_TXP,
	GT_TXN,
	GT_RXN,
	GT_RXP,
	GT_RXDATA,
	GT_RXDATAK,
	GT_TXDETECTRX,
	GT_TXELECIDLE,
	GT_TXCOMPLIANCE,
	GT_RXPOLARITY,
	GT_TXPOWERDOWN,
	GT_RXPOWERDOWN,
	GT_TXRATE,
	GT_RXRATE,
	GT_TXMARGIN,
	GT_TXSWING,
	GT_TXDEEMPH,
	GT_TXINHIBIT,
	GT_TXPRECURSOR,
	GT_TXMAINCURSOR,
	GT_TXPOSTCURSOR,
	GT_RXVALID,
	GT_PHYSTATUS,
	GT_RXELECIDLE,
	GT_RXSTATUS,
	GT_RXBUFSTATUS,
	GT_TXRATEDONE,
	GT_RXRATEDONE,
	GT_RXDISPERR,
	GT_RXNOTINTABLE,
	GT_DRPCLK,
	GT_DRPADDR,
	GT_DRPEN,
	GT_DRPDI,
	GT_DRPWE,
	GT_DRPDO,
	GT_DRPRDY,
	GT_TXPHALIGN,
	GT_TXPHALIGNEN,
	GT_TXPHINIT,
	GT_TXDLYBYPASS,
	GT_TXDLYSRESET,
	GT_TXDLYEN,
	GT_TXDLYSRESETDONE,
	GT_TXPHINITDONE,
	GT_TXPHALIGNDONE,
	GT_TXPHDLYRESET,
	GT_TXSYNCMODE,
	GT_TXSYNCIN,
	GT_TXSYNCALLIN,
	GT_TXSYNCOUT,
	GT_TXSYNCDONE,
	GT_RXPHALIGN,
	GT_RXPHALIGNEN,
	GT_RXDLYBYPASS,
	GT_RXDLYSRESET,
	GT_RXDLYEN,
	GT_RXDDIEN,
	GT_RXDLYSRESETDONE,
	GT_RXPHALIGNDONE,
	GT_RXSYNCMODE,
	GT_RXSYNCIN,
	GT_RXSYNCALLIN,
	GT_RXSYNCOUT,
	GT_RXSYNCDONE,
	GT_RXSLIDE,
	GT_RXCOMMADET,
	GT_RXCHARISCOMMA,
	GT_RXBYTEISALIGNED,
	GT_RXBYTEREALIGN,
	GT_RXCHBONDEN,
	GT_RXCHBONDI,
	GT_RXCHBONDLEVEL,
	GT_RXCHBONDMASTER,
	GT_RXCHBONDSLAVE,
	GT_RXCHANISALIGNED,
	GT_RXCHBONDO,
	GT_TXPRBSSEL,
	GT_RXPRBSSEL,
	GT_TXPRBSFORCEERR,
	GT_RXPRBSCNTRESET,
	GT_LOOPBACK,
	GT_RXPRBSERR,
	GT_DMONITOROUT
);
	localparam PCIE_GT_DEVICE = "GTP";
	localparam PCIE_USE_MODE = "1.0";
	localparam PCIE_PLL_SEL = "CPLL";
	localparam PCIE_LPM_DFE = "LPM";
	localparam PCIE_LPM_DFE_GEN3 = "DFE";
	localparam PCIE_ASYNC_EN = "FALSE";
	localparam PCIE_TXBUF_EN = "FALSE";
	localparam PCIE_TXSYNC_MODE = 0;
	localparam PCIE_RXSYNC_MODE = 0;
	localparam PCIE_CHAN_BOND = 1;
	localparam PCIE_CHAN_BOND_EN = "TRUE";
	localparam PCIE_REFCLK_FREQ = 0;
	localparam PCIE_TX_EIDLE_ASSERT_DELAY = 3'd2;
	localparam PCIE_OOBCLK_MODE = 1;
	localparam TX_MARGIN_FULL_0 = 7'b1001111;
	localparam TX_MARGIN_FULL_1 = 7'b1001110;
	localparam TX_MARGIN_FULL_2 = 7'b1001101;
	localparam TX_MARGIN_FULL_3 = 7'b1001100;
	localparam TX_MARGIN_FULL_4 = 7'b1000011;
	localparam TX_MARGIN_LOW_0 = 7'b1000101;
	localparam TX_MARGIN_LOW_1 = 7'b1000110;
	localparam TX_MARGIN_LOW_2 = 7'b1000011;
	localparam TX_MARGIN_LOW_3 = 7'b1000010;
	localparam TX_MARGIN_LOW_4 = 7'b1000000;
	localparam PCIE_DEBUG_MODE = 0;
	input GT_MASTER;
	input GT_GEN3;
	input GT_RX_CONVERGE;
	input GT_GTREFCLK0;
	input GT_QPLLCLK;
	input GT_QPLLREFCLK;
	input GT_TXUSRCLK;
	input GT_RXUSRCLK;
	input GT_TXUSRCLK2;
	input GT_RXUSRCLK2;
	input GT_OOBCLK;
	input [1:0] GT_TXSYSCLKSEL;
	input [1:0] GT_RXSYSCLKSEL;
	input GT_CPLLPDREFCLK;
	output wire GT_TXOUTCLK;
	output wire GT_RXOUTCLK;
	output wire GT_CPLLLOCK;
	output wire GT_RXCDRLOCK;
	input GT_CPLLPD;
	input GT_CPLLRESET;
	input GT_TXUSERRDY;
	input GT_RXUSERRDY;
	input GT_RESETOVRD;
	input GT_GTTXRESET;
	input GT_GTRXRESET;
	input GT_TXPMARESET;
	input GT_RXPMARESET;
	input GT_RXCDRRESET;
	input GT_RXCDRFREQRESET;
	input GT_RXDFELPMRESET;
	input GT_EYESCANRESET;
	input GT_TXPCSRESET;
	input GT_RXPCSRESET;
	input GT_RXBUFRESET;
	output wire GT_EYESCANDATAERROR;
	output wire GT_TXRESETDONE;
	output wire GT_RXRESETDONE;
	output wire GT_RXPMARESETDONE;
	input [31:0] GT_TXDATA;
	input [3:0] GT_TXDATAK;
	output wire GT_TXP;
	output wire GT_TXN;
	input GT_RXN;
	input GT_RXP;
	output wire [31:0] GT_RXDATA;
	output wire [3:0] GT_RXDATAK;
	input GT_TXDETECTRX;
	input GT_TXELECIDLE;
	input GT_TXCOMPLIANCE;
	input GT_RXPOLARITY;
	input [1:0] GT_TXPOWERDOWN;
	input [1:0] GT_RXPOWERDOWN;
	input [2:0] GT_TXRATE;
	input [2:0] GT_RXRATE;
	input [2:0] GT_TXMARGIN;
	input GT_TXSWING;
	input GT_TXDEEMPH;
	input GT_TXINHIBIT;
	input [4:0] GT_TXPRECURSOR;
	input [6:0] GT_TXMAINCURSOR;
	input [4:0] GT_TXPOSTCURSOR;
	output wire GT_RXVALID;
	output wire GT_PHYSTATUS;
	output wire GT_RXELECIDLE;
	output wire [2:0] GT_RXSTATUS;
	output wire [2:0] GT_RXBUFSTATUS;
	output wire GT_TXRATEDONE;
	output wire GT_RXRATEDONE;
	output wire [7:0] GT_RXDISPERR;
	output wire [7:0] GT_RXNOTINTABLE;
	input GT_DRPCLK;
	input [8:0] GT_DRPADDR;
	input GT_DRPEN;
	input [15:0] GT_DRPDI;
	input GT_DRPWE;
	output wire [15:0] GT_DRPDO;
	output wire GT_DRPRDY;
	input GT_TXPHALIGN;
	input GT_TXPHALIGNEN;
	input GT_TXPHINIT;
	input GT_TXDLYBYPASS;
	input GT_TXDLYSRESET;
	input GT_TXDLYEN;
	output wire GT_TXDLYSRESETDONE;
	output wire GT_TXPHINITDONE;
	output wire GT_TXPHALIGNDONE;
	input GT_TXPHDLYRESET;
	input GT_TXSYNCMODE;
	input GT_TXSYNCIN;
	input GT_TXSYNCALLIN;
	output wire GT_TXSYNCOUT;
	output wire GT_TXSYNCDONE;
	input GT_RXPHALIGN;
	input GT_RXPHALIGNEN;
	input GT_RXDLYBYPASS;
	input GT_RXDLYSRESET;
	input GT_RXDLYEN;
	input GT_RXDDIEN;
	output wire GT_RXDLYSRESETDONE;
	output wire GT_RXPHALIGNDONE;
	input GT_RXSYNCMODE;
	input GT_RXSYNCIN;
	input GT_RXSYNCALLIN;
	output wire GT_RXSYNCOUT;
	output wire GT_RXSYNCDONE;
	input GT_RXSLIDE;
	output wire GT_RXCOMMADET;
	output wire [3:0] GT_RXCHARISCOMMA;
	output wire GT_RXBYTEISALIGNED;
	output wire GT_RXBYTEREALIGN;
	input GT_RXCHBONDEN;
	input [4:0] GT_RXCHBONDI;
	input [2:0] GT_RXCHBONDLEVEL;
	input GT_RXCHBONDMASTER;
	input GT_RXCHBONDSLAVE;
	output wire GT_RXCHANISALIGNED;
	output wire [4:0] GT_RXCHBONDO;
	input [2:0] GT_TXPRBSSEL;
	input [2:0] GT_RXPRBSSEL;
	input GT_TXPRBSFORCEERR;
	input GT_RXPRBSCNTRESET;
	input [2:0] GT_LOOPBACK;
	output wire GT_RXPRBSERR;
	output wire [14:0] GT_DMONITOROUT;
	wire [2:0] txoutclksel;
	wire [2:0] rxoutclksel;
	wire [63:0] rxdata;
	wire [7:0] rxdatak;
	wire [7:0] rxchariscomma;
	wire rxlpmen;
	wire [14:0] dmonitorout;
	wire dmonitorclk;
	wire cpllpd;
	wire cpllrst;
	localparam OUT_DIV = 2;
	localparam CLK25_DIV = 4;
	localparam TX_XCLK_SEL = "TXUSR";
	localparam TX_RXDETECT_CFG = 14'd100;
	localparam TX_RXDETECT_REF = 3'b000;
	localparam OOBCLK_SEL = 1'd1;
	localparam RXOOB_CLK_CFG = "FABRIC";
	localparam PCS_RSVD_ATTR = {44'h0000000001c, OOBCLK_SEL, 3'd1};
	localparam RXCDR_CFG_GTP = 83'h0000107fe406001041010;
	localparam TXSYNC_OVRD = 1'd1;
	localparam RXSYNC_OVRD = 1'd1;
	localparam signed [31:0] link_pkg_PCIE_LANES = 1;
	localparam TXSYNC_MULTILANE = 1'd0;
	localparam RXSYNC_MULTILANE = 1'd0;
	localparam CLK_COR_MIN_LAT = 13;
	localparam CLK_COR_MAX_LAT = 15;
	assign txoutclksel = (GT_MASTER ? 3'd3 : 3'd0);
	assign rxoutclksel = 3'd0;
	assign rxlpmen = (GT_GEN3 ? 1'd0 : 1'd1);
	generate
		if (1) begin : dmonitorclk_i_disable
			assign dmonitorclk = 1'd0;
		end
	endgenerate
	wake_timer wake_timer_i(
		.i_ibufds_gte2(GT_CPLLPDREFCLK),
		.o_cpllpd_ovrd(cpllpd),
		.o_cpllreset_ovrd(cpllrst)
	);
	generate
		if (PCIE_GT_DEVICE == "GTP") begin : hm_chan
			GTPE2_CHANNEL #(
				.SIM_RESET_SPEEDUP("FALSE"),
				.SIM_RECEIVER_DETECT_PASS("TRUE"),
				.SIM_TX_EIDLE_DRIVE_LEVEL("1"),
				.SIM_VERSION(PCIE_USE_MODE),
				.TXOUT_DIV(OUT_DIV),
				.RXOUT_DIV(OUT_DIV),
				.TX_CLK25_DIV(CLK25_DIV),
				.RX_CLK25_DIV(CLK25_DIV),
				.TX_XCLK_SEL(TX_XCLK_SEL),
				.RX_XCLK_SEL("RXREC"),
				.TXPCSRESET_TIME(5'b00001),
				.RXPCSRESET_TIME(5'b00001),
				.TXPMARESET_TIME(5'b00011),
				.RXPMARESET_TIME(5'b00011),
				.TX_DATA_WIDTH(20),
				.RX_DATA_WIDTH(20),
				.TX_RXDETECT_CFG(TX_RXDETECT_CFG),
				.TX_RXDETECT_REF(3'b011),
				.RX_CM_SEL(2'd3),
				.RX_CM_TRIM(4'b1010),
				.TX_EIDLE_ASSERT_DELAY(PCIE_TX_EIDLE_ASSERT_DELAY),
				.TX_EIDLE_DEASSERT_DELAY(3'b010),
				.PD_TRANS_TIME_NONE_P2(8'h09),
				.TX_DRIVE_MODE("PIPE"),
				.TX_DEEMPH0(5'b10100),
				.TX_DEEMPH1(5'b01011),
				.TX_MARGIN_FULL_0(7'b1001111),
				.TX_MARGIN_FULL_1(7'b1001110),
				.TX_MARGIN_FULL_2(7'b1001101),
				.TX_MARGIN_FULL_3(7'b1001100),
				.TX_MARGIN_FULL_4(7'b1000011),
				.TX_MARGIN_LOW_0(7'b1000101),
				.TX_MARGIN_LOW_1(7'b1000110),
				.TX_MARGIN_LOW_2(7'b1000011),
				.TX_MARGIN_LOW_3(7'b1000010),
				.TX_MARGIN_LOW_4(7'b1000000),
				.TX_MAINCURSOR_SEL(1'b0),
				.TX_PREDRIVER_MODE(1'b0),
				.PCS_PCIE_EN("TRUE"),
				.PCS_RSVD_ATTR(48'h000000000100),
				.PMA_RSV2(32'h00002040),
				.RX_BIAS_CFG(16'h0f33),
				.TERM_RCAL_CFG(15'b100001000010000),
				.TERM_RCAL_OVRD(3'b000),
				.RXPI_CFG0(3'd0),
				.RXPI_CFG1(1'd1),
				.RXPI_CFG2(1'd1),
				.RXCDR_CFG(RXCDR_CFG_GTP),
				.RXCDR_LOCK_CFG(6'b010101),
				.RXCDR_HOLD_DURING_EIDLE(1'd1),
				.RXCDR_FR_RESET_ON_EIDLE(1'd0),
				.RXCDR_PH_RESET_ON_EIDLE(1'd0),
				.RXLPM_CFG(4'b0110),
				.RXLPM_GC_CFG(9'b111100010),
				.RXLPM_GC_CFG2(3'b001),
				.RXLPM_HF_CFG2(5'b01010),
				.RXLPM_HOLD_DURING_EIDLE(1'b1),
				.RXLPM_INCM_CFG(1'b1),
				.RXLPM_IPCM_CFG(1'b0),
				.RXLPM_LF_CFG2(5'b01010),
				.RXLPM_OSINT_CFG(3'b100),
				.RX_OS_CFG(13'h0080),
				.RXOSCALRESET_TIME(5'b00011),
				.RXOSCALRESET_TIMEOUT(5'b00000),
				.ES_EYE_SCAN_EN("FALSE"),
				.TXBUF_EN(PCIE_TXBUF_EN),
				.TXBUF_RESET_ON_RATE_CHANGE("TRUE"),
				.TXPI_SYNFREQ_PPM(3'd1),
				.PMA_RSV(32'h00000333),
				.PMA_RSV3(2'b00),
				.TXPI_PPMCLK_SEL("TXUSRCLK2"),
				.TXPI_CFG0(2'b00),
				.TXPI_CFG1(2'b00),
				.TXPI_CFG2(2'b00),
				.TXPI_CFG3(1'b0),
				.TXPI_CFG4(1'b0),
				.TXPI_CFG5(3'b000),
				.TXPI_GREY_SEL(1'b0),
				.TXPI_INVSTROBE_SEL(1'b0),
				.TXPI_PPM_CFG(8'h00),
				.CLK_COMMON_SWING(1'b0),
				.TX_CLKMUX_EN(1'b1),
				.RX_CLKMUX_EN(1'b1),
				.OUTREFCLK_SEL_INV(2'b11),
				.PD_TRANS_TIME_FROM_P2(12'h03c),
				.PD_TRANS_TIME_TO_P2(8'h64),
				.TRANS_TIME_RATE(8'h0e),
				.RXBUFRESET_TIME(5'b00001),
				.RXCDRFREQRESET_TIME(5'b00001),
				.RXCDRPHRESET_TIME(5'b00001),
				.RXISCANRESET_TIME(5'b00001),
				.RXLPMRESET_TIME(7'b0001111),
				.RXLPM_HF_CFG(14'b00001111110000),
				.RXLPM_LF_CFG(18'b000000001111110000),
				.RXOOB_CFG(7'b0000110),
				.SATA_BURST_SEQ_LEN(4'b1111),
				.SATA_BURST_VAL(3'b100),
				.SATA_EIDLE_VAL(3'b100),
				.RXBUF_EN("TRUE"),
				.RX_DEFER_RESET_BUF_EN("TRUE"),
				.RXBUF_ADDR_MODE("FULL"),
				.RXBUF_EIDLE_HI_CNT(4'd4),
				.RXBUF_EIDLE_LO_CNT(4'd0),
				.RXBUF_RESET_ON_CB_CHANGE("TRUE"),
				.RXBUF_RESET_ON_COMMAALIGN("FALSE"),
				.RXBUF_RESET_ON_EIDLE("TRUE"),
				.RXBUF_RESET_ON_RATE_CHANGE("TRUE"),
				.RXBUF_THRESH_OVRD("FALSE"),
				.RXBUF_THRESH_OVFLW(61),
				.RXBUF_THRESH_UNDFLW(4),
				.TXPH_CFG(16'h0780),
				.TXPH_MONITOR_SEL(5'd0),
				.TXPHDLY_CFG(24'h084020),
				.TXDLY_CFG(16'h001f),
				.TXDLY_LCFG(9'h030),
				.TXDLY_TAP_CFG(16'd0),
				.TXSYNC_OVRD(TXSYNC_OVRD),
				.TXSYNC_MULTILANE(TXSYNC_MULTILANE),
				.TXSYNC_SKIP_DA(1'b0),
				.RXPH_CFG(24'd0),
				.RXPH_MONITOR_SEL(5'd0),
				.RXPHDLY_CFG(24'h004020),
				.RXDLY_CFG(16'h001f),
				.RXDLY_LCFG(9'h030),
				.RXDLY_TAP_CFG(16'd0),
				.RX_DDI_SEL(6'd0),
				.RXSYNC_OVRD(RXSYNC_OVRD),
				.RXSYNC_MULTILANE(RXSYNC_MULTILANE),
				.RXSYNC_SKIP_DA(1'b0),
				.ALIGN_COMMA_DOUBLE("FALSE"),
				.ALIGN_COMMA_ENABLE(10'b1111111111),
				.ALIGN_COMMA_WORD(1),
				.ALIGN_MCOMMA_DET("TRUE"),
				.ALIGN_MCOMMA_VALUE(10'b1010000011),
				.ALIGN_PCOMMA_DET("TRUE"),
				.ALIGN_PCOMMA_VALUE(10'b0101111100),
				.DEC_MCOMMA_DETECT("TRUE"),
				.DEC_PCOMMA_DETECT("TRUE"),
				.DEC_VALID_COMMA_ONLY("FALSE"),
				.SHOW_REALIGN_COMMA("FALSE"),
				.RXSLIDE_AUTO_WAIT(7),
				.RXSLIDE_MODE("PMA"),
				.CHAN_BOND_KEEP_ALIGN("TRUE"),
				.CHAN_BOND_MAX_SKEW(7),
				.CHAN_BOND_SEQ_LEN(4),
				.CHAN_BOND_SEQ_1_ENABLE(4'b1111),
				.CHAN_BOND_SEQ_1_1(10'b0001001010),
				.CHAN_BOND_SEQ_1_2(10'b0001001010),
				.CHAN_BOND_SEQ_1_3(10'b0001001010),
				.CHAN_BOND_SEQ_1_4(10'b0110111100),
				.CHAN_BOND_SEQ_2_USE("TRUE"),
				.CHAN_BOND_SEQ_2_ENABLE(4'b1111),
				.CHAN_BOND_SEQ_2_1(10'b0001000101),
				.CHAN_BOND_SEQ_2_2(10'b0001000101),
				.CHAN_BOND_SEQ_2_3(10'b0001000101),
				.CHAN_BOND_SEQ_2_4(10'b0110111100),
				.FTS_DESKEW_SEQ_ENABLE(4'b1111),
				.FTS_LANE_DESKEW_EN("TRUE"),
				.FTS_LANE_DESKEW_CFG(4'b1111),
				.CBCC_DATA_SOURCE_SEL("DECODED"),
				.CLK_CORRECT_USE("TRUE"),
				.CLK_COR_KEEP_IDLE("TRUE"),
				.CLK_COR_MAX_LAT(CLK_COR_MAX_LAT),
				.CLK_COR_MIN_LAT(CLK_COR_MIN_LAT),
				.CLK_COR_PRECEDENCE("TRUE"),
				.CLK_COR_REPEAT_WAIT(0),
				.CLK_COR_SEQ_LEN(1),
				.CLK_COR_SEQ_1_ENABLE(4'b1111),
				.CLK_COR_SEQ_1_1(10'b0100011100),
				.CLK_COR_SEQ_1_2(10'b0000000000),
				.CLK_COR_SEQ_1_3(10'b0000000000),
				.CLK_COR_SEQ_1_4(10'b0000000000),
				.CLK_COR_SEQ_2_ENABLE(4'b0000),
				.CLK_COR_SEQ_2_USE("FALSE"),
				.CLK_COR_SEQ_2_1(10'b0000000000),
				.CLK_COR_SEQ_2_2(10'b0000000000),
				.CLK_COR_SEQ_2_3(10'b0000000000),
				.CLK_COR_SEQ_2_4(10'b0000000000),
				.RX_DISPERR_SEQ_MATCH("TRUE"),
				.GEARBOX_MODE(3'd0),
				.TXGEARBOX_EN("FALSE"),
				.RXGEARBOX_EN("FALSE"),
				.LOOPBACK_CFG(1'd0),
				.RXPRBS_ERR_LOOPBACK(1'd0),
				.TX_LOOPBACK_DRIVE_HIZ("FALSE"),
				.TXOOB_CFG(1'd1),
				.RXOOB_CLK_CFG(RXOOB_CLK_CFG),
				.DMONITOR_CFG(24'h000b01),
				.RX_DEBUG_CFG(14'h0000),
				.CFOK_CFG(43'h49000040e80),
				.CFOK_CFG2(7'b0100000),
				.CFOK_CFG3(7'b0100000),
				.CFOK_CFG4(1'd0),
				.CFOK_CFG5(2'd0),
				.CFOK_CFG6(4'd0)
			) gtpe2_channel_i(
				.PLL0CLK(GT_QPLLCLK),
				.PLL1CLK(1'd0),
				.PLL0REFCLK(GT_QPLLREFCLK),
				.PLL1REFCLK(1'd0),
				.TXUSRCLK(GT_TXUSRCLK),
				.RXUSRCLK(GT_RXUSRCLK),
				.TXUSRCLK2(GT_TXUSRCLK2),
				.RXUSRCLK2(GT_RXUSRCLK2),
				.TXSYSCLKSEL(GT_TXSYSCLKSEL),
				.RXSYSCLKSEL(GT_RXSYSCLKSEL),
				.TXOUTCLKSEL(txoutclksel),
				.RXOUTCLKSEL(rxoutclksel),
				.CLKRSVD0(1'd0),
				.CLKRSVD1(1'd0),
				.TXOUTCLK(GT_TXOUTCLK),
				.RXOUTCLK(GT_RXOUTCLK),
				.TXOUTCLKFABRIC(),
				.RXOUTCLKFABRIC(),
				.TXOUTCLKPCS(),
				.RXOUTCLKPCS(),
				.RXCDRLOCK(GT_RXCDRLOCK),
				.TXUSERRDY(GT_TXUSERRDY),
				.RXUSERRDY(GT_RXUSERRDY),
				.CFGRESET(1'd0),
				.GTRESETSEL(1'd0),
				.RESETOVRD(GT_RESETOVRD),
				.GTTXRESET(GT_GTTXRESET),
				.GTRXRESET(GT_GTRXRESET),
				.TXRESETDONE(GT_TXRESETDONE),
				.RXRESETDONE(GT_RXRESETDONE),
				.TXDATA(GT_TXDATA),
				.TXCHARISK(GT_TXDATAK),
				.GTPTXP(GT_TXP),
				.GTPTXN(GT_TXN),
				.GTPRXP(GT_RXP),
				.GTPRXN(GT_RXN),
				.RXDATA(rxdata[31:0]),
				.RXCHARISK(rxdatak[3:0]),
				.TXDETECTRX(GT_TXDETECTRX),
				.TXPDELECIDLEMODE(1'd0),
				.RXELECIDLEMODE(2'd0),
				.TXELECIDLE(GT_TXELECIDLE),
				.TXCHARDISPMODE({3'd0, GT_TXCOMPLIANCE}),
				.TXCHARDISPVAL(4'd0),
				.TXPOLARITY(1'b0),
				.RXPOLARITY(GT_RXPOLARITY),
				.TXPD(GT_TXPOWERDOWN),
				.RXPD(GT_RXPOWERDOWN),
				.TXRATE(GT_TXRATE),
				.RXRATE(GT_RXRATE),
				.TXRATEMODE(1'b0),
				.RXRATEMODE(1'b0),
				.TXMARGIN(GT_TXMARGIN),
				.TXSWING(GT_TXSWING),
				.TXDEEMPH(GT_TXDEEMPH),
				.TXINHIBIT(GT_TXINHIBIT),
				.TXBUFDIFFCTRL(3'b100),
				.TXDIFFCTRL(4'b1100),
				.TXPRECURSOR(GT_TXPRECURSOR),
				.TXPRECURSORINV(1'd0),
				.TXMAINCURSOR(GT_TXMAINCURSOR),
				.TXPOSTCURSOR(GT_TXPOSTCURSOR),
				.TXPOSTCURSORINV(1'd0),
				.RXVALID(GT_RXVALID),
				.PHYSTATUS(GT_PHYSTATUS),
				.RXELECIDLE(GT_RXELECIDLE),
				.RXSTATUS(GT_RXSTATUS),
				.TXRATEDONE(GT_TXRATEDONE),
				.RXRATEDONE(GT_RXRATEDONE),
				.DRPCLK(GT_DRPCLK),
				.DRPADDR(GT_DRPADDR),
				.DRPEN(GT_DRPEN),
				.DRPDI(GT_DRPDI),
				.DRPWE(GT_DRPWE),
				.DRPDO(GT_DRPDO),
				.DRPRDY(GT_DRPRDY),
				.TXPMARESET(GT_TXPMARESET),
				.RXPMARESET(GT_RXPMARESET),
				.RXLPMRESET(1'd0),
				.RXLPMOSINTNTRLEN(1'd0),
				.RXLPMHFHOLD(1'd0),
				.RXLPMHFOVRDEN(1'd0),
				.RXLPMLFHOLD(1'd0),
				.RXLPMLFOVRDEN(1'd0),
				.PMARSVDIN0(1'd0),
				.PMARSVDIN1(1'd0),
				.PMARSVDIN2(1'd0),
				.PMARSVDIN3(1'd0),
				.PMARSVDIN4(1'd0),
				.GTRSVD(16'd0),
				.PMARSVDOUT0(),
				.PMARSVDOUT1(),
				.DMONITOROUT(dmonitorout),
				.TXPCSRESET(GT_TXPCSRESET),
				.RXPCSRESET(GT_RXPCSRESET),
				.PCSRSVDIN(16'd0),
				.PCSRSVDOUT(),
				.RXCDRRESET(GT_RXCDRRESET),
				.RXCDRRESETRSV(1'd0),
				.RXCDRFREQRESET(GT_RXCDRFREQRESET),
				.RXCDRHOLD(1'b0),
				.RXCDROVRDEN(1'd0),
				.TXPIPPMEN(1'd0),
				.TXPIPPMOVRDEN(1'd0),
				.TXPIPPMPD(1'd0),
				.TXPIPPMSEL(1'd0),
				.TXPIPPMSTEPSIZE(5'd0),
				.TXPISOPD(1'd0),
				.RXDFEXYDEN(1'd0),
				.RXOSHOLD(1'd0),
				.RXOSOVRDEN(1'd0),
				.RXOSINTEN(1'd1),
				.RXOSINTHOLD(1'd0),
				.RXOSINTNTRLEN(1'd0),
				.RXOSINTOVRDEN(1'd0),
				.RXOSINTPD(1'd0),
				.RXOSINTSTROBE(1'd0),
				.RXOSINTTESTOVRDEN(1'd0),
				.RXOSINTCFG(4'b0010),
				.RXOSINTID0(4'd0),
				.RXOSINTDONE(),
				.RXOSINTSTARTED(),
				.RXOSINTSTROBEDONE(),
				.RXOSINTSTROBESTARTED(),
				.EYESCANRESET(GT_EYESCANRESET),
				.EYESCANMODE(1'd0),
				.EYESCANTRIGGER(1'b0),
				.EYESCANDATAERROR(GT_EYESCANDATAERROR),
				.TXBUFSTATUS(),
				.RXBUFRESET(GT_RXBUFRESET),
				.RXBUFSTATUS(GT_RXBUFSTATUS),
				.TXPHDLYRESET(GT_TXPHDLYRESET),
				.TXPHDLYTSTCLK(1'd0),
				.TXPHALIGN(GT_TXPHALIGN),
				.TXPHALIGNEN(GT_TXPHALIGNEN),
				.TXPHDLYPD(1'd0),
				.TXPHINIT(GT_TXPHINIT),
				.TXPHOVRDEN(1'd0),
				.TXDLYBYPASS(GT_TXDLYBYPASS),
				.TXDLYSRESET(GT_TXDLYSRESET),
				.TXDLYEN(GT_TXDLYEN),
				.TXDLYOVRDEN(1'd0),
				.TXDLYHOLD(1'd0),
				.TXDLYUPDOWN(1'd0),
				.TXPHALIGNDONE(GT_TXPHALIGNDONE),
				.TXPHINITDONE(GT_TXPHINITDONE),
				.TXDLYSRESETDONE(GT_TXDLYSRESETDONE),
				.TXSYNCMODE(GT_TXSYNCMODE),
				.TXSYNCIN(GT_TXSYNCIN),
				.TXSYNCALLIN(GT_TXSYNCALLIN),
				.TXSYNCDONE(GT_TXSYNCDONE),
				.TXSYNCOUT(GT_TXSYNCOUT),
				.RXPHDLYRESET(1'd0),
				.RXPHALIGN(GT_RXPHALIGN),
				.RXPHALIGNEN(GT_RXPHALIGNEN),
				.RXPHDLYPD(1'd0),
				.RXPHOVRDEN(1'd0),
				.RXDLYBYPASS(GT_RXDLYBYPASS),
				.RXDLYSRESET(GT_RXDLYSRESET),
				.RXDLYEN(GT_RXDLYEN),
				.RXDLYOVRDEN(1'd0),
				.RXDDIEN(GT_RXDDIEN),
				.RXPHALIGNDONE(GT_RXPHALIGNDONE),
				.RXPHMONITOR(),
				.RXPHSLIPMONITOR(),
				.RXDLYSRESETDONE(GT_RXDLYSRESETDONE),
				.RXSYNCMODE(GT_RXSYNCMODE),
				.RXSYNCIN(GT_RXSYNCIN),
				.RXSYNCALLIN(GT_RXSYNCALLIN),
				.RXSYNCDONE(GT_RXSYNCDONE),
				.RXSYNCOUT(GT_RXSYNCOUT),
				.RXCOMMADETEN(1'd1),
				.RXMCOMMAALIGNEN(1'd1),
				.RXPCOMMAALIGNEN(1'd1),
				.RXSLIDE(GT_RXSLIDE),
				.RXCOMMADET(GT_RXCOMMADET),
				.RXCHARISCOMMA(rxchariscomma[3:0]),
				.RXBYTEISALIGNED(GT_RXBYTEISALIGNED),
				.RXBYTEREALIGN(GT_RXBYTEREALIGN),
				.RXCHBONDEN(GT_RXCHBONDEN),
				.RXCHBONDI(GT_RXCHBONDI[3:0]),
				.RXCHBONDLEVEL(GT_RXCHBONDLEVEL),
				.RXCHBONDMASTER(GT_RXCHBONDMASTER),
				.RXCHBONDSLAVE(GT_RXCHBONDSLAVE),
				.RXCHANBONDSEQ(),
				.RXCHANISALIGNED(GT_RXCHANISALIGNED),
				.RXCHANREALIGN(),
				.RXCHBONDO(GT_RXCHBONDO[3:0]),
				.RXCLKCORCNT(),
				.TX8B10BBYPASS(4'd0),
				.TX8B10BEN(1'b1),
				.RX8B10BEN(1'b1),
				.RXDISPERR(GT_RXDISPERR[3:0]),
				.RXNOTINTABLE(GT_RXNOTINTABLE[3:0]),
				.TXHEADER(3'd0),
				.TXSEQUENCE(7'd0),
				.TXSTARTSEQ(1'd0),
				.RXGEARBOXSLIP(1'd0),
				.TXGEARBOXREADY(),
				.RXDATAVALID(),
				.RXHEADER(),
				.RXHEADERVALID(),
				.RXSTARTOFSEQ(),
				.TXPRBSSEL(GT_TXPRBSSEL),
				.RXPRBSSEL(GT_RXPRBSSEL),
				.TXPRBSFORCEERR(GT_TXPRBSFORCEERR),
				.RXPRBSCNTRESET(GT_RXPRBSCNTRESET),
				.LOOPBACK(GT_LOOPBACK),
				.RXPRBSERR(GT_RXPRBSERR),
				.SIGVALIDCLK(GT_OOBCLK),
				.TXCOMINIT(1'd0),
				.TXCOMSAS(1'd0),
				.TXCOMWAKE(1'd0),
				.RXOOBRESET(1'd0),
				.TXCOMFINISH(),
				.RXCOMINITDET(),
				.RXCOMSASDET(),
				.RXCOMWAKEDET(),
				.SETERRSTATUS(1'd0),
				.TXDIFFPD(1'd0),
				.TSTIN(20'hfffff),
				.RXADAPTSELTEST(14'd0),
				.DMONFIFORESET(1'd0),
				.DMONITORCLK(dmonitorclk),
				.RXOSCALRESET(1'd0),
				.RXPMARESETDONE(GT_RXPMARESETDONE),
				.TXPMARESETDONE()
			);
			assign GT_CPLLLOCK = 1'b0;
		end
	endgenerate
	assign GT_RXDATA = rxdata[31:0];
	assign GT_RXDATAK = rxdatak[3:0];
	assign GT_RXCHARISCOMMA = rxchariscomma[3:0];
	assign GT_DMONITOROUT = dmonitorout;
endmodule
module margin_tuner (
	EQ_CLK,
	EQ_RST_N,
	EQ_GEN3,
	EQ_TXEQ_CONTROL,
	EQ_TXEQ_PRESET,
	EQ_TXEQ_PRESET_DEFAULT,
	EQ_TXEQ_DEEMPH_IN,
	EQ_RXEQ_CONTROL,
	EQ_RXEQ_PRESET,
	EQ_RXEQ_LFFS,
	EQ_RXEQ_TXPRESET,
	EQ_RXEQ_USER_EN,
	EQ_RXEQ_USER_TXCOEFF,
	EQ_RXEQ_USER_MODE,
	EQ_TXEQ_DEEMPH,
	EQ_TXEQ_PRECURSOR,
	EQ_TXEQ_MAINCURSOR,
	EQ_TXEQ_POSTCURSOR,
	EQ_TXEQ_DEEMPH_OUT,
	EQ_TXEQ_DONE,
	EQ_TXEQ_FSM,
	EQ_RXEQ_NEW_TXCOEFF,
	EQ_RXEQ_LFFS_SEL,
	EQ_RXEQ_ADAPT_DONE,
	EQ_RXEQ_DONE,
	EQ_RXEQ_FSM
);
	reg _sv2v_0;
	input EQ_CLK;
	input EQ_RST_N;
	input EQ_GEN3;
	input [1:0] EQ_TXEQ_CONTROL;
	input [3:0] EQ_TXEQ_PRESET;
	input [3:0] EQ_TXEQ_PRESET_DEFAULT;
	input [5:0] EQ_TXEQ_DEEMPH_IN;
	input [1:0] EQ_RXEQ_CONTROL;
	input [2:0] EQ_RXEQ_PRESET;
	input [5:0] EQ_RXEQ_LFFS;
	input [3:0] EQ_RXEQ_TXPRESET;
	input EQ_RXEQ_USER_EN;
	input [17:0] EQ_RXEQ_USER_TXCOEFF;
	input EQ_RXEQ_USER_MODE;
	output wire EQ_TXEQ_DEEMPH;
	output wire [4:0] EQ_TXEQ_PRECURSOR;
	output wire [6:0] EQ_TXEQ_MAINCURSOR;
	output wire [4:0] EQ_TXEQ_POSTCURSOR;
	output wire [17:0] EQ_TXEQ_DEEMPH_OUT;
	output wire EQ_TXEQ_DONE;
	output wire [5:0] EQ_TXEQ_FSM;
	output wire [17:0] EQ_RXEQ_NEW_TXCOEFF;
	output wire EQ_RXEQ_LFFS_SEL;
	output wire EQ_RXEQ_ADAPT_DONE;
	output wire EQ_RXEQ_DONE;
	output wire [5:0] EQ_RXEQ_FSM;
	function automatic [18:0] txeq_preset_lut;
		input reg [3:0] sel;
		(* full_case, parallel_case *)
		case (sel)
			4'd0: txeq_preset_lut = 19'h28f00;
			4'd1: txeq_preset_lut = 19'h1b100;
			4'd2: txeq_preset_lut = 19'h21000;
			4'd3: txeq_preset_lut = 19'h15180;
			4'd4: txeq_preset_lut = 19'h01400;
			4'd5: txeq_preset_lut = 19'h01208;
			4'd6: txeq_preset_lut = 19'h0118a;
			4'd7: txeq_preset_lut = 19'h20e08;
			4'd8: txeq_preset_lut = 19'h14f0a;
			4'd9: txeq_preset_lut = 19'h0110d;
			4'd10: txeq_preset_lut = 19'h32e00;
			default: txeq_preset_lut = 19'd4;
		endcase
	endfunction
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg gen3_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg gen3_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [1:0] txctl_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [1:0] txctl_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [3:0] txpre_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [3:0] txpre_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [5:0] txdeemph_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [5:0] txdeemph_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [1:0] rxctl_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [1:0] rxctl_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [2:0] rxpre_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [2:0] rxpre_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [5:0] rxlffs_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [5:0] rxlffs_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [3:0] rxtxpre_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [3:0] rxtxpre_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg rxuen_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg rxuen_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [17:0] rxucoeff_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [17:0] rxucoeff_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg rxumode_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg rxumode_r2;
	always @(posedge EQ_CLK)
		if (!EQ_RST_N) begin
			gen3_r1 <= 1'b0;
			gen3_r2 <= 1'b0;
			txctl_r1 <= 2'd0;
			txctl_r2 <= 2'd0;
			txpre_r1 <= 4'd0;
			txpre_r2 <= 4'd0;
			txdeemph_r1 <= 6'd1;
			txdeemph_r2 <= 6'd1;
			rxctl_r1 <= 2'd0;
			rxctl_r2 <= 2'd0;
			rxpre_r1 <= 3'd0;
			rxpre_r2 <= 3'd0;
			rxlffs_r1 <= 6'd0;
			rxlffs_r2 <= 6'd0;
			rxtxpre_r1 <= 4'd0;
			rxtxpre_r2 <= 4'd0;
			rxuen_r1 <= 1'b0;
			rxuen_r2 <= 1'b0;
			rxucoeff_r1 <= 18'd0;
			rxucoeff_r2 <= 18'd0;
			rxumode_r1 <= 1'b0;
			rxumode_r2 <= 1'b0;
		end
		else begin
			gen3_r1 <= EQ_GEN3;
			gen3_r2 <= gen3_r1;
			txctl_r1 <= EQ_TXEQ_CONTROL;
			txctl_r2 <= txctl_r1;
			txpre_r1 <= EQ_TXEQ_PRESET;
			txpre_r2 <= txpre_r1;
			txdeemph_r1 <= EQ_TXEQ_DEEMPH_IN;
			txdeemph_r2 <= txdeemph_r1;
			rxctl_r1 <= EQ_RXEQ_CONTROL;
			rxctl_r2 <= rxctl_r1;
			rxpre_r1 <= EQ_RXEQ_PRESET;
			rxpre_r2 <= rxpre_r1;
			rxlffs_r1 <= EQ_RXEQ_LFFS;
			rxlffs_r2 <= rxlffs_r1;
			rxtxpre_r1 <= EQ_RXEQ_TXPRESET;
			rxtxpre_r2 <= rxtxpre_r1;
			rxuen_r1 <= EQ_RXEQ_USER_EN;
			rxuen_r2 <= rxuen_r1;
			rxucoeff_r1 <= EQ_RXEQ_USER_TXCOEFF;
			rxucoeff_r2 <= rxucoeff_r1;
			rxumode_r1 <= EQ_RXEQ_USER_MODE;
			rxumode_r2 <= rxumode_r1;
		end
	reg [18:0] txeq_preset = 19'd0;
	reg txeq_preset_done = 1'b0;
	reg [5:0] fsm_tx = 6'b000001;
	reg [5:0] fsm_tx_nx;
	always @(posedge EQ_CLK)
		if (!EQ_RST_N) begin
			txeq_preset <= txeq_preset_lut(EQ_TXEQ_PRESET_DEFAULT);
			txeq_preset_done <= 1'b0;
		end
		else if (fsm_tx == 6'b000010) begin
			txeq_preset <= txeq_preset_lut(txpre_r2);
			txeq_preset_done <= 1'b1;
		end
		else begin
			txeq_preset <= txeq_preset;
			txeq_preset_done <= 1'b0;
		end
	reg [18:0] txeq_txcoeff = 19'd0;
	reg [18:0] txeq_txcoeff_nx;
	reg [1:0] txeq_cnt = 2'd0;
	reg [1:0] txeq_cnt_nx;
	reg txeq_done = 1'b0;
	reg txeq_done_nx;
	always @(*) begin
		if (_sv2v_0)
			;
		fsm_tx_nx = fsm_tx;
		txeq_txcoeff_nx = txeq_txcoeff;
		txeq_cnt_nx = 2'd0;
		txeq_done_nx = 1'b0;
		(* full_case, parallel_case *)
		case (fsm_tx)
			6'b000001:
				(* full_case, parallel_case *)
				case (txctl_r2)
					2'd1: fsm_tx_nx = 6'b000010;
					2'd2: begin
						fsm_tx_nx = 6'b000100;
						txeq_txcoeff_nx = {txdeemph_r2, txeq_txcoeff[18:6]};
						txeq_cnt_nx = 2'd1;
					end
					2'd3: fsm_tx_nx = 6'b010000;
					default: fsm_tx_nx = 6'b000001;
				endcase
			6'b000010: begin
				fsm_tx_nx = (txeq_preset_done ? 6'b100000 : 6'b000010);
				txeq_txcoeff_nx = txeq_preset;
			end
			6'b000100: begin
				fsm_tx_nx = (txeq_cnt == 2'd2 ? 6'b001000 : 6'b000100);
				txeq_txcoeff_nx = (txeq_cnt == 2'd1 ? {1'b0, txdeemph_r2, txeq_txcoeff[18:7]} : {txdeemph_r2, txeq_txcoeff[18:6]});
				txeq_cnt_nx = txeq_cnt + 2'd1;
			end
			6'b001000: begin
				fsm_tx_nx = 6'b100000;
				txeq_txcoeff_nx = txeq_txcoeff << 1;
			end
			6'b010000: fsm_tx_nx = 6'b100000;
			6'b100000: begin
				fsm_tx_nx = (txctl_r2 == 2'd0 ? 6'b000001 : 6'b100000);
				txeq_done_nx = 1'b1;
			end
			default: begin
				fsm_tx_nx = 6'b000001;
				txeq_txcoeff_nx = 19'd0;
			end
		endcase
	end
	always @(posedge EQ_CLK)
		if (!EQ_RST_N) begin
			fsm_tx <= 6'b000001;
			txeq_txcoeff <= 19'd0;
			txeq_cnt <= 2'd0;
			txeq_done <= 1'b0;
		end
		else begin
			fsm_tx <= fsm_tx_nx;
			txeq_txcoeff <= txeq_txcoeff_nx;
			txeq_cnt <= txeq_cnt_nx;
			txeq_done <= txeq_done_nx;
		end
	wire rxeqscan_lffs_sel;
	wire rxeqscan_preset_done;
	wire [17:0] rxeqscan_new_txcoeff;
	wire rxeqscan_new_txcoeff_done;
	wire rxeqscan_adapt_done;
	reg [5:0] fsm_rx = 6'b000001;
	reg [5:0] fsm_rx_nx;
	reg [2:0] rxeq_preset = 3'd0;
	reg [2:0] rxeq_preset_nx;
	reg rxeq_preset_valid = 1'b0;
	reg rxeq_preset_valid_nx;
	reg [3:0] rxeq_txpreset = 4'd0;
	reg [3:0] rxeq_txpreset_nx;
	reg [17:0] rxeq_txcoeff = 18'd0;
	reg [17:0] rxeq_txcoeff_nx;
	reg [2:0] rxeq_cnt = 3'd0;
	reg [2:0] rxeq_cnt_nx;
	reg [5:0] rxeq_fs = 6'd0;
	reg [5:0] rxeq_fs_nx;
	reg [5:0] rxeq_lf = 6'd0;
	reg [5:0] rxeq_lf_nx;
	reg rxeq_new_txcoeff_req = 1'b0;
	reg rxeq_new_txcoeff_req_nx;
	reg [17:0] rxeq_new_txcoeff = 18'd0;
	reg [17:0] rxeq_new_txcoeff_nx;
	reg rxeq_lffs_sel = 1'b0;
	reg rxeq_lffs_sel_nx;
	reg rxeq_adapt_done_r = 1'b0;
	reg rxeq_adapt_done_r_nx;
	reg rxeq_adapt_done = 1'b0;
	reg rxeq_adapt_done_nx;
	reg rxeq_done = 1'b0;
	reg rxeq_done_nx;
	always @(*) begin
		if (_sv2v_0)
			;
		fsm_rx_nx = fsm_rx;
		rxeq_preset_nx = rxeq_preset;
		rxeq_preset_valid_nx = 1'b0;
		rxeq_txpreset_nx = rxeq_txpreset;
		rxeq_txcoeff_nx = rxeq_txcoeff;
		rxeq_cnt_nx = 3'd0;
		rxeq_fs_nx = rxeq_fs;
		rxeq_lf_nx = rxeq_lf;
		rxeq_new_txcoeff_req_nx = 1'b0;
		rxeq_new_txcoeff_nx = rxeq_new_txcoeff;
		rxeq_lffs_sel_nx = rxeq_lffs_sel;
		rxeq_adapt_done_r_nx = rxeq_adapt_done_r;
		rxeq_adapt_done_nx = 1'b0;
		rxeq_done_nx = 1'b0;
		case (fsm_rx)
			6'b000001: begin
				rxeq_lffs_sel_nx = 1'b0;
				(* full_case, parallel_case *)
				case (rxctl_r2)
					2'd1: begin
						fsm_rx_nx = 6'b000010;
						rxeq_preset_nx = rxpre_r2;
						rxeq_adapt_done_r_nx = 1'b0;
					end
					2'd2, 2'd3: begin
						fsm_rx_nx = 6'b000100;
						rxeq_txpreset_nx = rxtxpre_r2;
						rxeq_txcoeff_nx = {txdeemph_r2, rxeq_txcoeff[17:6]};
						rxeq_cnt_nx = 3'd1;
						rxeq_fs_nx = rxlffs_r2;
					end
					default: fsm_rx_nx = 6'b000001;
				endcase
			end
			6'b000010: begin
				fsm_rx_nx = (rxeqscan_preset_done ? 6'b100000 : 6'b000010);
				rxeq_preset_nx = rxpre_r2;
				rxeq_preset_valid_nx = 1'b1;
				rxeq_lffs_sel_nx = 1'b0;
			end
			6'b000100: begin
				fsm_rx_nx = (rxeq_cnt == 3'd2 ? 6'b001000 : 6'b000100);
				rxeq_txpreset_nx = rxtxpre_r2;
				rxeq_txcoeff_nx = {txdeemph_r2, rxeq_txcoeff[17:6]};
				rxeq_cnt_nx = rxeq_cnt + 3'd1;
				rxeq_lffs_sel_nx = 1'b1;
			end
			6'b001000: begin
				fsm_rx_nx = (rxeq_cnt == 3'd7 ? 6'b010000 : 6'b001000);
				rxeq_cnt_nx = rxeq_cnt + 3'd1;
				rxeq_lf_nx = (rxeq_cnt == 3'd7 ? rxlffs_r2 : rxeq_lf);
				rxeq_lffs_sel_nx = 1'b1;
			end
			6'b010000:
				if (rxeqscan_new_txcoeff_done) begin
					fsm_rx_nx = 6'b100000;
					rxeq_new_txcoeff_nx = (rxeqscan_lffs_sel ? {14'd0, rxeqscan_new_txcoeff[3:0]} : rxeqscan_new_txcoeff);
					rxeq_lffs_sel_nx = rxeqscan_lffs_sel;
					rxeq_adapt_done_r_nx = rxeqscan_adapt_done || rxeq_adapt_done_r;
					rxeq_adapt_done_nx = rxeqscan_adapt_done || rxeq_adapt_done_r;
					rxeq_done_nx = 1'b1;
				end
				else begin
					fsm_rx_nx = 6'b010000;
					rxeq_new_txcoeff_req_nx = 1'b1;
					rxeq_lffs_sel_nx = 1'b0;
				end
			6'b100000: begin
				fsm_rx_nx = (rxctl_r2 == 2'd0 ? 6'b000001 : 6'b100000);
				rxeq_adapt_done_nx = rxeq_adapt_done;
				rxeq_done_nx = 1'b1;
			end
			default: begin
				fsm_rx_nx = 6'b000001;
				rxeq_preset_nx = 3'd0;
				rxeq_txpreset_nx = 4'd0;
				rxeq_txcoeff_nx = 18'd0;
				rxeq_fs_nx = 6'd0;
				rxeq_lf_nx = 6'd0;
				rxeq_new_txcoeff_nx = 18'd0;
				rxeq_lffs_sel_nx = 1'b0;
				rxeq_adapt_done_r_nx = 1'b0;
			end
		endcase
	end
	always @(posedge EQ_CLK)
		if (!EQ_RST_N) begin
			fsm_rx <= 6'b000001;
			rxeq_preset <= 3'd0;
			rxeq_preset_valid <= 1'b0;
			rxeq_txpreset <= 4'd0;
			rxeq_txcoeff <= 18'd0;
			rxeq_cnt <= 3'd0;
			rxeq_fs <= 6'd0;
			rxeq_lf <= 6'd0;
			rxeq_new_txcoeff_req <= 1'b0;
			rxeq_new_txcoeff <= 18'd0;
			rxeq_lffs_sel <= 1'b0;
			rxeq_adapt_done_r <= 1'b0;
			rxeq_adapt_done <= 1'b0;
			rxeq_done <= 1'b0;
		end
		else begin
			fsm_rx <= fsm_rx_nx;
			rxeq_preset <= rxeq_preset_nx;
			rxeq_preset_valid <= rxeq_preset_valid_nx;
			rxeq_txpreset <= rxeq_txpreset_nx;
			rxeq_txcoeff <= rxeq_txcoeff_nx;
			rxeq_cnt <= rxeq_cnt_nx;
			rxeq_fs <= rxeq_fs_nx;
			rxeq_lf <= rxeq_lf_nx;
			rxeq_new_txcoeff_req <= rxeq_new_txcoeff_req_nx;
			rxeq_new_txcoeff <= rxeq_new_txcoeff_nx;
			rxeq_lffs_sel <= rxeq_lffs_sel_nx;
			rxeq_adapt_done_r <= rxeq_adapt_done_r_nx;
			rxeq_adapt_done <= rxeq_adapt_done_nx;
			rxeq_done <= rxeq_done_nx;
		end
	signal_probe signal_probe_i(
		.RXEQSCAN_CLK(EQ_CLK),
		.RXEQSCAN_RST_N(EQ_RST_N),
		.RXEQSCAN_CONTROL(rxctl_r2),
		.RXEQSCAN_FS(rxeq_fs),
		.RXEQSCAN_LF(rxeq_lf),
		.RXEQSCAN_PRESET(rxeq_preset),
		.RXEQSCAN_PRESET_VALID(rxeq_preset_valid),
		.RXEQSCAN_TXPRESET(rxeq_txpreset),
		.RXEQSCAN_TXCOEFF(rxeq_txcoeff),
		.RXEQSCAN_NEW_TXCOEFF_REQ(rxeq_new_txcoeff_req),
		.RXEQSCAN_PRESET_DONE(rxeqscan_preset_done),
		.RXEQSCAN_NEW_TXCOEFF(rxeqscan_new_txcoeff),
		.RXEQSCAN_NEW_TXCOEFF_DONE(rxeqscan_new_txcoeff_done),
		.RXEQSCAN_LFFS_SEL(rxeqscan_lffs_sel),
		.RXEQSCAN_ADAPT_DONE(rxeqscan_adapt_done)
	);
	assign EQ_TXEQ_DEEMPH = txeq_txcoeff[0];
	assign EQ_TXEQ_PRECURSOR = (gen3_r2 ? txeq_txcoeff[4:0] : 5'h00);
	assign EQ_TXEQ_MAINCURSOR = (gen3_r2 ? txeq_txcoeff[12:6] : 7'h00);
	assign EQ_TXEQ_POSTCURSOR = (gen3_r2 ? txeq_txcoeff[17:13] : 5'h00);
	assign EQ_TXEQ_DEEMPH_OUT = {1'b0, txeq_txcoeff[18:14], txeq_txcoeff[12:7], 1'b0, txeq_txcoeff[5:1]};
	assign EQ_TXEQ_DONE = txeq_done;
	assign EQ_TXEQ_FSM = fsm_tx;
	assign EQ_RXEQ_NEW_TXCOEFF = (rxuen_r2 ? rxucoeff_r2 : rxeq_new_txcoeff);
	assign EQ_RXEQ_LFFS_SEL = (rxuen_r2 ? rxumode_r2 : rxeq_lffs_sel);
	assign EQ_RXEQ_ADAPT_DONE = rxeq_adapt_done;
	assign EQ_RXEQ_DONE = rxeq_done;
	assign EQ_RXEQ_FSM = fsm_rx;
	initial _sv2v_0 = 0;
endmodule
module phase_align (
	SYNC_CLK,
	SYNC_RST_N,
	SYNC_SLAVE,
	SYNC_GEN3,
	SYNC_RATE_IDLE,
	SYNC_MMCM_LOCK,
	SYNC_RXELECIDLE,
	SYNC_RXCDRLOCK,
	SYNC_ACTIVE_LANE,
	SYNC_TXSYNC_START,
	SYNC_TXPHINITDONE,
	SYNC_TXDLYSRESETDONE,
	SYNC_TXPHALIGNDONE,
	SYNC_TXSYNCDONE,
	SYNC_RXSYNC_START,
	SYNC_RXDLYSRESETDONE,
	SYNC_RXPHALIGNDONE_M,
	SYNC_RXPHALIGNDONE_S,
	SYNC_RXSYNC_DONEM_IN,
	SYNC_RXSYNCDONE,
	SYNC_TXPHDLYRESET,
	SYNC_TXPHALIGN,
	SYNC_TXPHALIGNEN,
	SYNC_TXPHINIT,
	SYNC_TXDLYBYPASS,
	SYNC_TXDLYSRESET,
	SYNC_TXDLYEN,
	SYNC_TXSYNC_DONE,
	SYNC_FSM_TX,
	SYNC_RXPHALIGN,
	SYNC_RXPHALIGNEN,
	SYNC_RXDLYBYPASS,
	SYNC_RXDLYSRESET,
	SYNC_RXDLYEN,
	SYNC_RXDDIEN,
	SYNC_RXSYNC_DONEM_OUT,
	SYNC_RXSYNC_DONE,
	SYNC_FSM_RX
);
	reg _sv2v_0;
	input SYNC_CLK;
	input SYNC_RST_N;
	input SYNC_SLAVE;
	input SYNC_GEN3;
	input SYNC_RATE_IDLE;
	input SYNC_MMCM_LOCK;
	input SYNC_RXELECIDLE;
	input SYNC_RXCDRLOCK;
	input SYNC_ACTIVE_LANE;
	input SYNC_TXSYNC_START;
	input SYNC_TXPHINITDONE;
	input SYNC_TXDLYSRESETDONE;
	input SYNC_TXPHALIGNDONE;
	input SYNC_TXSYNCDONE;
	input SYNC_RXSYNC_START;
	input SYNC_RXDLYSRESETDONE;
	input SYNC_RXPHALIGNDONE_M;
	input SYNC_RXPHALIGNDONE_S;
	input SYNC_RXSYNC_DONEM_IN;
	input SYNC_RXSYNCDONE;
	output wire SYNC_TXPHDLYRESET;
	output wire SYNC_TXPHALIGN;
	output wire SYNC_TXPHALIGNEN;
	output wire SYNC_TXPHINIT;
	output wire SYNC_TXDLYBYPASS;
	output wire SYNC_TXDLYSRESET;
	output wire SYNC_TXDLYEN;
	output wire SYNC_TXSYNC_DONE;
	output wire [5:0] SYNC_FSM_TX;
	output wire SYNC_RXPHALIGN;
	output wire SYNC_RXPHALIGNEN;
	output wire SYNC_RXDLYBYPASS;
	output wire SYNC_RXDLYSRESET;
	output wire SYNC_RXDLYEN;
	output wire SYNC_RXDDIEN;
	output wire SYNC_RXSYNC_DONEM_OUT;
	output wire SYNC_RXSYNC_DONE;
	output wire [6:0] SYNC_FSM_RX;
	reg [5:0] fsm_tx = 6'b000001;
	reg [5:0] fsm_tx_nx;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg mmcm_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg mmcm_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txstart_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txstart_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txphinit_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txphinit_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txphinit_r3;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txdlyrst_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txdlyrst_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txdlyrst_r3;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txphalign_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txphalign_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txphalign_r3;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txsyncdone_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txsyncdone_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txsyncdone_r3;
	always @(posedge SYNC_CLK)
		if (!SYNC_RST_N) begin
			mmcm_r1 <= 1'b0;
			mmcm_r2 <= 1'b0;
			txstart_r1 <= 1'b0;
			txstart_r2 <= 1'b0;
			txphinit_r1 <= 1'b0;
			txphinit_r2 <= 1'b0;
			txphinit_r3 <= 1'b0;
			txdlyrst_r1 <= 1'b0;
			txdlyrst_r2 <= 1'b0;
			txdlyrst_r3 <= 1'b0;
			txphalign_r1 <= 1'b0;
			txphalign_r2 <= 1'b0;
			txphalign_r3 <= 1'b0;
			txsyncdone_r1 <= 1'b0;
			txsyncdone_r2 <= 1'b0;
			txsyncdone_r3 <= 1'b0;
		end
		else begin
			mmcm_r1 <= SYNC_MMCM_LOCK;
			mmcm_r2 <= mmcm_r1;
			txstart_r1 <= SYNC_TXSYNC_START;
			txstart_r2 <= txstart_r1;
			txphinit_r1 <= SYNC_TXPHINITDONE;
			txphinit_r2 <= txphinit_r1;
			txphinit_r3 <= txphinit_r2;
			txdlyrst_r1 <= SYNC_TXDLYSRESETDONE;
			txdlyrst_r2 <= txdlyrst_r1;
			txdlyrst_r3 <= txdlyrst_r2;
			txphalign_r1 <= SYNC_TXPHALIGNDONE;
			txphalign_r2 <= txphalign_r1;
			txphalign_r3 <= txphalign_r2;
			txsyncdone_r1 <= SYNC_TXSYNCDONE;
			txsyncdone_r2 <= txsyncdone_r1;
			txsyncdone_r3 <= txsyncdone_r2;
		end
	wire dlyrst_done_edge = !txdlyrst_r3 && txdlyrst_r2;
	wire phinit_done_edge = !txphinit_r3 && txphinit_r2;
	wire phalign_done_edge = !txphalign_r3 && txphalign_r2;
	reg txdlyen = 1'b0;
	reg txdlyen_nx;
	reg txsync_done = 1'b0;
	reg txsync_done_nx;
	always @(*) begin
		if (_sv2v_0)
			;
		fsm_tx_nx = fsm_tx;
		txdlyen_nx = txdlyen;
		txsync_done_nx = txsync_done;
		(* full_case, parallel_case *)
		case (fsm_tx)
			6'b000001:
				if (txstart_r2) begin
					fsm_tx_nx = 6'b000010;
					txdlyen_nx = 1'b0;
					txsync_done_nx = 1'b0;
				end
			6'b000010: begin
				fsm_tx_nx = (mmcm_r2 ? 6'b000100 : 6'b000010);
				txdlyen_nx = 1'b0;
				txsync_done_nx = 1'b0;
			end
			6'b000100: begin
				fsm_tx_nx = (dlyrst_done_edge ? 6'b001000 : 6'b000100);
				txdlyen_nx = 1'b0;
				txsync_done_nx = 1'b0;
			end
			6'b001000: begin
				fsm_tx_nx = (phinit_done_edge || !SYNC_ACTIVE_LANE ? 6'b010000 : 6'b001000);
				txdlyen_nx = 1'b0;
				txsync_done_nx = 1'b0;
			end
			6'b010000: begin
				fsm_tx_nx = (phalign_done_edge || !SYNC_ACTIVE_LANE ? 6'b100000 : 6'b010000);
				txdlyen_nx = 1'b0;
				txsync_done_nx = 1'b0;
			end
			6'b100000:
				if ((phalign_done_edge || !SYNC_ACTIVE_LANE) || SYNC_SLAVE) begin
					fsm_tx_nx = 6'b000001;
					txdlyen_nx = !SYNC_SLAVE;
					txsync_done_nx = 1'b1;
				end
				else begin
					fsm_tx_nx = 6'b100000;
					txdlyen_nx = !SYNC_SLAVE;
					txsync_done_nx = 1'b0;
				end
			default: begin
				fsm_tx_nx = 6'b000001;
				txdlyen_nx = 1'b0;
				txsync_done_nx = 1'b0;
			end
		endcase
	end
	always @(posedge SYNC_CLK)
		if (!SYNC_RST_N) begin
			fsm_tx <= 6'b000001;
			txdlyen <= 1'b0;
			txsync_done <= 1'b0;
		end
		else begin
			fsm_tx <= fsm_tx_nx;
			txdlyen <= txdlyen_nx;
			txsync_done <= txsync_done_nx;
		end
	assign SYNC_TXPHALIGNEN = 1'b1;
	assign SYNC_TXDLYBYPASS = 1'b0;
	assign SYNC_TXDLYSRESET = fsm_tx == 6'b000100;
	assign SYNC_TXPHDLYRESET = 1'b0;
	assign SYNC_TXPHINIT = fsm_tx == 6'b001000;
	assign SYNC_TXPHALIGN = fsm_tx == 6'b010000;
	assign SYNC_TXDLYEN = txdlyen;
	assign SYNC_TXSYNC_DONE = txsync_done;
	assign SYNC_FSM_TX = fsm_tx;
	assign SYNC_RXPHALIGNEN = 1'b0;
	assign SYNC_RXDLYBYPASS = 1'b1;
	assign SYNC_RXDLYSRESET = 1'b0;
	assign SYNC_RXPHALIGN = 1'b0;
	assign SYNC_RXDLYEN = 1'b0;
	assign SYNC_RXDDIEN = 1'b0;
	assign SYNC_RXSYNC_DONE = 1'b0;
	assign SYNC_RXSYNC_DONEM_OUT = 1'b0;
	assign SYNC_FSM_RX = 7'b0000001;
	initial _sv2v_0 = 0;
endmodule
module pll_bank (
	QPLL_CPLLPDREFCLK,
	QPLL_GTGREFCLK,
	QPLL_QPLLLOCKDETCLK,
	QPLL_QPLLOUTCLK,
	QPLL_QPLLOUTREFCLK,
	QPLL_QPLLLOCK,
	QPLL_QPLLPD,
	QPLL_QPLLRESET,
	QPLL_DRPCLK,
	QPLL_DRPADDR,
	QPLL_DRPEN,
	QPLL_DRPDI,
	QPLL_DRPWE,
	QPLL_DRPDO,
	QPLL_DRPRDY
);
	localparam PCIE_GT_DEVICE = "GTP";
	localparam PCIE_USE_MODE = "1.0";
	localparam PCIE_PLL_SEL = "CPLL";
	localparam PCIE_REFCLK_FREQ = 0;
	input QPLL_CPLLPDREFCLK;
	input QPLL_GTGREFCLK;
	input QPLL_QPLLLOCKDETCLK;
	output wire QPLL_QPLLOUTCLK;
	output wire QPLL_QPLLOUTREFCLK;
	output wire QPLL_QPLLLOCK;
	input QPLL_QPLLPD;
	input QPLL_QPLLRESET;
	input QPLL_DRPCLK;
	input [7:0] QPLL_DRPADDR;
	input QPLL_DRPEN;
	input [15:0] QPLL_DRPDI;
	input QPLL_DRPWE;
	output wire [15:0] QPLL_DRPDO;
	output wire QPLL_DRPRDY;
	localparam GTP_QPLL_FBDIV = 3'd5;
	localparam BIAS_CFG = 64'h0000042000001000;
	wire cpllpd;
	wire cpllrst;
	generate
		if (PCIE_GT_DEVICE == "GTP") begin : hm_cmn
			GTPE2_COMMON #(
				.SIM_PLL0REFCLK_SEL(3'b001),
				.SIM_PLL1REFCLK_SEL(3'b001),
				.SIM_RESET_SPEEDUP("FALSE"),
				.SIM_VERSION(PCIE_USE_MODE),
				.PLL0_CFG(27'h01f024c),
				.PLL1_CFG(27'h01f024c),
				.PLL_CLKOUT_CFG(8'd0),
				.PLL0_DMON_CFG(1'b0),
				.PLL1_DMON_CFG(1'b0),
				.PLL0_FBDIV(GTP_QPLL_FBDIV),
				.PLL1_FBDIV(GTP_QPLL_FBDIV),
				.PLL0_FBDIV_45(5),
				.PLL1_FBDIV_45(5),
				.PLL0_INIT_CFG(24'h00001e),
				.PLL1_INIT_CFG(24'h00001e),
				.PLL0_LOCK_CFG(9'h1e8),
				.PLL1_LOCK_CFG(9'h1e8),
				.PLL0_REFCLK_DIV(1),
				.PLL1_REFCLK_DIV(1),
				.BIAS_CFG(64'h0000000000050001),
				.RSVD_ATTR0(16'd0),
				.RSVD_ATTR1(16'd0)
			) gtpe2_common_i(
				.GTGREFCLK0(),
				.GTGREFCLK1(),
				.GTREFCLK0(QPLL_GTGREFCLK),
				.GTREFCLK1(),
				.GTEASTREFCLK0(),
				.GTEASTREFCLK1(),
				.GTWESTREFCLK0(),
				.GTWESTREFCLK1(),
				.PLL0LOCKDETCLK(QPLL_QPLLLOCKDETCLK),
				.PLL1LOCKDETCLK(QPLL_QPLLLOCKDETCLK),
				.PLL0LOCKEN(1'd1),
				.PLL1LOCKEN(1'd1),
				.PLL0REFCLKSEL(3'd1),
				.PLL1REFCLKSEL(3'd1),
				.PLLRSVD1(16'd0),
				.PLLRSVD2(5'd0),
				.PLL0OUTCLK(QPLL_QPLLOUTCLK),
				.PLL1OUTCLK(),
				.PLL0OUTREFCLK(QPLL_QPLLOUTREFCLK),
				.PLL1OUTREFCLK(),
				.PLL0LOCK(QPLL_QPLLLOCK),
				.PLL1LOCK(),
				.PLL0FBCLKLOST(),
				.PLL1FBCLKLOST(),
				.PLL0REFCLKLOST(),
				.PLL1REFCLKLOST(),
				.DMONITOROUT(),
				.PLL0PD(cpllpd | QPLL_QPLLPD),
				.PLL1PD(1'd1),
				.PLL0RESET(cpllrst | QPLL_QPLLRESET),
				.PLL1RESET(1'd1),
				.DRPCLK(QPLL_DRPCLK),
				.DRPADDR(QPLL_DRPADDR),
				.DRPEN(QPLL_DRPEN),
				.DRPDI(QPLL_DRPDI),
				.DRPWE(QPLL_DRPWE),
				.DRPDO(QPLL_DRPDO),
				.DRPRDY(QPLL_DRPRDY),
				.BGBYPASSB(1'd1),
				.BGMONITORENB(1'd1),
				.BGPDB(1'd1),
				.BGRCALOVRD(5'd31),
				.BGRCALOVRDENB(1'd1),
				.PMARSVD(8'd0),
				.RCALENB(1'd1),
				.REFCLKOUTMONITOR0(),
				.REFCLKOUTMONITOR1(),
				.PMARSVDOUT()
			);
		end
	endgenerate
	wake_timer wake_timer_i(
		.i_ibufds_gte2(QPLL_CPLLPDREFCLK),
		.o_cpllpd_ovrd(cpllpd),
		.o_cpllreset_ovrd(cpllrst)
	);
endmodule
module pll_init_ctrl (
	QRST_CLK,
	QRST_RST_N,
	QRST_MMCM_LOCK,
	QRST_CPLLLOCK,
	QRST_DRP_DONE,
	QRST_QPLLLOCK,
	QRST_RATE,
	QRST_QPLLRESET_IN,
	QRST_QPLLPD_IN,
	QRST_OVRD,
	QRST_DRP_START,
	QRST_QPLLRESET_OUT,
	QRST_QPLLPD_OUT,
	QRST_IDLE,
	QRST_FSM
);
	reg _sv2v_0;
	localparam PCIE_PLL_SEL = "CPLL";
	localparam PCIE_POWER_SAVING = "TRUE";
	localparam BYPASS_COARSE_OVRD = 1;
	input QRST_CLK;
	input QRST_RST_N;
	input QRST_MMCM_LOCK;
	localparam signed [31:0] link_pkg_PCIE_LANES = 1;
	input [0:0] QRST_CPLLLOCK;
	input [0:0] QRST_DRP_DONE;
	input [0:0] QRST_QPLLLOCK;
	input [1:0] QRST_RATE;
	input [0:0] QRST_QPLLRESET_IN;
	input [0:0] QRST_QPLLPD_IN;
	output wire QRST_OVRD;
	output wire QRST_DRP_START;
	output wire QRST_QPLLRESET_OUT;
	output wire QRST_QPLLPD_OUT;
	output wire QRST_IDLE;
	output wire [3:0] QRST_FSM;
	localparam [0:0] PLL_IS_QPLL = PCIE_PLL_SEL == "QPLL";
	localparam [0:0] PLL_IS_CPLL = PCIE_PLL_SEL == "CPLL";
	reg [3:0] state = 4'd2;
	reg [3:0] state_nx;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg mmcm_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg mmcm_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] cplllock_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] cplllock_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] drp_done_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] drp_done_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] qplllock_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] qplllock_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [1:0] rate_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [1:0] rate_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] qpllrst_in_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] qpllrst_in_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] qpllpd_in_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [0:0] qpllpd_in_r2;
	always @(posedge QRST_CLK)
		if (!QRST_RST_N) begin
			mmcm_r1 <= 1'b0;
			mmcm_r2 <= 1'b0;
			cplllock_r1 <= {link_pkg_PCIE_LANES {1'b1}};
			cplllock_r2 <= {link_pkg_PCIE_LANES {1'b1}};
			drp_done_r1 <= 1'sb0;
			drp_done_r2 <= 1'sb0;
			qplllock_r1 <= 1'sb0;
			qplllock_r2 <= 1'sb0;
			rate_r1 <= 2'd0;
			rate_r2 <= 2'd0;
			qpllrst_in_r1 <= {link_pkg_PCIE_LANES {1'b1}};
			qpllrst_in_r2 <= {link_pkg_PCIE_LANES {1'b1}};
			qpllpd_in_r1 <= 1'sb0;
			qpllpd_in_r2 <= 1'sb0;
		end
		else begin
			mmcm_r1 <= QRST_MMCM_LOCK;
			mmcm_r2 <= mmcm_r1;
			cplllock_r1 <= QRST_CPLLLOCK;
			cplllock_r2 <= cplllock_r1;
			drp_done_r1 <= QRST_DRP_DONE;
			drp_done_r2 <= drp_done_r1;
			qplllock_r1 <= QRST_QPLLLOCK;
			qplllock_r2 <= qplllock_r1;
			rate_r1 <= QRST_RATE;
			rate_r2 <= rate_r1;
			qpllrst_in_r1 <= QRST_QPLLRESET_IN;
			qpllrst_in_r2 <= qpllrst_in_r1;
			qpllpd_in_r1 <= QRST_QPLLPD_IN;
			qpllpd_in_r2 <= qpllpd_in_r1;
		end
	wire locks_lost = &(~cplllock_r2) && &(~qplllock_r2);
	wire mmcm_cpll = mmcm_r2 && &cplllock_r2;
	wire drp_busy = &(~drp_done_r2);
	wire drp_ready = &drp_done_r2;
	wire qpll_locked = &qplllock_r2;
	wire qpll_unlock = &(~qplllock_r2);
	wire cpll_hold = PLL_IS_CPLL && (rate_r2 != 2'd2);
	reg ovrd = 1'b0;
	reg ovrd_nx;
	reg qpllreset = 1'b1;
	reg qpllreset_nx;
	reg qpllpd = 1'b0;
	reg qpllpd_nx;
	always @(*) begin
		if (_sv2v_0)
			;
		state_nx = state;
		ovrd_nx = ovrd;
		qpllreset_nx = qpllreset;
		qpllpd_nx = qpllpd;
		(* full_case, parallel_case *)
		case (state)
			4'd1: begin
				state_nx = 4'd1;
				qpllreset_nx = &qpllrst_in_r2;
				qpllpd_nx = &qpllpd_in_r2;
			end
			4'd2: state_nx = (locks_lost ? 4'd3 : 4'd2);
			4'd3: state_nx = (mmcm_cpll ? 4'd4 : 4'd3);
			4'd4: state_nx = (drp_busy ? 4'd5 : 4'd4);
			4'd5: state_nx = (drp_ready ? 4'd6 : 4'd5);
			4'd6: begin
				state_nx = (qpll_locked ? 4'd11 : 4'd6);
				qpllreset_nx = 1'b0;
			end
			4'd7: begin
				state_nx = (drp_busy ? 4'd8 : 4'd7);
				ovrd_nx = 1'b1;
			end
			4'd8:
				if (drp_ready) begin
					state_nx = (PLL_IS_QPLL ? 4'd9 : 4'd11);
					qpllreset_nx = PLL_IS_QPLL;
				end
				else
					state_nx = 4'd8;
			4'd9: begin
				state_nx = (qpll_unlock ? 4'd10 : 4'd9);
				qpllreset_nx = 1'b1;
				qpllpd_nx = 1'b0;
			end
			4'd10: begin
				state_nx = (qpll_locked ? 4'd1 : 4'd10);
				qpllreset_nx = 1'b0;
				qpllpd_nx = 1'b0;
			end
			4'd11: begin
				state_nx = 4'd12;
				qpllreset_nx = cpll_hold;
			end
			4'd12: begin
				state_nx = 4'd1;
				qpllpd_nx = cpll_hold;
			end
			default: begin
				state_nx = 4'd2;
				ovrd_nx = 1'b0;
				qpllreset_nx = 1'b0;
				qpllpd_nx = 1'b0;
			end
		endcase
	end
	always @(posedge QRST_CLK)
		if (!QRST_RST_N) begin
			state <= 4'd2;
			ovrd <= 1'b0;
			qpllreset <= 1'b1;
			qpllpd <= 1'b0;
		end
		else begin
			state <= state_nx;
			ovrd <= ovrd_nx;
			qpllreset <= qpllreset_nx;
			qpllpd <= qpllpd_nx;
		end
	assign QRST_OVRD = ovrd;
	assign QRST_DRP_START = (state == 4'd4) || (state == 4'd7);
	assign QRST_QPLLRESET_OUT = qpllreset;
	assign QRST_QPLLPD_OUT = qpllpd;
	assign QRST_IDLE = state == 4'd1;
	assign QRST_FSM = state;
	initial _sv2v_0 = 0;
endmodule
module pll_retune (
	DRP_CLK,
	DRP_RST_N,
	DRP_OVRD,
	DRP_GEN3,
	DRP_QPLLLOCK,
	DRP_START,
	DRP_DO,
	DRP_RDY,
	DRP_ADDR,
	DRP_EN,
	DRP_DI,
	DRP_WE,
	DRP_DONE,
	DRP_QPLLRESET,
	DRP_CRSCODE,
	DRP_FSM
);
	reg _sv2v_0;
	localparam PCIE_GT_DEVICE = "GTP";
	localparam PCIE_PLL_SEL = "CPLL";
	localparam PCIE_REFCLK_FREQ = 0;
	localparam LOAD_CNT_MAX = 2'd3;
	localparam INDEX_MAX = 3'd6;
	input DRP_CLK;
	input DRP_RST_N;
	input DRP_OVRD;
	input DRP_GEN3;
	input DRP_QPLLLOCK;
	input DRP_START;
	input [15:0] DRP_DO;
	input DRP_RDY;
	output wire [7:0] DRP_ADDR;
	output wire DRP_EN;
	output wire [15:0] DRP_DI;
	output wire DRP_WE;
	output wire DRP_DONE;
	output wire DRP_QPLLRESET;
	output wire [5:0] DRP_CRSCODE;
	output wire [8:0] DRP_FSM;
	localparam [7:0] ADDR_FBDIV = 8'h36;
	localparam [7:0] ADDR_CFG = 8'h32;
	localparam [7:0] ADDR_LPF = 8'h31;
	localparam [7:0] ADDR_CRSCODE = 8'h88;
	localparam [7:0] ADDR_CFO = 8'h35;
	localparam [7:0] ADDR_CFO_EN = 8'h36;
	localparam [7:0] ADDR_LOCK_CFG = 8'h34;
	localparam [15:0] MASK_FBDIV = 16'b1111110000000000;
	localparam [15:0] MASK_CFG = 16'b1111111110111111;
	localparam [15:0] MASK_LPF = 16'b1000011111111111;
	localparam [15:0] MASK_CFO = 16'b0000001111111111;
	localparam [15:0] MASK_CFO_EN = 16'b1111011111111111;
	localparam [15:0] MASK_LOCK_CFG = 16'b1110011111111111;
	localparam [15:0] NORM_CFO = 16'b0000000000000000;
	localparam [15:0] NORM_CFO_EN = 16'b0000000000000000;
	localparam [15:0] NORM_LOCK_CFG = 16'b0000000000000000;
	localparam [15:0] OVRD_CFO_EN = 16'b0000100000000000;
	localparam [15:0] OVRD_LOCK_CFG = 16'b0000000000000000;
	localparam [15:0] QPLL_FBDIV = 16'b0000000100100000;
	localparam [15:0] GEN12_FBDIV = 16'b0000000101110000;
	localparam [15:0] GEN3_FBDIV = 16'b0000000100100000;
	localparam [15:0] GEN12_CFG = 16'b0000000001000000;
	localparam [15:0] GEN3_CFG = 16'b0000000001000000;
	localparam [15:0] GEN12_LPF = 16'b0110100000000000;
	localparam [15:0] GEN3_LPF = 16'b0110100000000000;
	reg [8:0] state = 9'b000000001;
	reg [8:0] state_nx;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg ovrd_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg ovrd_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg gen3_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg gen3_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg qlock_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg qlock_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg start_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg start_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [15:0] do_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [15:0] do_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg rdy_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg rdy_r2;
	always @(posedge DRP_CLK)
		if (!DRP_RST_N) begin
			ovrd_r1 <= 1'b0;
			gen3_r1 <= 1'b0;
			qlock_r1 <= 1'b0;
			start_r1 <= 1'b0;
			do_r1 <= 16'd0;
			rdy_r1 <= 1'b0;
			ovrd_r2 <= 1'b0;
			gen3_r2 <= 1'b0;
			qlock_r2 <= 1'b0;
			start_r2 <= 1'b0;
			do_r2 <= 16'd0;
			rdy_r2 <= 1'b0;
		end
		else begin
			ovrd_r1 <= DRP_OVRD;
			ovrd_r2 <= ovrd_r1;
			gen3_r1 <= DRP_GEN3;
			gen3_r2 <= gen3_r1;
			qlock_r1 <= DRP_QPLLLOCK;
			qlock_r2 <= qlock_r1;
			start_r1 <= DRP_START;
			start_r2 <= start_r1;
			do_r1 <= DRP_DO;
			do_r2 <= do_r1;
			rdy_r1 <= DRP_RDY;
			rdy_r2 <= rdy_r1;
		end
	wire [15:0] data_fbdiv = (gen3_r2 ? GEN3_FBDIV : GEN12_FBDIV);
	wire [15:0] data_cfg = (gen3_r2 ? GEN3_CFG : GEN12_CFG);
	wire [15:0] data_lpf = (gen3_r2 ? GEN3_LPF : GEN12_LPF);
	wire [15:0] data_cfo_en = (ovrd_r2 ? OVRD_CFO_EN : NORM_CFO_EN);
	wire [15:0] data_lock = (ovrd_r2 ? OVRD_LOCK_CFG : NORM_LOCK_CFG);
	reg [1:0] load_cnt = 2'd0;
	always @(posedge DRP_CLK)
		if (!DRP_RST_N)
			load_cnt <= 2'd0;
		else if (state != 9'b000000010)
			load_cnt <= 2'd0;
		else if (load_cnt < LOAD_CNT_MAX)
			load_cnt <= load_cnt + 2'd1;
	wire load_done = load_cnt == LOAD_CNT_MAX;
	reg [2:0] index = 3'd0;
	reg [2:0] index_nx;
	reg mode = 1'b0;
	reg mode_nx;
	reg [7:0] addr = 8'd0;
	reg [15:0] di = 16'd0;
	reg [5:0] crscode = 6'd0;
	always @(posedge DRP_CLK)
		if (!DRP_RST_N) begin
			addr <= 8'd0;
			di <= 16'd0;
			crscode <= 6'd0;
		end
		else
			case (index)
				3'd0: begin
					addr <= ADDR_FBDIV;
					di <= (do_r2 & MASK_FBDIV) | (mode ? data_fbdiv : QPLL_FBDIV);
				end
				3'd1: begin
					addr <= ADDR_CFG;
					di <= (do_r2 & 16'hffff) | data_cfg;
				end
				3'd2: begin
					addr <= ADDR_LPF;
					di <= (do_r2 & 16'hffff) | data_lpf;
				end
				3'd3: begin
					addr <= ADDR_CRSCODE;
					di <= do_r2;
					if (ovrd_r2)
						crscode <= do_r2[6:1];
				end
				3'd4: begin
					addr <= ADDR_CFO;
					di <= (do_r2 & MASK_CFO) | {crscode - 6'd1, NORM_CFO[9:0]};
				end
				3'd5: begin
					addr <= ADDR_CFO_EN;
					di <= (do_r2 & MASK_CFO_EN) | data_cfo_en;
				end
				3'd6: begin
					addr <= ADDR_LOCK_CFG;
					di <= (do_r2 & MASK_LOCK_CFG) | data_lock;
				end
				default: begin
					addr <= 8'd0;
					di <= 16'd0;
					crscode <= 6'd0;
				end
			endcase
	reg done = 1'b0;
	reg done_nx;
	always @(*) begin
		if (_sv2v_0)
			;
		state_nx = state;
		index_nx = index;
		mode_nx = mode;
		done_nx = done;
		(* full_case, parallel_case *)
		case (state)
			9'b000000001:
				if (start_r2) begin
					state_nx = 9'b000000010;
					index_nx = 3'd0;
					mode_nx = 1'b0;
					done_nx = 1'b0;
				end
				else if ((gen3_r2 != gen3_r1) && (PCIE_PLL_SEL == "QPLL")) begin
					state_nx = 9'b000000010;
					index_nx = 3'd0;
					mode_nx = 1'b1;
					done_nx = 1'b0;
				end
				else begin
					state_nx = 9'b000000001;
					index_nx = 3'd0;
					mode_nx = 1'b0;
					done_nx = 1'b1;
				end
			9'b000000010: begin
				state_nx = (load_done ? 9'b000000100 : 9'b000000010);
				done_nx = 1'b0;
			end
			9'b000000100: begin
				state_nx = 9'b000001000;
				done_nx = 1'b0;
			end
			9'b000001000: begin
				state_nx = (rdy_r2 ? 9'b000010000 : 9'b000001000);
				done_nx = 1'b0;
			end
			9'b000010000: begin
				state_nx = 9'b000100000;
				done_nx = 1'b0;
			end
			9'b000100000: begin
				state_nx = (rdy_r2 ? 9'b001000000 : 9'b000100000);
				done_nx = 1'b0;
			end
			9'b001000000:
				if ((index == INDEX_MAX) || (mode && (index == 3'd2))) begin
					state_nx = (mode ? 9'b010000000 : 9'b000000001);
					index_nx = 3'd0;
					done_nx = 1'b0;
				end
				else begin
					state_nx = 9'b000000010;
					index_nx = index + 3'd1;
					done_nx = 1'b0;
				end
			9'b010000000: begin
				state_nx = (!qlock_r2 ? 9'b100000000 : 9'b010000000);
				index_nx = 3'd0;
				done_nx = 1'b0;
			end
			9'b100000000: begin
				state_nx = (qlock_r2 ? 9'b000000001 : 9'b100000000);
				index_nx = 3'd0;
				done_nx = 1'b0;
			end
			default: begin
				state_nx = 9'b000000001;
				index_nx = 3'd0;
				mode_nx = 1'b0;
				done_nx = 1'b0;
			end
		endcase
	end
	always @(posedge DRP_CLK)
		if (!DRP_RST_N) begin
			state <= 9'b000000001;
			index <= 3'd0;
			mode <= 1'b0;
			done <= 1'b0;
		end
		else begin
			state <= state_nx;
			index <= index_nx;
			mode <= mode_nx;
			done <= done_nx;
		end
	assign DRP_ADDR = addr;
	assign DRP_EN = (state == 9'b000000100) || (state == 9'b000010000);
	assign DRP_DI = di;
	assign DRP_WE = state == 9'b000010000;
	assign DRP_DONE = done;
	assign DRP_QPLLRESET = state == 9'b010000000;
	assign DRP_CRSCODE = crscode;
	assign DRP_FSM = state;
	initial _sv2v_0 = 0;
endmodule
module serdes_ctrl (
	PIPE_CLK,
	PIPE_RESET_N,
	PIPE_PCLK,
	PIPE_TXDATA,
	PIPE_TXDATAK,
	PIPE_TXP,
	PIPE_TXN,
	PIPE_RXP,
	PIPE_RXN,
	PIPE_RXDATA,
	PIPE_RXDATAK,
	PIPE_TXDETECTRX,
	PIPE_TXELECIDLE,
	PIPE_TXCOMPLIANCE,
	PIPE_RXPOLARITY,
	PIPE_POWERDOWN,
	PIPE_RATE,
	PIPE_TXMARGIN,
	PIPE_TXSWING,
	PIPE_TXDEEMPH,
	PIPE_TXEQ_CONTROL,
	PIPE_TXEQ_PRESET,
	PIPE_TXEQ_PRESET_DEFAULT,
	PIPE_TXEQ_DEEMPH,
	PIPE_RXEQ_CONTROL,
	PIPE_RXEQ_PRESET,
	PIPE_RXEQ_LFFS,
	PIPE_RXEQ_TXPRESET,
	PIPE_RXEQ_USER_EN,
	PIPE_RXEQ_USER_TXCOEFF,
	PIPE_RXEQ_USER_MODE,
	PIPE_TXEQ_FS,
	PIPE_TXEQ_LF,
	PIPE_TXEQ_COEFF,
	PIPE_TXEQ_DONE,
	PIPE_RXEQ_NEW_TXCOEFF,
	PIPE_RXEQ_LFFS_SEL,
	PIPE_RXEQ_ADAPT_DONE,
	PIPE_RXEQ_DONE,
	PIPE_RXVALID,
	PIPE_PHYSTATUS,
	PIPE_PHYSTATUS_RST,
	PIPE_RXELECIDLE,
	PIPE_EYESCANDATAERROR,
	PIPE_RXSTATUS,
	PIPE_RXPMARESETDONE,
	PIPE_RXBUFSTATUS,
	PIPE_TXPHALIGNDONE,
	PIPE_TXPHINITDONE,
	PIPE_TXDLYSRESETDONE,
	PIPE_RXPHALIGNDONE,
	PIPE_RXDLYSRESETDONE,
	PIPE_RXSYNCDONE,
	PIPE_RXDISPERR,
	PIPE_RXNOTINTABLE,
	PIPE_RXCOMMADET,
	PIPE_MMCM_RST_N,
	PIPE_RXSLIDE,
	PIPE_CPLL_LOCK,
	PIPE_QPLL_LOCK,
	PIPE_PCLK_LOCK,
	PIPE_RXCDRLOCK,
	PIPE_USERCLK1,
	PIPE_USERCLK2,
	PIPE_RXUSRCLK,
	PIPE_RXOUTCLK,
	PIPE_TXSYNC_DONE,
	PIPE_RXSYNC_DONE,
	PIPE_GEN3_RDY,
	PIPE_RXCHANISALIGNED,
	PIPE_ACTIVE_LANE,
	INT_PCLK_OUT_SLAVE,
	INT_RXUSRCLK_OUT,
	INT_RXOUTCLK_OUT,
	INT_DCLK_OUT,
	INT_USERCLK1_OUT,
	INT_USERCLK2_OUT,
	INT_OOBCLK_OUT,
	INT_MMCM_LOCK_OUT,
	INT_QPLLLOCK_OUT,
	INT_QPLLOUTCLK_OUT,
	INT_QPLLOUTREFCLK_OUT,
	INT_PCLK_SEL_SLAVE,
	PIPE_PCLK_IN,
	PIPE_RXUSRCLK_IN,
	PIPE_RXOUTCLK_IN,
	PIPE_DCLK_IN,
	PIPE_USERCLK1_IN,
	PIPE_USERCLK2_IN,
	PIPE_OOBCLK_IN,
	PIPE_MMCM_LOCK_IN,
	PIPE_TXOUTCLK_OUT,
	PIPE_RXOUTCLK_OUT,
	PIPE_PCLK_SEL_OUT,
	PIPE_GEN3_OUT,
	QPLL_DRP_CRSCODE,
	QPLL_DRP_FSM,
	QPLL_DRP_DONE,
	QPLL_DRP_RESET,
	QPLL_QPLLLOCK,
	QPLL_QPLLOUTCLK,
	QPLL_QPLLOUTREFCLK,
	QPLL_QPLLPD,
	QPLL_QPLLRESET,
	QPLL_DRP_CLK,
	QPLL_DRP_RST_N,
	QPLL_DRP_OVRD,
	QPLL_DRP_GEN3,
	QPLL_DRP_START,
	PIPE_TXPRBSSEL,
	PIPE_RXPRBSSEL,
	PIPE_TXPRBSFORCEERR,
	PIPE_RXPRBSCNTRESET,
	PIPE_LOOPBACK,
	PIPE_RXPRBSERR,
	PIPE_TXINHIBIT,
	PIPE_RST_FSM,
	PIPE_QRST_FSM,
	PIPE_RATE_FSM,
	PIPE_SYNC_FSM_TX,
	PIPE_SYNC_FSM_RX,
	PIPE_DRP_FSM,
	PIPE_TXEQ_FSM,
	PIPE_RXEQ_FSM,
	PIPE_QDRP_FSM,
	PIPE_RST_IDLE,
	PIPE_QRST_IDLE,
	PIPE_RATE_IDLE,
	EXT_CH_GT_DRPCLK,
	EXT_CH_GT_DRPADDR,
	EXT_CH_GT_DRPEN,
	EXT_CH_GT_DRPDI,
	EXT_CH_GT_DRPWE,
	EXT_CH_GT_DRPDO,
	EXT_CH_GT_DRPRDY,
	PIPE_JTAG_EN,
	PIPE_JTAG_RDY,
	PIPE_DEBUG_0,
	PIPE_DEBUG_1,
	PIPE_DEBUG_2,
	PIPE_DEBUG_3,
	PIPE_DEBUG_4,
	PIPE_DEBUG_5,
	PIPE_DEBUG_6,
	PIPE_DEBUG_7,
	PIPE_DEBUG_8,
	PIPE_DEBUG_9,
	PIPE_DEBUG,
	PIPE_DMONITOROUT
);
	localparam EXT_CH_GT_DRP = "FALSE";
	localparam PCIE_TXSYNC_MODE = 0;
	localparam PCIE_RXSYNC_MODE = 0;
	localparam PCIE_CHAN_BOND = 1;
	localparam PCIE_CHAN_BOND_EN = "TRUE";
	localparam PCIE_OOBCLK_MODE = 1;
	localparam PCIE_DEBUG_MODE = 0;
	input PIPE_CLK;
	input PIPE_RESET_N;
	output wire PIPE_PCLK;
	localparam signed [31:0] link_pkg_PCIE_LANES = 1;
	input [31:0] PIPE_TXDATA;
	input [3:0] PIPE_TXDATAK;
	output wire [0:0] PIPE_TXP;
	output wire [0:0] PIPE_TXN;
	input [0:0] PIPE_RXP;
	input [0:0] PIPE_RXN;
	output wire [31:0] PIPE_RXDATA;
	output wire [3:0] PIPE_RXDATAK;
	input PIPE_TXDETECTRX;
	input [0:0] PIPE_TXELECIDLE;
	input [0:0] PIPE_TXCOMPLIANCE;
	input [0:0] PIPE_RXPOLARITY;
	input [1:0] PIPE_POWERDOWN;
	input [1:0] PIPE_RATE;
	input [2:0] PIPE_TXMARGIN;
	input PIPE_TXSWING;
	input [0:0] PIPE_TXDEEMPH;
	input [1:0] PIPE_TXEQ_CONTROL;
	input [3:0] PIPE_TXEQ_PRESET;
	input [3:0] PIPE_TXEQ_PRESET_DEFAULT;
	input [5:0] PIPE_TXEQ_DEEMPH;
	input [1:0] PIPE_RXEQ_CONTROL;
	input [2:0] PIPE_RXEQ_PRESET;
	input [5:0] PIPE_RXEQ_LFFS;
	input [3:0] PIPE_RXEQ_TXPRESET;
	input [0:0] PIPE_RXEQ_USER_EN;
	input [17:0] PIPE_RXEQ_USER_TXCOEFF;
	input [0:0] PIPE_RXEQ_USER_MODE;
	output wire [5:0] PIPE_TXEQ_FS;
	output wire [5:0] PIPE_TXEQ_LF;
	output wire [17:0] PIPE_TXEQ_COEFF;
	output wire [0:0] PIPE_TXEQ_DONE;
	output wire [17:0] PIPE_RXEQ_NEW_TXCOEFF;
	output wire [0:0] PIPE_RXEQ_LFFS_SEL;
	output wire [0:0] PIPE_RXEQ_ADAPT_DONE;
	output wire [0:0] PIPE_RXEQ_DONE;
	output wire [0:0] PIPE_RXVALID;
	output wire [0:0] PIPE_PHYSTATUS;
	output wire [0:0] PIPE_PHYSTATUS_RST;
	output wire [0:0] PIPE_RXELECIDLE;
	output wire [0:0] PIPE_EYESCANDATAERROR;
	output wire [2:0] PIPE_RXSTATUS;
	output wire [0:0] PIPE_RXPMARESETDONE;
	output wire [2:0] PIPE_RXBUFSTATUS;
	output wire [0:0] PIPE_TXPHALIGNDONE;
	output wire [0:0] PIPE_TXPHINITDONE;
	output wire [0:0] PIPE_TXDLYSRESETDONE;
	output wire [0:0] PIPE_RXPHALIGNDONE;
	output wire [0:0] PIPE_RXDLYSRESETDONE;
	output wire [0:0] PIPE_RXSYNCDONE;
	output wire [7:0] PIPE_RXDISPERR;
	output wire [7:0] PIPE_RXNOTINTABLE;
	output wire [0:0] PIPE_RXCOMMADET;
	input PIPE_MMCM_RST_N;
	input [0:0] PIPE_RXSLIDE;
	output wire [0:0] PIPE_CPLL_LOCK;
	output wire [0:0] PIPE_QPLL_LOCK;
	output wire PIPE_PCLK_LOCK;
	output wire [0:0] PIPE_RXCDRLOCK;
	output wire PIPE_USERCLK1;
	output wire PIPE_USERCLK2;
	output wire PIPE_RXUSRCLK;
	output wire [0:0] PIPE_RXOUTCLK;
	output wire [0:0] PIPE_TXSYNC_DONE;
	output wire [0:0] PIPE_RXSYNC_DONE;
	output wire [0:0] PIPE_GEN3_RDY;
	output wire [0:0] PIPE_RXCHANISALIGNED;
	output wire [0:0] PIPE_ACTIVE_LANE;
	output wire INT_PCLK_OUT_SLAVE;
	output wire INT_RXUSRCLK_OUT;
	output wire [0:0] INT_RXOUTCLK_OUT;
	output wire INT_DCLK_OUT;
	output wire INT_USERCLK1_OUT;
	output wire INT_USERCLK2_OUT;
	output wire INT_OOBCLK_OUT;
	output wire INT_MMCM_LOCK_OUT;
	output wire [1:0] INT_QPLLLOCK_OUT;
	output wire [1:0] INT_QPLLOUTCLK_OUT;
	output wire [1:0] INT_QPLLOUTREFCLK_OUT;
	input [0:0] INT_PCLK_SEL_SLAVE;
	input PIPE_PCLK_IN;
	input PIPE_RXUSRCLK_IN;
	input [0:0] PIPE_RXOUTCLK_IN;
	input PIPE_DCLK_IN;
	input PIPE_USERCLK1_IN;
	input PIPE_USERCLK2_IN;
	input PIPE_OOBCLK_IN;
	input PIPE_MMCM_LOCK_IN;
	output wire PIPE_TXOUTCLK_OUT;
	output wire [0:0] PIPE_RXOUTCLK_OUT;
	output wire [0:0] PIPE_PCLK_SEL_OUT;
	output wire PIPE_GEN3_OUT;
	input [11:0] QPLL_DRP_CRSCODE;
	input [17:0] QPLL_DRP_FSM;
	input [1:0] QPLL_DRP_DONE;
	input [1:0] QPLL_DRP_RESET;
	input [1:0] QPLL_QPLLLOCK;
	input [1:0] QPLL_QPLLOUTCLK;
	input [1:0] QPLL_QPLLOUTREFCLK;
	output wire QPLL_QPLLPD;
	output wire [1:0] QPLL_QPLLRESET;
	output wire QPLL_DRP_CLK;
	output wire QPLL_DRP_RST_N;
	output wire QPLL_DRP_OVRD;
	output wire QPLL_DRP_GEN3;
	output wire QPLL_DRP_START;
	input [2:0] PIPE_TXPRBSSEL;
	input [2:0] PIPE_RXPRBSSEL;
	input PIPE_TXPRBSFORCEERR;
	input PIPE_RXPRBSCNTRESET;
	input [2:0] PIPE_LOOPBACK;
	output wire [0:0] PIPE_RXPRBSERR;
	input [0:0] PIPE_TXINHIBIT;
	output wire [4:0] PIPE_RST_FSM;
	output wire [11:0] PIPE_QRST_FSM;
	output wire [4:0] PIPE_RATE_FSM;
	output wire [5:0] PIPE_SYNC_FSM_TX;
	output wire [6:0] PIPE_SYNC_FSM_RX;
	output wire [6:0] PIPE_DRP_FSM;
	output wire [5:0] PIPE_TXEQ_FSM;
	output wire [5:0] PIPE_RXEQ_FSM;
	output wire [8:0] PIPE_QDRP_FSM;
	output wire PIPE_RST_IDLE;
	output wire PIPE_QRST_IDLE;
	output wire PIPE_RATE_IDLE;
	output wire EXT_CH_GT_DRPCLK;
	input [8:0] EXT_CH_GT_DRPADDR;
	input [0:0] EXT_CH_GT_DRPEN;
	input [15:0] EXT_CH_GT_DRPDI;
	input [0:0] EXT_CH_GT_DRPWE;
	output wire [15:0] EXT_CH_GT_DRPDO;
	output wire [0:0] EXT_CH_GT_DRPRDY;
	input PIPE_JTAG_EN;
	output wire [0:0] PIPE_JTAG_RDY;
	output wire [0:0] PIPE_DEBUG_0;
	output wire [0:0] PIPE_DEBUG_1;
	output wire [0:0] PIPE_DEBUG_2;
	output wire [0:0] PIPE_DEBUG_3;
	output wire [0:0] PIPE_DEBUG_4;
	output wire [0:0] PIPE_DEBUG_5;
	output wire [0:0] PIPE_DEBUG_6;
	output wire [0:0] PIPE_DEBUG_7;
	output wire [0:0] PIPE_DEBUG_8;
	output wire [0:0] PIPE_DEBUG_9;
	output wire [31:0] PIPE_DEBUG;
	output wire [14:0] PIPE_DMONITOROUT;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg reset_n_reg1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg reset_n_reg2;
	wire clk_pclk;
	wire clk_rxusrclk;
	wire [0:0] clk_rxoutclk;
	wire clk_dclk;
	wire clk_oobclk;
	wire clk_mmcm_lock;
	wire rst_cpllreset;
	wire rst_cpllpd;
	wire rst_rxusrclk_reset;
	wire rst_dclk_reset;
	wire rst_gtreset;
	wire rst_drp_start;
	wire rst_drp_x16x20_mode;
	wire rst_drp_x16;
	wire rst_userrdy;
	wire rst_txsync_start;
	wire rst_idle;
	wire [4:0] rst_fsm;
	wire gtp_rst_qpllreset;
	wire gtp_rst_qpllpd;
	wire [0:0] qpllreset;
	wire qpllpd;
	wire qrst_ovrd;
	wire qrst_drp_start;
	wire qrst_qpllreset;
	wire qrst_qpllpd;
	wire qrst_idle;
	wire [3:0] qrst_fsm;
	wire [36:0] jtag_sl_iport;
	wire [16:0] jtag_sl_oport;
	wire [0:0] gt_txpmareset_i;
	wire [0:0] gt_rxpmareset_i;
	wire [0:0] user_oobclk;
	wire [0:0] user_resetovrd;
	wire [0:0] user_txpmareset;
	wire [0:0] user_rxpmareset;
	wire [0:0] user_rxcdrreset;
	wire [0:0] user_rxcdrfreqreset;
	wire [0:0] user_rxdfelpmreset;
	wire [0:0] user_eyescanreset;
	wire [0:0] user_txpcsreset;
	wire [0:0] user_rxpcsreset;
	wire [0:0] user_rxbufreset;
	wire [0:0] user_resetovrd_done;
	wire [0:0] user_active_lane;
	wire [0:0] user_resetdone;
	wire [0:0] user_rxcdrlock;
	wire [0:0] user_rx_converge;
	wire [0:0] PIPE_RXEQ_CONVERGE;
	wire [0:0] rate_cpllpd;
	wire [0:0] rate_qpllpd;
	wire [0:0] rate_cpllreset;
	wire [0:0] rate_qpllreset;
	wire [0:0] rate_txpmareset;
	wire [0:0] rate_rxpmareset;
	wire [1:0] rate_sysclksel;
	wire [0:0] rate_pclk_sel;
	wire [0:0] rate_drp_start;
	wire [0:0] rate_drp_x16x20_mode;
	wire [0:0] rate_drp_x16;
	wire [0:0] rate_gen3;
	wire [2:0] rate_rate;
	wire [0:0] rate_resetovrd_start;
	wire [0:0] rate_txsync_start;
	wire [0:0] rate_done;
	wire [0:0] rate_rxsync_start;
	wire [0:0] rate_rxsync;
	wire [0:0] rate_idle;
	wire [4:0] rate_fsm;
	wire [0:0] sync_txphdlyreset;
	wire [0:0] sync_txphalign;
	wire [0:0] sync_txphalignen;
	wire [0:0] sync_txphinit;
	wire [0:0] sync_txdlybypass;
	wire [0:0] sync_txdlysreset;
	wire [0:0] sync_txdlyen;
	wire [0:0] sync_txsync_done;
	wire [5:0] sync_fsm_tx;
	wire [0:0] sync_rxphalign;
	wire [0:0] sync_rxphalignen;
	wire [0:0] sync_rxdlybypass;
	wire [0:0] sync_rxdlysreset;
	wire [0:0] sync_rxdlyen;
	wire [0:0] sync_rxddien;
	wire [0:0] sync_rxsync_done;
	wire [0:0] sync_rxsync_donem;
	wire [6:0] sync_fsm_rx;
	wire [0:0] txdlysresetdone;
	wire [0:0] txphaligndone;
	wire [0:0] rxdlysresetdone;
	wire [0:0] rxphaligndone_s;
	wire txsyncallin;
	wire rxsyncallin;
	wire [8:0] drp_addr;
	wire [0:0] drp_en;
	wire [15:0] drp_di;
	wire [0:0] drp_we;
	wire [0:0] drp_done;
	wire [2:0] drp_fsm;
	wire [16:0] jtag_sl_addr;
	wire [0:0] jtag_sl_den;
	wire [0:0] jtag_sl_en;
	wire [15:0] jtag_sl_di;
	wire [0:0] jtag_sl_we;
	wire [8:0] drp_mux_addr;
	wire [0:0] drp_mux_en;
	wire [15:0] drp_mux_di;
	wire [0:0] drp_mux_we;
	wire [0:0] eq_txeq_deemph;
	wire [4:0] eq_txeq_precursor;
	wire [6:0] eq_txeq_maincursor;
	wire [4:0] eq_txeq_postcursor;
	wire [0:0] eq_rxeq_adapt_done;
	wire [7:0] qdrp_addr;
	wire [0:0] qdrp_en;
	wire [15:0] qdrp_di;
	wire [0:0] qdrp_we;
	wire [0:0] qdrp_done;
	wire [0:0] qdrp_qpllreset;
	wire [5:0] qdrp_crscode;
	wire [8:0] qdrp_fsm;
	wire [0:0] qpll_qplloutclk;
	wire [0:0] qpll_qplloutrefclk;
	wire [0:0] qpll_qplllock;
	wire [15:0] qpll_do;
	wire [0:0] qpll_rdy;
	wire [0:0] gt_txoutclk;
	wire [0:0] gt_rxoutclk;
	wire [0:0] gt_cplllock;
	wire [0:0] gt_rxcdrlock;
	wire [0:0] gt_txresetdone;
	wire [0:0] gt_rxresetdone;
	wire [0:0] gt_eyescandataerror;
	wire [0:0] gt_rxpmaresetdone;
	wire [7:0] gt_rxdisperr;
	wire [7:0] gt_rxnotintable;
	wire [0:0] gt_rxvalid;
	wire [0:0] gt_phystatus;
	wire [2:0] gt_rxstatus;
	wire [2:0] gt_rxbufstatus;
	wire [0:0] gt_rxelecidle;
	wire [0:0] gt_rxelecidle_i;
	reg [0:0] gt_rxrcvrdet_c;
	wire [0:0] gt_txratedone;
	wire [0:0] gt_rxratedone;
	wire [15:0] gt_do;
	wire [0:0] gt_rdy;
	wire [0:0] gt_txphinitdone;
	wire [0:0] gt_txdlysresetdone;
	wire [0:0] gt_txphaligndone;
	wire [0:0] gt_rxdlysresetdone;
	wire [link_pkg_PCIE_LANES:0] gt_rxphaligndone;
	wire [0:0] gt_txsyncout;
	wire [0:0] gt_txsyncdone;
	wire [0:0] gt_rxsyncout;
	wire [0:0] gt_rxsyncdone;
	wire [0:0] gt_rxcommadet;
	wire [3:0] gt_rxchariscomma;
	wire [0:0] gt_rxbyteisaligned;
	wire [0:0] gt_rxbyterealign;
	wire [4:0] gt_rxchbondi [link_pkg_PCIE_LANES:0];
	wire [2:0] gt_rxchbondlevel;
	wire [4:0] gt_rxchbondo [link_pkg_PCIE_LANES:0];
	wire [0:0] rxchbonden;
	wire [0:0] rxchbondmaster;
	wire [0:0] rxchbondslave;
	wire [0:0] oobclk;
	genvar _gv_i_1;
	assign gt_rxchbondo[0] = 5'd0;
	assign gt_rxphaligndone[link_pkg_PCIE_LANES] = 1'd1;
	assign txsyncallin = &(gt_txphaligndone | ~user_active_lane);
	assign rxsyncallin = &(gt_rxphaligndone | ~user_active_lane);
	always @(posedge clk_pclk or negedge PIPE_RESET_N)
		if (!PIPE_RESET_N) begin
			reset_n_reg1 <= 1'd0;
			reset_n_reg2 <= 1'd0;
		end
		else begin
			reset_n_reg1 <= 1'd1;
			reset_n_reg2 <= reset_n_reg1;
		end
	assign clk_pclk = PIPE_PCLK_IN;
	assign clk_rxusrclk = PIPE_RXUSRCLK_IN;
	assign clk_rxoutclk = PIPE_RXOUTCLK_IN;
	assign clk_dclk = PIPE_DCLK_IN;
	assign PIPE_USERCLK1 = PIPE_USERCLK1_IN;
	assign PIPE_USERCLK2 = PIPE_USERCLK2_IN;
	assign clk_oobclk = PIPE_OOBCLK_IN;
	assign clk_mmcm_lock = PIPE_MMCM_LOCK_IN;
	assign INT_PCLK_OUT_SLAVE = 1'b0;
	assign INT_RXUSRCLK_OUT = 1'b0;
	assign INT_RXOUTCLK_OUT = {link_pkg_PCIE_LANES {1'b0}};
	assign INT_DCLK_OUT = 1'b0;
	assign INT_USERCLK1_OUT = 1'b0;
	assign INT_USERCLK2_OUT = 1'b0;
	assign INT_OOBCLK_OUT = 1'b0;
	assign INT_MMCM_LOCK_OUT = 1'b0;
	init_ctrl init_ctrl_i(
		.RST_CLK(clk_pclk),
		.RST_RXUSRCLK(clk_rxusrclk),
		.RST_DCLK(clk_dclk),
		.RST_RST_N(reset_n_reg2),
		.RST_DRP_DONE(drp_done),
		.RST_RXPMARESETDONE(gt_rxpmaresetdone),
		.RST_PLLLOCK(&qpll_qplllock),
		.RST_RATE_IDLE(rate_idle),
		.RST_RXCDRLOCK(user_rxcdrlock),
		.RST_MMCM_LOCK(clk_mmcm_lock),
		.RST_RESETDONE(user_resetdone),
		.RST_PHYSTATUS(gt_phystatus),
		.RST_TXSYNC_DONE(sync_txsync_done),
		.RST_CPLLRESET(rst_cpllreset),
		.RST_CPLLPD(rst_cpllpd),
		.RST_RXUSRCLK_RESET(rst_rxusrclk_reset),
		.RST_DCLK_RESET(rst_dclk_reset),
		.RST_GTRESET(rst_gtreset),
		.RST_DRP_START(rst_drp_start),
		.RST_DRP_X16(rst_drp_x16),
		.RST_USERRDY(rst_userrdy),
		.RST_TXSYNC_START(rst_txsync_start),
		.RST_IDLE(rst_idle),
		.RST_FSM(rst_fsm)
	);
	assign gtp_rst_qpllreset = rst_cpllreset;
	assign gtp_rst_qpllpd = rst_cpllpd;
	pll_init_ctrl pll_init_ctrl_i(
		.QRST_CLK(clk_pclk),
		.QRST_RST_N(reset_n_reg2),
		.QRST_MMCM_LOCK(clk_mmcm_lock),
		.QRST_CPLLLOCK({link_pkg_PCIE_LANES {&qpll_qplllock}}),
		.QRST_DRP_DONE(qdrp_done),
		.QRST_QPLLLOCK(qpll_qplllock),
		.QRST_RATE(PIPE_RATE),
		.QRST_QPLLRESET_IN(rate_qpllreset),
		.QRST_QPLLPD_IN(rate_qpllpd),
		.QRST_OVRD(qrst_ovrd),
		.QRST_DRP_START(qrst_drp_start),
		.QRST_QPLLRESET_OUT(qrst_qpllreset),
		.QRST_QPLLPD_OUT(qrst_qpllpd),
		.QRST_IDLE(qrst_idle),
		.QRST_FSM(qrst_fsm)
	);
	assign jtag_sl_iport = {link_pkg_PCIE_LANES {37'd0}};
	wire gt_cpllpdrefclk;
	assign gt_cpllpdrefclk = clk_dclk;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < link_pkg_PCIE_LANES; _gv_i_1 = _gv_i_1 + 1) begin : lane_gen
			localparam i = _gv_i_1;
			lane_keeper lane_keeper_i(
				.USER_TXUSRCLK(clk_pclk),
				.USER_RXUSRCLK(clk_rxusrclk),
				.USER_OOBCLK_IN(clk_oobclk),
				.USER_RST_N(!rst_cpllreset),
				.USER_RXUSRCLK_RST_N(!rst_rxusrclk_reset),
				.USER_PCLK_SEL(rate_pclk_sel[i]),
				.USER_RESETOVRD_START(rate_resetovrd_start[i]),
				.USER_TXRESETDONE(gt_txresetdone[i]),
				.USER_RXRESETDONE(gt_rxresetdone[i]),
				.USER_TXELECIDLE(PIPE_TXELECIDLE[i]),
				.USER_TXCOMPLIANCE(PIPE_TXCOMPLIANCE[i]),
				.USER_RXCDRLOCK_IN(gt_rxcdrlock[i]),
				.USER_RXVALID_IN(gt_rxvalid[i]),
				.USER_RXSTATUS_IN(gt_rxstatus[(3 * i) + 2]),
				.USER_PHYSTATUS_IN(gt_phystatus[i]),
				.USER_RATE_DONE(rate_done[i]),
				.USER_RST_IDLE(rst_idle),
				.USER_RATE_RXSYNC(rate_rxsync[i]),
				.USER_RATE_IDLE(rate_idle[i]),
				.USER_RATE_GEN3(rate_gen3[i]),
				.USER_RXEQ_ADAPT_DONE(eq_rxeq_adapt_done[i]),
				.USER_OOBCLK(user_oobclk[i]),
				.USER_RESETOVRD(user_resetovrd[i]),
				.USER_TXPMARESET(user_txpmareset[i]),
				.USER_RXPMARESET(user_rxpmareset[i]),
				.USER_RXCDRRESET(user_rxcdrreset[i]),
				.USER_RXCDRFREQRESET(user_rxcdrfreqreset[i]),
				.USER_RXDFELPMRESET(user_rxdfelpmreset[i]),
				.USER_EYESCANRESET(user_eyescanreset[i]),
				.USER_TXPCSRESET(user_txpcsreset[i]),
				.USER_RXPCSRESET(user_rxpcsreset[i]),
				.USER_RXBUFRESET(user_rxbufreset[i]),
				.USER_RESETOVRD_DONE(user_resetovrd_done[i]),
				.USER_RESETDONE(user_resetdone[i]),
				.USER_ACTIVE_LANE(user_active_lane[i]),
				.USER_RXCDRLOCK_OUT(user_rxcdrlock[i]),
				.USER_RXVALID_OUT(PIPE_RXVALID[i]),
				.USER_PHYSTATUS_OUT(PIPE_PHYSTATUS[i]),
				.USER_PHYSTATUS_RST(PIPE_PHYSTATUS_RST[i]),
				.USER_GEN3_RDY(PIPE_GEN3_RDY[i]),
				.USER_RX_CONVERGE(user_rx_converge[i])
			);
			speed_ctrl speed_ctrl_i(
				.RATE_CLK(clk_pclk),
				.RATE_RST_N(!rst_cpllreset),
				.RATE_RATE_IN(PIPE_RATE),
				.RATE_DRP_DONE(drp_done[i]),
				.RATE_RXPMARESETDONE(gt_rxpmaresetdone[i]),
				.RATE_TXRATEDONE(gt_txratedone[i]),
				.RATE_RXRATEDONE(gt_rxratedone[i]),
				.RATE_PHYSTATUS(gt_phystatus[i]),
				.RATE_TXSYNC_DONE(sync_txsync_done[i]),
				.RATE_DRP_START(rate_drp_start[i]),
				.RATE_DRP_X16(rate_drp_x16[i]),
				.RATE_PCLK_SEL(rate_pclk_sel[i]),
				.RATE_RATE_OUT(rate_rate[(3 * i) + 2:3 * i]),
				.RATE_TXSYNC_START(rate_txsync_start[i]),
				.RATE_DONE(rate_done[i]),
				.RATE_IDLE(rate_idle[i]),
				.RATE_FSM(rate_fsm[(5 * i) + 4:5 * i])
			);
			assign rate_cpllpd[i] = 1'd0;
			assign rate_qpllpd[i] = 1'd0;
			assign rate_cpllreset[i] = 1'd0;
			assign rate_qpllreset[i] = 1'd0;
			assign rate_txpmareset[i] = 1'd0;
			assign rate_rxpmareset[i] = 1'd0;
			assign rate_sysclksel[(2 * i) + 1:2 * i] = 2'b00;
			assign rate_gen3[i] = 1'd0;
			assign rate_resetovrd_start[i] = 1'd0;
			assign rate_rxsync_start[i] = 1'd0;
			assign rate_rxsync[i] = 1'd0;
			phase_align phase_align_i(
				.SYNC_CLK(clk_pclk),
				.SYNC_RST_N(!rst_cpllreset),
				.SYNC_SLAVE(i > 0),
				.SYNC_GEN3(rate_gen3[i]),
				.SYNC_RATE_IDLE(rate_idle[i]),
				.SYNC_MMCM_LOCK(clk_mmcm_lock),
				.SYNC_RXELECIDLE(gt_rxelecidle_i[i]),
				.SYNC_RXCDRLOCK(user_rxcdrlock[i]),
				.SYNC_ACTIVE_LANE(user_active_lane[i]),
				.SYNC_TXSYNC_START(rate_txsync_start[i] || rst_txsync_start),
				.SYNC_TXPHINITDONE(&(gt_txphinitdone | ~user_active_lane)),
				.SYNC_TXDLYSRESETDONE(txdlysresetdone[i]),
				.SYNC_TXPHALIGNDONE(txphaligndone[i]),
				.SYNC_TXSYNCDONE(gt_txsyncdone[i]),
				.SYNC_RXSYNC_START(rate_rxsync_start[i]),
				.SYNC_RXDLYSRESETDONE(rxdlysresetdone[i]),
				.SYNC_RXPHALIGNDONE_M(gt_rxphaligndone[0]),
				.SYNC_RXPHALIGNDONE_S(rxphaligndone_s[i]),
				.SYNC_RXSYNC_DONEM_IN(sync_rxsync_donem[0]),
				.SYNC_RXSYNCDONE(gt_rxsyncdone[i]),
				.SYNC_TXPHDLYRESET(sync_txphdlyreset[i]),
				.SYNC_TXPHALIGN(sync_txphalign[i]),
				.SYNC_TXPHALIGNEN(sync_txphalignen[i]),
				.SYNC_TXPHINIT(sync_txphinit[i]),
				.SYNC_TXDLYBYPASS(sync_txdlybypass[i]),
				.SYNC_TXDLYSRESET(sync_txdlysreset[i]),
				.SYNC_TXDLYEN(sync_txdlyen[i]),
				.SYNC_TXSYNC_DONE(sync_txsync_done[i]),
				.SYNC_FSM_TX(sync_fsm_tx[(6 * i) + 5:6 * i]),
				.SYNC_RXPHALIGN(sync_rxphalign[i]),
				.SYNC_RXPHALIGNEN(sync_rxphalignen[i]),
				.SYNC_RXDLYBYPASS(sync_rxdlybypass[i]),
				.SYNC_RXDLYSRESET(sync_rxdlysreset[i]),
				.SYNC_RXDLYEN(sync_rxdlyen[i]),
				.SYNC_RXDDIEN(sync_rxddien[i]),
				.SYNC_RXSYNC_DONEM_OUT(sync_rxsync_donem[i]),
				.SYNC_RXSYNC_DONE(sync_rxsync_done[i]),
				.SYNC_FSM_RX(sync_fsm_rx[(7 * i) + 6:7 * i])
			);
			assign txdlysresetdone[i] = &gt_txdlysresetdone;
			assign txphaligndone[i] = &(gt_txphaligndone | ~user_active_lane);
			assign rxdlysresetdone[i] = &gt_rxdlysresetdone;
			assign rxphaligndone_s[i] = 1'd0;
			chan_retune chan_retune_i(
				.DRP_CLK(clk_dclk),
				.DRP_RST_N(!rst_dclk_reset),
				.DRP_X16(rst_drp_x16 || rate_drp_x16[i]),
				.DRP_START(rst_drp_start || rate_drp_start[i]),
				.DRP_DO(gt_do[(16 * i) + 15:16 * i]),
				.DRP_RDY(gt_rdy[i]),
				.DRP_ADDR(drp_addr[(9 * i) + 8:9 * i]),
				.DRP_EN(drp_en[i]),
				.DRP_DI(drp_di[(16 * i) + 15:16 * i]),
				.DRP_WE(drp_we[i]),
				.DRP_DONE(drp_done[i]),
				.DRP_FSM(drp_fsm[(3 * i) + 2:3 * i])
			);
			assign jtag_sl_oport[((i + 1) * 17) - 1:i * 17] = 17'd0;
			assign jtag_sl_addr[(17 * i) + 16:17 * i] = 17'd0;
			assign jtag_sl_den[i] = 1'd0;
			assign jtag_sl_di[(16 * i) + 15:16 * i] = 16'd0;
			assign jtag_sl_we[i] = 1'd0;
			assign PIPE_JTAG_RDY[i] = drp_fsm[(3 * i) + 2:3 * i] == 3'b000;
			assign jtag_sl_en[i] = (jtag_sl_addr[(17 * i) + 16:(17 * i) + 9] == 8'd0 ? jtag_sl_den[i] : 1'd0);
			assign drp_mux_en[i] = (PIPE_JTAG_RDY[i] && EXT_CH_GT_DRP ? EXT_CH_GT_DRPEN[i] : drp_en[i]);
			assign drp_mux_di[(16 * i) + 15:16 * i] = (PIPE_JTAG_RDY[i] && EXT_CH_GT_DRP ? EXT_CH_GT_DRPDI[(16 * i) + 15:16 * i] : drp_di[(16 * i) + 15:16 * i]);
			assign drp_mux_addr[(9 * i) + 8:9 * i] = (PIPE_JTAG_RDY[i] && EXT_CH_GT_DRP ? EXT_CH_GT_DRPADDR[(9 * i) + 8:9 * i] : drp_addr[(9 * i) + 8:9 * i]);
			assign drp_mux_we[i] = (PIPE_JTAG_RDY[i] && EXT_CH_GT_DRP ? EXT_CH_GT_DRPWE[i] : drp_we[i]);
			margin_tuner margin_tuner_i(
				.EQ_CLK(clk_pclk),
				.EQ_RST_N(!rst_cpllreset),
				.EQ_GEN3(rate_gen3[i]),
				.EQ_TXEQ_CONTROL(PIPE_TXEQ_CONTROL[(2 * i) + 1:2 * i]),
				.EQ_TXEQ_PRESET(PIPE_TXEQ_PRESET[(4 * i) + 3:4 * i]),
				.EQ_TXEQ_PRESET_DEFAULT(PIPE_TXEQ_PRESET_DEFAULT[(4 * i) + 3:4 * i]),
				.EQ_TXEQ_DEEMPH_IN(PIPE_TXEQ_DEEMPH[(6 * i) + 5:6 * i]),
				.EQ_RXEQ_CONTROL(PIPE_RXEQ_CONTROL[(2 * i) + 1:2 * i]),
				.EQ_RXEQ_PRESET(PIPE_RXEQ_PRESET[(3 * i) + 2:3 * i]),
				.EQ_RXEQ_LFFS(PIPE_RXEQ_LFFS[(6 * i) + 5:6 * i]),
				.EQ_RXEQ_TXPRESET(PIPE_RXEQ_TXPRESET[(4 * i) + 3:4 * i]),
				.EQ_RXEQ_USER_EN(PIPE_RXEQ_USER_EN[i]),
				.EQ_RXEQ_USER_TXCOEFF(PIPE_RXEQ_USER_TXCOEFF[(18 * i) + 17:18 * i]),
				.EQ_RXEQ_USER_MODE(PIPE_RXEQ_USER_MODE[i]),
				.EQ_TXEQ_DEEMPH(eq_txeq_deemph[i]),
				.EQ_TXEQ_PRECURSOR(eq_txeq_precursor[(5 * i) + 4:5 * i]),
				.EQ_TXEQ_MAINCURSOR(eq_txeq_maincursor[(7 * i) + 6:7 * i]),
				.EQ_TXEQ_POSTCURSOR(eq_txeq_postcursor[(5 * i) + 4:5 * i]),
				.EQ_TXEQ_DEEMPH_OUT(PIPE_TXEQ_COEFF[(18 * i) + 17:18 * i]),
				.EQ_TXEQ_DONE(PIPE_TXEQ_DONE[i]),
				.EQ_TXEQ_FSM(PIPE_TXEQ_FSM[(6 * i) + 5:6 * i]),
				.EQ_RXEQ_NEW_TXCOEFF(PIPE_RXEQ_NEW_TXCOEFF[(18 * i) + 17:18 * i]),
				.EQ_RXEQ_LFFS_SEL(PIPE_RXEQ_LFFS_SEL[i]),
				.EQ_RXEQ_ADAPT_DONE(eq_rxeq_adapt_done[i]),
				.EQ_RXEQ_DONE(PIPE_RXEQ_DONE[i]),
				.EQ_RXEQ_FSM(PIPE_RXEQ_FSM[(6 * i) + 5:6 * i])
			);
			if ((i % 4) == 0) begin : quad_gen
				assign qpllpd = gtp_rst_qpllpd;
				assign qpllreset[i >> 2] = gtp_rst_qpllreset;
				wire [7:0] q_drp_addr;
				wire q_drp_en;
				wire [15:0] q_drp_di;
				wire q_drp_we;
				wire [15:0] q_drp_do;
				wire q_drp_rdy;
				pll_retune pll_retune_i(
					.DRP_CLK(clk_dclk),
					.DRP_RST_N(!rst_dclk_reset),
					.DRP_OVRD(qrst_ovrd),
					.DRP_GEN3(&rate_gen3),
					.DRP_QPLLLOCK(qpll_qplllock[i >> 2]),
					.DRP_START(qrst_drp_start),
					.DRP_DO(q_drp_do),
					.DRP_RDY(q_drp_rdy),
					.DRP_ADDR(q_drp_addr),
					.DRP_EN(q_drp_en),
					.DRP_DI(q_drp_di),
					.DRP_WE(q_drp_we),
					.DRP_DONE(qdrp_done[i >> 2]),
					.DRP_QPLLRESET(qdrp_qpllreset[i >> 2]),
					.DRP_CRSCODE(qdrp_crscode[(6 * (i >> 2)) + 5:6 * (i >> 2)]),
					.DRP_FSM(qdrp_fsm[(9 * (i >> 2)) + 8:9 * (i >> 2)])
				);
				pll_bank pll_bank_i(
					.QPLL_CPLLPDREFCLK(gt_cpllpdrefclk),
					.QPLL_GTGREFCLK(PIPE_CLK),
					.QPLL_QPLLLOCKDETCLK(1'd0),
					.QPLL_QPLLOUTCLK(qpll_qplloutclk[i >> 2]),
					.QPLL_QPLLOUTREFCLK(qpll_qplloutrefclk[i >> 2]),
					.QPLL_QPLLLOCK(qpll_qplllock[i >> 2]),
					.QPLL_QPLLPD(qpllpd),
					.QPLL_QPLLRESET(qpllreset[i >> 2]),
					.QPLL_DRPCLK(clk_dclk),
					.QPLL_DRPADDR(q_drp_addr),
					.QPLL_DRPEN(q_drp_en),
					.QPLL_DRPDI(q_drp_di),
					.QPLL_DRPWE(q_drp_we),
					.QPLL_DRPDO(q_drp_do),
					.QPLL_DRPRDY(q_drp_rdy)
				);
				assign QPLL_QPLLPD = 1'b0;
				assign QPLL_QPLLRESET[i >> 2] = 1'b0;
				assign QPLL_DRP_CLK = 1'b0;
				assign QPLL_DRP_RST_N = 1'b0;
				assign QPLL_DRP_OVRD = 1'b0;
				assign QPLL_DRP_GEN3 = 1'b0;
				assign QPLL_DRP_START = 1'b0;
				assign INT_QPLLLOCK_OUT[i >> 2] = qpll_qplllock[i >> 2];
				assign INT_QPLLOUTREFCLK_OUT[i >> 2] = qpll_qplloutrefclk[i >> 2];
				assign INT_QPLLOUTCLK_OUT[i >> 2] = qpll_qplloutclk[i >> 2];
			end
			assign gt_txpmareset_i[i] = user_txpmareset[i] || rate_txpmareset[i];
			assign gt_rxpmareset_i[i] = user_rxpmareset[i] || rate_rxpmareset[i];
			lane_xcvr xcvr_i(
				.GT_MASTER(i == 0),
				.GT_GEN3(rate_gen3[i]),
				.GT_RX_CONVERGE(&user_rx_converge),
				.GT_GTREFCLK0(PIPE_CLK),
				.GT_QPLLCLK(qpll_qplloutclk[i >> 2]),
				.GT_QPLLREFCLK(qpll_qplloutrefclk[i >> 2]),
				.GT_TXUSRCLK(clk_pclk),
				.GT_RXUSRCLK(clk_rxusrclk),
				.GT_TXUSRCLK2(clk_pclk),
				.GT_RXUSRCLK2(clk_rxusrclk),
				.GT_OOBCLK(oobclk[i]),
				.GT_TXSYSCLKSEL(rate_sysclksel[(2 * i) + 1:2 * i]),
				.GT_RXSYSCLKSEL(rate_sysclksel[(2 * i) + 1:2 * i]),
				.GT_CPLLPDREFCLK(gt_cpllpdrefclk),
				.GT_TXOUTCLK(gt_txoutclk[i]),
				.GT_RXOUTCLK(gt_rxoutclk[i]),
				.GT_CPLLLOCK(gt_cplllock[i]),
				.GT_RXCDRLOCK(gt_rxcdrlock[i]),
				.GT_CPLLPD(rst_cpllpd || rate_cpllpd[i]),
				.GT_CPLLRESET(rst_cpllreset || rate_cpllreset[i]),
				.GT_TXUSERRDY(rst_userrdy),
				.GT_RXUSERRDY(rst_userrdy),
				.GT_RESETOVRD(user_resetovrd[i]),
				.GT_GTTXRESET(rst_gtreset),
				.GT_GTRXRESET(rst_gtreset),
				.GT_TXPMARESET(gt_txpmareset_i[i]),
				.GT_RXPMARESET(gt_rxpmareset_i[i]),
				.GT_RXCDRRESET(user_rxcdrreset[i]),
				.GT_RXCDRFREQRESET(user_rxcdrfreqreset[i]),
				.GT_RXDFELPMRESET(user_rxdfelpmreset[i]),
				.GT_EYESCANRESET(user_eyescanreset[i]),
				.GT_TXPCSRESET(user_txpcsreset[i]),
				.GT_RXPCSRESET(user_rxpcsreset[i]),
				.GT_RXBUFRESET(user_rxbufreset[i]),
				.GT_EYESCANDATAERROR(gt_eyescandataerror[i]),
				.GT_TXRESETDONE(gt_txresetdone[i]),
				.GT_RXRESETDONE(gt_rxresetdone[i]),
				.GT_RXPMARESETDONE(gt_rxpmaresetdone[i]),
				.GT_TXDATA(PIPE_TXDATA[(32 * i) + 31:32 * i]),
				.GT_TXDATAK(PIPE_TXDATAK[(4 * i) + 3:4 * i]),
				.GT_TXP(PIPE_TXP[i]),
				.GT_TXN(PIPE_TXN[i]),
				.GT_RXP(PIPE_RXP[i]),
				.GT_RXN(PIPE_RXN[i]),
				.GT_RXDATA(PIPE_RXDATA[(32 * i) + 31:32 * i]),
				.GT_RXDATAK(PIPE_RXDATAK[(4 * i) + 3:4 * i]),
				.GT_TXDETECTRX(PIPE_TXDETECTRX),
				.GT_TXELECIDLE(PIPE_TXELECIDLE[i]),
				.GT_TXCOMPLIANCE(PIPE_TXCOMPLIANCE[i]),
				.GT_RXPOLARITY(PIPE_RXPOLARITY[i]),
				.GT_TXPOWERDOWN(PIPE_POWERDOWN[(2 * i) + 1:2 * i]),
				.GT_RXPOWERDOWN(PIPE_POWERDOWN[(2 * i) + 1:2 * i]),
				.GT_TXRATE(rate_rate[(3 * i) + 2:3 * i]),
				.GT_RXRATE(rate_rate[(3 * i) + 2:3 * i]),
				.GT_TXMARGIN(PIPE_TXMARGIN),
				.GT_TXSWING(PIPE_TXSWING),
				.GT_TXDEEMPH(PIPE_TXDEEMPH[i]),
				.GT_TXINHIBIT(PIPE_TXINHIBIT[i]),
				.GT_TXPRECURSOR(eq_txeq_precursor[(5 * i) + 4:5 * i]),
				.GT_TXMAINCURSOR(eq_txeq_maincursor[(7 * i) + 6:7 * i]),
				.GT_TXPOSTCURSOR(eq_txeq_postcursor[(5 * i) + 4:5 * i]),
				.GT_RXVALID(gt_rxvalid[i]),
				.GT_PHYSTATUS(gt_phystatus[i]),
				.GT_RXELECIDLE(gt_rxelecidle_i[i]),
				.GT_RXSTATUS(gt_rxstatus[(3 * i) + 2:3 * i]),
				.GT_RXBUFSTATUS(gt_rxbufstatus[(3 * i) + 2:3 * i]),
				.GT_TXRATEDONE(gt_txratedone[i]),
				.GT_RXRATEDONE(gt_rxratedone[i]),
				.GT_RXDISPERR(gt_rxdisperr[(8 * i) + 7:8 * i]),
				.GT_RXNOTINTABLE(gt_rxnotintable[(8 * i) + 7:8 * i]),
				.GT_DRPCLK(clk_dclk),
				.GT_DRPADDR(drp_mux_addr[(9 * i) + 8:9 * i]),
				.GT_DRPEN(drp_mux_en[i]),
				.GT_DRPDI(drp_mux_di[(16 * i) + 15:16 * i]),
				.GT_DRPWE(drp_mux_we[i]),
				.GT_DRPDO(gt_do[(16 * i) + 15:16 * i]),
				.GT_DRPRDY(gt_rdy[i]),
				.GT_TXPHALIGN(sync_txphalign[i]),
				.GT_TXPHALIGNEN(sync_txphalignen[i]),
				.GT_TXPHINIT(sync_txphinit[i]),
				.GT_TXDLYBYPASS(sync_txdlybypass[i]),
				.GT_TXDLYSRESET(sync_txdlysreset[i]),
				.GT_TXDLYEN(sync_txdlyen[i]),
				.GT_TXDLYSRESETDONE(gt_txdlysresetdone[i]),
				.GT_TXPHINITDONE(gt_txphinitdone[i]),
				.GT_TXPHALIGNDONE(gt_txphaligndone[i]),
				.GT_TXPHDLYRESET(sync_txphdlyreset[i]),
				.GT_TXSYNCMODE(i == 0),
				.GT_TXSYNCIN(gt_txsyncout[0]),
				.GT_TXSYNCALLIN(txsyncallin),
				.GT_TXSYNCOUT(gt_txsyncout[i]),
				.GT_TXSYNCDONE(gt_txsyncdone[i]),
				.GT_RXPHALIGN(sync_rxphalign[i]),
				.GT_RXPHALIGNEN(sync_rxphalignen[i]),
				.GT_RXDLYBYPASS(sync_rxdlybypass[i]),
				.GT_RXDLYSRESET(sync_rxdlysreset[i]),
				.GT_RXDLYEN(sync_rxdlyen[i]),
				.GT_RXDDIEN(sync_rxddien[i]),
				.GT_RXDLYSRESETDONE(gt_rxdlysresetdone[i]),
				.GT_RXPHALIGNDONE(gt_rxphaligndone[i]),
				.GT_RXSYNCMODE(i == 0),
				.GT_RXSYNCIN(gt_rxsyncout[0]),
				.GT_RXSYNCALLIN(rxsyncallin),
				.GT_RXSYNCOUT(gt_rxsyncout[i]),
				.GT_RXSYNCDONE(gt_rxsyncdone[i]),
				.GT_RXSLIDE(PIPE_RXSLIDE[i]),
				.GT_RXCOMMADET(gt_rxcommadet[i]),
				.GT_RXCHARISCOMMA(gt_rxchariscomma[(4 * i) + 3:4 * i]),
				.GT_RXBYTEISALIGNED(gt_rxbyteisaligned[i]),
				.GT_RXBYTEREALIGN(gt_rxbyterealign[i]),
				.GT_RXCHANISALIGNED(PIPE_RXCHANISALIGNED[i]),
				.GT_RXCHBONDEN(rxchbonden[i]),
				.GT_RXCHBONDI(gt_rxchbondi[i]),
				.GT_RXCHBONDLEVEL(gt_rxchbondlevel[(3 * i) + 2:3 * i]),
				.GT_RXCHBONDMASTER(rxchbondmaster[i]),
				.GT_RXCHBONDSLAVE(rxchbondslave[i]),
				.GT_RXCHBONDO(gt_rxchbondo[i + 1]),
				.GT_TXPRBSSEL(PIPE_TXPRBSSEL),
				.GT_RXPRBSSEL(PIPE_RXPRBSSEL),
				.GT_TXPRBSFORCEERR(PIPE_TXPRBSFORCEERR),
				.GT_RXPRBSCNTRESET(PIPE_RXPRBSCNTRESET),
				.GT_LOOPBACK(PIPE_LOOPBACK),
				.GT_RXPRBSERR(PIPE_RXPRBSERR[i]),
				.GT_DMONITOROUT(PIPE_DMONITOROUT[(15 * i) + 14:15 * i])
			);
			always @(posedge clk_rxusrclk)
				if ((PIPE_TXDETECTRX && gt_phystatus[i]) && (gt_rxstatus[(3 * i) + 2:3 * i] == 3'h3))
					gt_rxrcvrdet_c[i] <= 1'b1;
				else if ((PIPE_TXDETECTRX && gt_phystatus[i]) && (gt_rxstatus[(3 * i) + 2:3 * i] != 3'h3))
					gt_rxrcvrdet_c[i] <= 1'b0;
			initial gt_rxrcvrdet_c[i] = 1'b0;
			assign gt_rxelecidle[i] = gt_rxelecidle_i[i];
			assign oobclk[i] = user_oobclk[i];
			if (PCIE_CHAN_BOND_EN == "FALSE") begin : channel_bonding_ms_disable
				assign rxchbonden[i] = 1'd0;
				assign rxchbondmaster[i] = 1'd0;
				assign rxchbondslave[i] = 1'd0;
			end
			else begin : channel_bonding_ms_enable
				assign rxchbonden[i] = 1'd0;
				assign rxchbondmaster[i] = (rate_gen3[i] ? 1'd0 : i == 0);
				assign rxchbondslave[i] = (rate_gen3[i] ? 1'd0 : i > 0);
			end
			if (PCIE_CHAN_BOND_EN == "FALSE") begin : channel_bonding_in_disable
				assign gt_rxchbondi[i] = 5'd0;
				assign gt_rxchbondlevel[(3 * i) + 2:3 * i] = 3'd0;
			end
			else begin : channel_bonding_in_enable
				if (1) begin : channel_bonding_b
					assign gt_rxchbondi[i] = gt_rxchbondo[i];
					assign gt_rxchbondlevel[(3 * i) + 2:3 * i] = -i;
				end
			end
		end
	endgenerate
	assign PIPE_TXEQ_FS = 0;
	assign PIPE_TXEQ_LF = 0;
	assign PIPE_RXELECIDLE = gt_rxelecidle;
	assign PIPE_RXSTATUS = gt_rxstatus;
	assign PIPE_RXDISPERR = gt_rxdisperr;
	assign PIPE_RXNOTINTABLE = gt_rxnotintable;
	assign PIPE_RXPMARESETDONE = gt_rxpmaresetdone;
	assign PIPE_RXBUFSTATUS = gt_rxbufstatus;
	assign PIPE_TXPHALIGNDONE = gt_txphaligndone;
	assign PIPE_TXPHINITDONE = gt_txphinitdone;
	assign PIPE_TXDLYSRESETDONE = gt_txdlysresetdone;
	assign PIPE_RXPHALIGNDONE = gt_rxphaligndone;
	assign PIPE_RXDLYSRESETDONE = gt_rxdlysresetdone;
	assign PIPE_RXSYNCDONE = gt_rxsyncdone;
	assign PIPE_RXCOMMADET = gt_rxcommadet;
	assign PIPE_QPLL_LOCK = qpll_qplllock;
	assign PIPE_CPLL_LOCK = gt_cplllock;
	assign PIPE_PCLK = clk_pclk;
	assign PIPE_PCLK_LOCK = clk_mmcm_lock;
	assign PIPE_RXCDRLOCK = 0;
	assign PIPE_RXUSRCLK = 0;
	assign PIPE_RXOUTCLK = 0;
	assign PIPE_TXSYNC_DONE = 0;
	assign PIPE_RXSYNC_DONE = 0;
	assign PIPE_ACTIVE_LANE = 0;
	assign PIPE_TXOUTCLK_OUT = gt_txoutclk[0];
	assign PIPE_RXOUTCLK_OUT = gt_rxoutclk;
	assign PIPE_PCLK_SEL_OUT = rate_pclk_sel;
	assign PIPE_GEN3_OUT = rate_gen3[0];
	assign PIPE_RXEQ_CONVERGE = user_rx_converge;
	assign PIPE_RXEQ_ADAPT_DONE = {link_pkg_PCIE_LANES {1'd0}};
	assign PIPE_EYESCANDATAERROR = gt_eyescandataerror;
	assign PIPE_RST_FSM = rst_fsm;
	assign PIPE_QRST_FSM = qrst_fsm;
	assign PIPE_RATE_FSM = rate_fsm;
	assign PIPE_SYNC_FSM_TX = sync_fsm_tx;
	assign PIPE_SYNC_FSM_RX = sync_fsm_rx;
	assign PIPE_DRP_FSM = drp_fsm;
	assign PIPE_QDRP_FSM = 0;
	assign PIPE_RST_IDLE = &rst_idle;
	assign PIPE_QRST_IDLE = &qrst_idle;
	assign PIPE_RATE_IDLE = &rate_idle;
	assign EXT_CH_GT_DRPDO = gt_do[15:0];
	assign EXT_CH_GT_DRPRDY = gt_rdy[0:0];
	assign EXT_CH_GT_DRPCLK = clk_dclk;
	assign PIPE_DEBUG_0 = {link_pkg_PCIE_LANES {1'b0}};
	assign PIPE_DEBUG_1 = {link_pkg_PCIE_LANES {1'b0}};
	assign PIPE_DEBUG_2 = {link_pkg_PCIE_LANES {1'b0}};
	assign PIPE_DEBUG_3 = {link_pkg_PCIE_LANES {1'b0}};
	assign PIPE_DEBUG_4 = {link_pkg_PCIE_LANES {1'b0}};
	assign PIPE_DEBUG_5 = {link_pkg_PCIE_LANES {1'b0}};
	assign PIPE_DEBUG_6 = {link_pkg_PCIE_LANES {1'b0}};
	assign PIPE_DEBUG_7 = {link_pkg_PCIE_LANES {1'b0}};
	assign PIPE_DEBUG_8 = {link_pkg_PCIE_LANES {1'b0}};
	assign PIPE_DEBUG_9 = {link_pkg_PCIE_LANES {1'b0}};
	assign PIPE_DEBUG[1:0] = 2'd0;
	assign PIPE_DEBUG[5:2] = 4'd0;
	assign PIPE_DEBUG[31:6] = 26'd0;
endmodule
module signal_probe (
	RXEQSCAN_CLK,
	RXEQSCAN_RST_N,
	RXEQSCAN_CONTROL,
	RXEQSCAN_PRESET,
	RXEQSCAN_PRESET_VALID,
	RXEQSCAN_TXPRESET,
	RXEQSCAN_TXCOEFF,
	RXEQSCAN_NEW_TXCOEFF_REQ,
	RXEQSCAN_FS,
	RXEQSCAN_LF,
	RXEQSCAN_PRESET_DONE,
	RXEQSCAN_NEW_TXCOEFF,
	RXEQSCAN_NEW_TXCOEFF_DONE,
	RXEQSCAN_LFFS_SEL,
	RXEQSCAN_ADAPT_DONE
);
	reg _sv2v_0;
	localparam PCIE_GT_DEVICE = "GTP";
	localparam PCIE_RXEQ_MODE_GEN3 = 1;
	localparam CONVERGE_MAX = 22'd3125000;
	localparam CONVERGE_MAX_BYPASS = 22'd2083333;
	input RXEQSCAN_CLK;
	input RXEQSCAN_RST_N;
	input [1:0] RXEQSCAN_CONTROL;
	input [2:0] RXEQSCAN_PRESET;
	input RXEQSCAN_PRESET_VALID;
	input [3:0] RXEQSCAN_TXPRESET;
	input [17:0] RXEQSCAN_TXCOEFF;
	input RXEQSCAN_NEW_TXCOEFF_REQ;
	input [5:0] RXEQSCAN_FS;
	input [5:0] RXEQSCAN_LF;
	output wire RXEQSCAN_PRESET_DONE;
	output wire [17:0] RXEQSCAN_NEW_TXCOEFF;
	output wire RXEQSCAN_NEW_TXCOEFF_DONE;
	output wire RXEQSCAN_LFFS_SEL;
	output wire RXEQSCAN_ADAPT_DONE;
	localparam [21:0] CONV_MAX = CONVERGE_MAX;
	localparam [21:0] CONV_MAX_BYP = CONVERGE_MAX_BYPASS;
	reg [1:0] state = 2'd0;
	reg [1:0] state_nx;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [2:0] preset_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [2:0] preset_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg pvalid_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg pvalid_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [3:0] txpreset_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [3:0] txpreset_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [17:0] txcoeff_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [17:0] txcoeff_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg req_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg req_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [5:0] fs_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [5:0] fs_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [5:0] lf_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [5:0] lf_r2;
	always @(posedge RXEQSCAN_CLK)
		if (!RXEQSCAN_RST_N) begin
			preset_r1 <= 3'd0;
			pvalid_r1 <= 1'b0;
			txpreset_r1 <= 4'd0;
			txcoeff_r1 <= 18'd0;
			req_r1 <= 1'b0;
			fs_r1 <= 6'd0;
			lf_r1 <= 6'd0;
			preset_r2 <= 3'd0;
			pvalid_r2 <= 1'b0;
			txpreset_r2 <= 4'd0;
			txcoeff_r2 <= 18'd0;
			req_r2 <= 1'b0;
			fs_r2 <= 6'd0;
			lf_r2 <= 6'd0;
		end
		else begin
			preset_r1 <= RXEQSCAN_PRESET;
			preset_r2 <= preset_r1;
			pvalid_r1 <= RXEQSCAN_PRESET_VALID;
			pvalid_r2 <= pvalid_r1;
			txpreset_r1 <= RXEQSCAN_TXPRESET;
			txpreset_r2 <= txpreset_r1;
			txcoeff_r1 <= RXEQSCAN_TXCOEFF;
			txcoeff_r2 <= txcoeff_r1;
			req_r1 <= RXEQSCAN_NEW_TXCOEFF_REQ;
			req_r2 <= req_r1;
			fs_r1 <= RXEQSCAN_FS;
			fs_r2 <= fs_r1;
			lf_r1 <= RXEQSCAN_LF;
			lf_r2 <= lf_r1;
		end
	reg preset_done = 1'b0;
	reg preset_done_nx;
	reg [21:0] converge_cnt = 22'd0;
	reg [21:0] converge_cnt_nx;
	reg [17:0] new_txcoeff = 18'd0;
	reg [17:0] new_txcoeff_nx;
	reg new_txcoeff_done = 1'b0;
	reg new_txcoeff_done_nx;
	reg lffs_sel = 1'b0;
	reg lffs_sel_nx;
	reg adapt_done = 1'b0;
	reg adapt_done_nx;
	reg adapt_done_cnt = 1'b0;
	reg adapt_done_cnt_nx;
	wire [17:0] coeff_on_req = 18'd4;
	wire lffs_on_req = 1'b1;
	always @(*) begin
		if (_sv2v_0)
			;
		state_nx = state;
		preset_done_nx = 1'b0;
		converge_cnt_nx = 22'd0;
		new_txcoeff_nx = new_txcoeff;
		new_txcoeff_done_nx = 1'b0;
		lffs_sel_nx = 1'b0;
		adapt_done_nx = 1'b0;
		adapt_done_cnt_nx = adapt_done_cnt;
		(* full_case, parallel_case *)
		case (state)
			2'd0:
				if (pvalid_r2) begin
					state_nx = 2'd1;
					preset_done_nx = 1'b1;
				end
				else if (req_r2) begin
					state_nx = 2'd2;
					new_txcoeff_nx = coeff_on_req;
					lffs_sel_nx = lffs_on_req;
				end
			2'd1: begin
				state_nx = (!pvalid_r2 ? 2'd0 : 2'd1);
				preset_done_nx = 1'b1;
			end
			2'd2:
				if ((adapt_done_cnt == 1'b0) && (RXEQSCAN_CONTROL == 2'd2)) begin
					state_nx = 2'd3;
					lffs_sel_nx = lffs_sel;
				end
				else begin
					if (RXEQSCAN_CONTROL == 2'd2)
						state_nx = (converge_cnt == CONV_MAX ? 2'd3 : 2'd2);
					else
						state_nx = (converge_cnt == CONV_MAX_BYP ? 2'd3 : 2'd2);
					converge_cnt_nx = converge_cnt + 22'd1;
					lffs_sel_nx = lffs_sel;
				end
			2'd3:
				if (!req_r2) begin
					state_nx = 2'd0;
					lffs_sel_nx = lffs_sel;
					adapt_done_cnt_nx = (RXEQSCAN_CONTROL == 2'd3 ? 1'b0 : adapt_done_cnt + 1'b1);
				end
				else begin
					state_nx = 2'd3;
					new_txcoeff_done_nx = 1'b1;
					lffs_sel_nx = lffs_sel;
					adapt_done_nx = (adapt_done_cnt == 1'b1) || (RXEQSCAN_CONTROL == 2'd3);
				end
			default: begin
				state_nx = 2'd0;
				new_txcoeff_nx = 18'd0;
				adapt_done_cnt_nx = 1'b0;
			end
		endcase
	end
	always @(posedge RXEQSCAN_CLK)
		if (!RXEQSCAN_RST_N) begin
			state <= 2'd0;
			preset_done <= 1'b0;
			converge_cnt <= 22'd0;
			new_txcoeff <= 18'd0;
			new_txcoeff_done <= 1'b0;
			lffs_sel <= 1'b0;
			adapt_done <= 1'b0;
			adapt_done_cnt <= 1'b0;
		end
		else begin
			state <= state_nx;
			preset_done <= preset_done_nx;
			converge_cnt <= converge_cnt_nx;
			new_txcoeff <= new_txcoeff_nx;
			new_txcoeff_done <= new_txcoeff_done_nx;
			lffs_sel <= lffs_sel_nx;
			adapt_done <= adapt_done_nx;
			adapt_done_cnt <= adapt_done_cnt_nx;
		end
	assign RXEQSCAN_PRESET_DONE = preset_done;
	assign RXEQSCAN_NEW_TXCOEFF = new_txcoeff;
	assign RXEQSCAN_NEW_TXCOEFF_DONE = new_txcoeff_done;
	assign RXEQSCAN_LFFS_SEL = lffs_sel;
	assign RXEQSCAN_ADAPT_DONE = adapt_done;
	initial _sv2v_0 = 0;
endmodule
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
module speed_ctrl (
	RATE_CLK,
	RATE_RST_N,
	RATE_RATE_IN,
	RATE_DRP_DONE,
	RATE_RXPMARESETDONE,
	RATE_TXRATEDONE,
	RATE_RXRATEDONE,
	RATE_TXSYNC_DONE,
	RATE_PHYSTATUS,
	RATE_PCLK_SEL,
	RATE_DRP_START,
	RATE_DRP_X16,
	RATE_RATE_OUT,
	RATE_TXSYNC_START,
	RATE_DONE,
	RATE_IDLE,
	RATE_FSM
);
	reg _sv2v_0;
	localparam TXDATA_WAIT_MAX = 4'd15;
	input RATE_CLK;
	input RATE_RST_N;
	input [1:0] RATE_RATE_IN;
	input RATE_DRP_DONE;
	input RATE_RXPMARESETDONE;
	input RATE_TXRATEDONE;
	input RATE_RXRATEDONE;
	input RATE_TXSYNC_DONE;
	input RATE_PHYSTATUS;
	output wire RATE_PCLK_SEL;
	output wire RATE_DRP_START;
	output wire RATE_DRP_X16;
	output wire [2:0] RATE_RATE_OUT;
	output wire RATE_TXSYNC_START;
	output wire RATE_DONE;
	output wire RATE_IDLE;
	output wire [4:0] RATE_FSM;
	reg [3:0] state = 4'd0;
	reg [3:0] state_nx;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [1:0] rate_in_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg [1:0] rate_in_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg drp_done_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg drp_done_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg rxpma_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg rxpma_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txrate_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txrate_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg rxrate_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg rxrate_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg phy_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg phy_r2;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txsync_r1;
	(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *) reg txsync_r2;
	always @(posedge RATE_CLK)
		if (!RATE_RST_N) begin
			{rate_in_r1, drp_done_r1, rxpma_r1, txrate_r1, rxrate_r1, phy_r1, txsync_r1} <= 1'sb0;
			{rate_in_r2, drp_done_r2, rxpma_r2, txrate_r2, rxrate_r2, phy_r2, txsync_r2} <= 1'sb0;
		end
		else begin
			rate_in_r1 <= RATE_RATE_IN;
			rate_in_r2 <= rate_in_r1;
			drp_done_r1 <= RATE_DRP_DONE;
			drp_done_r2 <= drp_done_r1;
			rxpma_r1 <= RATE_RXPMARESETDONE;
			rxpma_r2 <= rxpma_r1;
			txrate_r1 <= RATE_TXRATEDONE;
			txrate_r2 <= txrate_r1;
			rxrate_r1 <= RATE_RXRATEDONE;
			rxrate_r2 <= rxrate_r1;
			phy_r1 <= RATE_PHYSTATUS;
			phy_r2 <= phy_r1;
			txsync_r1 <= RATE_TXSYNC_DONE;
			txsync_r2 <= txsync_r1;
		end
	wire [2:0] rate = (rate_in_r2 == 2'd1 ? 3'd1 : 3'd0);
	reg [3:0] txdata_wait_cnt = 4'd0;
	always @(posedge RATE_CLK)
		if (!RATE_RST_N)
			txdata_wait_cnt <= 4'd0;
		else if (state != 4'd1)
			txdata_wait_cnt <= 4'd0;
		else if (txdata_wait_cnt < TXDATA_WAIT_MAX)
			txdata_wait_cnt <= txdata_wait_cnt + 4'd1;
	wire txdata_wait_done = txdata_wait_cnt == TXDATA_WAIT_MAX;
	reg txratedone = 1'b0;
	reg rxratedone = 1'b0;
	reg phystatus = 1'b0;
	reg ratedone = 1'b0;
	wire latch_phase = (((state == 4'd9) || (state == 4'd6)) || (state == 4'd7)) || (state == 4'd8);
	always @(posedge RATE_CLK)
		if (!RATE_RST_N) begin
			txratedone <= 1'b0;
			rxratedone <= 1'b0;
			phystatus <= 1'b0;
			ratedone <= 1'b0;
		end
		else if (latch_phase) begin
			if (txrate_r2)
				txratedone <= 1'b1;
			if (rxrate_r2)
				rxratedone <= 1'b1;
			if (phy_r2)
				phystatus <= 1'b1;
			if ((rxratedone && txratedone) && phystatus)
				ratedone <= 1'b1;
		end
		else begin
			txratedone <= 1'b0;
			rxratedone <= 1'b0;
			phystatus <= 1'b0;
			ratedone <= 1'b0;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		state_nx = state;
		(* full_case, parallel_case *)
		case (state)
			4'd0: state_nx = (rate_in_r2 != rate_in_r1 ? 4'd1 : 4'd0);
			4'd1: state_nx = (txdata_wait_done ? 4'd2 : 4'd1);
			4'd2: state_nx = 4'd3;
			4'd3: state_nx = (!drp_done_r2 ? 4'd4 : 4'd3);
			4'd4: state_nx = (drp_done_r2 ? 4'd5 : 4'd4);
			4'd5: state_nx = 4'd6;
			4'd6: state_nx = (!rxpma_r2 ? 4'd7 : 4'd6);
			4'd7: state_nx = (!drp_done_r2 ? 4'd8 : 4'd7);
			4'd8: state_nx = (drp_done_r2 ? 4'd9 : 4'd8);
			4'd9: state_nx = (ratedone ? 4'd10 : 4'd9);
			4'd10: state_nx = (!txsync_r2 ? 4'd11 : 4'd10);
			4'd11: state_nx = (txsync_r2 ? 4'd12 : 4'd11);
			4'd12: state_nx = 4'd0;
			default: state_nx = 4'd0;
		endcase
	end
	reg pclk_sel = 1'b0;
	reg [2:0] rate_out = 3'd0;
	wire pclk_sel_d = (state == 4'd2 ? rate_in_r2 == 2'd1 : pclk_sel);
	wire [2:0] rate_out_d = (state == 4'd5 ? rate : rate_out);
	always @(posedge RATE_CLK)
		if (!RATE_RST_N) begin
			state <= 4'd0;
			pclk_sel <= 1'b0;
			rate_out <= 3'd0;
		end
		else begin
			state <= state_nx;
			pclk_sel <= pclk_sel_d;
			rate_out <= rate_out_d;
		end
	assign RATE_PCLK_SEL = pclk_sel;
	assign RATE_DRP_START = (state == 4'd3) || (state == 4'd7);
	assign RATE_DRP_X16 = (state == 4'd3) || (state == 4'd4);
	assign RATE_RATE_OUT = rate_out;
	assign RATE_TXSYNC_START = state == 4'd10;
	assign RATE_DONE = state == 4'd12;
	assign RATE_IDLE = state == 4'd0;
	assign RATE_FSM = {1'b0, state};
	initial _sv2v_0 = 0;
endmodule
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
module stream_tx_gate (
	s_axis_tx_tdata,
	s_axis_tx_tvalid,
	s_axis_tx_tuser,
	s_axis_tx_tlast,
	user_turnoff_ok,
	user_tcfg_gnt,
	trn_tbuf_av,
	trn_tdst_rdy,
	trn_tcfg_req,
	trn_tcfg_gnt,
	trn_lnk_up,
	cfg_pcie_link_state,
	cfg_pm_send_pme_to,
	cfg_pmcsr_powerstate,
	trn_rdllp_data,
	trn_rdllp_src_rdy,
	cfg_to_turnoff,
	cfg_turnoff_ok,
	tready_thrtl,
	user_clk,
	user_rst
);
	reg _sv2v_0;
	localparam signed [31:0] C_DATA_WIDTH = 64;
	input [63:0] s_axis_tx_tdata;
	input s_axis_tx_tvalid;
	input [3:0] s_axis_tx_tuser;
	input s_axis_tx_tlast;
	input user_turnoff_ok;
	input user_tcfg_gnt;
	input [5:0] trn_tbuf_av;
	input trn_tdst_rdy;
	input trn_tcfg_req;
	output wire trn_tcfg_gnt;
	input trn_lnk_up;
	input [2:0] cfg_pcie_link_state;
	input cfg_pm_send_pme_to;
	input [1:0] cfg_pmcsr_powerstate;
	input [31:0] trn_rdllp_data;
	input trn_rdllp_src_rdy;
	input cfg_to_turnoff;
	output reg cfg_turnoff_ok;
	output reg tready_thrtl;
	input user_clk;
	input user_rst;
	localparam TBUF_AV_MIN = 1;
	localparam TBUF_AV_GAP = 2;
	localparam TBUF_GAP_TIME = 1;
	localparam TCFG_LATENCY_TIME = 2'd2;
	reg lnk_up_thrtl;
	wire lnk_up_trig;
	wire lnk_up_exit;
	reg tbuf_av_min_thrtl;
	wire tbuf_av_min_trig;
	reg tbuf_av_gap_thrtl;
	reg [2:0] tbuf_gap_cnt;
	wire tbuf_av_gap_trig;
	wire tbuf_av_gap_exit;
	wire gap_trig_tlast;
	wire gap_trig_decr;
	wire gap_trig_tcfg;
	reg [5:0] tbuf_av_d;
	reg tcfg_req_thrtl;
	reg [1:0] tcfg_req_cnt;
	reg trn_tdst_rdy_d;
	wire tcfg_req_trig;
	wire tcfg_req_exit;
	reg tcfg_gnt_log;
	wire pre_throttle;
	wire reg_throttle;
	wire exit_crit;
	reg reg_tcfg_gnt;
	reg trn_tcfg_req_d;
	reg tcfg_gnt_pending;
	wire wire_to_turnoff;
	reg reg_turnoff_ok;
	reg tready_thrtl_mux;
	localparam LINKSTATE_L0 = 3'b000;
	localparam LINKSTATE_PPM_L1_TRANS = 3'b101;
	reg ppm_L1_thrtl;
	wire ppm_L1_trig;
	wire ppm_L1_exit;
	reg [2:0] cfg_pcie_link_state_d;
	reg trn_rdllp_src_rdy_d;
	reg ppm_L23_thrtl;
	wire ppm_L23_trig;
	reg cfg_turnoff_ok_pending;
	reg reg_tlast;
	localparam IDLE = 0;
	localparam THROTTLE = 1;
	reg cur_state;
	reg next_state;
	reg reg_axi_in_pkt;
	wire axi_in_pkt;
	wire axi_pkt_ending;
	wire axi_throttled;
	wire axi_thrtl_ok;
	wire tx_ecrc_pause;
	assign lnk_up_trig = !trn_lnk_up;
	assign lnk_up_exit = trn_tdst_rdy;
	always @(posedge user_clk)
		if (user_rst)
			lnk_up_thrtl <= 1'b1;
		else if (lnk_up_trig)
			lnk_up_thrtl <= 1'b1;
		else if (lnk_up_exit)
			lnk_up_thrtl <= 1'b0;
	assign tbuf_av_min_trig = trn_tbuf_av <= TBUF_AV_MIN;
	always @(posedge user_clk)
		if (user_rst)
			tbuf_av_min_thrtl <= 1'b0;
		else if (tbuf_av_min_trig)
			tbuf_av_min_thrtl <= 1'b1;
		else
			tbuf_av_min_thrtl <= 1'b0;
	assign gap_trig_tlast = (((trn_tbuf_av <= TBUF_AV_GAP) && s_axis_tx_tvalid) && tready_thrtl) && s_axis_tx_tlast;
	assign gap_trig_decr = (trn_tbuf_av == TBUF_AV_GAP) && (tbuf_av_d == 3);
	assign gap_trig_tcfg = tcfg_req_thrtl && tcfg_req_exit;
	assign tbuf_av_gap_trig = (gap_trig_tlast || gap_trig_decr) || gap_trig_tcfg;
	assign tbuf_av_gap_exit = tbuf_gap_cnt == 0;
	always @(posedge user_clk)
		if (user_rst) begin
			tbuf_av_gap_thrtl <= 1'b0;
			tbuf_gap_cnt <= 3'h0;
			tbuf_av_d <= 6'h00;
		end
		else begin
			if (tbuf_av_gap_trig)
				tbuf_av_gap_thrtl <= 1'b1;
			else if (tbuf_av_gap_exit)
				tbuf_av_gap_thrtl <= 1'b0;
			if (tbuf_av_gap_thrtl && (cur_state == THROTTLE)) begin
				if (tbuf_gap_cnt > 0)
					tbuf_gap_cnt <= tbuf_gap_cnt - 3'd1;
			end
			else
				tbuf_gap_cnt <= TBUF_GAP_TIME;
			tbuf_av_d <= trn_tbuf_av;
		end
	assign tcfg_req_trig = trn_tcfg_req && reg_tcfg_gnt;
	assign tcfg_req_exit = ((tcfg_req_cnt == 2'd0) && !trn_tdst_rdy_d) && trn_tdst_rdy;
	always @(posedge user_clk)
		if (user_rst) begin
			tcfg_req_thrtl <= 1'b0;
			trn_tcfg_req_d <= 1'b0;
			trn_tdst_rdy_d <= 1'b1;
			reg_tcfg_gnt <= 1'b0;
			tcfg_req_cnt <= 2'd0;
			tcfg_gnt_pending <= 1'b0;
		end
		else begin
			if (tcfg_req_trig)
				tcfg_req_thrtl <= 1'b1;
			else if (tcfg_req_exit)
				tcfg_req_thrtl <= 1'b0;
			if ((trn_tcfg_req && !trn_tcfg_req_d) || tcfg_gnt_pending)
				tcfg_req_cnt <= TCFG_LATENCY_TIME;
			else if (tcfg_req_cnt > 0)
				tcfg_req_cnt <= tcfg_req_cnt - 2'd1;
			if (trn_tcfg_req && !trn_tcfg_req_d)
				tcfg_gnt_pending <= 1'b1;
			else if (tcfg_gnt_log)
				tcfg_gnt_pending <= 1'b0;
			trn_tcfg_req_d <= trn_tcfg_req;
			trn_tdst_rdy_d <= trn_tdst_rdy;
			reg_tcfg_gnt <= user_tcfg_gnt;
		end
	assign ppm_L1_trig = (cfg_pcie_link_state_d == LINKSTATE_L0) && (cfg_pcie_link_state == LINKSTATE_PPM_L1_TRANS);
	assign ppm_L1_exit = cfg_pcie_link_state == LINKSTATE_L0;
	always @(posedge user_clk)
		if (user_rst) begin
			ppm_L1_thrtl <= 1'b0;
			cfg_pcie_link_state_d <= 3'b000;
			trn_rdllp_src_rdy_d <= 1'b0;
		end
		else begin
			if (ppm_L1_trig)
				ppm_L1_thrtl <= 1'b1;
			else if (ppm_L1_exit)
				ppm_L1_thrtl <= 1'b0;
			cfg_pcie_link_state_d <= cfg_pcie_link_state;
			trn_rdllp_src_rdy_d <= trn_rdllp_src_rdy;
		end
	assign ppm_L23_trig = wire_to_turnoff && reg_turnoff_ok;
	reg reg_to_turnoff;
	always @(posedge user_clk)
		if (user_rst)
			reg_to_turnoff <= 1'b0;
		else if (cfg_to_turnoff)
			reg_to_turnoff <= 1'b1;
	assign wire_to_turnoff = reg_to_turnoff;
	always @(posedge user_clk)
		if (user_rst)
			reg_turnoff_ok <= 1'b0;
		else
			reg_turnoff_ok <= user_turnoff_ok;
	always @(posedge user_clk)
		if (user_rst) begin
			ppm_L23_thrtl <= 1'b0;
			cfg_turnoff_ok_pending <= 1'b0;
		end
		else begin
			if (ppm_L23_trig)
				ppm_L23_thrtl <= 1'b1;
			if (ppm_L23_trig && !ppm_L23_thrtl)
				cfg_turnoff_ok_pending <= 1'b1;
			else if (cfg_turnoff_ok)
				cfg_turnoff_ok_pending <= 1'b0;
		end
	always @(posedge user_clk)
		if (user_rst)
			reg_axi_in_pkt <= 1'b0;
		else if (s_axis_tx_tvalid && s_axis_tx_tlast)
			reg_axi_in_pkt <= 1'b0;
		else if (tready_thrtl && s_axis_tx_tvalid)
			reg_axi_in_pkt <= 1'b1;
	assign axi_in_pkt = s_axis_tx_tvalid || reg_axi_in_pkt;
	assign axi_pkt_ending = s_axis_tx_tvalid && s_axis_tx_tlast;
	assign axi_throttled = !tready_thrtl;
	assign axi_thrtl_ok = (!axi_in_pkt || axi_pkt_ending) || axi_throttled;
	assign pre_throttle = ((((tbuf_av_min_trig || tbuf_av_gap_trig) || lnk_up_trig) || tcfg_req_trig) || ppm_L1_trig) || ppm_L23_trig;
	assign reg_throttle = ((((tbuf_av_min_thrtl || tbuf_av_gap_thrtl) || lnk_up_thrtl) || tcfg_req_thrtl) || ppm_L1_thrtl) || ppm_L23_thrtl;
	assign exit_crit = ((((!tbuf_av_min_thrtl && !tbuf_av_gap_thrtl) && !lnk_up_thrtl) && !tcfg_req_thrtl) && !ppm_L1_thrtl) && !ppm_L23_thrtl;
	always @(*) begin
		if (_sv2v_0)
			;
		case (cur_state)
			IDLE:
				if (reg_throttle && axi_thrtl_ok) begin
					tready_thrtl_mux = 1'b0;
					next_state = THROTTLE;
					if (tcfg_req_thrtl) begin
						tcfg_gnt_log = 1'b1;
						cfg_turnoff_ok = 1'b0;
					end
					else if (ppm_L23_thrtl) begin
						tcfg_gnt_log = 1'b0;
						cfg_turnoff_ok = 1'b1;
					end
					else begin
						tcfg_gnt_log = 1'b0;
						cfg_turnoff_ok = 1'b0;
					end
				end
				else begin
					tready_thrtl_mux = !(axi_thrtl_ok && pre_throttle);
					next_state = IDLE;
					tcfg_gnt_log = 1'b0;
					cfg_turnoff_ok = 1'b0;
				end
			THROTTLE: begin
				if (exit_crit) begin
					tready_thrtl_mux = !pre_throttle;
					next_state = IDLE;
				end
				else begin
					tready_thrtl_mux = 1'b0;
					next_state = THROTTLE;
				end
				if (tcfg_req_thrtl && tcfg_gnt_pending) begin
					tcfg_gnt_log = 1'b1;
					cfg_turnoff_ok = 1'b0;
				end
				else if (cfg_turnoff_ok_pending) begin
					tcfg_gnt_log = 1'b0;
					cfg_turnoff_ok = 1'b1;
				end
				else begin
					tcfg_gnt_log = 1'b0;
					cfg_turnoff_ok = 1'b0;
				end
			end
			default: begin
				tready_thrtl_mux = 1'b0;
				next_state = IDLE;
				tcfg_gnt_log = 1'b0;
				cfg_turnoff_ok = 1'b0;
			end
		endcase
	end
	always @(posedge user_clk)
		if (user_rst) begin
			cur_state <= THROTTLE;
			reg_tlast <= 1'b0;
			tready_thrtl <= 1'b0;
		end
		else begin
			cur_state <= next_state;
			tready_thrtl <= tready_thrtl_mux && !tx_ecrc_pause;
			reg_tlast <= s_axis_tx_tlast;
		end
	wire tx_ecrc_pkt;
	reg reg_tx_ecrc_pkt;
	wire [1:0] packet_fmt;
	wire packet_td;
	wire [2:0] header_len;
	wire [9:0] payload_len;
	wire [13:0] packet_len;
	wire pause_needed;
	assign packet_fmt = s_axis_tx_tdata[30:29];
	assign packet_td = s_axis_tx_tdata[15];
	assign header_len = (packet_fmt[0] ? 3'd4 : 3'd3);
	assign payload_len = (packet_fmt[1] ? s_axis_tx_tdata[9:0] : 10'h000);
	assign packet_len = {10'h000, header_len} + {4'h0, payload_len};
	assign pause_needed = (packet_len[0] == 1'b0) && !packet_td;
	assign tx_ecrc_pkt = (((s_axis_tx_tuser[0] && pause_needed) && tready_thrtl) && s_axis_tx_tvalid) && !reg_axi_in_pkt;
	always @(posedge user_clk)
		if (user_rst)
			reg_tx_ecrc_pkt <= 1'b0;
		else if (tx_ecrc_pkt && !s_axis_tx_tlast)
			reg_tx_ecrc_pkt <= 1'b1;
		else if ((tready_thrtl && s_axis_tx_tvalid) && s_axis_tx_tlast)
			reg_tx_ecrc_pkt <= 1'b0;
	assign tx_ecrc_pause = (((tx_ecrc_pkt || reg_tx_ecrc_pkt) && s_axis_tx_tlast) && s_axis_tx_tvalid) && tready_thrtl;
	assign trn_tcfg_gnt = tcfg_gnt_log;
	initial _sv2v_0 = 0;
endmodule
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
module wake_timer (
	i_ibufds_gte2,
	o_cpllpd_ovrd,
	o_cpllreset_ovrd
);
	input wire i_ibufds_gte2;
	output wire o_cpllpd_ovrd;
	output wire o_cpllreset_ovrd;
	(* equivalent_register_removal = "no" *) reg [95:0] cpllpd_wait = 96'hffffffffffffffffffffffff;
	(* equivalent_register_removal = "no" *) reg [127:0] cpllreset_wait = 128'h000000000000000000000000000000ff;
	always @(posedge i_ibufds_gte2) begin
		cpllpd_wait <= {cpllpd_wait[94:0], 1'b0};
		cpllreset_wait <= {cpllreset_wait[126:0], 1'b0};
	end
	assign o_cpllpd_ovrd = cpllpd_wait[95];
	assign o_cpllreset_ovrd = cpllreset_wait[127];
endmodule
module csr (
	clk,
	rst,
	s_cpuif_req,
	s_cpuif_req_is_wr,
	s_cpuif_addr,
	s_cpuif_wr_data,
	s_cpuif_wr_biten,
	s_cpuif_req_stall_wr,
	s_cpuif_req_stall_rd,
	s_cpuif_rd_ack,
	s_cpuif_rd_err,
	s_cpuif_rd_data,
	s_cpuif_wr_ack,
	s_cpuif_wr_err,
	hwif_in,
	hwif_out
);
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	input wire s_cpuif_req;
	input wire s_cpuif_req_is_wr;
	input wire [5:0] s_cpuif_addr;
	input wire [31:0] s_cpuif_wr_data;
	input wire [31:0] s_cpuif_wr_biten;
	output wire s_cpuif_req_stall_wr;
	output wire s_cpuif_req_stall_rd;
	output wire s_cpuif_rd_ack;
	output wire s_cpuif_rd_err;
	output wire [31:0] s_cpuif_rd_data;
	output wire s_cpuif_wr_ack;
	output wire s_cpuif_wr_err;
	input wire [95:0] hwif_in;
	output wire [128:0] hwif_out;
	wire cpuif_req;
	wire cpuif_req_is_wr;
	wire [5:0] cpuif_addr;
	wire [31:0] cpuif_wr_data;
	wire [31:0] cpuif_wr_biten;
	wire cpuif_req_stall_wr;
	wire cpuif_req_stall_rd;
	wire cpuif_rd_ack;
	wire cpuif_rd_err;
	wire [31:0] cpuif_rd_data;
	wire cpuif_wr_ack;
	wire cpuif_wr_err;
	assign cpuif_req = s_cpuif_req;
	assign cpuif_req_is_wr = s_cpuif_req_is_wr;
	assign cpuif_addr = s_cpuif_addr;
	assign cpuif_wr_data = s_cpuif_wr_data;
	assign cpuif_wr_biten = s_cpuif_wr_biten;
	assign s_cpuif_req_stall_wr = cpuif_req_stall_wr;
	assign s_cpuif_req_stall_rd = cpuif_req_stall_rd;
	assign s_cpuif_rd_ack = cpuif_rd_ack;
	assign s_cpuif_rd_err = cpuif_rd_err;
	assign s_cpuif_rd_data = cpuif_rd_data;
	assign s_cpuif_wr_ack = cpuif_wr_ack;
	assign s_cpuif_wr_err = cpuif_wr_err;
	wire cpuif_req_masked;
	assign cpuif_req_stall_rd = 1'sb0;
	assign cpuif_req_stall_wr = 1'sb0;
	assign cpuif_req_masked = (cpuif_req & !(!cpuif_req_is_wr & cpuif_req_stall_rd)) & !(cpuif_req_is_wr & cpuif_req_stall_wr);
	reg [8:0] decoded_reg_strb;
	reg decoded_err;
	wire [5:0] decoded_addr;
	wire decoded_req;
	wire decoded_req_is_wr;
	wire [31:0] decoded_wr_data;
	wire [31:0] decoded_wr_biten;
	always @(*) begin : sv2v_autoblock_1
		reg is_valid_addr;
		reg is_valid_rw;
		if (_sv2v_0)
			;
		is_valid_addr = 1'sb1;
		is_valid_rw = 1'sb1;
		decoded_reg_strb[8] = cpuif_req_masked & (cpuif_addr == 6'h00);
		decoded_reg_strb[7] = cpuif_req_masked & (cpuif_addr == 6'h04);
		decoded_reg_strb[6] = cpuif_req_masked & (cpuif_addr == 6'h08);
		decoded_reg_strb[5] = cpuif_req_masked & (cpuif_addr == 6'h0c);
		decoded_reg_strb[4] = (cpuif_req_masked & (cpuif_addr == 6'h10)) & !cpuif_req_is_wr;
		decoded_reg_strb[3] = (cpuif_req_masked & (cpuif_addr == 6'h14)) & !cpuif_req_is_wr;
		decoded_reg_strb[2] = (cpuif_req_masked & (cpuif_addr == 6'h18)) & !cpuif_req_is_wr;
		decoded_reg_strb[1] = (cpuif_req_masked & (cpuif_addr == 6'h1c)) & !cpuif_req_is_wr;
		decoded_reg_strb[0] = (cpuif_req_masked & (cpuif_addr == 6'h20)) & !cpuif_req_is_wr;
		decoded_err = 1'sb0;
	end
	assign decoded_addr = cpuif_addr;
	assign decoded_req = cpuif_req_masked;
	assign decoded_req_is_wr = cpuif_req_is_wr;
	assign decoded_wr_data = cpuif_wr_data;
	assign decoded_wr_biten = cpuif_wr_biten;
	reg [202:0] field_combo;
	reg [193:0] field_storage;
	always @(*) begin : sv2v_autoblock_2
		reg [31:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[193-:32];
		load_next_c = 1'sb0;
		if (decoded_reg_strb[8] && decoded_req_is_wr) begin
			next_c = (field_storage[193-:32] & ~decoded_wr_biten[31:0]) | (decoded_wr_data[31:0] & decoded_wr_biten[31:0]);
			load_next_c = 1'sb1;
		end
		field_combo[202-:32] = next_c;
		field_combo[170] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[193-:32] <= 32'h00000000;
		else if (field_combo[170])
			field_storage[193-:32] <= field_combo[202-:32];
	assign hwif_out[128-:32] = field_storage[193-:32];
	always @(*) begin : sv2v_autoblock_3
		reg [31:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[161-:32];
		load_next_c = 1'sb0;
		if (decoded_reg_strb[7] && decoded_req_is_wr) begin
			next_c = (field_storage[161-:32] & ~decoded_wr_biten[31:0]) | (decoded_wr_data[31:0] & decoded_wr_biten[31:0]);
			load_next_c = 1'sb1;
		end
		field_combo[169-:32] = next_c;
		field_combo[137] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[161-:32] <= 32'h00000000;
		else if (field_combo[137])
			field_storage[161-:32] <= field_combo[169-:32];
	assign hwif_out[96-:32] = field_storage[161-:32];
	always @(*) begin : sv2v_autoblock_4
		reg [31:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[129-:32];
		load_next_c = 1'sb0;
		if (decoded_reg_strb[6] && decoded_req_is_wr) begin
			next_c = (field_storage[129-:32] & ~decoded_wr_biten[31:0]) | (decoded_wr_data[31:0] & decoded_wr_biten[31:0]);
			load_next_c = 1'sb1;
		end
		field_combo[136-:32] = next_c;
		field_combo[104] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[129-:32] <= 32'h00000000;
		else if (field_combo[104])
			field_storage[129-:32] <= field_combo[136-:32];
	assign hwif_out[64-:32] = field_storage[129-:32];
	always @(*) begin : sv2v_autoblock_5
		reg [31:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[97-:32];
		load_next_c = 1'sb0;
		if (decoded_reg_strb[5] && decoded_req_is_wr) begin
			next_c = (field_storage[97-:32] & ~decoded_wr_biten[31:0]) | (decoded_wr_data[31:0] & decoded_wr_biten[31:0]);
			load_next_c = 1'sb1;
		end
		field_combo[103-:32] = next_c;
		field_combo[71] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[97-:32] <= 32'h00000000;
		else if (field_combo[71])
			field_storage[97-:32] <= field_combo[103-:32];
	assign hwif_out[32-:32] = field_storage[97-:32];
	assign hwif_out[0] = (decoded_reg_strb[5] && decoded_req_is_wr) && |decoded_wr_biten[31:0];
	always @(*) begin : sv2v_autoblock_6
		reg [2:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[65-:3];
		load_next_c = 1'sb0;
		if (hwif_in[92]) begin
			next_c = hwif_in[95-:3];
			load_next_c = 1'sb1;
		end
		field_combo[70-:3] = next_c;
		field_combo[67] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[65-:3] <= 3'h0;
		else if (field_combo[67])
			field_storage[65-:3] <= field_combo[70-:3];
	always @(*) begin : sv2v_autoblock_7
		reg [31:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[62-:32];
		load_next_c = 1'sb0;
		if (hwif_in[59]) begin
			next_c = hwif_in[91-:32];
			load_next_c = 1'sb1;
		end
		field_combo[66-:32] = next_c;
		field_combo[34] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[62-:32] <= 32'h00000000;
		else if (field_combo[34])
			field_storage[62-:32] <= field_combo[66-:32];
	always @(*) begin : sv2v_autoblock_8
		reg [6:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[30-:7];
		load_next_c = 1'sb0;
		if (hwif_in[51]) begin
			next_c = hwif_in[58-:7];
			load_next_c = 1'sb1;
		end
		field_combo[33-:7] = next_c;
		field_combo[26] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[30-:7] <= 7'h00;
		else if (field_combo[26])
			field_storage[30-:7] <= field_combo[33-:7];
	always @(*) begin : sv2v_autoblock_9
		reg [7:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[23-:8];
		load_next_c = 1'sb0;
		if (hwif_in[42]) begin
			next_c = hwif_in[50-:8];
			load_next_c = 1'sb1;
		end
		field_combo[25-:8] = next_c;
		field_combo[17] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[23-:8] <= 8'h00;
		else if (field_combo[17])
			field_storage[23-:8] <= field_combo[25-:8];
	always @(*) begin : sv2v_autoblock_10
		reg [15:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[15-:16];
		load_next_c = 1'sb0;
		if (hwif_in[25]) begin
			next_c = hwif_in[41-:16];
			load_next_c = 1'sb1;
		end
		field_combo[16-:16] = next_c;
		field_combo[0] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[15-:16] <= 16'h0000;
		else if (field_combo[0])
			field_storage[15-:16] <= field_combo[16-:16];
	assign cpuif_wr_ack = decoded_req & decoded_req_is_wr;
	assign cpuif_wr_err = 1'sb0;
	wire [5:0] rd_mux_addr;
	assign rd_mux_addr = decoded_addr;
	reg readback_err;
	reg readback_done;
	reg [31:0] readback_data;
	always @(*) begin : sv2v_autoblock_11
		reg [31:0] readback_data_var;
		if (_sv2v_0)
			;
		readback_data_var = 1'sb0;
		if (rd_mux_addr == 6'h00)
			readback_data_var[31:0] = field_storage[193-:32];
		if (rd_mux_addr == 6'h04)
			readback_data_var[31:0] = field_storage[161-:32];
		if (rd_mux_addr == 6'h08)
			readback_data_var[31:0] = field_storage[129-:32];
		if (rd_mux_addr == 6'h0c)
			readback_data_var[31:0] = field_storage[97-:32];
		if (rd_mux_addr == 6'h10)
			readback_data_var[2:0] = field_storage[65-:3];
		if (rd_mux_addr == 6'h14)
			readback_data_var[31:0] = field_storage[62-:32];
		if (rd_mux_addr == 6'h18) begin
			readback_data_var[6:0] = field_storage[30-:7];
			readback_data_var[15:8] = field_storage[23-:8];
			readback_data_var[31:16] = field_storage[15-:16];
		end
		if (rd_mux_addr == 6'h1c) begin
			readback_data_var[15:0] = hwif_in[24-:16];
			readback_data_var[16] = hwif_in[8];
		end
		if (rd_mux_addr == 6'h20) begin
			readback_data_var[5:0] = hwif_in[7-:6];
			readback_data_var[7:6] = hwif_in[1-:2];
		end
		readback_data = readback_data_var;
		readback_done = decoded_req & ~decoded_req_is_wr;
		readback_err = 1'sb0;
	end
	assign cpuif_rd_ack = readback_done;
	assign cpuif_rd_data = readback_data;
	assign cpuif_rd_err = readback_err;
	initial _sv2v_0 = 0;
endmodule
module soc_csr (
	clk,
	resetn,
	sel,
	vld,
	we,
	addr,
	wdat,
	rdat,
	rdy,
	hwif_in,
	hwif_out
);
	input wire clk;
	input wire resetn;
	input wire sel;
	input wire vld;
	input wire [3:0] we;
	input wire [5:2] addr;
	input wire [31:0] wdat;
	output reg [31:0] rdat;
	output reg rdy;
	input wire [95:0] hwif_in;
	output wire [128:0] hwif_out;
	wire cpuif_req;
	wire [31:0] cpuif_wr_biten;
	wire cpuif_rd_ack;
	wire cpuif_wr_ack;
	wire [31:0] cpuif_rd_data;
	wire cpuif_ack;
	wire cpuif_done;
	reg csr_busy;
	assign cpuif_wr_biten[31:24] = (we[3] ? {8 {1'sb1}} : {8 {1'sb0}});
	assign cpuif_wr_biten[23:16] = (we[2] ? {8 {1'sb1}} : {8 {1'sb0}});
	assign cpuif_wr_biten[15:8] = (we[1] ? {8 {1'sb1}} : {8 {1'sb0}});
	assign cpuif_wr_biten[7:0] = (we[0] ? {8 {1'sb1}} : {8 {1'sb0}});
	assign cpuif_ack = cpuif_rd_ack | cpuif_wr_ack;
	assign cpuif_req = ((sel & vld) & ~csr_busy) & ~rdy;
	assign cpuif_done = cpuif_ack & (cpuif_req | csr_busy);
	always @(posedge clk)
		if (!resetn) begin
			csr_busy <= 1'b0;
			rdy <= 1'b0;
			rdat <= 1'sb0;
		end
		else begin
			rdy <= 1'b0;
			if (cpuif_req && !cpuif_ack)
				csr_busy <= 1'b1;
			if (cpuif_done) begin
				csr_busy <= 1'b0;
				rdy <= 1'b1;
				rdat <= cpuif_rd_data;
			end
		end
	csr csr_inst(
		.clk(clk),
		.rst(~resetn),
		.s_cpuif_req(cpuif_req),
		.s_cpuif_req_is_wr(|we),
		.s_cpuif_addr({addr, 2'b00}),
		.s_cpuif_wr_data(wdat),
		.s_cpuif_wr_biten(cpuif_wr_biten),
		.s_cpuif_req_stall_wr(),
		.s_cpuif_req_stall_rd(),
		.s_cpuif_rd_ack(cpuif_rd_ack),
		.s_cpuif_rd_err(),
		.s_cpuif_rd_data(cpuif_rd_data),
		.s_cpuif_wr_ack(cpuif_wr_ack),
		.s_cpuif_wr_err(),
		.hwif_in(hwif_in),
		.hwif_out(hwif_out)
	);
endmodule
module riscv_pcie_soc (
	clk,
	resetn,
	s_axis_tx_tdata,
	s_axis_tx_tkeep,
	s_axis_tx_tlast,
	s_axis_tx_tvalid,
	s_axis_tx_tready,
	m_axis_rx_tdata,
	m_axis_rx_tkeep,
	m_axis_rx_tlast,
	m_axis_rx_tvalid,
	m_axis_rx_tready,
	cfg_status,
	cfg_command,
	cfg_msg_received_err_fatal,
	tx_buf_av
);
	reg _sv2v_0;
	input wire clk;
	input wire resetn;
	output reg [63:0] s_axis_tx_tdata;
	output reg [7:0] s_axis_tx_tkeep;
	output reg s_axis_tx_tlast;
	output reg s_axis_tx_tvalid;
	input wire s_axis_tx_tready;
	input wire [63:0] m_axis_rx_tdata;
	input wire [7:0] m_axis_rx_tkeep;
	input wire m_axis_rx_tlast;
	input wire m_axis_rx_tvalid;
	output wire m_axis_rx_tready;
	input wire [15:0] cfg_status;
	input wire [15:0] cfg_command;
	input wire cfg_msg_received_err_fatal;
	input wire [5:0] tx_buf_av;
	wire mem_valid;
	wire mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0] mem_wstrb;
	reg [31:0] mem_rdata;
	wire ram_ready;
	wire [31:0] ram_rdata;
	reg [31:0] tx_packet_counter;
	wire is_ram;
	wire is_bridge;
	assign is_ram = mem_addr[31:24] == 8'h00;
	assign is_bridge = mem_addr[31:24] == 8'h30;
	picorv32 #(
		.PROGADDR_RESET(32'h00000000),
		.STACKADDR(32'h00002000),
		.BARREL_SHIFTER(1),
		.ENABLE_COUNTERS(1)
	) cpu(
		.clk(clk),
		.resetn(resetn),
		.mem_valid(mem_valid),
		.mem_ready(mem_ready),
		.mem_addr(mem_addr),
		.mem_wdata(mem_wdata),
		.mem_wstrb(mem_wstrb),
		.mem_rdata(mem_rdata)
	);
	reg [31:0] ram [0:2047];
	initial $readmemh("firmware.hex", ram);
	reg [31:0] ram_rdata_reg;
	reg ram_ready_reg;
	always @(posedge clk) begin
		ram_ready_reg <= 1'b0;
		if (mem_valid && is_ram) begin
			if (mem_wstrb == {4 {1'sb0}}) begin
				ram_rdata_reg <= ram[mem_addr[12:2]];
				ram_ready_reg <= 1'b1;
			end
			else begin
				if (mem_wstrb[0])
					ram[mem_addr[12:2]][7:0] <= mem_wdata[7:0];
				if (mem_wstrb[1])
					ram[mem_addr[12:2]][15:8] <= mem_wdata[15:8];
				if (mem_wstrb[2])
					ram[mem_addr[12:2]][23:16] <= mem_wdata[23:16];
				if (mem_wstrb[3])
					ram[mem_addr[12:2]][31:24] <= mem_wdata[31:24];
				ram_ready_reg <= 1'b1;
			end
		end
	end
	assign ram_rdata = ram_rdata_reg;
	assign ram_ready = ram_ready_reg;
	wire [31:0] bridge_rdat;
	wire bridge_rdy;
	wire [31:0] tx_header0;
	wire [31:0] tx_header1;
	wire [31:0] tx_header2;
	wire [31:0] tx_data;
	reg [1:0] tx_state;
	reg rx_phase;
	wire [95:0] hwif_in;
	wire [128:0] hwif_out;
	soc_csr u_soc_csr(
		.clk(clk),
		.resetn(resetn),
		.sel(is_bridge),
		.vld(mem_valid),
		.we(mem_wstrb),
		.addr(mem_addr[5:2]),
		.wdat(mem_wdata),
		.rdat(bridge_rdat),
		.rdy(bridge_rdy),
		.hwif_in(hwif_in),
		.hwif_out(hwif_out)
	);
	wire tx_start;
	assign tx_header0 = hwif_out[128-:32];
	assign tx_header1 = hwif_out[96-:32];
	assign tx_header2 = hwif_out[64-:32];
	assign tx_data = hwif_out[32-:32];
	assign tx_start = hwif_out[0];
	always @(posedge clk)
		if (!resetn) begin
			tx_state <= 2'd0;
			s_axis_tx_tvalid <= 1'b0;
			tx_packet_counter <= 1'sb0;
		end
		else begin
			if (tx_start) begin
				tx_state <= 2'd1;
				tx_packet_counter <= tx_packet_counter + 32'd1;
			end
			case (tx_state)
				2'd0: s_axis_tx_tvalid <= 1'b0;
				2'd1: begin
					s_axis_tx_tdata <= {tx_header1, tx_header0};
					s_axis_tx_tkeep <= 8'hff;
					s_axis_tx_tvalid <= 1'b1;
					s_axis_tx_tlast <= 1'b0;
					if (s_axis_tx_tready)
						tx_state <= 2'd2;
				end
				2'd2: begin
					s_axis_tx_tdata <= {tx_data, tx_header2};
					s_axis_tx_tkeep <= (tx_header0[30] == 1'b1 ? 8'hff : 8'h0f);
					s_axis_tx_tvalid <= 1'b1;
					s_axis_tx_tlast <= 1'b1;
					if (s_axis_tx_tready)
						tx_state <= 2'd0;
				end
				default:
					;
			endcase
		end
	wire rx_cpl_dw0;
	wire rx_cpl_dw2;
	assign rx_cpl_dw0 = (m_axis_rx_tvalid & (rx_phase == 1'b0)) & (m_axis_rx_tdata[28:24] == 5'b01010);
	assign rx_cpl_dw2 = m_axis_rx_tvalid & (rx_phase == 1'b1);
	always @(posedge clk)
		if (!resetn)
			rx_phase <= 1'b0;
		else if (rx_cpl_dw0)
			rx_phase <= 1'b1;
		else if (rx_cpl_dw2 && m_axis_rx_tlast)
			rx_phase <= 1'b0;
	assign hwif_in[92] = rx_cpl_dw0;
	assign hwif_in[95-:3] = m_axis_rx_tdata[47:45];
	assign hwif_in[59] = rx_cpl_dw2;
	assign hwif_in[91-:32] = m_axis_rx_tdata[63:32];
	assign hwif_in[25] = rx_cpl_dw2;
	assign hwif_in[41-:16] = m_axis_rx_tdata[31:16];
	assign hwif_in[42] = rx_cpl_dw2;
	assign hwif_in[50-:8] = m_axis_rx_tdata[15:8];
	assign hwif_in[51] = rx_cpl_dw2;
	assign hwif_in[58-:7] = m_axis_rx_tdata[6:0];
	assign hwif_in[24-:16] = cfg_status;
	assign hwif_in[8] = cfg_msg_received_err_fatal;
	assign hwif_in[1-:2] = tx_state;
	assign hwif_in[7-:6] = tx_buf_av;
	assign m_axis_rx_tready = 1'b1;
	always @(*) begin
		if (_sv2v_0)
			;
		if (is_ram)
			mem_rdata = ram_rdata;
		else if (is_bridge)
			mem_rdata = bridge_rdat;
		else
			mem_rdata = 32'hdeadbeef;
	end
	assign mem_ready = ram_ready || bridge_rdy;
	initial _sv2v_0 = 0;
endmodule
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
