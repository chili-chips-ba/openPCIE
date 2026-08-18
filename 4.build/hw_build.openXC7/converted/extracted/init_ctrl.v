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
