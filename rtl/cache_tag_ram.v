
`timescale 1ns/1ps

module cache_tag_ram (
    input wire clk,
    input wire write_enable,
    input wire [5:0] index,
    input wire [21:0] write_tag,
    output wire [21:0] read_tag
);

    reg [21:0] tag_mem [0:63];

    assign read_tag = tag_mem[index];

    always @(posedge clk) begin
        if (write_enable) begin
            tag_mem[index] <= write_tag;
        end
    end

endmodule
