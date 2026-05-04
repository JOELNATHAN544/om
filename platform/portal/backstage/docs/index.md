# OM Platform Portal

Welcome to the **OM Platform Portal** — the self-service developer portal for the OM Platform.

## What is this?

This portal is built on [Backstage](https://backstage.io) and provides a unified interface for:

- 🗂️ **Software Catalog** — Discover all services, APIs, libraries, and teams
- 🚀 **Self-Service Templates** — Create new applications, request services, and onboard teams
- 📊 **Kubernetes** — View live pod and deployment status for any service
- 🔄 **ArgoCD** — Monitor GitOps deployment sync status
- 📖 **TechDocs** — Read documentation for every service in one place
- 🔍 **Search** — Find anything across the entire platform

## Quick Links

| Resource | URL |
|----------|-----|
| Live Portal | https://portal.backstage.com |
| GitHub Organisation | https://github.com/your-org |

## Getting Started

1. Navigate to [https://portal.backstage.com](https://portal.backstage.com)
2. Sign in with your Google account
3. Explore the **Catalog** to see all registered services
4. Use **Create** to scaffold a new application or request a service
5. Click **Docs** on any component to read its documentation

## Key Concepts

### Components
A **Component** is any piece of software — a microservice, a website, a CLI tool, or a library. Each component has:
- An owner (team)
- A lifecycle stage (experimental, production, deprecated)
- Links to its repository, documentation, and live deployments

### Templates
**Templates** are forms that automate repetitive tasks. Available templates:
- `new-application` — Scaffold a new service with CI/CD and deployment config
- `request-service` — Request a managed database, cache, or message queue
- `team-onboarding` — Provision a new team with namespaces and permissions

### Systems
A **System** is a collection of related components that together provide a feature or product.
