
`timescale 1ps/1ps

module xpm_cdc_single #(
    parameter integer DEST_SYNC_FF   = 4,  
    parameter integer INIT_SYNC_FF   = 0,  
    parameter integer SIM_ASSERT_CHK = 0,  
    parameter integer SRC_INPUT_REG  = 1   
) (
    input  wire src_clk,
    input  wire src_in,
    input  wire dest_clk,
    output wire dest_out
);

    wire src_ff;

    generate
        if (SRC_INPUT_REG != 0) begin : g_src_reg
            (* ASYNC_REG = "TRUE" *) reg src_q = 1'b0;
            always @(posedge src_clk) src_q <= src_in;
            assign src_ff = src_q;
        end else begin : g_src_comb
            assign src_ff = src_in;
        end
    endgenerate

    (* ASYNC_REG = "TRUE" *) reg [DEST_SYNC_FF-1:0] dest_sync = {DEST_SYNC_FF{1'b0}};

    always @(posedge dest_clk)
        dest_sync <= {dest_sync[DEST_SYNC_FF-2:0], src_ff};

    assign dest_out = dest_sync[DEST_SYNC_FF-1];

endmodule
