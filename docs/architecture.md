
# Direct-Mapped Cache Controller — Architecture

## Overview

This project implements a 1 KB direct-mapped cache controller using Verilog HDL.

The cache supports 32-bit aligned read and write operations, cache hit/miss detection, block replacement, and write-through with no-write-allocate behavior.

## Cache Configuration

| Parameter | Value |
|---|---|
| Cache capacity | 1024 bytes |
| Cache block size | 16 bytes |
| Cache lines | 64 |
| CPU address width | 32 bits |
| Data word width | 32 bits |
| Cache block width | 128 bits |
| Tag width | 22 bits |
| Index width | 6 bits |
| Offset width | 4 bits |
| Backing memory | 4 KB simulation model |

## Address Mapping

The 32-bit address is divided into:

- Tag: address[31:10]
- Index: address[9:4]
- Offset: address[3:0]

Mapping formula:

Cache Line = (Address / 16) % 64

Cache Hit = Valid AND (Requested Tag == Stored Tag)

## Main Components

1. address_decoder: Extracts tag, index, offset.
2. cache_data_ram: Stores cached blocks.
3. cache_tag_ram: Stores tags.
4. valid_bit_ram: Tracks valid cache lines.
5. tag_comparator: Detects hits and misses.
6. main_memory: Simulated backing memory.
7. cache_controller: Controls the cache FSM.
8. cache_top: Integrates all modules.

## Cache Controller States

IDLE -> LOOKUP -> RESPOND (hit)

IDLE -> LOOKUP -> MISS_WAIT -> REFILL -> RESPOND (read miss)

## Read Policy

On a read hit, the requested word is returned from the cache.

On a read miss, the required block is fetched from backing memory and installed in the cache before the CPU receives the result.

## Write Policy

The design uses write-through and no-write-allocate.

- Write hit: update cache and backing memory.
- Write miss: update backing memory without allocating a new cache line.

## Access Timing

Latency convention: cycle 1 is the cycle in which the controller
accepts the request.

| Access | Cycles | States |
|---|---:|---|
| Read hit | 2 | LOOKUP, RESPOND |
| Write hit or miss | 2 | LOOKUP, RESPOND |
| Read miss | 7 | LOOKUP, 4 x MISS_WAIT, REFILL, RESPOND |

- **Hit time** = 2 cycles (20 ns at a 10 ns clock)
- **Miss penalty** = 7 - 2 = 5 cycles (50 ns)

Writes never enter `MISS_WAIT`, because the design is
no-write-allocate: a write miss updates backing memory and leaves the
cache line untouched.

## Average Memory Access Time

```
AMAT = HitTime + MissRate x MissPenalty
     = 2 + MissRate x 5    (cycles)
```

HitTime and MissPenalty are fixed by the hardware. MissRate is a
property of the access pattern, so AMAT is where the architecture and
the workload meet.

| Miss rate | AMAT (cycles) | AMAT (ns) |
|---:|---:|---:|
| 0% (ideal) | 2.00 | 20.0 |
| 25% | 3.25 | 32.5 |
| 50% | 4.50 | 45.0 |
| 100% (no cache) | 7.00 | 70.0 |

`tb_cache_performance` measures HitTime and MissPenalty by calibration
rather than assuming them, then asserts the analytical AMAT against the
latency observed in simulation. Measured results are in
`docs/project_report.md`.

## Design Trade-offs

**Why direct-mapped?** Lookup needs one tag read and one comparator,
with no associative search and no replacement policy, because each
block has exactly one legal line. The cost is conflict misses: two
blocks sharing an index cannot be resident together, even when the rest
of the cache is empty. The `Conflict` workload measures this at a 0%
hit rate with 98% of the cache idle.

**Why 16-byte blocks?** Four 32-bit words per block means one
compulsory miss serves the next three sequential references. The
`Sequential` workload measures exactly the 75% hit rate this predicts.

**Why write-through?** No dirty bits, no write-back path, and cache and
memory can never disagree — which `tb_cache_rw` verifies directly. The
cost is a memory write on every store. Combined with no-write-allocate,
writes never stall the CPU for a refill, so they complete in hit time.


## Limitations

- Only aligned 32-bit word accesses are supported.
- The backing-memory model covers 4 KB.
- The memory timing is simplified.
- The controller processes one request at a time.
- The controller handles one outstanding request; there is no
  pipelining and no write buffer.
- Generic synthesis only; no FPGA place-and-route or timing closure.
- This is an educational RTL implementation.
