// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openPCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
//                   Copyright (C) 2026 Chili.CHIPS
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
// contributors may be used to endorse or promote products derived
// from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
// IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//              https://opensource.org/license/bsd-3-clause
//--------------------------------------------------------------------------

module riscv_pcie_soc
  import pcie_pkg::*;
(
    input logic clk,
    input logic resetn,

    axis_if.master s_axis_tx,  // TLPs to the PCIE stack
    axis_if.slave  m_axis_rx,  // TLPs from the PCIE stack

    cfg_if.soc cfg  // status sideband from the PCIE core
);

  mem_if mem ();  // CPU memory bus

  logic        ram_ready;
  logic [31:0] ram_rdata;

  logic [31:0] tx_packet_counter;

  logic        is_ram;
  logic        is_bridge;

  // CPU address: region [31:24] and RAM word [12:2] are decoded; [23:13] are
  // not (the RAM repeats within its region) and [1:0] are byte lanes, which
  // the word bus carries in wstrb -- both no-connect
  logic [ 7:0] addr_region;
  assign addr_region = mem.addr[31:24];
  logic [10:0] NC_addr_mid;
  assign NC_addr_mid = mem.addr[23:13];
  logic [10:0] addr_word;
  assign addr_word = mem.addr[12:2];
  logic [1:0] NC_addr_byte;
  assign NC_addr_byte = mem.addr[1:0];

  assign is_ram       = (addr_region == 8'h00);
  assign is_bridge    = (addr_region == 8'h30);

  // -------------------------------------------------------------------------
  // The CPU -- two interchangeable implementations
  //
  //   default             : the picorv32 RTL core, executing firmware.hex out
  //                         of the instruction RAM below. This is what goes
  //                         into the bitstream.
  //   `define SOC_CPU_VPROC : the VProc virtual processor, so that a native
  //                         C/C++ program or the rv32 ISS drives the very
  //                         same bus. Co-simulation only -- see
  //                         5.sim/models/soc_cpu.VPROC.picorv32.sv and
  //                         "make CPU=vproc" / "make CPU=iss" in 5.sim.
  //
  // Nothing else in the SOC changes: the address decode, the CSR and the PCIe
  // stack see an identical memory interface either way.
  // -------------------------------------------------------------------------
`ifdef SOC_CPU_VPROC
  soc_cpu_vproc #(
      .NODE(4'd0)
  ) cpu (
      .clk      (clk),
      .resetn   (resetn),
      .mem_valid(mem.valid),
      .mem_ready(mem.ready),
      .mem_addr (mem.addr),
      .mem_wdata(mem.wdata),
      .mem_wstrb(mem.wstrb),
      .mem_rdata(mem.rdata)
  );
`else
  picorv32 #(
      .PROGADDR_RESET (32'h0000_0000),
      .STACKADDR      (32'h0000_2000),
      .BARREL_SHIFTER (1),
      .ENABLE_COUNTERS(1)
  ) cpu (
      .clk         (clk),
      .resetn      (resetn),
      .trap        (  /*LINT:OK*/),  // not monitored
      .mem_valid   (mem.valid),
      .mem_instr   (  /*LINT:OK*/),  // one RAM holds both code and data (IMEM = DMEM)
      .mem_ready   (mem.ready),
      .mem_addr    (mem.addr),
      .mem_wdata   (mem.wdata),
      .mem_wstrb   (mem.wstrb),
      .mem_rdata   (mem.rdata),
      // unused inputs are tied off (ENABLE_PCPI and ENABLE_IRQ are 0)
      .mem_la_read (  /*LINT:OK*/),  // look-ahead bus, the mem_* bus is used
      .mem_la_write(  /*LINT:OK*/),  // look-ahead bus, the mem_* bus is used
      .mem_la_addr (  /*LINT:OK*/),  // look-ahead bus, the mem_* bus is used
      .mem_la_wdata(  /*LINT:OK*/),  // look-ahead bus, the mem_* bus is used
      .mem_la_wstrb(  /*LINT:OK*/),  // look-ahead bus, the mem_* bus is used
      .pcpi_valid  (  /*LINT:OK*/),  // ENABLE_PCPI is 0
      .pcpi_insn   (  /*LINT:OK*/),  // ENABLE_PCPI is 0
      .pcpi_rsrc1  (  /*LINT:OK*/),  // ENABLE_PCPI is 0
      .pcpi_rsrc2  (  /*LINT:OK*/),  // ENABLE_PCPI is 0
      .pcpi_wr     (1'b0),
      .pcpi_rdst   ('0),
      .pcpi_wait   (1'b0),
      .pcpi_ready  (1'b0),
      .irq         ('0),
      .eoi         (  /*LINT:OK*/),  // ENABLE_IRQ is 0
      .trace_valid (  /*LINT:OK*/),  // ENABLE_TRACE is 0
      .trace_data  (  /*LINT:OK*/)   // ENABLE_TRACE is 0
  );
`endif

  logic [31:0] ram[0:2047];
  initial begin
    $readmemh("firmware.hex", ram);
  end

  always_ff @(posedge clk) begin
    ram_ready <= 1'b0;
    if (mem.valid && is_ram) begin
      if (mem.wstrb == '0) begin
        ram_rdata <= ram[addr_word];
        ram_ready <= 1'b1;
      end
      else begin
        if (mem.wstrb[0]) begin
          ram[addr_word][7:0] <= mem.wdata[7:0];
        end
        if (mem.wstrb[1]) begin
          ram[addr_word][15:8] <= mem.wdata[15:8];
        end
        if (mem.wstrb[2]) begin
          ram[addr_word][23:16] <= mem.wdata[23:16];
        end
        if (mem.wstrb[3]) begin
          ram[addr_word][31:24] <= mem.wdata[31:24];
        end
        ram_ready <= 1'b1;
      end
    end
  end

  // -------------------------------------------------------------------------
  // PCIe bridge CSR, generated by PeakRDL out of 4.build/csr_build/csr.rdl
  // (module "csr", wrapped by soc_csr.sv). The register map is the address
  // table at the top of csr.rdl.
  // -------------------------------------------------------------------------
  logic [31:0] bridge_rdat;
  logic        bridge_rdy;

  logic [31:0] tx_header1;
  logic [31:0] tx_data;

  typedef enum logic [1:0] {
    IDLE         = 2'd0,
    SEND_CYCLE_1 = 2'd1,
    SEND_CYCLE_2 = 2'd2
  } tx_state_e;
  tx_state_e          tx_state;

  logic               rx_phase;

  // Configuration TLPs are routed by bus number (switched topology).
  // The bus number is taken from the address dword the software wrote into
  // tx_cfg_dw2, and the Type 0 / Type 1 code is derived from it, exactly as
  // the AMD packet generator does it:
  //   bus == 1  -> Type 0, the device sits on the link-attached bus
  //   bus  > 1  -> Type 1, the request has to cross one or more bridges
  // tlp_type[4:1] marks a Configuration request and tlp_type[0] is the
  // Type 0 / Type 1 selector. The device number needs no such treatment --
  // it already travels in DW2, where the completer expects it.
  // PeakRDL-generated CSR ports (u_soc_csr below)
  csr_pkg::csr__in_t  csr_in;
  csr_pkg::csr__out_t csr_out;

  pcie_tlp_dw0_t tx_dw0, tx_dw0_routed;
  pcie_cfg_dw2_t tx_cfg_dw2;
  logic          pkt_is_cfg;

  assign tx_dw0     = csr_out.tx.header0.hdr.value;
  assign tx_cfg_dw2 = csr_out.tx.header2.hdr.value;
  assign pkt_is_cfg = (tx_dw0.tlp_type[4:1] == TLP_TYPE_CFG);

  always_comb begin
    tx_dw0_routed = tx_dw0;
    if (pkt_is_cfg) begin
      tx_dw0_routed.tlp_type[0] = (tx_cfg_dw2.bus > 8'd1);
    end
  end

  //=========================================================================
  // PeakRDL-generated CSR
  //
  // The register storage, the read mux and the bus handshake live in the
  // generated block. What stays here is the logic that the registers
  // drive and that drives them back: the Tx FSM and the Rx capture.
  //=========================================================================

  soc_csr u_soc_csr (
      .clk   (clk),
      .resetn(resetn),

      .sel (is_bridge),
      .mem (mem),
      .rdat(bridge_rdat),
      .rdy (bridge_rdy),

      .csr_in (csr_in),
      .csr_out(csr_out)
  );

  // ---- Tx: the CPU-written registers feed the FSM -------------------------
  // Writing tx.data is what launches a transfer, hence "swmod" -- the strobe
  // PeakRDL raises on the cycle software modifies that field.
  logic tx_start;

  assign tx_header1 = csr_out.tx.header1.hdr.value;
  assign tx_data    = csr_out.tx.data.payload.value;
  assign tx_start   = csr_out.tx.data.payload.swmod;

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      tx_state          <= IDLE;
      s_axis_tx.tvalid  <= 1'b0;
      s_axis_tx.tdata   <= '0;
      s_axis_tx.tkeep   <= '0;
      s_axis_tx.tlast   <= 1'b0;
      tx_packet_counter <= '0;
    end
    else begin
      if (tx_start) begin
        tx_state          <= SEND_CYCLE_1;
        tx_packet_counter <= tx_packet_counter + 32'd1;
      end

      unique case (tx_state)
        IDLE: begin
          s_axis_tx.tvalid <= 1'b0;
        end
        SEND_CYCLE_1: begin
          s_axis_tx.tdata  <= pcie_trn_desc_t'{dw1: tx_header1, dw0: tx_dw0_routed};
          s_axis_tx.tkeep  <= 8'hFF;
          s_axis_tx.tvalid <= 1'b1;
          s_axis_tx.tlast  <= 1'b0;
          if (s_axis_tx.tready) begin
            tx_state <= SEND_CYCLE_2;
          end
        end
        SEND_CYCLE_2: begin
          s_axis_tx.tdata  <= {tx_data, tx_cfg_dw2};
          s_axis_tx.tkeep  <= tx_dw0.fmt[1] ? 8'hFF : 8'h0F;  // with data: DW2 + payload
          s_axis_tx.tvalid <= 1'b1;
          s_axis_tx.tlast  <= 1'b1;

          if (s_axis_tx.tready) begin
            tx_state <= IDLE;
          end
        end
      endcase
    end
  end

  // ---- Rx: the completion TLP is written straight into the CSR fields -----
  // 1st beat carries the Completion header DW0/DW1, the 2nd one DW2 and the
  // payload DWORD.
  pcie_tlp_dw0_t rx_hdr_dw0;
  pcie_cpl_dw1_t rx_hdr_cpl_dw1;
  pcie_cpl_dw2_t rx_hdr_cpl_dw2;
  logic          rx_cpl_dw0;
  logic          rx_cpl_dw2;

  assign rx_hdr_dw0 = m_axis_rx.tdata[31:0];  // 1st beat
  assign rx_hdr_cpl_dw1 = m_axis_rx.tdata[63:32];  // 1st beat
  assign rx_hdr_cpl_dw2 = m_axis_rx.tdata[31:0];  // 2nd beat

  assign rx_cpl_dw0 = m_axis_rx.tvalid & (rx_phase == 1'b0) & (rx_hdr_dw0.tlp_type == TLP_TYPE_CPL);
  assign rx_cpl_dw2 = m_axis_rx.tvalid & (rx_phase == 1'b1);

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      rx_phase <= 1'b0;
    end
    else if (rx_cpl_dw0) begin
      rx_phase <= 1'b1;
    end
    else if (rx_cpl_dw2 && m_axis_rx.tlast) begin
      rx_phase <= 1'b0;
    end
  end

  assign csr_in.rx.status.cpl_status.we          = rx_cpl_dw0;
  assign csr_in.rx.status.cpl_status.next        = rx_hdr_cpl_dw1.cpl_status;

  assign csr_in.rx.data.payload.we               = rx_cpl_dw2;
  assign csr_in.rx.data.payload.next             = m_axis_rx.tdata[63:32];  // payload DW, 2nd beat

  assign csr_in.rx.header_info.requester_id.we   = rx_cpl_dw2;
  assign csr_in.rx.header_info.requester_id.next = rx_hdr_cpl_dw2.requester_id;
  assign csr_in.rx.header_info.tag.we            = rx_cpl_dw2;
  assign csr_in.rx.header_info.tag.next          = rx_hdr_cpl_dw2.tag;
  assign csr_in.rx.header_info.lower_addr.we     = rx_cpl_dw2;
  assign csr_in.rx.header_info.lower_addr.next   = rx_hdr_cpl_dw2.lower_addr;

  // ---- Status: straight from the hard macro, no shadow registers ----------
  assign csr_in.status.err.msg_err_fatal.next    = cfg.msg_err_fatal;

  assign csr_in.status.phy.tx_state.next         = tx_state;
  assign csr_in.status.phy.tx_buf_avail.next     = cfg.tx_buf_avail;

  assign m_axis_rx.tready                        = 1'b1;

  // Per-packet transmit qualifiers of the hard macro (pcie_tx_tuser_t), none
  // of which this design uses. Left undriven they are X in simulation, and
  // the macro discards every TLP.
  assign s_axis_tx.tuser                         = '0;

  always_comb begin
    if (is_ram) begin
      mem.rdata = ram_rdata;
    end
    else if (is_bridge) begin
      mem.rdata = bridge_rdat;
    end
    else begin
      mem.rdata = 32'hDEADBEEF;
    end
  end

  assign mem.ready = ram_ready || bridge_rdy;

endmodule

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
