# ArgoCD Values Directory

This directory contains custom `values.yaml` files for configuring ArgoCD and application Helm charts in different environments.

## Purpose
- Store environment-specific and shared Helm values
- Enable DRY, modular configuration for ArgoCD and applications
- Support production-grade, secure, and scalable deployments

## Structure
- `argocd-values.yaml`: Main values file for ArgoCD installation
- `nginx-values.yaml`, `prometheus-values.yaml`, etc.: Application-specific values
- `README.md`: This documentation file

## Usage
1. **Edit the appropriate `values.yaml` file** for your environment or application
2. **Reference the values file** in your ArgoCD Application manifest or Helm command
   ```bash
   helm upgrade --install my-app ./my-chart -f values/nginx-values.yaml
   ```
3. **Commit and push changes** to version control

## Best Practices
- Use separate values files for each environment (dev, staging, prod)
- Document all custom values and overrides
- Avoid storing secrets in plain text; use external-secrets or sealed-secrets

## Troubleshooting
- Check ArgoCD and Helm logs for values parsing errors
- Validate YAML syntax before committing
- See the main [TROUBLESHOOTING.md](../../TROUBLESHOOTING.md) for more help
