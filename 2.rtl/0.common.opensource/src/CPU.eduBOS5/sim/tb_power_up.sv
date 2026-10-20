// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// eduBOS5 before reset acts (run-power-up.sh): arst_n is low from time 0, so
// the asynchronous reset has no edge and acts only at the first clock (5 ns).
// Prints the FSM state and RVFI at time 0, at 2 ns and after the first clock.
// IMEM returns NOP (addi x0, x0, 0); DMEM never answers.
//==========================================================================
module tb_power_up;
  import edubos5_pkg::*;
  parameter int EN_WAIT4REGS = 0;

  logic clk = 1'b0;
  logic arst_n = 1'b0;
  always begin
    #5 clk = ~clk;
  end
  initial begin
    #25 arst_n = 1'b1;
  end

  logic rvfi_valid, rvfi_trap, rvfi_halt, rvfi_intr;
  logic [63:0] rvfi_order;
  logic [31:0] rvfi_insn, rvfi_rs1_rdata, rvfi_rs2_rdata, rvfi_rd_wdata;
  logic [31:0] rvfi_pc_rdata, rvfi_pc_wdata, rvfi_mem_addr, rvfi_mem_rdata, rvfi_mem_wdata;
  logic [4:0] rvfi_rs1_addr, rvfi_rs2_addr, rvfi_rd_addr;
  logic [3:0] rvfi_mem_rmask, rvfi_mem_wmask;
  logic [1:0] rvfi_mode, rvfi_ixl;

  cpu_pc_t imem_addr;
  cpu_addr_t dmem_addr;
  we_bs_t dmem_we;
  cpu_data_t dmem_wdat;
  logic imem_vld, dmem_strobe, dmem_vld;

  edubos5 #(
      .EN_WAIT4REGS(EN_WAIT4REGS)
  ) uut (
      .clk,
      .arst_n,
      .rvfi_valid,
      .rvfi_order,
      .rvfi_insn,
      .rvfi_trap,
      .rvfi_halt,
      .rvfi_intr,
      .rvfi_mode,
      .rvfi_ixl,
      .rvfi_rs1_addr,
      .rvfi_rs2_addr,
      .rvfi_rs1_rdata,
      .rvfi_rs2_rdata,
      .rvfi_rd_addr,
      .rvfi_rd_wdata,
      .rvfi_pc_rdata,
      .rvfi_pc_wdata,
      .rvfi_mem_addr,
      .rvfi_mem_rmask,
      .rvfi_mem_wmask,
      .rvfi_mem_rdata,
      .rvfi_mem_wdata,
      .imem_addr,
      .imem_rdat  (32'h0000_0013),
      .imem_rdy   (1'b1),
      .imem_vld,
      .dmem_addr,
      .dmem_we,
      .dmem_strobe,
      .dmem_wdat,
      .dmem_rdat  ('0),
      .dmem_rdy   (1'b0),
      .dmem_vld
  );

  task automatic show();
    $display("t=%0t ns arst_n=%b state=%b rvfi_valid=%b rvfi_order=%0d", $time, arst_n, uut.state,
             rvfi_valid, rvfi_order);
  endtask

  initial begin
    #0 show();
    #2 show();
    @(posedge clk);
    #1 show();
    $finish;
  end
endmodule : tb_power_up
