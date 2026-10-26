//==========================================================================
// Copyright (C) 2026 Chili.CHIPS
//--------------------------------------------------------------------------
// SPDX-License-Identifier: BSD-3-Clause
//--------------------------------------------------------------------------
// Description:
//   openpcie2-rc top level co-simulation test bench.
//
//   The DUT is the REAL Root Complex, 2.rtl/0.common.opensource:
//
//        RC_opensource
//          |- pcie_top
//          |    |- clk_rst_gen        MMCM, real RTL
//          |    |- pcie_core       real RTL
//          |    |    `- PCIE_2_1     Xilinx hard macro
//          |    `- phy_top     <-- SWAPPED for models/phy_top.PIPE.sv
//          |                            (PIPE PHY model + pcievhost endpoint)
//          `- riscv_pcie_soc
//               |- picorv32 / edubos5  real RTL, runs the real firmware.hex
//               `- soc_csr -> csr   PeakRDL-generated CSR
//
//   Only two files differ from the bitstream build:
//
//     phy_top  the 7-series transceiver cannot be paired with a PIPE
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

  // The run ends RESULT_TAIL_US after the firmware reports its result, so the
  // last completion still shows; RUN_SIM_US is only the time limit for a run
  // that never reports. It is read, in microseconds, at time 0 from run_us.cfg,
  // which the make file writes from its RUN_US variable, so changing it needs
  // no re-elaboration:
  //     make run RUN_US=40000
  // A file is used rather than a plusarg because xsim's -testplusarg does not
  // accept the name=value form -- it splits the argument at the '='.
  integer RUN_SIM_US;
  localparam int RESULT_TAIL_US = 10;
  event result_seen;  // the firmware has written its result marker

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
  // clocks themselves are made inside the design (clk_rst_gen's MMCM) from the
  // TXOUTCLK that the PIPE PHY model provides.
  localparam HALF_REFCLK_PERIOD_PS = 5_000;   // 100 MHz
  localparam RST_CYCLES            = 200;

  logic refclk_p;
  wire  refclk_n;
  logic perst_n;

  initial begin
    refclk_p = 1'b0;
    perst_n = 1'b0;

    fork
      begin : board_rst_n
        #(HALF_REFCLK_PERIOD_PS * RST_CYCLES * 1ps)
          perst_n = 1'b1;
        $display("%t  TB     PERST# released", $time);
      end

      forever begin : refclk_gen
        #(HALF_REFCLK_PERIOD_PS * 1ps)
          refclk_p = ~refclk_p;
      end

      begin : run_sim
        fork
          begin : time_limit
            #(RUN_SIM_US * 1us);
            $display("\n%t  TB     *** simulation time limit reached ***", $time);
          end
          begin : result_tail
            @(result_seen);
            #(RESULT_TAIL_US * 1us);
            $display("\n%t  TB     *** run ends %0d us after the firmware result ***", $time,
                     RESULT_TAIL_US);
          end
        join_any
        report_status();
        $finish(2);
      end
    join
  end

  assign refclk_n = ~refclk_p;

//--------------------------------------------------------------
// DUT -- the real opensource Root Complex
//--------------------------------------------------------------

  wire [link_pkg::PCIE_LANES-1:0] rxp, rxn, txp, txn;  // unused: the link runs over PIPE
  wire [3:0] led_link_up;
  wire       clk_req;

  assign rxp = 1'b0;
  assign rxn = 1'b1;

  RC_opensource dut (
    .refclk_p    (refclk_p),
    .refclk_n    (refclk_n),

    .rxn          (rxn),
    .rxp          (rxp),
    .txn          (txn),
    .txp          (txp),

    .perst_n    (perst_n),

    .led_link_up  (led_link_up),
    .clk_req      (clk_req)
  );

