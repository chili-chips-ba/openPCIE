
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
// File       : cgator_pkt_generator.v
// Version    : 3.3
//
// Description : Configurator Packet Generator module - transmits downstream
//               TLPs. Packet type and non-static header and data fields are
//               provided by the Configurator module
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
module cgator_pkt_generator
  #(
    parameter        TCQ          = 1,
    parameter [15:0] REQUESTER_ID = 16'h10EE,
    parameter C_DATA_WIDTH        = 64,
    parameter KEEP_WIDTH          = C_DATA_WIDTH / 8 )
  (
    // globals
    input wire          user_clk,
    input wire          reset,

    // Tx mux interface
    input                          pg_s_axis_tx_tready,
    output reg [C_DATA_WIDTH-1:0]  pg_s_axis_tx_tdata,
    output reg [KEEP_WIDTH-1:0]    pg_s_axis_tx_tkeep,
    output  [3:0]                  pg_s_axis_tx_tuser,
    output reg                     pg_s_axis_tx_tlast,
    output reg                     pg_s_axis_tx_tvalid,

    // Controller interface
    input wire [1:0]    pkt_type,  // See TYPE_* below for encodings
    input wire [1:0]    pkt_func_num,
    input wire [9:0]    pkt_reg_num,
    input wire [3:0]    pkt_1dw_be,
    input wire [2:0]    pkt_msg_routing,
    input wire [7:0]    pkt_msg_code,
    input wire [31:0]   pkt_data,
    input wire          pkt_start,
    output reg          pkt_done
  );

  // Encodings for pkt_type
  localparam [1:0] TYPE_CFGRD = 2'b00;
  localparam [1:0] TYPE_CFGWR = 2'b01;
  localparam [1:0] TYPE_MSG   = 2'b10;
  localparam [1:0] TYPE_MSGD  = 2'b11;

  // State encodings
  localparam [2:0] ST_IDLE   = 3'd0;
  localparam [2:0] ST_CFG0   = 3'd1;
  localparam [2:0] ST_CFG1   = 3'd2;
  localparam [2:0] ST_MSG0   = 3'd3;
  localparam [2:0] ST_MSG1   = 3'd4;
  localparam [2:0] ST_MSG2   = 3'd5;

  // State variable
  reg [2:0]  pkt_state;

  generate
    if (C_DATA_WIDTH == 64) begin : width_64
      // State-machine and controller hand-shake
      always @(posedge user_clk) begin
        if (reset) begin
          pkt_state          <= #TCQ ST_IDLE;
          pkt_done           <= #TCQ 1'b0;
        end else begin
          case (pkt_state)
            ST_IDLE: begin
              // Idle - wait for Controller to request TLP transmission

              pkt_done       <= #TCQ 1'b0;

              if (pkt_start) begin
                if (pkt_type == TYPE_CFGRD || pkt_type == TYPE_CFGWR) begin
                  pkt_state  <= #TCQ ST_CFG0;
                end else begin
                  pkt_state  <= #TCQ ST_MSG0;
                end
              end
            end // ST_IDLE

            ST_CFG0: begin
              // First Quad-word (2 dwords) of a CfgRd0 or CfgWr0 TLP
              if (pg_s_axis_tx_tready) begin
                pkt_state    <= #TCQ ST_CFG1;
              end
            end // ST_CFG0

            ST_CFG1: begin
              // Second and last QW of a CfgRd0 or CfgWr0 TLP
              if (pg_s_axis_tx_tready) begin
                pkt_state    <= #TCQ ST_IDLE;
                pkt_done     <= #TCQ 1'b1;
              end
            end // ST_CFG1

            ST_MSG0: begin
              // First QW of a Msg or MsgD TLP
              if (pg_s_axis_tx_tready) begin
                pkt_state    <= #TCQ ST_MSG1;
              end
            end // ST_MSG0

            ST_MSG1: begin
              // Second QW of a Msg or MsgD TLP
              if (pg_s_axis_tx_tready) begin
                if (pkt_type == TYPE_MSGD) begin
                  // MsgD TLPs have a third QW
                  pkt_state    <= #TCQ ST_MSG2;
                end else begin
                  // Msg TLPs end after two QWs
                  pkt_state    <= #TCQ ST_IDLE;
                  pkt_done     <= #TCQ 1'b1;
                end
              end
            end // ST_MSG1

            ST_MSG2: begin
              // Third and last QW of a MsgD TLP
              if (pg_s_axis_tx_tready) begin
                pkt_state    <= #TCQ ST_IDLE;
                pkt_done     <= #TCQ 1'b1;
              end
            end // ST_MSG2

            default: begin
              pkt_state      <= #TCQ ST_IDLE;
            end // default case
          endcase
        end
      end

      // Packet generation output - combinatorially generate output to Tx Mux
      // depending on the current state
      assign pg_s_axis_tx_tuser = 4'b0100; //Enable streaming

      always @* begin
        case (pkt_state)
          ST_CFG0: begin
            // First QW of a CfgRd0 or CfgWr0 TLP
            pg_s_axis_tx_tlast = 1'b0;
            pg_s_axis_tx_tdata = {REQUESTER_ID,                       // Requester ID
                            8'd0,                                     // Tag
                            4'd0,                                     // Last DW BE
                            pkt_1dw_be,                               // First DW BE
                            1'b0,                                     // Reserved
                            (pkt_type == TYPE_CFGWR) ? 2'b10 : 2'b00, // Fmt
                            5'b00100,                                 // Type
                            8'h00,                                    // Reserved, TC, Reserved
                            4'h0,                                     // TD, EP, Attr
                            2'b00,                                    // Reserved
                            10'd1                                     // Length
                            };
            pg_s_axis_tx_tkeep  = 8'hFF;
            pg_s_axis_tx_tvalid = 1'b1;
          end // ST_CFG0

          ST_CFG1: begin
            // Second and last QW of a CfgRd0 or CfgWr0 TLP
            pg_s_axis_tx_tlast = 1'b1;
            pg_s_axis_tx_tdata = {{pkt_data, // Data (Not used if CfgRd)
                              8'd1,          // Bus #            \
                              5'd0,          // Device #         |  Completer ID
                              1'b0,          // Function # (Hi)  |
                              pkt_func_num}, // Function # (Lo)  /
                             4'h0,           // Reserved
                             pkt_reg_num,    // Ext Reg Number, Register Number
                             2'b00           // Reserved
                             };
            pg_s_axis_tx_tkeep  = (pkt_type == TYPE_CFGWR) ? 8'hFF : 8'h0F;
            pg_s_axis_tx_tvalid = 1'b1;
          end // ST_CFG1

          ST_MSG0: begin
            // First QW of a Msg or MsgD TLP
            pg_s_axis_tx_tlast = 1'b0;
            pg_s_axis_tx_tdata = {REQUESTER_ID,                       // Requester ID
                             8'd0,                                    // Tag
                             pkt_msg_code,                            // Message Code
                             1'b0,                                    // Reserved
                             (pkt_type == TYPE_MSGD) ? 2'b11 : 2'b01, // Fmt
                             2'b10,                                   // 2 MSb of Type
                             pkt_msg_routing,                         // Msg Routing
                             8'h00,                                   // Reserved, TC, Reserved
                             4'h0,                                    // TD, EP, Attr
                             2'b00,                                   // Reserved
                             (pkt_type == TYPE_MSGD) ? 10'd1 : 10'd0  // Length
                             };
            pg_s_axis_tx_tkeep  = 8'hFF;
            pg_s_axis_tx_tvalid = 1'b1;
          end // ST_MSG0

          ST_MSG1: begin
            // Second QW of a Msg or MsgD TLP (last for Msg)
            pg_s_axis_tx_tlast  = (pkt_type == TYPE_MSGD) ? 1'b0 : 1'b1;
            pg_s_axis_tx_tdata  = 64'h0000_0000_0000_0000; // Addr[31:2], Reserved, Addr[63:32]
            pg_s_axis_tx_tkeep  = 8'hFF;
            pg_s_axis_tx_tvalid = 1'b1;
          end // ST_MSG1

          ST_MSG2: begin
            // Third and last QW of a MsgD TLP
            pg_s_axis_tx_tlast  = 1'b1;
            pg_s_axis_tx_tdata  = {32'h0000_0000, pkt_data}; // Data, don't-care
            pg_s_axis_tx_tkeep  = 8'h0F;
            pg_s_axis_tx_tvalid = 1'b1;
          end // ST_MSG2

          default: begin
            // No TLP active
            pg_s_axis_tx_tlast  = 1'b0;
            pg_s_axis_tx_tdata  = 64'h0000_0000_0000_0000;
            pg_s_axis_tx_tkeep  = 8'h00;
            pg_s_axis_tx_tvalid = 1'b0;
          end // default case
        endcase
      end // End 64-bit mode
    end else begin : width_128
       // State-machine and controller hand-shake
      always @(posedge user_clk) begin
        if (reset) begin
          pkt_state          <= #TCQ ST_IDLE;
          pkt_done           <= #TCQ 1'b0;
        end else begin
          case (pkt_state)
            ST_IDLE: begin
              // Idle - wait for Controller to request TLP transmission

              pkt_done       <= #TCQ 1'b0;

              if (pkt_start) begin
                if (pkt_type == TYPE_CFGRD || pkt_type == TYPE_CFGWR) begin
                  pkt_state  <= #TCQ ST_CFG0;
                end else begin
                  pkt_state  <= #TCQ ST_MSG0;
                end
              end
            end // ST_IDLE

            ST_CFG0: begin
              // First 2 QW's (4 dwords) of a CfgRd0 or CfgWr0 TLP
              if (pg_s_axis_tx_tready) begin
                pkt_state    <= #TCQ ST_IDLE;
                pkt_done     <= #TCQ 1'b1;
              end
            end // ST_CFG0

            ST_MSG0: begin
              // First 2 QW's of a Msg or MsgD TLP
              if (pg_s_axis_tx_tready) begin
                if (pkt_type == TYPE_MSGD) begin
                  pkt_state    <= #TCQ ST_MSG1;
                end else begin
                  pkt_state    <= #TCQ ST_IDLE;
                  pkt_done     <= #TCQ 1'b1;
                end
              end
            end // ST_MSG0

            ST_MSG1: begin
              // Third QW of MsgD TLP
              if (pg_s_axis_tx_tready) begin
                  pkt_state    <= #TCQ ST_IDLE;
                  pkt_done     <= #TCQ 1'b1;
              end
            end // ST_MSG1

            default: begin
              pkt_state      <= #TCQ ST_IDLE;
            end // default case
          endcase
        end
      end

      // Packet generation output - combinatorially generate output to Tx Mux
      // depending on the current state
      assign pg_s_axis_tx_tuser = 4'b0100; //Enable streaming

      always @* begin
        case (pkt_state)
          ST_CFG0: begin
            // First 2 QW of a CfgRd0 or CfgWr0 TLP
            pg_s_axis_tx_tdata = {{pkt_data,                                 // Data (Not used if CfgRd)
                                   8'd1,                                     // Bus #            \
                                   5'd0,                                     // Device #         |  Completer ID
                                   1'b0,                                     // Function # (Hi)  |
                                   pkt_func_num},                            // Function # (Lo)  /
                                   4'h0,                                     // Reserved
                                   pkt_reg_num,                              // Ext Reg Number, Register Number
                                   2'b00,                                    // Reserved
                                   REQUESTER_ID,                             // Requester ID
                                   8'd0,                                     // Tag
                                   4'd0,                                     // Last DW BE
                                   pkt_1dw_be,                               // First DW BE
                                   1'b0,                                     // Reserved
                                   (pkt_type == TYPE_CFGWR) ? 2'b10 : 2'b00, // Fmt
                                    5'b00100,                                // Type
                                    8'h00,                                   // Reserved, TC, Reserved
                                    4'h0,                                    // TD, EP, Attr
                                    2'b00,                                   // Reserved
                                    10'd1                                    // Length
                                 };
            pg_s_axis_tx_tkeep  = (pkt_type == TYPE_CFGWR) ? 16'hFFFF : 16'h0FFF;
            pg_s_axis_tx_tvalid = 1'b1;
            pg_s_axis_tx_tlast  = 1'b1;
          end // ST_CFG0

          ST_MSG0: begin
            // First 2 QW of a Msg or MsgD TLP
            pg_s_axis_tx_tdata = {64'h0000_0000_0000_0000,                 // Addr[31:2], Reserved, Addr[63:32]
                                  REQUESTER_ID,                            // Requester ID
                                  8'd0,                                    // Tag
                                  pkt_msg_code,                            // Message Code
                                  1'b0,                                    // Reserved
                                  (pkt_type == TYPE_MSGD) ? 2'b11 : 2'b01, // Fmt
                                  2'b10,                                   // 2 MSb of Type
                                  pkt_msg_routing,                         // Msg Routing
                                  8'h00,                                   // Reserved, TC, Reserved
                                  4'h0,                                    // TD, EP, Attr
                                  2'b00,                                   // Reserved
                                  (pkt_type == TYPE_MSGD) ? 10'd1 : 10'd0  // Length
                                 };
            pg_s_axis_tx_tlast  = (pkt_type == TYPE_MSGD) ? 1'b0 : 1'b1;
            pg_s_axis_tx_tkeep  = 16'hFFFF;
            pg_s_axis_tx_tvalid = 1'b1;
          end // ST_MSG0

          ST_MSG1: begin
            // Third and last QW of a MsgD TLP
            pg_s_axis_tx_tlast  = 1'b1;
            pg_s_axis_tx_tdata  = {32'h0000_0000, pkt_data}; // Data, don't-care
            pg_s_axis_tx_tkeep  = 16'h000F;
            pg_s_axis_tx_tvalid = 1'b1;
          end // ST_MSG1

          default: begin
            // No TLP active
            pg_s_axis_tx_tlast  = 1'b0;
            pg_s_axis_tx_tdata  = {C_DATA_WIDTH{1'b0}};
            pg_s_axis_tx_tkeep  = {KEEP_WIDTH{1'b0}};
            pg_s_axis_tx_tvalid = 1'b0;
          end // default case
        endcase
      end
    end // End 128-bit Mode
    endgenerate

endmodule // cgator_pkt_generator
