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
BUILD_BACKSTAGE_IMAGE=false
PULL_BACKSTAGE_IMAGE=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --build-backstage-image)
      BUILD_BACKSTAGE_IMAGE=true
      shift
      ;;
    --pull-backstage-image)
      PULL_BACKSTAGE_IMAGE=true
      shift
      ;;
    --help)
      echo "Usage: $0 [--config path/to/secrets.env]"
      echo ""
      echo "Options:"
      echo "  --config FILE    Path to secrets configuration file"
      echo "                   Default: configs/secrets-templates/backstage-secrets.env"
      echo "  --build-backstage-image  Build and push the Backstage image to the local registry"
      echo "  --pull-backstage-image   Pull a prebuilt Backstage image and push it to the local registry"
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
K3D_AGENTS="${K3D_AGENTS:-0}"
BACKSTAGE_IMAGE_REMOTE="${BACKSTAGE_IMAGE_REMOTE:-docker.io/joelnatahn/my-backstage:fixed}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"
TECHDOCS_BUCKET="${TECHDOCS_BUCKET:-}"
ARGOCD_USERNAME="${ARGOCD_USERNAME:-admin}"
ARGOCD_PASSWORD="${ARGOCD_PASSWORD:-}"
ARGOCD_DOMAIN="${ARGOCD_DOMAIN:-argocd.backstage.com}"
REDIS_HOST="${REDIS_HOST:-backstage-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"
OM_GIT_REPO_URL="${OM_GIT_REPO_URL:-https://github.com/${GITHUB_ORG}/${GITHUB_REPO}.git}"
OM_GIT_REPO_SSH="${OM_GIT_REPO_SSH:-git@github.com:${GITHUB_ORG}/${GITHUB_REPO}.git}"
OM_GIT_REVISION="${OM_GIT_REVISION:-main}"

echo -e "${GREEN}✅ Configuration validated${NC}"
echo -e "   Organization: ${GITHUB_ORG}"
echo -e "   Repository: ${GITHUB_REPO}"
echo -e "   Domain: ${BACKSTAGE_DOMAIN}"
echo -e "   Base URL: ${BACKSTAGE_BASE_URL}"
echo -e "   K3d Registry Port: ${K3D_REGISTRY_PORT}"
echo -e "   K3d HTTP Port: ${K3D_HTTP_PORT}"
echo -e "   K3d HTTPS Port: ${K3D_HTTPS_PORT}"
echo -e "   K3d Agents: ${K3D_AGENTS}"

# Some tools (k3d) rely on TMPDIR for temp files. If TMPDIR points to a non-existent
# directory, cluster creation can fail (e.g. /tmp/om-bootstrap missing).
if [[ -n "${TMPDIR:-}" && ! -d "${TMPDIR}" ]]; then
  if mkdir -p "${TMPDIR}" >/dev/null 2>&1; then
    :
  else
    export TMPDIR="/tmp"
  fi
fi

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

retry() {
  local -r _max_attempts="$1"; shift
  local -r _sleep_seconds="$1"; shift
  local _attempt=1
  while true; do
    if "$@"; then
      return 0
    fi
    if [[ "${_attempt}" -ge "${_max_attempts}" ]]; then
      return 1
    fi
    sleep "${_sleep_seconds}"
    _attempt=$((_attempt + 1))
  done
}

kubectl_retry() {
  retry 30 2 kubectl "$@"
}

wait_for_cluster_networking() {
  echo -e "${BLUE}🩺 Waiting for cluster networking/Traefik to become Ready...${NC}"

  if ! retry 60 2 kubectl get nodes >/dev/null 2>&1; then
    echo -e "${RED}❌ Kubernetes API is not responding.${NC}"
    return 1
  fi

  if kubectl -n kube-system get ds kube-flannel-ds >/dev/null 2>&1; then
    kubectl -n kube-system rollout status ds/kube-flannel-ds --timeout=10m >/dev/null 2>&1 || true
  fi

  if kubectl -n kube-system get deploy traefik >/dev/null 2>&1; then
    kubectl -n kube-system rollout status deploy/traefik --timeout=10m >/dev/null 2>&1 || true
  fi

  if ! retry 60 2 bash -c 'kubectl -n kube-system get endpoints traefik -o jsonpath="{.subsets[0].addresses[0].ip}" 2>/dev/null | grep -q .'; then
    echo -e "${RED}❌ Traefik endpoints are not ready (ingress will return 503).${NC}"
    echo -e "${YELLOW}If you see flannel errors (subnet.env missing), restart Colima and/or recreate the k3d cluster.${NC}"
    echo -e "${YELLOW}Debug:${NC}"
    echo -e "${YELLOW}  kubectl -n kube-system get pods | egrep 'traefik|svclb-traefik|flannel'${NC}"
    echo -e "${YELLOW}  kubectl -n kube-system describe pod -l app.kubernetes.io/name=traefik | sed -n '1,200p'${NC}"
    return 1
  fi
  echo -e "${GREEN}✅ Cluster networking looks Ready${NC}"
}

