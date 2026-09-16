`timescale 1ns / 1ps

// Pattern 1: sparse isometric cubes.
// ASC v0.41 timing contract: exactly 4 pixel-clock latency.
module pattern_isometric_cubes (
    input  wire        clk,
    input  wire        logical_valid,
    input  wire [9:0]  logical_x,
    input  wire [9:0]  logical_y,
    input  wire [8:0]  frame_phase,
    output reg  [23:0] rgb888
);

    // ------------------------------------------------------------------
    // P1-S1: vertical scroll / row parity. Preserve x and phase for S2.
    // ------------------------------------------------------------------
    wire [10:0] y_scrolled_comb = {1'b0, logical_y} +
                                   {3'b000, frame_phase[8:1]};
    wire row_parity_comb = y_scrolled_comb[7];

    reg        valid_s1;
    reg [9:0]  x_s1;
    reg [8:0]  phase_s1;
    reg [10:0] y_scrolled_s1;
    reg        row_parity_s1;

    always @(posedge clk) begin
        valid_s1       <= logical_valid;
        x_s1           <= logical_x;
        phase_s1       <= frame_phase;
        y_scrolled_s1  <= y_scrolled_comb;
        row_parity_s1  <= row_parity_comb;
    end

    // ------------------------------------------------------------------
    // P1-S2: horizontal scroll and local cell coordinates.
    // ------------------------------------------------------------------
    wire [10:0] x_scrolled_comb = {1'b0, x_s1} +
                                   {2'b00, phase_s1} +
                                   (row_parity_s1 ? 11'd128 : 11'd0);
    wire [7:0] u_comb = x_scrolled_comb[7:0];
    wire [6:0] v_comb = y_scrolled_s1[6:0];
    wire [1:0] theme_comb = {x_scrolled_comb[8], row_parity_s1};

    reg       valid_s2;
    reg [7:0] u_s2;
    reg [6:0] v_s2;
    reg [1:0] theme_s2;

    always @(posedge clk) begin
        valid_s2 <= valid_s1;
        u_s2     <= u_comb;
        v_s2     <= v_comb;
        theme_s2 <= theme_comb;
    end

    // ------------------------------------------------------------------
    // P1-S3: face metrics and mask decisions.
    // ------------------------------------------------------------------
    wire [7:0] abs_u128 = (u_s2 >= 8'd128) ?
                           (u_s2 - 8'd128) : (8'd128 - u_s2);
    wire [6:0] abs_v46  = (v_s2 >= 7'd46) ?
                           (v_s2 - 7'd46) : (7'd46 - v_s2);
    wire [8:0] top_metric = {1'b0, abs_u128} + {1'b0, abs_v46, 1'b0};
    wire mask_top_comb = (top_metric <= 9'd56);

    wire signed [9:0] left_metric =
        $signed({2'b00, v_s2, 1'b0}) - $signed({2'b00, u_s2});
    wire mask_left_comb = (u_s2 >= 8'd72) && (u_s2 <= 8'd128) &&
                          (left_metric >= 10'sd20) &&
                          (left_metric <= 10'sd108);

    wire [8:0] right_metric = {1'b0, v_s2, 1'b0} + {1'b0, u_s2};
    wire mask_right_comb = (u_s2 >= 8'd128) && (u_s2 <= 8'd184) &&
                           (right_metric >= 9'd276) &&
                           (right_metric <= 9'd364);

    reg       valid_s3;
    reg [1:0] theme_s3;
    reg       mask_top_s3;
    reg       mask_right_s3;
    reg       mask_left_s3;

    always @(posedge clk) begin
        valid_s3      <= valid_s2;
        theme_s3      <= theme_s2;
        mask_top_s3   <= mask_top_comb;
        mask_right_s3 <= mask_right_comb;
        mask_left_s3  <= mask_left_comb;
    end

    function [23:0] bg1_color;
        input [1:0] index;
        begin
            case (index)
                2'd0: bg1_color = 24'h041C24;
                2'd1: bg1_color = 24'h091638;
                2'd2: bg1_color = 24'h210D32;
                default: bg1_color = 24'h32101E;
            endcase
        end
    endfunction

    function [23:0] top_color;
        input [1:0] index;
        begin
            case (index)
                2'd0: top_color = 24'h00D9C7;
                2'd1: top_color = 24'h9B4DFF;
                2'd2: top_color = 24'hFFAE2B;
                default: top_color = 24'h00BDEB;
            endcase
        end
    endfunction

    function [23:0] left_color;
        input [1:0] index;
        begin
            case (index)
                2'd0: left_color = 24'h42D65A;
                2'd1: left_color = 24'hE45CFF;
                2'd2: left_color = 24'h2F6BFF;
                default: left_color = 24'hFF3D88;
            endcase
        end
    endfunction

    function [23:0] right_color;
        input [1:0] index;
        begin
            case (index)
                2'd0: right_color = 24'h2F6BFF;
                2'd1: right_color = 24'hFF3D88;
                2'd2: right_color = 24'h42D65A;
                default: right_color = 24'hE45CFF;
            endcase
        end
    endfunction

    // P1-S4: palette selection / output register.
    always @(posedge clk) begin
        if (!valid_s3) begin
            rgb888 <= 24'h000000;
        end else if (mask_top_s3) begin
            rgb888 <= top_color(theme_s3);
        end else if (mask_right_s3) begin
            rgb888 <= right_color(theme_s3);
        end else if (mask_left_s3) begin
            rgb888 <= left_color(theme_s3);
        end else begin
            rgb888 <= bg1_color(theme_s3);
        end
    end

endmodule
