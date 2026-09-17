`timescale 1ns / 1ps

// Pattern 1: sparse isometric cubes in normalized logical space.
// Four-clock latency, one sample/clock. No physical-resolution dependency.
module pattern_isometric_cubes (
    input  wire               clk,
    input  wire               logical_valid,
    input  wire signed [15:0] logical_x,
    input  wire signed [15:0] logical_y,
    input  wire [23:0]        logical_time,
    output reg  [23:0]        rgb888
);

    // S1: diagonal logical scroll and row parity.
    // low 14 time bits = modulo 4 seconds; >>3 gives 0..0.5 logical unit.
    wire [10:0] scroll_comb = logical_time[13:3];
    wire signed [16:0] scroll_ext = $signed({6'd0, scroll_comb});
    wire signed [16:0] y_scrolled_comb = $signed(logical_y) + scroll_ext;
    wire signed [16:0] row_index_comb = y_scrolled_comb >>> 10; // 0.25-unit rows

    reg               valid_s1;
    reg signed [15:0] x_s1;
    reg [10:0]        scroll_s1;
    reg signed [16:0] y_scrolled_s1;
    reg               row_parity_s1;

    always @(posedge clk) begin
        valid_s1      <= logical_valid;
        x_s1          <= logical_x;
        scroll_s1     <= scroll_comb;
        y_scrolled_s1 <= y_scrolled_comb;
        row_parity_s1 <= row_index_comb[0];
    end

    // S2: staggered 0.5 x 0.25 logical-unit cell decomposition.
    wire signed [16:0] x_scroll_s2_comb =
        $signed(x_s1) + $signed({6'd0, scroll_s1}) +
        (row_parity_s1 ? 17'sd1024 : 17'sd0);

    wire [10:0] u_comb = x_scroll_s2_comb[10:0]; // modulo 2048
    wire [9:0]  v_comb = y_scrolled_s1[9:0];     // modulo 1024
    wire [1:0]  theme_comb = {x_scroll_s2_comb[11], row_parity_s1};

    reg       valid_s2;
    reg [10:0] u_s2;
    reg [9:0]  v_s2;
    reg [1:0]  theme_s2;

    always @(posedge clk) begin
        valid_s2 <= valid_s1;
        u_s2     <= u_comb;
        v_s2     <= v_comb;
        theme_s2 <= theme_comb;
    end

    // S3: scaled version of the v0.4 three-face lightweight metrics.
    wire [10:0] abs_u_mid = (u_s2 >= 11'd1024) ?
                             (u_s2 - 11'd1024) : (11'd1024 - u_s2);
    wire [9:0] abs_v_top = (v_s2 >= 10'd368) ?
                            (v_s2 - 10'd368) : (10'd368 - v_s2);
    wire [11:0] top_metric = {1'b0, abs_u_mid} + {1'b0, abs_v_top, 1'b0};
    wire mask_top_comb = (top_metric <= 12'd448);

    wire signed [12:0] left_metric =
        $signed({2'b00, v_s2, 1'b0}) - $signed({2'b00, u_s2});
    wire mask_left_comb = (u_s2 >= 11'd576) && (u_s2 <= 11'd1024) &&
                          (left_metric >= 13'sd160) &&
                          (left_metric <= 13'sd864);

    wire [11:0] right_metric = {1'b0, v_s2, 1'b0} + {1'b0, u_s2};
    wire mask_right_comb = (u_s2 >= 11'd1024) && (u_s2 <= 11'd1472) &&
                           (right_metric >= 12'd2208) &&
                           (right_metric <= 12'd2912);

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

    function [23:0] bg_color;
        input [1:0] index;
        begin
            case (index)
                2'd0: bg_color = 24'h041C24;
                2'd1: bg_color = 24'h091638;
                2'd2: bg_color = 24'h210D32;
                default: bg_color = 24'h32101E;
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

    // S4: palette selection.
    always @(posedge clk) begin
        if (!valid_s3)
            rgb888 <= 24'h000000;
        else if (mask_top_s3)
            rgb888 <= top_color(theme_s3);
        else if (mask_right_s3)
            rgb888 <= right_color(theme_s3);
        else if (mask_left_s3)
            rgb888 <= left_color(theme_s3);
        else
            rgb888 <= bg_color(theme_s3);
    end

endmodule
