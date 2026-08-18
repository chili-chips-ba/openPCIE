//==========================================================================
// Copyright (C) 2026 Chili.CHIPS*ba
//--------------------------------------------------------------------------
// SPDX-License-Identifier: BSD-3-Clause
//--------------------------------------------------------------------------
// Description:
//   Co-simulation stand-in for 2.rtl/*/src/pcie/serdes_front.sv
//
//   Same module name, same port list, so it is a drop-in replacement: the
//   simulation file list picks this file INSTEAD of the synthesis one and
//   nothing else in the design changes. It is the exact same trick the test
//   bench uses for the CPU with soc_cpu.VPROC.sv.
//
//   What it replaces
//   ----------------
//   The synthesis serdes_front wraps serdes_ctrl -> lane_xcvr -> GTPE2_CHANNEL,
//   i.e. the 7-series gigabit transceiver, and presents a PIPE interface to
//   the PCIE_2_1 hard macro above it. The transceiver is what turns PIPE
//   symbols into a 5 GT/s serial bit stream.
//
//   The pcievhost VIP models the link at PIPE symbol level, not at serial bit
//   level, so the transceiver has to come out for co-simulation. This module
//   therefore provides:
//
//     1. a behavioural PIPE PHY -- the sideband handshake the PCIE_2_1 LTSSM
//        needs from a PHY: PHYSTATUS pulses, receiver detection, RXVALID,
//        RXELECIDLE and the PCLK/rate handling
//     2. the link partner itself -- a pcieVHostPipex1 configured as an
//        ENDPOINT, so the openPCIE Root Complex has something to enumerate
//
//        PCIE_2_1  <--16-bit PIPE-->  this PHY  <--16-bit PIPE-->  pcieVHost EP
//              (silicon_core.sv)                                   (VUserMain1)
//
//   Clocking
//   --------
//   In hardware the GT recovers TXOUTCLK (125 MHz) and clk_synth's MMCM makes
//   PCLK (125 MHz Gen1 / 250 MHz Gen2) and USERCLK1/2 (62.5 MHz) from it. Here
//   TXOUTCLK is a behavioural oscillator and everything downstream is the real
//   clk_synth, so the clock topology the design sees is unchanged.
//
//   The pcievhost wrapper needs a symbol clock at twice the 16-bit PIPE rate;
//   it is generated from the same behavioural source so the two stay edge
//   aligned, and it follows the link rate when the LTSSM changes speed.
//==========================================================================

