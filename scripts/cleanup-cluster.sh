#!/bin/bash
# =============================================================================
# Cleanup Script - Remove existing k3d cluster and registry
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    🧹  Cleaning up k3d cluster          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"

# Check if running with sudo
K3D_CMD="k3d"
if ! docker ps &>/dev/null 2>&1; then
  echo -e "${YELLOW}⚠️  Using sudo for k3d commands${NC}"
  K3D_CMD="sudo k3d"
fi

# Delete cluster
if $K3D_CMD cluster list 2>/dev/null | grep -q "om-cluster"; then
  echo -e "${YELLOW}🗑️  Deleting k3d cluster 'om-cluster'...${NC}"
  $K3D_CMD cluster delete om-cluster
  echo -e "${GREEN}✅ Cluster deleted${NC}"
else
  echo -e "${BLUE}ℹ️  No cluster 'om-cluster' found${NC}"
fi

# Delete registry
if $K3D_CMD registry list 2>/dev/null | grep -q "om-registry"; then
  echo -e "${YELLOW}🗑️  Deleting k3d registry 'om-registry'...${NC}"
  $K3D_CMD registry delete om-registry
  echo -e "${GREEN}✅ Registry deleted${NC}"
else
  echo -e "${BLUE}ℹ️  No registry 'om-registry' found${NC}"
fi

# Clean up kubeconfig
if [ -f "${HOME}/.kube/config" ]; then
  echo -e "${YELLOW}🧹 Cleaning up kubeconfig...${NC}"
  # Backup first
  cp "${HOME}/.kube/config" "${HOME}/.kube/config.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
  # Remove om-cluster context
  kubectl config delete-context k3d-om-cluster 2>/dev/null || true
  kubectl config delete-cluster k3d-om-cluster 2>/dev/null || true
  kubectl config delete-user admin@k3d-om-cluster 2>/dev/null || true
  echo -e "${GREEN}✅ Kubeconfig cleaned${NC}"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✨  Cleanup complete!                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Verify your config: ${YELLOW}configs/secrets-templates/backstage-secrets.env${NC}"
echo -e "  2. Run deployment: ${YELLOW}./scripts/platform-up-v2.sh${NC}"
echo ""
