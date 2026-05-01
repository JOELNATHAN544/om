#!/bin/bash
# =============================================================================
# OM Platform - Universal Bootstrap Script
# Supports: macOS (Homebrew), Ubuntu/Debian Linux
# Usage: ./scripts/platform-up.sh
# =============================================================================
set -euo pipefail

# --- Colors ------------------------------------------------------------------
GREEN='\033[0;32m'; BLUE='\033[0;34m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

# --- Paths (portable - no hardcoding /home/vagrant) --------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKSTAGE_DIR="${PROJECT_ROOT}/platform/portal/backstage"
HELM_VALUES="${PROJECT_ROOT}/helm/values/prod/backstage-values.yaml"

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    🚀  OM Platform Bootstrap Starting    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo -e "   Project Root: ${PROJECT_ROOT}"

# =============================================================================
# 1. Detect OS
# =============================================================================
OS="$(uname -s)"
case "${OS}" in
  Linux*)   DISTRO="Linux" ;;
  Darwin*)  DISTRO="Mac"   ;;
  *)        echo -e "${RED}❌ Unsupported OS: ${OS}${NC}"; exit 1 ;;
esac
echo -e "   OS Detected: ${GREEN}${DISTRO}${NC}"

# =============================================================================
# 2. Install Dependencies
# =============================================================================
install_docker_linux() {
  echo -e "${BLUE}🛠️  Installing Docker (official)...${NC}"
  # Remove old versions
  sudo apt-get remove -y docker.io docker-doc docker-compose podman-docker containerd runc 2>/dev/null || true
  # Install from official script
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "${USER}"
  sudo systemctl enable --now docker 2>/dev/null || sudo service docker start 2>/dev/null || true
  sleep 3
  echo -e "${GREEN}✅ Docker installed.${NC}"
}

check_docker_version() {
  if ! command -v docker &>/dev/null; then return 1; fi
  local api_ver
  api_ver=$(docker version --format '{{.Client.APIVersion}}' 2>/dev/null || echo "0.0")
  # k3d requires Docker API >= 1.44
  if [[ "$(printf '%s\n' "1.44" "$api_ver" | sort -V | head -n1)" != "1.44" ]]; then
    echo -e "${YELLOW}⚠️  Docker API version ${api_ver} is too old (need ≥1.44). Upgrading...${NC}"
    return 1
  fi
  return 0
}

install_dep() {
  local cmd=$1
  case $cmd in
    docker)
      if ! check_docker_version; then
        [ "$DISTRO" = "Mac" ] && { echo -e "${RED}❌ Please upgrade Docker Desktop from https://docker.com${NC}"; exit 1; }
        install_docker_linux
      else
        echo -e "${GREEN}✅ docker (API $(docker version --format '{{.Client.APIVersion}}' 2>/dev/null)) OK${NC}"
      fi
      ;;
    *)
      if command -v "$cmd" &>/dev/null; then
        echo -e "${GREEN}✅ ${cmd} already installed.${NC}"
        return
      fi
      echo -e "${BLUE}🛠️  Installing ${cmd}...${NC}"
      if [ "$DISTRO" = "Mac" ]; then
        brew install "$cmd" 2>/dev/null || brew install --cask "$cmd" 2>/dev/null || true
      else
        sudo apt-get update -qq
        case $cmd in
          k3d)
            curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
            ;;
          kubectl)
            curl -fLO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl
            ;;
          helm)
            curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
            ;;
        esac
      fi
      ;;
  esac
}

install_dep docker
install_dep k3d
install_dep kubectl
install_dep helm

# Docker socket access check
K3D_CMD="k3d"
DOCKER_CMD="docker"
if ! docker ps &>/dev/null 2>&1; then
  echo -e "${YELLOW}⚠️  Docker socket not accessible as current user — using sudo.${NC}"
  echo -e "${YELLOW}   (Tip: log out and back in after install to fix this permanently)${NC}"
  K3D_CMD="sudo k3d"
  DOCKER_CMD="sudo docker"
fi

# =============================================================================
# 3. Gather Secrets (Interactive)
# =============================================================================
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       🔐  Platform Secrets Setup         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo -e "${YELLOW}   Press ENTER to keep default values shown in [brackets].${NC}"
echo ""

read -rp "  PostgreSQL Password       [backstage]: "  POSTGRES_PASSWORD
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-backstage}"

read -rp "  GitHub Org [${GITHUB_ORG:-}]:          "  GITHUB_ORG
GITHUB_ORG="${GITHUB_ORG:-}"
read -rp "  GitHub Repo [${GITHUB_REPO:-}]:        "  GITHUB_REPO
GITHUB_REPO="${GITHUB_REPO:-}"
read -rp "  GitHub Token (ghp_...) [hidden]:       "  GITHUB_TOKEN

