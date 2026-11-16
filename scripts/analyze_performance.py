#!/usr/bin/env python3
"""
Performance analysis for the direct-mapped cache controller.

Reads results/performance.csv (written by tb_cache_performance)
and produces the hit-rate, latency and AMAT charts used in the
project report.

AMAT = HitTime + MissRate x MissPenalty

The hit time and miss penalty are not assumed here: they are
measured by the testbench's calibration pass and carried in the
CSV, so these charts always reflect the hardware as simulated.
"""

import csv
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # headless-safe
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
CSV_FILE = ROOT / "results" / "performance.csv"
OUTPUT_DIR = ROOT / "results" / "graphs"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

if not CSV_FILE.exists():
    sys.exit(f"Performance CSV not found: {CSV_FILE}\nRun 'make perf' first.")

with CSV_FILE.open(newline="") as handle:
    rows = list(csv.DictReader(handle))

if not rows:
    sys.exit("Performance CSV is empty")

workloads = [r["workload"] for r in rows]
hit_rates = [float(r["hit_rate"]) for r in rows]
miss_rates = [float(r["miss_rate"]) for r in rows]
amat_cycles = [float(r["amat_cycles"]) for r in rows]
amat_ns = [float(r["amat_ns"]) for r in rows]

hit_time = float(rows[0]["hit_time_cycles"])
miss_penalty = float(rows[0]["miss_penalty_cycles"])

# Consistency check: every row must share the same hardware
# parameters, otherwise the charts would compare different designs.
for row in rows:
    if (float(row["hit_time_cycles"]) != hit_time
            or float(row["miss_penalty_cycles"]) != miss_penalty):
        sys.exit("CSV mixes different hardware timing parameters")

HIT_COLOUR = "#2E7D32"
MISS_COLOUR = "#C62828"
AMAT_COLOUR = "#1565C0"
BASE_COLOUR = "#90A4AE"


def annotate(axis, bars, fmt="{:.2f}"):
    for bar in bars:
        axis.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height(),
            fmt.format(bar.get_height()),
            ha="center",
            va="bottom",
            fontsize=9,
        )


def save(fig, name):
    fig.tight_layout()
    fig.savefig(OUTPUT_DIR / name, dpi=200)
    plt.close(fig)


# ---------------------------------------------------------------
# 1. Hit rate
# ---------------------------------------------------------------
fig, ax = plt.subplots(figsize=(9, 5))
bars = ax.bar(workloads, hit_rates, color=HIT_COLOUR)
annotate(ax, bars, "{:.2f}%")
ax.set_title("Direct-Mapped Cache: Hit Rate by Access Pattern")
ax.set_xlabel("Memory access pattern")
ax.set_ylabel("Cache hit rate (%)")
ax.set_ylim(0, 112)
ax.grid(axis="y", alpha=0.3)
plt.setp(ax.get_xticklabels(), rotation=15, ha="right")
save(fig, "hit_rate.png")

# ---------------------------------------------------------------
# 2. Hit vs miss composition
# ---------------------------------------------------------------
fig, ax = plt.subplots(figsize=(9, 5))
ax.bar(workloads, hit_rates, label="Hit rate", color=HIT_COLOUR)
ax.bar(workloads, miss_rates, bottom=hit_rates,
       label="Miss rate", color=MISS_COLOUR)
ax.set_title("Cache Hit and Miss Rate Comparison")
ax.set_xlabel("Memory access pattern")
ax.set_ylabel("Percentage of references (%)")
ax.set_ylim(0, 105)
ax.legend()
ax.grid(axis="y", alpha=0.3)
plt.setp(ax.get_xticklabels(), rotation=15, ha="right")
save(fig, "hit_miss_comparison.png")

