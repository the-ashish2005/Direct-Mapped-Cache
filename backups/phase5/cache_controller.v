
`timescale 1ns/1ps

module cache_controller (
    input  wire clk,
    input  wire reset,

    // CPU request interface
    input  wire cpu_req,

    // Cache lookup result
    input  wire cache_hit,

    // Main memory completion signal
    input  wire mem_ready,

    // Control outputs
    output wire mem_req,
    output wire cache_write_enable,
    output wire cpu_ready,
    output wire cpu_hit,
    output wire busy
);

    // FSM state definitions
    localparam [2:0]
        IDLE      = 3'd0,
        LOOKUP    = 3'd1,
        MISS_WAIT = 3'd2,
        REFILL    = 3'd3,
        RESPOND   = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;

    // Store whether the request was a cache hit
    reg hit_result;

    // State register
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next-state logic
    always @(*) begin
        next_state = state;

        case (state)

            IDLE: begin
                if (cpu_req)
                    next_state = LOOKUP;
            end

            LOOKUP: begin
                if (cache_hit)
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

            default: begin
                next_state = IDLE;
            end

        endcase
    end

    // Save the result of the cache lookup
    always @(posedge clk or posedge reset) begin
        if (reset)
            hit_result <= 1'b0;
        else if (state == LOOKUP)
            hit_result <= cache_hit;
    end

    // Generate controller outputs
    assign mem_req =
        (state == MISS_WAIT);

    assign cache_write_enable =
        (state == REFILL);

    assign cpu_ready =
        (state == RESPOND);

    assign cpu_hit = hit_result;

    assign busy =
        (state != IDLE);

endmodule
