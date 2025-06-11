# Troubleshooting Guide

## Common Issues
- **Terraform init/apply fails:** Check AWS credentials and backend config.
- **ArgoCD pods not running:** Check pod logs and resource limits.
- **Application not syncing:** Check ArgoCD UI and app status.
- **Monitoring/alerts not firing:** Check Prometheus and AlertManager logs.

## Useful Commands
- `kubectl get pods -A`
- `kubectl logs -n <namespace> <pod>`
- `terraform plan`
- `terraform apply`
