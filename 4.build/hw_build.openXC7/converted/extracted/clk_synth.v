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
