# [Backstage](https://backstage.io)

This is your newly scaffolded Backstage App, Good Luck!

To start the app, run:

```sh
yarn install
yarn start
```

## Google OAuth (local + prod)

### 1) Set Google OAuth Redirect URI(s)

In Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Client, set:

- Local dev redirect URI: `http://localhost:7007/api/auth/google/handler/frame`
- Production redirect URI: `https://portal.example.com/api/auth/google/handler/frame`

If your deployed URL is different, replace `portal.example.com` with your real domain.

### 2) Provide `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`

Local dev (shell env vars):

```sh
export GOOGLE_CLIENT_ID="..."
export GOOGLE_CLIENT_SECRET="..."
yarn start
```

Run frontend + backend in separate terminals (no scripts):

```sh
# Terminal 1 (backend)
cd platform/portal/backstage
export GOOGLE_CLIENT_ID="..."
export GOOGLE_CLIENT_SECRET="..."
export APP_CONFIG_FILES=app-config.yaml,app-config.local.yaml
yarn workspace backend start
```

```sh
# Terminal 2 (frontend)
cd platform/portal/backstage
export APP_CONFIG_FILES=app-config.yaml,app-config.local.yaml
yarn workspace app start
```

Alternative (recommended): create `platform/portal/backstage/.env` (gitignored) and run:

```sh
bash scripts/start-local.sh
```

Kubernetes (Helm): create/update the `backstage-secrets` secret with keys
`GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` (see `platform/portal/backstage/k8s-resources.yaml`).

### 3) Add a Backstage `User` for your email

This repo resolves Google sign-in using the resolver:
`emailMatchingUserEntityProfileEmail`.

That means you must have a `User` entity whose `spec.profile.email` matches your
Google account email exactly.

- Edit: `platform/portal/backstage/catalog/users.yaml`
- Set `spec.profile.email` to your real email

Then restart Backstage.

### 4) Verify the `User` is actually in the catalog (debug)

If Google login fails with “unable to resolve user identity”, verify the user entity exists:

```sh
# Get a guest token (works without catalog user mapping)
TOKEN="$(curl -s "http://localhost:7007/api/auth/guest/refresh?env=development" | jq -r .backstageIdentity.token)"

# Check your user exists in the catalog
curl -i -H "Authorization: Bearer ${TOKEN}" \
  "http://localhost:7007/api/catalog/entities/by-name/user/default/wankojoelnathan"

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

`platform/portal/backstage/app-config.production.yaml` and `helm/values/dev/backstage-values.yaml`
use:

- `GITHUB_ORG` (default: `skyengpro`)
- `GITHUB_REPO` (default: `om`)

Set them to match where this repo actually lives.
```

## Deploy (Helm + ArgoCD)

This repo deploys Backstage via ArgoCD using the upstream Backstage Helm chart:

- ArgoCD app: `argocd/apps/infrastructure/backstage.yaml`
- Values: `helm/values/dev/backstage-values.yaml`

Checklist:

1) Set your real domain everywhere you see `portal.example.com`
2) Create the `backstage-secrets` secret in the `backstage` namespace with:
   - `GOOGLE_CLIENT_ID`
   - `GOOGLE_CLIENT_SECRET`
   - `GITHUB_TOKEN` (if you use GitHub catalog integrations)
3) Ensure your Google OAuth client has a redirect URI for the deployed URL:
   `https://<your-domain>/api/auth/google/handler/frame`
4) Sync the ArgoCD application `backstage` and watch the pod logs for any missing config/env vars.
