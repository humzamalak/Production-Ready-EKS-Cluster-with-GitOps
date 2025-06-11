# ArgoCD Bootstrap Directory

This directory contains the manifests and configuration files required to bootstrap ArgoCD into your EKS cluster. Bootstrapping ArgoCD is the first step in enabling GitOps workflows for continuous delivery and cluster management.

## Purpose
- Install ArgoCD in the `argocd` namespace
- Apply initial configuration (admin user, RBAC, ingress, etc.)
- Set up the "app-of-apps" pattern for managing all cluster applications declaratively

## Structure
- `argo-cd-install.yaml`: Main ArgoCD installation manifest (Helm or Kustomize)
- `values.yaml`: Custom values for production-grade ArgoCD deployment
- Additional manifests for RBAC, ingress, and secrets as needed

## Usage
1. **Apply the ArgoCD installation manifest:**
   ```bash
   kubectl apply -f argo-cd-install.yaml
   # Or use Helm:
   helm upgrade --install argocd argo/argo-cd -n argocd -f values.yaml
   ```
2. **Access the ArgoCD UI:**
   - Forward the ArgoCD server port or use the configured ingress
   - Login with the initial admin password (see ArgoCD docs or secret)
3. **Bootstrap applications:**
   - Apply the root app manifest to enable the app-of-apps pattern

## Best Practices
- Use OIDC for SSO integration
- Restrict admin access and configure RBAC
- Enable resource limits and high availability
- Store secrets securely (do not commit them to Git)

## Troubleshooting
- Check pod logs in the `argocd` namespace for errors
- Ensure all CRDs are installed before applying custom resources
- See the main [TROUBLESHOOTING.md](../../TROUBLESHOOTING.md) for more help

---

For more details, see the [ArgoCD Configuration Guide](../../docs/argocd-configuration.md).
