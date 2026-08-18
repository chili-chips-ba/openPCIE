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
