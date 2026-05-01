#!/bin/bash
# =============================================================================
# OM Platform - Universal Bootstrap Script (v2 - Improved)
# Supports: macOS (Homebrew), Ubuntu/Debian Linux
# Usage: ./scripts/platform-up-v2.sh [--config path/to/secrets.env]
# =============================================================================
set -euo pipefail

# --- Colors ------------------------------------------------------------------
GREEN='\033[0;32m'; BLUE='\033[0;34m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

# --- Paths -------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKSTAGE_DIR="${PROJECT_ROOT}/platform/portal/backstage"
HELM_VALUES="${PROJECT_ROOT}/helm/values/prod/backstage-values.yaml"
DEFAULT_CONFIG="${PROJECT_ROOT}/configs/secrets-templates/backstage-secrets.env"

# --- Parse Arguments ---------------------------------------------------------
CONFIG_FILE="${DEFAULT_CONFIG}"
while [[ $# -gt 0 ]]; do
  case $1 in
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [--config path/to/secrets.env]"
      echo ""
      echo "Options:"
      echo "  --config FILE    Path to secrets configuration file"
      echo "                   Default: configs/secrets-templates/backstage-secrets.env"
      echo ""
      echo "Setup:"
      echo "  1. Copy configs/secrets-templates/backstage-secrets.env.example"
      echo "  2. Rename to backstage-secrets.env"
      echo "  3. Fill in your actual values"
      echo "  4. Run this script"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    🚀  OM Platform Bootstrap v2          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo -e "   Project Root: ${PROJECT_ROOT}"

# --- Load Configuration ------------------------------------------------------
if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo -e "${RED}❌ Configuration file not found: ${CONFIG_FILE}${NC}"
  echo -e "${YELLOW}📝 Please create it from the example:${NC}"
  echo -e "   cp configs/secrets-templates/backstage-secrets.env.example \\"
  echo -e "      configs/secrets-templates/backstage-secrets.env"
  echo -e ""
  echo -e "   Then edit it with your actual values."
  exit 1
fi

echo -e "${BLUE}📋 Loading configuration from: ${CONFIG_FILE}${NC}"
set -a  # automatically export all variables
source "${CONFIG_FILE}"
set +a

# --- Validate Required Variables ---------------------------------------------
REQUIRED_VARS=(
  "GITHUB_TOKEN"
  "GITHUB_ORG"
  "GITHUB_REPO"
  "GOOGLE_CLIENT_ID"
  "GOOGLE_CLIENT_SECRET"
  "POSTGRES_PASSWORD"
  "BACKSTAGE_DOMAIN"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]] || [[ "${!var}" == *"your-"* ]] || [[ "${!var}" == *"change-me"* ]]; then
    MISSING_VARS+=("$var")
  fi
done

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
  echo -e "${RED}❌ Missing or invalid required variables:${NC}"
  for var in "${MISSING_VARS[@]}"; do
    echo -e "   - ${var}"
  done
  echo -e "${YELLOW}Please update ${CONFIG_FILE}${NC}"
  exit 1
fi

# Set defaults for optional variables
BACKSTAGE_BASE_URL="${BACKSTAGE_BASE_URL:-https://${BACKSTAGE_DOMAIN}}"
K3D_REGISTRY_PORT="${K3D_REGISTRY_PORT:-5000}"
K3D_HTTP_PORT="${K3D_HTTP_PORT:-80}"
K3D_HTTPS_PORT="${K3D_HTTPS_PORT:-443}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"
TECHDOCS_BUCKET="${TECHDOCS_BUCKET:-}"
ARGOCD_USERNAME="${ARGOCD_USERNAME:-admin}"
ARGOCD_PASSWORD="${ARGOCD_PASSWORD:-}"
ARGOCD_DOMAIN="${ARGOCD_DOMAIN:-argocd.backstage.com}"
REDIS_HOST="${REDIS_HOST:-backstage-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"

echo -e "${GREEN}✅ Configuration validated${NC}"
echo -e "   Organization: ${GITHUB_ORG}"
echo -e "   Repository: ${GITHUB_REPO}"
echo -e "   Domain: ${BACKSTAGE_DOMAIN}"
echo -e "   Base URL: ${BACKSTAGE_BASE_URL}"
echo -e "   K3d Registry Port: ${K3D_REGISTRY_PORT}"
echo -e "   K3d HTTP Port: ${K3D_HTTP_PORT}"
echo -e "   K3d HTTPS Port: ${K3D_HTTPS_PORT}"

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
  sudo apt-get remove -y docker.io docker-doc docker-compose podman-docker containerd runc 2>/dev/null || true
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
# 3. Create Kubernetes Cluster
# =============================================================================
mkdir -p "${HOME}/.kube"

if $K3D_CMD cluster list 2>/dev/null | grep -q "om-cluster"; then
  echo -e "${GREEN}✅ Cluster 'om-cluster' already exists.${NC}"
else
  echo -e "${BLUE}📦 Creating K3d registry 'om-registry'...${NC}"
  if $K3D_CMD registry list 2>/dev/null | awk '{print $1}' | grep -qx "k3d-om-registry"; then
    echo -e "${YELLOW}ℹ️  Registry 'om-registry' already exists. Ensuring it is running...${NC}"
    if ! ${DOCKER_CMD} start k3d-om-registry >/dev/null 2>&1; then
      echo -e "${YELLOW}🧹 Existing registry could not be started. Recreating...${NC}"
      $K3D_CMD registry delete om-registry || true
      $K3D_CMD registry create om-registry --port "${K3D_REGISTRY_PORT}"
    fi
  else
    $K3D_CMD registry create om-registry --port "${K3D_REGISTRY_PORT}"
  fi

  echo -e "${BLUE}📦 Creating K3d cluster 'om-cluster'...${NC}"
  $K3D_CMD cluster create om-cluster \
    --api-port 6550 \
    -p "${K3D_HTTP_PORT}:80@loadbalancer" \
    -p "${K3D_HTTPS_PORT}:443@loadbalancer" \
    --registry-use k3d-om-registry:5000 \
    --agents 0
fi

$K3D_CMD kubeconfig get om-cluster > "${HOME}/.kube/config"
chmod 600 "${HOME}/.kube/config"
echo -e "${GREEN}✅ Kubeconfig updated.${NC}"

# =============================================================================
# 4. Install ArgoCD
# =============================================================================
echo -e "${BLUE}⚓ Installing ArgoCD...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm --force-update || true
helm repo update argo

# If a previous install/upgrade failed (often due to resource pressure), uninstall before retrying.
if helm status argocd -n argocd >/dev/null 2>&1; then
  ARGOCD_STATUS=$(helm status argocd -n argocd 2>/dev/null | awk -F': ' '/^STATUS:/{print $2}' || true)
  if [[ "${ARGOCD_STATUS}" == "failed" ]]; then
    echo -e "${YELLOW}🧹 ArgoCD Helm release is in failed state. Uninstalling before retry...${NC}"
    helm uninstall argocd -n argocd || true
    kubectl delete job -n argocd -l app.kubernetes.io/instance=argocd --ignore-not-found=true || true
  fi
fi

helm upgrade --install argocd argo/argo-cd \
  -n argocd \
  --set configs.params."server\.insecure"=true \
  --set server.ingress.enabled=true \
  --set server.ingress.ingressClassName=traefik \
  --set "server.ingress.hosts={${ARGOCD_DOMAIN}}" \
  --wait --timeout 30m

# Fix Host header for VM port-forwarding (browsers may include :<port> in Host).
kubectl apply -f - <<EOF
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: argocd-host-fix
  namespace: argocd
spec:
  headers:
    customRequestHeaders:
      Host: "${ARGOCD_DOMAIN}"
EOF
cat <<'EOF' | sed "s|__ARGOCD_DOMAIN__|${ARGOCD_DOMAIN}|g" | kubectl apply -f -
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-portforward
  namespace: argocd
spec:
  entryPoints:
    - web
    - websecure
  routes:
    - match: 'HostRegexp(`{host:__ARGOCD_DOMAIN__(:[0-9]+)?}`)'
      kind: Rule
      middlewares:
        - name: argocd-host-fix
      services:
        - name: argocd-server
          port: 80
EOF

# Get ArgoCD password
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "not-set-yet")
echo -e "${GREEN}✅ ArgoCD ready. Admin password: ${YELLOW}${ARGOCD_PASS}${NC}"

