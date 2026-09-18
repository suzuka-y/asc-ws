`timescale 1ns / 1ps

// P4: full-cell corner triangle fill on the 80x80 physical grid.
// Background rate: 25%. Orientation is cell-hash derived.
// Visual scroll: up at 80 px/s (1 cell/s).
//
// Pipeline (4 clocks total):
//   S1: capture raw coordinates + scroll phase
//   S2: apply Y scroll
//   S3: cell style
//   S4: triangle geometry + palette / RGB output
module pattern_corner_fill (
    input  wire        clk,
    input  wire        pattern_valid,
    input  wire [3:0]  cell_x80,
    input  wire [6:0]  local_x80,
    input  wire [3:0]  cell_y80,
    input  wire [6:0]  local_y80,
    input  wire [14:0] scroll_cell80,
    input  wire [6:0]  scroll_local80,
    output reg  [23:0] rgb888
);
    localparam [23:0] BG_RGB = 24'hFFFFFF;

    // ------------------------------------------------------------------
    // S1: capture raw coordinates and scroll phase.
    //
    // This register boundary cuts the former critical path from the
    // scroll-phase registers through grid_offset_axis into the first
    // pattern register.
    // ------------------------------------------------------------------
    reg valid_s1;
    reg signed [15:0] cell_x_s1;
    reg signed [15:0] base_y_cell_s1;
    reg [6:0] local_x_s1;
    reg [6:0] base_y_local_s1;
    reg [14:0] scroll_cell_s1;
    reg [6:0] scroll_local_s1;

    always @(posedge clk) begin
        valid_s1        <= pattern_valid;
        cell_x_s1       <= $signed({12'd0, cell_x80});
        base_y_cell_s1  <= $signed({12'd0, cell_y80});
        local_x_s1      <= local_x80;
        base_y_local_s1 <= local_y80;
        scroll_cell_s1  <= scroll_cell80;
        scroll_local_s1 <= scroll_local80;
    end

    // ------------------------------------------------------------------
    // S2: apply Y scrolling only.
    // ------------------------------------------------------------------
    wire signed [15:0] shifted_y_cell_w;
    wire [6:0] shifted_y_local_w;

    grid_offset_axis #(.CELL_SIZE(80), .SUBTRACT(0)) u_scroll_y (
        .base_cell(base_y_cell_s1),
        .base_local(base_y_local_s1),
        .offset_cell(scroll_cell_s1),
        .offset_local(scroll_local_s1),
        .out_cell(shifted_y_cell_w),
        .out_local(shifted_y_local_w)
    );

    reg valid_s2;
    reg signed [15:0] cell_x_s2, cell_y_s2;
    reg [6:0] local_x_s2, local_y_s2;

    always @(posedge clk) begin
        valid_s2   <= valid_s1;
        cell_x_s2  <= cell_x_s1;
        cell_y_s2  <= shifted_y_cell_w;
        local_x_s2 <= local_x_s1;
        local_y_s2 <= shifted_y_local_w;
    end

    // ------------------------------------------------------------------
    // S3: deterministic cell style.
    // ------------------------------------------------------------------
    wire bg_comb;
    wire [2:0] color_comb;
    wire [1:0] orientation_comb, size_unused;

    pattern_cell_style #(
        .SALT(16'h4E91),
        .BG_THRESHOLD(4'd4)
    ) u_style (
        .cell_x(cell_x_s2),
        .cell_y(cell_y_s2),
        .is_background(bg_comb),
        .color_index(color_comb),
        .orientation(orientation_comb),
        .size_sel(size_unused)
    );

    reg valid_s3, bg_s3;
    reg [6:0] local_x_s3, local_y_s3;
    reg [2:0] color_s3;
    reg [1:0] orientation_s3;

    always @(posedge clk) begin
        valid_s3       <= valid_s2;
        bg_s3          <= bg_comb;
        local_x_s3     <= local_x_s2;
        local_y_s3     <= local_y_s2;
        color_s3       <= color_comb;
        orientation_s3 <= orientation_comb;
    end

    // ------------------------------------------------------------------
    // S4: triangle geometry and palette/output select.
    //
    // Geometry is intentionally kept in the final stage because it is only
    // two small subtracts, one add, and one threshold compare.
    // ------------------------------------------------------------------
    wire [6:0] rev_x_s3 = 7'd79 - local_x_s3;
    wire [6:0] rev_y_s3 = 7'd79 - local_y_s3;

    reg [7:0] axis_sum_comb;
    always @* begin
        case (orientation_s3)
            2'd0: axis_sum_comb = {1'b0, local_x_s3} + {1'b0, local_y_s3};
            2'd1: axis_sum_comb = {1'b0, rev_x_s3}   + {1'b0, local_y_s3};
            2'd2: axis_sum_comb = {1'b0, local_x_s3} + {1'b0, rev_y_s3};
            default:
                  axis_sum_comb = {1'b0, rev_x_s3}   + {1'b0, rev_y_s3};
        endcase
    end

    wire geom_hit_comb = (axis_sum_comb < 8'd80);

    wire [23:0] object_rgb;
    pattern_palette8 u_palette (
        .color_index(color_s3),
        .rgb888(object_rgb)
    );

    always @(posedge clk) begin
        if (!valid_s3)
            rgb888 <= 24'h000000;
        else if ((!bg_s3) && geom_hit_comb)
            rgb888 <= object_rgb;
        else
            rgb888 <= BG_RGB;
    end

endmodule
