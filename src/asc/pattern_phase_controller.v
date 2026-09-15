`timescale 1ns / 1ps

// Platform-independent common frame-phase controller.
// frame_phase advances exactly once per completed display frame.
module pattern_phase_controller (
    input  wire       clk,
    input  wire       reset_n,
    input  wire       frame_tick,
    output reg  [8:0] frame_phase
);

    // Active-low synchronous reset.
    always @(posedge clk) begin
        if (!reset_n)
            frame_phase <= 9'd0;
        else if (frame_tick)
            frame_phase <= frame_phase + 9'd1;
    end

endmodule
