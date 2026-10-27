
`timescale 1ns/1ps

module tag_comparator (
    input  wire [21:0] requested_tag,
    input  wire [21:0] stored_tag,
    input  wire        valid,
    output wire        hit,
    output wire        miss
);

    // A hit requires a valid line and matching tags.
    assign hit = valid && (requested_tag == stored_tag);

    // Otherwise the lookup is a miss.
    assign miss = ~hit;

endmodule
