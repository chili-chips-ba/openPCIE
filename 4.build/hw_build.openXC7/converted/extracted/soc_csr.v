module soc_csr (
	clk,
	resetn,
	sel,
	vld,
	we,
	addr,
	wdat,
	rdat,
	rdy,
	hwif_in,
	hwif_out
);
	input wire clk;
	input wire resetn;
	input wire sel;
	input wire vld;
	input wire [3:0] we;
	input wire [5:2] addr;
	input wire [31:0] wdat;
	output reg [31:0] rdat;
	output reg rdy;
	input wire [95:0] hwif_in;
	output wire [128:0] hwif_out;
	wire cpuif_req;
	wire [31:0] cpuif_wr_biten;
	wire cpuif_rd_ack;
	wire cpuif_wr_ack;
	wire [31:0] cpuif_rd_data;
	wire cpuif_ack;
	wire cpuif_done;
	reg csr_busy;
	assign cpuif_wr_biten[31:24] = (we[3] ? {8 {1'sb1}} : {8 {1'sb0}});
	assign cpuif_wr_biten[23:16] = (we[2] ? {8 {1'sb1}} : {8 {1'sb0}});
	assign cpuif_wr_biten[15:8] = (we[1] ? {8 {1'sb1}} : {8 {1'sb0}});
	assign cpuif_wr_biten[7:0] = (we[0] ? {8 {1'sb1}} : {8 {1'sb0}});
	assign cpuif_ack = cpuif_rd_ack | cpuif_wr_ack;
	assign cpuif_req = ((sel & vld) & ~csr_busy) & ~rdy;
	assign cpuif_done = cpuif_ack & (cpuif_req | csr_busy);
	always @(posedge clk)
		if (!resetn) begin
			csr_busy <= 1'b0;
			rdy <= 1'b0;
			rdat <= 1'sb0;
		end
		else begin
			rdy <= 1'b0;
			if (cpuif_req && !cpuif_ack)
				csr_busy <= 1'b1;
			if (cpuif_done) begin
				csr_busy <= 1'b0;
				rdy <= 1'b1;
				rdat <= cpuif_rd_data;
			end
		end
	csr csr_inst(
		.clk(clk),
		.rst(~resetn),
		.s_cpuif_req(cpuif_req),
		.s_cpuif_req_is_wr(|we),
		.s_cpuif_addr({addr, 2'b00}),
		.s_cpuif_wr_data(wdat),
		.s_cpuif_wr_biten(cpuif_wr_biten),
		.s_cpuif_req_stall_wr(),
		.s_cpuif_req_stall_rd(),
		.s_cpuif_rd_ack(cpuif_rd_ack),
		.s_cpuif_rd_err(),
		.s_cpuif_rd_data(cpuif_rd_data),
		.s_cpuif_wr_ack(cpuif_wr_ack),
		.s_cpuif_wr_err(),
		.hwif_in(hwif_in),
		.hwif_out(hwif_out)
	);
endmodule
