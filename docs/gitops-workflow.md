# GitOps Workflow Guide

This guide explains the end-to-end GitOps process for managing infrastructure and applications in your EKS cluster.

## Overview
- All infrastructure and application changes are managed via Git.
- ArgoCD continuously syncs the cluster state to match the Git repository.

## Steps
1. **Create a feature branch** and make your changes.
2. **Open a Pull Request (PR)** for review.
3. **CI/CD runs tests, security, and plan checks** automatically.
4. **Merge to main** triggers deployment to the cluster.
5. **ArgoCD syncs changes** to the EKS cluster.

## Promotion
- Use environment-specific apps for staging and production.
- Promote changes by merging to the appropriate branch or updating the app-of-apps manifest.

## Best Practices
- Keep all configuration and manifests in version control.
- Use PR reviews to catch issues early.
- Document all changes and workflows.

## Troubleshooting
- Check ArgoCD and CI/CD logs for errors.
- See the main [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) for more help.
