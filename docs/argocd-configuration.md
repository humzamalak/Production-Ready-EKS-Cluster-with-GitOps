# ArgoCD Configuration Guide

This guide covers installation, configuration, RBAC, and the app-of-apps pattern for ArgoCD in your EKS GitOps environment.

## Overview
ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It enables automated deployment and management of applications using Git as the source of truth.

## Installation
> Note: This repository is CI/CD-agnostic. You can apply these manifests manually or integrate via your preferred pipeline.
1. Apply manifests in `argo-cd/bootstrap/`:
   ```bash
   kubectl apply -f argo-cd/bootstrap/argo-cd-install.yaml
   # Or use Helm:
   helm upgrade --install argocd argo/argo-cd -n argocd -f argo-cd/bootstrap/values.yaml
   ```
2. Access the ArgoCD UI and log in with the admin credentials (see secret or docs). For production, rotate the admin password immediately and enable SSO/OIDC.

## RBAC & Security
- Configure RBAC and admin user settings in `values.yaml`.
- Integrate with OIDC for SSO and secure authentication.
- Restrict admin access and use least-privilege roles.
- Store secrets outside Git (e.g., AWS Secrets Manager + external-secrets). Apply only references in Git.

## App of Apps Pattern
- Use `apps/root-app.yaml` to manage all applications declaratively.
- Add environment-specific apps in `apps/environments/` for staging, production, etc.

## Troubleshooting
- Check ArgoCD pod logs:
  ```bash
  kubectl logs -n argocd <pod>
  ```
- See [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) for common issues.

---

For more details, see the [Application Deployment Guide](application-deployment.md).