//--------------------------------------------------------------
// Link-up watch
//--------------------------------------------------------------
// led_link_up[2] is driven with ~trn_link_up by the design, so it falling is
// the moment the PCIe link reaches L0 and the SOC comes out of reset.

  logic link_up_seen;

  initial link_up_seen = 1'b0;

  // Individual link status bits, so a stall can be pinned to a layer
  always @(dut.u_pcie.u_core.u_pcie_block.PLPHYLNKUPN)
    $display("%t  TB     pl_phy_lnk_up = %b", $time, !dut.u_pcie.u_core.u_pcie_block.PLPHYLNKUPN);
  always @(dut.core_rst_n)
    $display("%t  TB     core_rst_n   = %b", $time, dut.core_rst_n);
  always @(dut.trn_link_up)
    $display("%t  TB     trn_link_up   = %b", $time, dut.trn_link_up);

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
    if (dut.s_axis_tx.tvalid && dut.s_axis_tx.tready && !dut.s_axis_tx.tlast) begin
      $display("%t  TX-TLP hdr0=%08h hdr1=%08h", $time,
               dut.s_axis_tx.tdata[31:0], dut.s_axis_tx.tdata[63:32]);
    end
    if (dut.m_axis_rx.tvalid && dut.m_axis_rx.tready) begin
      $display("%t  RX-TLP %016h", $time, dut.m_axis_rx.tdata);
    end
  end
`endif

// The same two streams, re-timed to one DW per clock with SOP/EOP flags, the
// shape a waveform viewer's PCIe TLP decoder takes (models/tlp_dw_monitor.sv):
//   tlp_tx  RC -> EP, what the firmware sends
//   tlp_rx  EP -> RC, the completions coming back

  tlp_dw_if tx_dw (dut.user_clk);
  tlp_dw_if rx_dw (dut.user_clk);

  tlp_dw_monitor tlp_tx (
    .axis_tdata  (dut.s_axis_tx.tdata),
    .axis_tkeep  (dut.s_axis_tx.tkeep),
    .axis_tlast  (dut.s_axis_tx.tlast),
    .axis_tvalid (dut.s_axis_tx.tvalid),
    .axis_tready (dut.s_axis_tx.tready),
    .dw          (tx_dw)
  );

  tlp_dw_monitor tlp_rx (
    .axis_tdata  (dut.m_axis_rx.tdata),
    .axis_tkeep  (dut.m_axis_rx.tkeep),
    .axis_tlast  (dut.m_axis_rx.tlast),
    .axis_tvalid (dut.m_axis_rx.tvalid),
    .axis_tready (dut.m_axis_rx.tready),
    .dw          (rx_dw)
  );

// Both streams again, as the nine-signal sets the WaveCrux decoder plugin
// auto-binds to: prefix tx_ decodes RC -> EP, rx_ decodes EP -> RC, each with
// the other direction as its peer (models/tlp_wavecrux_view.sv)

  tlp_wavecrux_view tlp_view (
    .tx (tx_dw),
    .rx (rx_dw)
  );

// The SOC CPU under RVFI names, for WaveCrux's RISC-V views
// (2.rtl/0.common.opensource/src/CPU.eduBOS5/wavecrux/soc_cpu_view.sv)
`ifdef DUMP_SOC_CPU
  soc_cpu_view cpu_view (
    .clk      (dut.u_soc.clk),
    .valid    (dut.u_soc.cpu.rvfi_valid),
    .order    (dut.u_soc.cpu.rvfi_order),
    .insn     (dut.u_soc.cpu.rvfi_insn),
    .trap     (dut.u_soc.cpu.rvfi_trap),
    .halt     (dut.u_soc.cpu.rvfi_halt),
    .intr     (dut.u_soc.cpu.rvfi_intr),
    .rs1_addr (dut.u_soc.cpu.rvfi_rs1_addr),
    .rs2_addr (dut.u_soc.cpu.rvfi_rs2_addr),
    .rs1_rdata(dut.u_soc.cpu.rvfi_rs1_rdata),
    .rs2_rdata(dut.u_soc.cpu.rvfi_rs2_rdata),
    .rd_addr  (dut.u_soc.cpu.rvfi_rd_addr),
    .rd_wdata (dut.u_soc.cpu.rvfi_rd_wdata),
    .pc_rdata (dut.u_soc.cpu.rvfi_pc_rdata),
    .pc_wdata (dut.u_soc.cpu.rvfi_pc_wdata),
    .mem_addr (dut.u_soc.cpu.rvfi_mem_addr),
    .mem_rmask(dut.u_soc.cpu.rvfi_mem_rmask),
    .mem_wmask(dut.u_soc.cpu.rvfi_mem_wmask),
    .mem_rdata(dut.u_soc.cpu.rvfi_mem_rdata),
    .mem_wdata(dut.u_soc.cpu.rvfi_mem_wdata)
  );
