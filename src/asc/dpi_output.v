`timescale 1ns / 1ps

// ASC v0.43 RGB888 DPI output.
//
// PCLK always runs directly from clk.
// HSYNC / VSYNC / DE / RGB are registered here as the final pipeline stage.
// This adds one clock of external-output latency, making the complete ASC
// pixel pipeline 13 clocks.
//
// Before the upstream 12-clock pipeline becomes valid, syncs are held at
// their inactive level (Low for the positive-polarity 720p profile), DE is
// Low and RGB is black.
module dpi_output (
    input  wire        clk,
    input  wire        output_valid,
    input  wire        timing_hsync,
    input  wire        timing_vsync,
    input  wire        timing_de,
    input  wire [23:0] pattern_rgb888,

    output wire        pclk,
    output reg         hsync,
    output reg         vsync,
    output reg         de,
    output reg  [23:0] rgb
);

    assign pclk = clk;

    // Final DPI output register stage.
    //
    // Keeping this register at the pad-facing boundary removes the previous
    // output_valid -> mask logic -> I/O pad critical path.  No explicit reset
    // is required here: output_valid is reset/masked upstream and PCLK is
    // expected to run during reset, so these outputs are driven to their
    // inactive values on the first clock while the core is held in reset.
    always @(posedge clk) begin
        if (!output_valid) begin
            hsync <= 1'b0;
            vsync <= 1'b0;
            de    <= 1'b0;
            rgb   <= 24'h000000;
        end else begin
            hsync <= timing_hsync;
            vsync <= timing_vsync;
            de    <= timing_de;
            rgb   <= timing_de ? pattern_rgb888 : 24'h000000;
        end
    end

endmodule
