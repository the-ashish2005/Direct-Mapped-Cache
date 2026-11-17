# Verification and Testing

## Tools

- **Icarus Verilog** (`-g2012`) — simulation
- **GTKWave** — waveform inspection
- **Yosys** — generic synthesis
- **Python 3 + matplotlib** — performance analysis

## Strategy

Verification is bottom-up: each module is checked on its own before the
integrated system is exercised, so a failure localises to one block
rather than to "the cache".

Every check is self-checking. A mismatch calls `$fatal`, which makes
`vvp` exit non-zero and stops `make regress`. No test can fail silently
and no result needs to be read by eye to know whether it passed.

| Level | Testbench | Target |
|---|---|---|
| Unit | `tb_address_decoder` | `address_decoder` |
| Unit | `tb_cache_controller` | `cache_controller` FSM |
| Unit | `tb_cache_memory` | tag / valid / data arrays |
| System | `tb_cache_rw` | `cache_top` read + write regression |
| System | `tb_cache_top` | `cache_top` integration sequencing |
| Performance | `tb_cache_performance` | hit rate, latency, AMAT |

## Functional coverage

1. Address decoding across the full range, including `0x00000000` and
   `0xFFFFFFFF`
2. Cache data, tag and valid-bit storage
3. Valid-bit clearing on reset — stale data must never read as a hit
4. FSM transitions: read hit, read miss with refill, write hit, write
   miss, and reset from a mid-access state
5. Read hit and read miss behaviour
6. Hit on a different word within an already-cached block
7. Write-through: backing memory is read back and compared after writes
8. No-write-allocate: a write miss must not validate the line
9. Conflict replacement between two tags sharing an index
10. Address-boundary accesses at the top of the 4 KB backing memory
11. X-propagation guards — any unknown on `cpu_read_data` or `cpu_hit`
    fails the test

## Running

```bash
make regress     # all functional tests
make perf        # performance benchmark and traces
make all         # regress + perf + analyze + synth
```

To run a single testbench by hand:

```bash
iverilog -g2012 -Wall -s tb_cache_rw -o results/cache_rw_sim \
  rtl/address_decoder.v rtl/cache_data_ram.v rtl/cache_tag_ram.v \
  rtl/valid_bit_ram.v rtl/main_memory.v rtl/tag_comparator.v \
  rtl/cache_controller.v rtl/cache_top.v \
  testbench/tb_cache_rw.v

vvp results/cache_rw_sim
```

## Latency convention

All testbenches count cycle 1 as the cycle in which the controller
accepts the request, so latencies are directly comparable between them:

| Access | Cycles | States traversed |
|---|---:|---|
| Hit (read or write) | 2 | LOOKUP, RESPOND |
| Read miss | 7 | LOOKUP, 4 x MISS_WAIT, REFILL, RESPOND |

Miss penalty = 7 - 2 = **5 cycles**.

## Performance evaluation

`tb_cache_performance` calibrates the hardware before measuring it: it
issues one guaranteed miss and one guaranteed hit, derives HitTime and
MissPenalty from the observed latencies, and uses those measured values
in the AMAT model.

```
AMAT = HitTime + MissRate x MissPenalty
```

For every workload the analytical AMAT is asserted against the average
latency actually observed. A disagreement greater than 0.01 cycles
fails the run, so the published AMAT figures cannot drift away from the
hardware they describe.

Workloads: Repeated, Sequential, Conflict, PseudoRandom, WorkingSet,
ReadWriteMix.

Outputs:

- `results/performance.csv` — machine-readable summary
- `results/logs/performance.log` — full benchmark transcript
- `results/traces/*.csv` — per-reference memory-access traces
- `results/graphs/*.png` — five charts

## Verification status

| Item | Status |
|---|---|
| Functional regression | **46 / 46 passed, 0 failed** |
| Benchmark | **Completed** — 6 workloads, AMAT verified against measurement |
| Memory-access traces | **Generated** — 448 references across 6 traces |
| Yosys generic synthesis | **Completed** — 1,718 cells, no warnings |

Transcripts: `results/logs/regression.log`,
`results/logs/performance.log`.
