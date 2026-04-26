# OM Platform Portal — Backstage

Self-service developer portal built on [Backstage](https://backstage.io), deployed on Kubernetes (k3s) with HTTPS via Traefik Ingress.

**Live URL**: [https://portal.backstage.com](https://portal.backstage.com)

---

## Architecture

```
Browser (HTTPS)
    │
    ▼
Traefik Ingress (TLS termination, port 443)
    │
    ▼
Backstage ClusterIP Service (port 7007)
    │
    ▼
Backstage Pod
    ├── Google OAuth  → accounts.google.com
    ├── PostgreSQL    → backstage-postgresql (in-cluster)
    ├── GitHub API    → api.github.com (catalog discovery)
    └── ArgoCD / K8s  → cluster APIs (plugins)
```

---

## Quick Reference — Key Files

| File | Purpose |
|------|---------|
| `helm/values/prod/backstage-values.yaml` | Helm values (domain, auth, ingress, secrets) |
| `platform/portal/backstage/app-config.yaml` | Backstage base config |
| `platform/portal/backstage/app-config.production.yaml` | Production config overrides |
| `platform/portal/backstage/packages/backend/src/index.ts` | Backend entry point & auth resolver |
| `platform/portal/backstage/packages/backend/Dockerfile` | Docker image definition |
| `argocd/apps/infrastructure/backstage.yaml` | ArgoCD application manifest |

---

## Full Setup Guide (From Scratch)

Follow these steps in order. Each command is ready to copy-paste.

### Step 1 — Configure DNS (Local Machine)

Map the portal domain to your local machine:

```sh
echo "127.0.0.1 portal.backstage.com" | sudo tee -a /etc/hosts
```

Verify:

```sh
ping -c 1 portal.backstage.com
# Should resolve to 127.0.0.1
```

### Step 2 — Create the Namespace

```sh
kubectl create namespace backstage
```

### Step 3 — Add the Backstage Helm Repository

```sh
helm repo add backstage https://backstage.github.io/charts
helm repo update
```

### Step 4 — Create Container Registry Secret

This allows Kubernetes to pull the private Docker image from GitHub Container Registry:

```sh
kubectl create secret docker-registry ghcr-login \
  -n backstage \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-github-pat> \
  --docker-email=<your-email>
```

### Step 5 — Create Application Secrets

These secrets provide credentials to the Backstage application at runtime:

```sh
kubectl create secret generic backstage-secrets \
  -n backstage \
  --from-literal=GOOGLE_CLIENT_ID="<your-google-client-id>" \
  --from-literal=GOOGLE_CLIENT_SECRET="<your-google-client-secret>" \
  --from-literal=GITHUB_TOKEN="<your-github-pat>" \
  --from-literal=GITHUB_ORG="<your-github-org>" \
  --from-literal=GITHUB_REPO="<your-repo-name>"
```

> **To change the GitHub organization or repository later**, delete and recreate this secret with the new values, then restart the Backstage deployment (see Maintenance section below).

### Step 6 — Configure Google OAuth

Go to [Google Cloud Console → APIs & Services → Credentials](https://console.cloud.google.com/apis/credentials)
and configure your OAuth 2.0 Client:

| Setting | Value |
|---------|-------|
| **Authorized JavaScript origins** | `https://portal.backstage.com` |
| **Authorized redirect URIs** | `https://portal.backstage.com/api/auth/google/handler/frame` |

> **Important**: Google rejects `.local` domains. We use `portal.backstage.com` (a public-looking TLD) pointed at `127.0.0.1` via `/etc/hosts` to satisfy this requirement.

### Step 7 — Build the Application

```sh
cd platform/portal/backstage

# Install dependencies (only needed first time or after package changes)
yarn install

# Build the backend bundle (this also bundles the frontend)
yarn build:backend
```

### Step 8 — Build and Push the Docker Image

```sh
# Build the image
docker build --no-cache \
  -f packages/backend/Dockerfile \
  -t ghcr.io/<your-username>/<your-image-name>:latest .

# Push to GitHub Container Registry
docker push ghcr.io/<your-username>/<your-image-name>:latest
```

### Step 9 — Deploy with Helm

From the `platform/portal/backstage/` directory:

```sh
helm upgrade --install backstage backstage/backstage \
  -n backstage \
  -f ../../../helm/values/prod/backstage-values.yaml
```

### Step 10 — Verify the Deployment

```sh
# Watch pods until backstage and postgresql are both 1/1 Running
kubectl get pods -n backstage -w
```

Expected output:

```
NAME                         READY   STATUS    RESTARTS   AGE
backstage-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
backstage-postgresql-0       1/1     Running   0          30s
```

### Step 11 — Access the Portal

1. Open an **Incognito/Private** browser window
2. Go to: **https://portal.backstage.com**
3. Accept the self-signed certificate warning (**Advanced → Proceed**)
4. Click **SIGN IN** under Google
5. Authenticate with your Google account

---

## Updating the Application (After Code Changes)

Whenever you modify Backstage code or configuration, run the full pipeline:

```sh
# 1. Build the backend bundle
cd platform/portal/backstage
yarn build:backend

# 2. Build the Docker image
docker build --no-cache \
  -f packages/backend/Dockerfile \
  -t ghcr.io/<your-username>/<your-image-name>:latest .

# 3. Push to registry
docker push ghcr.io/<your-username>/<your-image-name>:latest

# 4. Deploy via Helm (picks up any values.yaml changes)
helm upgrade --install backstage backstage/backstage \
  -n backstage \
  -f ../../../helm/values/prod/backstage-values.yaml

# 5. Force pod restart to pull the new :latest image
kubectl rollout restart deployment backstage -n backstage

# 6. Watch the rollout
kubectl get pods -n backstage -w
```

---

## Maintenance Commands

### View Pod Logs

```sh
kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail 50
```

### Restart Backstage (without rebuilding)

```sh
kubectl rollout restart deployment backstage -n backstage
```

### Update Secrets (e.g., change GitHub org/repo)

```sh
# Delete the old secret
kubectl delete secret backstage-secrets -n backstage

# Recreate with new values
kubectl create secret generic backstage-secrets \
  -n backstage \
  --from-literal=GOOGLE_CLIENT_ID="<your-id>" \
  --from-literal=GOOGLE_CLIENT_SECRET="<your-secret>" \
  --from-literal=GITHUB_TOKEN="<your-token>" \
  --from-literal=GITHUB_ORG="NewOrgName" \
  --from-literal=GITHUB_REPO="new-repo-name"

# Restart to pick up new secrets
kubectl rollout restart deployment backstage -n backstage
```

### Check DNS From Inside the Pod

```sh
kubectl exec -n backstage deploy/backstage -- \
  node -e "require('dns').resolve('google.com', console.log)"
```

Expected output: `null [ '142.250.x.x' ]`

### Check Ingress Status

```sh
kubectl get ingress -n backstage
kubectl describe ingress backstage -n backstage
```

### Check All Resources in the Namespace

```sh
kubectl get all -n backstage
```

---

## Authentication

### Google OAuth (OIDC)

| Setting | Value |
|---------|-------|
| Provider | Google |
| Mode | Production (HTTPS enforced) |
| Auth environment | `production` |

### Automatic User Discovery

A custom sign-in resolver in `packages/backend/src/index.ts` automatically maps any Google user to a Backstage identity:

- `john.doe@gmail.com` → `user:default/john.doe`
- **No manual entry in `users.yaml` is required**
- Any Google account can authenticate

### Verify Your Identity

After login, click **Settings** (bottom-left sidebar). You should see:
- Your Google name and email under **Profile**
- A `User Entity` under **Backstage Identity**

---

## GitHub Integration

A GitHub Personal Access Token (PAT) is used for:

| Feature | Token Scope Required |
|---------|---------------------|
| Read private repos for catalog | `repo` |
| Scaffolder templates with GitHub Actions | `workflow` |
| Organization repository discovery | `read:org` |

The token is stored in the `backstage-secrets` Kubernetes secret as `GITHUB_TOKEN`.

---

## Troubleshooting

### Login fails: "Failed to obtain access token"

**Cause**: Backstage pod can't reach `google.com` (DNS failure).

```sh
# Fix: Restart DNS and Backstage
kubectl rollout restart deployment coredns -n kube-system
kubectl rollout restart deployment backstage -n backstage
```

### Login fails: "PopupRejectedError: Failed to open auth popup"

**Cause**: Browser is blocking the Google sign-in popup.

**Fix**: Allow popups for `https://portal.backstage.com` in your browser settings.

### Black page: "404 page not found" (from Traefik)

**Cause**: Traefik lost its connection to the Kubernetes API.

```sh
# Fix: Restart the entire cluster networking
sudo systemctl restart k3s

# Wait 30-60 seconds, then restart pods
kubectl rollout restart deployment coredns traefik -n kube-system
kubectl rollout restart deployment backstage -n backstage
```

### "Looks like someone dropped the mic!" (Backstage 404)

**Cause**: Normal behavior. The root URL (`/`) has no home page configured.

**Fix**: Use the sidebar to navigate to **Catalog**, **Create**, or **Docs**.

### DNS breaks after laptop sleep/wake

**Cause**: k3s internal networking freezes when the host machine sleeps.

```sh
# Fix: Restart k3s
sudo systemctl restart k3s

# Wait 30-60 seconds, then restart pods
kubectl rollout restart deployment coredns traefik -n kube-system
kubectl rollout restart deployment backstage -n backstage
```

### Helm upgrade fails: "additional properties not allowed"

**Cause**: Helm values schema mismatch.

```sh
# Check the chart's expected schema
helm show values backstage/backstage | grep -A 20 "service:"

# Verify your values file matches
cat helm/values/prod/backstage-values.yaml
```

---

## Helm Values Reference

| Value | Current Setting | Purpose |
|-------|-----------------|---------|
| `backstage.image.registry` | `ghcr.io` | Container registry |
| `backstage.image.repository` | `<your-username>/<your-image-name>` | Image name |
| `backstage.image.tag` | `latest` | Image version |
| `backstage.appConfig.app.baseUrl` | `https://portal.backstage.com` | Frontend URL |
| `backstage.appConfig.backend.baseUrl` | `https://portal.backstage.com` | Backend API URL |
| `backstage.appConfig.auth.environment` | `production` | Auth mode (HTTPS enforced) |
| `service.type` | `ClusterIP` | Internal service |
| `ingress.enabled` | `true` | Traefik Ingress active |
| `ingress.className` | `traefik` | Ingress controller |
| `ingress.host` | `portal.backstage.com` | Domain name |
| `ingress.tls.enabled` | `true` | HTTPS/TLS termination |
| `postgresql.enabled` | `true` | In-cluster PostgreSQL |
