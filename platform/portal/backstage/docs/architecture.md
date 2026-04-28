# Architecture

## Overview

The OM Platform Portal is deployed on a **k3s** Kubernetes cluster using the official Backstage Helm chart with Traefik as the Ingress controller.

## Component Diagram

```
┌─────────────────────────────────────────────────┐
│                 Developer Browser                │
└───────────────────┬─────────────────────────────┘
                    │ HTTPS (443)
                    ▼
┌─────────────────────────────────────────────────┐
│         Traefik Ingress Controller               │
│         TLS termination @ portal.backstage.com   │
└───────────────────┬─────────────────────────────┘
                    │ HTTP (7007)
                    ▼
┌─────────────────────────────────────────────────┐
│              Backstage Pod                       │
│  ┌──────────────┐  ┌──────────────────────────┐ │
│  │   Frontend   │  │        Backend           │ │
│  │  (React SPA) │  │  (Node.js + plugins)     │ │
│  └──────────────┘  └──────────┬───────────────┘ │
└─────────────────────────────┬─┘─────────────────┘
           ┌──────────────────┼──────────────────┐
           ▼                  ▼                  ▼
   ┌───────────────┐  ┌──────────────┐  ┌──────────────┐
   │  PostgreSQL   │  │  GitHub API  │  │  Google OAuth│
   │  (catalog DB) │  │  (discovery) │  │  (auth)      │
   └───────────────┘  └──────────────┘  └──────────────┘
```

## Deployment

| Resource | Value |
|----------|-------|
| Kubernetes Distribution | k3s |
| Helm Chart | backstage/backstage |
| Image Registry | ghcr.io |
| Domain | portal.backstage.com |
| TLS | Traefik self-signed |
| Database | PostgreSQL 15 (in-cluster) |

## Secrets

All credentials are stored in the `backstage-secrets` Kubernetes Secret in the `backstage` namespace:

| Key | Purpose |
|-----|---------|
| `GOOGLE_CLIENT_ID` | Google OAuth |
| `GOOGLE_CLIENT_SECRET` | Google OAuth |
| `GITHUB_TOKEN` | GitHub catalog discovery |
| `GITHUB_ORG` | Target GitHub organisation |
| `GITHUB_REPO` | Platform repository |
| `KUBERNETES_SA_TOKEN` | Kubernetes plugin service account |
| `KUBERNETES_CA_DATA` | Kubernetes cluster CA certificate |
| `KUBERNETES_API_URL` | Kubernetes API server URL |
| `ARGOCD_USERNAME` | ArgoCD plugin credentials |
| `ARGOCD_PASSWORD` | ArgoCD plugin credentials |
