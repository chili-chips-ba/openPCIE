module riscv_pcie_soc (
	clk,
	resetn,
	s_axis_tx_tdata,
	s_axis_tx_tkeep,
	s_axis_tx_tlast,
	s_axis_tx_tvalid,
	s_axis_tx_tready,
	m_axis_rx_tdata,
	m_axis_rx_tkeep,
	m_axis_rx_tlast,
	m_axis_rx_tvalid,
	m_axis_rx_tready,
	cfg_status,
	cfg_command,
	cfg_msg_received_err_fatal,
	tx_buf_av
);
	reg _sv2v_0;
	input wire clk;
	input wire resetn;
	output reg [63:0] s_axis_tx_tdata;
	output reg [7:0] s_axis_tx_tkeep;
	output reg s_axis_tx_tlast;
	output reg s_axis_tx_tvalid;
	input wire s_axis_tx_tready;
	input wire [63:0] m_axis_rx_tdata;
	input wire [7:0] m_axis_rx_tkeep;
	input wire m_axis_rx_tlast;
	input wire m_axis_rx_tvalid;
	output wire m_axis_rx_tready;
	input wire [15:0] cfg_status;
	input wire [15:0] cfg_command;
	input wire cfg_msg_received_err_fatal;
	input wire [5:0] tx_buf_av;
	wire mem_valid;
	wire mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0] mem_wstrb;
	reg [31:0] mem_rdata;
	wire ram_ready;
	wire [31:0] ram_rdata;
	reg [31:0] tx_packet_counter;
	wire is_ram;
	wire is_bridge;
	assign is_ram = mem_addr[31:24] == 8'h00;
	assign is_bridge = mem_addr[31:24] == 8'h30;
	picorv32 #(
		.PROGADDR_RESET(32'h00000000),
		.STACKADDR(32'h00002000),
		.BARREL_SHIFTER(1),
		.ENABLE_COUNTERS(1)
	) cpu(
		.clk(clk),
		.resetn(resetn),
		.mem_valid(mem_valid),
		.mem_ready(mem_ready),
		.mem_addr(mem_addr),
		.mem_wdata(mem_wdata),
		.mem_wstrb(mem_wstrb),
		.mem_rdata(mem_rdata)
	);
	reg [31:0] ram [0:2047];
	initial $readmemh("firmware.hex", ram);
	reg [31:0] ram_rdata_reg;
	reg ram_ready_reg;
	always @(posedge clk) begin
		ram_ready_reg <= 1'b0;
		if (mem_valid && is_ram) begin
			if (mem_wstrb == {4 {1'sb0}}) begin
				ram_rdata_reg <= ram[mem_addr[12:2]];
				ram_ready_reg <= 1'b1;
			end
			else begin
				if (mem_wstrb[0])
					ram[mem_addr[12:2]][7:0] <= mem_wdata[7:0];
				if (mem_wstrb[1])
					ram[mem_addr[12:2]][15:8] <= mem_wdata[15:8];
				if (mem_wstrb[2])
					ram[mem_addr[12:2]][23:16] <= mem_wdata[23:16];
				if (mem_wstrb[3])
					ram[mem_addr[12:2]][31:24] <= mem_wdata[31:24];
				ram_ready_reg <= 1'b1;
			end
		end
	end
	assign ram_rdata = ram_rdata_reg;
	assign ram_ready = ram_ready_reg;
	wire [31:0] bridge_rdat;
	wire bridge_rdy;
	wire [31:0] tx_header0;
	wire [31:0] tx_header1;
	wire [31:0] tx_header2;
	wire [31:0] tx_data;
	reg [1:0] tx_state;
	reg rx_phase;
	wire [95:0] hwif_in;
	wire [128:0] hwif_out;
	soc_csr u_soc_csr(
		.clk(clk),
		.resetn(resetn),
		.sel(is_bridge),
		.vld(mem_valid),
		.we(mem_wstrb),
		.addr(mem_addr[5:2]),
		.wdat(mem_wdata),
		.rdat(bridge_rdat),
		.rdy(bridge_rdy),
		.hwif_in(hwif_in),
		.hwif_out(hwif_out)
	);
	wire tx_start;
	assign tx_header0 = hwif_out[128-:32];
	assign tx_header1 = hwif_out[96-:32];
	assign tx_header2 = hwif_out[64-:32];
	assign tx_data = hwif_out[32-:32];
	assign tx_start = hwif_out[0];
	always @(posedge clk)
		if (!resetn) begin
			tx_state <= 2'd0;
			s_axis_tx_tvalid <= 1'b0;
			tx_packet_counter <= 1'sb0;
		end
		else begin
			if (tx_start) begin
				tx_state <= 2'd1;
				tx_packet_counter <= tx_packet_counter + 32'd1;
			end
			case (tx_state)
				2'd0: s_axis_tx_tvalid <= 1'b0;
				2'd1: begin
					s_axis_tx_tdata <= {tx_header1, tx_header0};
					s_axis_tx_tkeep <= 8'hff;
					s_axis_tx_tvalid <= 1'b1;
					s_axis_tx_tlast <= 1'b0;
					if (s_axis_tx_tready)
						tx_state <= 2'd2;
				end
				2'd2: begin
					s_axis_tx_tdata <= {tx_data, tx_header2};
					s_axis_tx_tkeep <= (tx_header0[30] == 1'b1 ? 8'hff : 8'h0f);
					s_axis_tx_tvalid <= 1'b1;
					s_axis_tx_tlast <= 1'b1;
					if (s_axis_tx_tready)
						tx_state <= 2'd0;
				end
				default:
					;
			endcase
		end
	wire rx_cpl_dw0;
	wire rx_cpl_dw2;
	assign rx_cpl_dw0 = (m_axis_rx_tvalid & (rx_phase == 1'b0)) & (m_axis_rx_tdata[28:24] == 5'b01010);
	assign rx_cpl_dw2 = m_axis_rx_tvalid & (rx_phase == 1'b1);
	always @(posedge clk)
		if (!resetn)
			rx_phase <= 1'b0;
		else if (rx_cpl_dw0)
			rx_phase <= 1'b1;
		else if (rx_cpl_dw2 && m_axis_rx_tlast)
			rx_phase <= 1'b0;
	assign hwif_in[92] = rx_cpl_dw0;
	assign hwif_in[95-:3] = m_axis_rx_tdata[47:45];
	assign hwif_in[59] = rx_cpl_dw2;
	assign hwif_in[91-:32] = m_axis_rx_tdata[63:32];
	assign hwif_in[25] = rx_cpl_dw2;
	assign hwif_in[41-:16] = m_axis_rx_tdata[31:16];
	assign hwif_in[42] = rx_cpl_dw2;
	assign hwif_in[50-:8] = m_axis_rx_tdata[15:8];
	assign hwif_in[51] = rx_cpl_dw2;
	assign hwif_in[58-:7] = m_axis_rx_tdata[6:0];
	assign hwif_in[24-:16] = cfg_status;
	assign hwif_in[8] = cfg_msg_received_err_fatal;
	assign hwif_in[1-:2] = tx_state;
	assign hwif_in[7-:6] = tx_buf_av;
	assign m_axis_rx_tready = 1'b1;
	always @(*) begin
		if (_sv2v_0)
			;
		if (is_ram)
			mem_rdata = ram_rdata;
		else if (is_bridge)
			mem_rdata = bridge_rdat;
		else
			mem_rdata = 32'hdeadbeef;
	end
	assign mem_ready = ram_ready || bridge_rdy;
	initial _sv2v_0 = 0;
endmodule
