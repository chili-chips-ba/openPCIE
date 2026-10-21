// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// riscv-formal wrapper for eduBOS5 (run-riscv-formal.sh): the core with free
// memories, as the SOC (riscv_pcie_soc.sv) connects it.
//  - IMEM: synchronous read; the word changes only if the address changed.
//  - DMEM: free read data; dmem_rdy only answers a pending read (load_wait),
//    the SOC's bus rule. EDUBOS5_STORE_WAIT (STORE_WAITS_RDY=1): it also
//    answers a store, after any number of clocks.
// Plain Verilog with the riscv-formal macros; the core is read by read_slang.
//==========================================================================
module rvfi_wrapper (
    input clock,
    input reset,
    `RVFI_OUTPUTS
);
  (* keep *) `rvformal_rand_reg [31:0] imem_word;  // the RAM contents at the address
  (* keep *) `rvformal_rand_reg [31:0] dmem_rdat;
  (* keep *) `rvformal_rand_reg dmem_ready;

  (* keep *) wire [29:0] imem_addr;
  (* keep *) wire [31:0] dmem_addr;
  (* keep *) wire [ 3:0] dmem_we;
  (* keep *) wire [31:0] dmem_wdat;
  (* keep *) wire        dmem_vld;
  (* keep *) wire        dmem_rdy;

  reg [31:0] imem_rdat;
  reg [29:0] imem_addr_q;
  reg        load_wait;

  // IMEM: imem_rdat follows the address of the clock before
  always @(posedge clock) begin
    imem_rdat   <= imem_word;
    imem_addr_q <= imem_addr;
  end
  always @* begin
    if (!reset && imem_addr == imem_addr_q) assume (imem_word == imem_rdat);
  end

  // DMEM: a read is a request without write strobes, as in the SOC
  always @(posedge clock) begin
    load_wait <= !reset && dmem_vld && dmem_we == 4'b0000 && !dmem_ready;
  end
`ifdef EDUBOS5_STORE_WAIT
  wire store_req = dmem_vld && dmem_we != 4'b0000;
  assign dmem_rdy = dmem_ready && (load_wait || store_req);
`else
  assign dmem_rdy = dmem_ready && load_wait;
`endif

// Legal, aligned code: eduBOS5 has no illegal-instruction and no misaligned
// trap. EDUBOS5_LEGAL_CODE (LEGAL=1) is both halves below; each half can also
// be set alone (ALIGNED=1, LEGAL_STORES=1), which tells the two causes of a
// failure apart.
`ifdef EDUBOS5_LEGAL_CODE
`define EDUBOS5_ALIGNED
`define EDUBOS5_LEGAL_STORES
`endif
  wire [ 6:0] rvfi_opcode = rvfi_insn[6:0];
  wire [ 1:0] rvfi_size = rvfi_insn[13:12];  // 0: byte, 1: half, 2: word
  wire [31:0] rvfi_ld_addr = rvfi_rs1_rdata + {{20{rvfi_insn[31]}}, rvfi_insn[31:20]};
  wire [31:0] rvfi_st_addr = rvfi_rs1_rdata + {{20{rvfi_insn[31]}}, rvfi_insn[31:25], rvfi_insn[11:7]};
  wire [ 1:0] rvfi_ls_low = rvfi_opcode == 7'b0100011 ? rvfi_st_addr[1:0] : rvfi_ld_addr[1:0];
`ifdef EDUBOS5_ALIGNED
  // Loads and stores hit their natural alignment; branch, JAL and JALR
  // targets are word-aligned.
  always @* begin
    if (!reset && rvfi_valid) begin
      if (rvfi_opcode == 7'b0000011 || rvfi_opcode == 7'b0100011) begin
        assume (rvfi_size == 2'd0 || rvfi_size == 2'd1 && !rvfi_ls_low[0] || rvfi_ls_low == 2'd0);
      end
      if (rvfi_opcode == 7'b1100011) assume (!rvfi_insn[8]);  // branch offset bit 1
      if (rvfi_opcode == 7'b1101111) assume (!rvfi_insn[21]);  // JAL offset bit 1
      if (rvfi_opcode == 7'b1100111) assume (!rvfi_ld_addr[1]);  // JALR target bit 1
    end
  end
`endif
`ifdef EDUBOS5_LEGAL_STORES
  // Stores have a legal funct3 (an illegal one makes a bus read, whose
  // dmem_rdy reaches the next load).
  always @* begin
    if (!reset && rvfi_valid && rvfi_opcode == 7'b0100011)
      assume (!rvfi_insn[14] && rvfi_size != 2'd3);  // SB, SH, SW
  end
`endif

// Fairness for the liveness and hang checks (riscv-formal defines
// RISCV_FORMAL_FAIRNESS for those two only): a read is answered the clock
// after it is requested. dmem_ready must also stay low while no read is
// pending, or it keeps load_wait from ever rising and the read is never
// answered.
`ifdef RISCV_FORMAL_FAIRNESS
  always @* begin
`ifdef EDUBOS5_STORE_WAIT
    if (!reset) assume (dmem_ready == (load_wait || store_req));
`else
    if (!reset) assume (dmem_ready == load_wait);
`endif
  end
`endif

// NO_SYSTEM=1: IMEM holds only RV32I opcodes eduBOS5 executes. A SYSTEM or an
// unknown opcode halts the core in EXECUTE without rvfi_halt, which liveness
// and hang report as a hang.
`ifdef EDUBOS5_NO_SYSTEM
  always @* begin
    assume (imem_word[6:0] == 7'b0110011 || imem_word[6:0] == 7'b0010011 ||
            imem_word[6:0] == 7'b1100011 || imem_word[6:0] == 7'b1100111 ||
            imem_word[6:0] == 7'b1101111 || imem_word[6:0] == 7'b0010111 ||
            imem_word[6:0] == 7'b0110111 || imem_word[6:0] == 7'b0000011 ||
            imem_word[6:0] == 7'b0100011 || imem_word[6:0] == 7'b0001111);
  end
`endif

  edubos5 uut (
      .clk        (clock),
      .arst_n     (!reset),
      .imem_addr  (imem_addr),
      .imem_rdat  (imem_rdat),
      .imem_rdy   (1'b1),
      .imem_vld   (),
      .dmem_addr  (dmem_addr),
      .dmem_we    (dmem_we),
      .dmem_strobe(),
      .dmem_wdat  (dmem_wdat),
      .dmem_rdat  (dmem_rdat),
      .dmem_rdy   (dmem_rdy),
      .dmem_vld   (dmem_vld),
      `RVFI_CONN
  );
endmodule

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 17, 2026
// -----------------------------------------------------------------------------
