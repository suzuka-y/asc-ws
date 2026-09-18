`timescale 1ns / 1ps

// P5: hollow counterpart of P1.
// The original fill region is used, then its center is replaced by background.
// Rim width: 5 physical pixels (= 1/16 of an 80-pixel cell).
// Visual scroll: down-left at 20 px/s.
//
// Pipeline (4 clocks total):
//   S1: capture raw coordinates + scroll phase
//   S2: apply X/Y scroll
//   S3: cell style
//   S4: hollow-square geometry + palette / RGB output
module pattern_square_hollow (
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
    // ------------------------------------------------------------------
    reg valid_s1;
    reg signed [15:0] base_x_cell_s1, base_y_cell_s1;
    reg [6:0] base_x_local_s1, base_y_local_s1;
    reg [14:0] scroll_cell_s1;
    reg [6:0] scroll_local_s1;

    always @(posedge clk) begin
        valid_s1        <= pattern_valid;
        base_x_cell_s1  <= $signed({12'd0, cell_x80});
        base_y_cell_s1  <= $signed({12'd0, cell_y80});
        base_x_local_s1 <= local_x80;
        base_y_local_s1 <= local_y80;
        scroll_cell_s1  <= scroll_cell80;
        scroll_local_s1 <= scroll_local80;
    end

    // ------------------------------------------------------------------
    // S2: apply X/Y scrolling.
    //
    // Visual left => sample to the right (add offset).
    // Visual down => sample upward (subtract offset).
    // ------------------------------------------------------------------
    wire signed [15:0] shifted_x_cell_w, shifted_y_cell_w;
    wire [6:0] shifted_x_local_w, shifted_y_local_w;

    grid_offset_axis #(.CELL_SIZE(80), .SUBTRACT(0)) u_scroll_x (
        .base_cell(base_x_cell_s1),
        .base_local(base_x_local_s1),
        .offset_cell(scroll_cell_s1),
        .offset_local(scroll_local_s1),
        .out_cell(shifted_x_cell_w),
        .out_local(shifted_x_local_w)
    );

    grid_offset_axis #(.CELL_SIZE(80), .SUBTRACT(1)) u_scroll_y (
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
        cell_x_s2  <= shifted_x_cell_w;
        cell_y_s2  <= shifted_y_cell_w;
        local_x_s2 <= shifted_x_local_w;
        local_y_s2 <= shifted_y_local_w;
    end

    // ------------------------------------------------------------------
    // S3: deterministic cell style.
    // ------------------------------------------------------------------
    wire bg_comb;
    wire [2:0] color_comb;
    wire [1:0] orient_unused, size_comb;

    pattern_cell_style #(
        .SALT(16'hA531),
        .BG_THRESHOLD(4'd4)
    ) u_style (
        .cell_x(cell_x_s2),
        .cell_y(cell_y_s2),
        .is_background(bg_comb),
        .color_index(color_comb),
        .orientation(orient_unused),
        .size_sel(size_comb)
    );

    reg valid_s3, bg_s3;
    reg [6:0] local_x_s3, local_y_s3;
    reg [2:0] color_s3;
    reg [1:0] size_s3;

    always @(posedge clk) begin
        valid_s3   <= valid_s2;
        bg_s3      <= bg_comb;
        local_x_s3 <= local_x_s2;
        local_y_s3 <= local_y_s2;
        color_s3   <= color_comb;
        size_s3    <= size_comb;
    end

    // ------------------------------------------------------------------
    // S4: hollow-square geometry and palette/output select.
    // ------------------------------------------------------------------
    reg outer_hit_comb, inner_hit_comb;

    always @* begin
        case (size_s3)
            2'd0: begin
                outer_hit_comb =
                    (local_x_s3 >= 7'd30) && (local_x_s3 < 7'd50) &&
                    (local_y_s3 >= 7'd30) && (local_y_s3 < 7'd50);

                inner_hit_comb =
                    (local_x_s3 >= 7'd35) && (local_x_s3 < 7'd45) &&
                    (local_y_s3 >= 7'd35) && (local_y_s3 < 7'd45);
            end

            2'd2: begin
                outer_hit_comb = 1'b1;

                inner_hit_comb =
                    (local_x_s3 >= 7'd5)  && (local_x_s3 < 7'd75) &&
                    (local_y_s3 >= 7'd5)  && (local_y_s3 < 7'd75);
            end

            default: begin
                outer_hit_comb =
                    (local_x_s3 >= 7'd20) && (local_x_s3 < 7'd60) &&
                    (local_y_s3 >= 7'd20) && (local_y_s3 < 7'd60);

                inner_hit_comb =
                    (local_x_s3 >= 7'd25) && (local_x_s3 < 7'd55) &&
                    (local_y_s3 >= 7'd25) && (local_y_s3 < 7'd55);
            end
        endcase
    end

    wire geom_hit_comb = outer_hit_comb && (!inner_hit_comb);

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
