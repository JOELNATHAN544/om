#!/usr/bin/env bash
set -euo pipefail

BACKSTAGE_DOMAIN="${BACKSTAGE_DOMAIN:-portal.backstage.com}"
ARGOCD_DOMAIN="${ARGOCD_DOMAIN:-argocd.backstage.com}"

MODE="${1:-}"
RESTART_BACKSTAGE=false
RESTART_COREDNS=false

for arg in "$@"; do
  case "${arg}" in
    --print|--apply)
      MODE="${arg}"
      ;;
    --restart-backstage)
      RESTART_BACKSTAGE=true
      ;;
    --restart-coredns)
      RESTART_COREDNS=true
      ;;
  esac
done

TRAEFIK_IP=$(kubectl -n kube-system get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
if [[ -z "${TRAEFIK_IP}" ]]; then
  echo "Traefik EXTERNAL-IP not found. Is the cluster running?"
  exit 1
fi

ENTRY="${TRAEFIK_IP} ${BACKSTAGE_DOMAIN} ${ARGOCD_DOMAIN}"

if [[ "${1:-}" == "--print" ]]; then
  echo "${ENTRY}"
  exit 0
fi

if [[ -z "${MODE}" ]]; then
  echo "${ENTRY}"
  exit 0
fi

if [[ "${MODE}" != "--apply" ]]; then
  echo "Usage: $0 [--print] | --apply [--restart-backstage] [--restart-coredns]"
  echo ""
  echo "--print  Prints the /etc/hosts entry you should have"
  echo "--apply  Updates /etc/hosts (removes old entries for the domains, then adds the current one)"
  echo "--restart-backstage  Restarts Backstage after updating /etc/hosts"
  echo "--restart-coredns    Restarts CoreDNS after updating /etc/hosts"
  exit 2
fi

TMP=$(mktemp)
trap 'rm -f "${TMP}"' EXIT

# Remove any previous mappings for these domains (including malformed duplicates)
awk -v b="${BACKSTAGE_DOMAIN}" -v a="${ARGOCD_DOMAIN}" '
  {
    for (i = 1; i <= NF; i++) {
      if ($i == b || $i == a) next
    }
    print
  }
' /etc/hosts > "${TMP}"

printf "%s\n" "${ENTRY}" >> "${TMP}"

cp "${TMP}" /etc/hosts

echo "Updated /etc/hosts with: ${ENTRY}"

if [[ "${RESTART_COREDNS}" == "true" ]]; then
  if kubectl -n kube-system get deploy coredns >/dev/null 2>&1; then
    kubectl -n kube-system rollout restart deploy/coredns >/dev/null
    kubectl -n kube-system rollout status deploy/coredns --timeout=5m >/dev/null || true
    echo "Restarted CoreDNS"
  else
    echo "CoreDNS deployment not found (skipping)"
  fi
fi

if [[ "${RESTART_BACKSTAGE}" == "true" ]]; then
  if kubectl -n backstage get deploy backstage >/dev/null 2>&1; then
    kubectl -n backstage rollout restart deploy/backstage >/dev/null
    kubectl -n backstage rollout status deploy/backstage --timeout=10m >/dev/null || true
    echo "Restarted Backstage"
  else
    echo "Backstage deployment not found (skipping)"
  fi
fi
