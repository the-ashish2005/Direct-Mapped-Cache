
`timescale 1ns/1ps

module cache_top (
    input  wire        clk,
    input  wire        reset,
    input  wire        cpu_req,
    input  wire        cpu_write,
    input  wire [31:0] cpu_address,
    input  wire [31:0] cpu_write_data,

    output wire [31:0] cpu_read_data,
    output wire        cpu_ready,
    output wire        cpu_hit,
    output wire        busy
);

    // Store current CPU request
    reg [31:0] request_address;
    reg [31:0] request_write_data;
    reg        request_write;

    // Decoded address
    wire [21:0] requested_tag;
    wire [5:0]  cache_index;
    wire [3:0]  block_offset;

    // Cache memory signals
    wire [127:0] cache_block;
    wire [127:0] memory_block;
    wire [21:0]  stored_tag;

    wire valid_bit;
    wire cache_hit;
    wire cache_miss;

    // Controller signals
    wire mem_req;
    wire mem_ready;
    wire memory_write_enable;
    wire cache_write_enable;

    // Simulated main-memory latency
    reg [2:0] memory_wait_count;

    // Modified data blocks
    reg [127:0] updated_cache_block;
    reg [127:0] updated_memory_block;

    // Selected 32-bit word
    reg [31:0] selected_word;

    // Capture CPU transaction inputs
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            request_address <= 32'b0;
            request_write_data <= 32'b0;
            request_write <= 1'b0;
        end
        else if (!busy && cpu_req) begin
            request_address <= cpu_address;
            request_write_data <= cpu_write_data;
            request_write <= cpu_write;
        end
    end

    // Decode requested address
    address_decoder decoder (
        .address(request_address),
        .tag(requested_tag),
        .index(cache_index),
        .offset(block_offset)
    );

    // Cache data RAM
    cache_data_ram data_ram (
        .clk(clk),
        .write_enable(cache_write_enable),
        .index(cache_index),
        .write_data(
            request_write ?
            updated_cache_block : memory_block
        ),
        .read_data(cache_block)
    );

    // Cache tag RAM
    cache_tag_ram tag_ram (
        .clk(clk),
        .write_enable(cache_write_enable),
        .index(cache_index),
        .write_tag(requested_tag),
        .read_tag(stored_tag)
    );

    // Cache valid-bit RAM
    valid_bit_ram valid_ram (
        .clk(clk),
        .reset(reset),
        .write_enable(cache_write_enable),
        .index(cache_index),
        .valid_in(1'b1),
        .valid_out(valid_bit)
    );

    // Tag comparison
    tag_comparator comparator (
        .requested_tag(requested_tag),
        .stored_tag(stored_tag),
        .valid(valid_bit),
        .hit(cache_hit),
        .miss(cache_miss)
    );

    // Backing memory
    main_memory backing_mem (
        .clk(clk),
        .write_enable(memory_write_enable),
        .block_index(request_address[11:4]),
        .write_data(updated_memory_block),
        .read_data(memory_block)
    );

    // Simulate main-memory read latency
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
        .cpu_write(request_write),
        .cache_hit(cache_hit),
        .mem_ready(mem_ready),
        .mem_req(mem_req),
        .memory_write_enable(memory_write_enable),
        .cache_write_enable(cache_write_enable),
        .cpu_ready(cpu_ready),
        .cpu_hit(cpu_hit),
        .busy(busy)
    );

    // Update the selected 32-bit word in each block
    always @(*) begin

        updated_cache_block = cache_block;
        updated_memory_block = memory_block;

        case (block_offset[3:2])

            2'd0: begin
                updated_cache_block[31:0] =
                    request_write_data;
                updated_memory_block[31:0] =
                    request_write_data;
            end

            2'd1: begin
                updated_cache_block[63:32] =
                    request_write_data;
                updated_memory_block[63:32] =
                    request_write_data;
            end

            2'd2: begin
                updated_cache_block[95:64] =
                    request_write_data;
                updated_memory_block[95:64] =
                    request_write_data;
            end

            2'd3: begin
                updated_cache_block[127:96] =
                    request_write_data;
                updated_memory_block[127:96] =
                    request_write_data;
            end

        endcase
    end

    // Select requested 32-bit word for CPU reads
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
