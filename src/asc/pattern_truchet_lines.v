`timescale 1ns / 1ps

// Pattern 5: 64x64 Truchet tiles mixing approximate arcs and straight lines.
// ASC v0.41 timing contract: exactly 4 pixel-clock latency.
module pattern_truchet_lines (
    input  wire        clk,
    input  wire        logical_valid,
    input  wire [9:0]  logical_x,
    input  wire [9:0]  logical_y,
    input  wire [8:0]  frame_phase,
    output reg  [23:0] rgb888
);

    // P5-S1: tile decomposition and motif selectors.
    wire [3:0] i_comb = logical_x[9:6];
    wire [3:0] j_comb = logical_y[9:6];
    wire [5:0] u_comb = logical_x[5:0];
    wire [5:0] v_comb = logical_y[5:0];
    wire [4:0] t5_comb = frame_phase[8:4];
    wire line_sel_comb = i_comb[0] ^ j_comb[1] ^ t5_comb[0];
    wire [1:0] o5_comb = i_comb[1:0] ^ j_comb[1:0] ^ t5_comb[1:0];
    wire line_vertical_comb = i_comb[1] ^ j_comb[0] ^ t5_comb[1];
    wire [1:0] b5_comb = i_comb[1:0] ^ j_comb[1:0] ^ t5_comb[1:0];

    reg       valid_s1;
    reg [3:0] i_s1, j_s1;
    reg [5:0] u_s1, v_s1;
    reg [4:0] t5_s1;
    reg       line_sel_s1;
    reg [1:0] o5_s1;
    reg       line_vertical_s1;
    reg [1:0] b5_s1;

    always @(posedge clk) begin
        valid_s1 <= logical_valid;
        i_s1 <= i_comb; j_s1 <= j_comb;
        u_s1 <= u_comb; v_s1 <= v_comb;
        t5_s1 <= t5_comb;
        line_sel_s1 <= line_sel_comb;
        o5_s1 <= o5_comb;
        line_vertical_s1 <= line_vertical_comb;
        b5_s1 <= b5_comb;
    end

    // P5-S2: local distances and palette-index arithmetic.
    reg [5:0] uc_comb;
    reg [5:0] vc_comb;
    always @* begin
        case (o5_s1)
            2'd0: begin uc_comb = 6'd0;  vc_comb = 6'd0;  end
            2'd1: begin uc_comb = 6'd63; vc_comb = 6'd0;  end
            2'd2: begin uc_comb = 6'd63; vc_comb = 6'd63; end
            default: begin uc_comb = 6'd0; vc_comb = 6'd63; end
        endcase
    end

    wire [5:0] a_comb = (u_s1 >= uc_comb) ? (u_s1 - uc_comb) : (uc_comb - u_s1);
    wire [5:0] b_comb = (v_s1 >= vc_comb) ? (v_s1 - vc_comb) : (vc_comb - v_s1);
    wire [5:0] h_delta_comb = (v_s1 >= 6'd32) ? (v_s1 - 6'd32) : (6'd32 - v_s1);
    wire [5:0] v_delta_comb = (u_s1 >= 6'd32) ? (u_s1 - 6'd32) : (6'd32 - u_s1);

    wire [7:0] i8 = {4'd0, i_s1};
    wire [7:0] j8 = {4'd0, j_s1};
    wire [7:0] t58 = {3'd0, t5_s1};
    wire [7:0] q5_sum_comb = (i8 << 1) + i8 + (j8 << 2) + j8 + t58;

    reg       valid_s2;
    reg [5:0] a_s2, b_s2;
    reg [5:0] h_delta_s2, v_delta_s2;
    reg       line_sel_s2;
    reg       line_vertical_s2;
    reg [2:0] q5_s2;
    reg [1:0] b5_s2;

    always @(posedge clk) begin
        valid_s2 <= valid_s1;
        a_s2 <= a_comb; b_s2 <= b_comb;
        h_delta_s2 <= h_delta_comb;
        v_delta_s2 <= v_delta_comb;
        line_sel_s2 <= line_sel_s1;
        line_vertical_s2 <= line_vertical_s1;
        q5_s2 <= q5_sum_comb[2:0];
        b5_s2 <= b5_s1;
    end

    // P5-S3: arc/line hit decision.
    wire [5:0] max_ab = (a_s2 >= b_s2) ? a_s2 : b_s2;
    wire [5:0] min_ab = (a_s2 >= b_s2) ? b_s2 : a_s2;
    wire [6:0] d = {1'b0, max_ab} + ({1'b0, min_ab} >> 1);
    wire [6:0] arc_delta = (d >= 7'd48) ? (d - 7'd48) : (7'd48 - d);
    wire m_arc = (arc_delta < 7'd6);
    wire m_h = (h_delta_s2 < 6'd6);
    wire m_v = (v_delta_s2 < 6'd6);
    wire m_line = line_vertical_s2 ? m_v : m_h;
    wire m5_comb = line_sel_s2 ? m_line : m_arc;

    reg       valid_s3;
    reg       m5_s3;
    reg [2:0] q5_s3;
    reg [1:0] b5_s3;

    always @(posedge clk) begin
        valid_s3 <= valid_s2;
        m5_s3 <= m5_comb;
        q5_s3 <= q5_s2;
        b5_s3 <= b5_s2;
    end

    function [23:0] vivid8_color;
        input [2:0] index;
        begin
            case (index)
                3'd0: vivid8_color = 24'h00D9C7;
                3'd1: vivid8_color = 24'h2F6BFF;
                3'd2: vivid8_color = 24'h9B4DFF;
                3'd3: vivid8_color = 24'hFF3D88;
                3'd4: vivid8_color = 24'hFFAE2B;
                3'd5: vivid8_color = 24'h42D65A;
                3'd6: vivid8_color = 24'h00BDEB;
                default: vivid8_color = 24'hE45CFF;
            endcase
        end
    endfunction

    function [23:0] bg5_color;
        input [1:0] index;
        begin
            case (index)
                2'd0: bg5_color = 24'h041C24;
                2'd1: bg5_color = 24'h091638;
                2'd2: bg5_color = 24'h210D32;
                default: bg5_color = 24'h32101E;
            endcase
        end
    endfunction

    // P5-S4: palette selection / output register.
    always @(posedge clk) begin
        if (!valid_s3)
            rgb888 <= 24'h000000;
        else if (m5_s3)
            rgb888 <= vivid8_color(q5_s3);
        else
            rgb888 <= bg5_color(b5_s3);
    end

endmodule
