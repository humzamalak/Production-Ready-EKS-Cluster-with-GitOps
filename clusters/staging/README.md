# Staging Environment Configuration

This directory contains the GitOps configuration for the staging environment.

## Structure

- `app-of-apps.yaml` - Root ArgoCD Application that manages all staging applications
- `namespaces.yaml` - Namespace definitions for staging workloads
- `staging-apps-project.yaml` - ArgoCD Project configuration for staging applications

## Deployment

To deploy the staging environment:

1. Apply the ArgoCD project:
   ```bash
   kubectl apply -f clusters/staging/staging-apps-project.yaml
   ```

2. Apply the root application:
   ```bash
   kubectl apply -f clusters/staging/app-of-apps.yaml
   ```

3. Apply namespace definitions:
   ```bash
   kubectl apply -f clusters/staging/namespaces.yaml
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
- Separate monitoring namespace (`staging-monitoring`)
