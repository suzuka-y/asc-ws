`timescale 1ns / 1ps

// Nine-level, shift/add-only fade scaler.
// ASC v0.41 timing contract: exactly 1 pixel-clock latency.
// fade_level is decoded earlier in the pipeline; this stage contains only
// channel scaling plus the output register.
module fade_scaler (
    input  wire        clk,
    input  wire [3:0]  fade_level,
    input  wire [23:0] mixed_rgb888,
    output reg  [23:0] faded_rgb888
);

    function [7:0] scale_channel;
        input [7:0] c;
        input [3:0] level;
        begin
            case (level)
                4'd0:    scale_channel = 8'd0;
                4'd1:    scale_channel = c >> 4;
                4'd2:    scale_channel = c >> 3;
                4'd3:    scale_channel = (c >> 3) + (c >> 4);
                4'd4:    scale_channel = c >> 2;
                4'd5:    scale_channel = (c >> 2) + (c >> 3);
                4'd6:    scale_channel = c >> 1;
                4'd7:    scale_channel = (c >> 1) + (c >> 2);
                default: scale_channel = c;
            endcase
        end
    endfunction

    wire [7:0] faded_r_comb = scale_channel(mixed_rgb888[23:16], fade_level);
    wire [7:0] faded_g_comb = scale_channel(mixed_rgb888[15:8],  fade_level);
    wire [7:0] faded_b_comb = scale_channel(mixed_rgb888[7:0],   fade_level);

    always @(posedge clk) begin
        faded_rgb888 <= {faded_r_comb, faded_g_comb, faded_b_comb};
    end

endmodule
