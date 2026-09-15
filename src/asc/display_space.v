`timescale 1ns / 1ps

// ASC v0.4 logical-display-space boundary.
//
// Responsibility:
//   - Accept coordinates from the real/physical raster space.
//   - Present coordinates to pattern RTL only as logical-space coordinates.
//   - Form a registered timing boundary before the pattern-computation cone.
//
// v0.4 intentionally requires the logical and real display spaces to match.
// Therefore the mapping is an identity mapping.  Future revisions may change
// only this boundary when a non-identity mapping is required; pattern RTL must
// remain independent of the real display timing and output interface.
module display_space (
    input  wire       clk,
    input  wire       reset_n,

    input  wire [9:0] physical_x,
    input  wire [9:0] physical_y,
    input  wire       physical_valid,

    output reg  [9:0] logical_x,
    output reg  [9:0] logical_y,
    output reg        logical_valid
);

    // One-pixel-clock register boundary.  This both establishes the ownership
    // boundary between raster timing and pattern computation and prevents the
    // physical counters from directly feeding the long pattern logic cone.
    always @(posedge clk) begin
        if (!reset_n) begin
            logical_x     <= 10'd0;
            logical_y     <= 10'd0;
            logical_valid <= 1'b0;
        end else begin
            logical_x     <= physical_x;
            logical_y     <= physical_y;
            logical_valid <= physical_valid;
        end
    end

endmodule
