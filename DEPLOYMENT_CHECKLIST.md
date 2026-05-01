# Backstage Deployment Checklist

Use this checklist to ensure a successful deployment.

## Pre-Deployment

### System Requirements
- [ ] macOS or Linux system available
- [ ] Minimum 8GB RAM (16GB recommended)
- [ ] 20GB free disk space
- [ ] 4 CPU cores available
- [ ] Docker installed and running

### Accounts & Access
- [ ] GitHub account with organization access
- [ ] Google Cloud account for OAuth
- [ ] AWS account (optional, for TechDocs S3)
- [ ] Admin access to create credentials

## Configuration Setup

### GitHub Configuration
- [ ] Created Personal Access Token at https://github.com/settings/tokens
- [ ] Token has `repo` scope
- [ ] Token has `read:org` scope
- [ ] Token has `read:user` scope
- [ ] Verified organization name is correct
- [ ] Verified repository name is correct

### Google OAuth Configuration
- [ ] Created OAuth 2.0 Client at https://console.cloud.google.com/apis/credentials
- [ ] Application type set to "Web application"
- [ ] Added redirect URI: `https://portal.backstage.com/api/auth/google/handler/frame`
- [ ] Added redirect URI: `http://localhost:7007/api/auth/google/handler/frame` (for local dev)
- [ ] Copied Client ID
- [ ] Copied Client Secret
- [ ] OAuth consent screen configured

### AWS Configuration (Optional)
- [ ] Created S3 bucket for TechDocs
- [ ] Created IAM user with S3 access
- [ ] Attached policy with required permissions:
  - [ ] `s3:PutObject`
  - [ ] `s3:GetObject`
  - [ ] `s3:ListBucket`
- [ ] Generated access key and secret
- [ ] Noted bucket name and region

### Secrets File
- [ ] Copied example: `cp configs/secrets-templates/backstage-secrets.env.example configs/secrets-templates/backstage-secrets.env`
- [ ] Filled in `GITHUB_TOKEN`
- [ ] Filled in `GITHUB_ORG`
- [ ] Filled in `GITHUB_REPO`
- [ ] Filled in `GOOGLE_CLIENT_ID`
- [ ] Filled in `GOOGLE_CLIENT_SECRET`
- [ ] Set `POSTGRES_PASSWORD` (strong password)
- [ ] Filled in AWS credentials (if using S3)
- [ ] Verified no placeholder values remain
- [ ] File is NOT committed to Git

## Deployment

### Run Script
- [ ] Executed: `./scripts/platform-up-v2.sh`
- [ ] Script validated configuration successfully
- [ ] Docker dependencies installed
- [ ] k3d cluster created
- [ ] ArgoCD installed
- [ ] Backstage image built successfully
- [ ] PostgreSQL deployed
- [ ] Backstage deployed
- [ ] No errors in script output
- [ ] Noted ArgoCD admin password

### DNS Configuration
- [ ] Added to `/etc/hosts`: `127.0.0.1  portal.backstage.com`
- [ ] Added to `/etc/hosts`: `127.0.0.1  argocd.backstage.com`
- [ ] Verified entries: `cat /etc/hosts | grep backstage`

## Verification

### Kubernetes Resources
- [ ] All pods running: `kubectl get pods -n backstage`
- [ ] Backstage pod status: Running
- [ ] PostgreSQL pod status: Running
- [ ] No CrashLoopBackOff errors
- [ ] Ingress created: `kubectl get ingress -n backstage`
- [ ] Secrets created: `kubectl get secrets -n backstage`

### Logs Check
- [ ] Backstage logs show no errors: `kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=50`
- [ ] PostgreSQL logs show successful startup
- [ ] No authentication errors
- [ ] No database connection errors

### Access Testing
- [ ] Can access https://portal.backstage.com in browser
- [ ] Accepted self-signed certificate warning
- [ ] Backstage UI loads successfully
- [ ] "Sign In" button visible
- [ ] Can click "Sign In with Google"
- [ ] Google OAuth flow works
- [ ] Successfully authenticated
- [ ] Redirected back to Backstage
- [ ] Can see software catalog
- [ ] Can see templates

