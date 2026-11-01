
`timescale 1ns/1ps

module tb_cache_memory;

    reg clk;
    reg reset;

    reg [5:0] cache_index;
    reg [7:0] memory_index;

    reg [127:0] write_data;
    reg [21:0]  write_tag;
    reg         valid_in;

    reg cache_we;
    reg tag_we;
    reg valid_we;
    reg memory_we;

    wire [127:0] cache_read_data;
    wire [127:0] memory_read_data;
    wire [21:0]  read_tag;
    wire         valid_out;

    integer tests;
    integer passed;

    // Example 16-byte blocks
    localparam [127:0] BLOCK_A =
        128'h00112233445566778899AABBCCDDEEFF;

    localparam [127:0] BLOCK_B =
        128'hFFEEDDCCBBAA99887766554433221100;

    localparam [127:0] BLOCK_C =
        128'h123456789ABCDEF0123456789ABCDEF0;

    // Clock: period = 10 ns
    initial clk = 0;
    always #5 clk = ~clk;

    cache_data_ram data_ram (
        .clk(clk),
        .write_enable(cache_we),
        .index(cache_index),
        .write_data(write_data),
        .read_data(cache_read_data)
    );

    cache_tag_ram tag_ram (
        .clk(clk),
        .write_enable(tag_we),
        .index(cache_index),
        .write_tag(write_tag),
        .read_tag(read_tag)
    );

    valid_bit_ram valid_ram (
        .clk(clk),
        .reset(reset),
        .write_enable(valid_we),
        .index(cache_index),
        .valid_in(valid_in),
        .valid_out(valid_out)
    );

    main_memory backing_mem (
        .clk(clk),
        .write_enable(memory_we),
        .block_index(memory_index),
        .write_data(write_data),
        .read_data(memory_read_data)
    );

    // Writes all four components at a clock edge
    task write_block;
        input [5:0]   line;
        input [7:0]   mem_line;
        input [127:0] data;
        input [21:0]  tag_value;

        begin
            @(negedge clk);

            cache_index = line;
            memory_index = mem_line;
            write_data = data;
            write_tag = tag_value;

            cache_we = 1;
            tag_we = 1;
            valid_we = 1;
            memory_we = 1;
            valid_in = 1;

            @(posedge clk);
            #1;

            @(negedge clk);
            cache_we = 0;
            tag_we = 0;
            valid_we = 0;
            memory_we = 0;
        end
    endtask

    // Checks the cache line and backing memory
    task verify_block;
        input [5:0]   line;
        input [7:0]   mem_line;
        input [127:0] expected_data;
        input [21:0]  expected_tag;

        begin
            cache_index = line;
            memory_index = mem_line;
            #1;

            tests = tests + 1;

            if (cache_read_data === expected_data &&
                memory_read_data === expected_data &&
                read_tag === expected_tag &&
                valid_out === 1'b1) begin

                passed = passed + 1;
                $display("PASS | Line=%0d MemoryBlock=%0d",
                         line, mem_line);
            end else begin
                $display("FAIL | Line=%0d MemoryBlock=%0d",
                         line, mem_line);
                $display("Cache data: %h", cache_read_data);
                $display("Memory data: %h", memory_read_data);
                $display("Tag: %h Valid: %b",
                         read_tag, valid_out);
                $fatal(1, "Memory verification failed");
            end
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/cache_memory.vcd");
        $dumpvars(0, tb_cache_memory);

        reset = 1;
        cache_index = 0;
        memory_index = 0;
        write_data = 0;
        write_tag = 0;
        valid_in = 0;

        cache_we = 0;
        tag_we = 0;
        valid_we = 0;
        memory_we = 0;

        tests = 0;
        passed = 0;

        #2;
        reset = 0;
        #1;

        $display("=====================================");
        $display(" CACHE MEMORY VERIFICATION");
        $display("=====================================");

        // Test 1: Valid bits start cleared
        tests = tests + 1;
        if (valid_out === 1'b0) begin
            passed = passed + 1;
            $display("PASS | Initial valid bit is zero");
        end else begin
            $fatal(1, "Initial valid bit incorrect");
        end

        // Test 2: Write and read block A
        write_block(6'd0, 8'd0, BLOCK_A, 22'd0);
        verify_block(6'd0, 8'd0, BLOCK_A, 22'd0);

        // Test 3: Write and read block B
        write_block(6'd1, 8'd1, BLOCK_B, 22'd0);
        verify_block(6'd1, 8'd1, BLOCK_B, 22'd0);

        // Test 4: Line 0 still has block A
        verify_block(6'd0, 8'd0, BLOCK_A, 22'd0);

        // Test 5: Replace line 0 with block C.
        // Memory block 64 maps to cache line 0.
        write_block(6'd0, 8'd64, BLOCK_C, 22'd1);
        verify_block(6'd0, 8'd64, BLOCK_C, 22'd1);

        // Test 6: Line 1 remains unchanged
        verify_block(6'd1, 8'd1, BLOCK_B, 22'd0);

        // Test 7: Reset must invalidate line 0
        @(negedge clk);
        reset = 1;
        #1;

        cache_index = 0;
        #1;

        tests = tests + 1;
        if (valid_out === 1'b0) begin
            passed = passed + 1;
            $display("PASS | Reset invalidates cache");
        end else begin
            $fatal(1, "Reset verification failed");
        end

        reset = 0;

        $display("=====================================");
        $display("Tests executed : %0d", tests);
        $display("Tests passed   : %0d", passed);
        $display("Tests failed   : %0d", tests - passed);
        $display("=====================================");

        $finish;
    end

endmodule
