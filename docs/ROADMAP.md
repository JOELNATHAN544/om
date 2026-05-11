# OM Platform Roadmap

## Overview

This document outlines the implementation roadmap for the OM (Operation and Maintenance) Platform.

## Timeline Overview

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                              OM Platform Roadmap                                         │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  Phase 1       Phase 2       Phase 3       Phase 4       Phase 5       Phase 6           │
│  ┌───────┐     ┌───────┐     ┌───────┐     ┌───────┐     ┌───────┐     ┌───────┐         │
│  │ Core  │────▶│Platform────▶│ Team  │────▶│Security────▶│ Prod  │────▶│Portal │         │
│  │ Infra │     │ Comps │     │Onboard│     │Harden │     │ Ready │     │& Svc  │         │
│  └───────┘     └───────┘     └───────┘     └───────┘     └───────┘     └───────┘         │
│  Sprint 1-2    Sprint 3-4    Sprint 5-6    Sprint 7-8    Sprint 9-10   Sprint 11-14      │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

## Phase 1: Core Infrastructure Setup (Sprint 1-2)

**Goal**: Establish foundational cloud infrastructure

### Deliverables

| Item | Description | Status |
|------|-------------|--------|
| VPC & Networking | AWS VPC with public/private subnets | Planned |
| EKS Cluster | Managed Kubernetes cluster | Planned |
| IAM Roles | Cluster and node IAM configuration | Planned |
| State Backend | S3 + DynamoDB for Terraform state | Planned |