ensure_traefik() {
  if kubectl -n kube-system get deploy traefik >/dev/null 2>&1; then
    return 0
  fi

  echo -e "${YELLOW}⚠️  Traefik is not installed in kube-system. Installing via Helm...${NC}"
  helm repo add traefik https://traefik.github.io/charts --force-update >/dev/null 2>&1 || true
  helm repo update traefik >/dev/null 2>&1 || true
  kubectl create namespace kube-system --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true

  helm upgrade --install traefik-crds traefik/traefik-crds \
    -n kube-system \
    --wait --timeout 10m \
    --skip-schema-validation >/dev/null 2>&1 || true

  helm upgrade --install traefik traefik/traefik \
    -n kube-system \
    --set providers.kubernetesCRD.enabled=true \
    --set providers.kubernetesIngress.enabled=true \
    --set ports.web.port=8000 \
    --set ports.websecure.port=8443 \
    --set service.type=LoadBalancer \
    --set ingressClass.enabled=true \
    --set ingressClass.isDefaultClass=true \
    --skip-schema-validation \
    --wait --timeout 20m
}

http_smoke_test() {
  local -r _name="$1"
  local -r _url="$2"
  local _code
  echo -e "${BLUE}🧪 Smoke test: ${_name} (${_url})...${NC}"

  if ! retry 30 2 bash -c "_code=\$(curl -k -sS -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 10 '${_url}' || echo 000); [[ \"\$_code\" != '000' && \"\$_code\" != '503' ]]"; then
    _code=$(curl -k -sS -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 10 "${_url}" 2>/dev/null || echo 000)
    echo -e "${RED}❌ Smoke test failed for ${_name} (HTTP ${_code}).${NC}"
    echo -e "${YELLOW}Diagnostics:${NC}"
    kubectl -n kube-system get pods | egrep 'traefik|svclb-traefik|flannel|coredns' || true
    kubectl -n kube-system get svc traefik 2>/dev/null || true
    kubectl -n kube-system get endpoints traefik 2>/dev/null || true
    kubectl -n backstage get pods 2>/dev/null || true
    kubectl -n backstage get ingress 2>/dev/null || true
    kubectl -n argocd get pods 2>/dev/null || true
    kubectl -n argocd get ingress 2>/dev/null || true
    return 1
  fi

  _code=$(curl -k -sS -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 10 "${_url}" 2>/dev/null || echo 000)
  echo -e "${GREEN}✅ Smoke test OK for ${_name} (HTTP ${_code})${NC}"
}

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
  # Cluster exists — make sure it is actually running (nodes ready).
  # If stopped (e.g. after a machine reboot), start it before proceeding.
  CLUSTER_SERVERS_RUNNING=$($K3D_CMD cluster list 2>/dev/null | awk '/om-cluster/{print $2}' | cut -d'/' -f1)
  if [[ "${CLUSTER_SERVERS_RUNNING}" == "0" ]]; then
    echo -e "${YELLOW}⚠️  Cluster 'om-cluster' exists but is stopped. Starting it...${NC}"
    $K3D_CMD cluster start om-cluster
  else
    echo -e "${GREEN}✅ Cluster 'om-cluster' already exists and is running.${NC}"
  fi
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
    --registry-use "k3d-om-registry:${K3D_REGISTRY_PORT}" \
    --agents "${K3D_AGENTS}"
fi

$K3D_CMD kubeconfig get om-cluster > "${HOME}/.kube/config"
chmod 600 "${HOME}/.kube/config"
echo -e "${GREEN}✅ Kubeconfig updated.${NC}"

ensure_traefik

wait_for_cluster_networking

# =============================================================================
# 4. Install ArgoCD
# =============================================================================
echo -e "${BLUE}⚓ Installing ArgoCD...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm --force-update || true
helm repo update argo

# Ensure ArgoCD is reachable via Traefik with TLS termination.
# We create a local self-signed cert for ${ARGOCD_DOMAIN} and store it in the argocd namespace.
if ! kubectl -n argocd get secret argocd-tls >/dev/null 2>&1; then
  echo -e "${YELLOW}🛡️  Generating TLS certificate for ${ARGOCD_DOMAIN}...${NC}"
  _argo_tmpdir="${TMPDIR:-/tmp}"
  _argo_crt="${_argo_tmpdir%/}/argocd.crt"
  _argo_key="${_argo_tmpdir%/}/argocd.key"
  openssl req -x509 -nodes -newkey rsa:2048 \
    -subj "/CN=${ARGOCD_DOMAIN}/O=OM Platform" \
    -keyout "${_argo_key}" \
    -out "${_argo_crt}" \
    -days 365 >/dev/null 2>&1 || true
  kubectl -n argocd create secret tls argocd-tls \
    --cert="${_argo_crt}" \
    --key="${_argo_key}" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
  echo -e "${GREEN}✅ ArgoCD TLS certificate created.${NC}"
