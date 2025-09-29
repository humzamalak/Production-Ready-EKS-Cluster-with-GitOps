# Bootstrap Configuration

This directory contains the bootstrap configuration for the GitOps environment. These manifests are applied first to set up the foundational components required for the GitOps workflow.

## 🎯 Purpose

### Why the numeric prefixes?
- They enforce apply order (lower runs first).
- Gaps are avoided; contiguous numbering (00..06) reflects current implementation order.
- If you add a new step, increment at the end (e.g., 07-...).

The bootstrap directory provides:
- ArgoCD installation and configuration
- Vault Agent Injector usage notes
- Helm repository configurations
- Security policies and standards
- Vault integration components

## 📁 Components

### Core Infrastructure
- **`argo-cd-install.yaml`**: ArgoCD installation and configuration
- **`helm-repos.yaml`**: Helm repository configurations for Prometheus, Grafana, and Vault
- **`network-policy.yaml`**: Default network policies for security
- **`pod-security-standards.yaml`**: Pod Security Standards configuration

### Secrets Management
- **`external-secrets-operator.yaml`**: External Secrets Operator installation
- **`external-secrets.yaml`**: External Secrets configuration
- **`vault-secret-stores.yaml`**: HashiCorp Vault SecretStore configurations
- **`vault-policies.yaml`**: Vault policies and permissions

### Backup and Recovery
- **`etcd-backup.yaml`**: etcd backup configuration
- **`vault-setup-script.sh`**: Vault initialization script

### Configuration
- **`values.yaml`**: ArgoCD Helm values for customization

## 🚀 Usage

### 1. Apply Bootstrap Manifests (ordered by filename)

```bash
# Apply in natural order (filenames are intentionally numbered to preserve order)
kubectl apply -f bootstrap/00-namespaces.yaml      # create namespaces first
kubectl apply -f bootstrap/01-pod-security-standards.yaml
kubectl apply -f bootstrap/02-network-policy.yaml
kubectl apply -f bootstrap/03-helm-repos.yaml      # add shared Helm repos
kubectl apply -f bootstrap/04-argo-cd-install.yaml # install Argo CD
kubectl apply -f bootstrap/05-vault-policies.yaml  # baseline Vault policies
kubectl apply -f bootstrap/06-etcd-backup.yaml     # etcd backup cronjob
```

### 2. Verify Installation

```bash
# Check ArgoCD deployment
kubectl get pods -n argocd

# Check Vault (if installed via security stack)
kubectl get pods -n vault

# Check Helm repositories
kubectl get helmrepositories -A
```

### 3. Access ArgoCD

```bash
# Port forward to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## ⚙️ Configuration

### Customizing ArgoCD

Edit `helm-values/argo-cd-values.yaml` to customize ArgoCD installation:
```yaml
# Example customizations
global:
  domain: argocd.your-domain.com
  
server:
  ingress:
    enabled: true
    hosts:
      - argocd.your-domain.com
```

### Adding Helm Repositories

Add new repositories in `helm-repos.yaml` (if present) or manage via your GitOps tooling:
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: your-repo
  namespace: argocd
spec:
  url: https://your-helm-repo.com
  interval: 24h
```

## 🔒 Security Considerations

### Pod Security Standards

The bootstrap includes Pod Security Standards enforcement:

```yaml
# Restricted mode for enhanced security
pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/warn: restricted
```

### Network Policies

Default network policies are applied to:
- Restrict traffic between namespaces
- Allow only necessary communication
- Block unauthorized access

### Vault Integration

- Vault Agent Injector for pod-level secret injection (no Kubernetes Secret objects)
- Vault policies for fine-grained access control
- Annotations-based per-pod secret templates

## 🛠️ Troubleshooting

### Common Issues

1. **ArgoCD Not Starting**
   ```bash
   kubectl describe pod -l app.kubernetes.io/name=argocd-server -n argocd
   kubectl logs -l app.kubernetes.io/name=argocd-server -n argocd
   ```

2. **Vault Agent Injector Issues**
   ```bash
   kubectl get pods -n vault
   kubectl get pods -n vault -l app.kubernetes.io/name=vault-agent-injector
   kubectl get mutatingwebhookconfiguration | grep vault
   ```

3. **Helm Repositories Not Syncing**
   ```bash
   kubectl get helmrepositories -A
   kubectl describe helmrepository prometheus-community -n argocd
   ```

### Verification Commands

```bash
# Check all bootstrap components
kubectl get all -n argocd
kubectl get all -n external-secrets-system

# Check network policies
kubectl get networkpolicies -A

# Check pod security standards
kubectl get namespaces -o yaml | grep pod-security
```

## 📚 Next Steps

After applying bootstrap manifests:

1. **Deploy Applications**: Use `clusters/production/app-of-apps.yaml`
2. **Configure Vault**: Run the vault setup script if needed
3. **Set Up Monitoring**: Applications will be deployed automatically
4. **Configure Ingress**: Update ingress configurations for external access

## 🔗 Related Documentation

- [GitOps Structure](../docs/gitops-structure.md) - Repository structure guide
- [Security Best Practices](../docs/security-best-practices.md) - Security guidelines
- [Deployment Guide](../DEPLOYMENT_GUIDE.md) - Complete deployment instructions