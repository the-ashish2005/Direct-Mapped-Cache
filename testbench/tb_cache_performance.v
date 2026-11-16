`timescale 1ns/1ps

//---------------------------------------------------------------
// tb_cache_performance
//
// Memory-access-pattern benchmark for the direct-mapped cache.
//
// For every workload this testbench reports:
//   - hit ratio and miss ratio
//   - the measured average access latency
//   - AMAT, computed from the hardware's hit time and miss
//     penalty, which are themselves measured by a calibration
//     pass rather than assumed
//
// It also writes a per-workload memory-access trace so the
// hit/miss decision for every individual reference can be
// inspected or re-analysed offline.
//
// Latency convention: cycle 1 is the cycle in which the request
// is accepted by the controller. The same convention is used in
// tb_cache_rw and tb_cache_top.
//---------------------------------------------------------------

module tb_cache_performance;

    //-----------------------------------------------------------
    // Clock / DUT
    //-----------------------------------------------------------
    localparam real CLK_PERIOD_NS = 10.0;

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
    always #(CLK_PERIOD_NS/2.0) clk = ~clk;

    //-----------------------------------------------------------
    // Statistics
    //-----------------------------------------------------------
    integer reads, read_hits, read_misses;
    integer writes, write_hits, write_misses;
    integer read_hit_cycles, read_miss_cycles, total_cycles;
    integer total_requests;

    integer cycles;
    integer i, j;
    integer csv_file, trace_file;
    integer seq;

    // Hardware timing parameters, filled in by calibrate()
    real HIT_TIME;        // cycles
    real MISS_PENALTY;    // extra cycles on a miss

    reg [31:0] lfsr;

    //-----------------------------------------------------------
    // Deterministic pseudo-random generator (32-bit Galois LFSR).
    // Self-contained so results reproduce on any simulator.
    //-----------------------------------------------------------
    task rand_next;
        begin
            lfsr = {lfsr[30:0],
                    lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
        end
    endtask

    //-----------------------------------------------------------
    // Reset the cache and clear the counters
    //-----------------------------------------------------------
    task start_workload;
        input [8*16-1:0] name;
        begin
            @(negedge clk);
            reset   = 1'b1;
            cpu_req = 1'b0;

            @(negedge clk);
            @(negedge clk);
            reset = 1'b0;

            reads  = 0; read_hits  = 0; read_misses  = 0;
            writes = 0; write_hits = 0; write_misses = 0;
            read_hit_cycles = 0; read_miss_cycles = 0;
            total_cycles = 0; total_requests = 0;
            seq = 0;

            lfsr = 32'hACE1_2345;

            if (name !== "CALIBRATE") begin
                trace_file = $fopen($sformatf(
                    "results/traces/%0s.csv", name), "w");

                if (trace_file == 0)
                    $fatal(1, "Could not open trace file");

                $fdisplay(trace_file,
                    "seq,address,tag,index,offset,op,outcome,cycles");
            end
            else begin
                trace_file = 0;
            end
        end
    endtask

    //-----------------------------------------------------------
    // Issue one access and record its latency and outcome
    //-----------------------------------------------------------
    task do_access;
        input        is_write;
        input [31:0] address;
        input [31:0] data;

        begin
            while (busy !== 1'b0)
                @(negedge clk);

            @(negedge clk);
            cpu_address    = address;
            cpu_write      = is_write;
            cpu_write_data = data;
            cpu_req        = 1'b1;

            @(negedge clk);
            cpu_req = 1'b0;

            cycles = 1;

            while (cpu_ready !== 1'b1 && cycles < 30) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (cpu_ready !== 1'b1)
                $fatal(1, "Timeout at address %h", address);

            if (cpu_hit !== 1'b0 && cpu_hit !== 1'b1)
                $fatal(1, "Unknown hit signal at %h", address);

            if (!is_write && (^cpu_read_data === 1'bx))
                $fatal(1, "Unknown read data at %h", address);

            total_requests = total_requests + 1;
            total_cycles   = total_cycles + cycles;
            seq            = seq + 1;

            if (is_write) begin
                writes = writes + 1;
                if (cpu_hit) write_hits  = write_hits  + 1;
                else         write_misses = write_misses + 1;
            end
            else begin
                reads = reads + 1;
                if (cpu_hit) begin
                    read_hits       = read_hits + 1;
                    read_hit_cycles = read_hit_cycles + cycles;
                end
                else begin
                    read_misses      = read_misses + 1;
                    read_miss_cycles = read_miss_cycles + cycles;
                end
            end

            if (trace_file != 0) begin
                $fdisplay(trace_file,
                    "%0d,0x%08h,0x%06h,%0d,%0d,%0s,%0s,%0d",
                    seq,
                    address,
                    address[31:10],   // tag
                    address[9:4],     // index
                    address[3:0],     // offset
                    is_write ? "W" : "R",
                    cpu_hit  ? "HIT" : "MISS",
                    cycles);
            end

            @(negedge clk);
            while (busy !== 1'b0)
                @(negedge clk);
        end
    endtask

    task do_read;
        input [31:0] address;
        begin
            do_access(1'b0, address, 32'b0);
        end
    endtask

    task do_write;
        input [31:0] address;
        input [31:0] data;
        begin
            do_access(1'b1, address, data);
        end
    endtask

    //-----------------------------------------------------------
    // Calibration: measure the hardware hit time and miss
    // penalty directly instead of assuming them.
    //-----------------------------------------------------------
    task calibrate;
        real measured_hit;
        real measured_miss;
        begin
            start_workload("CALIBRATE");

            // Cold access -> guaranteed miss
            do_read(32'h0000_0000);
            // Same line again -> guaranteed hit
            do_read(32'h0000_0000);

            if (read_hits != 1 || read_misses != 1)
                $fatal(1, "Calibration pattern did not behave as expected");

            measured_hit  = 1.0 * read_hit_cycles  / read_hits;
            measured_miss = 1.0 * read_miss_cycles / read_misses;

            HIT_TIME     = measured_hit;
            MISS_PENALTY = measured_miss - measured_hit;

            $display("=========================================");
            $display(" HARDWARE TIMING CALIBRATION");
            $display("=========================================");
            $display("Clock period        : %0.1f ns", CLK_PERIOD_NS);
            $display("Hit time            : %0.2f cycles (%0.1f ns)",
                     HIT_TIME, HIT_TIME * CLK_PERIOD_NS);
            $display("Miss latency        : %0.2f cycles", measured_miss);
            $display("Miss penalty        : %0.2f cycles (%0.1f ns)",
                     MISS_PENALTY, MISS_PENALTY * CLK_PERIOD_NS);
            $display("AMAT = HitTime + MissRate x MissPenalty");
        end
    endtask

    //-----------------------------------------------------------
    // Report one workload and append it to the CSV
    //-----------------------------------------------------------
    task print_results;
        input [8*16-1:0] workload;
        input [8*40-1:0] description;

        real hit_rate, miss_rate;
        real amat_cycles, amat_ns;
        real measured_read_latency;
        real avg_cycles;
        real delta;

        begin
            if (reads == 0)
                $fatal(1, "Workload issued no reads");

            hit_rate   = 100.0 * read_hits   / reads;
            miss_rate  = 1.0   * read_misses / reads;
            avg_cycles = 1.0   * total_cycles / total_requests;

            measured_read_latency =
                1.0 * (read_hit_cycles + read_miss_cycles) / reads;

            // Textbook AMAT, from calibrated hardware parameters
            amat_cycles = HIT_TIME + miss_rate * MISS_PENALTY;
            amat_ns     = amat_cycles * CLK_PERIOD_NS;

            // Self-check: the analytical model must agree with
            // the latency actually observed in simulation.
            delta = amat_cycles - measured_read_latency;
            if (delta < 0) delta = -delta;

            if (delta > 0.01)
                $fatal(1,
                    "AMAT model disagrees with measurement (%0.3f vs %0.3f)",
                    amat_cycles, measured_read_latency);

            $display("-----------------------------------------");
            $display("Workload   : %0s", workload);
            $display("Pattern    : %0s", description);
            $display("Requests   : %0d  (reads %0d, writes %0d)",
                     total_requests, reads, writes);
            $display("Read hits  : %0d", read_hits);
            $display("Read misses: %0d", read_misses);
            $display("Hit Rate   : %0.2f%%", hit_rate);
            $display("Miss Rate  : %0.2f%%", miss_rate * 100.0);
            $display("AMAT       : %0.3f cycles (%0.2f ns)",
                     amat_cycles, amat_ns);
            $display("  = %0.2f + %0.4f x %0.2f",
                     HIT_TIME, miss_rate, MISS_PENALTY);
            $display("Measured   : %0.3f cycles  [model verified]",
                     measured_read_latency);
            if (writes > 0)
                $display("Writes     : %0d (write-through, %0.2f cycles each)",
                         writes, HIT_TIME);
            $display("Avg cycles : %0.2f (all accesses)", avg_cycles);

            $fdisplay(csv_file,
                "%0s,%0s,%0d,%0d,%0d,%0d,%0d,%0.2f,%0.2f,%0.2f,%0.2f,%0.3f,%0.2f,%0.2f",
                workload,
                description,
                total_requests,
                reads,
                writes,
                read_hits,
                read_misses,
                hit_rate,
                miss_rate * 100.0,
                HIT_TIME,
                MISS_PENALTY,
                amat_cycles,
                amat_ns,
                avg_cycles
            );
        end
    endtask

    //-----------------------------------------------------------
    // Main
    //-----------------------------------------------------------
    initial begin
        $dumpfile("results/waveforms/cache_performance.vcd");
        $dumpvars(0, tb_cache_performance);

        reset          = 1'b1;
        cpu_req        = 1'b0;
        cpu_write      = 1'b0;
        cpu_address    = 0;
        cpu_write_data = 0;

        // Initialise the 4 KB backing memory with known data.
        for (i = 0; i < 256; i = i + 1) begin
            dut.backing_mem.memory[i] =
                {32'(i*4+3), 32'(i*4+2),
                 32'(i*4+1), 32'(i*4)};
        end

        csv_file = $fopen("results/performance.csv", "w");
        if (csv_file == 0)
            $fatal(1, "Could not create CSV file");

        $fdisplay(csv_file,
            {"workload,description,requests,reads,writes,",
             "read_hits,read_misses,hit_rate,miss_rate,",
             "hit_time_cycles,miss_penalty_cycles,",
             "amat_cycles,amat_ns,avg_cycles"});

        #12;
        reset = 0;

        // ---- Measure the hardware before measuring workloads ----
        calibrate();

        $display("");
        $display("=========================================");
        $display(" CACHE PERFORMANCE BENCHMARK");
        $display("=========================================");

        //-------------------------------------------------------
        // 1. Repeated - maximum temporal locality
        //-------------------------------------------------------
        start_workload("Repeated");
        for (i = 0; i < 32; i = i + 1)
            do_read(32'h0000_0000);
        print_results("Repeated", "same address repeated 32 times");

        //-------------------------------------------------------
        // 2. Sequential - spatial locality within 16-byte blocks
        //-------------------------------------------------------
        start_workload("Sequential");
        for (i = 0; i < 64; i = i + 1)
            do_read(i * 4);
        print_results("Sequential", "64 consecutive 32-bit words");

        //-------------------------------------------------------
        // 3. Conflict - two blocks, same index, different tags
        //-------------------------------------------------------
        start_workload("Conflict");
        for (i = 0; i < 32; i = i + 1) begin
            if (i % 2 == 0) do_read(32'h0000_0000);
            else            do_read(32'h0000_0400);
        end
        print_results("Conflict", "two blocks mapping to one line");

        //-------------------------------------------------------
        // 4. PseudoRandom - uniform over the whole 4 KB space.
        //    Addresses repeat, so hits are possible; the hit rate
        //    reflects the 4:1 ratio of memory blocks to lines.
        //-------------------------------------------------------
        start_workload("PseudoRandom");
        for (i = 0; i < 128; i = i + 1) begin
            rand_next();
            do_read(((lfsr % 256) * 16) + ((lfsr >> 8) % 4) * 4);
        end
        print_results("PseudoRandom", "random over full 4 KB range");

        //-------------------------------------------------------
        // 5. WorkingSet - random within 32 blocks (512 B), which
        //    fits entirely in the 1 KB cache
        //-------------------------------------------------------
        start_workload("WorkingSet");
        for (i = 0; i < 128; i = i + 1) begin
            rand_next();
            do_read(((lfsr % 32) * 16) + ((lfsr >> 8) % 4) * 4);
        end
        print_results("WorkingSet", "random within a 512 B working set");

        //-------------------------------------------------------
        // 6. ReadWriteMix - exercises write-through and
        //    no-write-allocate alongside reads
        //-------------------------------------------------------
        start_workload("ReadWriteMix");
        for (i = 0; i < 16; i = i + 1) begin
            do_read (i * 16);                      // cold miss, allocates
            do_write(i * 16 + 4, 32'hA5A5_0000 + i); // write hit
            do_read (i * 16 + 4);                  // reads back written word
            do_read (i * 16 + 8);                  // same block, hit
        end
        print_results("ReadWriteMix", "read/write mix (write-through)");

        $fclose(csv_file);

        $display("-----------------------------------------");
        $display("Benchmark completed successfully.");
        $display("All AMAT values verified against measured latency.");
        $display("-----------------------------------------");

        $finish;
    end

endmodule
