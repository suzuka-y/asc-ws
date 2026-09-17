`timescale 1ns / 1ps

// ASC v0.42 normalized logical display space.
// Semantic coordinates:
//   xL = (2*x + 1 - W) / H
//   yL = (2*y + 1 - H) / H
// with W=1280, H=720 and the same scale on X/Y.
//
// The pixel path uses a signed Q3.22 DDA accumulator, then truncates to
// signed Q3.12 at the registered output. No general divider is present.
// This block is intentionally reset-free datapath logic.
module display_space (
    input  wire               clk,
    input  wire [10:0]        physical_x,
    input  wire [9:0]         physical_y,
    input  wire               physical_valid,

    output reg  signed [15:0] logical_x,
    output reg  signed [15:0] logical_y,
    output reg                logical_valid
);

    // Q3.22 constants, rounded from the semantic mapping above.
    // step = 2/720 * 2^22
    localparam signed [25:0] STEP_Q22    = 26'sd11651;
    localparam signed [25:0] X_START_Q22 = -26'sd7450715;
    localparam signed [25:0] Y_START_Q22 = -26'sd4188479;

    reg signed [25:0] x_acc_q22;
    reg signed [25:0] y_line_q22;
    reg signed [25:0] y_next_q22;

    function signed [15:0] q22_to_q12;
        input signed [25:0] value;
        begin
            q22_to_q12 = value >>> 10;
        end
    endfunction

    always @(posedge clk) begin
        logical_valid <= physical_valid;

        if (physical_valid) begin
            if (physical_x == 11'd0) begin
                logical_x <= q22_to_q12(X_START_Q22);
                x_acc_q22 <= X_START_Q22 + STEP_Q22;

                if (physical_y == 10'd0) begin
                    logical_y <= q22_to_q12(Y_START_Q22);
                    y_line_q22 <= Y_START_Q22;
                    y_next_q22 <= Y_START_Q22 + STEP_Q22;
                end else begin
                    logical_y <= q22_to_q12(y_next_q22);
                    y_line_q22 <= y_next_q22;
                    y_next_q22 <= y_next_q22 + STEP_Q22;
                end
            end else begin
                logical_x <= q22_to_q12(x_acc_q22);
                logical_y <= q22_to_q12(y_line_q22);
                x_acc_q22 <= x_acc_q22 + STEP_Q22;
            end
        end
    end

endmodule