# Update ARGOCD_PASSWORD if not set
if [[ -z "${ARGOCD_PASSWORD}" ]]; then
  ARGOCD_PASSWORD="${ARGOCD_PASS}"
fi

# =============================================================================
# 5. Create Namespaces & Secrets
# =============================================================================
echo -e "${BLUE}🔑 Creating namespaces and injecting secrets...${NC}"
kubectl create namespace backstage --dry-run=client -o yaml | kubectl apply -f -

# Backstage service account
kubectl create serviceaccount backstage -n backstage --dry-run=client -o yaml | kubectl apply -f -
kubectl create clusterrolebinding backstage-view --clusterrole=view --serviceaccount=backstage:backstage --dry-run=client -o yaml | kubectl apply -f -

# Generate token for K8s plugin
SA_TOKEN=$(kubectl create token backstage -n backstage --duration=87600h 2>/dev/null || echo "sa-token-placeholder")
K8S_API_URL="https://kubernetes.default.svc.cluster.local"
K8S_CA_DATA=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

# Main secrets
kubectl create secret generic backstage-secrets -n backstage \
  --from-literal=GITHUB_TOKEN="${GITHUB_TOKEN}" \
  --from-literal=GITHUB_ORG="${GITHUB_ORG}" \
  --from-literal=GITHUB_REPO="${GITHUB_REPO}" \
  --from-literal=GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID}" \
  --from-literal=GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET}" \
  --from-literal=KUBERNETES_SA_TOKEN="${SA_TOKEN}" \
  --from-literal=KUBERNETES_API_URL="${K8S_API_URL}" \
  --from-literal=KUBERNETES_CA_DATA="${K8S_CA_DATA}" \
  --from-literal=ARGOCD_USERNAME="${ARGOCD_USERNAME}" \
  --from-literal=ARGOCD_PASSWORD="${ARGOCD_PASSWORD}" \
  --from-literal=POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