read -rp "  Google OAuth Client ID [${GOOGLE_CLIENT_ID:-}]: "  GOOGLE_CLIENT_ID
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
read -rp "  Google OAuth Client Secret [hidden]:   "  GOOGLE_CLIENT_SECRET

read -rp "  AWS Access Key ID [${AWS_ACCESS_KEY_ID:-}]: "  AWS_ACCESS_KEY_ID
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
read -rp "  AWS Secret Access Key [hidden]:        "  AWS_SECRET_ACCESS_KEY
read -rp "  AWS Region [${AWS_REGION:-us-east-1}]: "  AWS_REGION
AWS_REGION="${AWS_REGION:-us-east-1}"

read -rp "  TechDocs S3 Bucket [${TECHDOCS_BUCKET:-}]: "  TECHDOCS_BUCKET
TECHDOCS_BUCKET="${TECHDOCS_BUCKET:-}"

echo ""

# =============================================================================
# 4. Create Kubernetes Cluster
# =============================================================================
mkdir -p "${HOME}/.kube"

if $K3D_CMD cluster list 2>/dev/null | grep -q "om-cluster"; then
  echo -e "${GREEN}✅ Cluster 'om-cluster' already exists.${NC}"
else
  echo -e "${BLUE}📦 Creating K3d registry 'om-registry'...${NC}"
  $K3D_CMD registry create om-registry --port 5000 || true

  echo -e "${BLUE}📦 Creating K3d cluster 'om-cluster'...${NC}"
  $K3D_CMD cluster create om-cluster \
    --api-port 6550 \
    -p "80:80@loadbalancer" \
    -p "443:443@loadbalancer" \
    --registry-use k3d-om-registry:5000 \
    --agents 2
fi

# Always refresh kubeconfig for the current user
$K3D_CMD kubeconfig get om-cluster > "${HOME}/.kube/config"
chmod 600 "${HOME}/.kube/config"
echo -e "${GREEN}✅ Kubeconfig updated.${NC}"

# =============================================================================
# 5. Install ArgoCD
# =============================================================================
echo -e "${BLUE}⚓ Installing ArgoCD...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm --force-update || true
helm repo update argo
helm upgrade --install argocd argo/argo-cd \
  -n argocd \
  --set configs.params."server\.insecure"=true \
  --set server.ingress.enabled=true \
  --set server.ingress.ingressClassName=traefik \
  --set 'server.ingress.hosts={argocd.backstage.com}' \
  --wait --timeout 10m

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "not-set-yet")
echo -e "${GREEN}✅ ArgoCD ready. Admin password: ${YELLOW}${ARGOCD_PASS}${NC}"

# =============================================================================
# 6. Create Namespaces & Secrets
# =============================================================================
echo -e "${BLUE}🔑 Creating namespaces and injecting secrets...${NC}"
kubectl create namespace backstage --dry-run=client -o yaml | kubectl apply -f -

# Backstage service account (needed for K8s plugin token)
kubectl create serviceaccount backstage -n backstage --dry-run=client -o yaml | kubectl apply -f -
kubectl create clusterrolebinding backstage-view --clusterrole=view --serviceaccount=backstage:backstage --dry-run=client -o yaml | kubectl apply -f -

# Generate a token for the K8s plugin
SA_TOKEN=$(kubectl create token backstage -n backstage --duration=87600h 2>/dev/null || echo "sa-token-placeholder")
K8S_API_URL="https://kubernetes.default.svc.cluster.local"
K8S_CA_DATA=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

kubectl create secret generic backstage-secrets -n backstage \
  --from-literal=GITHUB_TOKEN="${GITHUB_TOKEN}" \
  --from-literal=GITHUB_ORG="${GITHUB_ORG}" \
  --from-literal=GITHUB_REPO="${GITHUB_REPO}" \
  --from-literal=GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID}" \
  --from-literal=GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET}" \
  --from-literal=KUBERNETES_SA_TOKEN="${SA_TOKEN}" \
  --from-literal=KUBERNETES_API_URL="${K8S_API_URL}" \
  --from-literal=KUBERNETES_CA_DATA="${K8S_CA_DATA}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic backstage-s3-auth -n backstage \
  --from-literal=AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
  --from-literal=AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
  --from-literal=AWS_REGION="us-east-1" \
  --from-literal=TECHDOCS_BUCKET_NAME="${TECHDOCS_BUCKET}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic backstage-postgresql -n backstage \
  --from-literal=postgres-password="${POSTGRES_PASSWORD}" \
  --from-literal=password="${POSTGRES_PASSWORD}" \
  --dry-run=client -o yaml | \
  kubectl apply -f -

