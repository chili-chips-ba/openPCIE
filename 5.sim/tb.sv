//==========================================================================
// Copyright (C) 2026 Chili.CHIPS*ba
//--------------------------------------------------------------------------
// SPDX-License-Identifier: BSD-3-Clause
//--------------------------------------------------------------------------
// Description:
//   openpcie2-rc top level co-simulation test bench.
//
//   The DUT is the REAL Root Complex, 2.rtl/2.RC-direct.opensource:
//
//        RC_direct_opensource
//          |- host_bridge
//          |    |- clk_synth        MMCM, real RTL
//          |    |- txn_engine       real RTL
//          |    |    `- silicon_core -> PCIE_2_1   Xilinx hard macro
//          |    `- serdes_front     <-- SWAPPED for models/serdes_front.PIPE.sv
//          |                            (PIPE PHY model + pcievhost endpoint)
//          `- riscv_pcie_soc
//               |- picorv32         real RTL, runs the real firmware.hex
//               `- soc_csr -> csr   PeakRDL-generated CSR
//
//   Only two files differ from the bitstream build:
//
//     serdes_front  the 7-series transceiver cannot be paired with a PIPE
//                   level VIP, so a behavioural PIPE PHY takes its place and
//                   carries the pcieVHost endpoint on its far side
//     firmware.hex  read by riscv_pcie_soc.sv with $readmemh, copied into the
//                   simulation directory by the Makefile
//
//   Everything else -- the hard macro, the transaction layer, the CPU, the
//   CSR and the software -- is exactly what goes into the FPGA.
//==========================================================================

`timescale 1ps/1ps

module tb;

  // How long to run, in microseconds. Read at time 0 from run_us.cfg, which the
  // make file writes from its RUN_US variable, so changing the run length needs
  // no re-elaboration:
  //     make run RUN_US=40000
  // A file is used rather than a plusarg because xsim's -testplusarg does not
  // accept the name=value form -- it splits the argument at the '='.
  integer RUN_SIM_US;

  initial begin : get_run_length
    integer fh;
    integer code;

    RUN_SIM_US = 2000;

    fh = $fopen("run_us.cfg", "r");
    if (fh != 0) begin
      code = $fscanf(fh, "%d", RUN_SIM_US);
      $fclose(fh);
      if (code != 1 || RUN_SIM_US <= 0) begin
        RUN_SIM_US = 2000;
      end
    end

    $display("%t  TB     run length %0d us", $time, RUN_SIM_US);
  end

//--------------------------------------------------------------
// Clock and reset generation
//--------------------------------------------------------------

  // The 100 MHz PCIe reference clock, as supplied by the backplane. The link
  // clocks themselves are made inside the design (clk_synth's MMCM) from the
  // TXOUTCLK that the PIPE PHY model provides.
  localparam HALF_REFCLK_PERIOD_PS = 5_000;   // 100 MHz
  localparam RST_CYCLES            = 200;

  logic sys_clk_p;
  wire  sys_clk_n;
  logic sys_rst_n;

  initial begin
    sys_clk_p = 1'b0;
    sys_rst_n = 1'b0;

    fork
      begin : board_rst_n
        #(HALF_REFCLK_PERIOD_PS * RST_CYCLES * 1ps)
          sys_rst_n = 1'b1;
        $display("%t  TB     PERST# released", $time);
      end

      forever begin : refclk_gen
        #(HALF_REFCLK_PERIOD_PS * 1ps)
          sys_clk_p = ~sys_clk_p;
      end

      begin : run_sim
        #(RUN_SIM_US * 1us);
        $display("\n%t  TB     *** simulation time limit reached ***", $time);
        report_status();
        $finish(2);
      end
    join
  end

  assign sys_clk_n = ~sys_clk_p;

//--------------------------------------------------------------
// DUT -- the real opensource Root Complex
//--------------------------------------------------------------

  wire [0:0] RXP, RXN, TXP, TXN;
  wire [3:0] led_link_up;
  wire       clk_req;

  assign RXP = 1'b0;
  assign RXN = 1'b1;

  RC_direct_opensource dut (
    .sys_clk_p    (sys_clk_p),
    .sys_clk_n    (sys_clk_n),

    .RXN          (RXN),
    .RXP          (RXP),
    .TXN          (TXN),
    .TXP          (TXP),

    .sys_rst_n    (sys_rst_n),

    .led_link_up  (led_link_up),
    .clk_req      (clk_req)
  );

//--------------------------------------------------------------
// Link-up watch
//--------------------------------------------------------------
// led_link_up[2] is driven with ~user_lnk_up by the design, so it falling is
// the moment the PCIe link reaches L0 and the SOC comes out of reset.

  logic link_up_seen;

  initial link_up_seen = 1'b0;

  // Individual link status bits, so a stall can be pinned to a layer
  always @(dut.user_lnk_up)
    $display("%t  TB     user_lnk_up  = %b", $time, dut.user_lnk_up);
  always @(dut.user_reset)
    $display("%t  TB     user_reset   = %b", $time, dut.user_reset);
  always @(dut.pcie_inst.trn_lnk_up)
    $display("%t  TB     trn_lnk_up   = %b", $time, dut.pcie_inst.trn_lnk_up);
  always @(dut.pcie_inst.pl_phy_lnk_up_wire)
    $display("%t  TB     phy_lnk_up   = %b", $time, dut.pcie_inst.pl_phy_lnk_up_wire);

  always @(negedge led_link_up[2]) begin
    if (!link_up_seen) begin
      link_up_seen = 1'b1;
      $display("\n%t  TB     ===> PCIe LINK UP -- SOC released from reset\n", $time);
    end
  end

//--------------------------------------------------------------
// TLP watch on the SOC's AXI-Stream interface
//--------------------------------------------------------------
// This is the software's view of the link: every TLP the firmware pushes out
// and every completion that comes back. It is the quickest way to see whether
// enumeration is making progress without opening a waveform.

`ifndef NO_TLP_TRACE
  always @(posedge dut.user_clk) begin
    if (dut.s_axis_tx_tvalid && dut.s_axis_tx_tready && !dut.s_axis_tx_tlast) begin
      $display("%t  TX-TLP hdr0=%08h hdr1=%08h", $time,
               dut.s_axis_tx_tdata[31:0], dut.s_axis_tx_tdata[63:32]);
    end
    if (dut.m_axis_rx_tvalid && dut.m_axis_rx_tready) begin
      $display("%t  RX-TLP %016h", $time, dut.m_axis_rx_tdata);
    end
  end
