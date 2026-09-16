`timescale 1ns / 1ps

// ASC v0.41 reset synchronizer.
// External reset is asserted asynchronously and released synchronously.
// rst_n_raw must not be distributed beyond this boundary.
module reset_synchronizer (
    input  wire clk,
    input  wire rst_n_raw,
    output wire core_rst_n
);

    reg [1:0] reset_sync;

    always @(posedge clk or negedge rst_n_raw) begin
        if (!rst_n_raw)
            reset_sync <= 2'b00;
        else
            reset_sync <= {reset_sync[0], 1'b1};
    end

    assign core_rst_n = reset_sync[1];

endmodule
