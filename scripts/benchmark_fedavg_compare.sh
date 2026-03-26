#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_REF="${BASE_REF:-HEAD~1}"
BENCH_TIME="${BENCH_TIME:-200ms}"
BENCH_COUNT="${BENCH_COUNT:-1}"
GO_TEST_TARGET="${GO_TEST_TARGET:-./test}"
BENCH_REGEX="${BENCH_REGEX:-BenchmarkAggregateParallel}"
REPORT_PATH="${REPORT_PATH:-results/metrics/fedavg_benchmark_compare.md}"

if [[ -n "${TOOLROOT:-}" ]]; then
  export GOROOT="$TOOLROOT"
  export PATH="$TOOLROOT/bin:$PATH"
  export GOTOOLCHAIN="${GOTOOLCHAIN:-local}"
fi

if ! git -C "$ROOT_DIR" rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "error: base ref '$BASE_REF' not found"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
BASE_WORKTREE="$TMP_DIR/base"
BASE_OUT="$TMP_DIR/base_bench.txt"
CURR_OUT="$TMP_DIR/current_bench.txt"
BASE_TSV="$TMP_DIR/base.tsv"
CURR_TSV="$TMP_DIR/current.tsv"
JOINED_TSV="$TMP_DIR/joined.tsv"

cleanup() {
  git -C "$ROOT_DIR" worktree remove --force "$BASE_WORKTREE" >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

git -C "$ROOT_DIR" worktree add --quiet --detach "$BASE_WORKTREE" "$BASE_REF"

run_bench() {
  local repo_dir="$1"
  local out_file="$2"
  (
    cd "$repo_dir"
    go test "$GO_TEST_TARGET" -run '^$' -bench "$BENCH_REGEX" -benchmem -benchtime="$BENCH_TIME" -count "$BENCH_COUNT"
  ) | tee "$out_file"
}

run_bench "$BASE_WORKTREE" "$BASE_OUT"
run_bench "$ROOT_DIR" "$CURR_OUT"

aggregate_bench_ns() {
  local in_file="$1"
  local out_file="$2"
  awk '
    /^BenchmarkAggregateParallel\// {
      sum[$1] += $3
      cnt[$1] += 1
    }
    END {
      for (k in sum) {
        printf "%s\t%.0f\n", k, (sum[k] / cnt[k])
      }
    }
  ' "$in_file" | sort > "$out_file"
}

aggregate_bench_ns "$BASE_OUT" "$BASE_TSV"
aggregate_bench_ns "$CURR_OUT" "$CURR_TSV"

join -t $'\t' -a1 -a2 -e "NA" -o 0,1.2,2.2 "$BASE_TSV" "$CURR_TSV" > "$JOINED_TSV" || true

mkdir -p "$(dirname "$ROOT_DIR/$REPORT_PATH")"

{
  echo "# FedAvg Benchmark Comparison"
  echo
  echo "- Base ref: $BASE_REF"
  echo "- Benchtime: $BENCH_TIME"
  echo "- Count: $BENCH_COUNT"
  echo "- Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo
  echo "| Benchmark | Base ns/op | Current ns/op | Speedup (x) | Delta % |"
  echo "|---|---:|---:|---:|---:|"

  if [[ ! -s "$JOINED_TSV" ]]; then
    echo "| (no benchmark rows found) | - | - | - | - |"
  else
    while IFS=$'\t' read -r name base_ns curr_ns; do
      if [[ "$base_ns" == "NA" || "$curr_ns" == "NA" ]]; then
        speedup="-"
        delta="-"
      else
        speedup="$(awk -v b="$base_ns" -v c="$curr_ns" 'BEGIN { if (c == 0) { print "inf" } else { printf "%.2f", b/c } }')"
        delta="$(awk -v b="$base_ns" -v c="$curr_ns" 'BEGIN { if (b == 0) { print "0.00" } else { printf "%.2f", ((c-b)/b)*100 } }')"
      fi
      echo "| $name | $base_ns | $curr_ns | $speedup | $delta |"
    done < "$JOINED_TSV"
  fi
} > "$ROOT_DIR/$REPORT_PATH"

echo "wrote benchmark comparison report to $REPORT_PATH"