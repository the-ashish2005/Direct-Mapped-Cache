# Direct-Mapped Cache Controller Using Verilog HDL

A hardware-description-language project implementing a **1 KB direct-mapped cache controller** with cache hit/miss detection, memory block refill, write-through updates, and no-write-allocate behavior.

## Project Overview

This project explores how cache memory can improve processor memory-access performance by exploiting temporal and spatial locality.

The design is implemented in Verilog HDL and evaluated using functional simulation, waveform inspection, performance benchmarks, and generic hardware synthesis.

## Features

- 32-bit address decoding
- 64 cache lines with 16-byte blocks
- 22-bit tag comparison and valid-bit tracking
- Read hit/miss detection
- Automatic cache refill on read misses
- Write-through and no-write-allocate support
- Direct-mapped replacement behavior
- Performance benchmarking using different access patterns
- Waveform generation and synthesis analysis

## Tools

- Verilog HDL
- Icarus Verilog
- GTKWave
- Yosys
- Python
- Matplotlib

## Architecture

**CPU → Address Decoder → Cache Lookup → Cache Controller → Cache / Main Memory**

Each address is divided into a 22-bit tag, 6-bit index, and 4-bit block offset.

A cache hit occurs when the selected line is valid and its stored tag matches the requested tag.

## Running the Project

Compile the current read/write testbench:

```bash
iverilog -g2012 -Wall -s tb_cache_rw -o results/cache_rw_sim \
  rtl/address_decoder.v rtl/cache_data_ram.v \
  rtl/cache_tag_ram.v rtl/valid_bit_ram.v \
  rtl/main_memory.v rtl/tag_comparator.v \
  rtl/cache_controller.v rtl/cache_top.v \
  testbench/tb_cache_rw.v
```

Run the simulation:

```bash
vvp results/cache_rw_sim
```

View waveforms:

```bash
gtkwave results/waveforms/cache_rw.vcd
```

Generate performance charts after creating `results/performance.csv`:

```bash
python3 scripts/analyze_performance.py
```

## Synthesis

The design was processed using Yosys generic synthesis.

| Metric | Result |
|---|---:|
| Generic cells | 1,718 |
| Wires | 1,765 |
| Wire bits | 87,697 |

These are technology-independent synthesis statistics, not FPGA-specific utilization or timing measurements.

## Limitations

The current design supports aligned 32-bit accesses within a 4 KB simulated backing memory. Memory latency and request handling are simplified for educational use.

## Project Documentation

- `docs/architecture.md` — System architecture and design decisions
- `docs/testing.md` — Verification strategy
- `docs/project_report.md` — Final technical report
- `results/` — Simulation and synthesis outputs

## Course

Modern Computer Architecture — Academic RTL Design Project