# S3 secrets (if configured)
if [[ -n "${AWS_ACCESS_KEY_ID}" && -n "${AWS_SECRET_ACCESS_KEY}" && -n "${TECHDOCS_BUCKET}" ]]; then
  kubectl create secret generic backstage-s3-auth -n backstage \
    --from-literal=AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    --from-literal=AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    --from-literal=AWS_REGION="${AWS_REGION}" \
    --from-literal=TECHDOCS_BUCKET_NAME="${TECHDOCS_BUCKET}" \
    --dry-run=client -o yaml | kubectl apply -f -
  echo -e "${GREEN}✅ S3 secrets configured for TechDocs${NC}"
else
  echo -e "${YELLOW}⚠️  S3 credentials not configured - TechDocs will use local storage${NC}"
fi

# PostgreSQL secret (used by Helm PostgreSQL chart)
kubectl create secret generic backstage-postgresql -n backstage \
  --from-literal=user-password="${POSTGRES_PASSWORD}" \
  --from-literal=admin-password="${POSTGRES_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ Secrets injected.${NC}"

# =============================================================================
# 6. Build Backstage Docker Image
# =============================================================================
# NOTE: Build the image manually first, then run this script
# Run in VM: docker build -t localhost:5000/om-backstage:local -f platform/portal/backstage/Dockerfile.multistage platform/portal/backstage
# Then: docker push localhost:5000/om-backstage:local
echo -e "${BLUE}🏗️  Checking for Backstage image...${NC}"
if ${DOCKER_CMD} images --format '{{.Repository}}:{{.Tag}}' | grep -q "localhost:5000/om-backstage:local"; then
  echo -e "${GREEN}✅ Backstage image found${NC}"
