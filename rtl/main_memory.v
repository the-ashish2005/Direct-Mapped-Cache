
`timescale 1ns/1ps

module main_memory (
    input  wire         clk,
    input  wire         write_enable,
    input  wire [7:0]   block_index,
    input  wire [127:0] write_data,
    output wire [127:0] read_data
);

    // Main memory: 256 blocks, 16 bytes per block
    // Total capacity = 4096 bytes (4 KB)
    reg [127:0] memory [0:255];

    // Asynchronous read operation
    assign read_data = memory[block_index];

    // Synchronous write operation
    always @(posedge clk) begin
        if (write_enable) begin
            memory[block_index] <= write_data;
        end
    end

endmodule
