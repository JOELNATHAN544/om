#!/bin/bash
# =============================================================================
# Fix Stuck Backstage Deployment
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    🔧  Fixing Stuck Deployment           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"

# 1. Cancel the stuck Helm operation
echo -e "${YELLOW}1. Cancelling stuck Helm operation...${NC}"
pkill -f "helm upgrade" || true
sleep 2

# 2. Check current pod status
echo -e "${BLUE}2. Current pod status:${NC}"
kubectl get pods -n backstage

# 3. Fix PostgreSQL ImagePullBackOff
echo -e "${YELLOW}3. Fixing PostgreSQL pod...${NC}"
kubectl delete pod -l app.kubernetes.io/name=postgresql -n backstage --force --grace-period=0 || true
sleep 5

# 4. Update PostgreSQL StatefulSet with correct image
echo -e "${YELLOW}4. Updating PostgreSQL configuration...${NC}"
kubectl patch statefulset backstage-postgresql -n backstage --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/image",
    "value": "docker.io/bitnami/postgresql:15"
  }
]' || echo "StatefulSet patch failed, will try Helm upgrade"

# 5. Wait for PostgreSQL
echo -e "${BLUE}5. Waiting for PostgreSQL to start...${NC}"
sleep 10
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n backstage --timeout=300s || {
  echo -e "${RED}PostgreSQL still failing. Checking details:${NC}"
  kubectl describe pod -l app.kubernetes.io/name=postgresql -n backstage | tail -100
  kubectl get events -n backstage --sort-by='.lastTimestamp' | tail -20
  exit 1
}

echo -e "${GREEN}✅ PostgreSQL is now running!${NC}"

# 6. Check Backstage pod
echo -e "${BLUE}6. Checking Backstage pod...${NC}"
kubectl get pods -n backstage

# 7. Wait for Backstage
echo -e "${BLUE}7. Waiting for Backstage to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=backstage -n backstage --timeout=300s || {
  echo -e "${YELLOW}Backstage not ready yet. Checking logs:${NC}"
  kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=50
}

# 8. Final status
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅  Deployment Fixed!                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
kubectl get pods -n backstage
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Add to /etc/hosts: 127.0.0.1  portal.backstage.com"
echo -e "  2. Access: https://portal.backstage.com"