fi

# Avoid Helm server-side apply field ownership conflicts on argocd-cm.
# If the CM was previously applied via kubectl (client-side), it carries
# kubectl-client-side-apply field ownership that conflicts with Helm SSA.
# Delete it so Helm can create it cleanly. ArgoCD recreates it on startup.
kubectl delete configmap argocd-cm -n argocd --ignore-not-found=true >/dev/null 2>&1 || true

# If we previously patched the ArgoCD Ingress (or applied custom routes), Helm's
# server-side apply may conflict on spec.rules ownership. Recreate it cleanly.
kubectl delete ingress argocd-server -n argocd --ignore-not-found=true >/dev/null 2>&1 || true
kubectl delete ingressroute argocd-portforward -n argocd --ignore-not-found=true >/dev/null 2>&1 || true

# Remove the ingress-nginx admission webhook if it exists from a previous run.
# On re-runs its TLS certificate is stale (signed by an unknown CA), which causes
# Helm to fail when creating any Ingress resource (including the ArgoCD ingress).
kubectl delete validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found=true >/dev/null 2>&1 || true

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
  --set server.extraArgs[0]=--insecure \
  --set server.ingress.enabled=true \
  --set server.ingress.ingressClassName=traefik \
  --set "server.ingress.hosts={${ARGOCD_DOMAIN}}" \
  --wait --timeout 30m

# Ensure ingress host + TLS secret are correct (chart defaults can drift across upgrades).
if kubectl -n argocd get ingress argocd-server >/dev/null 2>&1; then
  kubectl -n argocd patch ingress argocd-server --type='json' -p='[
    {"op":"replace","path":"/spec/rules/0/host","value":"'"${ARGOCD_DOMAIN}"'"}
  ]' >/dev/null 2>&1 || true
  kubectl -n argocd patch ingress argocd-server --type='merge' -p="
spec:
  tls:
    - hosts:
        - ${ARGOCD_DOMAIN}
      secretName: argocd-tls
" >/dev/null 2>&1 || true
fi

# Wait for ArgoCD server to be Ready (otherwise Traefik returns 503 no available server).
kubectl -n argocd rollout status deploy/argocd-server --timeout=10m >/dev/null 2>&1 || true

# Fix Host header for VM port-forwarding (browsers may include :<port> in Host).
kubectl apply -f - <<EOF
apiVersion: traefik.io/v1alpha1
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
apiVersion: traefik.io/v1alpha1
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
  --from-literal=OM_GIT_REVISION="${OM_GIT_REVISION}" \
  --from-literal=OM_GIT_REPO_URL="${OM_GIT_REPO_URL}" \
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
echo -e "${BLUE}🏗️  Backstage image...${NC}"
if [[ "${BUILD_BACKSTAGE_IMAGE}" == "true" && "${PULL_BACKSTAGE_IMAGE}" == "true" ]]; then
  echo -e "${RED}❌ Please choose only one: --build-backstage-image OR --pull-backstage-image${NC}"
  exit 1
fi

if [[ "${PULL_BACKSTAGE_IMAGE}" == "true" ]]; then
  echo -e "${YELLOW}⏳ Pulling Backstage image: ${BACKSTAGE_IMAGE_REMOTE}${NC}"
  ${DOCKER_CMD} pull "${BACKSTAGE_IMAGE_REMOTE}"
  ${DOCKER_CMD} tag "${BACKSTAGE_IMAGE_REMOTE}" localhost:5000/om-backstage:local
  echo -e "${BLUE}📦 Pushing image to local registry...${NC}"
  ${DOCKER_CMD} push localhost:5000/om-backstage:local
  echo -e "${GREEN}✅ Image pulled + pushed.${NC}"
elif [[ "${BUILD_BACKSTAGE_IMAGE}" == "true" ]]; then
  echo -e "${YELLOW}⏳ Building Backstage image (this can take a while)...${NC}"
  ${DOCKER_CMD} build \
    -t localhost:5000/om-backstage:local \
    -f "${BACKSTAGE_DIR}/Dockerfile.multistage" \
    "${BACKSTAGE_DIR}"
  echo -e "${BLUE}📦 Pushing image to local registry...${NC}"
  ${DOCKER_CMD} push localhost:5000/om-backstage:local
  echo -e "${GREEN}✅ Image built + pushed.${NC}"
