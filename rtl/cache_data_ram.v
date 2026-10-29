
`timescale 1ns/1ps

module cache_data_ram (
    input  wire         clk,
    input  wire         write_enable,
    input  wire [5:0]   index,
    input  wire [127:0] write_data,
    output wire [127:0] read_data
);

    // 64 cache lines, 128 bits each
    reg [127:0] data_mem [0:63];

    // Asynchronous read
    assign read_data = data_mem[index];

    // Synchronous write
    always @(posedge clk) begin
        if (write_enable) begin
            data_mem[index] <= write_data;
        end
    end

endmodule
