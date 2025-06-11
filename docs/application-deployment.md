# Application Deployment Guide

This guide explains how to add and manage applications in your EKS cluster using ArgoCD and GitOps.

## Adding a New Application
1. **Create a new Application manifest** in `argo-cd/apps/`.
2. **Add Helm values** in `argo-cd/values/` if needed for configuration.
3. **Reference the app** in the root or environment app-of-apps manifest.
4. **Commit and push changes** to GitHub.
5. **Monitor ArgoCD** for deployment status and troubleshoot as needed.

## Best Practices
- Use descriptive names and labels for applications.
- Separate configuration for each environment (dev, staging, prod).
- Use Helm charts for complex applications.
- Keep manifests DRY and modular.

## Troubleshooting
- Check ArgoCD UI for sync status and errors.
- Review application logs in the target namespace.
- See the main [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) for more help.