### ArgoCD Access
- [ ] Can access http://argocd.backstage.com
- [ ] Can login with username: `admin`
- [ ] Can login with password from script output
- [ ] ArgoCD UI loads successfully

## Feature Verification

### Software Catalog
- [ ] Catalog page loads
- [ ] Can search for components
- [ ] GitHub integration working
- [ ] Catalog locations configured

### Templates
- [ ] Templates page loads
- [ ] "New Application" template visible
- [ ] "Request Service" template visible
- [ ] "Team Onboarding" template visible
- [ ] Can click on a template
- [ ] Template form loads

### Kubernetes Plugin
- [ ] Can view Kubernetes resources
- [ ] Cluster connection working
- [ ] Can see pods/deployments

### TechDocs
- [ ] TechDocs page accessible
- [ ] Documentation renders correctly
- [ ] S3 storage working (if configured)

## Troubleshooting (If Issues Found)

### Pod Issues
- [ ] Checked pod status: `kubectl get pods -n backstage`
- [ ] Checked pod logs: `kubectl logs -n backstage <pod-name>`
- [ ] Checked pod events: `kubectl describe pod -n backstage <pod-name>`
- [ ] Verified secrets exist: `kubectl get secrets -n backstage`

### Access Issues
- [ ] Verified /etc/hosts entries
- [ ] Checked ingress: `kubectl describe ingress backstage -n backstage`
- [ ] Verified ports 80/443 not in use
- [ ] Tried different browser
- [ ] Cleared browser cache

### Authentication Issues
- [ ] Verified Google OAuth redirect URIs
- [ ] Checked GOOGLE_CLIENT_ID in secrets
- [ ] Checked GOOGLE_CLIENT_SECRET in secrets
- [ ] Reviewed Backstage logs for auth errors

### Database Issues
- [ ] Verified PostgreSQL pod running
- [ ] Checked PostgreSQL logs
- [ ] Verified POSTGRES_PASSWORD in secrets
- [ ] Tested database connection from Backstage pod

## Post-Deployment

### Documentation
- [ ] Documented ArgoCD admin password (securely)
- [ ] Noted any custom configuration
- [ ] Created runbook for common issues
- [ ] Shared access instructions with team

### Team Onboarding
- [ ] Shared portal URL with team
- [ ] Explained authentication process
- [ ] Demonstrated template usage
- [ ] Provided documentation links

### Monitoring
- [ ] Set up log monitoring
- [ ] Configured alerts (if applicable)
- [ ] Documented troubleshooting steps
- [ ] Scheduled regular health checks

## Production Readiness (Future)

### Infrastructure
- [ ] Migrate to real Kubernetes cluster
- [ ] Configure real DNS records
- [ ] Set up Let's Encrypt certificates
- [ ] Deploy Redis for caching
- [ ] Configure database backups
- [ ] Set up high availability

### Security
- [ ] Migrate to secrets manager (Vault/AWS Secrets Manager)
- [ ] Configure RBAC properly
- [ ] Enable audit logging
- [ ] Set up network policies
- [ ] Regular security scans

### Operations
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure alerting
- [ ] Create disaster recovery plan
- [ ] Document runbooks
- [ ] Set up CI/CD pipeline

## Notes

**Date Deployed:** _______________

**Deployed By:** _______________

**Environment:** [ ] Development [ ] Staging [ ] Production

**Issues Encountered:**
```
(List any issues and how they were resolved)
```

**Custom Configuration:**
```
(Note any deviations from standard setup)
```

**Next Steps:**
```
(What needs to be done next)
```

---

**Status:** [ ] ✅ Fully Deployed [ ] ⚠️ Partially Working [ ] ❌ Failed

**Ready for Use:** [ ] Yes [ ] No [ ] With Limitations

**Approved By:** _______________

**Date:** _______________
