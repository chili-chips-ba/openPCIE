
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
// File       : pio_master_controller.v
// Version    : 3.3
//
// Description : PIO Master Controller module - performs write/read test on
//               a PIO design instantiated in a connected Endpoint. This
//               module controls the read/write/verify cycle. It waits for
//               user_lnk_up to be asserted, directs the Configurator to
//               configure the attached Endpoint, directs the PIO Master
//               Packet Generator to transmit TLPs writing data to each
//               configured BAR, directs the PIO Master Packet Generator to
//               transmit TLPs reading back data from each BAR, and specifies
//               the data to be matched to the PIO Master Checker. If the
//               entire process succeeds, it asserts the pio_test_finished
//               output. If not, it asserts the pio_test_failed output.
//
// Note        : pio_test_long is unused at this time, but is intended to
//               allow user to select between short (one write/read for each
//               aperture) and long (full memory test) tests in the future
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
module pio_master_controller
  #(
    parameter           TCQ = 1,

    // BAR A settings
    parameter           BAR_A_ENABLED = 1,
    parameter           BAR_A_64BIT = 1,  
    parameter           BAR_A_IO = 0,
    parameter [63:0]    BAR_A_BASE = 64'h1000_0000_8000_0000,
    parameter           BAR_A_SIZE = 1024, // Size in DW

    // BAR B settings
    parameter           BAR_B_ENABLED = 0,
    parameter           BAR_B_64BIT = 0,
    parameter           BAR_B_IO = 0,
    parameter [63:0]    BAR_B_BASE = 64'h0000_0000_2000_0000,
    parameter           BAR_B_SIZE = 1024, // Size in DW

    // BAR C settings
    parameter           BAR_C_ENABLED = 0,
    parameter           BAR_C_64BIT = 0,
    parameter           BAR_C_IO = 0,
    parameter [63:0]    BAR_C_BASE = 64'h0000_0000_4000_0000,
    parameter           BAR_C_SIZE = 1024, // Size in DW

    // BAR D settings
    parameter           BAR_D_ENABLED = 0,
    parameter           BAR_D_64BIT = 0,
    parameter           BAR_D_IO = 0,
    parameter [63:0]    BAR_D_BASE = 64'h0000_0000_8000_0000,
    parameter           BAR_D_SIZE = 1024  // Size in DW
  )
  (
    // globals
    input wire          user_clk,
    input wire          reset,

    // System information
    input wire          user_lnk_up,
    input wire          pio_test_restart,
    input wire          pio_test_long, // Unused for now
    output reg          pio_test_finished,
    output reg          pio_test_failed,

    // Control configuration process
    output reg          start_config,
    input wire          finished_config,
    input wire          failed_config,

    // Link Gen2
    input wire          link_gen2_capable,
    input wire          link_gen2,

    // Packet generator interface
    output reg [2:0]    tx_type,  // see TX_TYPE_* below for encoding
    output reg [7:0]    tx_tag,
    output reg [63:0]   tx_addr,
    output reg [31:0]   tx_data,
    output reg          tx_start,
    input wire          tx_done,

    // Checker interface
    output reg          rx_type,  // see RX_TYPE_* below for encoding
    output wire [7:0]   rx_tag,
    output reg [31:0]   rx_data,
    input wire          rx_good,
    input wire          rx_bad
  );

  // TLP type encoding for tx_type
  localparam [2:0] TX_TYPE_MEMRD32 = 3'b000;
  localparam [2:0] TX_TYPE_MEMWR32 = 3'b001;
  localparam [2:0] TX_TYPE_MEMRD64 = 3'b010;
  localparam [2:0] TX_TYPE_MEMWR64 = 3'b011;
  localparam [2:0] TX_TYPE_IORD    = 3'b100;
  localparam [2:0] TX_TYPE_IOWR    = 3'b101;

  // TLP type encoding for rx_type
  localparam       RX_TYPE_CPL     = 1'b0;
  localparam       RX_TYPE_CPLD    = 1'b1;

  // State encodings
  localparam [3:0] ST_WAIT_CFG      = 4'd0;
  localparam [3:0] ST_WRITE         = 4'd1;
  localparam [3:0] ST_WRITE_WAIT    = 4'd2;
  localparam [3:0] ST_IOWR_CPL_WAIT = 4'd3;
  localparam [3:0] ST_READ          = 4'd4;
  localparam [3:0] ST_READ_WAIT     = 4'd5;
  localparam [3:0] ST_READ_CPL_WAIT = 4'd6;
  localparam [3:0] ST_DONE          = 4'd7;
  localparam [3:0] ST_ERROR         = 4'd8;

  // Data used for checking each memory aperture
  localparam [31:0] BAR_A_DATA   = 32'd6;
  localparam [31:0] BAR_B_DATA   = 32'hFEED_FACE;
  localparam [31:0] BAR_C_DATA   = 32'hDECA_FBAD;
  localparam [31:0] BAR_D_DATA   = 32'h3141_5927;

  // Determine the highest-numbered enabled memory aperture
  localparam        LAST_BAR     = BAR_A_ENABLED + BAR_B_ENABLED +
                                   BAR_C_ENABLED + BAR_D_ENABLED - 1;

  // Sanity check on BAR settings
  initial begin
    if (((BAR_B_ENABLED || BAR_C_ENABLED || BAR_D_ENABLED) && !BAR_A_ENABLED) ||
        ((BAR_C_ENABLED || BAR_D_ENABLED) && !BAR_B_ENABLED) ||
        (BAR_D_ENABLED && !BAR_B_ENABLED)) begin
      $display("ERROR in %m : BARs must be enabled contiguously starting with BAR_A");
      $finish;
    end
  end

  // State control
  reg [3:0]    ctl_state;
  reg [1:0]    cur_bar;
  reg          cur_last_bar;

  // Sampling registers
  reg          user_lnk_up_q;
  reg          user_lnk_up_q2;
  reg          link_gen2_q;
  reg          link_gen2_q2;

  // Start Configurator after link comes up
  always @(posedge user_clk) begin
    if (reset) begin
      user_lnk_up_q  <= #TCQ 1'b0;
      user_lnk_up_q2 <= #TCQ 1'b0;
      link_gen2_q    <= #TCQ 1'b0;
      link_gen2_q2   <= #TCQ 1'b0;
      start_config   <= #TCQ 1'b0;
    end else begin
      user_lnk_up_q  <= #TCQ user_lnk_up;
      user_lnk_up_q2 <= #TCQ user_lnk_up_q;
      link_gen2_q    <= #TCQ link_gen2;
      link_gen2_q2   <= #TCQ link_gen2_q;
      start_config   <= #TCQ (link_gen2_capable) ? (!link_gen2_q2 && link_gen2_q && user_lnk_up) : (!user_lnk_up_q2 && user_lnk_up_q);
    end
  end

  // Controller state-machine
  always @(posedge user_clk) begin
    if (reset || !user_lnk_up) begin
      // Link going down causes PIO master state machine to restart
      ctl_state       <= #TCQ ST_WAIT_CFG;
      cur_bar         <= #TCQ 2'b00;
    end else begin
      case (ctl_state)
        ST_WAIT_CFG: begin
          // Wait for Configurator to finish configuring the Endpoint
          // If this state is entered due to assertion of pio_test_restart,
          // state machine will immediately fall through to ST_WRITE. In that
          // case, this state is used to reset the cur_bar counter

          if (failed_config) begin
            ctl_state      <= #TCQ ST_ERROR;
          end else if (finished_config) begin
            ctl_state      <= #TCQ ST_WRITE;
          end

          cur_bar          <= #TCQ 2'b00;
        end // ST_WAIT_CFG

        ST_WRITE: begin
          // Transmit write TLP to Endpoint PIO design

          ctl_state        <= #TCQ ST_WRITE_WAIT;
        end // ST_WRITE

        ST_WRITE_WAIT: begin
          // Wait for write TLP to be transmitted

          if (tx_done) begin
            if (tx_type == TX_TYPE_IOWR) begin
              // If targeted aperture was an IO BAR, wait for a completion TLP
              ctl_state    <= #TCQ ST_IOWR_CPL_WAIT;

            end else if (cur_last_bar) begin
              // If targeted aperture was the last one enabled, start sending
              // reads
              ctl_state    <= #TCQ ST_READ;
              //ctl_state    <= #TCQ ST_DONE;
              cur_bar      <= #TCQ 2'b00;

            end else begin
              // Otherwise, send more writes
              ctl_state    <= #TCQ ST_WRITE;
              cur_bar      <= #TCQ cur_bar + 1'b1;
            end
          end
        end // ST_WRITE_WAIT

        ST_IOWR_CPL_WAIT: begin
          // Wait for completion for an IO write to be returned

          if (rx_bad) begin
            // If there was something wrong with the completion, finish with
            // an error condition
            ctl_state      <= #TCQ ST_ERROR;

          end else if (rx_good) begin
            if (cur_last_bar) begin
              // If completion was good and targeted aperture was the last one
              // enabled, start sending reads
              ctl_state    <= #TCQ ST_READ;
              cur_bar      <= #TCQ 2'b00;

            end else begin
              // Otherwise, send more writes
              ctl_state    <= #TCQ ST_WRITE;
              cur_bar      <= #TCQ cur_bar + 1'b1;
            end
          end
        end // ST_IOWR_CPL_WAIT

        ST_READ: begin
          // Send a read TLP to Endpoint PIO design

          ctl_state        <= #TCQ ST_READ_WAIT;
        end // ST_READ

        ST_READ_WAIT: begin
          // Wait for write TLP to be transmitted

          if (tx_done) begin
            ctl_state      <= #TCQ ST_READ_CPL_WAIT;
          end
        end // ST_WRITE_WAIT

        ST_READ_CPL_WAIT: begin
          // Wait for completion to be returned

          if (rx_bad) begin
            // If there was something wrong with the completion, finish with
            // an error condition
            ctl_state      <= #TCQ ST_ERROR;

          end else if (rx_good) begin
            if (cur_last_bar) begin
              // If completion was good and targeted aperture was the last one
              // enabled, finish with a success condition
              ctl_state    <= #TCQ ST_DONE;

            end else begin
              // Otherwise, send more reads
              ctl_state    <= #TCQ ST_READ;
              cur_bar      <= #TCQ cur_bar + 1'b1;
            end
          end
        end // ST_IOWR_CPL_WAIT

        ST_DONE: begin
          // Test passed successfully. Wait for restart to be requested

          if (pio_test_restart) begin
            ctl_state      <= #TCQ ST_WAIT_CFG;
          end
        end // ST_DONE

        ST_ERROR: begin
          // Test failed. Wait for restart to be requested

          if (pio_test_restart) begin
            ctl_state      <= #TCQ ST_WAIT_CFG;    
          end
        end // ST_ERROR
      endcase
    end
  end

  // Generate status outputs based on state
  always @(posedge user_clk) begin
    if (reset) begin
      pio_test_finished     <= #TCQ 1'b0;
      pio_test_failed       <= #TCQ 1'b0;
    end else begin
      pio_test_finished     <= #TCQ (ctl_state == ST_DONE);
      pio_test_failed       <= #TCQ (ctl_state == ST_ERROR);
    end
  end

  // Track whether currnt BAR is last in the list. cur_bar gets incremented in
  // ST_WRITE and ST_READ, and tx_done and rx_done take at least two
  // clock cycles to be asserted, so cur_last_bar will always be valid before
  // it's needed
  always @(posedge user_clk) begin
    if (reset) begin
      cur_last_bar      <= #TCQ 1'b0;
    end else begin
      cur_last_bar      <= #TCQ (cur_bar == LAST_BAR);
    end
  end

  // Generate outputs to packet generator and checker
  always @(posedge user_clk) begin
    if (reset) begin
      tx_type          <= #TCQ 3'b000;
      tx_addr          <= #TCQ 64'd0;
      tx_data          <= #TCQ 32'd0;
      rx_type          <= #TCQ 1'b0;
      rx_data          <= #TCQ 32'd0;

      tx_tag           <= #TCQ 8'd0;
      tx_start         <= #TCQ 1'b0;
    end else begin
      if (ctl_state == ST_WRITE || ctl_state == ST_READ) begin
        // New control information is latched out only in these two states

        case (cur_bar)  // Select settings for current aperture
          2'd0: begin   // BAR A
            tx_type    <= #TCQ (ctl_state == ST_WRITE) ?
                                    BAR_A_IO ? TX_TYPE_IOWR :
                                               BAR_A_64BIT ? TX_TYPE_MEMWR64 :
                                                             TX_TYPE_MEMWR32 :
                                    BAR_A_IO ? TX_TYPE_IORD :
                                               BAR_A_64BIT ? TX_TYPE_MEMRD64 :
                                                             TX_TYPE_MEMRD32;
            tx_data    <= #TCQ BAR_A_DATA;
            tx_addr    <= #TCQ BAR_A_BASE;
            rx_type    <= #TCQ (ctl_state == ST_READ) ? RX_TYPE_CPLD : RX_TYPE_CPL;
            rx_data    <= #TCQ BAR_A_DATA;
          end

          2'd1: begin   // BAR B
            tx_type    <= #TCQ (ctl_state == ST_WRITE) ?
                                    BAR_B_IO ? TX_TYPE_IOWR :
                                               BAR_B_64BIT ? TX_TYPE_MEMWR64 :
                                                             TX_TYPE_MEMWR32 :
                                    BAR_B_IO ? TX_TYPE_IORD :
                                               BAR_B_64BIT ? TX_TYPE_MEMRD64 :
                                                             TX_TYPE_MEMRD32;
            tx_data    <= #TCQ BAR_B_DATA;
            tx_addr    <= #TCQ BAR_B_BASE;
            rx_type    <= #TCQ (ctl_state == ST_READ) ? RX_TYPE_CPLD : RX_TYPE_CPL;
            rx_data    <= #TCQ BAR_B_DATA;
          end

          2'd2: begin   // BAR C
            tx_type    <= #TCQ (ctl_state == ST_WRITE) ?
                                    BAR_C_IO ? TX_TYPE_IOWR :
                                               BAR_C_64BIT ? TX_TYPE_MEMWR64 :
                                                             TX_TYPE_MEMWR32 :
                                    BAR_C_IO ? TX_TYPE_IORD :
                                               BAR_C_64BIT ? TX_TYPE_MEMRD64 :
                                                             TX_TYPE_MEMRD32;
            tx_data    <= #TCQ BAR_C_DATA;
            tx_addr    <= #TCQ BAR_C_BASE;
            rx_type    <= #TCQ (ctl_state == ST_READ) ? RX_TYPE_CPLD : RX_TYPE_CPL;
            rx_data    <= #TCQ BAR_C_DATA;
          end

          default: begin   // BAR D
            tx_type    <= #TCQ (ctl_state == ST_WRITE) ?
                                    BAR_D_IO ? TX_TYPE_IOWR :
                                               BAR_D_64BIT ? TX_TYPE_MEMWR64 :
                                                             TX_TYPE_MEMWR32 :
                                    BAR_D_IO ? TX_TYPE_IORD :
                                               BAR_D_64BIT ? TX_TYPE_MEMRD64 :
                                                             TX_TYPE_MEMRD32;
            tx_data    <= #TCQ BAR_D_DATA;
            tx_addr    <= #TCQ BAR_D_BASE;
            rx_type    <= #TCQ (ctl_state == ST_READ) ? RX_TYPE_CPLD : RX_TYPE_CPL;
            rx_data    <= #TCQ BAR_D_DATA;
          end
        endcase
      end

      if (ctl_state == ST_WRITE || ctl_state == ST_READ) begin
        // Tag is incremented for each TLP sent
        tx_tag         <= #TCQ tx_tag + 1'b1;
      end

      if (ctl_state == ST_WRITE || ctl_state == ST_READ) begin
        // Pulse tx_start for one cycle as state machine passes through
        // ST_WRITE or ST_READ
        tx_start       <= #TCQ 1'b1;
      end else begin
        tx_start       <= #TCQ 1'b0;
      end
    end
  end

  // tx_tag and rx_tag are always the same
  assign rx_tag = tx_tag;

endmodule // pio_master_controller

