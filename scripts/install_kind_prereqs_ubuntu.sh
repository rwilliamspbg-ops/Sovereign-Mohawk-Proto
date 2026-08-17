#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "$INSTALL_DIR"
export PATH="$INSTALL_DIR:$PATH"

if ! command -v curl >/dev/null 2>&1; then
  echo "[install] installing curl"
  if command -v apt-get >/dev/null 2>&1; then
    if [[ "$EUID" -eq 0 ]]; then
      apt-get update
      apt-get install -y curl ca-certificates
    else
      echo "error: this environment cannot install curl without root or sudo access" >&2
      exit 1
    fi
  else
    echo "error: curl is required and no apt-get is available" >&2
    exit 1
  fi
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "[install] docker is required but not available in this restricted environment"
  echo "install docker manually or run this on a Docker-capable host"
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[install] installing kubectl locally"
  curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  install -m 0755 /tmp/kubectl "$INSTALL_DIR/kubectl"
fi

if ! command -v kind >/dev/null 2>&1; then
  echo "[install] installing kind locally"
  curl -fsSL -o /tmp/kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
  install -m 0755 /tmp/kind "$INSTALL_DIR/kind"
fi

echo "[install] prerequisites ready: docker kubectl kind"
echo "[install] ensure this is in PATH: $INSTALL_DIR"
