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
