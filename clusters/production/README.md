# Production Cluster Configuration

This directory contains the production cluster configuration for the GitOps environment. It defines the root application that manages all other applications in the production environment.

## 🎯 Purpose

The production cluster configuration provides:
- Root application bootstrap (app-of-apps pattern)
- Required namespace definitions
- ArgoCD project configuration
- Production-specific settings

## 📁 Components

### Core Files
- **`app-of-apps.yaml`**: Root ArgoCD Application that manages all other applications
- **`namespaces.yaml`**: Required namespaces for the production environment
- **`production-apps-project.yaml`**: ArgoCD project configuration with security policies

## 🏗️ Architecture

### App-of-Apps Pattern

The production cluster uses a hierarchical application management pattern:

```
Production Cluster (app-of-apps.yaml)
├── Monitoring Stack (applications/monitoring/)
│   ├── Prometheus
│   └── Grafana
└── Security Stack (applications/security/)
    └── Vault
```

### Namespaces

The production environment uses the following namespaces:

- **`monitoring`**: Monitoring stack (Prometheus, Grafana, AlertManager)
- **`vault`**: HashiCorp Vault secrets management
- **`argocd`**: ArgoCD components

## 🚀 Deployment

### 1. Prerequisites

Ensure the following are completed:
- ArgoCD is installed and running
- Bootstrap manifests have been applied
- Cluster has sufficient resources

### 2. Deploy Production Cluster

```bash
# Apply the root application
kubectl apply -f clusters/production/app-of-apps.yaml

# Verify deployment
kubectl get applications -n argocd
```

### 3. Monitor Deployment

```bash
# Check application sync status
kubectl get applications -n argocd -o wide

# View application details
kubectl describe application production-cluster -n argocd
```

## ⚙️ Configuration

### Customizing Applications

To modify application configurations:

1. **Edit Application Manifests**: Modify files in `applications/` directory
2. **Update Helm Values**: Edit values files for Helm-based applications
3. **Commit Changes**: Git commits trigger automatic reconciliation

### Adding New Applications

1. **Create Application Directory**: Add new app under `applications/`
2. **Define Application Manifest**: Create ArgoCD Application YAML
3. **Update App-of-Apps**: Reference new app in appropriate app-of-apps.yaml
4. **Commit and Deploy**: ArgoCD will automatically discover and deploy

### Environment-Specific Settings

For production-specific configurations:

- **Resource Limits**: Adjust in application manifests
- **Replica Counts**: Modify for production scale
- **Storage Classes**: Use production-grade storage
- **Security Policies**: Enforce strict security standards

## 🔒 Security Configuration

### ArgoCD Project

The production project enforces:

```yaml
# Source repository restrictions
sourceRepos:
  - https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps

# Namespace restrictions
destinations:
  - namespace: monitoring
  - namespace: vault
  - namespace: argocd
```

### Pod Security Standards

All namespaces enforce restricted Pod Security Standards:

```yaml
pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/warn: restricted
```

### Network Policies

Network policies are applied to:
- Isolate traffic between namespaces
- Allow only necessary communication
- Block unauthorized access

## 📊 Monitoring and Observability

### Application Health

Monitor application health through:

```bash
# Check application sync status
kubectl get applications -n argocd

# View application health
argocd app get production-cluster

# Check application logs
kubectl logs -l app.kubernetes.io/name=argocd-server -n argocd
```

### Resource Monitoring

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Dashboards and visualization
- **AlertManager**: Alert routing and notification

## 🛠️ Troubleshooting

### Common Issues

1. **Application Not Syncing**
   ```bash
   kubectl describe application production-cluster -n argocd
   kubectl get events -n argocd
   ```

2. **Namespace Creation Issues**
   ```bash
   kubectl get namespaces
   kubectl describe namespace monitoring
   ```

3. **Resource Constraints**
   ```bash
   kubectl top nodes
   kubectl top pods -n monitoring
   ```

### Debug Commands

```bash
# Check ArgoCD server logs
kubectl logs -l app.kubernetes.io/name=argocd-server -n argocd

# Check application sync status
argocd app get production-cluster

# Force sync if needed
argocd app sync production-cluster
```

## 🔄 Sync Waves

Applications are deployed in waves to ensure proper dependency ordering:

1. **Wave 1**: Root application and namespaces
2. **Wave 2**: Monitoring stack
3. **Wave 3**: Security stack

## 📚 Related Documentation

- [GitOps Structure](../../docs/gitops-structure.md) - Repository structure guide
- [Deployment Guide](../../DEPLOYMENT_GUIDE.md) - Complete deployment instructions
- [Security Best Practices](../../docs/security-best-practices.md) - Security guidelines
- [Bootstrap Configuration](../../bootstrap/README.md) - Bootstrap setup guide