else
  echo -e "${RED}❌ Backstage image not found!${NC}"
  echo -e "${YELLOW}Build it first with:${NC}"
  echo -e "  docker build -t localhost:5000/om-backstage:local -f platform/portal/backstage/Dockerfile.multistage platform/portal/backstage"
  echo -e "  docker push localhost:5000/om-backstage:local"
  exit 1
fi

# Uncomment below to build automatically (takes 30-60 minutes)
# echo -e "${BLUE}🏗️  Building Backstage image (this will take 30-60 minutes)...${NC}"
# ${DOCKER_CMD} build \
#   -t localhost:5000/om-backstage:local \
#   -f "${BACKSTAGE_DIR}/Dockerfile.multistage" \
#   "${BACKSTAGE_DIR}"
# echo -e "${BLUE}📦 Pushing image to local registry...${NC}"
# ${DOCKER_CMD} push localhost:5000/om-backstage:local
# echo -e "${GREEN}✅ Image pushed.${NC}"

# =============================================================================
# 7. Generate TLS Certificate
# =============================================================================
echo -e "${BLUE}🛡️  Generating TLS certificate for ${BACKSTAGE_DOMAIN}...${NC}"
CERT_DIR=$(mktemp -d)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${CERT_DIR}/tls.key" \
  -out    "${CERT_DIR}/tls.crt" \
  -subj   "/CN=${BACKSTAGE_DOMAIN}/O=OM Platform" 2>/dev/null

kubectl create secret tls backstage-tls -n backstage \
  --cert="${CERT_DIR}/tls.crt" \
  --key="${CERT_DIR}/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -
rm -rf "${CERT_DIR}"
echo -e "${GREEN}✅ TLS certificate created.${NC}"

# =============================================================================
# 8. Deploy PostgreSQL Separately
# =============================================================================
echo -e "${BLUE}🐘 PostgreSQL will be deployed by the Backstage Helm chart...${NC}"

# Cleanup legacy custom PostgreSQL resources (from older versions of this script)
if kubectl get statefulset -n backstage backstage-postgresql &>/dev/null; then
  LEGACY_PG_LABEL=$(kubectl get statefulset -n backstage backstage-postgresql -o jsonpath='{.metadata.labels.app}' 2>/dev/null || true)
  LEGACY_PG_HELM=$(kubectl get statefulset -n backstage backstage-postgresql -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || true)
  if [[ "${LEGACY_PG_LABEL}" == "backstage-postgresql" && "${LEGACY_PG_HELM}" != "Helm" ]]; then
    echo -e "${YELLOW}🧹 Removing legacy custom PostgreSQL StatefulSet...${NC}"
    kubectl delete statefulset -n backstage backstage-postgresql --ignore-not-found=true
    kubectl delete svc -n backstage backstage-postgresql-hl --ignore-not-found=true
  fi
fi