else
  echo -e "${BLUE}🔎 Checking for Backstage image in local registry cache...${NC}"
  if ${DOCKER_CMD} images --format '{{.Repository}}:{{.Tag}}' | grep -q "localhost:5000/om-backstage:local"; then
    echo -e "${GREEN}✅ Backstage image found${NC}"
  else
    echo -e "${RED}❌ Backstage image not found!${NC}"
    echo -e "${YELLOW}Build it with:${NC}"
    echo -e "  $0 --build-backstage-image"
    echo -e "${YELLOW}Or pull it with:${NC}"
    echo -e "  $0 --pull-backstage-image"
    exit 1
  fi
fi

# Import the image into the k3d cluster to avoid flaky pulls and local registry HTTPS/HTTP issues.
# Kubelet/containerd may attempt HTTPS when pulling from the local registry; importing avoids that.
BACKSTAGE_IMAGE_LOCALHOST="localhost:5000/om-backstage:local"
BACKSTAGE_IMAGE_K3D="k3d-om-registry:${K3D_REGISTRY_PORT}/om-backstage:local"
echo -e "${BLUE}\U0001F4E6 Importing Backstage image into k3d...${NC}"
${DOCKER_CMD} tag "${BACKSTAGE_IMAGE_LOCALHOST}" "${BACKSTAGE_IMAGE_K3D}" 2>/dev/null || true
$K3D_CMD image import --cluster om-cluster "${BACKSTAGE_IMAGE_K3D}" >/dev/null 2>&1 || true
echo -e "${GREEN}\u2705 Backstage image imported into k3d.${NC}"

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

# Pre-pull and import the PostgreSQL image into k3d to avoid flaky in-node pulls/DNS.
if $K3D_CMD cluster list 2>/dev/null | awk '{print $1}' | grep -qx "om-cluster"; then
  echo -e "${BLUE}📦 Ensuring PostgreSQL image is available in k3d...${NC}"
  if ${DOCKER_CMD} image inspect "${DESIRED_PG_IMAGE}" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ PostgreSQL image already present locally${NC}"
  else
    echo -e "${YELLOW}⏳ Pulling PostgreSQL image from Docker Hub...${NC}"
    PULL_OK=false
    for _attempt in 1 2 3; do
      if ${DOCKER_CMD} pull "${DESIRED_PG_IMAGE}" >/dev/null 2>&1; then
        PULL_OK=true
        break
      fi
      echo -e "${YELLOW}⚠️  Pull attempt ${_attempt}/3 failed; retrying in 5s...${NC}"
      sleep 5
    done

    if [[ "${PULL_OK}" != "true" ]]; then
      echo -e "${RED}❌ Unable to pull '${DESIRED_PG_IMAGE}' from Docker Hub.${NC}"
      echo -e "${YELLOW}This usually means your machine can't reach registry-1.docker.io (network/proxy/DNS).${NC}"
      echo -e "${YELLOW}Fix options:${NC}"
      echo -e "${YELLOW}  1) Ensure you have internet access to Docker Hub, then re-run this script.${NC}"
      echo -e "${YELLOW}  2) Pre-load the image into Docker by other means, then re-run this script.${NC}"
      echo -e "${YELLOW}     (Once present locally, the script will import it into k3d without pulling.)${NC}"
      exit 1
    fi
  fi

  $K3D_CMD image import -c om-cluster "${DESIRED_PG_IMAGE}" >/dev/null 2>&1 || true
fi

