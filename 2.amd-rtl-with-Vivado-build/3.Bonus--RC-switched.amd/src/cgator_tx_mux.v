
//-----------------------------------------------------------------------------
//
// (c) Copyright 2020-2026 Advanced Micro Devices, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of AMD and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
// Project    : Series-7 Integrated Block for PCI Express
// File       : cgator_tx_mux.v
// Version    : 3.3
//
// Description : Configurator Tx Mux module - multiplexes between data from
//               Packet Generator and user logic
//
// Hierarchy   : xilinx_pcie_2_1_rport_7x
//               |
//               |--cgator_wrapper
//               |  |
//               |  |--pcie_2_1_rport_7x (in source directory)
//               |  |  |
//               |  |  |--<various>
//               |  |
//               |  |--cgator
//               |     |
//               |     |--cgator_cpl_decoder
//               |     |--cgator_pkt_generator
//               |     |--cgator_tx_mux
//               |     |--cgator_controller
//               |        |--<cgator_cfg_rom.data> (specified by ROM_FILE)
//               |
//               |--pio_master
//                  |
//                  |--pio_master_controller
//                  |--pio_master_checker
//                  |--pio_master_pkt_generator
//-----------------------------------------------------------------------------

`timescale 1ns/1ns

(* DowngradeIPIdentifiedWarnings = "yes" *)
module cgator_tx_mux
  #(
    parameter TCQ                      = 1,
    parameter C_DATA_WIDTH             = 64,
    parameter KEEP_WIDTH               = C_DATA_WIDTH / 8
  ) (
    // globals
    input wire                    user_clk,
    input wire                    reset,  

    output                        usr_s_axis_tx_tready,
    input  [C_DATA_WIDTH-1:0]     usr_s_axis_tx_tdata,
    input  [KEEP_WIDTH-1:0]       usr_s_axis_tx_tkeep,
    input  [3:0]                  usr_s_axis_tx_tuser,
    input                         usr_s_axis_tx_tlast,
    input                         usr_s_axis_tx_tvalid,

    // Packet Generator Tx interface
    output                        pg_s_axis_tx_tready,
    input  [C_DATA_WIDTH-1:0]     pg_s_axis_tx_tdata,
    input  [KEEP_WIDTH-1:0]       pg_s_axis_tx_tkeep,
    input  [3:0]                  pg_s_axis_tx_tuser,
    input                         pg_s_axis_tx_tlast,
    input                         pg_s_axis_tx_tvalid,

    // Root Port Wrapper Tx interface
    input                         rport_tx_cfg_req,
    input                         rport_tx_cfg_gnt,
    input                         rport_s_axis_tx_tready,
    output reg [C_DATA_WIDTH-1:0] rport_s_axis_tx_tdata,
    output reg [KEEP_WIDTH-1:0]   rport_s_axis_tx_tkeep,
    output reg [3:0]              rport_s_axis_tx_tuser,
    output reg                    rport_s_axis_tx_tlast,
    output reg                    rport_s_axis_tx_tvalid,

    // Root port status interface
    input [5:0]                   rport_tx_buf_av,

    // Controller interface
    input wire                    config_mode,
    output reg                    config_mode_active
  );

  // Local variables
  wire    usr_active_start;
  wire    usr_active_end;
  reg     usr_active;
  reg     usr_holdoff;

  wire    sop;                   // Start of packet
  reg     in_packet_q;


   // Generate a signal that indicates if we are currently receiving a packet.
   // This value is one clock cycle delayed from what is actually on the AXIS
   // data bus.
  always@(posedge user_clk) begin
    if(reset)
      in_packet_q <= #TCQ 1'b0;
    else if (usr_s_axis_tx_tvalid && usr_s_axis_tx_tready && usr_s_axis_tx_tlast)
      in_packet_q <= #TCQ 1'b0;
    else if (sop && usr_s_axis_tx_tready)
      in_packet_q <= #TCQ 1'b1;
  end

  assign sop = (!in_packet_q && usr_s_axis_tx_tvalid);

  // Determine when user is in the middle of a Tx TLP
  assign usr_active_start = sop && usr_s_axis_tx_tvalid && usr_s_axis_tx_tready;
  assign usr_active_end   = usr_s_axis_tx_tlast && usr_s_axis_tx_tvalid && usr_s_axis_tx_tready;
  always @(posedge user_clk) begin
    if (reset) begin
      usr_active        <= #TCQ 1'b0;
    end else begin
      if (usr_active_start) begin
        usr_active      <= #TCQ 1'b1;
      end else if (usr_active_end) begin
        usr_active      <= #TCQ 1'b0;
      end
    end
  end

  //  User tx_tready is the same as rport_tx_tready unless
  //  usr_holdoff is asserted. This can happen when:
  //    - config mode is asserted
  //    - trn_tx_cfg_req is asserted and tx_cfg_gnt is asserted
  //    - tbuf_av = 1
  //    AND user is between packets
  always @(posedge user_clk) begin
    if (reset) begin
      usr_holdoff       <= #TCQ 1'b1;
    end else begin
      if ((!usr_active && !usr_active_start) ||
          (usr_active && usr_active_end)) begin
        // User logic is between packets

        if (config_mode ||
            (rport_tx_cfg_req && rport_tx_cfg_gnt) ||
            (rport_tx_buf_av == 6'd1 && usr_active_end)) begin
            // If
            //   configuration mode is requested, or
            //   an packet is being generated inside the Root Port, or
            //   the last TX buffer is being consumed
            // Then
            //   prevent user logic from transmitting a new TLP - this
            //   compensates for the 1-cycle delay between usr_tx_tready and
            //   rport_tsrc_rdy_n
          usr_holdoff   <= #TCQ 1'b1;

        end else begin
          // None of the above conditions is true - allow user packets
          usr_holdoff   <= #TCQ 1'b0;
        end

      end else begin
        // If user logic is starting or is in the middle of a packet, don't
        // deassert usr_tdst_rdy_n
        usr_holdoff     <= #TCQ 1'b0;
      end
    end
  end

  // Deassert usr_s_axis_tx_tready when above logic determines user cannot transmit,
  // or when Root Port is not accepting data
  assign usr_s_axis_tx_tready = rport_s_axis_tx_tready && !usr_holdoff;

  // Accept entry to config mode when config_mode is asserted and user
  // has finished any outstanding Tx TLP
  always @(posedge user_clk) begin
    if (reset) begin
      config_mode_active  <= #TCQ 1'b0;
    end else begin
      config_mode_active  <= #TCQ config_mode && usr_holdoff;
    end
  end

  // tx_tready to Packet Generator is the same as usr_s_axis_tx_tready when
  // config_mode_active is asserted
  assign pg_s_axis_tx_tready = rport_s_axis_tx_tready && config_mode_active;

  // Data-path mux with one pipeline stage
  always @(posedge user_clk) begin
    if (reset) begin
      rport_s_axis_tx_tdata     <= #TCQ {C_DATA_WIDTH{1'b0}};
      rport_s_axis_tx_tkeep     <= #TCQ {KEEP_WIDTH{1'b0}};
      rport_s_axis_tx_tuser     <= #TCQ 4'h0;
      rport_s_axis_tx_tlast     <= #TCQ 1'b0;
      rport_s_axis_tx_tvalid    <= #TCQ 1'b0;

    end else begin
      if (config_mode_active) begin

        rport_s_axis_tx_tdata     <= #TCQ pg_s_axis_tx_tdata;
        rport_s_axis_tx_tkeep     <= #TCQ pg_s_axis_tx_tkeep;
        rport_s_axis_tx_tuser     <= #TCQ pg_s_axis_tx_tuser;
        rport_s_axis_tx_tlast     <= #TCQ pg_s_axis_tx_tlast;
        rport_s_axis_tx_tvalid    <= #TCQ pg_s_axis_tx_tvalid  && pg_s_axis_tx_tready;


      end else begin

        rport_s_axis_tx_tdata     <= #TCQ usr_s_axis_tx_tdata;
        rport_s_axis_tx_tkeep     <= #TCQ usr_s_axis_tx_tkeep;
        rport_s_axis_tx_tuser     <= #TCQ usr_s_axis_tx_tuser;
        rport_s_axis_tx_tlast     <= #TCQ usr_s_axis_tx_tlast;
        rport_s_axis_tx_tvalid    <= #TCQ usr_s_axis_tx_tvalid  && usr_s_axis_tx_tready;

      end
    end
  end

endmodule // cgator_tx_mux

