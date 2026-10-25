//==========================================================================
// Copyright (C) 2026 Chili.CHIPS
//--------------------------------------------------------------------------
// SPDX-License-Identifier: BSD-3-Clause
//--------------------------------------------------------------------------
// Description:
//   PIPExN__pcieVHost: a pcieVHost on an x1 or x4 PIPE link, as RC
//   (EndPoint=0) or EP (EndPoint=1), with the link offered at three layers,
//   all always present. Here it is the EP, in models/phy_top.PIPE.sv. At
//   Lanes = 1 it is openCologne-PCIE's PIPEx1__pcieVHost, which that project
//   uses for its host and its mock EP.
//
//   TxData/RxData are this node's PIPE link, lane l in bits
//   [l*DataWidth +: DataWidth]. x1 runs upstream's pcieVHostPipex1, x4 our
//   pcieVHostPipexN (models/pcieVHostPipexN.sv). The other outputs are named by
//   link direction, the same on both sides (dn = RC -> EP, up = EP -> RC),
//   with the names WaveCrux auto-binds (a decoder signal matches the suffix
//   of a port name under a shared prefix):
//
//     PIPE         pipe_dn_*, pipe_up_* (pclk, data, datak): copies of the
//                  link (lane 0), for the PIPE and Data Link Layer decoders
//                  (wavecrux-decoders, decoders/pcie). All four lanes of
//                  an x4 link: pipe_x4_view (models/pipe_x4_view.sv)
//     Data Link    dll_rx_*: the RC -> EP TLPs as an EP's DLL hands them to
//                  its TL (dll_if rx_data, rx_tlp_valid/first/last), on
//                  dll_clk: drives a TL under test without the MAC and DLL
//                  below it. dllp_dn_*, dllp_up_*: every DLLP, one word each
//     Transaction  tx_* (TLPs RC -> EP, peer EP -> RC), rx_* (EP -> RC, peer
//                  RC -> EP): for the TLP decoder (decoders/pcie-tlp)
//
//   The TLPs and DLLPs come from the transaction taps we added to pcieVHost
//   (models/pcievhost/README.md): what this node sends and receives. One net
//   under several names is an alias in the dump; WaveCrux offers every name
//   of an alias from 1.1.
//==========================================================================

