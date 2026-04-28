# ArgoCD Plugin

The ArgoCD plugin shows GitOps deployment status for each catalog component.

## What it Shows

On any component page, click the **ArgoCD** tab to see:

- Sync status (Synced / OutOfSync)
- Health status (Healthy / Degraded / Progressing)
- Last deployed commit
- Link to the full ArgoCD application

## How it Works

Each component is matched to its ArgoCD application via annotations in `catalog-info.yaml`:

```yaml
annotations:
  argocd/app-name: my-app-name
```

The plugin connects to ArgoCD using credentials stored in `backstage-secrets`.
