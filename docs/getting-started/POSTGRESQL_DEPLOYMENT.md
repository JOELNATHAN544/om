# PostgreSQL Deployment for Backstage

## Overview

This document explains the PostgreSQL deployment architecture for the OM Platform Backstage instance.

## Architecture Decision

We deploy PostgreSQL **separately** from the Backstage Helm chart for the following reasons:

### Why Separate PostgreSQL?

1. **Bitnami Image Crisis**: Starting August 2025, Bitnami moved most container images from `docker.io/bitnami/` to `docker.io/bitnamilegacy/`. The Backstage Helm chart v0.22.5 has hardcoded references to old Bitnami PostgreSQL images that no longer exist.

2. **Production Best Practice**: Backstage official documentation recommends running Backstage as a stateless application with an external PostgreSQL database.

3. **Better Control**: Separate deployment gives us:
   - Full control over PostgreSQL version
   - Independent scaling and management
   - Easier backup and recovery
   - No dependency on Helm chart bugs

4. **Modern Image**: We use the official `postgres:16-alpine` image which is:
   - Actively maintained
   - Smaller footprint
   - Well-documented
   - Production-ready

## Deployment Components

### 1. PostgreSQL StatefulSet

**File**: `platform/portal/backstage/kubernetes/postgres.yaml`

**Key Features**:
- Uses official `postgres:16-alpine` image
- StatefulSet with persistent volume (10Gi)
- Health checks (readiness and liveness probes)
- Secure password management via Kubernetes Secret
- Runs as non-root user (fsGroup: 999)

**Configuration**:
```yaml
Database: backstage
User: postgres
Password: From secret backstage-postgresql
Port: 5432
Storage: 2Gi PVC
```

### 2. PostgreSQL Service

**Service Name**: `backstage-postgresql`
**Type**: ClusterIP (internal only)
**Port**: 5432

This service provides a stable DNS name for Backstage to connect to PostgreSQL.

### 3. Secrets

Two secrets are created:

1. **backstage-postgresql**: Used by PostgreSQL StatefulSet
   - `postgres-password`: Database password
   - `password`: Alias for compatibility

2. **backstage-secrets**: Used by Backstage application
   - Contains `POSTGRES_PASSWORD` for app-config.yaml substitution
   - Plus all other application secrets

## Connection Configuration

Backstage connects to PostgreSQL using these settings in `helm/values/prod/backstage-values.yaml`:

```yaml
backend:
  database:
    client: pg
    connection:
      host: backstage-postgresql
      port: 5432
      user: postgres
      password: ${POSTGRES_PASSWORD}
      database: backstage
```

The `${POSTGRES_PASSWORD}` is substituted at runtime from the environment variable.

## Deployment Flow

The `scripts/platform-up-v2.sh` script follows this sequence:

1. **Create Namespace**: `backstage` namespace
2. **Create Secrets**: Both PostgreSQL and Backstage secrets
3. **Deploy PostgreSQL**: Apply `postgres.yaml` manifest
4. **Wait for PostgreSQL**: Ensure database is ready (up to 5 minutes)
5. **Verify Connection**: Test PostgreSQL connectivity
6. **Deploy Backstage**: Helm install with `postgresql.enabled=false`

## Verification

After deployment, verify PostgreSQL is running:

```bash
# Check PostgreSQL pod
kubectl get pods -n backstage -l app=backstage-postgresql

# Check PostgreSQL logs
kubectl logs -n backstage -l app=backstage-postgresql

# Test connection
kubectl run psql-test --rm -it --restart=Never \
  --image=postgres:16-alpine -n backstage \
  --env="PGPASSWORD=your-password" \
  --command -- psql -h backstage-postgresql -U postgres -d backstage -c "SELECT version();"
```

## Backup and Recovery

### Manual Backup

```bash
# Backup database
kubectl exec -n backstage backstage-postgresql-0 -- \
  pg_dump -U postgres backstage > backstage-backup.sql

# Restore database
kubectl exec -i -n backstage backstage-postgresql-0 -- \
  psql -U postgres backstage < backstage-backup.sql
```

### Automated Backups

For production, consider:
- Velero for Kubernetes-native backups
- PostgreSQL WAL archiving to S3
- Scheduled CronJobs for pg_dump
- Managed PostgreSQL services (RDS, Cloud SQL)

## Scaling Considerations

Current setup is single-instance for development/testing. For production:

1. **High Availability**: Use PostgreSQL replication (primary + replicas)
2. **Connection Pooling**: Add PgBouncer between Backstage and PostgreSQL
3. **Monitoring**: Add Prometheus PostgreSQL exporter
4. **Resource Limits**: Tune CPU/memory based on load
5. **Storage**: Use faster storage classes (SSD)

## Migration from Embedded PostgreSQL

If you previously used the embedded Bitnami PostgreSQL:

1. **Backup Data**: Export data from old PostgreSQL
2. **Deploy New PostgreSQL**: Run the updated script
3. **Restore Data**: Import data into new PostgreSQL
4. **Update Backstage**: Redeploy with new connection settings

## Troubleshooting

### PostgreSQL Pod Not Starting

```bash
# Check pod status
kubectl describe pod -n backstage backstage-postgresql-0

# Check logs
kubectl logs -n backstage backstage-postgresql-0

# Common issues:
# - PVC not binding: Check storage class
# - Permission denied: Check fsGroup and securityContext
# - Image pull errors: Check image name and registry access
```

### Backstage Cannot Connect

```bash
# Check Backstage logs
kubectl logs -n backstage -l app.kubernetes.io/name=backstage

# Verify secret exists
kubectl get secret backstage-secrets -n backstage -o yaml

# Test connection from Backstage pod
kubectl exec -it -n backstage deployment/backstage -- \
  psql -h backstage-postgresql -U postgres -d backstage
```

### Performance Issues

```bash
# Check PostgreSQL metrics
kubectl exec -n backstage backstage-postgresql-0 -- \
  psql -U postgres -d backstage -c "SELECT * FROM pg_stat_activity;"

# Check resource usage
kubectl top pod -n backstage backstage-postgresql-0
```

## References

- [Backstage Kubernetes Deployment Guide](https://backstage.io/docs/deployment/k8s)
- [PostgreSQL Official Docker Image](https://hub.docker.com/_/postgres)
- [Bitnami Image Migration Issue](https://github.com/bitnami/charts/issues/35164)
- [Backstage Helm Chart Issues](https://github.com/backstage/backstage/issues)

## Related Files

- `platform/portal/backstage/kubernetes/postgres.yaml` - PostgreSQL deployment manifest
- `scripts/platform-up-v2.sh` - Deployment script
- `helm/values/prod/backstage-values.yaml` - Backstage Helm values
- `configs/secrets-templates/backstage-secrets.env.example` - Configuration template