`endif

//--------------------------------------------------------------
// CPU activity
//--------------------------------------------------------------
// Confirms the picorv32 is actually executing, and how fast. Without it there
// is no way to tell a stalled CPU from one still inside a long delay loop.

`ifdef CPU_TRACE
  // What the firmware polls before it will send anything: send_tlp() spins on
  // status.phy until the Tx FSM is idle AND the hard macro reports at least one
  // free transmit buffer.
  always @(dut.rport_tx_buf_av)
    $display("%t  CSR    tx_buf_av = %0d", $time, dut.rport_tx_buf_av);

  // Every CPU access into the CSR window
  integer csr_acc;
  initial csr_acc = 0;

  always @(posedge dut.user_clk) begin
    if (dut.soc_inst.mem_valid && dut.soc_inst.is_bridge && dut.soc_inst.mem_ready) begin
      csr_acc = csr_acc + 1;
      if (csr_acc <= 300 || (csr_acc % 5000) == 0) begin
        $display("%t  CSR    %s [0x%02h] data=%08h  (#%0d)", $time,
                 (|dut.soc_inst.mem_wstrb) ? "WR" : "RD",
                 dut.soc_inst.mem_addr[7:0],
                 (|dut.soc_inst.mem_wstrb) ? dut.soc_inst.mem_wdata
                                           : dut.soc_inst.mem_rdata, csr_acc);
      end
    end
  end

  // First bus accesses after reset release, to see where the CPU actually goes.
  // Override the count with +define+BUS_TRACE_N=<n>.
`ifndef BUS_TRACE_N
  `define BUS_TRACE_N 60
`endif
  integer first_n;
  initial first_n = 0;

  always @(posedge dut.user_clk) begin
    if (dut.soc_inst.mem_valid && dut.soc_inst.mem_ready && first_n < `BUS_TRACE_N) begin
      first_n = first_n + 1;
      $display("%t  BUS  %2d  addr=%08h %s data=%08h", $time, first_n,
               dut.soc_inst.mem_addr,
               (|dut.soc_inst.mem_wstrb) ? "WR" : "RD",
               (|dut.soc_inst.mem_wstrb) ? dut.soc_inst.mem_wdata
                                         : dut.soc_inst.mem_rdata);
    end
  end

  integer cpu_acc;
  integer cpu_pc_min, cpu_pc_max;

  initial begin
    cpu_acc = 0; cpu_pc_min = 32'h7fffffff; cpu_pc_max = 0;
  end

  always @(posedge dut.user_clk) begin
    if (dut.soc_inst.mem_valid && dut.soc_inst.mem_ready) begin
      cpu_acc = cpu_acc + 1;
      if (dut.soc_inst.is_ram) begin
        if (dut.soc_inst.mem_addr < cpu_pc_min) cpu_pc_min = dut.soc_inst.mem_addr;
        if (dut.soc_inst.mem_addr > cpu_pc_max) cpu_pc_max = dut.soc_inst.mem_addr;
      end
    end
  end

  initial forever begin
    #(1000 * 1us);
    $display("%t  CPU    %0d bus accesses, RAM addr range 0x%08h..0x%08h",
             $time, cpu_acc, cpu_pc_min, cpu_pc_max);
  end