# If a previous run/ArgoCD/values drift left PostgreSQL pointing at a non-existent tag,
# force the StatefulSet template to use the desired image so Helm --wait can complete.
if kubectl get statefulset -n backstage backstage-postgresql &>/dev/null; then
  CURRENT_STS_PG_IMAGE=$(kubectl get statefulset -n backstage backstage-postgresql -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
  if [[ -n "${CURRENT_STS_PG_IMAGE}" && "${CURRENT_STS_PG_IMAGE}" != "${DESIRED_PG_IMAGE}" ]]; then
    echo -e "${YELLOW}🩹 Fixing PostgreSQL StatefulSet image '${CURRENT_STS_PG_IMAGE}' -> '${DESIRED_PG_IMAGE}'...${NC}"
    kubectl -n backstage set image statefulset/backstage-postgresql postgresql="${DESIRED_PG_IMAGE}" || true
    kubectl -n backstage delete pod backstage-postgresql-0 --ignore-not-found=true || true
    kubectl -n backstage rollout status sts/backstage-postgresql --timeout=10m || true
  fi
fi

if kubectl get pod -n backstage backstage-postgresql-0 &>/dev/null; then
  CURRENT_PG_IMAGE=$(kubectl get pod -n backstage backstage-postgresql-0 -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true)
  if [[ -n "${CURRENT_PG_IMAGE}" && "${CURRENT_PG_IMAGE}" != "${DESIRED_PG_IMAGE}" ]]; then
    echo -e "${YELLOW}🧹 PostgreSQL pod is using '${CURRENT_PG_IMAGE}'. Recreating to pick up '${DESIRED_PG_IMAGE}'...${NC}"
    kubectl delete pod -n backstage backstage-postgresql-0 --ignore-not-found=true
  fi
fi

# Create temporary override with dynamic values
# macOS mktemp can occasionally fail with 'File exists' (rare collision / template issues).
# Retry a few times with a safer template under TMPDIR.
OVERRIDE_FILE=""
for _dir in "${TMPDIR:-}" "/tmp"; do
  [[ -z "${_dir}" ]] && continue
  for _i in 1 2 3 4 5; do
    OVERRIDE_FILE=$(mktemp "${_dir%/}/backstage-override.XXXXXXXXXX" 2>/dev/null || true)
    if [[ -n "${OVERRIDE_FILE}" && -f "${OVERRIDE_FILE}" ]]; then
      break 2
    fi
    OVERRIDE_FILE=""
  done
done
if [[ -z "${OVERRIDE_FILE}" ]]; then
  echo -e "${RED}❌ Failed to create temporary Helm override file under ${TMPDIR:-/tmp}${NC}"
  exit 1
fi
cat > "${OVERRIDE_FILE}" <<EOF
commonLabels:
  backstage.io/kubernetes-id: backstage

backstage:
  pdb:
    create: false
  autoscaling:
    enabled: false
  extraEnvVars:
    - name: OM_GIT_REVISION
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: OM_GIT_REVISION
    - name: OM_GIT_REPO_URL
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: OM_GIT_REPO_URL
    - name: GITHUB_TOKEN
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: GITHUB_TOKEN
    - name: GITHUB_ORG
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: GITHUB_ORG
    - name: GITHUB_REPO
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: GITHUB_REPO
    - name: GOOGLE_CLIENT_ID
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: GOOGLE_CLIENT_ID
    - name: GOOGLE_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: GOOGLE_CLIENT_SECRET
    - name: KUBERNETES_SA_TOKEN
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: KUBERNETES_SA_TOKEN
    - name: KUBERNETES_API_URL
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: KUBERNETES_API_URL
    - name: KUBERNETES_CA_DATA
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: KUBERNETES_CA_DATA
    - name: ARGOCD_USERNAME
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: ARGOCD_USERNAME
    - name: ARGOCD_PASSWORD
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: ARGOCD_PASSWORD
    - name: AWS_ACCESS_KEY_ID
      valueFrom:
        secretKeyRef:
          name: backstage-s3-auth
          key: AWS_ACCESS_KEY_ID
          optional: true
    - name: AWS_SECRET_ACCESS_KEY
      valueFrom:
        secretKeyRef:
          name: backstage-s3-auth
          key: AWS_SECRET_ACCESS_KEY
          optional: true
    - name: AWS_REGION
      valueFrom:
        secretKeyRef:
          name: backstage-s3-auth
          key: AWS_REGION
          optional: true
    - name: TECHDOCS_BUCKET_NAME
      valueFrom:
        secretKeyRef:
          name: backstage-s3-auth
          key: TECHDOCS_BUCKET_NAME
          optional: true
  image:
    registry: "k3d-om-registry:5000"
    repository: om-backstage
    tag: local
    pullPolicy: Never
  appConfig:
    app:
      baseUrl: ${BACKSTAGE_BASE_URL}
    backend:
      baseUrl: ${BACKSTAGE_BASE_URL}
      cors:
        origin: ${BACKSTAGE_BASE_URL}
        methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
        credentials: true
      reading:
        allow:
          - host: raw.githubusercontent.com
          - host: github.com
      database:
        client: pg
        connection:
          host: backstage-postgresql
          port: 5432
          user: postgres
          password: \${POSTGRES_PASSWORD}
          database: backstage

    kubernetes:
      serviceLocatorMethod:
        type: multiTenant
      clusterLocatorMethods:
        - type: config
          clusters:
            - name: local-cluster
              url: https://kubernetes.default.svc
              authProvider: serviceAccount
              serviceAccountToken: \${KUBERNETES_SA_TOKEN}
              skipTLSVerify: true
    
    integrations:
      github:
        - host: github.com
          token: \${GITHUB_TOKEN}
    
    catalog:
      providers: {}
      locations:
        - type: url
          target: https://github.com/\${GITHUB_ORG}/\${GITHUB_REPO}/blob/${OM_GIT_REVISION}/platform/portal/backstage/catalog/users.yaml
        - type: url
          target: https://github.com/\${GITHUB_ORG}/\${GITHUB_REPO}/blob/${OM_GIT_REVISION}/platform/portal/backstage/catalog-info.yaml
        - type: url
          target: https://github.com/\${GITHUB_ORG}/\${GITHUB_REPO}/blob/${OM_GIT_REVISION}/platform/portal/backstage/templates/new-application/template.yaml
        - type: url
          target: https://github.com/\${GITHUB_ORG}/\${GITHUB_REPO}/blob/${OM_GIT_REVISION}/platform/portal/backstage/templates/request-service/template.yaml
        - type: url
          target: https://github.com/\${GITHUB_ORG}/\${GITHUB_REPO}/blob/${OM_GIT_REVISION}/platform/portal/backstage/templates/team-onboarding/template.yaml
    
    argocd:
      baseUrl: https://${ARGOCD_DOMAIN}
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

# On re-runs ArgoCD owns fields on Backstage resources via server-side apply.
# Suspend ArgoCD auto-sync on the backstage app so it can't re-claim ownership
# between our cleanup and the Helm upgrade, then resume it after.
kubectl -n argocd patch application backstage \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}' >/dev/null 2>&1 || true

