
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
// File       : cgator_cpl_decoder.v
// Version    : 3.3
//
// Description : Configurator Completion Decoder module - receives incoming
//               TLPs and checks completion status. When in config mode, all
//               received TLPs are consumed by this module. When not in config
//               mode, all TLPs are passed to user logic
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
module cgator_cpl_decoder
  #(
    parameter           TCQ            = 1,
    parameter           EXTRA_PIPELINE = 1,
    parameter [15:0]    REQUESTER_ID   = 16'h10EE,
    parameter C_DATA_WIDTH             = 64,
    parameter KEEP_WIDTH               = C_DATA_WIDTH / 8
  ) (
    // globals
    input wire          user_clk,

    input wire          reset,

    // Root Port Wrapper Rx interface

    // Rx
    input  [C_DATA_WIDTH-1:0]     rport_m_axis_rx_tdata,
    input  [KEEP_WIDTH-1:0]       rport_m_axis_rx_tkeep,
    input                         rport_m_axis_rx_tlast,
    input                         rport_m_axis_rx_tvalid,
    output                        rport_m_axis_rx_tready,
    input    [21:0]               rport_m_axis_rx_tuser,
    output                        rport_rx_np_ok,



    // User Rx interface

    output reg [C_DATA_WIDTH-1:0]     usr_m_axis_rx_tdata,
    output reg [KEEP_WIDTH-1:0]       usr_m_axis_rx_tkeep,
    output reg                        usr_m_axis_rx_tlast,
    output reg                        usr_m_axis_rx_tvalid,
    output reg   [21:0]               usr_m_axis_rx_tuser,

    // Controller interface
    input wire          config_mode,
    output reg          cpl_sc,
    output reg          cpl_ur,
    output reg          cpl_crs,
    output reg          cpl_ca,
    output reg [31:0]   cpl_data,
    output reg          cpl_mismatch
  );

  // Bit-slicing positions for decoding header fields
  localparam FMT_TYPE_HI   = 30;
  localparam FMT_TYPE_LO   = 24;
  localparam CPL_STAT_HI   = 47;
  localparam CPL_STAT_LO   = 45;
  localparam CPL_DATA_HI   = 63;
  localparam CPL_DATA_LO   = 32;
  localparam REQ_ID_HI     = 31;
  localparam REQ_ID_LO     = 16;

  localparam CPL_DATA_HI_128 = 127;
  localparam CPL_DATA_LO_128 = 96;
  localparam REQ_ID_HI_128   = 95;
  localparam REQ_ID_LO_128   = 80;

  // Static field values for comparison
  localparam FMT_TYPE_CPLX = 6'b001010;
  localparam SC_STATUS     = 3'b000;
  localparam UR_STATUS     = 3'b001;
  localparam CRS_STATUS    = 3'b010;
  localparam CA_STATUS     = 3'b100;

  // Local variables
  reg    [C_DATA_WIDTH-1:0]   pipe_m_axis_rx_tdata;
  reg    [KEEP_WIDTH-1:0]     pipe_m_axis_rx_tkeep;
  reg                         pipe_m_axis_rx_tlast;
  reg                         pipe_m_axis_rx_tvalid;
  reg [21:0]                  pipe_m_axis_rx_tuser;
  reg                         pipe_rsop;

  reg [C_DATA_WIDTH-1:0]  check_rd;
  reg         check_rsop;
  reg         check_rsrc_rdy;
  reg [2:0]   cpl_status;
  reg         cpl_detect;

  wire        sop;                   // Start of packet
  reg         in_packet_q;

   // Generate a signal that indicates if we are currently receiving a packet.
   // This value is one clock cycle delayed from what is actually on the AXIS
   // data bus.
  generate
    if (C_DATA_WIDTH == 64) begin : in_pkt_width_64
      always@(posedge user_clk) begin
          if(reset)
            in_packet_q <= #TCQ 1'b0;
          else if (rport_m_axis_rx_tvalid && rport_m_axis_rx_tready && rport_m_axis_rx_tlast)
            in_packet_q <= #TCQ 1'b0;
          else if (sop && rport_m_axis_rx_tready)
            in_packet_q <= #TCQ 1'b1;
      end

    assign sop = (!in_packet_q && rport_m_axis_rx_tvalid);

    end else begin: in_pkt_width_128
      always@(posedge user_clk) begin
          if(reset)
            in_packet_q <= #TCQ 1'b0;
          else if (rport_m_axis_rx_tvalid && rport_m_axis_rx_tready && rport_m_axis_rx_tuser[21])
            in_packet_q <= #TCQ 1'b0;
          else if (sop && rport_m_axis_rx_tready)
            in_packet_q <= #TCQ 1'b1;
      end

      // Assign start of packet to IS_SOF encoded into TUSER bus
      assign sop = (!in_packet_q && rport_m_axis_rx_tuser[14] && rport_m_axis_rx_tvalid);

    end
  endgenerate

  // Data-path with one or two pipeline stages
  always @(posedge user_clk) begin
    if (reset) begin
      pipe_m_axis_rx_tdata   <= #TCQ {C_DATA_WIDTH{1'b0}};
      pipe_m_axis_rx_tkeep   <= #TCQ {KEEP_WIDTH{1'b0}};
      pipe_m_axis_rx_tlast   <= #TCQ 1'b0;
      pipe_m_axis_rx_tvalid  <= #TCQ 1'b0;
      pipe_m_axis_rx_tuser   <= #TCQ 22'b0;
      pipe_rsop              <= #TCQ 1'b0;

      usr_m_axis_rx_tdata    <= #TCQ {C_DATA_WIDTH{1'b0}};
      usr_m_axis_rx_tkeep    <= #TCQ {KEEP_WIDTH{1'b0}};
      usr_m_axis_rx_tlast    <= #TCQ 1'b0;
      usr_m_axis_rx_tvalid   <= #TCQ 1'b0;
      usr_m_axis_rx_tuser    <= #TCQ 22'b0;

    end else begin

      pipe_m_axis_rx_tdata   <= #TCQ rport_m_axis_rx_tdata;
      pipe_m_axis_rx_tkeep   <= #TCQ rport_m_axis_rx_tkeep;
      pipe_m_axis_rx_tlast   <= #TCQ rport_m_axis_rx_tlast;
      pipe_m_axis_rx_tvalid  <= #TCQ rport_m_axis_rx_tvalid;
      pipe_m_axis_rx_tuser   <= #TCQ rport_m_axis_rx_tuser;
      pipe_rsop              <= #TCQ sop;

      usr_m_axis_rx_tdata    <= #TCQ (EXTRA_PIPELINE == 1) ? pipe_m_axis_rx_tdata     : rport_m_axis_rx_tdata;
      usr_m_axis_rx_tkeep    <= #TCQ (EXTRA_PIPELINE == 1) ? pipe_m_axis_rx_tkeep     : rport_m_axis_rx_tkeep;
      usr_m_axis_rx_tlast    <= #TCQ (EXTRA_PIPELINE == 1) ? pipe_m_axis_rx_tlast     : rport_m_axis_rx_tlast;
      usr_m_axis_rx_tvalid   <= #TCQ (EXTRA_PIPELINE == 1) ? (pipe_m_axis_rx_tvalid && !config_mode) :
                                                             (rport_m_axis_rx_tvalid && !config_mode);
      usr_m_axis_rx_tuser    <= #TCQ (EXTRA_PIPELINE == 1) ? pipe_m_axis_rx_tuser     : rport_m_axis_rx_tuser;
    end
  end

  // Dst rdy and rNP OK are always asserted to Root Port wrapper
  assign rport_m_axis_rx_tready = 1'b1;
  assign rport_rx_np_ok   = 1'b1;

  //
  // Completion processing
  //

  // Select input to completion decoder depending on whether extra pipeline
  // stage is selected
  always @* begin
    check_rd         = EXTRA_PIPELINE ? pipe_m_axis_rx_tdata    : rport_m_axis_rx_tdata;
    check_rsop       = EXTRA_PIPELINE ? pipe_rsop               : sop;
    check_rsrc_rdy   = EXTRA_PIPELINE ? pipe_m_axis_rx_tvalid   : rport_m_axis_rx_tvalid;
  end

  generate
    if (C_DATA_WIDTH == 64) begin : width_64

      // Process first QW of received TLP - Check for Cpl or CplD type and capture
      // completion status
      always @(posedge user_clk) begin
        if (reset) begin
          cpl_status     <= #TCQ 3'b000;
          cpl_detect     <= #TCQ 1'b0;
        end else begin
          if (check_rsop && check_rsrc_rdy) begin
            // Check for Start of Frame

            if (check_rd[FMT_TYPE_HI-1:FMT_TYPE_LO] == FMT_TYPE_CPLX) begin
              // Check Format and Type fields to see whether this is a Cpl or
              // CplD. If so, set the cpl_detect bit for the next pipeline stage.
              cpl_detect   <= #TCQ 1'b1;

              // Capture Completion Status header field
              cpl_status   <= #TCQ check_rd[CPL_STAT_HI:CPL_STAT_LO];

            end else begin
              // Not a Cpl or CplD TLP
              cpl_detect   <= #TCQ 1'b0;
            end

          end else begin
            // Not start-of-frame
            cpl_detect     <= #TCQ 1'b0;
          end
        end
      end

      // Process second QW of received TLP - check Requester ID and output
      // status bits and data Dword
      always @(posedge user_clk) begin
        if (reset) begin
          cpl_sc         <= #TCQ 1'b0;
          cpl_ur         <= #TCQ 1'b0;
          cpl_crs        <= #TCQ 1'b0;
          cpl_ca         <= #TCQ 1'b0;
          cpl_data       <= #TCQ 32'd0;
          cpl_mismatch   <= #TCQ 1'b0;
        end else begin
          if (cpl_detect) begin
            // Only process TLP if previous pipeline stage has determined this is
            // a Cpl or CplD TLP

            // Capture data
            cpl_data       <= #TCQ check_rd[CPL_DATA_HI:CPL_DATA_LO];

            if (check_rd[REQ_ID_HI:REQ_ID_LO] == REQUESTER_ID) begin
              // If requester ID matches, check Completion Status field
              cpl_sc       <= #TCQ (cpl_status == SC_STATUS);
              cpl_ur       <= #TCQ (cpl_status == UR_STATUS);
              cpl_crs      <= #TCQ (cpl_status == CRS_STATUS);
              cpl_ca       <= #TCQ (cpl_status == CA_STATUS);
              cpl_mismatch <= #TCQ 1'b0;

            end else begin
              // If Requester ID doesn't match, set mismatch indicator
              cpl_sc       <= #TCQ 1'b0;
              cpl_ur       <= #TCQ 1'b0;
              cpl_crs      <= #TCQ 1'b0;
              cpl_ca       <= #TCQ 1'b0;
              cpl_mismatch <= #TCQ 1'b1;
            end

          end else begin
            // If this isn't the 2nd QW of a Cpl or CplD, do nothing
            cpl_sc         <= #TCQ 1'b0;
            cpl_ur         <= #TCQ 1'b0;
            cpl_crs        <= #TCQ 1'b0;
            cpl_ca         <= #TCQ 1'b0;
            cpl_mismatch   <= #TCQ 1'b0;
          end
        end
      end
    end else begin : width_128
      // Process first 2 QW's of received TLP - Check for Cpl or CplD type and capture
      // completion status
      always @(posedge user_clk) begin
        if (reset) begin
          cpl_status     <= #TCQ 3'b000;
          cpl_detect     <= #TCQ 1'b0;
          cpl_sc         <= #TCQ 1'b0;
          cpl_ur         <= #TCQ 1'b0;
          cpl_crs        <= #TCQ 1'b0;
          cpl_ca         <= #TCQ 1'b0;
          cpl_data       <= #TCQ 32'd0;
          cpl_mismatch   <= #TCQ 1'b0;
        end else begin
          cpl_detect     <= #TCQ 1'b0;  // Unused in 128-bit mode
          if (check_rsop && check_rsrc_rdy) begin
            // Check for Start of Frame

            if (check_rd[FMT_TYPE_HI-1:FMT_TYPE_LO] == FMT_TYPE_CPLX) begin

              if (check_rd[REQ_ID_HI_128:REQ_ID_LO_128] == REQUESTER_ID) begin
                // If requester ID matches, check Completion Status field
                cpl_sc       <= #TCQ (check_rd[CPL_STAT_HI:CPL_STAT_LO] == SC_STATUS);
                cpl_ur       <= #TCQ (check_rd[CPL_STAT_HI:CPL_STAT_LO] == UR_STATUS);
                cpl_crs      <= #TCQ (check_rd[CPL_STAT_HI:CPL_STAT_LO] == CRS_STATUS);
                cpl_ca       <= #TCQ (check_rd[CPL_STAT_HI:CPL_STAT_LO] == CA_STATUS);
                cpl_mismatch <= #TCQ 1'b0;
              end else begin
                cpl_sc       <= #TCQ 1'b0;
                cpl_ur       <= #TCQ 1'b0;
                cpl_crs      <= #TCQ 1'b0;
                cpl_ca       <= #TCQ 1'b0;
                cpl_mismatch <= #TCQ 1'b1;
              end

            // Capture data
            cpl_data       <= #TCQ check_rd[CPL_DATA_HI_128:CPL_DATA_LO_128];

            end else begin
              // Not a Cpl or CplD TLP
              cpl_data     <= #TCQ {C_DATA_WIDTH{1'b0}};
              cpl_sc       <= #TCQ 1'b0;
              cpl_ur       <= #TCQ 1'b0;
              cpl_crs      <= #TCQ 1'b0;
              cpl_ca       <= #TCQ 1'b0;
              cpl_mismatch <= #TCQ 1'b0;
            end

          end else begin
            // Not start-of-frame
            cpl_data     <= #TCQ {C_DATA_WIDTH{1'b0}};
            cpl_sc       <= #TCQ 1'b0;
            cpl_ur       <= #TCQ 1'b0;
            cpl_crs      <= #TCQ 1'b0;
            cpl_ca       <= #TCQ 1'b0;
            cpl_mismatch <= #TCQ 1'b0;
          end
        end
      end
    end
    endgenerate

endmodule // cgator_cpl_decoder

