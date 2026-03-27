#!/usr/bin/env bash
set -euo pipefail

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  exec docker compose "$@"
fi

if command -v docker-compose >/dev/null 2>&1; then
  exec docker-compose "$@"
fi

cat >&2 <<'EOF'
No Docker Compose command found.

Install either:
- Docker Compose v2 plugin (docker compose)
- docker-compose v1 binary (docker-compose)
EOF
exit 127