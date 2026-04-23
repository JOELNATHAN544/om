# [Backstage](https://backstage.io)

This is your newly scaffolded Backstage App, Good Luck!

To start the app, run:

```sh
yarn install
yarn start
```

## Local Development & Deployment

### 1) Hosts File Configuration
To access the portal locally using its production-like domain, add this to your `/etc/hosts`:

```sh
127.0.0.1 portal.backstage.com
```

### 2) Google OAuth (HTTPS)

Google requires HTTPS for all domains except `localhost`. We use a "fake" public domain specifically to satisfy this security requirement.

**Google Cloud Console Settings:**
- Authorized JavaScript origins: `https://portal.backstage.com`
- Authorized redirect URIs: `https://portal.backstage.com/api/auth/google/handler/frame`

### 2) Provide `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`

Local dev (shell env vars):

```sh
export GOOGLE_CLIENT_ID="..."
export GOOGLE_CLIENT_SECRET="..."
export GITHUB_ORG="..."        # required (catalog GitHub provider)
export GITHUB_TOKEN="..."      # required (GitHub integration)
yarn start
```

Run frontend + backend in separate terminals (no scripts):

```sh
# Terminal 1 (backend)
cd platform/portal/backstage
export GOOGLE_CLIENT_ID="..."
export GOOGLE_CLIENT_SECRET="..."
export GITHUB_ORG="..."
export GITHUB_TOKEN="..."
export APP_CONFIG_FILES=app-config.yaml,app-config.local.yaml
yarn workspace backend start
```

### 3) Deployment (Local k3s)

The portal is deployed via Helm with a Traefik Ingress.

```sh
# 1. Build and push image
yarn build:backend
docker build -f packages/backend/Dockerfile -t ghcr.io/joelnathan544/om-backstage:latest .
docker push ghcr.io/joelnathan544/om-backstage:latest

# 2. Upgrade Helm
helm upgrade --install backstage backstage/backstage \
  -n backstage \
  -f ../../../helm/values/prod/backstage-values.yaml
```

Kubernetes Configuration:
- Values: `helm/values/prod/backstage-values.yaml`
- Secrets: `backstage-secrets` (Namespace: `backstage`)

### 4) Authentication & User Discovery

We have implemented an **Automatic User Identity Resolver**.

- **Behavior**: Any user who authenticates via Google is automatically mapped to a Backstage user based on their email local-part (e.g., `john.doe@gmail.com` -> `user:default/john.doe`).
- **No Manual Catalog Entry Required**: You do **not** need to manually add yourself to `users.yaml` to log in successfully.
- **Debugging**: If login fails, ensure your `GOOGLE_CLIENT_ID` in the `backstage-secrets` K8s secret matches the one in your Google Console.

## GitHub integration (catalog + templates)

Backstage needs a GitHub token to:

- Read catalog files from GitHub URLs (`catalog.locations`)
- Discover repositories that contain `catalog-info.yaml` (`catalog.providers.github.*`)
- Create PRs/repos when using the Scaffolder GitHub actions

### 1) Create a GitHub token

For a Personal Access Token (PAT), a typical starting point is:

- Private repos: `repo`
- Scaffolder with GitHub Actions templates: `workflow`
- Org discovery (optional): `read:org`

### 2) Provide `GITHUB_TOKEN` locally

```sh
export GITHUB_TOKEN="..."
```

### 3) Point Backstage at your org/repo (production + Helm)

`platform/portal/backstage/app-config.production.yaml` and `helm/values/prod/backstage-values.yaml`
use:

- `GITHUB_ORG`
- `GITHUB_REPO`

Set them to match where this repo actually lives.
```

## Deploy (Helm + ArgoCD)

This repo deploys Backstage via ArgoCD using the upstream Backstage Helm chart:

- ArgoCD app: `argocd/apps/infrastructure/backstage.yaml`
- Values: `helm/values/prod/backstage-values.yaml`

Checklist:

1) Set your real domain everywhere you see `portal.example.com`
2) Create the `backstage-secrets` secret in the `backstage` namespace with:
   - `GOOGLE_CLIENT_ID`
   - `GOOGLE_CLIENT_SECRET`
   - `GITHUB_TOKEN` (if you use GitHub catalog integrations)
3) Ensure your Google OAuth client has a redirect URI for the deployed URL:
   `https://<your-domain>/api/auth/google/handler/frame`
4) Sync the ArgoCD application `backstage` and watch the pod logs for any missing config/env vars.
