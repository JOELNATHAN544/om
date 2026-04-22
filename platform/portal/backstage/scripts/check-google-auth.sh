#!/usr/bin/env bash
set -euo pipefail

backend_url="${BACKEND_URL:-http://localhost:7007}"

echo "Backstage Google auth preflight"
echo "Backend URL: ${backend_url}"
echo "Shell: ${SHELL:-unknown} (argv0: ${0})"
echo "Interactive: $([[ $- == *i* ]] && echo yes || echo no)"
echo

if [[ -n "${GOOGLE_CLIENT_ID:-}" ]]; then
  echo "GOOGLE_CLIENT_ID: set (len=${#GOOGLE_CLIENT_ID})"
else
  echo "GOOGLE_CLIENT_ID: MISSING"
fi

if [[ -n "${GOOGLE_CLIENT_SECRET:-}" ]]; then
  echo "GOOGLE_CLIENT_SECRET: set (len=${#GOOGLE_CLIENT_SECRET})"
else
  echo "GOOGLE_CLIENT_SECRET: MISSING"
fi

echo
echo "Checking backend auth route (should be 302 or 400, not 404):"
if ! command -v curl >/dev/null 2>&1; then
  echo "curl: MISSING (install curl, or manually open ${backend_url}/api/auth/google/start in the browser)"
  exit 2
fi
status="$(
  curl -sS -o /dev/null -w "%{http_code}" \
    "${backend_url}/api/auth/google/start?scope=openid%20email%20profile"
)"
echo "GET /api/auth/google/start => ${status}"

if [[ "${status}" == "404" ]]; then
  echo
  echo "404 means the backend did not register the Google auth provider."
  echo "Most common cause: GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET not set when backend started."
  exit 1
fi
