`timescale 1ns / 1ps

// Platform-independent internal debug signals.
module debug_signal_gen (
    input  wire       reset_n,
    input  wire [9:0] h_count,
    input  wire [9:0] v_count,
    input  wire       de,
    output wire [3:0] debug
);

    assign debug[0] = (h_count == 10'd0) && (v_count == 10'd0);
    assign debug[1] = (h_count == 10'd0);
    assign debug[2] = de;
    assign debug[3] = reset_n;

endmodule
