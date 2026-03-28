#!/usr/bin/env bash
set -euo pipefail

BENCH_TIME="${BENCH_TIME:-200ms}"
REPORT_PATH="${REPORT_PATH:-results/metrics/bridge_compression_benchmark_compare.md}"
RAW_PATH="${RAW_PATH:-results/metrics/bridge_compression_benchmark_raw.txt}"
USE_DOCKER="${USE_DOCKER:-1}"
GO_IMAGE="${GO_IMAGE:-golang:1.25.7}"

mkdir -p "$(dirname "$REPORT_PATH")"
mkdir -p "$(dirname "$RAW_PATH")"

if [[ "$USE_DOCKER" == "1" ]]; then
  docker run --rm -v "$PWD":/src -w /src "$GO_IMAGE" sh -lc \
    "/usr/local/go/bin/go test ./internal/pyapi -run '^$' -bench 'BenchmarkCompressGradients(JSON|ZeroCopy)' -benchmem -benchtime=${BENCH_TIME}" \
    > "$RAW_PATH"
else
  go test ./internal/pyapi -run '^$' -bench 'BenchmarkCompressGradients(JSON|ZeroCopy)' -benchmem -benchtime="$BENCH_TIME" > "$RAW_PATH"
fi

python3 - "$RAW_PATH" "$REPORT_PATH" "$BENCH_TIME" <<'PY'
import re
import sys
from pathlib import Path

raw_path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
bench_time = sys.argv[3]

pattern = re.compile(
    r"^BenchmarkCompressGradients(?P<kind>JSON|ZeroCopy)/dim(?P<dim>\d+)-\d+\s+\d+\s+(?P<ns>[0-9.]+)\s+ns/op"
)

results = {}
for line in raw_path.read_text(encoding="utf-8").splitlines():
    m = pattern.match(line.strip())
    if not m:
        continue
    dim = int(m.group("dim"))
    kind = m.group("kind")
    ns = float(m.group("ns"))
    results.setdefault(dim, {})[kind] = ns

rows = []
for dim in sorted(results):
    row = results[dim]
    j = row.get("JSON")
    z = row.get("ZeroCopy")
    speedup = (j / z) if (j is not None and z is not None and z > 0) else None
    rows.append((dim, j, z, speedup))

lines = []
lines.append("# Bridge Compression Benchmark Comparison")
lines.append("")
lines.append(f"Benchmark window: `{bench_time}`")
lines.append("")
lines.append("| Dimension | JSON ns/op | Zero-Copy ns/op | Speedup (x) |")
lines.append("| --- | ---: | ---: | ---: |")
if not rows:
    lines.append("| (no benchmark rows found) | - | - | - |")
else:
    for dim, j, z, s in rows:
        jv = f"{j:.0f}" if j is not None else "NA"
        zv = f"{z:.0f}" if z is not None else "NA"
        sv = f"{s:.2f}" if s is not None else "NA"
        lines.append(f"| {dim} | {jv} | {zv} | {sv} |")

report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"wrote bridge compression benchmark report to {report_path}")
PY

echo "wrote raw benchmark output to $RAW_PATH"
