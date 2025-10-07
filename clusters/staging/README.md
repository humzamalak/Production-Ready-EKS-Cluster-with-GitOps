> **⚠️ DEPRECATION NOTICE**: This directory (`clusters/staging/`) is maintained for backward compatibility only.
>
> **Please use `environments/staging/` instead**, which contains the current staging configuration:
> - `environments/staging/app-of-apps.yaml` - Root application
> - `environments/staging/namespaces.yaml` - Namespace definitions
> - `environments/staging/project.yaml` - ArgoCD project
> - `environments/staging/apps/` - Individual applications
>
> This directory may be removed in a future version.

---

# Staging Environment Configuration (LEGACY)

This directory contains legacy staging configuration. The active configuration has moved to `environments/staging/`.

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
