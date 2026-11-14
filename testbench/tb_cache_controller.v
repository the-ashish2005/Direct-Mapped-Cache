`timescale 1ns/1ps

//---------------------------------------------------------------
// tb_cache_controller
//
// Unit-level verification of the cache controller FSM.
// Exercises the read-hit, read-miss (refill) and write
// (write-through / no-write-allocate) control paths.
//---------------------------------------------------------------

module tb_cache_controller;

    reg clk;
    reg reset;
    reg cpu_req;
    reg cpu_write;
    reg cache_hit;
    reg mem_ready;

    wire mem_req;
    wire memory_write_enable;
    wire cache_write_enable;
    wire cpu_ready;
    wire cpu_hit;
    wire busy;

    integer tests;
    integer passed;

    cache_controller dut (
        .clk(clk),
        .reset(reset),
        .cpu_req(cpu_req),
        .cpu_write(cpu_write),
        .cache_hit(cache_hit),
        .mem_ready(mem_ready),
        .mem_req(mem_req),
        .memory_write_enable(memory_write_enable),
        .cache_write_enable(cache_write_enable),
        .cpu_ready(cpu_ready),
        .cpu_hit(cpu_hit),
        .busy(busy)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    //-----------------------------------------------------------
    // Drive one access through the FSM and check the control
    // outputs at every stage.
    //-----------------------------------------------------------
    task check_access;
        input is_write;
        input hit_expected;

        begin
            @(negedge clk);
            cache_hit = hit_expected;
            cpu_write = is_write;
            cpu_req   = 1'b1;

            // IDLE -> LOOKUP
            @(posedge clk);
            #1;

            if (busy !== 1'b1)
                $fatal(1, "Controller did not leave IDLE");

            @(negedge clk);
            cpu_req = 1'b0;

            // LOOKUP -> (RESPOND | MISS_WAIT)
            @(posedge clk);
            #1;

            // Only a READ MISS goes to main memory.
            // Writes are no-write-allocate, so they never refill.
            if (!is_write && !hit_expected) begin

                if (mem_req !== 1'b1)
                    $fatal(1, "Read miss did not request memory");

                @(negedge clk);
                mem_ready = 1'b1;

                // MISS_WAIT -> REFILL
                @(posedge clk);
                #1;

                if (cache_write_enable !== 1'b1)
                    $fatal(1, "Refill did not write the cache line");

                @(negedge clk);
                mem_ready = 1'b0;

                // REFILL -> RESPOND
                @(posedge clk);
                #1;
            end
            else begin
                if (mem_req !== 1'b0)
                    $fatal(1, "Unexpected memory request raised");
            end

            tests = tests + 1;

            // Now in RESPOND
            if (cpu_ready !== 1'b1)
                $fatal(1, "Controller never asserted cpu_ready");

            if (cpu_hit !== hit_expected)
                $fatal(1, "Latched hit result is wrong");

            // Write-through: every write updates backing memory
            if (is_write && memory_write_enable !== 1'b1)
                $fatal(1, "Write did not update main memory");

            if (!is_write && memory_write_enable !== 1'b0)
                $fatal(1, "Read incorrectly wrote main memory");

            // No-write-allocate: only a write HIT updates the line
            if (is_write && hit_expected &&
                cache_write_enable !== 1'b1)
                $fatal(1, "Write hit did not update the cache line");

            if (is_write && !hit_expected &&
                cache_write_enable !== 1'b0)
                $fatal(1, "Write miss incorrectly allocated a line");

            passed = passed + 1;

            $display("PASS | %s %s | Ready=%b Hit=%b MemWr=%b CacheWr=%b",
                     is_write    ? "WRITE" : "READ ",
                     hit_expected ? "HIT " : "MISS",
                     cpu_ready, cpu_hit,
                     memory_write_enable, cache_write_enable);

            // RESPOND -> IDLE
            @(posedge clk);
            #1;

            if (busy !== 1'b0)
                $fatal(1, "Controller did not return to IDLE");
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/cache_controller.vcd");
        $dumpvars(0, tb_cache_controller);

        reset     = 1'b1;
        cpu_req   = 1'b0;
        cpu_write = 1'b0;
        cache_hit = 1'b0;
        mem_ready = 1'b0;
        tests     = 0;
        passed    = 0;

        #12;
        reset = 1'b0;

        $display("=================================");
        $display(" CACHE CONTROLLER VERIFICATION");
        $display("=================================");

        check_access(1'b0, 1'b1);   // read hit
        check_access(1'b0, 1'b0);   // read miss -> refill
        check_access(1'b0, 1'b1);   // read hit after refill
        check_access(1'b1, 1'b1);   // write hit  -> cache + memory
        check_access(1'b1, 1'b0);   // write miss -> memory only
        check_access(1'b0, 1'b0);   // read miss again

        // Reset must return the FSM to IDLE immediately
        @(negedge clk);
        reset = 1'b1;
        @(posedge clk);
        #1;
        tests = tests + 1;
        if (busy !== 1'b0)
            $fatal(1, "Reset did not force the FSM to IDLE");
        passed = passed + 1;
        $display("PASS | Reset returns FSM to IDLE");
        @(negedge clk);
        reset = 1'b0;

        $display("=================================");
        $display("Tests executed : %0d", tests);
        $display("Tests passed   : %0d", passed);
        $display("Tests failed   : %0d", tests-passed);
        $display("=================================");

        if (tests != passed)
            $fatal(1, "Controller verification FAILED");

        $display("CONTROLLER VERIFICATION PASSED");
        $finish;
    end

endmodule
