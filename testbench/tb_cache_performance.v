
`timescale 1ns/1ps

module tb_cache_performance;

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

    integer total_requests;
    integer hits;
    integer misses;
    integer total_cycles;
    integer cycles;
    integer i;
    integer csv_file;

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

    // Clear performance counters and cache validity
    task start_workload;
        begin
            @(negedge clk);
            reset = 1'b1;
            cpu_req = 1'b0;

            @(negedge clk);
            reset = 1'b0;

            total_requests = 0;
            hits = 0;
            misses = 0;
            total_cycles = 0;
        end
    endtask

    // Perform one CPU read and measure response latency
    task measure_read;
        input [31:0] address;

        begin
            // Wait for controller to become idle
            while (busy !== 1'b0)
                @(negedge clk);

            @(negedge clk);
            cpu_address = address;
            cpu_write = 1'b0;
            cpu_req = 1'b1;

            // Request accepted on next rising edge
            @(negedge clk);
            cpu_req = 1'b0;

            cycles = 1;

            while (cpu_ready !== 1'b1 && cycles < 30) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (cpu_ready !== 1'b1)
                $fatal(1, "Timeout at address %h", address);

            if (cpu_hit !== 1'b0 &&
                cpu_hit !== 1'b1)
                $fatal(1, "Unknown hit signal");

            if (^cpu_read_data === 1'bx)
                $fatal(1, "Unknown read data");

            total_requests = total_requests + 1;
            total_cycles = total_cycles + cycles;

            if (cpu_hit)
                hits = hits + 1;
            else
                misses = misses + 1;

            // Wait for response to finish
            @(negedge clk);
            while (busy !== 1'b0)
                @(negedge clk);
        end
    endtask

    // Display and export metrics
    task print_results;
        input [8*32-1:0] workload;

        real hit_rate;
        real miss_rate;
        real avg_cycles;

        begin
            hit_rate = 100.0 * hits / total_requests;
            miss_rate = 100.0 * misses / total_requests;
            avg_cycles = 1.0 * total_cycles / total_requests;

            $display("-----------------------------------------");
            $display("Workload: %0s", workload);
            $display("Requests : %0d", total_requests);
            $display("Hits     : %0d", hits);
            $display("Misses   : %0d", misses);
            $display("Hit Rate : %0.2f%%", hit_rate);
            $display("Miss Rate: %0.2f%%", miss_rate);
            $display("Avg Cycles: %0.2f", avg_cycles);

            $fdisplay(csv_file,
                "%0s,%0d,%0d,%0d,%0.2f,%0.2f,%0.2f",
                workload,
                total_requests,
                hits,
                misses,
                hit_rate,
                miss_rate,
                avg_cycles
            );
        end
    endtask

    initial begin
        $dumpfile(
            "results/waveforms/cache_performance.vcd"
        );
        $dumpvars(0, tb_cache_performance);

        reset = 1'b1;
        cpu_req = 1'b0;
        cpu_write = 1'b0;
        cpu_address = 0;
        cpu_write_data = 0;

        // Initialize the 4 KB backing memory.
        // All 256 blocks have known data.
        for (i = 0; i < 256; i = i + 1) begin
            dut.backing_mem.memory[i] =
                {32'(i*4+3), 32'(i*4+2),
                 32'(i*4+1), 32'(i*4)};
        end

        csv_file = $fopen(
            "results/performance.csv", "w"
        );

        if (csv_file == 0)
            $fatal(1, "Could not create CSV file");

        $fdisplay(csv_file,
            "workload,requests,hits,misses,hit_rate,miss_rate,avg_cycles"
        );

        #12;
        reset = 0;

        $display("CACHE PERFORMANCE BENCHMARK");

        // Workload 1: Repeat the same address
        start_workload();
        for (i = 0; i < 32; i = i + 1)
            measure_read(32'h00000000);
        print_results("Repeated");

        // Workload 2: 64 sequential 32-bit words
        start_workload();
        for (i = 0; i < 64; i = i + 1)
            measure_read(i * 4);
        print_results("Sequential");

        // Workload 3: Alternate conflicting blocks
        start_workload();
        for (i = 0; i < 32; i = i + 1) begin
            if (i % 2 == 0)
                measure_read(32'h00000000);
            else
                measure_read(32'h00000400);
        end
        print_results("Conflict");

        // Workload 4: Deterministic pseudo-random blocks
        start_workload();
        for (i = 0; i < 64; i = i + 1)
            measure_read(((i * 37) % 256) * 16);
        print_results("PseudoRandom");

        $fclose(csv_file);

        $display("-----------------------------------------");
        $display("Benchmark completed successfully.");

        $finish;
    end

endmodule
