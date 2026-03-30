#!/usr/bin/env bash
set -euo pipefail

BENCH_TIME="${BENCH_TIME:-200ms}"
BENCH_COUNT="${BENCH_COUNT:-5}"
BENCHSTAT_ALPHA="${BENCHSTAT_ALPHA:-0.01}"
REPORT_PATH="${REPORT_PATH:-results/metrics/bridge_compression_benchmark_compare.md}"
RAW_PATH="${RAW_PATH:-results/metrics/bridge_compression_benchmark_raw.txt}"
USE_DOCKER="${USE_DOCKER:-1}"
GO_IMAGE="${GO_IMAGE:-golang:1.25.7}"

mkdir -p "$(dirname "$REPORT_PATH")"
mkdir -p "$(dirname "$RAW_PATH")"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

JSON_RAW="$TMP_DIR/json_raw.txt"
ZERO_RAW="$TMP_DIR/zero_raw.txt"
JSON_NORM="$TMP_DIR/json_norm.txt"
ZERO_NORM="$TMP_DIR/zero_norm.txt"
BENCHSTAT_TXT="$TMP_DIR/benchstat.txt"

run_go_bench() {
  local bench_regex="$1"
  local out_file="$2"
  if [[ "$USE_DOCKER" == "1" ]]; then
    docker run --rm -v "$PWD":/src -w /src "$GO_IMAGE" sh -lc \
      "/usr/local/go/bin/go test ./internal/pyapi -run '^$' -bench '${bench_regex}' -benchmem -benchtime=${BENCH_TIME} -count=${BENCH_COUNT}" \
      > "$out_file"
  else
    go test ./internal/pyapi -run '^$' -bench "$bench_regex" -benchmem -benchtime="$BENCH_TIME" -count="$BENCH_COUNT" > "$out_file"
  fi
}

run_go_bench '^BenchmarkCompressGradientsJSON$' "$JSON_RAW"
run_go_bench '^BenchmarkCompressGradientsZeroCopy$' "$ZERO_RAW"

cat "$JSON_RAW" "$ZERO_RAW" > "$RAW_PATH"

sed -E 's/BenchmarkCompressGradientsJSON/BenchmarkCompressGradientsFormat/' "$JSON_RAW" > "$JSON_NORM"
sed -E 's/BenchmarkCompressGradientsZeroCopy/BenchmarkCompressGradientsFormat/' "$ZERO_RAW" > "$ZERO_NORM"

if command -v benchstat >/dev/null 2>&1; then
  benchstat -alpha "$BENCHSTAT_ALPHA" "$JSON_NORM" "$ZERO_NORM" > "$BENCHSTAT_TXT"
else
  printf "benchstat not found in PATH; install with: go install golang.org/x/perf/cmd/benchstat@latest\n" > "$BENCHSTAT_TXT"
fi
python3 - "$JSON_RAW" "$ZERO_RAW" "$BENCHSTAT_TXT" "$REPORT_PATH" "$BENCH_TIME" "$BENCH_COUNT" "$BENCHSTAT_ALPHA" <<'PY'
import re
import sys
from pathlib import Path
from statistics import mean, stdev

json_raw_path = Path(sys.argv[1])
zero_raw_path = Path(sys.argv[2])
benchstat_path = Path(sys.argv[3])
report_path = Path(sys.argv[4])
bench_time = sys.argv[5]
bench_count = int(sys.argv[6])
benchstat_alpha = sys.argv[7]

pattern = re.compile(
    r"^BenchmarkCompressGradients(?P<kind>JSON|ZeroCopy)/dim(?P<dim>\d+)-\d+\s+(?P<n>\d+)\s+(?P<ns>[0-9.]+)\s+ns/op\s+(?P<bop>[0-9.]+)\s+B/op\s+(?P<alloc>[0-9.]+)\s+allocs/op"
)

def parse(path: Path):
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        m = pattern.match(line.strip())
        if not m:
            continue
        dim = int(m.group("dim"))
        kind = m.group("kind")
        out.setdefault(dim, {}).setdefault(kind, {"ns": [], "bop": [], "alloc": [], "n": []})
        out[dim][kind]["ns"].append(float(m.group("ns")))
        out[dim][kind]["bop"].append(float(m.group("bop")))
        out[dim][kind]["alloc"].append(float(m.group("alloc")))
        out[dim][kind]["n"].append(float(m.group("n")))
    return out

def agg(values):
    if not values:
        return None, None
    if len(values) == 1:
        return values[0], 0.0
    return mean(values), stdev(values)

json_data = parse(json_raw_path)
zero_data = parse(zero_raw_path)
results = {}
for dim in set(json_data.keys()) | set(zero_data.keys()):
    results[dim] = {}
    if dim in json_data and "JSON" in json_data[dim]:
        results[dim]["JSON"] = json_data[dim]["JSON"]
    if dim in zero_data and "ZeroCopy" in zero_data[dim]:
        results[dim]["ZeroCopy"] = zero_data[dim]["ZeroCopy"]

rows = []
for dim in sorted(results):
    row = results[dim]
    j = row.get("JSON", {})
    z = row.get("ZeroCopy", {})
    j_ns_mean, j_ns_sd = agg(j.get("ns", []))
    z_ns_mean, z_ns_sd = agg(z.get("ns", []))
    j_alloc_mean, _ = agg(j.get("alloc", []))
    z_alloc_mean, _ = agg(z.get("alloc", []))
    speedup = (j_ns_mean / z_ns_mean) if (j_ns_mean is not None and z_ns_mean is not None and z_ns_mean > 0) else None
    alloc_reduction = (j_alloc_mean / z_alloc_mean) if (j_alloc_mean is not None and z_alloc_mean is not None and z_alloc_mean > 0) else None
    rows.append((dim, j_ns_mean, j_ns_sd, z_ns_mean, z_ns_sd, speedup, j_alloc_mean, z_alloc_mean, alloc_reduction))

benchstat_text = benchstat_path.read_text(encoding="utf-8").rstrip()

lines = []
lines.append("# Bridge Serialization Format Compare")
lines.append("")
lines.append("Comparison type: JSON vs zero-copy format comparison on the same commit (not cross-commit regression)")
lines.append("Base ref: N/A")
lines.append(f"Benchmark window: {bench_time}")
lines.append(f"Sample count per format: {bench_count}")
lines.append(f"Benchstat alpha: {benchstat_alpha}")
lines.append("")
lines.append("| Dimension | JSON ns/op (mean +- sd) | Zero-copy ns/op (mean +- sd) | Speedup (x) | JSON allocs/op | Zero-copy allocs/op | Alloc reduction (x) |")
lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: |")
if not rows:
    lines.append("| (no benchmark rows found) | - | - | - | - | - | - |")
else:
    for dim, j, jsd, z, zsd, s, ja, za, ar in rows:
        jv = f"{j:.0f} +- {jsd:.0f}" if j is not None else "NA"
        zv = f"{z:.0f} +- {zsd:.0f}" if z is not None else "NA"
        sv = f"{s:.2f}" if s is not None else "NA"
        jav = f"{ja:.0f}" if ja is not None else "NA"
        zav = f"{za:.0f}" if za is not None else "NA"
        arv = f"{ar:.2f}" if ar is not None else "NA"
        lines.append(f"| {dim} | {jv} | {zv} | {sv} | {jav} | {zav} | {arv} |")

lines.append("")
lines.append("## Statistical Significance (benchstat)")
lines.append("")
lines.append("```text")
lines.append(benchstat_text)
lines.append("```")

report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"wrote bridge compression benchmark report to {report_path}")
PY

echo "wrote raw benchmark output to $RAW_PATH"
