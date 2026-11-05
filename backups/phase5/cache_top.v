
`timescale 1ns/1ps

module cache_top (
    input  wire        clk,
    input  wire        reset,

    // CPU read interface
    input  wire        cpu_req,
    input  wire [31:0] cpu_address,

    output wire [31:0] cpu_read_data,
    output wire        cpu_ready,
    output wire        cpu_hit,
    output wire        busy
);

    // Store the address for the current transaction
    reg [31:0] request_address;

    // Address decoder signals
    wire [21:0] requested_tag;
    wire [5:0]  cache_index;
    wire [3:0]  block_offset;

    // Cache data and metadata
    wire [127:0] cache_block;
    wire [21:0]  stored_tag;
    wire         valid_bit;
    wire         cache_hit;
    wire         cache_miss;

    // Backing memory
    wire [127:0] memory_block;
    wire         mem_req;
    wire         mem_ready;

    // Controller signals
    wire cache_write_enable;

    // Simulated memory latency
    reg [2:0] memory_wait_count;

    // Capture request address while idle
    always @(posedge clk or posedge reset) begin
        if (reset)
            request_address <= 32'b0;
        else if (!busy && cpu_req)
            request_address <= cpu_address;
    end

    // Decode latched address
    address_decoder decoder (
        .address(request_address),
        .tag(requested_tag),
        .index(cache_index),
        .offset(block_offset)
    );

    // Cache data storage
    cache_data_ram data_ram (
        .clk(clk),
        .write_enable(cache_write_enable),
        .index(cache_index),
        .write_data(memory_block),
        .read_data(cache_block)
    );

    // Cache tag storage
    cache_tag_ram tag_ram (
        .clk(clk),
        .write_enable(cache_write_enable),
        .index(cache_index),
        .write_tag(requested_tag),
        .read_tag(stored_tag)
    );

    // Cache valid bits
    valid_bit_ram valid_ram (
        .clk(clk),
        .reset(reset),
        .write_enable(cache_write_enable),
        .index(cache_index),
        .valid_in(1'b1),
        .valid_out(valid_bit)
    );

    // Compare requested and stored tags
    tag_comparator comparator (
        .requested_tag(requested_tag),
        .stored_tag(stored_tag),
        .valid(valid_bit),
        .hit(cache_hit),
        .miss(cache_miss)
    );

    // 4 KB backing memory: 256 blocks
    // Each block contains 16 bytes
    main_memory backing_mem (
        .clk(clk),
        .write_enable(1'b0),
        .block_index(request_address[11:4]),
        .write_data(128'b0),
        .read_data(memory_block)
    );

    // Memory latency model:
    // mem_ready goes high after 3 waiting cycles.
    always @(posedge clk or posedge reset) begin
        if (reset)
            memory_wait_count <= 3'd0;
        else if (!mem_req)
            memory_wait_count <= 3'd0;
        else if (memory_wait_count < 3'd3)
            memory_wait_count <= memory_wait_count + 1'b1;
    end

    assign mem_ready =
        (memory_wait_count == 3'd3);

    // Cache controller FSM
    cache_controller controller (
        .clk(clk),
        .reset(reset),
        .cpu_req(cpu_req),
        .cache_hit(cache_hit),
        .mem_ready(mem_ready),
        .mem_req(mem_req),
        .cache_write_enable(cache_write_enable),
        .cpu_ready(cpu_ready),
        .cpu_hit(cpu_hit),
        .busy(busy)
    );

    // Select one 32-bit word from the 128-bit block.
    // Our first version uses aligned 32-bit addresses.
    reg [31:0] selected_word;

    always @(*) begin
        case (block_offset[3:2])
            2'd0: selected_word = cache_block[31:0];
            2'd1: selected_word = cache_block[63:32];
            2'd2: selected_word = cache_block[95:64];
            2'd3: selected_word = cache_block[127:96];
            default: selected_word = 32'b0;
        endcase
    end

    assign cpu_read_data = selected_word;

endmodule