# Annotate/label for Helm adoption
kubectl label secret backstage-postgresql -n backstage "app.kubernetes.io/managed-by=Helm" --overwrite
kubectl annotate secret backstage-postgresql -n backstage "meta.helm.sh/release-name=backstage" --overwrite
kubectl annotate secret backstage-postgresql -n backstage "meta.helm.sh/release-namespace=backstage" --overwrite

echo -e "${GREEN}✅ Secrets injected.${NC}"

# =============================================================================
# 7. Build Backstage Docker Image Locally
# =============================================================================
echo -e "${BLUE}🏗️  Building Backstage image (first run: ~5-10 min)...${NC}"
# Use project root as context for monorepo build
${DOCKER_CMD} build \
  -t localhost:5000/om-backstage:local \
  -f "${BACKSTAGE_DIR}/Dockerfile.multistage" \
  "${BACKSTAGE_DIR}"

echo -e "${BLUE}📦 Pushing image to local registry...${NC}"
${DOCKER_CMD} push localhost:5000/om-backstage:local
echo -e "${GREEN}✅ Image pushed.${NC}"

# =============================================================================
# 8. Generate Self-Signed TLS Certificate
# =============================================================================
echo -e "${BLUE}🛡️  Generating TLS certificate for portal.backstage.com...${NC}"
CERT_DIR=$(mktemp -d)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${CERT_DIR}/tls.key" \
  -out    "${CERT_DIR}/tls.crt" \
  -subj   "/CN=portal.backstage.com/O=OM Platform" 2>/dev/null

kubectl create secret tls backstage-tls -n backstage \
  --cert="${CERT_DIR}/tls.crt" \
  --key="${CERT_DIR}/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -
rm -rf "${CERT_DIR}"
echo -e "${GREEN}✅ TLS certificate created.${NC}"

# =============================================================================
# 9. Deploy Backstage via Helm
# =============================================================================
echo -e "${BLUE}🎭 Deploying Backstage portal...${NC}"

# Temporary override: use local image + correct TLS schema
OVERRIDE_FILE=$(mktemp /tmp/backstage-override-XXXXXX.yaml)
cat > "${OVERRIDE_FILE}" <<EOF
backstage:
  image:
    registry: "k3d-om-registry:5000"
    repository: om-backstage
    tag: local
    pullPolicy: Always
  podLabels:
    backstage.io/kubernetes-id: backstage

postgresql:
  image:
    tag: "latest"
  auth:
    password: "${POSTGRES_PASSWORD}"
  primary:
    podLabels:
      backstage.io/kubernetes-id: backstage

ingress:
  enabled: true
  className: traefik
  host: portal.backstage.com
  tls:
    enabled: true
    secretName: backstage-tls
EOF

helm repo add backstage https://backstage.github.io/charts --force-update || true
helm repo update backstage
helm upgrade --install backstage backstage/backstage \
  --version 0.22.5 \
  -n backstage \
  -f "${HELM_VALUES}" \
  -f "${OVERRIDE_FILE}" \
  --skip-schema-validation \
  --wait --timeout 20m

rm -f "${OVERRIDE_FILE}"
echo -e "${GREEN}✅ Backstage deployed.${NC}"

# Fix 404 caused by port-forwarding (Host header mismatch)
kubectl apply -f - <<EOF
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: backstage-host-fix
  namespace: backstage
spec:
  headers:
    customRequestHeaders:
      Host: "portal.backstage.com"
EOF
kubectl annotate ingress backstage -n backstage traefik.ingress.kubernetes.io/router.middlewares=backstage-backstage-host-fix@kubernetescrd --overwrite

# =============================================================================
# 10. Register in ArgoCD UI (for observability)
# =============================================================================
kubectl apply -f "${PROJECT_ROOT}/argocd/bootstrap/projects.yaml" 2>/dev/null || true
kubectl apply -f "${PROJECT_ROOT}/argocd/apps/infrastructure/backstage.yaml" 2>/dev/null || true

# =============================================================================
# Done!
# =============================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✨  OM Platform is LIVE!                        ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Portal:  https://portal.backstage.com           ║${NC}"
echo -e "${GREEN}║  ArgoCD:  http://argocd.backstage.com            ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${YELLOW}║  Add these to /etc/hosts on your machine:        ║${NC}"
echo -e "${YELLOW}║    127.0.0.1  portal.backstage.com               ║${NC}"
echo -e "${YELLOW}║    127.0.0.1  argocd.backstage.com               ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  ArgoCD admin password: ${YELLOW}${ARGOCD_PASS}${GREEN}               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
