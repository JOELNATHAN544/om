# OM - Organization Management Platform

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/Terraform-1.6+-purple.svg)](https://terraform.io)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-blue.svg)](https://kubernetes.io)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-2.9+-orange.svg)](https://argoproj.github.io/cd/)
[![Backstage](https://img.shields.io/badge/Backstage-1.20+-9CF.svg)](https://backstage.io)

> **A central SRE platform enabling teams to self-service deploy applications following organizational policies and best practices.**

## Overview

OM (Operation and Maintenance) is a **central SRE Engineering platform** that enables development teams to:

- **Self-onboard** to the platform via a developer portal
- **Deploy applications** using standardized templates
- **Request managed services** (databases, caches, queues)
- **Follow organizational policies** automatically enforced

## 🚀 Getting Started

### Prerequisites
- **Docker**: [Install Docker](https://docs.docker.com/get-docker/)
- **K3d**: `curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.6.0 bash`
- **Kubectl & Helm**: Standard CLI tools

### One-Command Bootstrap
To stand up the entire platform (K8s, ArgoCD, Backstage, Monitoring) on **macOS** or **Linux**:

```bash
./scripts/platform-up-v2.sh
```

To build and push the Backstage image as part of the bootstrap (slower):

```bash
./scripts/platform-up-v2.sh --build-backstage-image
```

Run this on the **first deployment** (to ensure the image exists in the local registry), and again whenever you need to **rebuild + push** the Backstage image after changing Backstage code/Dockerfile. For faster runs when the image already exists, use `./scripts/platform-up-v2.sh` without the flag.

If you use the default local domains (`portal.backstage.com`, `argocd.backstage.com`), refresh your `/etc/hosts` mapping after reboot/network changes:

```bash
sudo ./scripts/update-backstage-hosts.sh --apply
```

### Teardown
To delete the cluster and all resources:

```bash
./scripts/platform-down.sh
```

### Key Features

| Feature | Description |
|---------|-------------|
| **Self-Service Portal** | Backstage-based developer portal for team onboarding and app deployment |
| **Workflow Automation** | n8n-powered approval workflows, onboarding automation, and alert handling |
| **Multi-Tenant Platform** | Isolated namespaces, quotas, and RBAC per team |
| **Service Catalog** | Pre-approved managed services (PostgreSQL, Redis, RabbitMQ) |
| **GitOps Deployments** | ArgoCD-based continuous delivery from Git |
| **Policy Enforcement** | OPA Gatekeeper policies for security and compliance |
| **Comprehensive Monitoring** | Prometheus, Grafana, and Alertmanager stack |
| **Infrastructure as Code** | Terraform modules for AWS EKS |

## Architecture

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                           OM Central SRE Platform                                  │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │                      Self-Service Portal (Backstage)                          │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │ │
│  │  │   Onboard   │  │   Create    │  │   Request   │  │    View     │           │ │
│  │  │    Team     │  │    App      │  │   Service   │  │   Status    │           │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘           │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                         │                                          │
│                                         ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │                    Workflow Automation (n8n)                                  │ │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐   │ │
│  │  │   Approval    │  │  Onboarding   │  │   Alerting    │  │  Reporting    │   │ │
│  │  │   Workflows   │  │   Automation  │  │   Handlers    │  │  Schedules    │   │ │
│  │  └───────────────┘  └───────────────┘  └───────────────┘  └───────────────┘   │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                         │                                          │
│                                         ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │                         Platform Controllers                                  │ │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐   │ │
│  │  │    Tenant     │  │    Service    │  │    ArgoCD     │  │   GitHub      │   │ │
│  │  │  Controller   │  │    Catalog    │  │   (GitOps)    │  │   Actions     │   │ │
│  │  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘   │ │
│  │          │                  │                  │                  │           │ │
│  │          ▼                  ▼                  ▼                  ▼           │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │ │
│  │  │ Namespaces  │    │ PostgreSQL  │    │  Helm Apps  │    │  Terraform  │     │ │
│  │  │ Quotas/RBAC │    │ Redis/RMQ   │    │   Sync      │    │   CI/CD     │     │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘     │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                         │                                          │
│                                         ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │                          Kubernetes Cluster (EKS)                             │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │ │
│  │  │                         Team Namespaces                                 │  │ │
│  │  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐             │  │ │
│  │  │  │ team-a    │  │ team-b    │  │ team-c    │  │ team-n    │             │  │ │
│  │  │  │ (dev/stg/ │  │ (dev/stg/ │  │ (dev/stg/ │  │ (dev/stg/ │             │  │ │
│  │  │  │  prod)    │  │  prod)    │  │  prod)    │  │  prod)    │             │  │ │
│  │  │  └───────────┘  └───────────┘  └───────────┘  └───────────┘             │  │ │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                         │                                          │
│                                         ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │                      Policy & Security Layer                                  │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌───────┐   │ │
│  │  │   OPA   │  │ Network │  │  Cert   │  │ Wazuh   │  │ NetBird │  │AdGuard│   │ │
│  │  │Gatekeeper│ │ Policy  │  │ Manager │  │  SIEM   │  │   VPN   │  │  DNS  │   │ │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └───────┘   │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                         │                                          │
│                                         ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │                         Observability Stack                                   │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                │ │
│  │  │   Prometheus    │  │     Grafana     │  │   Alertmanager  │                │ │
│  │  │   (Metrics)     │  │   (Dashboards)  │  │   (Alerting)    │                │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘                │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
```

### Event-Driven Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Platform Event Flow                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Event Sources              n8n Workflows                 Actions          │
│   ┌─────────────┐         ┌─────────────────┐         ┌─────────────┐       │
│   │ Kubernetes  │────────▶│  Onboarding     │────────▶│  Namespaces │       │
│   │ (Tenants)   │         │  Automation     │         │  RBAC/Quotas│       │
│   └─────────────┘         └─────────────────┘         └─────────────┘       │
│   ┌─────────────┐         ┌─────────────────┐         ┌─────────────┐       │
│   │   ArgoCD    │────────▶│  Prod Approval  │────────▶│  Slack/     │       │
│   │ (Deploys)   │         │  Workflow       │         │  PagerDuty  │       │
│   └─────────────┘         └─────────────────┘         └─────────────┘       │
│   ┌─────────────┐         ┌─────────────────┐         ┌─────────────┐       │
│   │ Prometheus  │────────▶│  Alert Handler  │────────▶│  Escalation │       │
│   │ (Alerts)    │         │                 │         │  Jira/Email │       │
│   └─────────────┘         └─────────────────┘         └─────────────┘       │
│   ┌─────────────┐         ┌─────────────────┐         ┌─────────────┐       │
│   │  Scheduled  │────────▶│  Cost Reports   │────────▶│  Finance    │       │
│   │  (Cron)     │         │  Compliance     │         │  Security   │       │
│   └─────────────┘         └─────────────────┘         └─────────────┘       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## How Teams Use the Platform

### 1. Team Onboarding

Teams subscribe to the platform by creating a `Tenant` resource:

```yaml
apiVersion: platform.om.io/v1alpha1
kind: Tenant
metadata:
  name: backend
spec:
  name: backend
  displayName: "Backend Engineering"
  owner: backend-lead@example.com
  tier: standard              # starter | standard | enterprise
  environments: [dev, staging, prod]
  costCenter: "ENG-001"
```

This automatically provisions:
- Namespaces per environment (`backend-dev`, `backend-staging`, `backend-prod`)
- Resource quotas based on tier
- RBAC roles for team members
- ArgoCD project for deployments
- Network policies for isolation

### 2. Deploy Applications

Teams deploy using the standardized `base-app` Helm chart:

```yaml
# apps/backend/api-service/values.yaml
name: api-service
team: backend

image:
  repository: docker.io/myorg/api
  tag: "1.0.0"

replicas: 3
resources:
  requests:
    cpu: 100m
    memory: 128Mi
```

### 3. Request Services

Teams request managed services via the Service Catalog:

```yaml
apiVersion: platform.om.io/v1alpha1
kind: ServiceRequest
metadata:
  name: api-database
  namespace: backend-dev
spec:
  service: postgresql
  size: medium
```

## Resource Quota Tiers

| Tier | CPU | Memory | Storage | Pods | Use Case |
|------|-----|--------|---------|------|----------|
| **Starter** | 4 | 8Gi | 50Gi | 20 | Small teams, dev only |
| **Standard** | 16 | 32Gi | 200Gi | 100 | Most production teams |
| **Enterprise** | 64 | 128Gi | 1Ti | 500 | Large/critical workloads |

## Quick Start

### Prerequisites

- [Terraform](https://terraform.io) >= 1.6
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.28
- [Helm](https://helm.sh) >= 3.12
- [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
- [AWS CLI](https://aws.amazon.com/cli/) configured

### Installation

```bash
# Clone the repository
git clone https://github.com/skyengpro/om.git
cd om

# Deploy infrastructure
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
terraform init && terraform apply

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name om-platform-dev

# Bootstrap ArgoCD
kubectl apply -k argocd/bootstrap/

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Get password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## Project Structure

```
om/
├── terraform/                    # Infrastructure as Code
│   ├── modules/
│   │   ├── kubernetes/           # EKS cluster
│   │   └── networking/           # VPC, subnets
│   └── environments/
│       ├── dev/
│       ├── staging/
│       └── prod/
│
├── platform/                     # Central Platform Components
│   ├── tenants/                  # Tenant CRD & controller
│   ├── quotas/                   # Resource quota tiers
│   ├── service-catalog/          # Managed services
│   │   └── offerings/            # PostgreSQL, Redis, RabbitMQ
│   ├── portal/                   # Backstage configuration
│   │   └── backstage/            # Templates & config
│   ├── n8n/                      # Workflow Automation
│   │   └── workflows/            # Approval, onboarding, alerting
│   └── events/                   # Event-Driven Architecture
│       ├── handlers/             # Event handlers
│       └── triggers/             # Webhooks & schedules
│
├── helm/                         # Helm Charts
│   └── charts/
│       └── base-app/             # Standard app deployment
│
├── argocd/                       # GitOps Configuration
│   ├── bootstrap/                # Initial setup
│   ├── apps/                     # Application definitions
│   └── applicationsets/          # Auto-generate team apps
│
├── monitoring/                   # Observability
│   ├── prometheus/               # Rules & alerts
│   └── grafana/                  # Dashboards
│
├── security/                     # Security
│   ├── opa-policies/             # Gatekeeper policies
│   ├── network-policies/         # Zero-trust networking
│   ├── rbac/                     # Platform roles
│   └── cert-manager/             # TLS automation
│
├── .github/                      # CI/CD
│   ├── workflows/                # GitHub Actions
│   └── ISSUE_TEMPLATE/           # Team onboarding template
│
└── docs/                         # Documentation
    ├── getting-started/          # Team onboarding guide
    ├── architecture/             # System design
    ├── customization/            # Configuration guide
    └── runbooks/                 # Operations
```

## Technology Stack

| Layer | Technologies |
|-------|-------------|
| **Self-Service Portal** | Backstage (CNCF) |
| **Workflow Automation** | n8n (approvals, onboarding, alerts) |
| **Infrastructure** | Terraform, AWS EKS |
| **GitOps** | ArgoCD, ApplicationSets |
| **Deployments** | Helm, Kustomize |
| **Service Catalog** | CloudNativePG, Redis Operator, RabbitMQ Operator |
| **Monitoring** | Prometheus, Grafana, Alertmanager |
| **Security** | OPA Gatekeeper, Wazuh, cert-manager |
| **Networking** | NetBird VPN, AdGuard DNS, Network Policies |
| **CI/CD** | GitHub Actions |

## Documentation

| Document | Description |
|----------|-------------|
| [Getting Started](docs/getting-started/README.md) | Team onboarding guide |
| [Architecture](docs/architecture/README.md) | System design |
| [Customization](docs/customization/README.md) | Configuration options |
| [Runbooks](docs/runbooks/README.md) | Operational procedures |
| [Roadmap](docs/ROADMAP.md) | Implementation phases |
| [Portal Architecture](platform/portal/ARCHITECTURE.md) | Backstage design |
| [Workflow Automation](platform/n8n/README.md) | n8n workflows |
| [Event System](platform/events/README.md) | Event-driven architecture |

### Tutorials

| Tutorial | Description |
|----------|-------------|
| [AdGuard + NetBird](docs/tutorial/deploying_and_integrating_adguard_with_netbird.md) | VPN with DNS filtering |

## Roadmap

| Phase | Focus | Status |
|-------|-------|--------|
| Phase 1 | Core Infrastructure (EKS, VPC) | Planned |
| Phase 2 | Platform Components (ArgoCD, Monitoring) | Planned |
| Phase 3 | Team Onboarding Framework | Ready |
| Phase 4 | Security Hardening | Ready |
| Phase 5 | Production Readiness | Planned |
| Phase 6 | Self-Service Portal (Backstage) | Designed |

See [full roadmap](docs/ROADMAP.md) for details.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Support

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/skyengpro/om/issues)
- **Discussions**: [GitHub Discussions](https://github.com/skyengpro/om/discussions)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built for Platform Engineering Teams**
