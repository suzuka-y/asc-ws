`timescale 1ns / 1ps

// P7: hollow diagonal-square lattice.
// Background rate: 37.5%. Visual scroll: up-right at 20 px/s.
// In (u,v), this motion changes v by -40 units/s and leaves u unchanged.
//
// v0.43 timing split (external latency remains exactly 4 clocks):
//   S1: diagonal base-coordinate generation + scroll-offset capture
//   S2: scrolling offset application
//   S3: deterministic cell style + hollow-border hit decision
//   S4: palette lookup / RGB register
module pattern_diagonal_hollow (
    input  wire        clk,
    input  wire        pattern_valid,
    input  wire [3:0]  cell_x80,
    input  wire [6:0]  local_x80,
    input  wire [3:0]  cell_y80,
    input  wire [6:0]  local_y80,
    input  wire [14:0] scroll_cell80_medium,
    input  wire [6:0]  scroll_local80_medium,
    output reg  [23:0] rgb888
);
    localparam [23:0] BG_RGB = 24'hFFFFFF;

    // ------------------------------------------------------------------
    // S1 input combinational logic: form diagonal u/v base coordinates.
    // The expensive grid scroll is intentionally NOT in this stage.
    // ------------------------------------------------------------------
    wire [7:0] u_local_sum = {1'b0, local_x80} + {1'b0, local_y80};
    wire       u_carry = (u_local_sum >= 8'd80);
    wire [6:0] u_local_base = u_carry ?
        (u_local_sum - 8'd80) : u_local_sum[6:0];
    wire signed [15:0] u_cell_base =
        $signed({12'd0, cell_x80}) +
        $signed({12'd0, cell_y80}) +
        (u_carry ? 16'sd1 : 16'sd0);

    wire       v_borrow = (local_x80 < local_y80);
    wire [7:0] v_local_w = v_borrow ?
        ({1'b0, local_x80} + 8'd80 - {1'b0, local_y80}) :
        ({1'b0, local_x80} - {1'b0, local_y80});
    wire [6:0] v_local_base = v_local_w[6:0];
    wire signed [15:0] v_cell_base =
        $signed({12'd0, cell_x80}) -
        $signed({12'd0, cell_y80}) -
        (v_borrow ? 16'sd1 : 16'sd0);

    reg               valid_s1;
    reg signed [15:0] u_cell_s1;
    reg        [6:0]  u_local_s1;
    reg signed [15:0] v_cell_s1;
    reg        [6:0]  v_local_s1;
    reg        [14:0] scroll_cell_s1;
    reg        [6:0]  scroll_local_s1;

    always @(posedge clk) begin
        valid_s1        <= pattern_valid;
        u_cell_s1       <= u_cell_base;
        u_local_s1      <= u_local_base;
        v_cell_s1       <= v_cell_base;
        v_local_s1      <= v_local_base;
        scroll_cell_s1  <= scroll_cell80_medium;
        scroll_local_s1 <= scroll_local80_medium;
    end

    // ------------------------------------------------------------------
    // S2: apply v-axis scroll using only registered S1 values.
    // This is the register boundary added specifically to break the
    // max_ss_125C_4v50 critical path seen in the first v0.43 hardening.
    // ------------------------------------------------------------------
    wire signed [15:0] v_cell_shifted_s1;
    wire        [6:0]  v_local_shifted_s1;

    grid_offset_axis #(.CELL_SIZE(80), .SUBTRACT(1)) u_scroll_v (
        .base_cell   (v_cell_s1),
        .base_local  (v_local_s1),
        .offset_cell (scroll_cell_s1),
        .offset_local(scroll_local_s1),
        .out_cell    (v_cell_shifted_s1),
        .out_local   (v_local_shifted_s1)
    );

    reg               valid_s2;
    reg signed [15:0] u_cell_s2;
    reg signed [15:0] v_cell_s2;
    reg        [6:0]  u_local_s2;
    reg        [6:0]  v_local_s2;

    always @(posedge clk) begin
        valid_s2   <= valid_s1;
        u_cell_s2  <= u_cell_s1;
        v_cell_s2  <= v_cell_shifted_s1;
        u_local_s2 <= u_local_s1;
        v_local_s2 <= v_local_shifted_s1;
    end

    // ------------------------------------------------------------------
    // S3: style lookup and hollow-border decision.
    // The local-coordinate comparisons are shallow and share this stage
    // with style generation so the external pattern latency stays 4 clocks.
    // ------------------------------------------------------------------
    wire       bg_comb;
    wire [2:0] color_comb;
    wire [1:0] orient_unused, size_unused;

    pattern_cell_style #(.SALT(16'hC539), .BG_THRESHOLD(4'd6)) u_style (
        .cell_x        (u_cell_s2),
        .cell_y        (v_cell_s2),
        .is_background (bg_comb),
        .color_index   (color_comb),
        .orientation   (orient_unused),
        .size_sel      (size_unused)
    );

    wire inner_hit_comb =
        (u_local_s2 >= 7'd5)  && (u_local_s2 < 7'd75) &&
        (v_local_s2 >= 7'd5)  && (v_local_s2 < 7'd75);

    reg       valid_s3;
    reg       hit_s3;
    reg [2:0] color_s3;

    always @(posedge clk) begin
        valid_s3 <= valid_s2;
        hit_s3   <= (!bg_comb) && (!inner_hit_comb);
        color_s3 <= color_comb;
    end

    // ------------------------------------------------------------------
    // S4: palette lookup / registered RGB output.
    // ------------------------------------------------------------------
    wire [23:0] object_rgb;
    pattern_palette8 u_palette (
        .color_index(color_s3),
        .rgb888     (object_rgb)
    );

    always @(posedge clk) begin
        if (!valid_s3)      rgb888 <= 24'h000000;
        else if (hit_s3)    rgb888 <= object_rgb;
        else                rgb888 <= BG_RGB;
    end

endmodule