# The ingress-nginx admission webhook uses a self-signed cert that becomes stale
# across cluster restarts. Delete it before any Helm install that creates Ingress
# resources — Helm will fail with x509 errors otherwise. ingress-nginx recreates
# it automatically on its next sync.
kubectl delete validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found=true >/dev/null 2>&1 || true

# Strip managedFields from conflicting resources so Helm can re-claim ownership cleanly.
for resource in \
  "configmap/backstage-app-config" \
  "deployment/backstage" \
  "ingress/backstage"; do
  if kubectl get -n backstage "${resource}" >/dev/null 2>&1; then
    kubectl patch -n backstage "${resource}" \
      --type=json \
      -p='[{"op":"remove","path":"/metadata/managedFields"}]' \
      >/dev/null 2>&1 || true
  fi
done

# If a previous rollout left a stale ProgressDeadlineExceeded condition on the
# deployment, Helm --wait will immediately fail. Reset it by bumping the deadline
# so Kubernetes re-evaluates the condition fresh on the next rollout.
if kubectl get deployment backstage -n backstage >/dev/null 2>&1; then
  kubectl -n backstage patch deployment backstage \
    --type merge \
    -p '{"spec":{"progressDeadlineSeconds":1200}}' >/dev/null 2>&1 || true
fi

# Deploy Backstage with external PostgreSQL
echo -e "${YELLOW}⏳ Starting Helm deployment (this may take a few minutes)...${NC}"
helm upgrade --install backstage backstage/backstage \
  --version 0.22.5 \
  -n backstage \
  -f "${HELM_VALUES}" \
  -f "${OVERRIDE_FILE}" \
  --skip-schema-validation \
  --force-conflicts \
  --timeout 20m \
  --wait

# Re-enable ArgoCD auto-sync on backstage now that Helm has finished.
kubectl -n argocd patch application backstage \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' >/dev/null 2>&1 || true

# Backstage catalog migrations can fail hard in some chart/image combinations if
# legacy tables are missing or a previous migration left a lock behind.
# Make the bootstrap idempotent by ensuring legacy tables exist (so 'drop table'
# migrations succeed) and by releasing any stuck migration lock.
kubectl -n backstage exec deploy/backstage -- node -e "const {Client}=require('pg');(async()=>{const db='backstage_plugin_catalog';const c=new Client({host:process.env.POSTGRES_HOST||'backstage-postgresql',port:Number(process.env.POSTGRES_PORT||5432),user:process.env.POSTGRES_USER||'postgres',password:process.env.POSTGRES_PASSWORD,database:db});await c.connect();await c.query('create table if not exists entities (id serial primary key, entity_id text, entity text)');await c.query('create table if not exists entities_relations (id serial primary key, entity_id text, relation_type text, target_entity_id text)');await c.query('create table if not exists entities_search (id serial primary key, entity_id text, document text)');try{await c.query('update knex_migrations_lock set is_locked=0 where index=1');}catch(e){};await c.end();console.log('catalog db bootstrap complete');})().catch(e=>{console.error(e);process.exit(1)});" >/dev/null 2>&1 || true

# Ensure pods carry the Kubernetes plugin identifier label. The chart version
# used here doesn't reliably propagate commonLabels into the pod template.
kubectl -n backstage patch deploy/backstage \
  --type merge \
  -p '{"spec":{"template":{"metadata":{"labels":{"backstage.io/kubernetes-id":"backstage"}}}}}' >/dev/null 2>&1 || true

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
apiVersion: traefik.io/v1alpha1
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
apiVersion: traefik.io/v1alpha1
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
OM_GIT_REPO_SSH="${OM_GIT_REPO_SSH:-git@github.com:${GITHUB_ORG}/${GITHUB_REPO}.git}"

