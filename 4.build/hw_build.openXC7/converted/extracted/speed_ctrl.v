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
