
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

    localparam [127:0] BLOCK_A =
        128'h00000004_00000003_00000002_00000001;

    localparam [127:0] BLOCK_B =
        128'h00000040_00000030_00000020_00000010;

    localparam [127:0] BLOCK_C =
        128'h00000404_00000403_00000402_00000401;

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

    initial clk = 0;
    always #5 clk = ~clk;

    // Perform and verify a CPU transaction
    task check_transaction;
        input        is_write;
        input [31:0] address;
        input [31:0] write_value;
        input [31:0] expected_read;
        input        expected_hit;

        integer cycles;

        begin
            // Present request while controller is idle
            @(negedge clk);
            cpu_req = 1;
            cpu_write = is_write;
            cpu_address = address;
            cpu_write_data = write_value;

            // Request captured on rising edge
            @(negedge clk);
            cpu_req = 0;

            cycles = 0;

            // Wait for response, with timeout
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

            // Allow response-state writes to commit
            // and the controller to return to IDLE.
            @(negedge clk);
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/cache_rw.vcd");
        $dumpvars(0, tb_cache_rw);

        reset = 1;
        cpu_req = 0;
        cpu_write = 0;
        cpu_address = 0;
        cpu_write_data = 0;

        tests = 0;
        passed = 0;

        // Initialize backing memory
        dut.backing_mem.memory[0]  = BLOCK_A;
        dut.backing_mem.memory[1]  = BLOCK_B;
        dut.backing_mem.memory[64] = BLOCK_C;

        #12;
        reset = 0;

        $display("=====================================");
        $display(" CACHE READ/WRITE VERIFICATION");
        $display("=====================================");

        // 1. Initial read -> MISS
        check_transaction(0, 32'h00000000,
            0, 32'h00000001, 0);

        // 2. Write hit -> cache and memory update
        check_transaction(1, 32'h00000004,
            32'hDEADBEEF, 0, 1);

        // 3. Read modified word -> HIT
        check_transaction(0, 32'h00000004,
            0, 32'hDEADBEEF, 1);

        // 4. Unmodified word remains correct
        check_transaction(0, 32'h00000000,
            0, 32'h00000001, 1);

        // 5. Write miss -> no write allocation
        check_transaction(1, 32'h00000010,
            32'hCAFEBABE, 0, 0);

        // 6. Subsequent read -> MISS, fetch new value
        check_transaction(0, 32'h00000010,
            0, 32'hCAFEBABE, 0);

        // 7. Repeated read -> HIT
        check_transaction(0, 32'h00000010,
            0, 32'hCAFEBABE, 1);

        // 8. Write miss to conflicting block
        check_transaction(1, 32'h00000400,
            32'h12345678, 0, 0);

        // 9. Original cache line remains valid
        check_transaction(0, 32'h00000000,
            0, 32'h00000001, 1);

        // 10. Read conflicting block -> MISS
        check_transaction(0, 32'h00000400,
            0, 32'h12345678, 0);

        // 11. Original block was evicted -> MISS
        check_transaction(0, 32'h00000000,
            0, 32'h00000001, 0);

        $display("=====================================");
        $display("Tests executed : %0d", tests);
        $display("Tests passed   : %0d", passed);
        $display("Tests failed   : %0d", tests - passed);
        $display("=====================================");

        $finish;
    end

endmodule
