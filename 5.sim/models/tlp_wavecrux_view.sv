// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openPCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
// Description:
//   Simulation-only signal set for the openPCIE PCIe TLP decoder plugin
//   (5.sim/tools/wavecrux-pcie-tlp) in WaveCrux.
//
//   The decoder takes nine signals: clk, the stream it decodes (tlp_*), and
//   the opposite direction (peer_*), which it uses to name each Completion
//   after the request it answers. This scope offers both pairings, one per
//   prefix:
//
//     tx_*   decode RC -> EP, peer = EP -> RC
//     rx_*   decode EP -> RC, peer = RC -> EP
//
//   WaveCrux auto-binds by (scope, prefix): it finds both groups here, and
//   its prefix drop-down picks tx_ or rx_. Every signal is a variable of its
//   own, because a VCD writes one net seen from two places as an alias, and
//   the viewer lists such an alias only once.
//==========================================================================

`timescale 1ns / 1ps

module tlp_wavecrux_view (
    tlp_dw_if.sink tx,     // RC -> EP
    tlp_dw_if.sink rx      // EP -> RC
);

    // RC -> EP decoded, EP -> RC as its peer
    logic        tx_clk;
    logic [31:0] tx_tlp_data;
    logic        tx_tlp_sop, tx_tlp_eop, tx_tlp_valid;
    logic [31:0] tx_peer_data;
    logic        tx_peer_sop, tx_peer_eop, tx_peer_valid;

    // EP -> RC decoded, RC -> EP as its peer
    logic        rx_clk;
    logic [31:0] rx_tlp_data;
    logic        rx_tlp_sop, rx_tlp_eop, rx_tlp_valid;
    logic [31:0] rx_peer_data;
    logic        rx_peer_sop, rx_peer_eop, rx_peer_valid;

    always_comb begin
        tx_clk        = tx.clk;
        tx_tlp_data   = tx.tlp_data;
        tx_tlp_sop    = tx.tlp_sop;
        tx_tlp_eop    = tx.tlp_eop;
        tx_tlp_valid  = tx.tlp_valid;
        tx_peer_data  = rx.tlp_data;
        tx_peer_sop   = rx.tlp_sop;
        tx_peer_eop   = rx.tlp_eop;
        tx_peer_valid = rx.tlp_valid;

        rx_clk        = rx.clk;
        rx_tlp_data   = rx.tlp_data;
        rx_tlp_sop    = rx.tlp_sop;
        rx_tlp_eop    = rx.tlp_eop;
        rx_tlp_valid  = rx.tlp_valid;
        rx_peer_data  = tx.tlp_data;
        rx_peer_sop   = tx.tlp_sop;
        rx_peer_eop   = tx.tlp_eop;
        rx_peer_valid = tx.tlp_valid;
    end

endmodule: tlp_wavecrux_view

//--------------------------------------------------------------------------
// Revision history:
//  2026/10/06 - initial creation
//--------------------------------------------------------------------------
