`timescale 1ns / 1ps

// Pattern 5: Truchet arcs + lines on 0.25-unit logical tiles.
module pattern_truchet_lines (
    input  wire               clk,
    input  wire               logical_valid,
    input  wire signed [15:0] logical_x,
    input  wire signed [15:0] logical_y,
    input  wire [23:0]        logical_time,
    output reg  [23:0]        rgb888
);

    // S1: 0.25-unit tile split, local coordinates and motif selectors.
    wire signed [15:0] tile_x_full = $signed(logical_x) >>> 10;
    wire signed [15:0] tile_y_full = $signed(logical_y) >>> 10;
    wire [3:0] i_comb = tile_x_full[3:0];
    wire [3:0] j_comb = tile_y_full[3:0];
    wire [9:0] u_comb = logical_x[9:0];
    wire [9:0] v_comb = logical_y[9:0];
    wire [2:0] t_comb = logical_time[14:12];
    wire line_sel_comb = i_comb[0] ^ j_comb[1] ^ t_comb[0];
    wire [1:0] orient_comb = i_comb[1:0] ^ j_comb[1:0] ^ t_comb[1:0];
    wire line_vertical_comb = i_comb[1] ^ j_comb[0] ^ t_comb[1];
    wire [1:0] bg_comb = i_comb[1:0] ^ j_comb[1:0] ^ t_comb[1:0];

    reg       valid_s1;
    reg [3:0] i_s1, j_s1;
    reg [9:0] u_s1, v_s1;
    reg       line_sel_s1;
    reg [1:0] orient_s1;
    reg       line_vertical_s1;
    reg [1:0] bg_s1;
    reg [2:0] t_s1;

    always @(posedge clk) begin
        valid_s1         <= logical_valid;
        i_s1             <= i_comb;
        j_s1             <= j_comb;
        u_s1             <= u_comb;
        v_s1             <= v_comb;
        line_sel_s1      <= line_sel_comb;
        orient_s1        <= orient_comb;
        line_vertical_s1 <= line_vertical_comb;
        bg_s1            <= bg_comb;
        t_s1             <= t_comb;
    end

    // S2: local corner distances, center-line distances and palette index.
    reg [9:0] uc_comb, vc_comb;
    always @* begin
        case (orient_s1)
            2'd0: begin uc_comb = 10'd0;    vc_comb = 10'd0;    end
            2'd1: begin uc_comb = 10'd1023; vc_comb = 10'd0;    end
            2'd2: begin uc_comb = 10'd1023; vc_comb = 10'd1023; end
            default: begin uc_comb = 10'd0; vc_comb = 10'd1023; end
        endcase
    end

    wire [9:0] a_comb = (u_s1 >= uc_comb) ? (u_s1 - uc_comb) : (uc_comb - u_s1);
    wire [9:0] b_comb = (v_s1 >= vc_comb) ? (v_s1 - vc_comb) : (vc_comb - v_s1);
    wire [9:0] h_delta_comb = (v_s1 >= 10'd512) ? (v_s1 - 10'd512) : (10'd512 - v_s1);
    wire [9:0] v_delta_comb = (u_s1 >= 10'd512) ? (u_s1 - 10'd512) : (10'd512 - u_s1);

    wire [7:0] q_sum = ({4'd0, i_s1} << 1) + {4'd0, i_s1} +
                         ({4'd0, j_s1} << 2) + {4'd0, j_s1} + {5'd0, t_s1};

    reg       valid_s2;
    reg [9:0] a_s2, b_s2;
    reg [9:0] h_delta_s2, v_delta_s2;
    reg       line_sel_s2, line_vertical_s2;
    reg [2:0] q_s2;
    reg [1:0] bg_s2;

    always @(posedge clk) begin
        valid_s2         <= valid_s1;
        a_s2             <= a_comb;
        b_s2             <= b_comb;
        h_delta_s2       <= h_delta_comb;
        v_delta_s2       <= v_delta_comb;
        line_sel_s2      <= line_sel_s1;
        line_vertical_s2 <= line_vertical_s1;
        q_s2             <= q_sum[2:0];
        bg_s2            <= bg_s1;
    end

    // S3: lightweight arc approximation and line hit.
    wire [9:0] max_ab = (a_s2 >= b_s2) ? a_s2 : b_s2;
    wire [9:0] min_ab = (a_s2 >= b_s2) ? b_s2 : a_s2;
    wire [10:0] d_approx = {1'b0, max_ab} + ({1'b0, min_ab} >> 1);
    wire [10:0] arc_delta = (d_approx >= 11'd768) ?
                             (d_approx - 11'd768) : (11'd768 - d_approx);
    wire arc_hit = (arc_delta < 11'd96);
    wire line_hit = line_vertical_s2 ?
                    (v_delta_s2 < 10'd96) : (h_delta_s2 < 10'd96);

    reg       valid_s3;
    reg       hit_s3;
    reg [2:0] q_s3;
    reg [1:0] bg_s3;

    always @(posedge clk) begin
        valid_s3 <= valid_s2;
        hit_s3   <= line_sel_s2 ? line_hit : arc_hit;
        q_s3     <= q_s2;
        bg_s3    <= bg_s2;
    end

    function [23:0] vivid8;
        input [2:0] index;
        begin
            case (index)
                3'd0: vivid8 = 24'h00D9C7;
                3'd1: vivid8 = 24'h2F6BFF;
                3'd2: vivid8 = 24'h9B4DFF;
                3'd3: vivid8 = 24'hFF3D88;
                3'd4: vivid8 = 24'hFFAE2B;
                3'd5: vivid8 = 24'h42D65A;
                3'd6: vivid8 = 24'h00BDEB;
                default: vivid8 = 24'hE45CFF;
            endcase
        end
    endfunction

    function [23:0] dark4;
        input [1:0] index;
        begin
            case (index)
                2'd0: dark4 = 24'h041C24;
                2'd1: dark4 = 24'h091638;
                2'd2: dark4 = 24'h210D32;
                default: dark4 = 24'h32101E;
            endcase
        end
    endfunction

    // S4: palette.
    always @(posedge clk) begin
        if (!valid_s3)
            rgb888 <= 24'h000000;
        else if (hit_s3)
            rgb888 <= vivid8(q_s3);
        else
            rgb888 <= dark4(bg_s3);
    end

endmodule
