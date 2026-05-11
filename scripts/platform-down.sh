#!/bin/bash

# =============================================================================
# OM Platform - Universal Teardown Script
# =============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}⚠️  WARNING: This will delete the entire OM Platform cluster and all resources.${NC}"
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

set +e

# 1. Delete K3d Cluster
if k3d cluster list | grep -q "om-cluster"; then
    echo -e "${BLUE}🗑️  Deleting K3d Cluster: om-cluster...${NC}"
    k3d cluster delete om-cluster
else
    echo -e "${GREEN}✅ No cluster found named om-cluster.${NC}"
fi

# 2. Delete K3d Registry (if created)
if k3d registry list 2>/dev/null | grep -q "om-registry"; then
    echo -e "${BLUE}🗑️  Deleting K3d Registry: om-registry...${NC}"
    k3d registry delete om-registry
else
    echo -e "${GREEN}✅ No registry found named om-registry.${NC}"
fi

# 3. Cleanup local files if any
echo -e "${BLUE}🧹 Cleaning up local cache...${NC}"
rm -rf platform/portal/backstage/dist

echo -e "${GREEN}✅ Platform successfully torn down.${NC}"
