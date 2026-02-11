`timescale 1ns / 1ps

module riscv_pcie_soc (
    input wire clk,
    input wire resetn,

    output reg  [63:0] s_axis_tx_tdata,
    output reg  [7:0]  s_axis_tx_tkeep,
    output reg         s_axis_tx_tlast,
    output reg         s_axis_tx_tvalid,
    input  wire        s_axis_tx_tready,

    input  wire [63:0] m_axis_rx_tdata,
    input  wire [7:0]  m_axis_rx_tkeep,
    input  wire        m_axis_rx_tlast,
    input  wire        m_axis_rx_tvalid,
    output wire        m_axis_rx_tready,

    input wire [15:0]  cfg_status,
    input wire [15:0]  cfg_command,
    input wire         cfg_msg_received_err_fatal,
    
    input wire [5:0]   tx_buf_av
);

    wire        mem_valid;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    reg  [31:0] mem_rdata; 

    wire ram_ready;
    wire [31:0] ram_rdata;
    wire bridge_ready;
    reg  [31:0] bridge_rdata;

    reg [31:0] tx_packet_counter;

    wire is_ram    = (mem_addr[31:24] == 8'h00); 
    wire is_bridge = (mem_addr[31:24] == 8'h30);

    picorv32 #(
        .PROGADDR_RESET(32'h0000_0000),
        .STACKADDR(32'h0000_2000),
        .BARREL_SHIFTER(1),
        .ENABLE_COUNTERS(1)
    ) cpu (
        .clk       (clk),
        .resetn    (resetn),
        .mem_valid (mem_valid),
        .mem_ready (mem_ready),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_rdata (mem_rdata)   
    );

    reg [31:0] ram [0:2047]; 
    initial begin
        $readmemh("firmware.hex", ram);
    end
    reg [31:0] ram_rdata_reg;
    reg ram_ready_reg;

    always @(posedge clk) begin
        ram_ready_reg <= 0;
        if (mem_valid && is_ram) begin
            if (mem_wstrb == 0) begin
                ram_rdata_reg <= ram[mem_addr[12:2]];
                ram_ready_reg <= 1;
            end else begin
                if (mem_wstrb[0]) ram[mem_addr[12:2]][7:0]   <= mem_wdata[7:0];
                if (mem_wstrb[1]) ram[mem_addr[12:2]][15:8]  <= mem_wdata[15:8];
                if (mem_wstrb[2]) ram[mem_addr[12:2]][23:16] <= mem_wdata[23:16];
                if (mem_wstrb[3]) ram[mem_addr[12:2]][31:24] <= mem_wdata[31:24];
                ram_ready_reg <= 1;
            end
        end
    end
    assign ram_rdata = ram_rdata_reg;
    assign ram_ready = ram_ready_reg;

    reg [31:0] tx_header0; // 0x30000000
    reg [31:0] tx_header1; // 0x30000004
    reg [31:0] tx_header2; // 0x30000008
    reg [31:0] tx_data;    // 0x3000000C

    reg [31:0] rx_status_reg;      
    reg [31:0] rx_data_reg;        
    reg [31:0] rx_header_info_reg;    
    reg [31:0] pcie_err_status_reg;
    
    reg [31:0] pcie_phy_status_reg;

    reg [1:0] tx_state;
    localparam IDLE = 0, SEND_CYCLE_1 = 1, SEND_CYCLE_2 = 2;

    reg rx_phase; 

    reg bridge_ready_reg;

    always @(posedge clk) begin
        if (!resetn) begin  
            pcie_err_status_reg <= 0;         
            pcie_phy_status_reg <= 0;
        end else begin
            pcie_err_status_reg <= {15'b0, cfg_msg_received_err_fatal, cfg_status};
            pcie_phy_status_reg <= {24'b0, tx_state, tx_buf_av}; 
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            tx_state <= IDLE;
            bridge_ready_reg <= 0;
            s_axis_tx_tvalid <= 0;
            rx_status_reg <= 0;
            rx_data_reg <= 0;
            rx_header_info_reg <= 0;
            rx_phase <= 0;
            
            tx_packet_counter <= 0; 
            
        end else begin
            bridge_ready_reg <= 0;

            if (mem_valid && is_bridge && !bridge_ready_reg) begin
                bridge_ready_reg <= 1;

                if (mem_wstrb != 0) begin
                    case (mem_addr[4:2])
                        3'b000: tx_header0 <= mem_wdata;
                        3'b001: tx_header1 <= mem_wdata;
                        3'b010: tx_header2 <= mem_wdata;
                        3'b011: begin 
                                tx_data <= mem_wdata;
                                tx_state <= SEND_CYCLE_1; 
                                
                                tx_packet_counter <= tx_packet_counter + 1;
                                end
                    endcase
                end
            end

            case (tx_state)    
                IDLE: begin
                    s_axis_tx_tvalid <= 0;
                end
                SEND_CYCLE_1: begin  
                    s_axis_tx_tdata  <= {tx_header1, tx_header0};
                    s_axis_tx_tkeep  <= 8'hFF;
                    s_axis_tx_tvalid <= 1;
                    s_axis_tx_tlast  <= 0;
                    if (s_axis_tx_tready) tx_state <= SEND_CYCLE_2;
                end
                SEND_CYCLE_2: begin
                    s_axis_tx_tdata  <= {tx_data, tx_header2};                     
                    s_axis_tx_tkeep  <= (tx_header0[30] == 1'b1) ? 8'hFF : 8'h0F; 
                    s_axis_tx_tvalid <= 1;
                    s_axis_tx_tlast  <= 1; 
                
                    if (s_axis_tx_tready) begin
                        tx_state <= IDLE;
                    end
                end
            endcase

            if (m_axis_rx_tvalid) begin
                if (rx_phase == 0) begin
                    if (m_axis_rx_tdata[28:24] == 5'b01010) begin 
                         rx_status_reg <= {29'b0, m_axis_rx_tdata[47:45]};
                         rx_phase <= 1;       
                    end
                end 
                else if (rx_phase == 1) begin
                    rx_header_info_reg <= m_axis_rx_tdata[31:0]; 
                    rx_data_reg        <= m_axis_rx_tdata[63:32];  
                    if (m_axis_rx_tlast) begin
                        rx_phase <= 0; 
                    end
                end
            end
        end
    end

    assign m_axis_rx_tready = 1'b1; 

    always @(*) begin
        if (is_ram) begin
            mem_rdata = ram_rdata;
        end else if (is_bridge) begin
            if (mem_addr[5]) begin
                 mem_rdata = pcie_phy_status_reg;
            end else begin

                case (mem_addr[4:2])
                    3'b100: mem_rdata = rx_status_reg;      
                    3'b101: mem_rdata = rx_data_reg;        
                    3'b110: mem_rdata = rx_header_info_reg; 
                    3'b111: mem_rdata = pcie_err_status_reg;
                    default: mem_rdata = 0;
                endcase
            end
        end else begin
            mem_rdata = 32'hDEADBEEF;
        end
    end

    assign mem_ready = ram_ready || bridge_ready_reg;

endmodule