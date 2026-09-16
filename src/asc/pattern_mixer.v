`timescale 1ns / 1ps

// ASC v0.41 8-pattern mixer.
// Timing contract: exactly 4 pixel-clock latency.
//
//   M1: mask + pair sums
//   M2: four-pattern group sums
//   M3: final sum + normalization, then REGISTER
//   M4: Gray subtraction / single-pattern bypass, then REGISTER
//
// The M3/M4 register boundary is deliberate: normalization and Gray
// subtraction were the tightest part of the previous STA path.
module pattern_mixer (
    input  wire        clk,
    input  wire [7:0]  pattern_mask,
    input  wire [1:0]  mix_shift,
    input  wire [23:0] pattern1_rgb888,
    input  wire [23:0] pattern2_rgb888,
    input  wire [23:0] pattern3_rgb888,
    input  wire [23:0] pattern4_rgb888,
    input  wire [23:0] pattern5_rgb888,
    input  wire [23:0] pattern6_rgb888,
    input  wire [23:0] pattern7_rgb888,
    input  wire [23:0] pattern8_rgb888,
    output reg  [23:0] mixed_rgb888
);

    wire [7:0] r0 = pattern_mask[0] ? pattern1_rgb888[23:16] : 8'd0;
    wire [7:0] r1 = pattern_mask[1] ? pattern2_rgb888[23:16] : 8'd0;
    wire [7:0] r2 = pattern_mask[2] ? pattern3_rgb888[23:16] : 8'd0;
    wire [7:0] r3 = pattern_mask[3] ? pattern4_rgb888[23:16] : 8'd0;
    wire [7:0] r4 = pattern_mask[4] ? pattern5_rgb888[23:16] : 8'd0;
    wire [7:0] r5 = pattern_mask[5] ? pattern6_rgb888[23:16] : 8'd0;
    wire [7:0] r6 = pattern_mask[6] ? pattern7_rgb888[23:16] : 8'd0;
    wire [7:0] r7 = pattern_mask[7] ? pattern8_rgb888[23:16] : 8'd0;

    wire [7:0] g0 = pattern_mask[0] ? pattern1_rgb888[15:8] : 8'd0;
    wire [7:0] g1 = pattern_mask[1] ? pattern2_rgb888[15:8] : 8'd0;
    wire [7:0] g2 = pattern_mask[2] ? pattern3_rgb888[15:8] : 8'd0;
    wire [7:0] g3 = pattern_mask[3] ? pattern4_rgb888[15:8] : 8'd0;
    wire [7:0] g4 = pattern_mask[4] ? pattern5_rgb888[15:8] : 8'd0;
    wire [7:0] g5 = pattern_mask[5] ? pattern6_rgb888[15:8] : 8'd0;
    wire [7:0] g6 = pattern_mask[6] ? pattern7_rgb888[15:8] : 8'd0;
    wire [7:0] g7 = pattern_mask[7] ? pattern8_rgb888[15:8] : 8'd0;

    wire [7:0] b0 = pattern_mask[0] ? pattern1_rgb888[7:0] : 8'd0;
    wire [7:0] b1 = pattern_mask[1] ? pattern2_rgb888[7:0] : 8'd0;
    wire [7:0] b2 = pattern_mask[2] ? pattern3_rgb888[7:0] : 8'd0;
    wire [7:0] b3 = pattern_mask[3] ? pattern4_rgb888[7:0] : 8'd0;
    wire [7:0] b4 = pattern_mask[4] ? pattern5_rgb888[7:0] : 8'd0;
    wire [7:0] b5 = pattern_mask[5] ? pattern6_rgb888[7:0] : 8'd0;
    wire [7:0] b6 = pattern_mask[6] ? pattern7_rgb888[7:0] : 8'd0;
    wire [7:0] b7 = pattern_mask[7] ? pattern8_rgb888[7:0] : 8'd0;

    // ------------------------------------------------------------------
    // M1: pair sums. Masking is absorbed into this stage.
    // ------------------------------------------------------------------
    reg [8:0] r01_s1, r23_s1, r45_s1, r67_s1;
    reg [8:0] g01_s1, g23_s1, g45_s1, g67_s1;
    reg [8:0] b01_s1, b23_s1, b45_s1, b67_s1;
    reg [1:0] mix_shift_s1;

    always @(posedge clk) begin
            r01_s1 <= {1'b0, r0} + {1'b0, r1};
            r23_s1 <= {1'b0, r2} + {1'b0, r3};
            r45_s1 <= {1'b0, r4} + {1'b0, r5};
            r67_s1 <= {1'b0, r6} + {1'b0, r7};
            g01_s1 <= {1'b0, g0} + {1'b0, g1};
            g23_s1 <= {1'b0, g2} + {1'b0, g3};
            g45_s1 <= {1'b0, g4} + {1'b0, g5};
            g67_s1 <= {1'b0, g6} + {1'b0, g7};
            b01_s1 <= {1'b0, b0} + {1'b0, b1};
            b23_s1 <= {1'b0, b2} + {1'b0, b3};
            b45_s1 <= {1'b0, b4} + {1'b0, b5};
            b67_s1 <= {1'b0, b6} + {1'b0, b7};
        mix_shift_s1 <= mix_shift;
    end

    // ------------------------------------------------------------------
    // M2: four-pattern group sums.
    // ------------------------------------------------------------------
    reg [9:0] r03_s2, r47_s2;
    reg [9:0] g03_s2, g47_s2;
    reg [9:0] b03_s2, b47_s2;
    reg [1:0] mix_shift_s2;

    always @(posedge clk) begin
            r03_s2 <= {1'b0, r01_s1} + {1'b0, r23_s1};
            r47_s2 <= {1'b0, r45_s1} + {1'b0, r67_s1};
            g03_s2 <= {1'b0, g01_s1} + {1'b0, g23_s1};
            g47_s2 <= {1'b0, g45_s1} + {1'b0, g67_s1};
            b03_s2 <= {1'b0, b01_s1} + {1'b0, b23_s1};
            b47_s2 <= {1'b0, b45_s1} + {1'b0, b67_s1};
        mix_shift_s2 <= mix_shift_s1;
    end

    // ------------------------------------------------------------------
    // M3: final sum + normalization. REGISTER normalized RGB here.
    // ------------------------------------------------------------------
    wire [10:0] r_sum_s2 = {1'b0, r03_s2} + {1'b0, r47_s2};
    wire [10:0] g_sum_s2 = {1'b0, g03_s2} + {1'b0, g47_s2};
    wire [10:0] b_sum_s2 = {1'b0, b03_s2} + {1'b0, b47_s2};

    wire [10:0] r_scaled_s2 = r_sum_s2 >> mix_shift_s2;
    wire [10:0] g_scaled_s2 = g_sum_s2 >> mix_shift_s2;
    wire [10:0] b_scaled_s2 = b_sum_s2 >> mix_shift_s2;

    reg [7:0] r_avg_s3, g_avg_s3, b_avg_s3;
    reg       multi_pattern_s3;

    always @(posedge clk) begin
            r_avg_s3 <= r_scaled_s2[7:0];
            g_avg_s3 <= g_scaled_s2[7:0];
            b_avg_s3 <= b_scaled_s2[7:0];
        multi_pattern_s3 <= (mix_shift_s2 != 2'd0);
    end

    // ------------------------------------------------------------------
    // M4: Gray subtraction. This stage starts only from normalized RGB regs.
    // ------------------------------------------------------------------
    wire [7:0] min_rg_s3 = (r_avg_s3 <= g_avg_s3) ? r_avg_s3 : g_avg_s3;
    wire [7:0] min_rgb_s3 = (min_rg_s3 <= b_avg_s3) ? min_rg_s3 : b_avg_s3;
    wire [7:0] gray_sub_s3 = min_rgb_s3 >> 1;

    wire [7:0] r_gray_s3 = r_avg_s3 - gray_sub_s3;
    wire [7:0] g_gray_s3 = g_avg_s3 - gray_sub_s3;
    wire [7:0] b_gray_s3 = b_avg_s3 - gray_sub_s3;

    always @(posedge clk) begin
        if (multi_pattern_s3) begin
            mixed_rgb888 <= {r_gray_s3, g_gray_s3, b_gray_s3};
        end else begin
            mixed_rgb888 <= {r_avg_s3, g_avg_s3, b_avg_s3};
        end
    end

endmodule