`timescale 1ps/1ps

module serdes_front
  import link_pkg::*;
(
  input  wire [5:0]                             pl_ltssm_state,

  phy_lanes_if.phy                              pipe,

  output wire [LINK_CAP_MAX_LINK_WIDTH-1:0]     pci_exp_txn,
  output wire [LINK_CAP_MAX_LINK_WIDTH-1:0]     pci_exp_txp,
  input  wire [LINK_CAP_MAX_LINK_WIDTH-1:0]     pci_exp_rxn,
  input  wire [LINK_CAP_MAX_LINK_WIDTH-1:0]     pci_exp_rxp,

  input  wire                                   sys_clk,
  input  wire                                   sys_rst_n,
  input  wire                                   PIPE_MMCM_RST_N,
  output wire                                   pipe_clk,
  output wire                                   user_clk,
  output wire                                   user_clk2,

  input  wire                                   PIPE_PCLK_IN,
  input  wire                                   PIPE_RXUSRCLK_IN,
  input  wire [LINK_CAP_MAX_LINK_WIDTH-1:0]     PIPE_RXOUTCLK_IN,
  input  wire                                   PIPE_DCLK_IN,
  input  wire                                   PIPE_USERCLK1_IN,
  input  wire                                   PIPE_USERCLK2_IN,
  input  wire                                   PIPE_OOBCLK_IN,
  input  wire                                   PIPE_MMCM_LOCK_IN,
  output wire                                   PIPE_TXOUTCLK_OUT,
  output wire [LINK_CAP_MAX_LINK_WIDTH-1:0]     PIPE_RXOUTCLK_OUT,
  output wire [LINK_CAP_MAX_LINK_WIDTH-1:0]     PIPE_PCLK_SEL_OUT,
  output wire                                   PIPE_GEN3_OUT,

  output wire                                   phy_rdy_n
);

  // The serial pads are unused -- the link is modelled at PIPE level
  assign pci_exp_txp = '0;
  assign pci_exp_txn = '0;

  //------------------------------------------------------------------
  // Behavioural clocks
  //------------------------------------------------------------------
  // TXOUTCLK is what the GT recovers and feeds to clk_synth's MMCM. It has to
  // be 100 MHz: clk_synth is parameterised with PCIE_REFCLK_FREQ = 0, i.e.
  // CLKIN1_PERIOD = 10 ns and CLKFBOUT_MULT_F = 10, so the VCO lands on
  // 1000 MHz and the outputs come out as
  //     CLKOUT0 = 1000/8  = 125   MHz   PCLK, Gen1
  //     CLKOUT1 = 1000/4  = 250   MHz   PCLK, Gen2
  //     CLKOUT2 = 1000/16 =  62.5 MHz   USERCLK1/2
  // Feed it anything else and every clock in the design scales with it -- at
  // 125 MHz in, PCLK becomes 156.25 MHz and the PIPE then over-samples the
  // link partner, duplicating one symbol in five.
  localparam int TXOUTCLK_HALF_PS = 5000;   // 100 MHz

  // Symbol clock for the pcievhost wrapper. A 16-bit PIPE carries 2 symbols
  // per PCLK, so this is 2 x PCLK: 250 MHz at Gen1, 500 MHz at Gen2.
  localparam int SYMCLK_HALF_GEN1_PS = 2000;  // 250 MHz
  localparam int SYMCLK_HALF_GEN2_PS = 1000;  // 500 MHz

  logic txoutclk = 1'b0;
  logic symclk   = 1'b0;

  always #(TXOUTCLK_HALF_PS * 1ps) txoutclk = ~txoutclk;

  // Rate follows PIPETXRATE, which the LTSSM drives on a speed change.
  // It has to be resolved to a hard 0/1 first: PIPETXRATE is X before the hard
  // macro comes out of reset, and an X delay expression is a zero delay, which
  // hangs the simulator at time 0.
  logic rate_sel = 1'b0;

  always @(pipe.tx_ctrl.rate) rate_sel = (pipe.tx_ctrl.rate === 1'b1);

  always begin
    #((rate_sel ? SYMCLK_HALF_GEN2_PS : SYMCLK_HALF_GEN1_PS) * 1ps);
    symclk = ~symclk;
  end

  assign PIPE_TXOUTCLK_OUT = txoutclk;
  assign PIPE_RXOUTCLK_OUT = {LINK_CAP_MAX_LINK_WIDTH{txoutclk}};

  // PCLK, USERCLK1 and USERCLK2 come straight back from clk_synth, exactly as
  // serdes_ctrl passes them through in the synthesis build
  assign pipe_clk  = PIPE_PCLK_IN;
  assign user_clk  = PIPE_USERCLK1_IN;
  assign user_clk2 = PIPE_USERCLK2_IN;

  // Tell clk_synth which PCLK to select. Gen3 does not exist on this device.
  assign PIPE_PCLK_SEL_OUT = {LINK_CAP_MAX_LINK_WIDTH{pipe.tx_ctrl.rate}};
  assign PIPE_GEN3_OUT     = 1'b0;

  //------------------------------------------------------------------
  // PHY ready
  //------------------------------------------------------------------
  // In hardware phy_rdy_n drops once the GT reset FSM has finished and the
  // MMCM has locked. Here it waits for the MMCM only.
  logic [7:0] rdy_cnt;
  logic       phy_rdy_n_int;

  always_ff @(posedge pipe_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
      rdy_cnt       <= '0;
      phy_rdy_n_int <= 1'b1;
    end
    else if (PIPE_MMCM_LOCK_IN) begin
      if (rdy_cnt != 8'hFF) begin
        rdy_cnt <= rdy_cnt + 8'd1;
      end
      else begin
        phy_rdy_n_int <= 1'b0;
      end
    end
  end

  assign phy_rdy_n = phy_rdy_n_int;

  //------------------------------------------------------------------
  // pcievhost endpoint, connected over a 16-bit PIPE
  //------------------------------------------------------------------
  // What we transmit is what the model receives, and vice versa.
  logic [15:0] ep_rx_data;      // -> model
  logic [1:0]  ep_rx_datak;
  wire  [15:0] ep_tx_data;      // <- model
  wire  [1:0]  ep_tx_datak;

  // Register the outgoing symbols on PCLK so the model sees a clean bus
  always_ff @(posedge pipe_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
      ep_rx_data  <= 16'h0000;
      ep_rx_datak <= 2'b00;
    end
    else begin
      ep_rx_data  <= pipe.tx[0].data;
      ep_rx_datak <= pipe.tx[0].char_is_k;
    end
  end

  pcieVHostPipex1 #(
    .NodeNum   (1),      // VUserMain1.cpp -- the endpoint program
    .EndPoint  (1),      // enables the config space and auto-completions
    .DataWidth (16)      // matches the 7-series 2-symbol PIPE
  ) u_pcie_ep (
    .pcieclk   (symclk),
    .pclk      (pipe_clk),
    .nreset    (sys_rst_n),

    .RxData    (ep_rx_data),
    .RxDataK   (ep_rx_datak),

    .TxData    (ep_tx_data),
    .TxDataK   (ep_tx_datak)
  );

  //------------------------------------------------------------------
  // PIPE sideband handshake towards PCIE_2_1
  //------------------------------------------------------------------
  // The hard macro's LTSSM will not move unless the PHY answers three things:
  //
  //   a) a PHYSTATUS pulse whenever it is told to change power state, change
  //      rate, or come out of PIPE reset
  //   b) a receiver-detection result: PHYSTATUS pulse together with
  //      RXSTATUS = 3'b011 while TXDETECTRX is asserted in P1
  //   c) RXVALID / RXELECIDLE that reflect whether the partner is driving
  //
  // Anything more elaborate (8b/10b error reporting, elastic buffer status)
  // is not modelled -- the link is ideal.

  localparam logic [2:0] RXSTATUS_RCVR_DETECTED = 3'b011;

  // Latency, in PCLK cycles, before the PHY answers. Any small non-zero value
  // works; these are picked to keep link training quick in simulation.
  localparam int PHYSTATUS_LAT = 8;
  localparam int RCVRDET_LAT   = 16;

  logic [1:0] powerdown_q;
  logic       rate_q;
  logic       pipe_reset_q;
  logic       rcvr_det_q;

  logic [7:0] phystat_cnt;      // counts down to a PHYSTATUS pulse
  logic       phystat_is_det;   // that pulse is a receiver-detect result
  logic       phy_status_r;
  logic [2:0] rx_status_r;

  wire pipe_reset_fall = pipe_reset_q & ~pipe.tx_ctrl.reset;
  wire powerdown_chg   = (powerdown_q != pipe.tx[0].powerdown);
  wire rate_chg        = (rate_q      != pipe.tx_ctrl.rate);
  wire rcvr_det_rise   = ~rcvr_det_q  &  pipe.tx_ctrl.rcvr_det;

  always_ff @(posedge pipe_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
      powerdown_q    <= 2'b10;          // P1 out of reset
      rate_q         <= 1'b0;
      pipe_reset_q   <= 1'b1;
      rcvr_det_q     <= 1'b0;

      phystat_cnt    <= 8'd0;
      phystat_is_det <= 1'b0;
      phy_status_r   <= 1'b0;
      rx_status_r    <= 3'b000;
    end
    else begin
      powerdown_q  <= pipe.tx[0].powerdown;
      rate_q       <= pipe.tx_ctrl.rate;
      pipe_reset_q <= pipe.tx_ctrl.reset;
      rcvr_det_q   <= pipe.tx_ctrl.rcvr_det;

      phy_status_r <= 1'b0;
      rx_status_r  <= 3'b000;

      // Arm the response. Receiver detection wins -- it is the one the LTSSM
      // is waiting for in Detect, and it carries a status code with it.
      if (rcvr_det_rise) begin
        phystat_cnt    <= RCVRDET_LAT;
        phystat_is_det <= 1'b1;
      end
      else if (powerdown_chg || rate_chg || pipe_reset_fall) begin
        phystat_cnt    <= PHYSTATUS_LAT;
        phystat_is_det <= 1'b0;
      end
      else if (phystat_cnt != 8'd0) begin
        phystat_cnt <= phystat_cnt - 8'd1;

        if (phystat_cnt == 8'd1) begin
          phy_status_r <= 1'b1;
          rx_status_r  <= phystat_is_det ? RXSTATUS_RCVR_DETECTED : 3'b000;
        end
      end
    end
  end

  //------------------------------------------------------------------
  // Receive side
  //------------------------------------------------------------------
  // The partner is considered to be driving from the first K character it
  // sends -- link training always opens with COM (K28.5), so this is a safe
  // and simple stand-in for a real squelch detector.
  logic rx_active;

  always_ff @(posedge pipe_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
      rx_active <= 1'b0;
    end
    else if (|ep_tx_datak) begin
      rx_active <= 1'b1;
    end
  end

  genvar i;
  generate
    for (i = 0; i < PIPE_MAX_LANES; i = i + 1) begin : lane_map
      if (i < LINK_CAP_MAX_LINK_WIDTH) begin : active
        assign pipe.rx[i].data          = ep_tx_data;
        assign pipe.rx[i].char_is_k     = ep_tx_datak;
        assign pipe.rx[i].valid         = rx_active;
        assign pipe.rx[i].chanisaligned = rx_active;
        assign pipe.rx[i].status        = rx_status_r;
        assign pipe.rx[i].phy_status    = phy_status_r;
        assign pipe.rx[i].elec_idle     = ~rx_active;
      end
      else begin : unused
        assign pipe.rx[i] = PIPE_RX_LANE_TIE;
      end
    end
  endgenerate

  //------------------------------------------------------------------
  // Ordered-set monitor
  //------------------------------------------------------------------
  // Decodes the symbol stream in both directions and reports each change of
  // ordered set. This is the quickest way to see which side of the link is
  // not answering during training. Enable with +define+PIPE_OS_TRACE.
`ifdef PIPE_OS_TRACE
  // TS1 and TS2 are 16 symbols: COM then 14 identifier-bearing symbols, of
  // which symbols 6..15 are D10.2 (0x4A) for TS1 and D5.2 (0x45) for TS2.
  localparam logic [7:0] SYM_COM = 8'hBC;
  localparam logic [7:0] SYM_TS1 = 8'h4A;
  localparam logic [7:0] SYM_TS2 = 8'h45;
  localparam logic [7:0] SYM_IDL = 8'h7C;   // K28.3, part of EIOS
  localparam logic [7:0] SYM_SKP = 8'h1C;   // K28.0

  // One monitor instance per direction, fed a symbol at a time
  function automatic string os_name(input logic [7:0] id);
    case (id)
      SYM_TS1: return "TS1";
      SYM_TS2: return "TS2";
      SYM_IDL: return "EIOS/IDL";
      SYM_SKP: return "SKP";
      default: return "other";
    endcase
  endfunction

  // TX side (RC -> EP)
  integer tx_pos;
  logic [7:0] tx_last_id;
  // RX side (EP -> RC)
  integer rx_pos;
  logic [7:0] rx_last_id;

  initial begin
    tx_pos = -1; tx_last_id = 8'hFF;
    rx_pos = -1; rx_last_id = 8'hFF;
  end

  logic [7:0] tx_link, tx_lane, tx_last_link, tx_last_lane;

  task automatic feed_tx(input logic [7:0] sym, input logic is_k);
    if (is_k && sym == SYM_COM) tx_pos = 0;
    else if (tx_pos >= 0) begin
      tx_pos = tx_pos + 1;
      if (tx_pos == 1) tx_link = sym;
      if (tx_pos == 2) tx_lane = sym;
      if (tx_pos == 6) begin
        if (sym !== tx_last_id || tx_link !== tx_last_link || tx_lane !== tx_last_lane) begin
          tx_last_id   = sym;
          tx_last_link = tx_link;
          tx_last_lane = tx_lane;
          $display("%t  PIPE   RC --> EP  %s link=%02h lane=%02h", $time,
                   os_name(sym), tx_link, tx_lane);
        end
        tx_pos = -1;
      end
    end
  endtask

  logic [7:0] rx_link, rx_lane, rx_last_link, rx_last_lane;

  task automatic feed_rx(input logic [7:0] sym, input logic is_k);
    if (is_k && sym == SYM_COM) rx_pos = 0;
    else if (rx_pos >= 0) begin
      rx_pos = rx_pos + 1;
      if (rx_pos == 1) rx_link = sym;
      if (rx_pos == 2) rx_lane = sym;
      if (rx_pos == 6) begin
        if (sym !== rx_last_id || rx_link !== rx_last_link || rx_lane !== rx_last_lane) begin
          rx_last_id   = sym;
          rx_last_link = rx_link;
          rx_last_lane = rx_lane;
          $display("%t  PIPE   EP --> RC  %s link=%02h lane=%02h", $time,
                   os_name(sym), rx_link, rx_lane);
        end
        rx_pos = -1;
      end
    end
  endtask

  // Raw symbol dump: the first PIPE_DUMP_N words in each direction once the
  // partner starts driving. Ground truth for alignment problems.
