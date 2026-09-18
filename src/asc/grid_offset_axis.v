`timescale 1ns / 1ps

// Add or subtract a positive scrolling offset from one grid axis.
// Both the base coordinate and the offset are represented as
//     cell * CELL_SIZE + local
// so this block needs only add/subtract/compare; no divider/modulo.
//
// Timing-oriented implementation:
//   - local carry/borrow is computed independently.
//   - the two possible 16-bit cell results are computed in parallel.
//   - carry/borrow selects between those already-computed candidates.
//   - keep attributes preserve the candidate nets so synthesis is less
//     likely to re-collapse the comparator and cell arithmetic into one cone.
//
// Function and combinational latency are unchanged.
module grid_offset_axis #(
    parameter integer CELL_SIZE = 80,
    parameter integer SUBTRACT  = 0
) (
    input  wire signed [15:0] base_cell,
    input  wire        [6:0]  base_local,
    input  wire        [14:0] offset_cell,
    input  wire        [6:0]  offset_local,
    output wire signed [15:0] out_cell,
    output wire        [6:0]  out_local
);

    wire signed [15:0] offset_cell_s = $signed({1'b0, offset_cell});

    generate
        if (SUBTRACT == 0) begin : g_add
            // Local-coordinate path.
            wire [8:0] local_sum =
                {2'b00, base_local} + {2'b00, offset_local};

            (* keep = "true" *)
            wire carry = (local_sum >= CELL_SIZE);

            wire [8:0] local_adj =
                carry ? (local_sum - CELL_SIZE) : local_sum;

            // Cell-coordinate path.
            //
            // Compute both candidates independently and preserve them through
            // synthesis.  The local-coordinate carry only selects the already
            // computed result at the final mux.
            (* keep = "true" *)
            wire signed [15:0] cell_no_carry =
                base_cell + offset_cell_s;

            (* keep = "true" *)
            wire signed [15:0] cell_with_carry =
                base_cell + offset_cell_s + 16'sd1;

            assign out_local = local_adj[6:0];
            assign out_cell  = carry ? cell_with_carry : cell_no_carry;

        end else begin : g_sub
            // Local-coordinate path.
            (* keep = "true" *)
            wire borrow = (base_local < offset_local);

            wire [8:0] local_no_borrow =
                {2'b00, base_local} - {2'b00, offset_local};

            wire [8:0] local_with_borrow =
                {2'b00, base_local} + CELL_SIZE -
                {2'b00, offset_local};

            // Cell-coordinate path.
            //
            // Preserve both arithmetic candidates.  The borrow comparator is
            // therefore intended to terminate only in the final select mux,
            // rather than being absorbed back into the 16-bit arithmetic cone.
            (* keep = "true" *)
            wire signed [15:0] cell_no_borrow =
                base_cell - offset_cell_s;

            (* keep = "true" *)
            wire signed [15:0] cell_with_borrow =
                base_cell - offset_cell_s - 16'sd1;

            assign out_local =
                borrow ? local_with_borrow[6:0] : local_no_borrow[6:0];

            assign out_cell =
                borrow ? cell_with_borrow : cell_no_borrow;
        end
    endgenerate

endmodule
