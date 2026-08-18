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
