# Local Deployment Guide

> Compatibility: Kubernetes v1.33.0 (Minikube or compatible local cluster)

Complete guide for deploying this GitOps repository on **Minikube** or similar local Kubernetes clusters.

## 🎯 Overview

This deployment provides a **complete GitOps stack** optimized for local development:

| Phase | Component | Duration | Description |
|-------|-----------|----------|-------------|
| **Phase 1** | Local Infrastructure | 5 min | Start Minikube with required addons |
| **Phase 2** | ArgoCD Bootstrap | 5-10 min | Install ArgoCD and GitOps foundation |
| **Phase 3** | Applications | 10-15 min | Deploy monitoring, vault, and web app via GitOps |
| **Phase 4** | Verification | 5 min | Validate deployment and access services |

**Total Time**: ~25-35 minutes

**Note**: This guide uses the **automated setup script** for simplicity. For manual step-by-step deployment, see the detailed sections below.

## 📋 Prerequisites

### System Requirements
- **RAM**: 4GB minimum, 8GB recommended
- **CPU**: 2 cores minimum, 4 cores recommended
- **Storage**: 30GB free disk space

### Required Tools

```bash
# macOS installation
brew install minikube kubectl helm vault

# Linux installation
# Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# kubectl v1.33+
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Vault CLI
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault
```

## 🚀 Quick Start (Automated)

### Single Command Deployment

```bash
# Run the automated setup script
./scripts/setup-minikube.sh
```

This script automatically:
- ✅ Checks prerequisites (kubectl, helm, minikube)
- ✅ Starts Minikube with optimized resources
- ✅ Enables required addons (ingress, metrics-server)
- ✅ Deploys ArgoCD
- ✅ Bootstraps GitOps applications
- ✅ Provides access credentials

**Skip to Phase 4** for verification if using the automated script.

---

## 🚀 Phase 1: Local Infrastructure (Manual)

### Step 1.1: Start Minikube

```bash
# Start Minikube with optimized resources
minikube start \
  --memory=4096 \
  --cpus=2 \
  --disk-size=30g \
  --driver=docker \
  --kubernetes-version=v1.33.0
```

### Step 1.2: Enable Required Addons

```bash
# Enable essential addons
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable storage-provisioner
minikube addons enable default-storageclass
```

**✅ Phase 1 Complete**: Minikube running with required addons

## 🔧 Phase 2: ArgoCD Bootstrap (Manual)

### Step 2.1: Create Namespaces

```bash
# Apply namespace definitions
kubectl apply -f argo-apps/install/01-namespaces.yaml

# Wait for namespaces to be active
kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/argocd --timeout=60s
```

### Step 2.2: Install ArgoCD

```bash
# Install ArgoCD using official manifest
ARGOCD_VERSION="2.13.0"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml

# Wait for ArgoCD to be ready (3-5 minutes)
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Additional wait for all pods to stabilize
sleep 30
```

> **Note**: ArgoCD auto-generates an admin password stored in the `argocd-initial-admin-secret` secret.

### Step 2.3: Access ArgoCD UI

```bash
# Get admin password
export ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
echo "ArgoCD UI: https://localhost:8080"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
```

**Alternative**: Use the automated login script:
```bash
./scripts/argocd-login.sh
```

### Step 2.4: Deploy Applications via GitOps

```bash
# Deploy the bootstrap manifest which includes all applications
kubectl apply -f argo-apps/install/03-bootstrap.yaml

# Wait for applications to sync
sleep 30

# Verify all applications are syncing
kubectl get applications -n argocd
# Expected: grafana, prometheus, vault, web-app
```

> **Note**: The bootstrap file contains ArgoCD Application manifests that reference Helm charts. ArgoCD will automatically sync and deploy all applications.

## 📊 Phase 3: Applications Deployment

> **Note**: ArgoCD automatically deploys all applications defined in `argo-apps/install/03-bootstrap.yaml`. This includes Prometheus, Grafana, Vault, and the sample web application. All applications use **upstream Helm charts** with custom values overrides.

### Step 3.1: Monitor Application Sync

```bash
# Watch applications as they sync
watch kubectl get applications -n argocd

# Check individual application status
kubectl get application prometheus -n argocd
kubectl get application grafana -n argocd
kubectl get application vault -n argocd
kubectl get application web-app -n argocd
```

### Step 3.2: Wait for All Pods

```bash
# Wait for monitoring namespace pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

# Wait for vault namespace pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault --timeout=300s

# Wait for production namespace pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=web-app -n production --timeout=300s
```

