
`timescale 1ns/1ps

module cache_controller (
    input  wire clk,
    input  wire reset,
    input  wire cpu_req,
    input  wire cpu_write,
    input  wire cache_hit,
    input  wire mem_ready,

    output wire mem_req,
    output wire memory_write_enable,
    output wire cache_write_enable,
    output wire cpu_ready,
    output wire cpu_hit,
    output wire busy
);

    localparam [2:0]
        IDLE      = 3'd0,
        LOOKUP    = 3'd1,
        MISS_WAIT = 3'd2,
        REFILL    = 3'd3,
        RESPOND   = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;
    reg hit_result;

    // Register for the current state
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // FSM transitions
    always @(*) begin
        next_state = state;

        case (state)
            IDLE: begin
                if (cpu_req)
                    next_state = LOOKUP;
            end

            LOOKUP: begin
                if (cpu_write || cache_hit)
                    next_state = RESPOND;
                else
                    next_state = MISS_WAIT;
            end

            MISS_WAIT: begin
                if (mem_ready)
                    next_state = REFILL;
            end

            REFILL: begin
                next_state = RESPOND;
            end

            RESPOND: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Remember the hit/miss result
    always @(posedge clk or posedge reset) begin
        if (reset)
            hit_result <= 1'b0;
        else if (state == LOOKUP)
            hit_result <= cache_hit;
    end

    // Main memory requests for read misses
    assign mem_req =
        (state == MISS_WAIT);

    // Write-through update to backing memory
    assign memory_write_enable =
        (state == RESPOND) && cpu_write;

    // Refill on read miss or update a write hit
    assign cache_write_enable =
        (state == REFILL) ||
        ((state == RESPOND) && cpu_write && hit_result);

    assign cpu_ready = (state == RESPOND);
    assign cpu_hit = hit_result;
    assign busy = (state != IDLE);

endmodule
