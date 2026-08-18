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