# Apply ArgoCD bootstrap manifests. The argocd/ files no longer contain template
# variables — they have the real repo URL baked in. The sed substitution is kept
# only for projects.yaml which still uses __OM_GIT_REPO_URL__ / __OM_GIT_REPO_SSH__.
sed -e "s|__OM_GIT_REPO_URL__|${OM_GIT_REPO_URL}|g" \
    -e "s|__OM_GIT_REPO_SSH__|${OM_GIT_REPO_SSH}|g" \
    "${PROJECT_ROOT}/argocd/bootstrap/projects.yaml" | kubectl apply -f - 2>/dev/null || true

kubectl apply -f "${PROJECT_ROOT}/argocd/apps/infrastructure/backstage.yaml" 2>/dev/null || true
kubectl apply -f "${PROJECT_ROOT}/argocd/bootstrap/app-of-apps.yaml" 2>/dev/null || true
kubectl apply -f "${PROJECT_ROOT}/argocd/applicationsets/team-apps.yaml" 2>/dev/null || true

sed -e "s|__OM_GIT_REPO_URL__|${OM_GIT_REPO_URL}|g" \
    -e "s|__OM_GIT_REVISION__|${OM_GIT_REVISION}|g" \
    "${PROJECT_ROOT}/argocd/bootstrap/argocd-cm.yaml" | kubectl apply -f - 2>/dev/null || true

# Deploy cert-manager via ArgoCD before cert-issuers (cert-issuers depends on cert-manager CRDs)
echo -e "${BLUE}🔐 Deploying cert-manager...${NC}"
kubectl apply -f "${PROJECT_ROOT}/argocd/apps/infrastructure/cert-manager.yaml" 2>/dev/null || true

# Wait for ArgoCD to sync cert-manager (it deploys asynchronously)
echo -e "${BLUE}⏳ Waiting for cert-manager pods to start (ArgoCD sync)...${NC}"
retry 60 5 bash -c 'kubectl get pods -n cert-manager 2>/dev/null | grep -q "cert-manager"' || true

# Wait for cert-manager CRDs to be fully established
echo -e "${BLUE}⏳ Waiting for cert-manager CRDs to be ready...${NC}"
for crd in clusterissuers.cert-manager.io certificates.cert-manager.io certificaterequests.cert-manager.io; do
  kubectl wait --for=condition=Established "crd/${crd}" --timeout=5m 2>/dev/null || true
done

# Wait for cert-manager webhook to be ready (required before creating ClusterIssuers)
kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=5m 2>/dev/null || true
echo -e "${GREEN}✅ cert-manager ready.${NC}"

kubectl apply -f "${PROJECT_ROOT}/argocd/apps/infrastructure/cert-issuers.yaml" 2>/dev/null || true

# Ensure Backstage ArgoCD app uses the pre-created service account.
# sources[0] = Helm chart (backstage.github.io/charts)
# sources[1] = git values ref (github.com/JOELNATHAN544/om.git)
kubectl -n argocd patch application backstage --type='json' -p='[
  {"op":"add","path":"/spec/sources/0/helm/parameters/-","value":{"name":"serviceAccount.create","value":"false"}},
  {"op":"add","path":"/spec/sources/0/helm/parameters/-","value":{"name":"serviceAccount.name","value":"backstage"}}
]' 2>/dev/null || true

kubectl -n argocd annotate application backstage argocd.argoproj.io/refresh=hard --overwrite 2>/dev/null || true

# =============================================================================
# 11. Fix cert-issuers for local k3d environment
# =============================================================================
# Disable Let's Encrypt issuers which don't work in local k3d environment
# Apply updated cert-manager manifests with only self-signed and CA issuers
kubectl apply -f "${PROJECT_ROOT}/security/cert-manager/cluster-issuer.yaml" 2>/dev/null || true

# Restart ArgoCD server to pick up updated AppProject configuration
kubectl rollout restart deployment/argocd-server -n argocd 2>/dev/null || true
kubectl rollout restart deployment/argocd-repo-server -n argocd 2>/dev/null || true

# Wait for ArgoCD components to be ready
kubectl rollout status deployment/argocd-server -n argocd --timeout=5m 2>/dev/null || true
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=5m 2>/dev/null || true

# Hard-refresh all apps so ArgoCD picks up the latest git commit immediately
for app in $(kubectl get applications -n argocd --no-headers 2>/dev/null | awk '{print $1}'); do
  kubectl -n argocd annotate application "$app" argocd.argoproj.io/refresh=hard --overwrite 2>/dev/null || true
