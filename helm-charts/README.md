# Custom Helm Charts

This directory contains custom Helm charts for deploying applications and infrastructure components to your EKS cluster using ArgoCD and GitOps workflows.

## Purpose
- Package and version Kubernetes applications
- Enable repeatable, declarative deployments
- Support environment-specific configuration via values files

## Structure
- Each chart is placed in its own subdirectory
- Follow Helm best practices for chart structure and versioning
- Example: `my-custom-chart/`, `nginx/`, `prometheus/`

## Usage
- Reference these charts in your ArgoCD Application manifests using the `path` field
- Update the `values.yaml` files as needed for each environment
- Example manifest:
  ```yaml
  repoURL: 'https://github.com/YOUR_ORG/Production-Ready-EKS-Cluster-with-GitOps'
  path: helm-charts/my-custom-chart
  ```

## Best Practices
- Use semantic versioning for charts
- Document all values and templates
- Keep charts DRY and modular

## Troubleshooting
- Check Helm and ArgoCD logs for deployment errors
- Validate chart syntax before committing
- See the main [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) for more help
