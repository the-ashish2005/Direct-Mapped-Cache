
`timescale 1ns/1ps

module tb_cache_controller;

    reg clk;
    reg reset;
    reg cpu_req;
    reg cache_hit;
    reg mem_ready;

    wire mem_req;
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
        .cache_hit(cache_hit),
        .mem_ready(mem_ready),
        .mem_req(mem_req),
        .cache_write_enable(cache_write_enable),
        .cpu_ready(cpu_ready),
        .cpu_hit(cpu_hit),
        .busy(busy)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task check_request;
        input hit_expected;
        begin
            @(negedge clk);
            cache_hit = hit_expected;
            cpu_req = 1;

            @(posedge clk);
            #1;

            if (busy !== 1'b1)
                $fatal(1, "Controller did not start");

            @(negedge clk);
            cpu_req = 0;

            @(posedge clk);
            #1;

            if (!hit_expected) begin
                if (mem_req !== 1'b1)
                    $fatal(1, "Memory request missing");

                @(negedge clk);
                mem_ready = 1;

                @(posedge clk);
                #1;

                if (cache_write_enable !== 1'b1)
                    $fatal(1, "Cache refill missing");

                @(negedge clk);
                mem_ready = 0;

                @(posedge clk);
                #1;
            end

            tests = tests + 1;

            if (cpu_ready === 1'b1 &&
                cpu_hit === hit_expected) begin
                passed = passed + 1;
                $display("PASS | Hit=%b Ready=%b",
                         cpu_hit, cpu_ready);
            end else begin
                $fatal(1, "Incorrect CPU response");
            end

            @(posedge clk);
            #1;

            if (busy !== 1'b0)
                $fatal(1, "Controller did not return to idle");
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/cache_controller.vcd");
        $dumpvars(0, tb_cache_controller);

        reset = 1;
        cpu_req = 0;
        cache_hit = 0;
        mem_ready = 0;
        tests = 0;
        passed = 0;

        #12;
        reset = 0;

        $display("=================================");
        $display(" CACHE CONTROLLER VERIFICATION");
        $display("=================================");

        check_request(1'b1);
        check_request(1'b0);
        check_request(1'b1);

        $display("=================================");
        $display("Tests executed : %0d", tests);
        $display("Tests passed   : %0d", passed);
        $display("Tests failed   : %0d", tests-passed);
        $display("=================================");

        $finish;
    end

endmodule