done

# =============================================================================
# Done!
# =============================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✨  OM Platform is LIVE!                        ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Portal:  https://${BACKSTAGE_DOMAIN}${NC}"
echo -e "${GREEN}║  ArgoCD:  https://${ARGOCD_DOMAIN}${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${YELLOW}║  Add these to /etc/hosts on your machine:        ║${NC}"
TRAEFIK_IP=$(kubectl -n kube-system get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
if [[ -z "${TRAEFIK_IP}" ]]; then
  echo -e "${YELLOW}║    <TRAEFIK_LB_IP>  ${BACKSTAGE_DOMAIN}${NC}"
  echo -e "${YELLOW}║    <TRAEFIK_LB_IP>  ${ARGOCD_DOMAIN}${NC}"
else
  echo -e "${YELLOW}║    ${TRAEFIK_IP}  ${BACKSTAGE_DOMAIN}${NC}"
  echo -e "${YELLOW}║    ${TRAEFIK_IP}  ${ARGOCD_DOMAIN}${NC}"

  RESOLVED_IP=$(getent hosts "${BACKSTAGE_DOMAIN}" 2>/dev/null | awk '{print $1}' | head -n 1 || true)
  if [[ -n "${RESOLVED_IP}" && "${RESOLVED_IP}" != "${TRAEFIK_IP}" ]]; then
    echo -e "${YELLOW}║  WARN: ${BACKSTAGE_DOMAIN} resolves to ${RESOLVED_IP} (expected ${TRAEFIK_IP})${NC}"
    echo -e "${YELLOW}║        Run: sudo ${PROJECT_ROOT}/scripts/update-backstage-hosts.sh --apply${NC}"
  fi
fi
echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  ArgoCD admin password: ${YELLOW}${ARGOCD_PASS}${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📝 Next steps:${NC}"
echo -e "   1. Add the /etc/hosts entries above"
echo -e "      (After reboot, re-run the helper to refresh the Traefik IP)"
echo -e "      sudo ${PROJECT_ROOT}/scripts/update-backstage-hosts.sh --apply"
echo -e "   2. Access Backstage at https://${BACKSTAGE_DOMAIN}"
echo -e "   3. Accept the self-signed certificate warning"
echo -e "   4. Sign in with Google OAuth"
echo ""
echo -e "${BLUE}🔍 Troubleshooting:${NC}"
echo -e "   Check pods:    kubectl get pods -n backstage"
echo -e "   Check logs:    kubectl logs -n backstage -l app.kubernetes.io/name=backstage"
echo -e "   Check ingress: kubectl get ingress -n backstage"

SKIP_SMOKE_TEST="${SKIP_SMOKE_TEST:-false}"
if [[ "${SKIP_SMOKE_TEST}" != "true" ]]; then
  http_smoke_test "Backstage" "https://${BACKSTAGE_DOMAIN}/"
  http_smoke_test "ArgoCD" "https://${ARGOCD_DOMAIN}/"
fi

FIX_COREDNS_ON_DNS_FAILURE="${FIX_COREDNS_ON_DNS_FAILURE:-false}"
if [[ "${FIX_COREDNS_ON_DNS_FAILURE}" == "true" ]]; then
  echo ""
  echo -e "${BLUE}🧪 Checking in-cluster DNS (OAuth/GitHub/TechDocs depend on this)...${NC}"
  if kubectl -n backstage exec deploy/backstage -- node -e "require('node:dns').promises.lookup('oauth2.googleapis.com').then(()=>process.exit(0)).catch(()=>process.exit(1))" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ In-cluster DNS OK${NC}"
  else
    echo -e "${YELLOW}⚠️  In-cluster DNS lookup failed. Applying CoreDNS forwarder fix...${NC}"
    kubectl -n kube-system get cm coredns -o yaml \
      | sed 's|forward \\. /etc/resolv\\.conf|forward . 1.1.1.1 8.8.8.8|g' \
      | kubectl apply -f - >/dev/null
    kubectl -n kube-system rollout restart deploy/coredns >/dev/null
    kubectl -n kube-system rollout status deploy/coredns --timeout=2m >/dev/null || true

    if kubectl -n backstage exec deploy/backstage -- node -e "require('node:dns').promises.lookup('oauth2.googleapis.com').then(()=>process.exit(0)).catch(()=>process.exit(1))" >/dev/null 2>&1; then
      echo -e "${GREEN}✅ CoreDNS fix applied; DNS now works${NC}"
    else
      echo -e "${RED}❌ CoreDNS fix attempted but DNS is still failing${NC}"
      echo -e "${YELLOW}   Check CoreDNS logs: kubectl -n kube-system logs deploy/coredns --since=10m${NC}"
    fi
  fi
fi
