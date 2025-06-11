# ArgoCD Applications Directory

This directory contains ArgoCD Application manifests for deploying workloads to your EKS cluster using GitOps principles.

## Purpose
- Define and manage all Kubernetes applications declaratively
- Enable the "app-of-apps" pattern for scalable, modular application management
- Support environment-specific and shared applications

## Structure
- `root-app.yaml`: The root ArgoCD Application that manages all other apps (app-of-apps)
- `environments/`: Subdirectory for environment-specific applications (e.g., staging, production)
- `nginx-app.yaml`, `prometheus-stack.yaml`, etc.: Example application manifests

## Usage
1. **Add a new application:**
   - Create a new YAML manifest in this directory or a subdirectory
   - Reference the application in the root app or environment app-of-apps
2. **Sync with ArgoCD:**
   - Commit and push changes to Git
   - ArgoCD will automatically detect and deploy the new/updated application

## Best Practices
- Use descriptive names for applications
- Separate environment-specific configuration
- Use Helm charts for complex applications
- Keep manifests DRY and modular

## Troubleshooting
- Check ArgoCD UI for sync status and errors
- Review application logs in the target namespace
- See the main [TROUBLESHOOTING.md](../../TROUBLESHOOTING.md) for more help

---

For more details, see the [Application Deployment Guide](../../docs/application-deployment.md).
