// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openPCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
// Description:
//   Simulation-only view of the SOC CPU for WaveCrux's RISC-V views: the
//   instruction-trace decoder and the RVFI Commit Inspector. It shows the
//   retired instructions under the riscv-formal RVFI names, which WaveCrux
//   binds by name, whichever CPU the SOC has: all 21 RVFI channels.
//
//   With `define DUMP_SOC_CPU, 5.sim/tb.sv connects it (cpu_view) to the SOC
//   CPU's RVFI outputs, dut.u_soc.cpu.rvfi_*: one connection fits every core
//   that has them. eduBOS5 and PicoRV32 build them with `define RISCV_FORMAL,
//   which the 5.sim Makefile adds with DUMP_SOC_CPU. Both run in machine
//   mode, 32-bit, so mode and ixl are constants here (PicoRV32 has no port
//   for them).
//==========================================================================

module soc_cpu_view (
    input logic        clk,
    input logic        valid,      // one clock per retired instruction
    input logic [63:0] order,      // its number
    input logic [31:0] insn,
    input logic        trap,
    input logic        halt,
    input logic        intr,
    input logic [ 4:0] rs1_addr,   // 0: not read
    input logic [ 4:0] rs2_addr,
    input logic [31:0] rs1_rdata,
    input logic [31:0] rs2_rdata,
    input logic [ 4:0] rd_addr,    // 0: no register written
    input logic [31:0] rd_wdata,
    input logic [31:0] pc_rdata,   // its address
    input logic [31:0] pc_wdata,   // the next one
    input logic [31:0] mem_addr,
    input logic [ 3:0] mem_rmask,
    input logic [ 3:0] mem_wmask,
    input logic [31:0] mem_rdata,
    input logic [31:0] mem_wdata
);

  logic        rvfi_clk;
  logic        rvfi_valid;
  logic [63:0] rvfi_order;
  logic [31:0] rvfi_insn;
  logic        rvfi_trap;
  logic        rvfi_halt;
  logic        rvfi_intr;
  logic [ 1:0] rvfi_mode;
  logic [ 1:0] rvfi_ixl;
  logic [ 4:0] rvfi_rs1_addr;
  logic [ 4:0] rvfi_rs2_addr;
  logic [31:0] rvfi_rs1_rdata;
  logic [31:0] rvfi_rs2_rdata;
  logic [ 4:0] rvfi_rd_addr;
  logic [31:0] rvfi_rd_wdata;
  logic [31:0] rvfi_pc_rdata;
  logic [31:0] rvfi_pc_wdata;
  logic [31:0] rvfi_mem_addr;
  logic [ 3:0] rvfi_mem_rmask;
  logic [ 3:0] rvfi_mem_wmask;
  logic [31:0] rvfi_mem_rdata;
  logic [31:0] rvfi_mem_wdata;

  always_comb begin
    rvfi_clk       = clk;
    rvfi_valid     = valid;
    rvfi_order     = order;
    rvfi_insn      = insn;
    rvfi_trap      = trap;
    rvfi_halt      = halt;
    rvfi_intr      = intr;
    rvfi_mode      = 2'd3;  // machine mode
    rvfi_ixl       = 2'd1;  // 32-bit
    rvfi_rs1_addr  = rs1_addr;
    rvfi_rs2_addr  = rs2_addr;
    rvfi_rs1_rdata = rs1_rdata;
    rvfi_rs2_rdata = rs2_rdata;
    rvfi_rd_addr   = rd_addr;
    rvfi_rd_wdata  = rd_wdata;
    rvfi_pc_rdata  = pc_rdata;
    rvfi_pc_wdata  = pc_wdata;
    rvfi_mem_addr  = mem_addr;
    rvfi_mem_rmask = mem_rmask;
    rvfi_mem_wmask = mem_wmask;
    rvfi_mem_rdata = mem_rdata;
    rvfi_mem_wdata = mem_wdata;
  end

endmodule : soc_cpu_view

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 16, 2026
// -----------------------------------------------------------------------------
