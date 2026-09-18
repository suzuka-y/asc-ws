`timescale 1ns / 1ps

// ASC v0.43 palette: index 0 is background white; 1..7 are pastel colors.
module pattern_palette8 (
    input  wire [2:0]  color_index,
    output reg  [23:0] rgb888
);
    always @* begin
        case (color_index)
            3'd0: rgb888 = 24'hFFFFFF; // background
            3'd1: rgb888 = 24'hF4B7BE; // pastel rose
            3'd2: rgb888 = 24'hF7CF94; // pastel apricot
            3'd3: rgb888 = 24'hF4E89D; // pastel yellow
            3'd4: rgb888 = 24'hB5DEBE; // pastel green
            3'd5: rgb888 = 24'hA8D8E4; // pastel cyan
            3'd6: rgb888 = 24'hB3C4E8; // pastel blue
            default: rgb888 = 24'hD0B9E2; // pastel lavender
        endcase
    end
endmodule
