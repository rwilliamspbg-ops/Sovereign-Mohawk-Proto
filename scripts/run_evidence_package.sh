#!/usr/bin/env bash
# run_evidence_package.sh — one entry point for the reproducible evidence package.
#
# Runs every evidence-producing stage into a single timestamped directory, then
# verifies that each stage actually produced its artifact and writes a SHA256
# manifest with a Merkle root over the whole package.
#
# See docs/EVIDENCE_PACKAGE.md for the full guide (prerequisites, stage details,
# interpreting the outputs, troubleshooting).
#
# Usage:
#   bash scripts/run_evidence_package.sh                     # everything that fits this host
#   bash scripts/run_evidence_package.sh --skip-kind         # explicit: no Kind scale stage
#   bash scripts/run_evidence_package.sh --stages zk-bench,zk-round,formal,manifest
#   bash scripts/run_evidence_package.sh --out results/evidence-package
#   bash scripts/run_evidence_package.sh --strict            # any skipped stage fails
#
# Exit code is non-zero if a stage fails or a required artifact is missing.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="${OUT_DIR:-$ROOT_DIR/results/evidence-package}"
STAGES="${STAGES:-zk-bench,zk-round,scale,dp,formal,manifest}"
SKIP_KIND=0
STRICT=0

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)     OUT_DIR="$2"; shift 2 ;;
    --stages)  STAGES="$2"; shift 2 ;;
    --skip-kind) SKIP_KIND=1; shift ;;
    --strict)  STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
  fi
}

stage_enabled() { [[ ",$STAGES," == *",$1,"* ]]; }

ARTIFACTS=()
add_artifact() { ARTIFACTS+=("$1"); }

mkdir -p "$OUT_DIR"
PACKAGE_DIR="$OUT_DIR/run-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$PACKAGE_DIR"
echo "[package] output directory: $PACKAGE_DIR"
echo "[package] stages: $STAGES"

# ---------------------------------------------------------------- stage: zk-bench
stage_zk_bench() {
  require_cmd go
  mkdir -p "$PACKAGE_DIR/zk"
  go run ./cmd/zkweightbench -out "$PACKAGE_DIR/zk" 2>&1 | tee "$PACKAGE_DIR/zk-bench.log"
  add_artifact "zk/weight-proof-latest.json"
  add_artifact "zk-bench.log"
}

# ---------------------------------------------------------------- stage: zk-round
# End-to-end round: build a witness, prove it, let the aggregator verify it.
stage_zk_round() {
  require_cmd go
  go run ./cmd/simulate 2>&1 | tee "$PACKAGE_DIR/zk-round.log" \
    | grep -vE '^[0-9]{2}:[0-9]{2}:' || true
  add_artifact "zk-round.log"
}

# ---------------------------------------------------------------- stage: scale
# Hierarchical scale matrix on Kind. Requires kind + kubectl + docker.
stage_scale() {
  if [[ "$SKIP_KIND" -eq 1 ]]; then
    echo "[package] scale: skipped (--skip-kind)"
    return 0
  fi
  if ! command -v kind >/dev/null 2>&1; then
    echo "[package] scale: 'kind' not found on PATH." >&2
    if [[ "$STRICT" -eq 1 ]]; then
      echo "[package] scale: failing because --strict is set." >&2
      exit 1
    fi
    echo "[package] scale: skipping. Install kind, or pass --skip-kind explicitly." >&2
    return 0
  fi
  require_cmd kubectl
  mkdir -p "$PACKAGE_DIR/scale"
  OUT_DIR="$PACKAGE_DIR/scale" bash scripts/run_kind_scale_evidence.sh \
    2>&1 | tee "$PACKAGE_DIR/scale.log"
  add_artifact "scale.log"
}

