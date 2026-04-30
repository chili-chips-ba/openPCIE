
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
// File       : pio_master_checker.v
// Version    : 3.3
//
// Description : PIO Master Checker module - consumes incoming TLPs and
//               verifies that all completion fields match what is expected.
//               Header and data fields to check against are provided by
//               Controller module
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
module pio_master_checker
  #(
    parameter           TCQ           = 1,
    parameter [15:0]    REQUESTER_ID  = 16'h10EE,
    parameter           C_DATA_WIDTH  = 64,
    parameter           KEEP_WIDTH    = C_DATA_WIDTH / 8
  ) (
    // globals
    input wire                  user_clk,
    input wire                  reset,

    // Rx AXIS interface
    input  [C_DATA_WIDTH-1:0]   m_axis_rx_tdata,
    input  [KEEP_WIDTH-1:0]     m_axis_rx_tkeep,
    input                       m_axis_rx_tlast,
    input                       m_axis_rx_tvalid,
    input    [21:0]             m_axis_rx_tuser,

    // Controller interface
    input wire                  rx_type, // see RX_TYPE_* below for encoding
    input wire [7:0]            rx_tag,
    input wire [31:0]           rx_data,
    output reg                  rx_good,
    output reg                  rx_bad
  );

  // Bit-slicing positions
  localparam FMT_TYPE_HI   = 30;
  localparam FMT_TYPE_LO   = 24;
  localparam CPL_STAT_HI   = 47;
  localparam CPL_STAT_LO   = 45;
  localparam CPL_DATA_HI   = 63;
  localparam CPL_DATA_LO   = 32;
  localparam REQ_ID_HI     = 31;
  localparam REQ_ID_LO     = 16;
  localparam TAG_HI        = 15;
  localparam TAG_LO        = 8;

  localparam CPL_DATA_HI_128   = 127;
  localparam CPL_DATA_LO_128   = 96;
  localparam REQ_ID_HI_128     = 95;
  localparam REQ_ID_LO_128     = 80;
  localparam TAG_HI_128        = 79;
  localparam TAG_LO_128        = 72;

  // Static field values for comparison
  localparam FMT_TYPE_CPLX = 6'b001010;
  localparam SC_STATUS     = 3'b000;
  localparam UR_STATUS     = 3'b001;
  localparam CRS_STATUS    = 3'b010;
  localparam CA_STATUS     = 3'b100;

  // TLP type encoding for rx_type - same as high bit of Format field
  localparam RX_TYPE_CPL   = 1'b0;
  localparam RX_TYPE_CPLD  = 1'b1;

  // Local registers for processing incoming completions
  reg     cpl_status_good;
  reg     cpl_type_match;
  reg     cpl_detect;
  reg     cpl_detect_q;
  (* mark_debug = "true" *) reg     cpl_data_match;
  reg     cpl_reqid_match;
  reg     cpl_tag_match;

  wire    sop;                   // Start of packet
  reg     in_packet_q;


   // Generate a signal that indicates if we are currently receiving a packet.
   // This value is one clock cycle delayed from what is actually on the AXIS
   // data bus.
  generate
    if (C_DATA_WIDTH == 64) begin : in_pkt_width_64
      always@(posedge user_clk) begin
        if(reset)
          in_packet_q <= #TCQ 1'b0;
        else if (m_axis_rx_tvalid && m_axis_rx_tlast)
          in_packet_q <= #TCQ 1'b0;
        else if (sop)
          in_packet_q <= #TCQ 1'b1;
      end

      assign sop = (!in_packet_q && m_axis_rx_tvalid);

    end else begin: in_pkt_width_128
      always@(posedge user_clk) begin
        if(reset)
          in_packet_q <= #TCQ 1'b0;
        else if (m_axis_rx_tvalid && m_axis_rx_tuser[21])
          in_packet_q <= #TCQ 1'b0;
        else if (sop)
          in_packet_q <= #TCQ 1'b1;
      end

      assign sop = (!in_packet_q && m_axis_rx_tuser[14] && m_axis_rx_tvalid);

    end
  endgenerate



  generate
    if (C_DATA_WIDTH == 64) begin : width_64
      // Process first Quad-word (two dwords) of received TLPs: Determine whether
      //   - TLP is a Completion
      //   - Type of completion matches expected
      //   - Completion status is "Successful Completion"
      always @(posedge user_clk) begin
        if (reset) begin
          cpl_status_good   <= #TCQ 1'b0;
          cpl_type_match    <= #TCQ 1'b0;
          cpl_detect        <= #TCQ 1'b0;
        end else begin
          if (sop) begin
            // Check for beginning of Completion TLP - cpl_detect is asserted for
            // Completion to indicate to later pipeline stages whether to continue
            // processing data
            if (m_axis_rx_tdata[FMT_TYPE_HI-1:FMT_TYPE_LO] == FMT_TYPE_CPLX) begin
              cpl_detect     <= #TCQ 1'b1;
            end else begin
              cpl_detect     <= #TCQ 1'b0;
            end

            // Compare type and completion status with expected
            cpl_type_match   <= #TCQ (m_axis_rx_tdata[FMT_TYPE_HI] == rx_type);
            cpl_status_good  <= #TCQ (m_axis_rx_tdata[CPL_STAT_HI:CPL_STAT_LO] == SC_STATUS);

          end else begin
            cpl_detect       <= #TCQ 1'b0;
          end
        end
      end

      // Process second Quad-word of received TLPs: Determine whether
      //   - Data matches expected value
      //   - Requester ID matches expected value
      //   - Tag matches expected value
      always @(posedge user_clk) begin
        if (reset) begin
          cpl_detect_q      <= #TCQ 1'b0;
          cpl_data_match    <= #TCQ 1'b0;
          cpl_reqid_match   <= #TCQ 1'b0;
          cpl_tag_match     <= #TCQ 1'b0;
        end else begin
          // Pipeline cpl_detect signal
          cpl_detect_q       <= #TCQ cpl_detect;

          // Check fields for match
          cpl_data_match     <= #TCQ (m_axis_rx_tdata[CPL_DATA_HI:CPL_DATA_LO] == rx_data);
          cpl_reqid_match    <= #TCQ (m_axis_rx_tdata[REQ_ID_HI:REQ_ID_LO] == REQUESTER_ID);
          cpl_tag_match      <= #TCQ (m_axis_rx_tdata[TAG_HI:TAG_LO] == rx_tag);
        end
      end

      // After second QW is processed, check whether all fields matched expected
      // and output results
      always @(posedge user_clk) begin
        if (reset) begin
          rx_good           <= #TCQ 1'b0;
          rx_bad            <= #TCQ 1'b0;
        end else begin
          if (cpl_detect_q) begin
            if (cpl_type_match && cpl_status_good && cpl_reqid_match && cpl_tag_match) begin
              if (cpl_data_match || (rx_type == RX_TYPE_CPL)) begin
                // Header and data match, or header match and no data expected
                rx_good      <= #TCQ 1'b1;

              end else begin
                // Data mismatch
                rx_bad       <= #TCQ 1'b1;
              end

            end else begin
              // Header mismatch
              rx_bad         <= #TCQ 1'b1;
            end

          end else begin
            // Not checking this cycle
            rx_good          <= #TCQ 1'b0;
            rx_bad           <= #TCQ 1'b0;
          end
        end
      end
    end else begin: width_128
      // Process first 2 QW's (4 DW's) of received TLPs: Determine whether
      //   - TLP is a Completion
      //   - Type of completion matches expected
      //   - Completion status is "Successful Completion"
      always @(posedge user_clk) begin
        if (reset) begin
          cpl_status_good   <= #TCQ 1'b0;
          cpl_type_match    <= #TCQ 1'b0;
          cpl_detect        <= #TCQ 1'b0;
          cpl_data_match    <= #TCQ 1'b0;
          cpl_reqid_match   <= #TCQ 1'b0;
          cpl_tag_match     <= #TCQ 1'b0;
          cpl_detect_q      <= #TCQ 1'b0;
        end else begin
          if (sop) begin
            // Check for beginning of Completion TLP and process entire packet in 1 clock
            if (m_axis_rx_tdata[FMT_TYPE_HI-1:FMT_TYPE_LO] == FMT_TYPE_CPLX) begin
              cpl_detect      <= #TCQ 1'b1;
            end else begin
              cpl_detect      <= #TCQ 1'b0;
            end

            // Compare type and completion status with expected
            cpl_data_match  <= #TCQ (m_axis_rx_tdata[CPL_DATA_HI_128:CPL_DATA_LO_128] == rx_data);
            cpl_reqid_match <= #TCQ (m_axis_rx_tdata[REQ_ID_HI_128:REQ_ID_LO_128] == REQUESTER_ID);
            cpl_tag_match   <= #TCQ (m_axis_rx_tdata[TAG_HI_128:TAG_LO_128] == rx_tag);
            cpl_type_match  <= #TCQ (m_axis_rx_tdata[FMT_TYPE_HI] == rx_type);
            cpl_status_good <= #TCQ (m_axis_rx_tdata[CPL_STAT_HI:CPL_STAT_LO] == SC_STATUS);

          end else begin
            cpl_status_good   <= #TCQ 1'b0;
            cpl_type_match    <= #TCQ 1'b0;
            cpl_detect        <= #TCQ 1'b0;
            cpl_data_match    <= #TCQ 1'b0;
            cpl_reqid_match   <= #TCQ 1'b0;
            cpl_tag_match     <= #TCQ 1'b0;
          end
        end
      end

      // After TLP is processed, check whether all fields matched expected and output results
      always @(posedge user_clk) begin
        if (reset) begin
          rx_good           <= #TCQ 1'b0;
          rx_bad            <= #TCQ 1'b0;
        end else begin
          if (cpl_detect) begin
            if (cpl_type_match && cpl_status_good && cpl_reqid_match && cpl_tag_match) begin
              if (cpl_data_match || (rx_type == RX_TYPE_CPL)) begin
                // Header and data match, or header match and no data expected
                rx_good      <= #TCQ 1'b1;
              end else begin
                // Data mismatch
                rx_bad       <= #TCQ 1'b1;
              end
            end else begin
              // Header mismatch
              rx_bad         <= #TCQ 1'b1;
            end
          end else begin
            // Not checking this cycle
            rx_good          <= #TCQ 1'b0;
            rx_bad           <= #TCQ 1'b0;
          end
        end
      end
    end
    endgenerate

endmodule // pio_master_checker