`endif

//--------------------------------------------------------------
// VCD dump, for viewers that do not read xsim's .wdb (e.g. WaveCrux):
//     make run USRSIMOPTS="--define DUMP_VCD"     -> tb.vcd, converted to tb.x1g1.direct.fst
// Add --define DUMP_SOC_CPU for the CPU under RVFI names (CPU.eduBOS5/wavecrux).
// Only the TLP monitors, the decoder view, the SOC level, the LTSSM
// state and the decoder page of the pcieVHost endpoint (u_pcie_ep, our
// wrapper models/PIPExN__pcieVHost.sv): its 16-bit PIPE for Ferrite's PCIe
// PIPE and Data Link Layer decoders (plus rx_active for rxvalid), and the
// TLPs and DLLPs it sends and receives, from the taps we added to the model.
// That keeps the file small enough to open in seconds.
//--------------------------------------------------------------

`ifdef DUMP_VCD
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(1, tlp_tx);
    $dumpvars(1, tlp_rx);
    $dumpvars(1, tlp_view);
    $dumpvars(1, dut.u_soc);
    $dumpvars(0, dut.u_pcie.pl_ltssm_state_int);
    // the wrapper's level only: the model below it has shift registers that
    // would make the file four times larger
    $dumpvars(1, dut.u_pcie.u_phy_top.u_pcie_ep);
`ifdef PIPE_X4
    // make SIM_LANES=4: all four lanes, for the multi-lane PIPE and DLL decoders
    $dumpvars(1, dut.u_pcie.u_phy_top.u_x4);
`endif
    $dumpvars(0, dut.u_pcie.u_phy_top.rx_active);
`ifdef DUMP_SOC_CPU
    // the SOC CPU under RVFI names; last, so the ids of the signals above stay put
    $dumpvars(1, cpu_view);
`endif
  end
