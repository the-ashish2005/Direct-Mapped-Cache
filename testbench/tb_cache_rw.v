
`timescale 1ns/1ps

module tb_cache_rw;

    reg clk;
    reg reset;
    reg cpu_req;
    reg cpu_write;
    reg [31:0] cpu_address;
    reg [31:0] cpu_write_data;

    wire [31:0] cpu_read_data;
    wire cpu_ready;
    wire cpu_hit;
    wire busy;

    integer tests;
    integer passed;

    // Test memory blocks
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
        .cpu_write(cpu_write),
        .cpu_address(cpu_address),
        .cpu_write_data(cpu_write_data),
        .cpu_read_data(cpu_read_data),
        .cpu_ready(cpu_ready),
        .cpu_hit(cpu_hit),
        .busy(busy)
    );

    // 10 ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Send one CPU transaction and check the response
    task check_transaction;
        input        is_write;
        input [31:0] address;
        input [31:0] write_value;
        input [31:0] expected_read;
        input        expected_hit;

        integer cycles;

        begin
            // Wait until the previous request has finished
            while (busy !== 1'b0)
                @(negedge clk);

            @(negedge clk);
            cpu_req = 1'b1;
            cpu_write = is_write;
            cpu_address = address;
            cpu_write_data = write_value;

            // Request accepted at rising edge
            @(negedge clk);
            cpu_req = 1'b0;

            cycles = 0;

            // Wait for response with timeout
            while (cpu_ready !== 1'b1 && cycles < 20) begin
                @(negedge clk);
                #1;
                cycles = cycles + 1;
            end

            tests = tests + 1;

            if (cpu_ready !== 1'b1 ||
                cpu_hit !== expected_hit) begin

                $fatal(1,
                    "Response failure: addr=%h hit=%b expected=%b",
                    address, cpu_hit, expected_hit);
            end

            if (!is_write &&
                cpu_read_data !== expected_read) begin

                $fatal(1,
                    "Data failure: addr=%h got=%h expected=%h",
                    address, cpu_read_data, expected_read);
            end

            passed = passed + 1;

            $display(
                "PASS | %s Addr=%h Hit=%b Cycles=%0d",
                is_write ? "WRITE" : "READ ",
                address,
                cpu_hit,
                cycles
            );

            // Wait until response phase is finished
            @(negedge clk);
            while (busy !== 1'b0)
                @(negedge clk);
        end
    endtask

    initial begin

        $dumpfile("results/waveforms/cache_rw.vcd");
        $dumpvars(0, tb_cache_rw);

        reset = 1'b1;
        cpu_req = 1'b0;
        cpu_write = 1'b0;
        cpu_address = 32'b0;
        cpu_write_data = 32'b0;

        tests = 0;
        passed = 0;

        // Initialize backing memory for simulation
        dut.backing_mem.memory[0]  = BLOCK_A;
        dut.backing_mem.memory[1]  = BLOCK_B;
        dut.backing_mem.memory[64] = BLOCK_C;

        #12;
        reset = 1'b0;

        $display("=====================================");
        $display(" CACHE READ/WRITE VERIFICATION");
        $display("=====================================");

        // =====================================
        // PHASE 6: BASIC VERIFICATION
        // =====================================

        // Test 1: Initial read -> MISS
        check_transaction(
            0, 32'h00000000,
            0, 32'h00000001, 0
        );

        // Test 2: Write hit
        check_transaction(
            1, 32'h00000004,
            32'hDEADBEEF, 0, 1
        );

        // Test 3: Read modified word -> HIT
        check_transaction(
            0, 32'h00000004,
            0, 32'hDEADBEEF, 1
        );

        // Test 4: Unmodified word remains correct
        check_transaction(
            0, 32'h00000000,
            0, 32'h00000001, 1
        );

        // Test 5: Write miss -> No write allocation
        check_transaction(
            1, 32'h00000010,
            32'hCAFEBABE, 0, 0
        );

        // Test 6: Read after write miss -> MISS
        check_transaction(
            0, 32'h00000010,
            0, 32'hCAFEBABE, 0
        );

        // Test 7: Repeated read -> HIT
        check_transaction(
            0, 32'h00000010,
            0, 32'hCAFEBABE, 1
        );

        // Test 8: Write miss to conflicting block
        check_transaction(
            1, 32'h00000400,
            32'h12345678, 0, 0
        );

        // Test 9: Original cache line remains valid
        check_transaction(
            0, 32'h00000000,
            0, 32'h00000001, 1
        );

        // Test 10: Read conflicting block -> MISS
        check_transaction(
            0, 32'h00000400,
            0, 32'h12345678, 0
        );

        // Test 11: Original block was evicted -> MISS
        check_transaction(
            0, 32'h00000000,
            0, 32'h00000001, 0
        );

        // =====================================
        // PHASE 7: EXTENDED VERIFICATION
        // =====================================

        $display("=====================================");
        $display(" PHASE 7: EXTENDED VERIFICATION");
        $display("=====================================");

        // Test 12: Verify write-through consistency
        tests = tests + 1;

        if (dut.backing_mem.memory[0][63:32]
            === 32'hDEADBEEF) begin

            passed = passed + 1;
            $display("PASS | Write-through memory consistency");

        end else begin
            $fatal(1, "Write-through memory mismatch");
        end

        // Test 13: Cache and memory must agree
        tests = tests + 1;

        if (dut.data_ram.data_mem[0][63:32]
            === dut.backing_mem.memory[0][63:32]) begin

            passed = passed + 1;
            $display("PASS | Cache and memory agree");

        end else begin
            $fatal(1, "Cache/memory inconsistency");
        end

        // Test 14: Write miss updated main memory
        tests = tests + 1;

        if (dut.backing_mem.memory[1][31:0]
            === 32'hCAFEBABE) begin

            passed = passed + 1;
            $display("PASS | Write miss updated memory");

        end else begin
            $fatal(1, "Write miss memory mismatch");
        end

        // Test 15: Conflicting block value preserved
        tests = tests + 1;

        if (dut.backing_mem.memory[64][31:0]
            === 32'h12345678) begin

            passed = passed + 1;
            $display("PASS | Conflicting block preserved");

        end else begin
            $fatal(1, "Conflicting memory mismatch");
        end

        // Test 16: Last aligned word in 4 KB memory
        dut.backing_mem.memory[255] =
            128'hAABBCCDD_00000003_00000002_00000001;

        check_transaction(
            0, 32'h00000FFC,
            0, 32'hAABBCCDD, 0
        );

        // Test 17: Reset invalidates cache
        @(negedge clk);
        reset = 1'b1;
        #1;

        tests = tests + 1;

        if (dut.valid_ram.valid_bits === 64'b0) begin
            passed = passed + 1;
            $display("PASS | Reset invalidates cache");
        end else begin
            $fatal(1, "Reset did not invalidate cache");
        end

        @(negedge clk);
        reset = 1'b0;

        // Test 18: Previously cached block must miss
        check_transaction(
            0, 32'h00000000,
            0, 32'h00000001, 0
        );

        // =====================================
        // FINAL SUMMARY
        // =====================================

        $display("=====================================");
        $display("Tests executed : %0d", tests);
        $display("Tests passed   : %0d", passed);
        $display("Tests failed   : %0d", tests - passed);
        $display("=====================================");

        if (tests != passed)
            $fatal(1, "Verification failed");

        $display("ALL VERIFICATION TESTS PASSED");

        $finish;
    end

endmodule
