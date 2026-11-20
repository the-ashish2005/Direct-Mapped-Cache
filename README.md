# Direct-Mapped Cache Controller (Verilog HDL)

A **1 KB direct-mapped cache controller** with hit/miss detection,
block refill, write-through updates and no-write-allocate behaviour —
verified by a self-checking regression suite and characterised with
hit-rate and **AMAT** measurements across six memory-access patterns.

**Status:** 46 / 46 functional assertions pass. 6 workloads benchmarked.
Generic synthesis clean.

---

## Quick start

```bash
make regress    # compile and run all functional tests
make perf       # performance benchmark + AMAT + traces
make analyze    # regenerate the performance graphs
make synth      # Yosys generic synthesis
make all        # everything above
```

Requires Icarus Verilog, Yosys, Python 3 with matplotlib, and GTKWave
for waveform viewing.

---

## Configuration

| Parameter | Value |
|---|---|
| Cache capacity | 1 KB (64 lines x 16 bytes) |
| Address width | 32 bits |
| Tag / Index / Offset | 22 / 6 / 4 bits |
| Word size | 32 bits |
| Write policy | Write-through, no-write-allocate |
| Backing memory | 4 KB model, 4-cycle read latency |
| Clock | 10 ns |

```
 31                        10 9        4 3      0
+----------------------------+----------+--------+
|          TAG (22)          | INDEX(6) |OFFSET(4)|
+----------------------------+----------+--------+
```

```
Cache line = (Address / 16) mod 64
Cache hit  = Valid[index] AND (Tag[index] == Address[31:10])
```

---

## Architecture

```
CPU -> address_decoder -> tag/valid/data RAMs -> tag_comparator
                                                      |
                                              cache_controller (FSM)
                                                      |
                                                 main_memory
```

Controller FSM: `IDLE -> LOOKUP -> RESPOND` on a hit;
`IDLE -> LOOKUP -> MISS_WAIT -> REFILL -> RESPOND` on a read miss.
Writes never enter `MISS_WAIT` — that is what makes the design
no-write-allocate.

| Access | Latency |
|---|---:|
| Hit (read or write) | 2 cycles |
| Read miss | 7 cycles |
| **Miss penalty** | **5 cycles** |

---

## Results

### Functional verification

| Testbench | Checks | Result |
|---|---:|---|
| `tb_address_decoder` | 7 | pass |
| `tb_cache_controller` | 7 | pass |
| `tb_cache_memory` | 7 | pass |
| `tb_cache_rw` | 18 | pass |
| `tb_cache_top` | 7 | pass |
| **Total** | **46** | **46 / 46 pass** |

### Performance

Hit time **2 cycles**, miss penalty **5 cycles**, measured by
calibration, not assumed.

```
AMAT = HitTime + MissRate x MissPenalty = 2 + MissRate x 5
```

| Workload | Hit rate | AMAT (cycles) | AMAT (ns) | Speedup |
|---|---:|---:|---:|---:|
| Repeated | 96.88% | 2.156 | 21.56 | 3.25x |
| Sequential | 75.00% | 3.250 | 32.50 | 2.15x |
| Conflict | 0.00% | 7.000 | 70.00 | 1.00x |
| PseudoRandom | 15.62% | 6.219 | 62.19 | 1.13x |
| WorkingSet | 75.00% | 3.250 | 32.50 | 2.15x |
| ReadWriteMix | 66.67% | 3.667 | 36.67 | 1.91x |

Speedup is against an uncached system (70 ns per access).

Three results carry the analysis:

- **Sequential hits exactly 75%** because a 16-byte block holds four
  words: one compulsory miss serves the next three references. Spatial
  locality, working as designed.
- **Conflict hits 0%** with 98% of the cache empty. Two addresses
  sharing an index evict each other forever, and AMAT degrades to
  exactly the no-cache figure. This is the quantitative case for
  set-associativity.
- **PseudoRandom (15.62%) vs WorkingSet (75.00%)** use the *same*
  random generator and differ only in footprint — 4 KB versus 512 B.
  Capacity, not randomness, causes the collapse.

Every AMAT figure is asserted against the latency actually observed in
simulation; a disagreement over 0.01 cycles fails the run.

### Synthesis

Yosys generic (technology-independent) synthesis:

| Metric | Result |
|---|---:|
| Generic cells | 1,718 |
| Wires | 1,765 |
| Wire bits | 87,697 |

No warnings, no inferred latches. These are **not** FPGA LUT counts and
no timing closure is claimed.

---

## Repository layout

```
rtl/                  8 synthesisable modules
testbench/            5 functional + 1 performance testbench
scripts/              analyze_performance.py, synth.ys
docs/                 architecture.md, testing.md, project_report.md
results/
  performance.csv     machine-readable benchmark summary
  traces/             per-reference memory-access traces (448 refs)
  graphs/             5 charts
  logs/               regression and benchmark transcripts
  waveforms/          VCD files for GTKWave
  synthesis/          Yosys report
backups/phase5/       historical snapshot, not part of the build
```

### Viewing waveforms

```bash
make waves TB=cache_rw
```

---

## Limitations

- Aligned 32-bit accesses only.
- 4 KB backing-memory model; memory latency is a fixed 4-cycle counter.
- One outstanding request — no pipelining, no write buffer.
- Simulation and generic synthesis only; no FPGA place-and-route.

---

## Documentation

| Document | Read it for |
|---|---|
| [`docs/Presentation.pptx`](docs/Presentation.pptx) | PowerPoint Presentation |
| [`docs/IEEE_Report.pdf`](docs/IEEE_Report.pdf) | IEEE Technical Project Report |
| [`docs/architecture.md`](docs/architecture.md) | Design decisions and trade-offs |
| [`docs/testing.md`](docs/testing.md) | Verification strategy and coverage |

