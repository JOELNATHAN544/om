# OM Platform - Quick Start Guide

Get the self-service developer portal running in 15 minutes.

## Prerequisites

- macOS or Linux
- 8GB RAM minimum
- Docker installed

## Setup (5 minutes)

### 1. Configure Secrets

```bash
# Copy the example
cp configs/secrets-templates/backstage-secrets.env.example \
   configs/secrets-templates/backstage-secrets.env

# Edit with your values
nano configs/secrets-templates/backstage-secrets.env
```

**Required values:**
- `GITHUB_TOKEN` - Create at https://github.com/settings/tokens (needs `repo`, `read:org`, `read:user` scopes)
- `GITHUB_ORG` - Your GitHub organization or username
- `GITHUB_REPO` - This repository name (usually `om`)
- `GOOGLE_CLIENT_ID` - Create at https://console.cloud.google.com/apis/credentials
- `GOOGLE_CLIENT_SECRET` - From Google Cloud Console
- `POSTGRES_PASSWORD` - Any secure password

### 2. Deploy

```bash
./scripts/platform-up-v2.sh
```

Wait 10-15 minutes for the deployment to complete.

### 3. Configure DNS

Add to `/etc/hosts`:
```bash
127.0.0.1  portal.backstage.com
127.0.0.1  argocd.backstage.com
```

### 4. Access

Open https://portal.backstage.com in your browser.

Accept the self-signed certificate warning and sign in with Google.

## Verification

```bash
# Check pods are running
kubectl get pods -n backstage

# View logs
kubectl logs -n backstage -l app.kubernetes.io/name=backstage -f
```

## Common Issues

### "Configuration file not found"
→ Run step 1 above to create the config file

### "Missing or invalid required variables"
→ Edit `configs/secrets-templates/backstage-secrets.env` and replace all placeholder values

### Pod is CrashLooping
→ Check logs: `kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=100`

### Cannot access portal
→ Verify `/etc/hosts` entry exists: `cat /etc/hosts | grep backstage`

### OAuth error
→ Verify redirect URI in Google Console includes: `https://portal.backstage.com/api/auth/google/handler/frame`

## What's Included

✅ Backstage developer portal  
✅ PostgreSQL 16 database (separate deployment)  
✅ ArgoCD for GitOps  
✅ Kubernetes plugin  
✅ GitHub integration  
✅ Google OAuth authentication  
✅ Software catalog  
✅ Three templates:
  - New Application
  - Request Service
  - Team Onboarding

**Note**: PostgreSQL is deployed separately using the official `postgres:16-alpine` image for better reliability and control. See [PostgreSQL Deployment Guide](docs/getting-started/POSTGRESQL_DEPLOYMENT.md) for details.

## Next Steps

1. **Explore**: Browse the software catalog
2. **Create**: Use templates to scaffold new applications
3. **Customize**: Modify templates for your needs
4. **Integrate**: Add your existing services to the catalog

## Full Documentation

- [Detailed Deployment Guide](docs/getting-started/DEPLOYMENT.md)
- [Secrets Configuration](configs/secrets-templates/README.md)
- [Architecture Overview](platform/portal/ARCHITECTURE.md)

## Cleanup

```bash
k3d cluster delete om-cluster
k3d registry delete om-registry
```

## Support

- Check logs: `kubectl logs -n backstage -l app.kubernetes.io/name=backstage`
- Review [troubleshooting guide](docs/getting-started/DEPLOYMENT.md#troubleshooting)
- Open an issue in the repository
