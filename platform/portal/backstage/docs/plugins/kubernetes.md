# Kubernetes Plugin

The Kubernetes plugin shows live cluster resources for each catalog component.

## What it Shows

On any component page, click the **Kubernetes** tab to see:

- Pods (status, restarts, age)
- Deployments (desired vs ready replicas)
- Services
- Recent pod logs

## How it Works

Each component is matched to its Kubernetes resources via annotations in `catalog-info.yaml`:

```yaml
annotations:
  backstage.io/kubernetes-id: my-service
  backstage.io/kubernetes-namespace: my-namespace
```

The plugin connects to the cluster using a read-only Service Account token stored in `backstage-secrets`.
