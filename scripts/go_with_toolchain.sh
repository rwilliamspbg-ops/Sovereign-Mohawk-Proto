#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT_DIR/scripts/ensure_go_toolchain.sh"

if [[ $# -eq 0 ]]; then
  echo "go: $(go env GOVERSION)"
  echo "goroot: $(go env GOROOT)"
  echo "gotooldir: $(go env GOTOOLDIR)"
  exit 0
fi

exec "$@"