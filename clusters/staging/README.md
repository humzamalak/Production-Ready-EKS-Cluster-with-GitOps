<!-- Docs Update: 2025-10-05 — Point to environments/staging paths and correct apply commands. -->
# Staging Environment Configuration

This directory contains the GitOps configuration for the staging environment.

## Structure

- `environments/staging/app-of-apps.yaml` - Root Argo CD Application (lives under `environments/`)
- `environments/staging/namespaces.yaml` - Namespace definitions (lives under `environments/`)
- `environments/staging/project.yaml` - Argo CD Project configuration (lives under `environments/`)

## Deployment

To deploy the staging environment (from repo root):

1. Apply the Argo CD project:
   ```bash
   kubectl apply -f environments/staging/project.yaml
   ```

2. Apply the root application:
   ```bash
   kubectl apply -f environments/staging/app-of-apps.yaml
   ```

3. Apply namespace definitions:
   ```bash
   kubectl apply -f environments/staging/namespaces.yaml
   ```

## Applications

The staging environment includes:

- **Monitoring Stack**: Prometheus and Grafana with staging-specific configurations
- **Web Applications**: Staging versions of production applications
- **Infrastructure Components**: Reduced resource requirements for cost optimization

## Differences from Production

- Reduced resource limits and requests
- Staging-specific domains and certificates
- More verbose logging for debugging
- Relaxed pod disruption budgets
- Separate monitoring namespace as defined in `environments/staging/namespaces.yaml`