# ---------------------------------------------------------------- stage: dp
# Differential-privacy budget accounting: run the accountant tests and record
# the composition parameters the run used.
stage_dp() {
  require_cmd go
  {
    echo "# RDP accountant evidence"
    echo "# date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# command: go test ./test/ -run TestRDPAccountant -v"
    echo
    go test ./test/ -run 'TestRDPAccountant' -v -count=1 2>&1
  } > "$PACKAGE_DIR/dp-accounting.log"
  add_artifact "dp-accounting.log"
}

# ---------------------------------------------------------------- stage: formal
# Formal validation report + tamper-evident bundle, then verify the bundle.
stage_formal() {
  require_cmd python3
  mkdir -p "$PACKAGE_DIR/formal"
  python3 scripts/ci/generate_formal_validation_report.py --repo-root . \
    2>&1 | tee "$PACKAGE_DIR/formal/generate.log"
  python3 scripts/ci/build_formal_verification_bundle.py \
    2>&1 | tee "$PACKAGE_DIR/formal/bundle.log"
  python3 scripts/ci/verify_formal_verification_bundle.py \
    2>&1 | tee "$PACKAGE_DIR/formal/verify.log"
  # Both scripts write to the repo's canonical results/proofs/ location, which is
  # what CI produces. Copy their outputs in so the package is self-contained and
  # byte-identical to the CI artifact.
  cp results/proofs/formal_validation_report.json "$PACKAGE_DIR/formal/"
  cp -r results/proofs/formal-verification-bundle "$PACKAGE_DIR/formal/"
  add_artifact "formal/formal_validation_report.json"
  add_artifact "formal/formal-verification-bundle/bundle_manifest.json"
}

# ---------------------------------------------------------------- stage: manifest
# Hash every artifact and write manifest.json with a Merkle-style root.
stage_manifest() {
  require_cmd python3
  python3 - "$PACKAGE_DIR" <<'PY'
import hashlib, json, sys
from pathlib import Path

pkg = Path(sys.argv[1])
entries = []
for p in sorted(pkg.rglob("*")):
    if not p.is_file() or p.name == "manifest.json":
        continue
    rel = p.relative_to(pkg).as_posix()
    h = hashlib.sha256(p.read_bytes()).hexdigest()
    entries.append({"path": rel, "sha256": h, "bytes": p.stat().st_size})

root = hashlib.sha256(
    "\n".join(f"{e['sha256']}  {e['path']}" for e in entries).encode()
).hexdigest()

manifest = {
    "package_dir": pkg.name,
    "file_count": len(entries),
    "merkle_root": root,
    "files": entries,
}
(pkg / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"[package] manifest: {len(entries)} files, root {root[:16]}…")
PY
  add_artifact "manifest.json"
}

# ---------------------------------------------------------------- dispatch
run_stage() {
  local name="$1"
  if ! stage_enabled "$name"; then
    echo "[package] --- $name: not requested"
    return 0
  fi
  local fn="stage_${name//-/_}"
  echo "[package] --- $name: start"
  "$fn"
  echo "[package] --- $name: done"
}

for s in zk-bench zk-round scale dp formal manifest; do
  run_stage "$s"
done

# ---------------------------------------------------------------- gate
echo "[package] verifying required artifacts"
MISSING=0
for rel in "${ARTIFACTS[@]}"; do
  if [[ ! -s "$PACKAGE_DIR/$rel" ]]; then
    echo "[package] MISSING: $rel" >&2
    MISSING=1
  fi
done
if [[ "$MISSING" -ne 0 ]]; then
  echo "[package] FAILED: one or more stages did not produce their artifact." >&2
  exit 1
fi

echo
echo "[package] OK"
echo "[package]   directory : $PACKAGE_DIR"
echo "[package]   manifest  : $PACKAGE_DIR/manifest.json"
echo "[package]   bytes     : $(du -sb "$PACKAGE_DIR" | awk '{print $1}')"
echo "[package] Next: commit $PACKAGE_DIR, or point a reviewer at manifest.json."
