# Getting Started

## Prerequisites

Before you can access the portal, ensure the following:

- A Google account that belongs to the organisation
- Your machine has the following entry in `/etc/hosts`:
  ```
  127.0.0.1 portal.backstage.com
  ```

## Accessing the Portal

1. Open a browser and navigate to **https://portal.backstage.com**
2. Accept the self-signed certificate warning (click **Advanced → Proceed**)
3. Click **SIGN IN** on the Google card
4. Authenticate with your Google account

> Your identity is automatically resolved from your Google email. No manual setup required.

## Exploring the Catalog

The **Catalog** is the heart of the portal. To explore it:

1. Click **Catalog** in the left sidebar
2. Filter by **Kind** (Component, API, Group, User, Template)
3. Click any component to view its details, documentation, and live status

## Creating Resources

Click **Create** in the left sidebar to use a Scaffolder template:

| Template | Purpose |
|----------|---------|
| New Application | Scaffold a new microservice with full CI/CD setup |
| Request Platform Service | Provision a managed PostgreSQL, Redis, or RabbitMQ |
| Onboard New Team | Create team namespaces, RBAC, and catalog group |

## Viewing Documentation

Every component registered in the catalog can have documentation. Click the **Docs** tab on any component page to read its TechDocs.
