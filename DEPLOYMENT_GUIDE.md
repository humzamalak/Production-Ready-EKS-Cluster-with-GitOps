# GitOps Deployment Guide

This guide provides comprehensive instructions for deploying the GitOps repository with Prometheus, Grafana, and Vault using Argo CD.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Detailed Configuration](#detailed-configuration)
4. [Platform-Specific Guides](#platform-specific-guides)
5. [Post-Deployment Setup](#post-deployment-setup)
6. [Troubleshooting](#troubleshooting)
7. [Security Considerations](#security-considerations)

## Prerequisites

### Required Tools

- **kubectl** (v1.28+) - Kubernetes CLI
- **Helm** (v3.x) - Package manager
- **Git** - Version control
- **Argo CD CLI** (optional) - For advanced operations

### Kubernetes Cluster Requirements

- **Kubernetes version**: 1.25+ (recommended: 1.28+)
- **CPU**: Minimum 4 cores across all nodes
- **Memory**: Minimum 8GB RAM across all nodes
- **Storage**: Persistent volume support (recommended: 50GB+)
- **Ingress Controller**: nginx, traefik, or similar
- **Cert-Manager**: For automatic SSL certificate management

### Argo CD Installation

Argo CD must be installed in your cluster before deploying these applications:

```bash
# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Quick Start

### 1. Clone and Configure

```bash
# Clone the repository
git clone https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps.git
cd Production-Ready-EKS-Cluster-with-GitOps

# Update configuration for your environment
# 1. Update repoURL in clusters/production/app-of-apps.yaml
# 2. Update domain names in application manifests
# 3. Update AWS Account ID in Vault configuration
```

### 2. Bootstrap ArgoCD

```bash
# Apply bootstrap manifests
kubectl apply -f bootstrap/

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### 3. Deploy Applications

```bash
# Deploy the root application (app-of-apps pattern)
kubectl apply -f clusters/production/app-of-apps.yaml

# Verify deployment
kubectl get applications -n argocd
```

### 4. Access Applications

```bash
# Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access: https://localhost:8080

# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus -n monitoring 9090:9090
# Access: http://localhost:9090

# Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80
# Access: http://localhost:3000 (admin/changeme)

# Vault
kubectl port-forward svc/vault -n vault 8200:8200
# Access: https://localhost:8200
```

## Detailed Configuration

### Environment Variables

Before deploying, update these configuration values:

#### 1. Domain Configuration

Replace `your-domain.com` with your actual domain:

```bash
# Update all domain references
sed -i 's/your-domain\.com/your-actual-domain.com/g' \
  apps/grafana/application.yaml \
  apps/vault/values.yaml \
  apps/prometheus/application.yaml
```

#### 2. AWS Account ID

For AWS deployments, update the account ID:

```bash
# Replace ACCOUNT_ID with your AWS account ID
sed -i 's/ACCOUNT_ID/123456789012/g' apps/vault/values.yaml
```

#### 3. Repository URL

If you've forked the repository, update the URL:

```bash
# Update repository URL
sed -i 's|https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps|https://github.com/your-org/your-repo|g' app-of-apps.yaml
```

### Customization Options

#### Grafana Configuration

Update `apps/grafana/application.yaml`:

```yaml
# Change admin password
adminPassword: "your-secure-password"

# Enable external secrets integration
admin:
  existingSecret: grafana-admin
  userKey: admin-user
  passwordKey: admin-password
```

#### Prometheus Configuration

Update `apps/prometheus/application.yaml`:

```yaml
# Adjust retention settings
retention: 30d
retentionSize: 50GB

# Configure alerting
alertmanager:
  config:
    global:
      smtp_smarthost: 'your-smtp-server:587'
      smtp_from: 'alerts@your-domain.com'
```

#### Vault Configuration

Update `apps/vault/values.yaml`:

```yaml
# Configure backup settings
server:
  extraArgs: |
    -config=/vault/config/extraconfig-from-values.hcl

# Enable additional audit devices
audit:
  enabled: true
  type: file
  path: /vault/audit/audit.log
```

## Platform-Specific Guides

### AWS EKS

For complete AWS EKS deployment, see [AWS_DEPLOYMENT_GUIDE.md](AWS_DEPLOYMENT_GUIDE.md).

Key considerations:
- IAM roles for service accounts (IRSA)
- EBS CSI driver for persistent volumes
- Load balancer controller for ingress
- CloudWatch integration

### Minikube

For local development, see [MINIKUBE_DEPLOYMENT_GUIDE.md](MINIKUBE_DEPLOYMENT_GUIDE.md).

Key considerations:
- Local storage classes
- Port forwarding for access
- Resource limitations
- Development workflows

### Other Kubernetes Platforms

#### Google GKE

```bash
# Enable required APIs
gcloud services enable container.googleapis.com

# Create cluster with workload identity
gcloud container clusters create my-cluster \
  --enable-workload-identity \
  --num-nodes=3 \
  --machine-type=e2-standard-2

# Configure kubectl
gcloud container clusters get-credentials my-cluster
```

#### Azure AKS

```bash
# Create resource group
az group create --name myResourceGroup --location eastus

# Create AKS cluster
az aks create \
  --resource-group myResourceGroup \
  --name myAKSCluster \
  --node-count 3 \
  --enable-addons monitoring \
  --generate-ssh-keys

# Configure kubectl
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

## Post-Deployment Setup

### 1. Initialize Vault

After Vault is deployed, initialize and unseal it:

```bash
# Initialize Vault (run once)
kubectl exec -n vault vault-0 -- vault operator init

# Save the unseal keys and root token securely!

# Unseal Vault with 3 unseal keys
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-1>
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-2>
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key-3>

# Verify Vault is unsealed
kubectl exec -n vault vault-0 -- vault status
```

### 2. Configure Grafana

Access Grafana and configure:

1. **Change admin password** (if not using external secrets)
2. **Verify datasources** are connected
3. **Import additional dashboards** if needed
4. **Configure users and teams** for access control

### 3. Set Up Monitoring

Verify monitoring is working:

```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus -n monitoring 9090:9090
# Visit: http://localhost:9090/targets

# Check AlertManager
kubectl port-forward svc/prometheus-kube-prometheus-stack-alertmanager -n monitoring 9093:9093
# Visit: http://localhost:9093
```

### 4. Configure Backup

Set up backup strategies:

```bash
# Backup Vault data
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/vault-backup.snap

# Backup Grafana dashboards
kubectl exec -n monitoring deployment/grafana -- grafana-cli admin export-dashboard > grafana-dashboards.json

# Backup Prometheus data (if needed)
kubectl exec -n monitoring deployment/prometheus-server -- promtool tsdb create-blocks-from openmetrics /tmp/backup.prom
```

## Troubleshooting

### Common Issues

#### Applications Not Syncing

```bash
# Check application status
kubectl get applications -n argocd

# Force sync
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'

# Check Argo CD logs
kubectl logs -n argocd deployment/argocd-application-controller
```

#### Pod Startup Issues

```bash
# Check pod status
kubectl get pods -n monitoring
kubectl get pods -n vault

# Describe problematic pods
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace> --previous
```

#### Storage Issues

```bash
# Check persistent volumes
kubectl get pv,pvc -n monitoring
kubectl get pv,pvc -n vault

# Check storage classes
kubectl get storageclass

# Check volume attachments
kubectl get volumeattachment
```

### Health Checks

```bash
# Comprehensive health check script
./scripts/health-check.sh
```

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Security Considerations

### Pre-Production Checklist

- [ ] **Change default passwords** (Grafana admin password)
- [ ] **Configure TLS certificates** for all ingress resources
- [ ] **Set up RBAC** with least privilege principles
- [ ] **Enable audit logging** for all components
- [ ] **Configure network policies** for traffic isolation
- [ ] **Set up backup and disaster recovery**
- [ ] **Enable monitoring and alerting**
- [ ] **Review and update resource limits**
- [ ] **Configure external secrets management**
- [ ] **Set up log aggregation and analysis**

### Security Best Practices

1. **Use External Secrets**: Store sensitive data in Vault or cloud secret managers
2. **Enable Pod Security Standards**: Use restricted security contexts
3. **Implement Network Policies**: Restrict inter-pod communication
4. **Regular Updates**: Keep all components updated with security patches
5. **Access Control**: Implement proper RBAC and user management
6. **Audit Logging**: Enable comprehensive audit trails
7. **Encryption**: Use TLS for all communications
8. **Backup Security**: Encrypt backup data and secure backup access

### Compliance

For compliance requirements:

- **SOC 2**: Implement comprehensive logging and access controls
- **PCI DSS**: Use encrypted storage and secure communications
- **HIPAA**: Implement data encryption and access controls
- **GDPR**: Enable data retention policies and audit trails

## Support

For additional support:

1. **Documentation**: Check all guide files in this repository
2. **Issues**: Open an issue on GitHub for bugs or feature requests
3. **Community**: Join the Argo CD community for general questions
4. **Professional Support**: Consider professional support for production environments

---

**⚠️ Important**: This deployment guide is designed for production use. Always test in a development environment first and customize all configuration values according to your organization's requirements.