`endif

//--------------------------------------------------------------
// CPU activity
//--------------------------------------------------------------
// Confirms the CPU is actually executing, and how fast. Without it there
// is no way to tell a stalled CPU from one still inside a long delay loop.

`ifdef CPU_TRACE
  // What the firmware polls before it will send anything: send_tlp() spins on
  // status.phy until the Tx FSM is idle AND the hard macro reports at least one
  // free transmit buffer.
  always @(dut.cfg.tx_buf_avail)
    $display("%t  CSR    tx_buf_avail = %0d", $time, dut.cfg.tx_buf_avail);

  // Every CPU access into the CSR window
  integer csr_acc;
  initial csr_acc = 0;

  always @(posedge dut.user_clk) begin
    if ((dut.u_soc.u_soc_csr.cpuif_req && (|dut.u_soc.mem.wstrb)) ||
        (dut.u_soc.mem.valid && dut.u_soc.is_bridge && dut.u_soc.mem.ready && !(|dut.u_soc.mem.wstrb))) begin
      csr_acc = csr_acc + 1;
      if (csr_acc <= 300 || (csr_acc % 5000) == 0) begin
        $display("%t  CSR    %s [0x%02h] data=%08h  (#%0d)", $time,
                 (|dut.u_soc.mem.wstrb) ? "WR" : "RD",
                 dut.u_soc.mem.addr[7:0],
                 (|dut.u_soc.mem.wstrb) ? dut.u_soc.mem.wdata
                                           : dut.u_soc.mem.rdata, csr_acc);
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
    if (dut.u_soc.mem.valid && dut.u_soc.mem.ready && first_n < `BUS_TRACE_N) begin
      first_n = first_n + 1;
      $display("%t  BUS  %2d  addr=%08h %s data=%08h", $time, first_n,
               dut.u_soc.mem.addr,
               (|dut.u_soc.mem.wstrb) ? "WR" : "RD",
               (|dut.u_soc.mem.wstrb) ? dut.u_soc.mem.wdata
                                         : dut.u_soc.mem.rdata);
    end
  end

  integer cpu_acc;
  integer cpu_pc_min, cpu_pc_max;

  initial begin
    cpu_acc = 0; cpu_pc_min = 32'h7fffffff; cpu_pc_max = 0;
  end

  always @(posedge dut.user_clk) begin
    if (dut.u_soc.mem.valid && dut.u_soc.mem.ready) begin
      cpu_acc = cpu_acc + 1;
      if (dut.u_soc.is_ram) begin
        if (dut.u_soc.mem.addr < cpu_pc_min) cpu_pc_min = dut.u_soc.mem.addr;
        if (dut.u_soc.mem.addr > cpu_pc_max) cpu_pc_max = dut.u_soc.mem.addr;
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
// main() ends by writing a marker into status.result:
//   0x0000FACE  memory write/read back matched
//   0x0000DEAD  it did not, or the read was not completed with SC
//   0xBAD00000  no device answered the first config read (RC-switched:
//               the switch upstream port)
//   0xBAD00001  RC-switched only: the switch is up, no endpoint behind it
//   0xBAD00002  a later config request failed (UR/CA/timeout)
//   0xBAD00003  BAR0 is not implemented, is I/O, or does not fit
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
    if (dut.u_soc.mem.valid && dut.u_soc.mem.ready &&
        dut.u_soc.is_bridge && !(|dut.u_soc.mem.wstrb) &&
        dut.u_soc.mem.addr[7:0] == 8'h14) begin
      rx_data_last = dut.u_soc.mem.rdata;
    end
  end

  // A write is counted on the CSR request strobe, once per access: picorv32
  // holds valid until ready, but eduBOS5 stores are one-cycle requests whose
  // ready comes after valid has dropped
  // tx.data (0x0C) launches a TLP; status.result (0x24) carries the marker
  always @(posedge dut.user_clk) begin
    if (dut.u_soc.u_soc_csr.cpuif_req && (|dut.u_soc.mem.wstrb)) begin

      if (dut.u_soc.mem.addr[7:0] == 8'h0c) begin
        tlp_tx_count = tlp_tx_count + 1;

        // Fmt/Type 0x40 is a Memory Write; its payload is this very dword
        if (dut.u_soc.tx_dw0[31:24] == 8'h40) begin
          mem_wr_payload = dut.u_soc.mem.wdata;
          mem_wr_seen    = 1'b1;
        end
      end

      if (dut.u_soc.mem.addr[7:0] == 8'h24) begin
        result_marker  = dut.u_soc.mem.wdata;
        mem_rd_payload = rx_data_last;
        $display("\n%t  TB     ===> FIRMWARE RESULT 0x%08h  (%s)\n", $time,
                 dut.u_soc.mem.wdata,
                 (dut.u_soc.mem.wdata == 32'h0000_face) ? "PASS" : "FAIL");
        ->result_seen;
      end
    end
  end

`ifdef SOC_IPC
  // IPC: instructions the CPU retires (RVFI) per user_clk cycle, from SOC
  // reset release to the firmware result. The Makefile adds RISCV_FORMAL.
  longint ipc_cycles = 0, ipc_instrs = 0;
  bit     ipc_on = 1'b1;
  always @(posedge dut.user_clk) begin
    if (ipc_on && dut.u_soc.resetn) begin
      ipc_cycles++;
      if (dut.u_soc.cpu.rvfi_valid) ipc_instrs++;
    end
  end
  always @(result_seen) begin
    ipc_on = 1'b0;
    $display("%t  TB     IPC %0d instructions / %0d cycles = %0.4f", $time, ipc_instrs,
             ipc_cycles, real'(ipc_instrs) / real'(ipc_cycles));
  end
`endif

//--------------------------------------------------------------
// Final report
//--------------------------------------------------------------

  task automatic report_status();
    $display("--------------------------------------------------------");
    $display(" openpcie2-rc co-simulation summary");
    $display("--------------------------------------------------------");
    $display("  PCIe link up ............ %s", link_up_seen ? "YES" : "NO");
    $display("  LTSSM final state ....... 0x%02h",
             dut.u_pcie.pl_ltssm_state_int);
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
      32'hbad0_0000: $display("  FIRMWARE RESULT ......... no device at bus 1 (switched: the switch) (0x%08h)", result_marker);
      32'hbad0_0001: $display("  FIRMWARE RESULT ......... switch up, no endpoint behind it (0x%08h)", result_marker);
      32'hbad0_0002: $display("  FIRMWARE RESULT ......... config request failed (0x%08h)", result_marker);
      32'hbad0_0003: $display("  FIRMWARE RESULT ......... BAR0 not usable (0x%08h)", result_marker);
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
 2026/10/07:    DUT is RC_opensource from 2.rtl/0.common.opensource, the RTL
                shared by RC-direct and RC-switched; 0xBAD00001 decoded
 2026/10/08:    DUMP_VCD also dumps the 16-bit PIPE at the pcieVHost endpoint,
                for Ferrite's PCIe PIPE / Data Link Layer WaveCrux decoders
 2026/10/17:    firmware result read from status.result, which sends no TLP
*/

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
