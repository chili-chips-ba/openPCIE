module csr (
	clk,
	rst,
	s_cpuif_req,
	s_cpuif_req_is_wr,
	s_cpuif_addr,
	s_cpuif_wr_data,
	s_cpuif_wr_biten,
	s_cpuif_req_stall_wr,
	s_cpuif_req_stall_rd,
	s_cpuif_rd_ack,
	s_cpuif_rd_err,
	s_cpuif_rd_data,
	s_cpuif_wr_ack,
	s_cpuif_wr_err,
	hwif_in,
	hwif_out
);
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	input wire s_cpuif_req;
	input wire s_cpuif_req_is_wr;
	input wire [5:0] s_cpuif_addr;
	input wire [31:0] s_cpuif_wr_data;
	input wire [31:0] s_cpuif_wr_biten;
	output wire s_cpuif_req_stall_wr;
	output wire s_cpuif_req_stall_rd;
	output wire s_cpuif_rd_ack;
	output wire s_cpuif_rd_err;
	output wire [31:0] s_cpuif_rd_data;
	output wire s_cpuif_wr_ack;
	output wire s_cpuif_wr_err;
	input wire [95:0] hwif_in;
	output wire [128:0] hwif_out;
	wire cpuif_req;
	wire cpuif_req_is_wr;
	wire [5:0] cpuif_addr;
	wire [31:0] cpuif_wr_data;
	wire [31:0] cpuif_wr_biten;
	wire cpuif_req_stall_wr;
	wire cpuif_req_stall_rd;
	wire cpuif_rd_ack;
	wire cpuif_rd_err;
	wire [31:0] cpuif_rd_data;
	wire cpuif_wr_ack;
	wire cpuif_wr_err;
	assign cpuif_req = s_cpuif_req;
	assign cpuif_req_is_wr = s_cpuif_req_is_wr;
	assign cpuif_addr = s_cpuif_addr;
	assign cpuif_wr_data = s_cpuif_wr_data;
	assign cpuif_wr_biten = s_cpuif_wr_biten;
	assign s_cpuif_req_stall_wr = cpuif_req_stall_wr;
	assign s_cpuif_req_stall_rd = cpuif_req_stall_rd;
	assign s_cpuif_rd_ack = cpuif_rd_ack;
	assign s_cpuif_rd_err = cpuif_rd_err;
	assign s_cpuif_rd_data = cpuif_rd_data;
	assign s_cpuif_wr_ack = cpuif_wr_ack;
	assign s_cpuif_wr_err = cpuif_wr_err;
	wire cpuif_req_masked;
	assign cpuif_req_stall_rd = 1'sb0;
	assign cpuif_req_stall_wr = 1'sb0;
	assign cpuif_req_masked = (cpuif_req & !(!cpuif_req_is_wr & cpuif_req_stall_rd)) & !(cpuif_req_is_wr & cpuif_req_stall_wr);
	reg [8:0] decoded_reg_strb;
	reg decoded_err;
	wire [5:0] decoded_addr;
	wire decoded_req;
	wire decoded_req_is_wr;
	wire [31:0] decoded_wr_data;
	wire [31:0] decoded_wr_biten;
	always @(*) begin : sv2v_autoblock_1
		reg is_valid_addr;
		reg is_valid_rw;
		if (_sv2v_0)
			;
		is_valid_addr = 1'sb1;
		is_valid_rw = 1'sb1;
		decoded_reg_strb[8] = cpuif_req_masked & (cpuif_addr == 6'h00);
		decoded_reg_strb[7] = cpuif_req_masked & (cpuif_addr == 6'h04);
		decoded_reg_strb[6] = cpuif_req_masked & (cpuif_addr == 6'h08);
		decoded_reg_strb[5] = cpuif_req_masked & (cpuif_addr == 6'h0c);
		decoded_reg_strb[4] = (cpuif_req_masked & (cpuif_addr == 6'h10)) & !cpuif_req_is_wr;
		decoded_reg_strb[3] = (cpuif_req_masked & (cpuif_addr == 6'h14)) & !cpuif_req_is_wr;
		decoded_reg_strb[2] = (cpuif_req_masked & (cpuif_addr == 6'h18)) & !cpuif_req_is_wr;
		decoded_reg_strb[1] = (cpuif_req_masked & (cpuif_addr == 6'h1c)) & !cpuif_req_is_wr;
		decoded_reg_strb[0] = (cpuif_req_masked & (cpuif_addr == 6'h20)) & !cpuif_req_is_wr;
		decoded_err = 1'sb0;
	end
	assign decoded_addr = cpuif_addr;
	assign decoded_req = cpuif_req_masked;
	assign decoded_req_is_wr = cpuif_req_is_wr;
	assign decoded_wr_data = cpuif_wr_data;
	assign decoded_wr_biten = cpuif_wr_biten;
	reg [202:0] field_combo;
	reg [193:0] field_storage;
	always @(*) begin : sv2v_autoblock_2
		reg [31:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[193-:32];
		load_next_c = 1'sb0;
		if (decoded_reg_strb[8] && decoded_req_is_wr) begin
			next_c = (field_storage[193-:32] & ~decoded_wr_biten[31:0]) | (decoded_wr_data[31:0] & decoded_wr_biten[31:0]);
			load_next_c = 1'sb1;
		end
		field_combo[202-:32] = next_c;
		field_combo[170] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[193-:32] <= 32'h00000000;
		else if (field_combo[170])
			field_storage[193-:32] <= field_combo[202-:32];
	assign hwif_out[128-:32] = field_storage[193-:32];
	always @(*) begin : sv2v_autoblock_3
		reg [31:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[161-:32];
		load_next_c = 1'sb0;
		if (decoded_reg_strb[7] && decoded_req_is_wr) begin
			next_c = (field_storage[161-:32] & ~decoded_wr_biten[31:0]) | (decoded_wr_data[31:0] & decoded_wr_biten[31:0]);
			load_next_c = 1'sb1;
		end
		field_combo[169-:32] = next_c;
		field_combo[137] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[161-:32] <= 32'h00000000;
		else if (field_combo[137])
			field_storage[161-:32] <= field_combo[169-:32];
	assign hwif_out[96-:32] = field_storage[161-:32];
	always @(*) begin : sv2v_autoblock_4
		reg [31:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[129-:32];
		load_next_c = 1'sb0;
		if (decoded_reg_strb[6] && decoded_req_is_wr) begin
			next_c = (field_storage[129-:32] & ~decoded_wr_biten[31:0]) | (decoded_wr_data[31:0] & decoded_wr_biten[31:0]);
			load_next_c = 1'sb1;
		end
		field_combo[136-:32] = next_c;
		field_combo[104] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[129-:32] <= 32'h00000000;
		else if (field_combo[104])
			field_storage[129-:32] <= field_combo[136-:32];
	assign hwif_out[64-:32] = field_storage[129-:32];
	always @(*) begin : sv2v_autoblock_5
		reg [31:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[97-:32];
		load_next_c = 1'sb0;
		if (decoded_reg_strb[5] && decoded_req_is_wr) begin
			next_c = (field_storage[97-:32] & ~decoded_wr_biten[31:0]) | (decoded_wr_data[31:0] & decoded_wr_biten[31:0]);
			load_next_c = 1'sb1;
		end
		field_combo[103-:32] = next_c;
		field_combo[71] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[97-:32] <= 32'h00000000;
		else if (field_combo[71])
			field_storage[97-:32] <= field_combo[103-:32];
	assign hwif_out[32-:32] = field_storage[97-:32];
	assign hwif_out[0] = (decoded_reg_strb[5] && decoded_req_is_wr) && |decoded_wr_biten[31:0];
	always @(*) begin : sv2v_autoblock_6
		reg [2:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[65-:3];
		load_next_c = 1'sb0;
		if (hwif_in[92]) begin
			next_c = hwif_in[95-:3];
			load_next_c = 1'sb1;
		end
		field_combo[70-:3] = next_c;
		field_combo[67] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[65-:3] <= 3'h0;
		else if (field_combo[67])
			field_storage[65-:3] <= field_combo[70-:3];
	always @(*) begin : sv2v_autoblock_7
		reg [31:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[62-:32];
		load_next_c = 1'sb0;
		if (hwif_in[59]) begin
			next_c = hwif_in[91-:32];
			load_next_c = 1'sb1;
		end
		field_combo[66-:32] = next_c;
		field_combo[34] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[62-:32] <= 32'h00000000;
		else if (field_combo[34])
			field_storage[62-:32] <= field_combo[66-:32];
	always @(*) begin : sv2v_autoblock_8
		reg [6:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[30-:7];
		load_next_c = 1'sb0;
		if (hwif_in[51]) begin
			next_c = hwif_in[58-:7];
			load_next_c = 1'sb1;
		end
		field_combo[33-:7] = next_c;
		field_combo[26] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[30-:7] <= 7'h00;
		else if (field_combo[26])
			field_storage[30-:7] <= field_combo[33-:7];
	always @(*) begin : sv2v_autoblock_9
		reg [7:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[23-:8];
		load_next_c = 1'sb0;
		if (hwif_in[42]) begin
			next_c = hwif_in[50-:8];
			load_next_c = 1'sb1;
		end
		field_combo[25-:8] = next_c;
		field_combo[17] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[23-:8] <= 8'h00;
		else if (field_combo[17])
			field_storage[23-:8] <= field_combo[25-:8];
	always @(*) begin : sv2v_autoblock_10
		reg [15:0] next_c;
		reg load_next_c;
		if (_sv2v_0)
			;
		next_c = field_storage[15-:16];
		load_next_c = 1'sb0;
		if (hwif_in[25]) begin
			next_c = hwif_in[41-:16];
			load_next_c = 1'sb1;
		end
		field_combo[16-:16] = next_c;
		field_combo[0] = load_next_c;
	end
	always @(posedge clk)
		if (rst)
			field_storage[15-:16] <= 16'h0000;
		else if (field_combo[0])
			field_storage[15-:16] <= field_combo[16-:16];
	assign cpuif_wr_ack = decoded_req & decoded_req_is_wr;
	assign cpuif_wr_err = 1'sb0;
	wire [5:0] rd_mux_addr;
	assign rd_mux_addr = decoded_addr;
	reg readback_err;
	reg readback_done;
	reg [31:0] readback_data;
	always @(*) begin : sv2v_autoblock_11
		reg [31:0] readback_data_var;
		if (_sv2v_0)
			;
		readback_data_var = 1'sb0;
		if (rd_mux_addr == 6'h00)
			readback_data_var[31:0] = field_storage[193-:32];
		if (rd_mux_addr == 6'h04)
			readback_data_var[31:0] = field_storage[161-:32];
		if (rd_mux_addr == 6'h08)
			readback_data_var[31:0] = field_storage[129-:32];
		if (rd_mux_addr == 6'h0c)
			readback_data_var[31:0] = field_storage[97-:32];
		if (rd_mux_addr == 6'h10)
			readback_data_var[2:0] = field_storage[65-:3];
		if (rd_mux_addr == 6'h14)
			readback_data_var[31:0] = field_storage[62-:32];
		if (rd_mux_addr == 6'h18) begin
			readback_data_var[6:0] = field_storage[30-:7];
			readback_data_var[15:8] = field_storage[23-:8];
			readback_data_var[31:16] = field_storage[15-:16];
		end
		if (rd_mux_addr == 6'h1c) begin
			readback_data_var[15:0] = hwif_in[24-:16];
			readback_data_var[16] = hwif_in[8];
		end
		if (rd_mux_addr == 6'h20) begin
			readback_data_var[5:0] = hwif_in[7-:6];
			readback_data_var[7:6] = hwif_in[1-:2];
		end
		readback_data = readback_data_var;
		readback_done = decoded_req & ~decoded_req_is_wr;
		readback_err = 1'sb0;
	end
	assign cpuif_rd_ack = readback_done;
	assign cpuif_rd_data = readback_data;
	assign cpuif_rd_err = readback_err;
	initial _sv2v_0 = 0;
endmodule
