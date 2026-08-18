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
