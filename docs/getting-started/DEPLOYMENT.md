# Backstage Deployment Guide

This guide walks you through deploying the OM Platform's self-service developer portal (Backstage).

## Prerequisites

### System Requirements
- **OS**: macOS or Linux (Ubuntu/Debian)
- **RAM**: 8GB minimum (16GB recommended)
- **Disk**: 20GB free space
- **CPU**: 4 cores recommended

### Required Tools
The deployment script will auto-install these if missing:
- Docker (API version ≥1.44)
- k3d (Kubernetes in Docker)
- kubectl
- helm

### Required Accounts & Credentials

1. **GitHub Account** with:
   - Organization access (or personal account for testing)
   - Ability to create Personal Access Tokens

2. **Google Cloud Account** for OAuth:
   - Access to Google Cloud Console
   - Ability to create OAuth 2.0 credentials

3. **AWS Account** (Optional - for TechDocs S3 storage):
   - S3 bucket creation permissions
   - IAM user creation permissions

## Deployment Steps

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/om.git
cd om
```

### 2. Configure Secrets

Copy the example configuration:

```bash
cp configs/secrets-templates/backstage-secrets.env.example \
   configs/secrets-templates/backstage-secrets.env
```

Edit the file with your actual values:

```bash
nano configs/secrets-templates/backstage-secrets.env
```

**Minimum required configuration:**

```bash
# GitHub
GITHUB_TOKEN=ghp_your_token_here
GITHUB_ORG=your-org-or-username
GITHUB_REPO=om

# Google OAuth
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your-secret

# Database
POSTGRES_PASSWORD=secure-password-here

# Domain
BACKSTAGE_DOMAIN=portal.backstage.com
```

See [Secrets Configuration Guide](../../configs/secrets-templates/README.md) for detailed instructions.

### 3. Run the Deployment Script

```bash
./scripts/platform-up-v2.sh
```

The script will:
1. ✅ Validate your configuration
2. ✅ Install required dependencies
3. ✅ Create a local Kubernetes cluster (k3d)
4. ✅ Install ArgoCD
5. ✅ Build the Backstage Docker image
6. ✅ Deploy PostgreSQL
7. ✅ Deploy Backstage
8. ✅ Configure ingress and TLS

**Expected duration:** 10-15 minutes (first run)

### 4. Configure DNS

Add these entries to your `/etc/hosts` file:

```bash
# On macOS/Linux:
sudo nano /etc/hosts

# Add these lines:
127.0.0.1  portal.backstage.com
127.0.0.1  argocd.backstage.com
```

On Windows, edit `C:\Windows\System32\drivers\etc\hosts` as Administrator.

### 5. Access Backstage

Open your browser and navigate to:
- **Backstage Portal**: https://portal.backstage.com
- **ArgoCD**: http://argocd.backstage.com

**Note:** You'll see a certificate warning because we're using self-signed certificates. Click "Advanced" → "Proceed" to continue.

### 6. Sign In

Click "Sign In" and choose "Google" to authenticate with your Google account.

## Verification

### Check Deployment Status

```bash
# Check all pods are running
kubectl get pods -n backstage

# Expected output:
# NAME                                    READY   STATUS    RESTARTS   AGE
# backstage-xxxxxxxxxx-xxxxx              1/1     Running   0          5m
# backstage-postgresql-0                  1/1     Running   0          5m
```

### Check Logs

```bash
# View Backstage logs
kubectl logs -n backstage -l app.kubernetes.io/name=backstage -f

# View PostgreSQL logs
kubectl logs -n backstage backstage-postgresql-0
```

### Check Ingress

```bash
kubectl get ingress -n backstage

# Expected output:
# NAME        CLASS     HOSTS                   ADDRESS      PORTS     AGE
# backstage   traefik   portal.backstage.com    172.x.x.x    80, 443   5m
```

## Troubleshooting

### Issue: "Configuration file not found"

**Solution:** Create the config file from the example:
```bash
cp configs/secrets-templates/backstage-secrets.env.example \
   configs/secrets-templates/backstage-secrets.env
```

### Issue: "Missing or invalid required variables"

**Solution:** Edit your config file and replace all placeholder values:
```bash
nano configs/secrets-templates/backstage-secrets.env
```

Look for and replace:
- `your-token-here`
- `your-org-name`
- `change-me-in-production`

### Issue: Backstage pod is CrashLooping

**Check logs:**
```bash
kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=100
```

**Common causes:**
1. **Database connection failed**: Check PostgreSQL is running
   ```bash
   kubectl get pods -n backstage | grep postgresql
   ```

2. **Invalid GitHub token**: Verify token has correct scopes
   ```bash
   # Test token
   curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
   ```

3. **Invalid Google OAuth credentials**: Check client ID and secret

### Issue: Cannot access portal (connection refused)

**Check ingress:**
```bash
kubectl get ingress -n backstage
kubectl describe ingress backstage -n backstage
```

**Verify /etc/hosts:**
```bash
cat /etc/hosts | grep backstage
```

**Check if port 80/443 are available:**
```bash
# On Linux
sudo netstat -tulpn | grep -E ':(80|443)'

