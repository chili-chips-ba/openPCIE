module eios_squelch (
	USER_RXCHARISK,
	USER_RXDATA,
	USER_RXVALID,
	USER_RXELECIDLE,
	USER_RX_STATUS,
	USER_RX_PHY_STATUS,
	GT_RXCHARISK,
	GT_RXDATA,
	GT_RXVALID,
	GT_RXELECIDLE,
	GT_RX_STATUS,
	GT_RX_PHY_STATUS,
	PLM_IN_L0,
	PLM_IN_RS,
	USER_CLK,
	RESET
);
	output wire [1:0] USER_RXCHARISK;
	output wire [15:0] USER_RXDATA;
	output wire USER_RXVALID;
	output wire USER_RXELECIDLE;
	output wire [2:0] USER_RX_STATUS;
	output wire USER_RX_PHY_STATUS;
	input wire [1:0] GT_RXCHARISK;
	input wire [15:0] GT_RXDATA;
	input wire GT_RXVALID;
	input wire GT_RXELECIDLE;
	input wire [2:0] GT_RX_STATUS;
	input wire GT_RX_PHY_STATUS;
	input wire PLM_IN_L0;
	input wire PLM_IN_RS;
	input wire USER_CLK;
	input wire RESET;
	localparam [4:0] EIOS_DET_IDL = 5'b00001;
	localparam [4:0] EIOS_DET_NO_STR0 = 5'b00010;
	localparam [4:0] EIOS_DET_STR0 = 5'b00100;
	localparam [4:0] EIOS_DET_STR1 = 5'b01000;
	localparam [4:0] EIOS_DET_DONE = 5'b10000;
	localparam [7:0] EIOS_COM = 8'hbc;
	localparam [7:0] EIOS_IDL = 8'h7c;
	reg [4:0] reg_state_eios_det;
	reg reg_symbol_after_eios;
	reg [1:0] gt_rxcharisk_q;
	reg [15:0] gt_rxdata_q;
	reg gt_rxvalid_q;
	reg gt_rxelecidle_q;
	reg [2:0] gt_rx_status_q;
	reg gt_rx_phy_status_q;
	always @(posedge USER_CLK)
		if (RESET) begin
			reg_state_eios_det <= EIOS_DET_IDL;
			reg_symbol_after_eios <= 1'b0;
			gt_rxcharisk_q <= 2'b00;
			gt_rxdata_q <= 16'h0000;
			gt_rxvalid_q <= 1'b0;
			gt_rxelecidle_q <= 1'b0;
			gt_rx_status_q <= 3'b000;
			gt_rx_phy_status_q <= 1'b0;
		end
		else begin
			reg_symbol_after_eios <= 1'b0;
			gt_rxcharisk_q <= GT_RXCHARISK;
			gt_rxelecidle_q <= GT_RXELECIDLE;
			gt_rxdata_q <= GT_RXDATA;
			gt_rx_phy_status_q <= GT_RX_PHY_STATUS;
			if ((reg_state_eios_det == EIOS_DET_DONE) && PLM_IN_L0)
				gt_rxvalid_q <= 1'b0;
			else if (GT_RXELECIDLE && !gt_rxvalid_q)
				gt_rxvalid_q <= 1'b0;
			else
				gt_rxvalid_q <= GT_RXVALID;
			if (gt_rxvalid_q)
				gt_rx_status_q <= GT_RX_STATUS;
			else if (!gt_rxvalid_q && PLM_IN_L0)
				gt_rx_status_q <= 3'b000;
			else
				gt_rx_status_q <= GT_RX_STATUS;
			case (reg_state_eios_det)
				EIOS_DET_IDL:
					if (((gt_rxcharisk_q[0] && (gt_rxdata_q[7:0] == EIOS_COM)) && gt_rxcharisk_q[1]) && (gt_rxdata_q[15:8] == EIOS_IDL))
						reg_state_eios_det <= EIOS_DET_NO_STR0;
					else if (gt_rxcharisk_q[1] && (gt_rxdata_q[15:8] == EIOS_COM))
						reg_state_eios_det <= EIOS_DET_STR0;
					else
						reg_state_eios_det <= EIOS_DET_IDL;
				EIOS_DET_NO_STR0:
					if ((gt_rxcharisk_q[0] && (gt_rxdata_q[7:0] == EIOS_IDL)) && (gt_rxcharisk_q[1] && (gt_rxdata_q[15:8] == EIOS_IDL))) begin
						reg_state_eios_det <= EIOS_DET_DONE;
						gt_rxvalid_q <= 1'b0;
					end
					else if (gt_rxcharisk_q[0] && (gt_rxdata_q[7:0] == EIOS_IDL)) begin
						reg_state_eios_det <= EIOS_DET_DONE;
						gt_rxvalid_q <= 1'b0;
					end
					else
						reg_state_eios_det <= EIOS_DET_IDL;
				EIOS_DET_STR0:
					if ((gt_rxcharisk_q[0] && (gt_rxdata_q[7:0] == EIOS_IDL)) && (gt_rxcharisk_q[1] && (gt_rxdata_q[15:8] == EIOS_IDL))) begin
						reg_state_eios_det <= EIOS_DET_STR1;
						gt_rxvalid_q <= 1'b0;
						reg_symbol_after_eios <= 1'b1;
					end
					else
						reg_state_eios_det <= EIOS_DET_IDL;
				EIOS_DET_STR1:
					if (gt_rxcharisk_q[0] && (gt_rxdata_q[7:0] == EIOS_IDL)) begin
						reg_state_eios_det <= EIOS_DET_DONE;
						gt_rxvalid_q <= 1'b0;
					end
					else
						reg_state_eios_det <= EIOS_DET_IDL;
				EIOS_DET_DONE: reg_state_eios_det <= EIOS_DET_IDL;
				default: reg_state_eios_det <= EIOS_DET_IDL;
			endcase
		end
	assign USER_RXVALID = gt_rxvalid_q;
	assign USER_RXCHARISK[0] = (gt_rxvalid_q ? gt_rxcharisk_q[0] : 1'b0);
	assign USER_RXCHARISK[1] = (gt_rxvalid_q && !reg_symbol_after_eios ? gt_rxcharisk_q[1] : 1'b0);
	assign USER_RXDATA[7:0] = gt_rxdata_q[7:0];
	assign USER_RXDATA[15:8] = gt_rxdata_q[15:8];
	assign USER_RX_STATUS = gt_rx_status_q;
	assign USER_RX_PHY_STATUS = gt_rx_phy_status_q;
	assign USER_RXELECIDLE = gt_rxelecidle_q;
endmodule
