
# Verification and Testing

## Verification Tools

- Icarus Verilog for simulation
- GTKWave for waveform inspection
- Yosys for generic synthesis
- Python and Matplotlib for performance analysis

## Functional Test Categories

1. Address decoding
2. Cache data and tag storage
3. Valid-bit reset behavior
4. Controller state transitions
5. Read hits and read misses
6. Write-through updates
7. No-write-allocate behavior
8. Cache conflict replacement
9. Backing-memory consistency
10. Address boundary testing

## Test Execution

Compile the final RTL and regression testbench:

```sh
iverilog -g2012 -Wall \
  -s tb_cache_rw \
  -o results/cache_rw_sim \
  rtl/address_decoder.v \
  rtl/cache_data_ram.v \
  rtl/cache_tag_ram.v \
  rtl/valid_bit_ram.v \
  rtl/main_memory.v \
  rtl/tag_comparator.v \
  rtl/cache_controller.v \
  rtl/cache_top.v \
  testbench/tb_cache_rw.v
```

Run:

```sh
vvp results/cache_rw_sim
```

Record the actual number of passed and failed tests.

## Performance Evaluation

Measure:

- Cache hit ratio
- Cache miss ratio
- Average response latency
- Memory-access-pattern comparisons

Benchmark workloads:

- Repeated
- Sequential
- Conflict
- Pseudo-random

## Synthesis

Yosys generic synthesis completed and reported:

- 1718 generic cells
- 1765 wires
- 87697 wire bits

These values are not device-specific FPGA resources.

## Verification Status

Functional regression: Pending confirmation
Benchmark results: Pending confirmation
Yosys generic synthesis: Completed

Update the pending entries only after reviewing the actual outputs.
