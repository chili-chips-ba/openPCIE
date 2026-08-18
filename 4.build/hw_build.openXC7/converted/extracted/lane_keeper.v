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
