#!/usr/bin/env bash

set -euo pipefail

# Source this script before running Go commands to avoid mixed toolchain state
# (e.g., go=1.25.9 with compile=1.25.4 from /usr/local/go).

version_lt() {
  local a="$1"
  local b="$2"
  local a_major a_minor a_patch b_major b_minor b_patch

  IFS='.' read -r a_major a_minor a_patch <<<"${a}"
  IFS='.' read -r b_major b_minor b_patch <<<"${b}"

  a_patch="${a_patch:-0}"
  b_patch="${b_patch:-0}"

  ((10#${a_major} < 10#${b_major})) && return 0
  ((10#${a_major} > 10#${b_major})) && return 1
  ((10#${a_minor} < 10#${b_minor})) && return 0
  ((10#${a_minor} > 10#${b_minor})) && return 1
  ((10#${a_patch} < 10#${b_patch})) && return 0
  return 1
}

normalize_uname_arch() {
  case "$(uname -m)" in
    x86_64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) echo "$(uname -m)" ;;
  esac
}

required_go_version="$(awk '/^toolchain[[:space:]]+/ {print $2; exit}' go.mod 2>/dev/null || true)"
if [[ -z "$required_go_version" ]]; then
  required_go_version="$(awk '/^go[[:space:]]+/ {print $2; exit}' go.mod 2>/dev/null || true)"
fi
required_go_version="${required_go_version:-1.25.9}"
required_go_version="${required_go_version#go}"

GO_BIN="$(command -v go)"
GO_BIN_DIR="$(cd "$(dirname "$GO_BIN")" && pwd)"
TOOLCHAIN_ROOT="$(cd "$GO_BIN_DIR/.." && pwd)"

if [[ -x "$TOOLCHAIN_ROOT/pkg/tool/$(go env GOOS)_$(go env GOARCH)/compile" ]]; then
  export GOROOT="$TOOLCHAIN_ROOT"
  export PATH="$GOROOT/bin:$PATH"
fi

current_go_version_raw="$(GOTOOLCHAIN=local go env GOVERSION 2>/dev/null || true)"
current_go_version="${current_go_version_raw#go}"
arch="$(normalize_uname_arch)"
toolchain_cache="/go/pkg/mod/golang.org/toolchain@v0.0.1-go${required_go_version}.linux-${arch}"

current_compile_version=""
if [[ -x "$(go env GOTOOLDIR 2>/dev/null)/compile" ]]; then
  current_compile_version="$("$(go env GOTOOLDIR)/compile" -V=full | grep -o 'go[0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?' | head -n1 || true)"
fi

if [[ -n "$current_go_version" ]] && version_lt "$current_go_version" "$required_go_version"; then
  if [[ -x "$toolchain_cache/bin/go" ]]; then
    export GOROOT="$toolchain_cache"
    export PATH="$GOROOT/bin:$PATH"
    export GOTOOLCHAIN="local"
  else
    # Force selection of the required toolchain and allow auto-updates beyond it.
    export GOTOOLCHAIN="go${required_go_version}+auto"
  fi
else
  export GOTOOLCHAIN="${GOTOOLCHAIN:-go${required_go_version}+auto}"
fi

# If the system Go install reports matching version but has stale/mixed compiler
# artifacts, force the cached required toolchain to restore consistency.
if [[ -x "$toolchain_cache/bin/go" ]] && [[ -n "$current_compile_version" ]] && [[ "$current_go_version_raw" != "$current_compile_version" ]]; then
  export GOROOT="$toolchain_cache"
  export PATH="$GOROOT/bin:$PATH"
  export GOTOOLCHAIN="local"
fi

go_version="$(go env GOVERSION)"
compile_version="$("$(go env GOTOOLDIR)/compile" -V=full | grep -o 'go[0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?' | head -n1)"

if version_lt "${go_version#go}" "$required_go_version"; then
  cat >&2 <<EOF
Go toolchain too old for this repository:
  required : go$required_go_version
  detected : $go_version
  GOROOT   : $(go env GOROOT)
EOF
  if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    return 1
  fi
  exit 1
fi

if [[ "$go_version" != "$compile_version" ]]; then
  cat >&2 <<EOF
Go toolchain mismatch detected:
  go       : $go_version
  compile  : $compile_version
  GOROOT   : $(go env GOROOT)
  GOTOOLDIR: $(go env GOTOOLDIR)
EOF
  if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    return 1
  fi
  exit 1
fi
