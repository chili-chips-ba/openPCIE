// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// Formal miter for the capture side of the eduBOS5 MCP (run-mcp-formal.sh):
// whatever a register captures at the 1st edge after launch is never used.
// Two cores run on the same inputs. Core B sees an arbitrary instruction
// word (and so arbitrary rs1/rs2) in the cycle after each launch edge: a
// path that has not settled. Both must drive the same bus and RF writes.
//==========================================================================
module edubos5_mcp_miter
  import edubos5_pkg::*;
#(
    parameter bit EN_WAIT4REGS = 1  // 0: the 2-stage core, which must fail
) (
    input logic      clk,
    input cpu_data_t imem_word,  // the RAM contents at the address, free
    input cpu_data_t imem_junk,  // what core B sees before the path settles
    input cpu_data_t dmem_rdat,
    input logic      dmem_rdy
);
  cpu_pc_t imem_addr_a, imem_addr_b;
  cpu_data_t imem_rdat, dmem_addr_a, dmem_addr_b, dmem_wdat_a, dmem_wdat_b;
  logic imem_vld_a, imem_vld_b, dmem_vld_a, dmem_vld_b, strobe_a, strobe_b;
  we_bs_t dmem_we_a, dmem_we_b;

  logic [1:0] rst_cnt = '0;  // reset for the first 2 clocks
  logic       arst_n;
  assign arst_n = rst_cnt[1];
  always_ff @(posedge clk) begin
    if (!arst_n) rst_cnt <= rst_cnt + 2'd1;
  end

  // synchronous instruction RAM, read by core A's address
  always_ff @(posedge clk) begin
    imem_rdat <= imem_word;
  end
  always @(posedge clk) begin
    if ($past(arst_n) && imem_addr_a == $past(imem_addr_a)) begin  // free in reset
      assume (imem_word == $past(imem_word));
    end
  end

  // the openPCIE SOC's data bus (riscv_pcie_soc.sv): ready reaches the core
  // only in the cycle after a read that was still waiting
  logic load_wait = 1'b0;
  always_ff @(posedge clk) begin
    load_wait <= dmem_vld_a && dmem_we_a == NOWR && !dmem_rdy;
  end
  always @(posedge clk) begin
    if (dmem_rdy) begin
      assume (load_wait);
    end
  end

  // legal RV32I stores only (SB, SH, SW): an illegal funct3 makes a bus cycle
  // without write strobes, which the SOC takes for a read
  always @(posedge clk) begin
    if (imem_word[6:0] == 7'b0100011) begin
      assume (imem_word[14:12] <= 3'd2);
    end
  end

  // the cycle after a launch edge (the edge that ends FETCH_INSTR)
  logic settling = 1'b0;
  always_ff @(posedge clk) begin
    settling <= arst_n && u_a.state == 3'd0;  // FETCH_INSTR
  end

  edubos5 #(
      .EN_WAIT4REGS(EN_WAIT4REGS)
  ) u_a (
      .clk        (clk),
      .arst_n     (arst_n),
      .imem_addr  (imem_addr_a),
      .imem_rdat  (imem_rdat),
      .imem_rdy   (1'b1),
      .imem_vld   (imem_vld_a),
      .dmem_addr  (dmem_addr_a),
      .dmem_we    (dmem_we_a),
      .dmem_strobe(strobe_a),
      .dmem_wdat  (dmem_wdat_a),
      .dmem_rdat  (dmem_rdat),
      .dmem_rdy   (dmem_rdy),
      .dmem_vld   (dmem_vld_a)
  );

  edubos5 #(
      .EN_WAIT4REGS(EN_WAIT4REGS)
  ) u_b (
      .clk        (clk),
      .arst_n     (arst_n),
      .imem_addr  (imem_addr_b),
      .imem_rdat  (settling ? imem_junk : imem_rdat),
      .imem_rdy   (1'b1),
      .imem_vld   (imem_vld_b),
      .dmem_addr  (dmem_addr_b),
      .dmem_we    (dmem_we_b),
      .dmem_strobe(strobe_b),
      .dmem_wdat  (dmem_wdat_b),
      .dmem_rdat  (dmem_rdat),
      .dmem_rdy   (dmem_rdy),
      .dmem_vld   (dmem_vld_b)
  );

  // same fetches, bus cycles and register writes
  always @(posedge clk) begin
    if (arst_n) begin
      assert (imem_addr_a == imem_addr_b && imem_vld_a == imem_vld_b);
      assert (dmem_vld_a == dmem_vld_b && dmem_we_a == dmem_we_b);
      if (dmem_vld_a) begin
        assert (dmem_addr_a == dmem_addr_b && strobe_a == strobe_b);
      end
      if (dmem_vld_a && dmem_we_a != NOWR) begin
        assert (dmem_wdat_a == dmem_wdat_b);
      end
      assert (u_a.rf_we == u_b.rf_we);
      if (u_a.rf_we) begin
        assert (u_a.u_rf.rd_addr == u_b.u_rf.rd_addr && u_a.rf_wdat == u_b.rf_wdat);
      end
    end
  end
endmodule : edubos5_mcp_miter

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 16, 2026
// -----------------------------------------------------------------------------
