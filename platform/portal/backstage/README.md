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
