
`timescale 1ns/1ps

module tb_cache_top;

    reg clk;
    reg reset;
    reg cpu_req;
    reg [31:0] cpu_address;

    wire [31:0] cpu_read_data;
    wire cpu_ready;
    wire cpu_hit;
    wire busy;

    integer tests;
    integer passed;

    // Test data: 16 bytes per memory block
    localparam [127:0] BLOCK_A =
        128'h00000004_00000003_00000002_00000001;

    localparam [127:0] BLOCK_B =
        128'h00000040_00000030_00000020_00000010;

    localparam [127:0] BLOCK_C =
        128'h00000404_00000403_00000402_00000401;

    // Device Under Test
    cache_top dut (
        .clk(clk),
        .reset(reset),
        .cpu_req(cpu_req),
        .cpu_address(cpu_address),
        .cpu_read_data(cpu_read_data),
        .cpu_ready(cpu_ready),
        .cpu_hit(cpu_hit),
        .busy(busy)
    );

    // Generate clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Task to send CPU read requests
    task check_read;
        input [31:0] address;
        input [31:0] expected_data;
        input expected_hit;

        integer cycles;

        begin
            // Wait until controller is idle
            while (busy !== 1'b0)
                @(negedge clk);

            // Apply request
            @(negedge clk);
            cpu_address = address;
            cpu_req = 1'b1;

            // Request accepted on rising edge
            @(negedge clk);
            cpu_req = 1'b0;

            cycles = 0;

            // Wait for CPU response
            while (cpu_ready !== 1'b1 && cycles < 20) begin
                @(negedge clk);
                #1;
                cycles = cycles + 1;
            end

            tests = tests + 1;

            // Verify output
            if (cpu_ready === 1'b1 &&
                cpu_read_data === expected_data &&
                cpu_hit === expected_hit) begin

                passed = passed + 1;

                $display(
                    "PASS | Address=%h Data=%h Hit=%b Cycles=%0d",
                    address,
                    cpu_read_data,
                    cpu_hit,
                    cycles
                );

            end else begin

                $display(
                    "FAIL | Address=%h Expected=%h Actual=%h",
                    address,
                    expected_data,
                    cpu_read_data
                );

                $display(
                    "Expected Hit=%b Actual Hit=%b Ready=%b",
                    expected_hit,
                    cpu_hit,
                    cpu_ready
                );

                $fatal(1, "Cache integration test failed");
            end

            // Allow controller to finish response
            @(negedge clk);
        end
    endtask

    initial begin

        // Generate waveform file
        $dumpfile("results/waveforms/cache_top.vcd");
        $dumpvars(0, tb_cache_top);

        reset = 1'b1;
        cpu_req = 1'b0;
        cpu_address = 32'b0;

        tests = 0;
        passed = 0;

        // Initialize backing memory
        // Hierarchical initialization is testbench-only
        dut.backing_mem.memory[0]  = BLOCK_A;
        dut.backing_mem.memory[1]  = BLOCK_B;
        dut.backing_mem.memory[64] = BLOCK_C;

        // Release reset
        #12;
        reset = 1'b0;

        $display("========================================");
        $display(" DIRECT-MAPPED CACHE INTEGRATION TEST");
        $display("========================================");

        // Test 1: First access -> MISS
        check_read(
            32'h00000000,
            32'h00000001,
            1'b0
        );

        // Test 2: Repeated access -> HIT
        check_read(
            32'h00000000,
            32'h00000001,
            1'b1
        );

        // Test 3: Same block, different word -> HIT
        check_read(
            32'h00000004,
            32'h00000002,
            1'b1
        );

        // Test 4: Conflicting block -> MISS
        check_read(
            32'h00000400,
            32'h00000401,
            1'b0
        );

        // Test 5: Original block was evicted -> MISS
        check_read(
            32'h00000000,
            32'h00000001,
            1'b0
        );

        // Test 6: Access another cache line -> MISS
        check_read(
            32'h00000010,
            32'h00000010,
            1'b0
        );

        // Test 7: Repeated access -> HIT
        check_read(
            32'h00000010,
            32'h00000010,
            1'b1
        );

        // Final verification summary
        $display("========================================");
        $display("Tests executed : %0d", tests);
        $display("Tests passed   : %0d", passed);
        $display("Tests failed   : %0d", tests - passed);
        $display("========================================");

        $finish;
    end

endmodule
