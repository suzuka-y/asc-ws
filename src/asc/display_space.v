`timescale 1ns / 1ps

// ASC v0.41 logical-display-space boundary.
// v0.41 keeps the v0.4 identity mapping and one-clock latency.
// This is a reset-free datapath register stage; output validity is managed
// globally after the complete 10-clock pipeline fills.
module display_space (
    input  wire       clk,

    input  wire [9:0] physical_x,
    input  wire [9:0] physical_y,
    input  wire       physical_valid,

    output reg  [9:0] logical_x,
    output reg  [9:0] logical_y,
    output reg        logical_valid
);

    always @(posedge clk) begin
        logical_x     <= physical_x;
        logical_y     <= physical_y;
        logical_valid <= physical_valid;
    end

endmodule
