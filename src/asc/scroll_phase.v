`timescale 1ns / 1ps

// Exact frame-rate DDA for physical-pixel scroll offsets.
//
// SPEED_PPS is pixels/second and the video profile is fixed at 60 frames/s.
// CELL_SIZE is either 80 (normal cell) or 40 (brick row).
// The state is kept as cell_offset + local_offset, so no runtime division or
// modulo operation is required.
module scroll_phase #(
    parameter integer CELL_SIZE = 80,
    parameter integer SPEED_PPS = 20
) (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        frame_tick,
    output reg  [14:0] cell_offset,
    output reg  [6:0]  local_offset
);

    reg [6:0] frame_remainder;

    wire [7:0] remainder_sum = frame_remainder + SPEED_PPS;
    wire [1:0] pixel_inc = (remainder_sum >= 8'd120) ? 2'd2 :
                           (remainder_sum >= 8'd60)  ? 2'd1 : 2'd0;
    wire [6:0] remainder_next = (remainder_sum >= 8'd120) ? remainder_sum - 8'd120 :
                                (remainder_sum >= 8'd60)  ? remainder_sum - 8'd60  :
                                                                    remainder_sum[6:0];

    wire [8:0] local_sum = {2'b00, local_offset} + pixel_inc;
    wire       cell_carry = (local_sum >= CELL_SIZE);
    wire [8:0] local_next_wide = cell_carry ? (local_sum - CELL_SIZE) : local_sum;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            frame_remainder <= 7'd0;
            cell_offset     <= 15'd0;
            local_offset    <= 7'd0;
        end else if (frame_tick) begin
            frame_remainder <= remainder_next;
            local_offset    <= local_next_wide[6:0];
            if (cell_carry)
                cell_offset <= cell_offset + 15'd1;
        end
    end

endmodule
