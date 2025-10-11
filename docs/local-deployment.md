# Local Deployment Guide

> **Primary deployment path for this repository**  
> Compatibility: Kubernetes v1.33.0 (Minikube or compatible local cluster)

Complete guide for deploying a GitOps stack on **Minikube** with ArgoCD, Vault (manual unseal), Prometheus, and Grafana.

## 🎯 Overview

This deployment provides a **complete GitOps stack** optimized for local development:

| Phase | Component | Duration | Description |
|-------|-----------|----------|-------------|
| **Phase 0** | Prerequisites Check | 2 min | Verify tools and system resources |
| **Phase 1** | Local Infrastructure | 5 min | Start Minikube with required addons |
| **Phase 2** | ArgoCD Bootstrap | 5-10 min | Install ArgoCD and GitOps foundation |
| **Phase 3** | Applications | 10-15 min | Deploy monitoring, vault, and web app via GitOps |
| **Phase 3.5** | Vault Unseal | 2-3 min | Manually unseal Vault (required) |
| **Phase 4** | Verification | 5 min | Validate deployment and access services |

**Total Time**: ~30-40 minutes

**Note**: This guide uses the **automated setup script** for simplicity. For manual step-by-step deployment, see the detailed sections below.

## ⚠️ Important: Vault Configuration

This local setup uses **single-replica Vault with file storage** and **manual unseal**:
- **NOT dev mode** - Proper initialization required
- **Manual unseal** - Required after each Vault restart
- **File storage** - Data persists in PVC at `/vault/data`
- **Minikube storageClass** - Uses `standard` (not `gp3`)

For production AWS deployment with HA and KMS auto-unseal, see [Vault AWS Setup](vault-setup.md).

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

**⚠️ Important**: After script completes, you must **manually unseal Vault** (see Phase 3.5 below).

**Skip to Phase 3.5** for Vault unseal if using the automated script.

---

## 🛠️ Phase 0: Prerequisites Check (Manual)

### Step 0.1: Verify Required Tools

```bash
# Check Minikube
minikube version
# Expected: v1.30+

# Check kubectl
kubectl version --client
# Expected: v1.33+

# Check Helm
helm version
# Expected: v3.x

# Check Docker
docker --version
# Expected: 20.x+
```

### Step 0.2: Verify System Resources

```bash
# Check available memory (Linux/macOS)
free -h  # Should show at least 4GB available

# Check available disk space
df -h .  # Should show at least 30GB free
```

**✅ Phase 0 Complete**: All prerequisites verified

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
ARGOCD_VERSION="3.1.0"
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

---

## 🔐 Phase 3.5: Vault Manual Unseal (REQUIRED)

> **Critical**: Vault will not be ready until manually unsealed. This is normal for non-dev mode Vault.

### Step 3.5.1: Check Vault Status

```bash
# Check Vault pod status
kubectl get pods -n vault

# Expected output:
# NAME      READY   STATUS    RESTARTS   AGE
# vault-0   0/1     Running   0          2m
# Note: 0/1 Ready is normal - Vault is sealed
```

### Step 3.5.2: Initialize Vault (First Time Only)

**Only run this if Vault has never been initialized:**

```bash
# Port-forward to Vault
kubectl port-forward svc/vault -n vault 8200:8200 &

# Initialize Vault
kubectl exec -n vault vault-0 -- vault operator init -key-shares=1 -key-threshold=1

# Save the output! You'll see:
# Unseal Key 1: <UNSEAL_KEY>
# Initial Root Token: <ROOT_TOKEN>

# Save these to a local file (KEEP SECURE)
cat > ~/.vault-local-env <<EOF
export VAULT_UNSEAL_KEY="<paste-unseal-key-here>"
export VAULT_ROOT_TOKEN="<paste-root-token-here>"
export VAULT_ADDR="http://localhost:8200"
EOF

chmod 600 ~/.vault-local-env
```

### Step 3.5.3: Unseal Vault

```bash
# Load saved keys
source ~/.vault-local-env

# Unseal Vault
kubectl exec -n vault vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY

# Verify Vault is unsealed
kubectl exec -n vault vault-0 -- vault status

# Expected: Sealed: false
```

### Step 3.5.4: Verify Vault Pod Ready

```bash
# Check pod status (should now show 1/1 Ready)
kubectl get pods -n vault

# Expected output:
# NAME      READY   STATUS    RESTARTS   AGE
# vault-0   1/1     Running   0          5m
```

**✅ Phase 3.5 Complete**: Vault unsealed and ready

---

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

