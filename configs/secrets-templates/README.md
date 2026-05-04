# Secrets Configuration Guide

This directory contains templates for managing sensitive configuration for the OM Platform.

## Quick Start

1. **Copy the example file:**
   ```bash
   cp backstage-secrets.env.example backstage-secrets.env
   ```

2. **Edit with your values:**
   ```bash
   # Use your preferred editor
   nano backstage-secrets.env
   # or
   vim backstage-secrets.env
   ```

3. **Run the deployment:**
   ```bash
   ./scripts/platform-up-v2.sh
   ```

   If you need the script to build and push the Backstage image:
   ```bash
   ./scripts/platform-up-v2.sh --build-backstage-image
   ```

## Required Secrets

### GitHub Integration

Create a Personal Access Token at: https://github.com/settings/tokens

**Required Scopes:**
- `repo` - Full control of private repositories
- `read:org` - Read org and team membership
- `read:user` - Read user profile data

```bash
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GITHUB_ORG=your-organization-name
GITHUB_REPO=your-repository-name
```

### Google OAuth (Authentication)

Create OAuth 2.0 credentials at: https://console.cloud.google.com/apis/credentials

**Configuration:**
1. Create a new OAuth 2.0 Client ID
2. Application type: Web application
3. Authorized redirect URIs:
   - `https://portal.backstage.com/api/auth/google/handler/frame`
   - `http://localhost:7007/api/auth/google/handler/frame` (for local dev)

```bash
GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxxxxxxxxxxxxxxxxxxxx
```

### AWS Credentials (Optional - for TechDocs)

If you want to store documentation in S3:

1. Create an S3 bucket for TechDocs
2. Create an IAM user with S3 access
3. Attach policy with `s3:PutObject`, `s3:GetObject`, `s3:ListBucket` permissions

```bash
AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AWS_REGION=us-east-1
TECHDOCS_BUCKET=your-techdocs-bucket-name
```

**If not configured:** TechDocs will use local file storage.

### PostgreSQL

Set a strong password for the PostgreSQL database:

```bash
POSTGRES_PASSWORD=your-secure-password-here
```

### ArgoCD (Optional)

ArgoCD credentials are auto-generated during deployment. You can override them:

```bash
ARGOCD_USERNAME=admin
ARGOCD_PASSWORD=  # Leave empty to use auto-generated password
```

## Security Best Practices

### ✅ DO:
- Keep `backstage-secrets.env` out of version control (already in .gitignore)
- Use strong, unique passwords
- Rotate credentials regularly
- Use least-privilege IAM policies for AWS
- Store production secrets in a proper secrets manager (Vault, AWS Secrets Manager, etc.)

### ❌ DON'T:
- Commit secrets to Git
- Share secrets via email or chat
- Use the same credentials across environments
- Hardcode secrets in application code

## Environment-Specific Configuration

For multiple environments, create separate config files:

```bash
# Development
configs/secrets-templates/backstage-secrets.dev.env

# Staging
configs/secrets-templates/backstage-secrets.staging.env

# Production
configs/secrets-templates/backstage-secrets.prod.env
```

Deploy with:
```bash
./scripts/platform-up-v2.sh --config configs/secrets-templates/backstage-secrets.prod.env
```

## Troubleshooting

### "Configuration file not found"
Make sure you've copied the example file:
```bash
cp configs/secrets-templates/backstage-secrets.env.example \
   configs/secrets-templates/backstage-secrets.env
```

### "Missing or invalid required variables"
Check that all required variables are set and don't contain placeholder values like:
- `your-token-here`
- `change-me-in-production`
- `your-org-name`

### GitHub Token Issues
- Verify the token has the required scopes
- Check if the token has expired
- Ensure the organization name is correct

### Google OAuth Issues
- Verify redirect URIs match exactly (including protocol and port)
- Check that the OAuth consent screen is configured
- Ensure the client ID and secret are correct

## Migration from Old Script

If you were using the old `platform-up.sh` script with hardcoded values:

1. Create the new config file from the example
2. Copy your values from the old script to the new config file
3. Use the new script: `./scripts/platform-up-v2.sh`

The new script provides:
- ✅ No hardcoded secrets
- ✅ Configuration validation
- ✅ Better error messages
- ✅ Support for multiple environments
- ✅ Easier to maintain and audit
