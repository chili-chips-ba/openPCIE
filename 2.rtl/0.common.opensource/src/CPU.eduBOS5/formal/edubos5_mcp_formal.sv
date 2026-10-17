// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// Formal harness for the eduBOS5 3-stage MCP proof (run-mcp-formal.sh):
// the core with EN_WAIT4REGS=1 and `define EDUBOS5_MCP_FORMAL. Inputs are
// free, after a 2-clock reset. One assumption models a synchronous
// instruction RAM: the read data changes only if the address changed.
//==========================================================================
module edubos5_mcp_formal
  import edubos5_pkg::*;
#(
    parameter bit EN_WAIT4REGS = 1  // 0: the 2-stage core (passes too: source side only)
) (
    input logic      clk,
    input cpu_data_t imem_word,  // the RAM contents at the address, free
    input cpu_data_t dmem_rdat,
    input logic      dmem_rdy
);
  cpu_pc_t         imem_addr;
  cpu_data_t       imem_rdat;

  logic      [1:0] rst_cnt = '0;  // reset for the first 2 clocks
  logic            arst_n;
  assign arst_n = rst_cnt[1];
  always_ff @(posedge clk) begin
    if (!arst_n) rst_cnt <= rst_cnt + 2'd1;
  end

  // synchronous read: imem_rdat follows the address of the clock before
  always_ff @(posedge clk) begin
    imem_rdat <= imem_word;
  end
  always @(posedge clk) begin
    if ($past(arst_n) && imem_addr == $past(imem_addr)) begin  // free in reset
      assume (imem_word == $past(imem_word));
    end
  end

  edubos5 #(
      .EN_WAIT4REGS(EN_WAIT4REGS)
  ) u_cpu (
      .clk        (clk),
      .arst_n     (arst_n),
      .imem_addr  (imem_addr),
      .imem_rdat  (imem_rdat),
      .imem_rdy   (1'b1),
      .imem_vld   (),
      .dmem_addr  (),
      .dmem_we    (),
      .dmem_strobe(),
      .dmem_wdat  (),
      .dmem_rdat  (dmem_rdat),
      .dmem_rdy   (dmem_rdy),
      .dmem_vld   ()
  );
endmodule : edubos5_mcp_formal

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 16, 2026
// -----------------------------------------------------------------------------
