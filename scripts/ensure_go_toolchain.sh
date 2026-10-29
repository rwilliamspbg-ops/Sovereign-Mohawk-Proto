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

# `go` is a native Windows binary on MSYS/Git-Bash hosts. Given an MSYS-style
# GOROOT (/c/Program Files/Go) it cannot resolve its own stdlib or toolchain,
# concludes it must re-download one, and then dies with a misleading
# "verifying module: missing GOSUMDB" (or "GOPROXY list is not the empty
# string, but contains no entries") -- neither of which names the real cause.
# Convert GOROOT to a native Windows path before exporting it.
#
# On Linux/macOS cygpath is absent and TOOLCHAIN_ROOT is already a native
# absolute path, so this returns its input unchanged and CI is unaffected.
to_native_path() {
  # Only MSYS-style drive paths (/c/..., /d/...) need converting. A POSIX path
  # like /usr/local/go is already what native Go expects, so leave it alone even
  # if cygpath happens to be installed -- converting it would BREAK Linux CI.
  case "$1" in
    /[A-Za-z]/*) ;;
    *) printf '%s' "$1"; return 0 ;;
  esac
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1" 2>/dev/null || printf '%s' "$1"
  else
    printf '%s' "$1"
  fi
}

required_go_version="$(awk '/^toolchain[[:space:]]+/ {print $2; exit}' go.mod 2>/dev/null || true)"
if [[ -z "$required_go_version" ]]; then
  required_go_version="$(awk '/^go[[:space:]]+/ {print $2; exit}' go.mod 2>/dev/null || true)"
fi
required_go_version="${required_go_version:-1.25.9}"
required_go_version="${required_go_version#go}"

# Same MSYS-vs-native problem as GOROOT below: on Git-Bash $HOME is /c/Users/x,
# so the default cache path is POSIX-absolute but not Windows-absolute. Native Go
# rejects it ("GOCACHE is not an absolute path") and silently falls back to
# GOCACHE=off, which disables the build cache entirely and recompiles every
# package on every run. Convert it. An explicit GOCACHE from the caller is
# already in whatever form that caller intended, so pass it through untouched.
if [[ -n "${GOCACHE:-}" ]]; then
  cache_root="$GOCACHE"
else
  cache_root="$(to_native_path "$HOME/.cache/go-build")"
fi
cache_marker="${cache_root}/.toolchain-go${required_go_version}"
if [[ ! -f "$cache_marker" ]]; then
  rm -rf "$cache_root"
  mkdir -p "$cache_root"
  touch "$cache_marker"
fi
export GOCACHE="$cache_root"

GO_BIN="$(command -v go)"
GO_BIN_DIR="$(cd "$(dirname "$GO_BIN")" && pwd)"
TOOLCHAIN_ROOT="$(cd "$GO_BIN_DIR/.." && pwd)"

if [[ -x "$TOOLCHAIN_ROOT/pkg/tool/$(go env GOOS)_$(go env GOARCH)/compile" ]]; then
  export GOROOT="$(to_native_path "$TOOLCHAIN_ROOT")"
  export PATH="$TOOLCHAIN_ROOT/bin:$PATH"
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