# On macOS
sudo lsof -i :80
sudo lsof -i :443
```

### Issue: "OAuth error" when signing in

**Verify redirect URI in Google Console:**
1. Go to https://console.cloud.google.com/apis/credentials
2. Click your OAuth client
3. Ensure redirect URIs include:
   - `https://portal.backstage.com/api/auth/google/handler/frame`

**Check OAuth configuration:**
```bash
kubectl get secret backstage-secrets -n backstage -o jsonpath='{.data.GOOGLE_CLIENT_ID}' | base64 -d
```

### Issue: Templates not showing up

**Check catalog locations:**
```bash
# View Backstage logs for catalog errors
kubectl logs -n backstage -l app.kubernetes.io/name=backstage | grep -i catalog
```

**Verify GitHub access:**
```bash
# Test if Backstage can access your repo
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO/contents/platform/portal/backstage/templates
```

### Issue: Docker build fails

**Check Docker version:**
```bash
docker version
```

**Increase Docker resources:**
- Docker Desktop → Settings → Resources
- Increase Memory to at least 4GB
- Increase CPUs to at least 2

**Clear Docker cache:**
```bash
docker system prune -a
```

## Advanced Configuration

### Using a Different Domain

Edit your config file:
```bash
BACKSTAGE_DOMAIN=portal.mycompany.com
ARGOCD_DOMAIN=argocd.mycompany.com
```

Update /etc/hosts accordingly.

### Deploying to a Real Kubernetes Cluster

The script currently deploys to a local k3d cluster. To deploy to a real cluster:

1. **Set your kubeconfig:**
   ```bash
   export KUBECONFIG=/path/to/your/kubeconfig
   ```

2. **Skip cluster creation** (modify script or create cluster manually)

3. **Use real TLS certificates** (Let's Encrypt with cert-manager)

4. **Configure real DNS** (instead of /etc/hosts)

### Enabling Redis Cache

1. **Deploy Redis:**
   ```bash
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm install backstage-redis bitnami/redis -n backstage
   ```

2. **Update config:**
   ```bash
   REDIS_HOST=backstage-redis-master
   REDIS_PORT=6379
   ```

3. **Update Helm values** to use Redis instead of memory cache

### Configuring TechDocs with S3

1. **Create S3 bucket:**
   ```bash
   aws s3 mb s3://your-techdocs-bucket
   ```

2. **Create IAM user with S3 access**

3. **Update config:**
   ```bash
   AWS_ACCESS_KEY_ID=AKIA...
   AWS_SECRET_ACCESS_KEY=...
   TECHDOCS_BUCKET=your-techdocs-bucket
   ```

4. **Redeploy:**
   ```bash
   ./scripts/platform-up-v2.sh
   ```

## Production Deployment Checklist

Before deploying to production:

- [ ] Use a real Kubernetes cluster (EKS, GKE, AKS)
- [ ] Configure real DNS records
- [ ] Use Let's Encrypt for TLS certificates
- [ ] Deploy Redis for caching
- [ ] Configure S3 for TechDocs
- [ ] Set up database backups
- [ ] Configure monitoring and alerting
- [ ] Use a secrets manager (Vault, AWS Secrets Manager)
- [ ] Enable RBAC and proper permissions
- [ ] Configure resource limits and requests
- [ ] Set up log aggregation
- [ ] Configure high availability (multiple replicas)
- [ ] Set up disaster recovery procedures
- [ ] Document runbooks for common issues

## Next Steps

After successful deployment:

1. **Explore the Portal**: Browse the software catalog and available templates
2. **Create Your First App**: Use the "New Application" template
3. **Onboard Your Team**: Use the "Team Onboarding" template
4. **Add Your Services**: Create `catalog-info.yaml` files in your repositories
5. **Customize Templates**: Modify templates to match your organization's needs

## Support

For issues and questions:
- Check the [troubleshooting section](#troubleshooting) above
- Review logs: `kubectl logs -n backstage -l app.kubernetes.io/name=backstage`
- Consult [Backstage documentation](https://backstage.io/docs)
- Open an issue in the repository

## Cleanup

To remove the deployment:

```bash
# Delete the k3d cluster
k3d cluster delete om-cluster

# Delete the registry
k3d registry delete om-registry

# Remove kubeconfig
rm ~/.kube/config
```
