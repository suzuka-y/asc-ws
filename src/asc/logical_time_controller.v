`timescale 1ns / 1ps

// ASC v0.42 logical time controller.
// Interface format: UQ12.12, where 4096 == 1 second.
// For the 60 Hz profile, 4096/60 = 68 + 16/60. A small remainder DDA
// alternates +68/+69 LSB per physical frame and has zero long-term drift
// over each 60-frame interval. No general divider is synthesized.
module logical_time_controller (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        frame_tick,
    output reg  [23:0] logical_time
);

    reg [5:0] remainder;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            logical_time <= 24'd0;
            remainder    <= 6'd0;
        end else if (frame_tick) begin
            if (remainder >= 6'd44) begin
                // remainder + 16 >= 60
                logical_time <= logical_time + 24'd69;
                remainder    <= remainder - 6'd44;
            end else begin
                logical_time <= logical_time + 24'd68;
                remainder    <= remainder + 6'd16;
            end
        end
    end

endmodule
