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