**✅ Phase 3 Complete**: All applications deployed via GitOps

## ✅ Phase 4: Verification & Access

### System Health Check

```bash
# Use the Makefile helper
make dev-status

# Or manually check each component
kubectl get applications -n argocd
kubectl get pods -A | grep -v "Running\|Completed"
kubectl top nodes
```

### Access All Services

**Using Automated Script:**
```bash
# This script handles port-forwarding and provides all access info
./scripts/argocd-login.sh
```

**Manual Access:**
```bash
# Stop any existing port-forwards
pkill -f "kubectl port-forward"

# Get passwords
export ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
echo "ArgoCD: https://localhost:8080 (admin / $ARGOCD_PASSWORD)"

# Prometheus
kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090 > /dev/null 2>&1 &
echo "Prometheus: http://localhost:9090"

# Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80 > /dev/null 2>&1 &
echo "Grafana: http://localhost:3000 (admin / admin)"

# Vault
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &
echo "Vault: http://localhost:8200"

# Web App
kubectl port-forward svc/web-app -n production 8081:80 > /dev/null 2>&1 &
echo "Web App: http://localhost:8081"
```

**Quick Access via Makefile:**
```bash
make port-forward-argocd   # ArgoCD UI
make port-forward-grafana  # Grafana
```

## 🚨 Troubleshooting

### Common Issues

#### Minikube Not Starting
```bash
# Check status and logs
minikube status
minikube logs

# Try recreating
minikube delete
minikube start --memory=4096 --cpus=2 --disk-size=30g --driver=docker
```

#### Out of Resources
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A

# Reduce monitoring resources or stop temporarily
kubectl scale statefulset prometheus-kube-prometheus-stack-prometheus -n monitoring --replicas=0
```

#### Vault Sealed After Restart
```bash
# Load keys and unseal
source ~/.vault-local-env
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &
vault operator unseal $VAULT_UNSEAL_KEY
```

## 🧹 Cleanup

### Full Cleanup
```bash
# Delete Minikube cluster
minikube delete

# Remove local files
rm -f vault-keys-local.txt
rm -f ~/.vault-local-env
```

### Partial Cleanup (Keep Minikube)
```bash
# Delete root application (this will cascade delete all child apps)
kubectl delete -f environments/prod/app-of-apps.yaml

# Wait for applications to be removed
kubectl wait --for=delete application/prod-cluster -n argocd --timeout=300s

# Delete ArgoCD
helm uninstall argo-cd -n argocd

# Delete namespaces
kubectl delete namespace argocd monitoring production
```

## 🔧 Daily Operations

### Starting Your Environment
```bash
# Start Minikube
minikube start

# Access services
./scripts/argocd-login.sh

# Or use Makefile
make argo-login
```

### Updating Application Configuration

```bash
# Edit Helm values
vi helm-charts/web-app/values-minikube.yaml

# Commit changes (ArgoCD will auto-sync)
git add helm-charts/web-app/values-minikube.yaml
git commit -m "Update web app configuration for Minikube"
git push

# Force sync if needed
kubectl patch application web-app -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

### Scaling Applications

```bash
# View current HPA status
kubectl get hpa -n production

# Manual scaling for testing
kubectl scale deployment web-app -n production --replicas=3
```

## 📚 Additional Resources

### Documentation
- **[Architecture Guide](architecture.md)** - Understand the repository structure
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions
- **[ArgoCD CLI Setup](argocd-cli-setup.md)** - Windows/cross-platform setup
- **[Scripts Documentation](scripts.md)** - Detailed script usage
- **[CI/CD Pipeline](ci_cd_pipeline.md)** - GitHub Actions workflows

### Makefile Commands

```bash
# Show all available commands
make help

# Common commands
make deploy-minikube      # Full automated deployment
make validate-all         # Validate everything
make argo-login          # Login to ArgoCD
make port-forward-argocd # Access ArgoCD UI
```

### Helm Chart Information

This repository uses **upstream Helm charts** for Prometheus, Grafana, and Vault:
- **Prometheus**: prometheus-community/kube-prometheus-stack
- **Grafana**: grafana/grafana
- **Vault**: hashicorp/vault

Only **values overrides** are maintained locally in `helm-charts/*/values*.yaml` files. The web-app uses a custom Helm chart in `helm-charts/web-app/`.

---

**Next Steps**: See [Troubleshooting Guide](troubleshooting.md) for common issues and [Architecture Guide](architecture.md) for understanding the repository structure.