module PIPExN__pcieVHost #(
    parameter int NodeNum   = 1,
    parameter bit EndPoint  = 0,   // 0: RC, 1: EP
    parameter int Lanes     = 1,   // 1 or 4
    parameter int DataWidth = 64,  // 8, 16, 32 or 64, per lane
    parameter int DllBytes  = 8    // dll_rx_data width, in bytes
) (
    input  logic                     pcieclk,  // 250 MHz symbol clock, Gen1
    input  logic                     pclk,     // pcieclk / (DataWidth/8)
    input  logic                     nreset,

`ifdef VERILATOR
    // Electrical idle side-band: Verilator has no Z on a wire
    output logic                     ElecIdleOut,
    input  logic                     ElecIdleIn,
`endif

    // the PIPE link of this node
    input  logic [  Lanes*DataWidth-1:0] RxData,
    input  logic [Lanes*DataWidth/8-1:0] RxDataK,
    output logic [  Lanes*DataWidth-1:0] TxData,
    output logic [Lanes*DataWidth/8-1:0] TxDataK,

    // PIPE, by link direction
    output logic                     pipe_dn_pclk,
    output logic [  DataWidth-1:0]   pipe_dn_data,
    output logic [DataWidth/8-1:0]   pipe_dn_datak,
    output logic                     pipe_up_pclk,
    output logic [  DataWidth-1:0]   pipe_up_data,
    output logic [DataWidth/8-1:0]   pipe_up_datak,

    // Data Link
    input  logic                     dll_clk,
    output logic [ DllBytes*8-1:0]   dll_rx_data,
    output logic                     dll_rx_tlp_valid,
    output logic                     dll_rx_tlp_first,
    output logic                     dll_rx_tlp_last,
    output logic [             7:0]  dll_rx_hdr_credit,
    output logic [            11:0]  dll_rx_data_credit,
    output logic [             1:0]  dll_rx_update_type,
    output logic [             1:0]  dll_rx_packet_type,
    output logic                     dll_rx_dllp_valid,
    output logic                     dllp_clk,
    output logic [            31:0]  dllp_dn_data,
    output logic                     dllp_dn_valid,
    output logic [            31:0]  dllp_up_data,
    output logic                     dllp_up_valid,

    // Transaction
    output logic                     tx_clk,
    output logic [            31:0]  tx_tlp_data,
    output logic                     tx_tlp_sop,
    output logic                     tx_tlp_eop,
    output logic                     tx_tlp_valid,
    output logic [            31:0]  tx_peer_data,
    output logic                     tx_peer_sop,
    output logic                     tx_peer_eop,
    output logic                     tx_peer_valid,
    output logic                     rx_clk,
    output logic [            31:0]  rx_tlp_data,
    output logic                     rx_tlp_sop,
    output logic                     rx_tlp_eop,
    output logic                     rx_tlp_valid,
    output logic [            31:0]  rx_peer_data,
    output logic                     rx_peer_sop,
    output logic                     rx_peer_eop,
    output logic                     rx_peer_valid
);

  // The model's taps, as this node sees them: Tx = sent, Rx = received
  logic [31:0] tap_tx_data, tap_rx_data, tap_dllp_tx, tap_dllp_rx;
  logic        tap_tx_sop, tap_tx_eop, tap_tx_valid;
  logic        tap_rx_sop, tap_rx_eop, tap_rx_valid;
  logic        tap_dllp_tx_valid, tap_dllp_rx_valid;

  if (Lanes == 1) begin : g_x1
    pcieVHostPipex1 #(
        .NodeNum  (NodeNum),
        .EndPoint (EndPoint),
        .DataWidth(DataWidth)
    ) u_pcievhost (
        .pcieclk    (pcieclk),
        .pclk       (pclk),
        .nreset     (nreset),
        .Gen2ClkSel (  /*LINT:OK*/),  // Gen1 only
        .ClkOut     (  /*LINT:OK*/),  // the test bench makes the clocks
`ifdef VERILATOR
        .ElecIdleOut(ElecIdleOut),
        .ElecIdleIn (ElecIdleIn),
`endif
        .RxData     (RxData),
        .RxDataK    (RxDataK),
        .TxData     (TxData),
        .TxDataK    (TxDataK),
        .TlpTxData  (tap_tx_data),
        .TlpTxSop   (tap_tx_sop),
        .TlpTxEop   (tap_tx_eop),
        .TlpTxValid (tap_tx_valid),
        .TlpRxData  (tap_rx_data),
        .TlpRxSop   (tap_rx_sop),
        .TlpRxEop   (tap_rx_eop),
        .TlpRxValid (tap_rx_valid),
        .DllpTxData (tap_dllp_tx),
        .DllpTxValid(tap_dllp_tx_valid),
        .DllpRxData (tap_dllp_rx),
        .DllpRxValid(tap_dllp_rx_valid)
    );
  end else begin : g_xn
    pcieVHostPipexN #(
        .NodeNum  (NodeNum),
        .EndPoint (EndPoint),
        .Lanes    (Lanes),
        .DataWidth(DataWidth)
    ) u_pcievhost (
        .pcieclk    (pcieclk),
        .pclk       (pclk),
        .nreset     (nreset),
        .Gen2ClkSel (  /*LINT:OK*/),  // Gen1 only
        .ClkOut     (  /*LINT:OK*/),  // the test bench makes the clocks
`ifdef VERILATOR
        .ElecIdleOut(ElecIdleOut),
        .ElecIdleIn (ElecIdleIn),
`endif
        .RxData     (RxData),
        .RxDataK    (RxDataK),
        .TxData     (TxData),
        .TxDataK    (TxDataK),
        .TlpTxData  (tap_tx_data),
        .TlpTxSop   (tap_tx_sop),
        .TlpTxEop   (tap_tx_eop),
        .TlpTxValid (tap_tx_valid),
        .TlpRxData  (tap_rx_data),
        .TlpRxSop   (tap_rx_sop),
        .TlpRxEop   (tap_rx_eop),
        .TlpRxValid (tap_rx_valid),
        .DllpTxData (tap_dllp_tx),
        .DllpTxValid(tap_dllp_tx_valid),
        .DllpRxData (tap_dllp_rx),
        .DllpRxValid(tap_dllp_rx_valid)
    );
  end

  // ---- by link direction: an RC sends dn, an EP sends up -------------------
  logic [31:0] tlp_dn_data, tlp_up_data;
  logic        tlp_dn_sop, tlp_dn_eop, tlp_dn_valid;
  logic        tlp_up_sop, tlp_up_eop, tlp_up_valid;

  always_comb begin
    if (EndPoint) begin
      {tlp_dn_data, tlp_dn_sop, tlp_dn_eop, tlp_dn_valid} = {tap_rx_data, tap_rx_sop, tap_rx_eop, tap_rx_valid};
      {tlp_up_data, tlp_up_sop, tlp_up_eop, tlp_up_valid} = {tap_tx_data, tap_tx_sop, tap_tx_eop, tap_tx_valid};
      {dllp_dn_data, dllp_dn_valid}                       = {tap_dllp_rx, tap_dllp_rx_valid};
      {dllp_up_data, dllp_up_valid}                       = {tap_dllp_tx, tap_dllp_tx_valid};
      {pipe_dn_data, pipe_dn_datak}                       = {RxData[DataWidth-1:0], RxDataK[DataWidth/8-1:0]};
      {pipe_up_data, pipe_up_datak}                       = {TxData[DataWidth-1:0], TxDataK[DataWidth/8-1:0]};
    end
    else begin
      {tlp_dn_data, tlp_dn_sop, tlp_dn_eop, tlp_dn_valid} = {tap_tx_data, tap_tx_sop, tap_tx_eop, tap_tx_valid};
      {tlp_up_data, tlp_up_sop, tlp_up_eop, tlp_up_valid} = {tap_rx_data, tap_rx_sop, tap_rx_eop, tap_rx_valid};
      {dllp_dn_data, dllp_dn_valid}                       = {tap_dllp_tx, tap_dllp_tx_valid};
      {dllp_up_data, dllp_up_valid}                       = {tap_dllp_rx, tap_dllp_rx_valid};
      {pipe_dn_data, pipe_dn_datak}                       = {TxData[DataWidth-1:0], TxDataK[DataWidth/8-1:0]};
      {pipe_up_data, pipe_up_datak}                       = {RxData[DataWidth-1:0], RxDataK[DataWidth/8-1:0]};
    end
  end

  // ---- PIPE and Transaction: the decoders' names --------------------------
  assign pipe_dn_pclk  = pclk;
  assign pipe_up_pclk  = pclk;
  assign dllp_clk      = pcieclk;
  assign tx_clk        = pcieclk;
  assign rx_clk        = pcieclk;

  assign tx_tlp_data   = tlp_dn_data;
  assign tx_tlp_sop    = tlp_dn_sop;
  assign tx_tlp_eop    = tlp_dn_eop;
  assign tx_tlp_valid  = tlp_dn_valid;
  assign tx_peer_data  = tlp_up_data;
  assign tx_peer_sop   = tlp_up_sop;
  assign tx_peer_eop   = tlp_up_eop;
  assign tx_peer_valid = tlp_up_valid;

  assign rx_tlp_data   = tlp_up_data;
  assign rx_tlp_sop    = tlp_up_sop;
  assign rx_tlp_eop    = tlp_up_eop;
  assign rx_tlp_valid  = tlp_up_valid;
  assign rx_peer_data  = tlp_dn_data;
  assign rx_peer_sop   = tlp_dn_sop;
  assign rx_peer_eop   = tlp_dn_eop;
  assign rx_peer_valid = tlp_dn_valid;

  // ---- Data Link: RC -> EP TLPs as an EP's DLL hands them to its TL -------
  // Each TLP is queued whole, byte by byte ({first, last, byte}), then played
  // out DllBytes per dll_clk, TLP byte 0 in dll_rx_data[7:0] (lane order).
  // A TLP that ends mid-beat leaves the rest of its last beat zero; the TL
  // takes the length from the header. Like a DLL, no ready: the TL takes a
  // beat on every clock dll_rx_tlp_valid is high.
  logic [9:0] dll_q[$];     // whole TLPs
  logic [9:0] dll_part[$];  // the TLP being tapped
  int         dll_tlps = 0; // whole TLPs in dll_q

  always @(posedge pcieclk) begin
    if (tlp_dn_valid) begin
      for (int b = 0; b < 4; b++) begin
        dll_part.push_back({tlp_dn_sop && b == 0, tlp_dn_eop && b == 3, tlp_dn_data[31-8*b-:8]});
      end
      if (tlp_dn_eop) begin
        while (dll_part.size() != 0) dll_q.push_back(dll_part.pop_front());
        dll_tlps++;
      end
    end
  end

  always @(posedge dll_clk or negedge nreset) begin
    if (!nreset) begin
      dll_rx_data      <= '0;
      dll_rx_tlp_valid <= 1'b0;
      dll_rx_tlp_first <= 1'b0;
      dll_rx_tlp_last  <= 1'b0;
    end else if (dll_tlps != 0) begin
      logic [DllBytes*8-1:0] d;
      logic                  first, last;
      d     = '0;
      first = 1'b0;
      last  = 1'b0;
      for (int b = 0; b < DllBytes && !last; b++) begin
        logic [9:0] e;
        e         = dll_q.pop_front();
        first     = first | e[9];
        last      = e[8];
        d[8*b+:8] = e[7:0];
      end
      if (last) dll_tlps--;
      dll_rx_data      <= d;
      dll_rx_tlp_valid <= 1'b1;
      dll_rx_tlp_first <= first;
      dll_rx_tlp_last  <= last;
    end else begin
      dll_rx_tlp_valid <= 1'b0;
      dll_rx_tlp_first <= 1'b0;
      dll_rx_tlp_last  <= 1'b0;
    end
  end

  // ---- Data Link: RC -> EP DLLPs as an EP's DLL hands them to its TL ------
  // One DLLP per dll_clk, the fields Cologne Chip's DLL forwards (DLL draft
  // v2, slide 7; virtual_channel_rx.v): DLLP Type = {packet_type,
  // update_type, 1'b0, VC}, HdrFC, DataFC. Like that DLL, every DLLP raises
  // dll_rx_dllp_valid, Ack/Nak too; for those the credit fields carry the
  // other bytes (the Ack/Nak sequence number is in dll_rx_data_credit).
  logic [31:0] dllp_q[$];

  always @(posedge pcieclk) begin
    if (dllp_dn_valid) dllp_q.push_back(dllp_dn_data);
  end

  always @(posedge dll_clk or negedge nreset) begin
    if (!nreset) begin
      dll_rx_hdr_credit  <= '0;
      dll_rx_data_credit <= '0;
      dll_rx_update_type <= '0;
      dll_rx_packet_type <= '0;
      dll_rx_dllp_valid  <= 1'b0;
    end else if (dllp_q.size() != 0) begin
      logic [31:0] w;
      w = dllp_q.pop_front();
      dll_rx_packet_type <= w[31:30];
      dll_rx_update_type <= w[29:28];
      dll_rx_hdr_credit  <= {w[21:16], w[15:14]};
      dll_rx_data_credit <= {w[11:8], w[7:0]};
      dll_rx_dllp_valid  <= 1'b1;
    end else begin
      dll_rx_dllp_valid <= 1'b0;
    end
  end

endmodule: PIPExN__pcieVHost

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 24, 2026
// -----------------------------------------------------------------------------
