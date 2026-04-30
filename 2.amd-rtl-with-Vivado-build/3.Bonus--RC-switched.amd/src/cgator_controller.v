
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
// File       : cgator_controller.v
// Version    : 3.3
//
// Description : Configurator Controller module - directs configuration of
//               Endpoint connected to the local Root Port. Configuration
//               steps are read from the file specified by the ROM_FILE
//               parameter. This module directs the Packet Generator module to
//               create downstream TLPs and receives decoded Completion TLP
//               information from the Completion Decoder module.
//
// Hierarchy   : xilinx_pcie_2_1_rport_7x
//               |
//               |--cgator_wrapper
//               |  |
//               |  |--pcie_2_1_rport_7x (Core Top Level, in source directory)
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
module cgator_controller
  #(
    parameter TCQ                  = 1,
    parameter ROM_FILE             = "cgator_cfg_rom.data", 
    parameter ROM_SIZE             = 46 
  )  
  (   
    // globals
    input wire          user_clk,
    input wire          reset,

    // User interface
    input wire          start_config,
    output reg          finished_config,
    output reg          failed_config,

    // Packet Generator interface
    output reg [7:0]    pkt_bus_num,
    output reg [4:0]    pkt_dev_num,
    
    output reg [1:0]    pkt_type,
    output reg [1:0]    pkt_func_num,
    output reg [9:0]    pkt_reg_num,  
    output reg [3:0]    pkt_1dw_be,
    output reg [2:0]    pkt_msg_routing,
    output reg [7:0]    pkt_msg_code,
    output reg [31:0]   pkt_data,
    output reg          pkt_start,
    input wire          pkt_done,  

    // Tx Mux and Completion Decoder interface
    output reg          config_mode,
    input wire          config_mode_active,
    input wire          cpl_sc,
    input wire          cpl_ur,
    input wire          cpl_crs,
    input wire          cpl_ca,
    input wire [31:0]   cpl_data,
    input wire          cpl_mismatch
  );

  // Encodings for pkt_type output
  localparam [1:0] TYPE_CFGRD = 2'b00;
  localparam [1:0] TYPE_CFGWR = 2'b01;
  localparam [1:0] TYPE_MSG   = 2'b10;
  localparam [1:0] TYPE_MSGD  = 2'b11;

  // State encodings
  localparam [2:0] ST_IDLE     = 3'd0;
  localparam [2:0] ST_WAIT_CFG = 3'd1;
  localparam [2:0] ST_READ1    = 3'd2;
  localparam [2:0] ST_READ2    = 3'd3;
  localparam [2:0] ST_WAIT_PKT = 3'd4;
  localparam [2:0] ST_WAIT_CPL = 3'd5;
  localparam [2:0] ST_DONE     = 3'd6;

  localparam       ROM_ADDR_WIDTH = 11; 

  // Bit-slicing constants for ROM output data
  localparam       PKT_BUS_HI         = 31;
  localparam       PKT_BUS_LO         = 24;
  localparam       PKT_DEV_HI         = 23;
  localparam       PKT_DEV_LO         = 19;
  
  localparam       PKT_TYPE_HI        = 17;
  localparam       PKT_TYPE_LO        = 16;
  localparam       PKT_FUNC_NUM_HI    = 15;
  localparam       PKT_FUNC_NUM_LO    = 14;
  localparam       PKT_REG_NUM_HI     = 13;
  localparam       PKT_REG_NUM_LO     = 4;
  localparam       PKT_1DW_BE_HI      = 3;
  localparam       PKT_1DW_BE_LO      = 0;
  localparam       PKT_MSG_ROUTING_HI = 10;
  localparam       PKT_MSG_ROUTING_LO = 8; 
  localparam       PKT_MSG_CODE_HI    = 7;  
  localparam       PKT_MSG_CODE_LO    = 0; 
  localparam       PKT_DATA_HI        = 31;
  localparam       PKT_DATA_LO        = 0;

  // Local variables
  reg [2:0]                ctl_state;
  reg [ROM_ADDR_WIDTH-1:0] ctl_addr;
  reg [31:0]               ctl_data;
  reg                      ctl_last_cfg;
  reg                      ctl_skip_cpl;
  
  reg                      config_success_any; 

  // ROM instantiation
  reg [31:0]               ctl_rom [0:ROM_SIZE-1];

  // Determine when the last ROM address is being read  
  always @(posedge user_clk) begin
    if (reset) begin  
      ctl_last_cfg    <= #TCQ 1'b0;
    end else begin
      if (ctl_addr == (ROM_SIZE-1)) begin
        ctl_last_cfg  <= #TCQ 1'b1;
      end else if (start_config) begin
        ctl_last_cfg  <= #TCQ 1'b0;
      end
    end
  end

  // Determine whether or not to expect a completion
  always @(posedge user_clk) begin
    if (reset) begin
      ctl_skip_cpl    <= #TCQ 1'b0;
    end else begin
      if (pkt_start) begin
        if (pkt_type == TYPE_MSG || pkt_type == TYPE_MSGD) begin
          ctl_skip_cpl  <= #TCQ 1'b1;
        end else begin
          ctl_skip_cpl  <= #TCQ 1'b0;
        end
      end
    end
  end

  // Controller state-machine
  always @(posedge user_clk) begin
    if (reset) begin
      ctl_state          <= #TCQ ST_IDLE;
      config_mode        <= #TCQ 1'b1;
      finished_config    <= #TCQ 1'b0;
      failed_config      <= #TCQ 1'b0;
      pkt_start          <= #TCQ 1'b0;
      pkt_type           <= #TCQ 2'd0;
      pkt_func_num       <= #TCQ 2'd0;
      pkt_reg_num        <= #TCQ 10'd0;
      pkt_1dw_be         <= #TCQ 4'd0;
      pkt_msg_routing    <= #TCQ 3'd0;
      pkt_msg_code       <= #TCQ 8'd0;
      pkt_data           <= #TCQ 32'd0;
      pkt_bus_num        <= #TCQ 8'd0;
      pkt_dev_num        <= #TCQ 5'd0;
      config_success_any <= #TCQ 1'b0;

      ctl_addr           <= #TCQ {ROM_ADDR_WIDTH{1'b0}};
    end else begin
      case (ctl_state)
        ST_IDLE: begin
          config_mode      <= #TCQ 1'b1;
          finished_config  <= #TCQ 1'b0;
          failed_config    <= #TCQ 1'b0;
          pkt_start        <= #TCQ 1'b0;
          
          if (start_config) begin
            config_success_any <= #TCQ 1'b0; 
            ctl_state          <= #TCQ ST_WAIT_CFG;
          end
        end 

        ST_WAIT_CFG: begin
          if (config_mode_active) begin
            ctl_state        <= #TCQ ST_READ1;
            ctl_addr         <= #TCQ ctl_addr + 1'b1;
          end
        end

        ST_READ1: begin
          pkt_bus_num      <= #TCQ ctl_data[PKT_BUS_HI:PKT_BUS_LO];
          pkt_dev_num      <= #TCQ ctl_data[PKT_DEV_HI:PKT_DEV_LO];
          pkt_type         <= #TCQ ctl_data[PKT_TYPE_HI:PKT_TYPE_LO];
          pkt_func_num     <= #TCQ ctl_data[PKT_FUNC_NUM_HI:PKT_FUNC_NUM_LO];
          pkt_reg_num      <= #TCQ ctl_data[PKT_REG_NUM_HI:PKT_REG_NUM_LO];
          pkt_1dw_be       <= #TCQ ctl_data[PKT_1DW_BE_HI:PKT_1DW_BE_LO];
          pkt_msg_routing  <= #TCQ ctl_data[PKT_MSG_ROUTING_HI:PKT_MSG_ROUTING_LO];
          pkt_msg_code     <= #TCQ ctl_data[PKT_MSG_CODE_HI:PKT_MSG_CODE_LO];

          ctl_addr         <= #TCQ ctl_addr + 1'b1;
          ctl_state        <= #TCQ ST_READ2;
        end

        ST_READ2: begin
          pkt_data         <= #TCQ ctl_data[PKT_DATA_HI:PKT_DATA_LO];
          pkt_start        <= #TCQ 1'b1;
          ctl_state        <= #TCQ ST_WAIT_PKT;
        end

        ST_WAIT_PKT: begin
          pkt_start        <= #TCQ 1'b0;
          if (pkt_done) begin
            ctl_state      <= #TCQ ST_WAIT_CPL;
          end
        end

        ST_WAIT_CPL: begin
          if (cpl_sc || ctl_skip_cpl || cpl_ur || cpl_ca) begin
                        if (cpl_sc) begin
                config_success_any <= #TCQ 1'b1;
            end
            
            if (ctl_last_cfg) begin
              finished_config <= #TCQ 1'b1;
              ctl_state       <= #TCQ ST_DONE;
            end else begin
              ctl_addr        <= #TCQ ctl_addr + 1'b1;
              ctl_state       <= #TCQ ST_READ1;
            end  

          end else if (cpl_crs) begin
            pkt_start         <= #TCQ 1'b1;
            ctl_state         <= #TCQ ST_WAIT_PKT;  

          end else if (cpl_mismatch) begin
            finished_config   <= #TCQ 1'b1;
            failed_config     <= #TCQ 1'b1;
            ctl_state         <= #TCQ ST_DONE;
          end
        end

        ST_DONE: begin
          ctl_addr            <= #TCQ {ROM_ADDR_WIDTH{1'b0}}; 
          if (!config_success_any && finished_config) begin
              failed_config   <= #TCQ 1'b1; 
          end

          if (start_config) begin
            config_mode       <= #TCQ 1'b1;
            finished_config   <= #TCQ 1'b0;
            failed_config     <= #TCQ 1'b0;
            config_success_any <= #TCQ 1'b0;
            ctl_state         <= #TCQ ST_WAIT_CFG;
          end else begin
            config_mode       <= #TCQ 1'b0;
          end
        end
      endcase
    end
  end

  always @(posedge user_clk) begin 
    ctl_data <= #TCQ ctl_rom[ctl_addr];
  end
  
  initial begin
    $readmemb(ROM_FILE, ctl_rom, 0, ROM_SIZE-1);
  end

endmodule