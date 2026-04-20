#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_TAG="${FORMAL_VERIFIER_IMAGE_TAG:-sovereign-mohawk/formal-verifier:lean4-v4.30.0-rc2-go1.25.9}"

cd "$ROOT_DIR"

echo "Building formal verifier container image: $IMAGE_TAG"
docker build -t "$IMAGE_TAG" -f docker/formal-verifier/Dockerfile .

echo "Running reproducible formal validation in container"
docker run --rm \
  -v "$ROOT_DIR":/workspace \
  -w /workspace \
  "$IMAGE_TAG" \
  bash -lc "make validate-formal"
