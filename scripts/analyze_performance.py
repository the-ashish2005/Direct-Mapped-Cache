
import csv
from pathlib import Path

import matplotlib.pyplot as plt

# Project directory
ROOT = Path(__file__).resolve().parents[1]

# Input CSV file
CSV_FILE = ROOT / "results" / "performance.csv"

# Output directory
OUTPUT_DIR = ROOT / "results" / "graphs"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

if not CSV_FILE.exists():
    raise FileNotFoundError(
        f"Performance CSV not found: {CSV_FILE}"
    )

# Read simulation results
with CSV_FILE.open(newline="") as file:
    reader = csv.DictReader(file)
    rows = list(reader)

if not rows:
    raise ValueError("Performance CSV is empty")

workloads = [row["workload"] for row in rows]

hit_rates = [
    float(row["hit_rate"]) for row in rows
]

miss_rates = [
    float(row["miss_rate"]) for row in rows
]

avg_cycles = [
    float(row["avg_cycles"]) for row in rows
]

# ------------------------------------
# Graph 1: Cache Hit Rate
# ------------------------------------

plt.figure(figsize=(9, 5))

plt.bar(workloads, hit_rates)

plt.title("Direct-Mapped Cache: Hit Rate Comparison")
plt.xlabel("Memory Access Pattern")
plt.ylabel("Cache Hit Rate (%)")
plt.ylim(0, 105)

plt.tight_layout()

plt.savefig(
    OUTPUT_DIR / "hit_rate.png",
    dpi=300
)

plt.close()

# ------------------------------------
# Graph 2: Average Access Latency
# ------------------------------------

plt.figure(figsize=(9, 5))

plt.bar(workloads, avg_cycles)

plt.title("Direct-Mapped Cache: Access Latency")
plt.xlabel("Memory Access Pattern")
plt.ylabel("Average Response Latency (Cycles)")

plt.tight_layout()

plt.savefig(
    OUTPUT_DIR / "average_latency.png",
    dpi=300
)

plt.close()

# ------------------------------------
# Graph 3: Hit Rate vs Miss Rate
# ------------------------------------

plt.figure(figsize=(9, 5))

plt.bar(workloads, hit_rates, label="Hit Rate")
plt.bar(
    workloads,
    miss_rates,
    bottom=hit_rates,
    label="Miss Rate"
)

plt.title("Cache Hit and Miss Rate Comparison")
plt.xlabel("Memory Access Pattern")
plt.ylabel("Percentage (%)")
plt.ylim(0, 105)
plt.legend()

plt.tight_layout()

plt.savefig(
    OUTPUT_DIR / "hit_miss_comparison.png",
    dpi=300
)

plt.close()

print("====================================")
print(" PERFORMANCE GRAPHS GENERATED")
print("====================================")

for name in [
    "hit_rate.png",
    "average_latency.png",
    "hit_miss_comparison.png"
]:
    print(OUTPUT_DIR / name)