# ---------------------------------------------------------------
# 3. AMAT in cycles, with the hit-time floor marked
# ---------------------------------------------------------------
fig, ax = plt.subplots(figsize=(9, 5))
bars = ax.bar(workloads, amat_cycles, color=AMAT_COLOUR)
annotate(ax, bars, "{:.2f}")
ax.axhline(
    hit_time,
    color=BASE_COLOUR,
    linestyle="--",
    linewidth=1.5,
    label=f"hit time = {hit_time:.0f} cycles (ideal cache)",
)
ax.legend(loc="upper left", fontsize=9)
ax.set_title(
    f"Average Memory Access Time\n"
    f"AMAT = {hit_time:.0f} + MissRate x {miss_penalty:.0f} cycles"
)
ax.set_xlabel("Memory access pattern")
ax.set_ylabel("AMAT (clock cycles)")
ax.set_ylim(0, max(amat_cycles) * 1.35)
ax.grid(axis="y", alpha=0.3)
plt.setp(ax.get_xticklabels(), rotation=15, ha="right")
save(fig, "amat_cycles.png")

# ---------------------------------------------------------------
# 4. AMAT in nanoseconds, against the no-cache baseline
# ---------------------------------------------------------------
no_cache_ns = (hit_time + miss_penalty) * 10.0  # every access misses

fig, ax = plt.subplots(figsize=(9, 5))
bars = ax.bar(workloads, amat_ns, color=AMAT_COLOUR)
annotate(ax, bars, "{:.1f}")
ax.axhline(
    no_cache_ns,
    color=MISS_COLOUR,
    linestyle="--",
    linewidth=1.5,
    label=f"no cache = {no_cache_ns:.0f} ns per access",
)
ax.legend(loc="upper left", fontsize=9)
ax.set_title("Average Memory Access Time (10 ns clock)")
ax.set_xlabel("Memory access pattern")
ax.set_ylabel("AMAT (nanoseconds)")
ax.set_ylim(0, no_cache_ns * 1.35)
ax.grid(axis="y", alpha=0.3)
plt.setp(ax.get_xticklabels(), rotation=15, ha="right")
save(fig, "amat_nanoseconds.png")

# ---------------------------------------------------------------
# 5. Speedup over an uncached memory system
# ---------------------------------------------------------------
speedup = [no_cache_ns / value for value in amat_ns]

fig, ax = plt.subplots(figsize=(9, 5))
bars = ax.bar(workloads, speedup, color="#6A1B9A")
annotate(ax, bars, "{:.2f}x")
ax.axhline(1.0, color=BASE_COLOUR, linestyle="--", linewidth=1.5,
           label="no speedup (uncached)")
ax.legend(loc="upper right", fontsize=9)
ax.set_title("Speedup over an Uncached Memory System")
ax.set_xlabel("Memory access pattern")
ax.set_ylabel("Speedup (x)")
ax.set_ylim(0, max(speedup) * 1.25)
ax.grid(axis="y", alpha=0.3)
plt.setp(ax.get_xticklabels(), rotation=15, ha="right")
save(fig, "speedup.png")

# ---------------------------------------------------------------
# Console summary
# ---------------------------------------------------------------
print("=" * 72)
print(" CACHE PERFORMANCE SUMMARY")
print("=" * 72)
print(f" Hit time     : {hit_time:.2f} cycles")
print(f" Miss penalty : {miss_penalty:.2f} cycles")
print(f" AMAT         = HitTime + MissRate x MissPenalty")
print("-" * 72)
print(f"{'Workload':<16}{'Hit%':>8}{'Miss%':>8}"
      f"{'AMAT(cyc)':>12}{'AMAT(ns)':>11}{'Speedup':>10}")
print("-" * 72)
for name, hit, miss, cyc, ns, spd in zip(
        workloads, hit_rates, miss_rates, amat_cycles, amat_ns, speedup):
    print(f"{name:<16}{hit:>8.2f}{miss:>8.2f}"
          f"{cyc:>12.3f}{ns:>11.2f}{spd:>9.2f}x")
print("-" * 72)
print(f" Uncached baseline: {no_cache_ns:.0f} ns per access")
print("=" * 72)
print(" Graphs written to", OUTPUT_DIR)
for name in sorted(p.name for p in OUTPUT_DIR.glob("*.png")):
    print("  -", name)
