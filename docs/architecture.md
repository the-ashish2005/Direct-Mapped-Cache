
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

## Limitations

- Only aligned 32-bit word accesses are supported.
- The backing-memory model covers 4 KB.
- The memory timing is simplified.
- The controller processes one request at a time.
- No physical FPGA deployment is included.
- This is an educational RTL implementation.
