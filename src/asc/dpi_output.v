`timescale 1ns / 1ps

// Platform-independent logical DPI output block for ASC v0.4.
// RGB remains RGB888 at the external logical interface.
// Physical I/O primitives, if ever required, must remain outside asc_core.
module dpi_output (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        timing_hsync,
    input  wire        timing_vsync,
    input  wire        timing_de,
    input  wire [23:0] pattern_rgb888,

    output wire        pclk,
    output wire        hsync,
    output wire        vsync,
    output wire        de,
    output wire [23:0] rgb
);

    assign pclk  = clk;
    assign hsync = timing_hsync;
    assign vsync = timing_vsync;
    assign de    = timing_de;

    assign rgb = (reset_n && timing_de) ? pattern_rgb888 : 24'h000000;

endmodule
