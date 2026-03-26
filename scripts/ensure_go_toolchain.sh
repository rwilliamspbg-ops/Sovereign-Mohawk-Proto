#!/usr/bin/env bash

set -euo pipefail

fail_toolchain() {
  local code="${1:-1}"
  if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    return "$code"
  fi
  exit "$code"
}

# Source this script before running Go commands to avoid mixed toolchain state
# (e.g., go=1.25.7 with compile=1.25.4 from /usr/local/go).

GO_BIN="$(command -v go)"
GO_BIN_DIR="$(cd "$(dirname "$GO_BIN")" && pwd)"
TOOLCHAIN_ROOT="$(cd "$GO_BIN_DIR/.." && pwd)"

if [[ -x "$TOOLCHAIN_ROOT/pkg/tool/$(go env GOOS)_$(go env GOARCH)/compile" ]]; then
  export GOROOT="$TOOLCHAIN_ROOT"
  export PATH="$GOROOT/bin:$PATH"
fi

export GOTOOLCHAIN="${GOTOOLCHAIN:-local}"

go_version="$(go env GOVERSION)"
compile_version="$("$(go env GOTOOLDIR)/compile" -V=full | grep -o 'go[0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?' | head -n1)"

if [[ "$go_version" != "$compile_version" ]]; then
  cat >&2 <<EOF
Go toolchain mismatch detected:
  go       : $go_version
  compile  : $compile_version
  GOROOT   : $(go env GOROOT)
  GOTOOLDIR: $(go env GOTOOLDIR)
EOF
  fail_toolchain 1
fi
