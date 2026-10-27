
`timescale 1ns/1ps

module valid_bit_ram (
    input  wire       clk,
    input  wire       reset,
    input  wire       write_enable,
    input  wire [5:0] index,
    input  wire       valid_in,
    output wire       valid_out
);

    reg [63:0] valid_bits;

    integer i;

    // Read the valid bit for the selected line
    assign valid_out = valid_bits[index];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            valid_bits <= 64'b0;
        end else if (write_enable) begin
            valid_bits[index] <= valid_in;
        end
    end

endmodule