`ifdef PIPE_RAW_DUMP
`ifndef PIPE_DUMP_FROM
  `define PIPE_DUMP_FROM 0
`endif
  integer dump_n = 0;
  always @(posedge pipe_clk) if (sys_rst_n && rx_active && dump_n < 40 && $time > `PIPE_DUMP_FROM) begin
    $display("%t  RAW  tx=%02h%s %02h%s   rx=%02h%s %02h%s", $time,
             pipe.tx[0].data[7:0],  pipe.tx[0].char_is_k[0] ? "K" : "d",
             pipe.tx[0].data[15:8], pipe.tx[0].char_is_k[1] ? "K" : "d",
             ep_tx_data[7:0],       ep_tx_datak[0] ? "K" : "d",
             ep_tx_data[15:8],      ep_tx_datak[1] ? "K" : "d");
    dump_n <= dump_n + 1;
  end
`endif

  always @(posedge pipe_clk) if (sys_rst_n) begin
    feed_tx(pipe.tx[0].data[7:0],   pipe.tx[0].char_is_k[0]);
    feed_tx(pipe.tx[0].data[15:8],  pipe.tx[0].char_is_k[1]);
    feed_rx(ep_tx_data[7:0],        ep_tx_datak[0]);
    feed_rx(ep_tx_data[15:8],       ep_tx_datak[1]);
  end
`endif

  //------------------------------------------------------------------
  // Progress reporting
  //------------------------------------------------------------------
  // The LTSSM state is the single most useful thing to watch when the link
  // does not come up, so every transition is printed.
`ifndef NO_LTSSM_TRACE
  logic [5:0] ltssm_q;

  always_ff @(posedge pipe_clk) begin
    ltssm_q <= pl_ltssm_state;

    if (ltssm_q !== pl_ltssm_state) begin
      $display("%t  LTSSM  0x%02h -> 0x%02h %s", $time, ltssm_q, pl_ltssm_state,
               ltssm_name(pl_ltssm_state));
    end
  end

  function automatic string ltssm_name(input logic [5:0] s);
    case (s)
      6'h00: return "DETECT_QUIET";
      6'h01: return "DETECT_ACTIVE";
      6'h02: return "POLLING_ACTIVE";
      6'h03: return "POLLING_COMPLIANCE";
      6'h04: return "POLLING_CONFIGURATION";
      6'h05: return "CONFIG_LINKWIDTH_START";
      6'h06: return "CONFIG_LINKWIDTH_ACCEPT";
      6'h07: return "CONFIG_LANENUM_WAIT";
      6'h08: return "CONFIG_LANENUM_ACCEPT";
      6'h09: return "CONFIG_COMPLETE";
      6'h0A: return "CONFIG_IDLE";
      6'h0B: return "RECOVERY_RCVRLOCK";
      6'h0C: return "RECOVERY_SPEED";
      6'h0D: return "RECOVERY_RCVRCFG";
      6'h0E: return "RECOVERY_IDLE";
      6'h10: return "L0";
      6'h16: return "L0  (linkup)";
      default: return "";
    endcase
  endfunction
`endif

endmodule
