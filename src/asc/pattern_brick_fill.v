`timescale 1ns / 1ps

// P2: sparse filled brick lattice.
// Brick size: 80x40 physical pixels. Odd rows are shifted by 40 pixels.
// Background rate: 6/16 = 37.5%. Visual scroll: down-right at 20 px/s.
//
// Pipeline (4 clocks total):
//   S1: scroll X/Y
//   S2: brick stagger / column generation
//   S3: cell style
//   S4: palette / background select
module pattern_brick_fill (
    input  wire        clk,
    input  wire        pattern_valid,
    input  wire [3:0]  cell_x80,
    input  wire [6:0]  local_x80,
    input  wire [4:0]  row_y40,
    input  wire [5:0]  local_y40,
    input  wire [14:0] scroll_cell80,
    input  wire [6:0]  scroll_local80,
    input  wire [14:0] scroll_row40,
    input  wire [6:0]  scroll_local40,
    output reg  [23:0] rgb888
);
    localparam [23:0] BG_RGB = 24'hFFFFFF;

    // ------------------------------------------------------------------
    // S1: apply X/Y scrolling only.
    // This register boundary removes the former long path:
    // grid_offset_axis -> row/stagger logic -> brick_col -> FF.
    // ------------------------------------------------------------------
    wire signed [15:0] base_x_cell = $signed({12'd0, cell_x80});
    wire signed [15:0] base_y_row  = $signed({11'd0, row_y40});

    wire signed [15:0] sx_cell_w, sy_row_w;
    wire [6:0] sx_local_w, sy_local_unused;

    grid_offset_axis #(.CELL_SIZE(80), .SUBTRACT(1)) u_scroll_x (
        .base_cell(base_x_cell),
        .base_local(local_x80),
        .offset_cell(scroll_cell80),
        .offset_local(scroll_local80),
        .out_cell(sx_cell_w),
        .out_local(sx_local_w)
    );

    grid_offset_axis #(.CELL_SIZE(40), .SUBTRACT(1)) u_scroll_y (
        .base_cell(base_y_row),
        .base_local({1'b0, local_y40}),
        .offset_cell(scroll_row40),
        .offset_local(scroll_local40),
        .out_cell(sy_row_w),
        .out_local(sy_local_unused)
    );

    reg valid_s1;
    reg signed [15:0] sx_cell_s1;
    reg signed [15:0] row_s1;
    reg [6:0] sx_local_s1;

    always @(posedge clk) begin
        valid_s1    <= pattern_valid;
        sx_cell_s1  <= sx_cell_w;
        row_s1      <= sy_row_w;
        sx_local_s1 <= sx_local_w;
    end

    // ------------------------------------------------------------------
    // S2: apply odd-row half-brick staggering.
    // ------------------------------------------------------------------
    wire row_odd_s1 = row_s1[0];
    wire stagger_borrow_s1 = row_odd_s1 && (sx_local_s1 < 7'd40);

    wire signed [15:0] brick_col_s1 =
        row_odd_s1
            ? (stagger_borrow_s1 ? (sx_cell_s1 - 16'sd1) : sx_cell_s1)
            : sx_cell_s1;

    reg valid_s2;
    reg signed [15:0] col_s2;
    reg signed [15:0] row_s2;

    always @(posedge clk) begin
        valid_s2 <= valid_s1;
        col_s2   <= brick_col_s1;
        row_s2   <= row_s1;
    end

    // ------------------------------------------------------------------
    // S3: derive deterministic cell style.
    // ------------------------------------------------------------------
    wire bg_comb;
    wire [2:0] color_comb;
    wire [1:0] orient_unused, size_unused;

    pattern_cell_style #(
        .SALT(16'h246B),
        .BG_THRESHOLD(4'd6)
    ) u_style (
        .cell_x(col_s2),
        .cell_y(row_s2),
        .is_background(bg_comb),
        .color_index(color_comb),
        .orientation(orient_unused),
        .size_sel(size_unused)
    );

    reg valid_s3;
    reg bg_s3;
    reg [2:0] color_s3;

    always @(posedge clk) begin
        valid_s3 <= valid_s2;
        bg_s3    <= bg_comb;
        color_s3 <= color_comb;
    end

    // ------------------------------------------------------------------
    // S4: palette lookup and final background/object select.
    // ------------------------------------------------------------------
    wire [23:0] object_rgb;
    pattern_palette8 u_palette (
        .color_index(color_s3),
        .rgb888(object_rgb)
    );

    always @(posedge clk) begin
        if (!valid_s3)
            rgb888 <= 24'h000000;
        else if (!bg_s3)
            rgb888 <= object_rgb;
        else
            rgb888 <= BG_RGB;
    end

endmodule
