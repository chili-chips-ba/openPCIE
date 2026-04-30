
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
// File       : pio_master_pkt_generator.v
// Version    : 3.3
//
// Description : PIO Master Packet Generator module - generates downstream TLPs
//               as directed by the Controller module. Type and contents for
//               variable fields are specified via the tx_* inputs.
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
module pio_master_pkt_generator
  #(
    parameter         TCQ           = 1,
    parameter [15:0]  REQUESTER_ID  = 16'h10EE,
    parameter         C_DATA_WIDTH  = 64,
    parameter         KEEP_WIDTH    = C_DATA_WIDTH / 8
  ) (
    // Globals
    input wire                user_clk,
    input wire                reset,

    // Tx TRN interface
    //output reg          trn_tsof_n,
    //output reg          trn_teof_n,
    //output reg [63:0]   trn_td,
    //output reg          trn_trem_n,
    //output wire         trn_tstr_n,
    //output wire         trn_terrfwd_n,
    //output wire         trn_tsrc_dsc_n,
    //output reg          trn_tsrc_rdy_n,
    //input wire          trn_tdst_rdy_n,

    // Tx
    input                         s_axis_tx_tready,
    output reg [C_DATA_WIDTH-1:0] s_axis_tx_tdata,
    output reg [KEEP_WIDTH-1:0]   s_axis_tx_tkeep,
    output [3:0]                  s_axis_tx_tuser,
    output reg                    s_axis_tx_tlast,
    output reg                    s_axis_tx_tvalid,

    // Controller interface
    input wire [2:0]          tx_type,  // see TX_TYPE_* below for encoding
    input wire [7:0]          tx_tag,
    input wire [63:0]         tx_addr,
    input wire [31:0]         tx_data,
    input wire                tx_start,
    output reg                tx_done
  );

  // TLP type encoding for tx_type
  localparam [2:0] TYPE_MEMRD32 = 3'b000;
  localparam [2:0] TYPE_MEMWR32 = 3'b001;
  localparam [2:0] TYPE_MEMRD64 = 3'b010;
  localparam [2:0] TYPE_MEMWR64 = 3'b011;
  localparam [2:0] TYPE_IORD    = 3'b100;
  localparam [2:0] TYPE_IOWR    = 3'b101;

  // State encoding
  localparam [1:0] ST_IDLE   = 2'd0;
  localparam [1:0] ST_CYC1    = 2'd1;
  localparam [1:0] ST_CYC2    = 2'd2;
  localparam [1:0] ST_CYC3    = 2'd3;

  // State variable
  reg [1:0]   pkt_state;

  // Registers to store format and type bits of the TLP header
  reg [1:0]   pkt_fmt;
  reg [4:0]   pkt_type;

  generate
    if (C_DATA_WIDTH == 64) begin : width_64
      // 64-bit Packet Generator State-machine - responsible for hand-shake
      // with Controller module and selecting which QW of the packet is
      // transmitted
      always @(posedge user_clk) begin
        if (reset) begin
          pkt_state     <= #TCQ ST_IDLE;
          tx_done       <= #TCQ 1'b0;
        end else begin
          case (pkt_state)
            ST_IDLE: begin
              // Waiting for input from Controller module

              tx_done        <= #TCQ 1'b0;

              if (tx_start) begin
                pkt_state    <= #TCQ ST_CYC1;
              end
            end // ST_IDLE

            ST_CYC1: begin
              // First Quad-word - wait for data to be accepted by core

              if (s_axis_tx_tready) begin
                pkt_state    <= #TCQ ST_CYC2;
              end
            end // ST_CYC1

            ST_CYC2: begin
              // Second Quad-word - wait for data to be accepted by core

              if (s_axis_tx_tready) begin
                if (tx_type == TYPE_MEMWR64) begin
                  // A MemWr64 TLP uses half of the third Quad-word

                  pkt_state  <= #TCQ ST_CYC3;
                end else begin
                  // All non-MemWr64 TLPs end here

                  pkt_state  <= #TCQ ST_IDLE;
                  tx_done    <= #TCQ 1'b1;
                end
              end
            end // ST_CYC2

            ST_CYC3: begin
              // Third Quad-word - wait for data to be accepted by core

              if (s_axis_tx_tready) begin
                pkt_state    <= #TCQ ST_IDLE;
                tx_done      <= #TCQ 1'b1;
              end
            end // ST_CYC3

            default: begin
              pkt_state      <= #TCQ ST_IDLE;
            end // default case
          endcase
        end
      end

      // Compute Format and Type fields from type of TLP requested
      always @(posedge user_clk) begin
        if (reset) begin
          pkt_fmt      <= #TCQ 2'b00;
          pkt_type     <= #TCQ 5'b00000;
        end else begin
          case (tx_type)
            TYPE_MEMRD32: begin
              pkt_fmt  <= #TCQ 2'b00;
              pkt_type <= #TCQ 5'b00000;
            end
            TYPE_MEMWR32: begin
              pkt_fmt  <= #TCQ 2'b10;
              pkt_type <= #TCQ 5'b00000;
            end
            TYPE_MEMRD64: begin
              pkt_fmt  <= #TCQ 2'b01;
              pkt_type <= #TCQ 5'b00000;
            end
            TYPE_MEMWR64: begin
              pkt_fmt  <= #TCQ 2'b11;
              pkt_type <= #TCQ 5'b00000;
            end
            TYPE_IORD: begin
              pkt_fmt  <= #TCQ 2'b00;
              pkt_type <= #TCQ 5'b00010;
            end
            TYPE_IOWR: begin
              pkt_fmt  <= #TCQ 2'b10;
              pkt_type <= #TCQ 5'b00010;
            end
            default: begin
              pkt_fmt  <= #TCQ 2'b00;
              pkt_type <= #TCQ 5'b00000;
            end
          endcase
        end
      end

      // Static Transaction Interface outputs
      assign s_axis_tx_tuser = 4'b0100; // Enable streaming

      // Packet generation output - combinatorial output using current state to
      // select which fields to output
      always @* begin
        case (pkt_state)
          ST_IDLE: begin
            s_axis_tx_tlast  = 1'b0;
            s_axis_tx_tdata  = 64'h0000_0000_0000_0000;
            s_axis_tx_tkeep  = 8'h0;
            s_axis_tx_tvalid = 1'b0;
          end // ST_IDLE

          ST_CYC1: begin
            // First QW (two dwords) of TLP

            s_axis_tx_tlast = 1'b0;
            s_axis_tx_tdata = {
                              REQUESTER_ID, // Requester ID
                              tx_tag,       // Tag
                              4'h0, 4'hF,   // Last DW BE, First DW BE
                              1'b0,         // Reserved
                              pkt_fmt,      // Format
                              pkt_type,     // Type
                              8'h00,        // Reserved, TC, Reserved
                              4'h0,         // TD, EP, Attr
                              2'b00,        // Reserved
                              10'd1         // Length
                              };
            s_axis_tx_tkeep  = 8'hFF;
            s_axis_tx_tvalid = 1'b1;
          end // ST_CYC1

          ST_CYC2: begin
            // Second QW of TLP - either address (for 64-bit transactions) or
            // address + data (for 32-bit transactions). For MemRd32 or IORd
            // TLPs, the tx_data field is ignored by the core because s_axis_tx_tkeep
            // masks it out.

            s_axis_tx_tlast  = (tx_type == TYPE_MEMWR64) ? 1'b0 : 1'b1;
            s_axis_tx_tdata  = (tx_type == TYPE_MEMRD64 || tx_type == TYPE_MEMWR64) ?
                                {tx_addr[31:2], 2'b00, tx_addr[63:32]} :      // 64-bit address
                                {tx_data, tx_addr[31:2], 2'b00};              // 32-bit address
            s_axis_tx_tkeep  = (tx_type == TYPE_MEMRD32 || tx_type == TYPE_IORD) ? 8'h0F : 8'hFF;
            s_axis_tx_tvalid = 1'b1;
          end // ST_CYC2

          ST_CYC3: begin
            // Third QW of TLP - only used for MemWr64; only lower 32-bits are
            // used

            s_axis_tx_tlast  = 1'b1;
            s_axis_tx_tdata  = {32'h0000_0000, tx_data}; // Data, don't-care
            s_axis_tx_tkeep  = 8'h0F;
            s_axis_tx_tvalid = 1'b1;
          end // ST_CYC3

          default: begin
            s_axis_tx_tlast  = 1'b0;
            s_axis_tx_tdata  = 64'h0000_0000_0000_0000;
            s_axis_tx_tkeep  = 8'h00;
            s_axis_tx_tvalid = 1'b0;
          end // default case
        endcase
      end
    end else begin : width_128

      // 128-bit Packet Generator State-machine - responsible for hand-shake
      // with Controller module and selecting which QW of the packet is
      // transmitted
      always @(posedge user_clk) begin
        if (reset) begin
          pkt_state     <= #TCQ ST_IDLE;
          tx_done       <= #TCQ 1'b0;
        end else begin
          case (pkt_state)
            ST_IDLE: begin
              // Waiting for input from Controller module
              tx_done        <= #TCQ 1'b0;
              if (tx_start) begin
                pkt_state    <= #TCQ ST_CYC1;
              end
            end // ST_IDLE

            ST_CYC1: begin
              // First Double-Quad-word - wait for data to be accepted by core
              if (s_axis_tx_tready) begin
                if (tx_type == TYPE_MEMWR64) begin
                  pkt_state    <= #TCQ ST_CYC2;
                end else begin
                  pkt_state  <= #TCQ ST_IDLE;
                  tx_done    <= #TCQ 1'b1;
                end
              end
            end // ST_CYC1

            ST_CYC2: begin
              // Second Quad-word - wait for data to be accepted by core
              if (s_axis_tx_tready) begin
                pkt_state  <= #TCQ ST_IDLE;
                tx_done    <= #TCQ 1'b1;
              end
            end // ST_CYC2

            default: begin
              pkt_state      <= #TCQ ST_IDLE;
            end // default case
          endcase
        end
      end

      // Compute Format and Type fields from type of TLP requested
      always @(posedge user_clk) begin
        if (reset) begin
          pkt_fmt      <= #TCQ 2'b00;
          pkt_type     <= #TCQ 5'b00000;
        end else begin
          case (tx_type)
            TYPE_MEMRD32: begin
              pkt_fmt  <= #TCQ 2'b00;
              pkt_type <= #TCQ 5'b00000;
            end
            TYPE_MEMWR32: begin
              pkt_fmt  <= #TCQ 2'b10;
              pkt_type <= #TCQ 5'b00000;
            end
            TYPE_MEMRD64: begin
              pkt_fmt  <= #TCQ 2'b01;
              pkt_type <= #TCQ 5'b00000;
            end
            TYPE_MEMWR64: begin
              pkt_fmt  <= #TCQ 2'b11;
              pkt_type <= #TCQ 5'b00000;
            end
            TYPE_IORD: begin
              pkt_fmt  <= #TCQ 2'b00;
              pkt_type <= #TCQ 5'b00010;
            end
            TYPE_IOWR: begin
              pkt_fmt  <= #TCQ 2'b10;
              pkt_type <= #TCQ 5'b00010;
            end
            default: begin
              pkt_fmt  <= #TCQ 2'b00;
              pkt_type <= #TCQ 5'b00000;
            end
          endcase
        end
      end

      // Static Transaction Interface outputs
      assign s_axis_tx_tuser = 4'b0100; // Enable streaming

      // Packet generation output - combinatorial output using current state to
      // select which fields to output
      always @* begin
        case (pkt_state)
          ST_IDLE: begin
            s_axis_tx_tlast  = 1'b0;
            s_axis_tx_tdata  = {C_DATA_WIDTH{1'b0}};
            s_axis_tx_tkeep  = {KEEP_WIDTH{1'b0}};
            s_axis_tx_tvalid = 1'b0;
          end // ST_IDLE

          ST_CYC1: begin
            // First 2 QW's (4 DW's) of TLP

            s_axis_tx_tlast  = (tx_type == TYPE_MEMWR64) ? 1'b0 : 1'b1;
            s_axis_tx_tdata  = {(tx_type == TYPE_MEMRD64 || tx_type == TYPE_MEMWR64) ?
                                {tx_addr[31:2], 2'b00, tx_addr[63:32]} :      // 64-bit address
                                {tx_data, tx_addr[31:2], 2'b00},
                                 REQUESTER_ID,                                // Requester ID
                                 tx_tag,                                      // Tag
                                 4'h0, 4'hF,                                  // Last DW BE, First DW BE
                                 1'b0,                                        // Reserved
                                 pkt_fmt,                                     // Format
                                 pkt_type,                                    // Type
                                 8'h00,                                       // Reserved, TC, Reserved
                                 4'h0,                                        // TD, EP, Attr
                                 2'b00,                                       // Reserved
                                 10'd1                                        // Length
                               };
            s_axis_tx_tkeep  = (tx_type == TYPE_MEMRD32 || tx_type == TYPE_IORD) ? 16'h0FFF:16'hFFFF;
            s_axis_tx_tvalid = 1'b1;
          end // ST_CYC1

          ST_CYC2: begin
            // Second 2 QW's of TLP (64-bit MWR only)
            s_axis_tx_tdata  = {96'h0000_0000, tx_data}; // 32-bit data
            s_axis_tx_tkeep  = 16'h000F;
            s_axis_tx_tvalid = 1'b1;
            s_axis_tx_tlast  = 1'b1;
          end // ST_CYC2

          default: begin
            s_axis_tx_tlast  = 1'b0;
            s_axis_tx_tdata  = {C_DATA_WIDTH{1'b0}};
            s_axis_tx_tkeep  = {KEEP_WIDTH{1'b0}};
            s_axis_tx_tvalid = 1'b0;
          end // default case
        endcase
      end
    end
    endgenerate

endmodule // pio_master_pkt_generator
