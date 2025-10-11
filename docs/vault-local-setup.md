# Vault Local Setup Guide

> **For local Minikube development only**  
> For production AWS deployment, see [Vault AWS Setup](vault-setup.md)

Complete guide for deploying and managing HashiCorp Vault on **Minikube** with single-replica, file storage, and manual unseal.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Initialization & Unsealing](#initialization--unsealing)
- [Daily Operations](#daily-operations)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

This Vault configuration is optimized for **local development and learning**:

### Key Features

| Feature | Local Configuration | Reason |
|---------|---------------------|--------|
| **Replicas** | Single (1) | Lightweight, sufficient for dev |
| **Storage** | File backend | Simple, PVC-backed persistence |
| **Unseal** | Manual | Closer to production than dev mode |
| **TLS** | Disabled | Simplified local access |
| **StorageClass** | `standard` (Minikube) | Local provisioner |
| **HA** | Disabled | Not needed locally |

### vs Production (AWS)

| Feature | Local | AWS Production |
|---------|-------|----------------|
| Replicas | 1 | 3 (HA) |
| Storage | File | Raft consensus |
| Unseal | Manual | AWS KMS auto-unseal |
| TLS | Disabled | Enabled |
| Performance | Dev workloads | Production scale |

## 🏗️ Architecture

### Local Vault Stack

```
┌──────────────────────────────────────┐
│         Minikube Cluster             │
│                                      │
│  ┌────────────────────────────────┐ │
│  │     Vault Namespace            │ │
│  │                                │ │
│  │  ┌──────────────────────────┐  │ │
│  │  │       vault-0            │  │ │
│  │  │  Single Replica          │  │ │
│  │  │  (Sealed on start)       │  │ │
│  │  └──────────┬───────────────┘  │ │
│  │             │                   │ │
│  │  ┌──────────▼───────────────┐  │ │
│  │  │  PVC: data-vault-0       │  │ │
│  │  │  StorageClass: standard  │  │ │
│  │  │  Path: /vault/data       │  │ │
│  │  └──────────────────────────┘  │ │
│  └────────────────────────────────┘ │
└──────────────────────────────────────┘

Manual Unseal Required:
  kubectl exec vault-0 -- vault operator unseal <key>
```

## ⚙️ Configuration

### Helm Values Structure

Vault uses **upstream Helm chart** with local overrides:

```
helm-charts/vault/
├── values.yaml              # Base values (shared)
├── values-minikube.yaml     # Local overrides
└── values-aws.yaml          # Production overrides
```

### Key Configuration: values-minikube.yaml

```yaml
server:
  # Single replica for local
  replicas: 1
  
  # File storage (not Raft)
  dataStorage:
    enabled: true
    size: 1Gi
    storageClass: standard  # Minikube storageClass
    accessMode: ReadWriteOnce
  
  # Standalone mode (no HA)
  standalone:
    enabled: true
    config: |
      ui = true
      listener "tcp" {
        tls_disable = 1
        address = "[::]:8200"
        cluster_address = "[::]:8201"
      }
      storage "file" {
        path = "/vault/data"
      }
  
  # Disable HA features
  ha:
    enabled: false
```

### Storage Backend

**File storage** is used instead of Raft:
- **Path**: `/vault/data` inside container
- **Backing**: PVC named `data-vault-0`
- **Persistence**: Data survives pod restarts
- **Not replicated**: Single copy (local dev acceptable)

## 🚀 Deployment

### Via Argo CD (Recommended)

Vault is deployed automatically via GitOps:

```bash
# 1. Ensure Argo CD is running
kubectl get pods -n argocd

# 2. Vault application is bootstrapped
kubectl get application vault -n argocd

# 3. Check Vault pod status
kubectl get pods -n vault
# Expected: vault-0   0/1   Running  (sealed)
```

### Manual Deployment

If deploying manually without Argo CD:

```bash
# Add HashiCorp Helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install Vault
helm install vault hashicorp/vault \
  -n vault \
  --create-namespace \
  -f helm-charts/vault/values.yaml \
  -f helm-charts/vault/values-minikube.yaml

# Wait for pod
kubectl wait --for=condition=PodScheduled pod/vault-0 -n vault --timeout=120s
```

## 🔐 Initialization & Unsealing

### First-Time Initialization

**Run once when Vault is first deployed:**

```bash
# 1. Port-forward to Vault
kubectl port-forward svc/vault -n vault 8200:8200 &

# 2. Initialize Vault (single unseal key for dev)
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=1 \
  -key-threshold=1

# Output will show:
# Unseal Key 1: <UNSEAL_KEY>
# Initial Root Token: <ROOT_TOKEN>
```

### Save Keys Securely

**Store keys in a local file:**

```bash
cat > ~/.vault-local-env <<'EOF'
export VAULT_UNSEAL_KEY="<paste-unseal-key-here>"
export VAULT_ROOT_TOKEN="<paste-root-token-here>"
export VAULT_ADDR="http://localhost:8200"
EOF

chmod 600 ~/.vault-local-env
```

⚠️ **Security Note**: This is for local dev only. In production, store keys in a secure vault or KMS.

### Unsealing Vault

**Required every time Vault pod restarts:**

```bash
# 1. Load saved keys
source ~/.vault-local-env

# 2. Port-forward (if not already running)
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &

# 3. Unseal Vault
kubectl exec -n vault vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY

# 4. Verify status
kubectl exec -n vault vault-0 -- vault status
# Should show: Sealed: false
```

### Check Vault Status

```bash
# Via kubectl
kubectl exec -n vault vault-0 -- vault status

# Expected output:
# Key             Value
# ---             -----
# Seal Type       shamir
# Initialized     true
# Sealed          false
# Total Shares    1
# Threshold       1
# Version         1.17.x
# Storage Type    file
# HA Enabled      false
```

## 🔧 Daily Operations

### Starting Minikube + Vault

Complete daily workflow:

```bash
# 1. Start Minikube
minikube start

# 2. Wait for Vault pod
kubectl get pods -n vault
# Shows: vault-0  0/1  Running  (sealed)

# 3. Unseal Vault
source ~/.vault-local-env
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &
kubectl exec -n vault vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY

# 4. Verify ready
kubectl get pods -n vault
# Shows: vault-0  1/1  Running
```

### Accessing Vault UI

```bash
# Port-forward (if not already running)
kubectl port-forward svc/vault -n vault 8200:8200

# Open browser
open http://localhost:8200

# Login with root token
source ~/.vault-local-env
echo $VAULT_ROOT_TOKEN
```

### Using Vault CLI

```bash
# Set environment
source ~/.vault-local-env

# Verify connection
vault status

# Write a secret
vault kv put secret/myapp/config \
  username=admin \
  password=supersecret

# Read a secret
vault kv get secret/myapp/config
```

### Checking Vault Logs

```bash
# Follow logs
kubectl logs -f vault-0 -n vault

# Last 50 lines
kubectl logs vault-0 -n vault --tail=50

# Previous pod logs (if crashed)
kubectl logs vault-0 -n vault --previous
```

## 🚨 Troubleshooting

### Vault Pod Not Ready

**Symptom**: Pod shows `0/1 Ready` after deployment

**Cause**: Vault is sealed (expected)

**Solution**: Unseal Vault (see [Unsealing Vault](#unsealing-vault))

### PVC Binding Failed

**Symptom**: PVC stuck in `Pending` state

```bash
kubectl get pvc -n vault
# NAME            STATUS    VOLUME   CAPACITY
# data-vault-0    Pending
```

**Solution**:

```bash
# Check storageClass exists
kubectl get storageclass
# Should show 'standard' for Minikube

# If PVC is stuck, delete and recreate
kubectl delete pvc data-vault-0 -n vault
kubectl delete pod vault-0 -n vault

# Or resync via Argo CD
kubectl patch application vault -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

### Permission Denied: /vault/data

**Symptom**: Vault logs show permission errors

```bash
kubectl logs vault-0 -n vault
# Error: permission denied: /vault/data
```

**Solution**:

```bash
# Check security context in Helm values
# values-minikube.yaml should have:
# server:
#   securityContext:
#     fsGroup: 1000
#     runAsUser: 100

# Reset PVC and pod
kubectl delete pod vault-0 -n vault
kubectl delete pvc data-vault-0 -n vault

# Resync Argo CD application
kubectl patch application vault -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

### Vault Becomes Sealed After Restart

**Symptom**: Vault sealed after Minikube restart

**Cause**: Manual unseal required (expected for non-KMS Vault)

**Solution**: This is normal behavior. Follow daily unseal procedure (see [Daily Operations](#daily-operations))

### Lost Unseal Key

**Symptom**: Cannot find unseal key or root token

**Solution**:

```bash
# 1. Check if file exists
cat ~/.vault-local-env

# 2. If lost, reinitialize Vault (DATA LOSS)
kubectl delete namespace vault
kubectl apply -f argo-apps/apps/vault.yaml
# Follow initialization steps again
```

⚠️ **Warning**: Reinitializing Vault will lose all stored secrets.

### Port Forward Issues

**Symptom**: `kubectl port-forward` fails or hangs

**Solution**:

```bash
# Kill existing port-forwards
pkill -f "kubectl port-forward.*vault"

# Check if port is in use
lsof -i :8200
# Kill process if needed

# Restart port-forward
kubectl port-forward svc/vault -n vault 8200:8200 &
```

## 📚 Additional Resources

### Official Documentation

- [Vault Documentation](https://www.vaultproject.io/docs)
- [Vault on Kubernetes](https://learn.hashicorp.com/tutorials/vault/kubernetes-minikube)
- [Vault Helm Chart](https://github.com/hashicorp/vault-helm)

### Related Guides

- [Local Deployment Guide](local-deployment.md) - Full Minikube setup
- [Vault AWS Setup](vault-setup.md) - Production Vault with HA
- [Troubleshooting Guide](troubleshooting.md) - Common issues

### Next Steps

1. **Learn Vault basics**: https://learn.hashicorp.com/vault
2. **Set up Kubernetes auth**: For application secret injection
3. **Create policies**: For least-privilege access
4. **Deploy to AWS**: When ready for production ([Vault AWS Setup](vault-setup.md))

---

**Questions?** See [Troubleshooting Guide](troubleshooting.md) or check the [main documentation index](README.md).

