#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

backend_port="${BACKEND_PORT:-7007}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

if command -v ss >/dev/null 2>&1; then
  if ss -ltn "sport = :${backend_port}" | tail -n +2 | grep -q .; then
    echo "Port ${backend_port} is already in use. Stop the existing Backstage backend first."
    ss -lptn "sport = :${backend_port}" || true
    exit 1
  fi
fi

if [[ -z "${GOOGLE_CLIENT_ID:-}" || -z "${GOOGLE_CLIENT_SECRET:-}" ]]; then
  echo "Warning: GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET not set; Google auth routes may be skipped."
fi

exec yarn start