`endif

//--------------------------------------------------------------
// Firmware result
//--------------------------------------------------------------
// main() ends by writing a marker into the Tx payload register:
//   0x0000FACE  memory write/read back matched
//   0x0000DEAD  it did not
//   0xBAD00000  no endpoint answered the first config read
// Everything before that is the enumeration sequence.

  logic [31:0] result_marker;
  integer      tlp_tx_count;

  // The marker only says pass or fail. These two carry the payload the test
  // actually moved across the link, so the summary can show the data rather
  // than just the verdict:
  //   mem_wr_payload  the dword written to the endpoint by a Memory Write TLP
  //                   (tx.header0[31:24] == 0x40 marks one)
  //   mem_rd_payload  the dword the last completion brought back, read by the
  //                   firmware out of rx.data (offset 0x14)
  logic [31:0] mem_wr_payload;
  logic [31:0] mem_rd_payload;
  logic [31:0] rx_data_last;
  logic        mem_wr_seen;

  initial begin
    result_marker  = 32'hffff_ffff;
    tlp_tx_count   = 0;
    mem_wr_payload = 32'h0;
    mem_rd_payload = 32'h0;
    rx_data_last   = 32'h0;
    mem_wr_seen    = 1'b0;
  end

  // Every firmware read of rx.data. The last one before the marker is the
  // memory read-back, so it is frozen into mem_rd_payload when the marker lands.
  always @(posedge dut.user_clk) begin
    if (dut.soc_inst.mem_valid && dut.soc_inst.mem_ready &&
        dut.soc_inst.is_bridge && !(|dut.soc_inst.mem_wstrb) &&
        dut.soc_inst.mem_addr[7:0] == 8'h14) begin
      rx_data_last = dut.soc_inst.mem_rdata;
    end
  end

  always @(posedge dut.user_clk) begin
    if (dut.soc_inst.mem_valid && dut.soc_inst.mem_ready &&
        dut.soc_inst.is_bridge && (|dut.soc_inst.mem_wstrb) &&
        dut.soc_inst.mem_addr[7:0] == 8'h0c) begin

      tlp_tx_count = tlp_tx_count + 1;

      // Fmt/Type 0x40 is a Memory Write; its payload is this very dword
      if (dut.soc_inst.tx_header0[31:24] == 8'h40) begin
        mem_wr_payload = dut.soc_inst.mem_wdata;
        mem_wr_seen    = 1'b1;
      end

      if (dut.soc_inst.mem_wdata == 32'h0000_face ||
          dut.soc_inst.mem_wdata == 32'h0000_dead ||
          dut.soc_inst.mem_wdata == 32'hbad0_0000) begin
        result_marker  = dut.soc_inst.mem_wdata;
        mem_rd_payload = rx_data_last;
        $display("\n%t  TB     ===> FIRMWARE RESULT 0x%08h  (%s)\n", $time,
                 dut.soc_inst.mem_wdata,
                 (dut.soc_inst.mem_wdata == 32'h0000_face) ? "PASS" : "FAIL");
      end
    end
  end

//--------------------------------------------------------------
// Final report
//--------------------------------------------------------------

  task automatic report_status();
    $display("--------------------------------------------------------");
    $display(" openpcie2-rc co-simulation summary");
    $display("--------------------------------------------------------");
    $display("  PCIe link up ............ %s", link_up_seen ? "YES" : "NO");
    $display("  LTSSM final state ....... 0x%02h",
             dut.pcie_inst.pl_ltssm_state_int);
    $display("  cfg_status .............. 0x%04h", dut.cfg_status_wire);
    $display("  TLPs sent by firmware ... %0d", tlp_tx_count);

    if (mem_wr_seen) begin
      $display("  Payload written to EP ... 0x%08h  (Memory Write TLP)",
               mem_wr_payload);
      // if/else rather than a ternary: Verilog widens both string literals to
      // the longer one, which would left-pad the shorter with NULs
      if (mem_rd_payload === mem_wr_payload)
        $display("  Payload read back ....... 0x%08h  (match)", mem_rd_payload);
      else
        $display("  Payload read back ....... 0x%08h  (MISMATCH)", mem_rd_payload);
    end

    case (result_marker)
      32'h0000_face: $display("  FIRMWARE RESULT ......... PASS (0x%08h)", result_marker);
      32'h0000_dead: $display("  FIRMWARE RESULT ......... FAIL (0x%08h)", result_marker);
      32'hbad0_0000: $display("  FIRMWARE RESULT ......... no endpoint found (0x%08h)", result_marker);
      default:       $display("  FIRMWARE RESULT ......... not reached yet");
    endcase
    $display("--------------------------------------------------------");
  endtask

// Top level fatal task, which can be called from anywhere in verilog code
// via the `fatal definition in pciedispheader.v.
task Fatal;
begin
    $display("***FATAL ERROR...calling $finish!");
    $finish;
end
endtask

endmodule: tb

/*
------------------------------------------------------------------------------
Version History:
------------------------------------------------------------------------------
 2025/08/19 SS: initial creation, against the dut_stub stand-in
 2026/08/11:    retargeted at the real RC_direct_opensource RTL, with the
                pcievhost endpoint moved behind the PIPE PHY model
*/