# If a Service named backstage-postgresql already exists but is not owned by the
# 'backstage' Helm release, Helm won't be able to create/import it.
if kubectl get svc -n backstage backstage-postgresql &>/dev/null; then
  PG_SVC_REL=$(kubectl get svc -n backstage backstage-postgresql -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' 2>/dev/null || true)
  PG_SVC_NS=$(kubectl get svc -n backstage backstage-postgresql -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' 2>/dev/null || true)
  if [[ "${PG_SVC_REL}" != "backstage" || "${PG_SVC_NS}" != "backstage" ]]; then
    echo -e "${YELLOW}🧹 Deleting pre-existing Service/backstage-postgresql (not owned by Helm release 'backstage')...${NC}"
    kubectl delete svc -n backstage backstage-postgresql --ignore-not-found=true
  fi
fi

# =============================================================================
# 9. Deploy Backstage via Helm
# =============================================================================
echo -e "${BLUE}🎭 Deploying Backstage portal...${NC}"

# Ensure PostgreSQL pod doesn't keep retrying an old/non-existent image.
DESIRED_PG_IMAGE="docker.io/bitnamilegacy/postgresql:17.6.0-debian-12-r4"
if kubectl get pod -n backstage backstage-postgresql-0 &>/dev/null; then
  CURRENT_PG_IMAGE=$(kubectl get pod -n backstage backstage-postgresql-0 -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true)
  if [[ -n "${CURRENT_PG_IMAGE}" && "${CURRENT_PG_IMAGE}" != "${DESIRED_PG_IMAGE}" ]]; then
    echo -e "${YELLOW}🧹 PostgreSQL pod is using '${CURRENT_PG_IMAGE}'. Recreating to pick up '${DESIRED_PG_IMAGE}'...${NC}"
    kubectl delete pod -n backstage backstage-postgresql-0 --ignore-not-found=true
  fi
fi

# Create temporary override with dynamic values
OVERRIDE_FILE=$(mktemp /tmp/backstage-override-XXXXXX.yaml)
cat > "${OVERRIDE_FILE}" <<EOF
backstage:
  pdb:
    create: false
  autoscaling:
    enabled: false
  image:
    registry: "k3d-om-registry:5000"
    repository: om-backstage
    tag: local
    pullPolicy: Always
  podLabels:
    backstage.io/kubernetes-id: backstage
  
  appConfig:
    app:
      baseUrl: ${BACKSTAGE_BASE_URL}
    backend:
      baseUrl: ${BACKSTAGE_BASE_URL}
      cors:
        origin: ${BACKSTAGE_BASE_URL}
        methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
        credentials: true
      database:
        client: pg
        connection:
          host: backstage-postgresql
          port: 5432
          user: postgres
          password: \${POSTGRES_PASSWORD}
          database: backstage
    
    integrations:
      github:
        - host: github.com
          token: \${GITHUB_TOKEN}
    
    catalog:
      providers:
        github:
          om-platform:
            organization: \${GITHUB_ORG}
            catalogPath: '/catalog-info.yaml'
      locations:
        - type: url
          target: https://github.com/\${GITHUB_ORG}/\${GITHUB_REPO}/blob/main/platform/portal/backstage/catalog/users.yaml
        - type: url
          target: https://github.com/\${GITHUB_ORG}/\${GITHUB_REPO}/blob/main/platform/portal/backstage/catalog-info.yaml
        - type: url
          target: https://github.com/\${GITHUB_ORG}/\${GITHUB_REPO}/blob/main/platform/portal/backstage/templates/new-application/template.yaml
        - type: url
          target: https://github.com/\${GITHUB_ORG}/\${GITHUB_REPO}/blob/main/platform/portal/backstage/templates/request-service/template.yaml
        - type: url
          target: https://github.com/\${GITHUB_ORG}/\${GITHUB_REPO}/blob/main/platform/portal/backstage/templates/team-onboarding/template.yaml
    
    argocd:
      baseUrl: http://argocd-server.argocd.svc
      username: \${ARGOCD_USERNAME}
      password: \${ARGOCD_PASSWORD}

postgresql:
  enabled: true
  image:
    registry: docker.io
    repository: bitnamilegacy/postgresql
    tag: 17.6.0-debian-12-r4
  auth:
    database: backstage
    username: postgres
    existingSecret: backstage-postgresql
    secretKeys:
      userPasswordKey: user-password
      adminPasswordKey: admin-password

ingress:
  enabled: true
  className: traefik
  host: ${BACKSTAGE_DOMAIN}
  tls:
    enabled: true
    secretName: backstage-tls
EOF

helm repo add backstage https://backstage.github.io/charts --force-update || true
helm repo update backstage

# Deploy Backstage with external PostgreSQL
echo -e "${YELLOW}⏳ Starting Helm deployment (this may take a few minutes)...${NC}"
helm upgrade --install backstage backstage/backstage \
  --version 0.22.5 \
  -n backstage \
  -f "${HELM_VALUES}" \
  -f "${OVERRIDE_FILE}" \
  --skip-schema-validation \
  --timeout 20m \
  --wait

# Ensure PostgreSQL is ready before relying on Backstage plugin initialization.
kubectl wait --for=condition=ready pod -n backstage -l app.kubernetes.io/name=postgresql --timeout=10m 2>/dev/null || true

# If Backstage started while PostgreSQL was unavailable, it can remain in a degraded state.
# Restart it after PostgreSQL becomes ready.
kubectl rollout restart deploy/backstage -n backstage
kubectl rollout status deploy/backstage -n backstage --timeout=10m

# If the PostgreSQL StatefulSet image changed (common when overriding Bitnami tags),
# the existing pod might keep retrying the old image. Force recreation when needed.
if kubectl get pod -n backstage backstage-postgresql-0 &>/dev/null; then
  CURRENT_PG_IMAGE=$(kubectl get pod -n backstage backstage-postgresql-0 -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true)
  if [[ -n "${CURRENT_PG_IMAGE}" && "${CURRENT_PG_IMAGE}" != "${DESIRED_PG_IMAGE}" ]]; then
    echo -e "${YELLOW}🧹 PostgreSQL pod is using '${CURRENT_PG_IMAGE}'. Recreating to pick up '${DESIRED_PG_IMAGE}'...${NC}"
    kubectl delete pod -n backstage backstage-postgresql-0 --ignore-not-found=true
  fi
fi

rm -f "${OVERRIDE_FILE}"

echo -e "${GREEN}✅ Backstage deployed successfully${NC}"

# Fix Host header for port-forwarding
kubectl apply -f - <<EOF
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: backstage-host-fix
  namespace: backstage
spec:
  headers:
    customRequestHeaders:
      Host: "${BACKSTAGE_DOMAIN}"
EOF
kubectl annotate ingress backstage -n backstage traefik.ingress.kubernetes.io/router.middlewares=backstage-backstage-host-fix@kubernetescrd --overwrite

# Traefik matches Host rules against the raw Host header. When accessing the VM via
# Vagrant forwarded ports (e.g. https://portal.backstage.com:9443), browsers send
# Host: portal.backstage.com:9443 which doesn't match a plain Host(`portal.backstage.com`).
# Add explicit IngressRoutes that match both variants.
cat <<'EOF' | sed "s|__BACKSTAGE_DOMAIN__|${BACKSTAGE_DOMAIN}|g" | kubectl apply -f -
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: backstage-portforward
  namespace: backstage
spec:
  entryPoints:
    - web
    - websecure
  routes:
    - match: 'HostRegexp(`{host:__BACKSTAGE_DOMAIN__(:[0-9]+)?}`)'
      kind: Rule
      middlewares:
        - name: backstage-host-fix
      services:
        - name: backstage
          port: 7007
  tls:
    secretName: backstage-tls
EOF

# =============================================================================
# 10. Register in ArgoCD
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
echo -e "${GREEN}║  Portal:  https://${BACKSTAGE_DOMAIN}${NC}"
echo -e "${GREEN}║  ArgoCD:  http://${ARGOCD_DOMAIN}${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${YELLOW}║  Add these to /etc/hosts on your machine:        ║${NC}"
echo -e "${YELLOW}║    127.0.0.1  ${BACKSTAGE_DOMAIN}${NC}"
echo -e "${YELLOW}║    127.0.0.1  ${ARGOCD_DOMAIN}${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  ArgoCD admin password: ${YELLOW}${ARGOCD_PASS}${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📝 Next steps:${NC}"
echo -e "   1. Add the /etc/hosts entries above"
echo -e "   2. Access Backstage at https://${BACKSTAGE_DOMAIN}"
echo -e "   3. Accept the self-signed certificate warning"
echo -e "   4. Sign in with Google OAuth"
echo ""
echo -e "${BLUE}🔍 Troubleshooting:${NC}"
echo -e "   Check pods:    kubectl get pods -n backstage"
echo -e "   Check logs:    kubectl logs -n backstage -l app.kubernetes.io/name=backstage"
echo -e "   Check ingress: kubectl get ingress -n backstage"