### GitHub Issues
- [#6 - Phase 1: Core Infrastructure Setup](https://github.com/skyengpro/om/issues/6)
- [#11 - Deploy VPC and networking](https://github.com/skyengpro/om/issues/11)
- [#12 - Deploy EKS cluster](https://github.com/skyengpro/om/issues/12)

### Success Criteria
- [x] Proxmox cluster is running and accessible (Version 9.1.1)
- [x] Talos k8s cluster is running and accessible (Version 1.33.x)
- [x] OpenStack cluster is running and accessible (Version 2025.2.x)
- [ ] 80% -> Netbird cluster is running and accessible (Version Management-0.67.1, Dashboard-2.36.0)
- [x] ArgoCD, Grafana, Prometheus, Alertmanager, Loki, Alloy, tempo, mimir, pyroscope, metalLB, Nginx ingress Controller, IAM Operator are deploy and running 
- [x] All infrastructure is defined with IaC (Ansible, Terraform) 
- [ ] 70% -> CI/CD can deploy infrastructure changes
- [ ] 80% -> Proxmox VM template for MacOS, Windows and Linux

---

## Phase 2: Platform Components (Sprint 3-4)

**Goal**: Deploy core platform services

### Deliverables

| Item | Description | Status |
|------|-------------|--------|
| OpenStack Core | VM, Network, and Subcription Management | Planned |
| OpenStack Services | K8s, Container Services and Plugins | Planned |
| TLS Provisioning | Automated Certificate Management | Planned |
| ArgoCD | GitOps continuous delivery | Planned |
| Monitoring Stack | Prometheus, Grafana, Alertmanager | Planned |
| cert-manager | Automated TLS certificates | Planned |
| Ingress NGINX | External traffic routing | Planned |
| Netbird | Agent Installation script readiness | planned |

### GitHub Issues
- [#7 - Phase 2: Platform Components](https://github.com/skyengpro/om/issues/7)
- [#13 - Deploy ArgoCD](https://github.com/skyengpro/om/issues/13)
- [#14 - Deploy monitoring stack](https://github.com/skyengpro/om/issues/14)

### Success Criteria
- [ ] Proxmox operation and maintenance handover to Usher and Onel
- [ ] proxmox VM templates with ansible
- [ ] Openstack full functional (Subscription, Create resource like VM, Networks, Manager K8s Service, Container Services, Plugins(vault-plugin-secrets-openstack, self-registration-plugins))
- [ ] Backstage is running and accessible
- [ ] ArgoCD is managing all applications
- [ ] Custom Monitoring dashboards are accessible
- [ ] TLS certificates are automatically provisioned and renew
- [ ] External traffic reaches applications
- [ ] Netbird agent install script is ready
- [ ] Deployment of IVISS platform
- [ ] Deployment of Azamra

---

## Phase 3: Team Onboarding Framework (Sprint 5-6)

**Goal**: Enable self-service deployments for teams

### Deliverables

| Item | Description | Status |
|------|-------------|--------|
| Base App Chart | Standardized Helm chart | Complete |
| ApplicationSets | Automatic app generation | Complete |
| Team RBAC | Role-based access control | Complete |
| Documentation | Onboarding guides | Complete |

### GitHub Issues
- [#8 - Phase 3: Team Onboarding Framework](https://github.com/skyengpro/om/issues/8)
- [#15 - Create team onboarding process](https://github.com/skyengpro/om/issues/15)

### Success Criteria
- [ ] Teams can deploy via Git pull request
- [ ] Teams have isolated namespaces
- [ ] Self-service documentation is complete
- [ ] First team successfully onboarded

---

## Phase 4: Security Hardening (Sprint 7-8)

**Goal**: Implement comprehensive security controls

### Deliverables

| Item | Description | Status |
|------|-------------|--------|
| OPA Gatekeeper | Policy enforcement | Planned |
| Network Policies | Zero-trust networking | Complete |
| Wazuh SIEM | Security monitoring | Planned |
| Secrets Management | External Secrets Operator | Planned |

### GitHub Issues
- [#9 - Phase 4: Security Hardening](https://github.com/skyengpro/om/issues/9)
- [#16 - Implement OPA security policies](https://github.com/skyengpro/om/issues/16)

### Success Criteria
- [ ] All pods comply with security policies
- [ ] Network policies enforce least-privilege
- [ ] Security events are logged and alerted
- [ ] Secrets are managed externally

---

## Phase 5: Production Readiness (Sprint 9-10)

**Goal**: Prepare for production workloads

### Deliverables

| Item | Description | Status |
|------|-------------|--------|
| Disaster Recovery | Backup and restore procedures | Planned |
| Multi-Environment | Staging to prod pipeline | Planned |
| SLO Dashboards | Service level monitoring | Planned |
| Runbooks | Operational procedures | Complete |

### GitHub Issues
- [#10 - Phase 5: Production Readiness](https://github.com/skyengpro/om/issues/10)

### Success Criteria
- [ ] DR procedures tested
- [ ] Production environment deployed
- [ ] SLO compliance visible
- [ ] All runbooks complete

---

## Phase 6: Self-Service Portal & Service Catalog (Sprint 11-14)

**Goal**: Deploy comprehensive self-service platform for teams

### Deliverables

| Item | Description | Status |
|------|-------------|--------|
| Tenant CRD | Custom resource for team management | Complete |
| Resource Quotas | Tiered resource limits per team | Complete |
| Service Catalog | Managed services (PostgreSQL, Redis, etc.) | Complete |
| Backstage Portal | Self-service developer portal | Designed |

### GitHub Issues
- [#17 - Phase 6: Self-Service Portal](https://github.com/skyengpro/om/issues/17)
- [#18 - Implement Tenant CRD and Controller](https://github.com/skyengpro/om/issues/18)
- [#19 - Deploy Service Catalog with Operators](https://github.com/skyengpro/om/issues/19)
- [#20 - Deploy Backstage Developer Portal](https://github.com/skyengpro/om/issues/20)

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Self-Service Platform                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Backstage Portal                                               │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  Software   │  Templates  │  Service   │  Kubernetes   │   │
│   │  Catalog    │  (Scaffold) │  Catalog   │  Dashboard    │   │
│   └─────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│   Platform APIs                                                  │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│   │   Tenant    │  │   Service   │  │   ArgoCD    │            │
│   │  Controller │  │   Catalog   │  │    API      │            │
│   └─────────────┘  └─────────────┘  └─────────────┘            │
│                              │                                   │
│                              ▼                                   │
│   Kubernetes Resources                                           │
│   ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐              │
│   │Tenant  │  │Service │  │Quota   │  │Network │              │
│   │  CR    │  │Request │  │        │  │Policy  │              │
│   └────────┘  └────────┘  └────────┘  └────────┘              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Success Criteria
- [ ] Teams can self-onboard via portal
- [ ] Time to deploy first app < 30 minutes
- [ ] Service requests provision automatically
- [ ] Resource quotas enforce limits
- [ ] > 90% self-service rate

---

## Future Enhancements (Backlog)

### Multi-Cloud Support
- GCP GKE integration
- Azure AKS integration
- Multi-cluster management

### Service Mesh
- Istio or Linkerd integration
- mTLS between services
- Traffic management

### Advanced Observability
- Distributed tracing (Jaeger/Tempo)
- Log aggregation (Loki)
- Cost monitoring

### Developer Experience
- Local development environment
- Preview environments
- IDE integrations

---

## Project Links

- **Repository**: https://github.com/skyengpro/om
- **Issues**: https://github.com/skyengpro/om/issues
- **Projects**: https://github.com/skyengpro/om/projects

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for how to contribute to this project.
