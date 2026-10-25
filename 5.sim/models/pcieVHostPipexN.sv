//==========================================================================
// Copyright (C) 2026 Chili.CHIPS
//--------------------------------------------------------------------------
// SPDX-License-Identifier: BSD-3-Clause
//--------------------------------------------------------------------------
// Description:
//   pcieVHostPipexN: upstream's pcieVHostPipex1 (pcievhost
//   verilog/pcieVHost/pcieVHostPipex1.v) for Lanes lanes: the same PIPE
//   shifters, one set per lane, around one PcieVhost with LinkWidth = Lanes.
//   8b/10b is off, so each lane carries {K, byte} symbols, as in the x1
//   wrapper. Lane l is bits [l*DataWidth +: DataWidth] of RxData/TxData.
//
//   Differences from pcieVHostPipex1: Gen1 clocks only (Gen2Clk = 0, which
//   is how the test bench uses the x1 wrapper too); under Verilator the
//   electrical idle side-band is one bit for all lanes.
//==========================================================================

module pcieVHostPipexN #(
    parameter int NodeNum   = 8,
    parameter bit EndPoint  = 1,
    parameter int Lanes     = 4,   // 1 to 16
    parameter int DataWidth = 16   // 8, 16, 32 or 64, per lane
) (
    input  logic                             pcieclk,  // 250 MHz symbol clock, Gen1
    input  logic                             pclk,     // pcieclk / (DataWidth/8), synchronous
    input  logic                             nreset,
    output logic                             Gen2ClkSel,
    output logic                             ClkOut,
`ifdef VERILATOR
    output logic                             ElecIdleOut,
    input  logic                             ElecIdleIn,
`endif
    input  logic [Lanes*DataWidth    -1:0]   RxData,
    input  logic [Lanes*DataWidth/8  -1:0]   RxDataK,
    output logic [Lanes*DataWidth    -1:0]   TxData,
    output logic [Lanes*DataWidth/8  -1:0]   TxDataK,

    // Transaction taps, on ClkOut: see pcieVHost.v
    output logic [31:0]                      TlpTxData,
    output logic                             TlpTxSop, TlpTxEop, TlpTxValid,
    output logic [31:0]                      TlpRxData,
    output logic                             TlpRxSop, TlpRxEop, TlpRxValid,
    output logic [31:0]                      DllpTxData,
    output logic                             DllpTxValid,
    output logic [31:0]                      DllpRxData,
    output logic                             DllpRxValid
);

  localparam int BYTES = DataWidth / 8;

  // one 10-bit link symbol per lane, {0, K, byte}; lanes above Lanes float
  wire [15:0][9:0] link_in, link_out;

  logic [Lanes-1:0][DataWidth-1:0] rx_sample, tx_pipe;
  logic [Lanes-1:0][   BYTES-1:0]  rxk_sample, txk_pipe;
  int                              rxcount;

  for (genvar l = 0; l < 16; l++) begin : g_link_in
    if (l < Lanes) begin : g_used
      assign link_in[l] = {1'b0, rxk_sample[l][0], rx_sample[l][7:0]};
    end else begin : g_unused
      assign link_in[l] = 'z;
    end
  end

  // Sample each lane's RX word every BYTES symbol clocks and shift it out one
  // symbol per clock; shift the link's TX symbols into each lane's word
  always @(posedge pcieclk or negedge nreset) begin
    if (!nreset) begin
      rxcount <= 0;
    end else if (rxcount == 0) begin
      for (int l = 0; l < Lanes; l++) begin
        rx_sample[l]  <= RxData [l*DataWidth +: DataWidth];
        rxk_sample[l] <= RxDataK[l*BYTES     +: BYTES];
      end
      rxcount <= BYTES - 1;
    end else begin
      for (int l = 0; l < Lanes; l++) begin
        rx_sample[l]  <= DataWidth'(rx_sample[l]  >> 8);
        rxk_sample[l] <= BYTES'(rxk_sample[l] >> 1);
      end
      rxcount <= rxcount - 1;
    end

    for (int l = 0; l < Lanes; l++) begin
      if (BYTES == 1) begin
        tx_pipe[l]  <= DataWidth'(link_out[l][7:0]);
        txk_pipe[l] <= BYTES'(link_out[l][8]);
      end else begin
        tx_pipe[l]  <= {link_out[l][7:0], tx_pipe[l][DataWidth-1:8]};
        txk_pipe[l] <= {link_out[l][8], txk_pipe[l][BYTES-1:1]};
      end
    end
  end

  // At the PIPE clock rate, update the TX outputs (pcieclk when 8 bits wide)
  wire tx_sample_clk = (BYTES == 1) ? pcieclk : pclk;

  always @(posedge tx_sample_clk) begin
    for (int l = 0; l < Lanes; l++) begin
      TxData [l*DataWidth +: DataWidth] <= tx_pipe[l];
      TxDataK[l*BYTES     +: BYTES]     <= txk_pipe[l];
    end
  end

`ifdef VERILATOR
  logic [15:0] elec_idle_out;
  assign ElecIdleOut = elec_idle_out[0];
`endif

  PcieVhost #(
      .LinkWidth        (Lanes),
      .NodeNum          (NodeNum),
      .EndPoint         (EndPoint),
      .DisableScrambling(0),
      .Disable8b10b     (1),
      .Gen2Clk          (0)
  ) pcievh_i (
      .Clk        (pcieclk),
      .notReset   (nreset),
      .Gen2ClkSel (Gen2ClkSel),
      .ClkOut     (ClkOut),
`ifdef VERILATOR
      .ElecIdleOut(elec_idle_out),
      .ElecIdleIn ({16{ElecIdleIn}}),
`endif
      .LinkIn0    (link_in[0]),  .LinkIn1  (link_in[1]),  .LinkIn2  (link_in[2]),  .LinkIn3  (link_in[3]),
      .LinkIn4    (link_in[4]),  .LinkIn5  (link_in[5]),  .LinkIn6  (link_in[6]),  .LinkIn7  (link_in[7]),
      .LinkIn8    (link_in[8]),  .LinkIn9  (link_in[9]),  .LinkIn10 (link_in[10]), .LinkIn11 (link_in[11]),
      .LinkIn12   (link_in[12]), .LinkIn13 (link_in[13]), .LinkIn14 (link_in[14]), .LinkIn15 (link_in[15]),
      .LinkOut0   (link_out[0]), .LinkOut1 (link_out[1]), .LinkOut2 (link_out[2]), .LinkOut3 (link_out[3]),
      .LinkOut4   (link_out[4]), .LinkOut5 (link_out[5]), .LinkOut6 (link_out[6]), .LinkOut7 (link_out[7]),
      .LinkOut8   (link_out[8]), .LinkOut9 (link_out[9]), .LinkOut10(link_out[10]),.LinkOut11(link_out[11]),
      .LinkOut12  (link_out[12]),.LinkOut13(link_out[13]),.LinkOut14(link_out[14]),.LinkOut15(link_out[15]),
      .TlpTxData  (TlpTxData),   .TlpTxSop (TlpTxSop),    .TlpTxEop (TlpTxEop),    .TlpTxValid(TlpTxValid),
      .TlpRxData  (TlpRxData),   .TlpRxSop (TlpRxSop),    .TlpRxEop (TlpRxEop),    .TlpRxValid(TlpRxValid),
      .DllpTxData (DllpTxData),  .DllpTxValid(DllpTxValid),
      .DllpRxData (DllpRxData),  .DllpRxValid(DllpRxValid)
  );

endmodule: pcieVHostPipexN

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 24, 2026
// -----------------------------------------------------------------------------
