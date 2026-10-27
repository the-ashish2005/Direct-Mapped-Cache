`timescale 1ns/1ps

module address_decoder (
    input  wire [31:0] address,
    output wire [21:0] tag,
    output wire [5:0]  index,
    output wire [3:0]  offset
);

    // The upper 22 bits identify the memory block.
    assign tag = address[31:10];

    // The next 6 bits select one of 64 cache lines.
    assign index = address[9:4];

    // The lower 4 bits select a byte in the block.
    assign offset = address[3:0];

endmodule