### Vault Issues

#### Vault Pod Not Ready (0/1)

**Symptom**: Vault pod shows `0/1 Ready` even after deployment

**Cause**: Vault is sealed (normal for non-dev mode)

**Solution**: Unseal Vault following [Phase 3.5](#-phase-35-vault-manual-unseal-required)

#### Vault PVC Binding Issues

**Symptom**: Vault PVC stuck in `Pending` state

```bash
kubectl get pvc -n vault
# NAME                   STATUS    VOLUME   CAPACITY
# data-vault-0           Pending
```

**Cause**: Wrong storageClass specified (e.g., `gp3` instead of `standard` for Minikube)

**Solution**:

```bash
# 1. Verify Minikube storageClass exists
kubectl get storageclass
# Should see 'standard' storageClass

# 2. Delete the stuck PVC
kubectl delete pvc data-vault-0 -n vault

# 3. Delete the Vault pod to trigger recreation
kubectl delete pod vault-0 -n vault

# 4. Or resync the Argo CD application
kubectl patch application vault -n argocd --type merge -p '{"operation":{"sync":{}}}'

# 5. Verify new PVC binds correctly
kubectl get pvc -n vault
# Should show 'Bound' status
```

**Helm values check** (ensure `values-minikube.yaml` uses `standard`):
```yaml
# helm-charts/vault/values-minikube.yaml
server:
  dataStorage:
    storageClass: standard  # NOT gp3
```

#### Vault Permission Errors (`/vault/data`)

**Symptom**: Vault pod logs show permission denied for `/vault/data`

```bash
kubectl logs vault-0 -n vault
# Error: permission denied: /vault/data
```

**Cause**: Init container or security context issues with PVC ownership

**Solution**:

```bash
# 1. Check init container logs
kubectl logs vault-0 -n vault -c vault-init

# 2. Verify security context in Helm values
# helm-charts/vault/values-minikube.yaml should have:
# server:
#   securityContext:
#     fsGroup: 1000
#     runAsUser: 100
#     runAsNonRoot: true

# 3. Delete pod and PVC to start fresh
kubectl delete pod vault-0 -n vault
kubectl delete pvc data-vault-0 -n vault

# 4. Resync Argo CD application
kubectl patch application vault -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

#### Vault Sealed After Restart

**Symptom**: Vault becomes sealed after Minikube restart or pod restart

**Cause**: Manual unseal required (expected behavior for non-KMS Vault)

**Solution**:
```bash
# Load saved keys
source ~/.vault-local-env

# Port-forward to Vault
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &

# Unseal Vault
kubectl exec -n vault vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY

# Verify unsealed
kubectl exec -n vault vault-0 -- vault status
```

### Argo CD Issues

#### Application Stuck Syncing

**Symptom**: Argo CD application shows "Progressing" or "OutOfSync" indefinitely

**Solution**:

```bash
# 1. Hard refresh the application
kubectl patch application <app-name> -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# 2. Force sync
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"sync":{}}}'

# 3. Check application status
kubectl get application <app-name> -n argocd
kubectl describe application <app-name> -n argocd
```

#### PVC Cleanup and Resync Workflow

**When to use**: Application has persistent issues, need fresh start

```bash
# Example: Reset Vault completely

# 1. Delete the Argo CD application (stops management)
kubectl delete application vault -n argocd

# 2. Delete the namespace (removes all resources)
kubectl delete namespace vault

# 3. Delete any stuck PVCs
kubectl get pvc -A | grep vault
kubectl delete pvc <pvc-name> -n vault

# 4. Recreate the application (Argo CD will resync)
kubectl apply -f argo-apps/apps/vault.yaml

# 5. Wait for deployment
kubectl wait --for=condition=available deployment/vault -n vault --timeout=300s

# 6. Unseal Vault (see Phase 3.5)
```

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

### Daily Startup Workflow

**Complete workflow for starting your local environment:**

```bash
# 1. Start Minikube
minikube start

# 2. Wait for all pods (except Vault)
kubectl get pods -A
# Most pods should show Running, Vault will be 0/1 (sealed)

# 3. Unseal Vault
source ~/.vault-local-env
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &
kubectl exec -n vault vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY

# 4. Verify Vault is ready
kubectl get pods -n vault
# Should show vault-0 as 1/1 Running

# 5. Access services
./scripts/argocd-login.sh
```

**Quick check - All services healthy:**
```bash
# Check all pods are running
kubectl get pods -A | grep -v "Running\|Completed"
# Should show no output (or only Completed jobs)
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
