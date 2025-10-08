# Vault Minikube Setup - Quick Reference

## 🚀 Quick Start (1-Command Setup)

```bash
chmod +x scripts/setup-vault-minikube.sh
./scripts/setup-vault-minikube.sh
```

This script handles everything automatically:
- ✅ Starts Minikube with proper resources
- ✅ Configures AWS credentials (optional)
- ✅ Deploys Vault via ArgoCD
- ✅ Initializes and unseals Vault
- ✅ Joins Raft peers
- ✅ Sets up port-forwarding

---

## 📋 What This Setup Provides

### Vault Configuration
- **Mode**: HA with 3 replicas (Raft consensus)
- **Storage**: Raft integrated storage (10Gi per replica)
- **Auto-Unseal**: AWS KMS (optional, falls back to manual)
- **UI**: Enabled at http://localhost:8200
- **Injector**: Enabled for automatic secret injection
- **Telemetry**: Prometheus metrics enabled

### Key Features
- **GitOps**: Fully managed by ArgoCD
- **HA Ready**: 3-node Raft cluster
- **Production-Like**: Similar config to AWS deployment
- **Resource Optimized**: Configured for Minikube constraints

---

## ⚙️ Configuration Files

### 1. `apps/vault/values-minikube.yaml`
**Purpose**: Helm values for Vault on Minikube

**Key Settings**:
```yaml
server:
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
  dataStorage:
    storageClass: standard  # Minikube default
    size: 10Gi
  resources:
    requests:
      memory: 512Mi
      cpu: 500m
```

**To Scale Down** (if resources constrained):
```yaml
server:
  ha:
    replicas: 1  # Change from 3 to 1
```

### 2. `argocd/apps/vault.yaml`
**Purpose**: ArgoCD Application definition

**For Minikube**, update line 68:
```yaml
helm:
  valueFiles:
    - $values/apps/vault/values.yaml
    - $values/apps/vault/values-minikube.yaml  # Use this for Minikube
```

**Already Configured**:
```yaml
ignoreDifferences:
  - group: admissionregistration.k8s.io
    kind: MutatingWebhookConfiguration
    jsonPointers:
      - /webhooks/0/clientConfig/caBundle  # Fixes OutOfSync issue
```

---

## 🔧 Manual Setup (Step-by-Step)

### Prerequisites
```bash
# Install required tools
brew install minikube kubectl helm jq  # macOS
# or
choco install minikube kubernetes-cli kubernetes-helm jq  # Windows
```

### Step 1: Start Minikube
```bash
minikube start --cpus 4 --memory 8192 --driver=docker
minikube status
```

### Step 2: Setup AWS KMS (Optional)
```bash
export AWS_ACCESS_KEY_ID=<your-key>
export AWS_SECRET_ACCESS_KEY=<your-secret>

kubectl create namespace vault
kubectl create secret generic aws-credentials -n vault \
  --from-literal=aws_access_key_id=$AWS_ACCESS_KEY_ID \
  --from-literal=aws_secret_access_key=$AWS_SECRET_ACCESS_KEY
```

**Note**: Requires KMS key `alias/vault-kms-key` in `us-west-2`. Skip if not using auto-unseal.

### Step 3: Deploy Vault
```bash
# Apply ArgoCD application
kubectl apply -f argocd/apps/vault.yaml

# Watch sync progress
kubectl get application vault -n argocd -w

# Check pods
kubectl get pods -n vault
```

### Step 4: Initialize Vault
```bash
# Wait for vault-0 to be running
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/vault-0 -n vault --timeout=300s

# Initialize
kubectl exec -it vault-0 -n vault -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json | tee vault-keys.json

chmod 600 vault-keys.json
```

**Output**: Save the unseal keys and root token securely!

### Step 5: Unseal Vault

**Option A: Auto-Unseal (with AWS KMS)**
```bash
# Wait 10 seconds for auto-unseal
sleep 10

# Check status
kubectl exec -it vault-0 -n vault -- vault status
# Should show: Sealed: false
```

**Option B: Manual Unseal**
```bash
# Use 3 of the 5 keys from vault-keys.json
kubectl exec -it vault-0 -n vault -- vault operator unseal <key1>
kubectl exec -it vault-0 -n vault -- vault operator unseal <key2>
kubectl exec -it vault-0 -n vault -- vault operator unseal <key3>
```

### Step 6: Join Raft Peers (HA Mode)
```bash
# Wait for all pods
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/vault-1 -n vault --timeout=300s
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/vault-2 -n vault --timeout=300s

# Join to cluster
kubectl exec -it vault-1 -n vault -- vault operator raft join http://vault-0.vault-internal:8200
kubectl exec -it vault-2 -n vault -- vault operator raft join http://vault-0.vault-internal:8200

# Verify
kubectl exec -it vault-0 -n vault -- vault operator raft list-peers
```

### Step 7: Access UI
```bash
# Port-forward
kubectl port-forward -n vault svc/vault 8200:8200

# Get root token
jq -r '.root_token' vault-keys.json

# Open browser: http://localhost:8200
```

---

## 🐛 Troubleshooting

### Issue 1: ArgoCD Shows OutOfSync (MutatingWebhookConfiguration)

**Cause**: `caBundle` field drifts (dynamically managed by Kubernetes)

**Solution**: Already handled by `ignoreDifferences` in `argocd/apps/vault.yaml`

**Force refresh**:
```bash
kubectl patch application vault -n argocd --type merge \
  -p '{"metadata": {"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Issue 2: Vault Pod Running but Not Ready (0/1)

**Cause**: Vault is sealed or not initialized

**Check**:
```bash
kubectl exec -it vault-0 -n vault -- vault status
```

**Solutions**:
- If `Initialized: false` → Initialize (Step 4)
- If `Sealed: true` → Unseal (Step 5)

### Issue 3: StatefulSet Progressing (PVC Issues)

**Check PVCs**:
```bash
kubectl get pvc -n vault
kubectl describe pvc data-vault-0 -n vault
```

**Common fixes**:
```bash
# Check storage class exists
kubectl get storageclass

# Enable storage provisioner (if needed)
minikube addons enable storage-provisioner
minikube addons enable default-storageclass

# Check node resources
kubectl describe node minikube
```

### Issue 4: Insufficient Resources

**Symptoms**: Pods stuck in `Pending` or `CrashLoopBackOff`

**Option A: Increase Minikube resources**
```bash
minikube delete
minikube start --cpus 6 --memory 12288
```

**Option B: Scale down Vault**

Edit `apps/vault/values-minikube.yaml`:
```yaml
server:
  ha:
    replicas: 1  # Scale to 1 replica
  resources:
    requests:
      memory: 256Mi
      cpu: 250m
```

Then sync:
```bash
kubectl patch application vault -n argocd --type merge \
  -p '{"metadata": {"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Issue 5: AWS KMS Auto-Unseal Fails

**Check logs**:
```bash
kubectl logs vault-0 -n vault | grep -i kms
```

**Common causes**:
- Invalid AWS credentials
- KMS key doesn't exist
- Wrong region
- Insufficient IAM permissions

**Required IAM permissions**:
```json
{
  "Effect": "Allow",
  "Action": [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:DescribeKey"
  ],
  "Resource": "arn:aws:kms:us-west-2:ACCOUNT_ID:key/*"
}
```

**Fallback**: Comment out `seal "awskms"` block in `values-minikube.yaml` and use manual unseal

---

## 🔍 Useful Commands

### Status Checks
```bash
# Vault status
kubectl exec -it vault-0 -n vault -- vault status

# Pods
kubectl get pods -n vault

# PVCs
kubectl get pvc -n vault

# StatefulSet
kubectl get statefulset vault -n vault

# ArgoCD sync
kubectl get application vault -n argocd
```

### Logs
```bash
# Vault logs
kubectl logs vault-0 -n vault

# Follow logs
kubectl logs -f vault-0 -n vault

# Injector logs
kubectl logs -l app.kubernetes.io/name=vault-agent-injector -n vault
```

### Raft Operations
```bash
# List peers
kubectl exec -it vault-0 -n vault -- vault operator raft list-peers

# Raft configuration
kubectl exec -it vault-0 -n vault -- vault operator raft configuration

# Take snapshot
kubectl exec -it vault-0 -n vault -- vault operator raft snapshot save /tmp/snapshot.snap
kubectl cp vault/vault-0:/tmp/snapshot.snap ./vault-backup.snap
```

### Secrets Operations
```bash
# Login
kubectl exec -it vault-0 -n vault -- vault login <root-token>

# Enable KV v2
kubectl exec -it vault-0 -n vault -- vault secrets enable -path=secret kv-v2

# Write secret
kubectl exec -it vault-0 -n vault -- vault kv put secret/myapp password=secret123

# Read secret
kubectl exec -it vault-0 -n vault -- vault kv get secret/myapp
```

---

## 📊 Resource Requirements

### Minimum (1 Replica)
- **CPU**: 2 cores
- **Memory**: 4GB
- **Disk**: 15GB

### Recommended (3 Replicas)
- **CPU**: 4 cores
- **Memory**: 8GB
- **Disk**: 30GB

### Vault Resource Allocation
```yaml
# Per pod (3 replicas)
server:
  resources:
    requests:
      memory: 512Mi  # Total: ~1.5Gi
      cpu: 500m      # Total: 1500m (1.5 cores)
    limits:
      memory: 2Gi    # Total: 6Gi
      cpu: 2000m     # Total: 6 cores

# Injector
injector:
  resources:
    requests:
      memory: 256Mi
      cpu: 250m
```

---

## 🔐 Security Notes

### For Minikube (Development)
- ✅ TLS disabled (ease of testing)
- ✅ Manual unseal acceptable
- ✅ Root token stored locally
- ✅ Single-node acceptable

### For Production (AWS)
- ⚠️ TLS required
- ⚠️ AWS KMS auto-unseal
- ⚠️ No root token storage
- ⚠️ Multi-node with pod anti-affinity

### Protecting Vault Keys
```bash
# Add to .gitignore
echo "vault-keys.json" >> .gitignore
echo "*.snap" >> .gitignore

# Set restrictive permissions
chmod 600 vault-keys.json

# Delete after secure backup
rm vault-keys.json
```

---

## 🎯 Next Steps After Setup

1. **Configure Kubernetes Auth**:
   ```bash
   ./scripts/vault-init.sh
   ```

2. **Create Sample Secret**:
   ```bash
   kubectl exec -it vault-0 -n vault -- vault kv put secret/webapp \
     db_password=secret123 \
     api_key=abc123
   ```

3. **Test with Web-App**:
   - Deploy web-app with Vault annotations
   - Verify secrets are injected

4. **Backup**:
   ```bash
   kubectl exec -it vault-0 -n vault -- vault operator raft snapshot save /tmp/backup.snap
   kubectl cp vault/vault-0:/tmp/backup.snap ./vault-backup-$(date +%Y%m%d).snap
   ```

---

## 📚 Additional Resources

- **Full Documentation**: `docs/vault-minikube-setup.md`
- **Vault Init Script**: `scripts/vault-init.sh`
- **Setup Script**: `scripts/setup-vault-minikube.sh`
- **Values Files**: `apps/vault/values-minikube.yaml`

---

## 🆘 Getting Help

1. Check `docs/vault-minikube-setup.md` for detailed troubleshooting
2. Review logs: `kubectl logs vault-0 -n vault`
3. Check ArgoCD UI: `kubectl port-forward -n argocd svc/argocd-server 8080:443`
4. Open GitHub issue with:
   - Minikube version (`minikube version`)
   - Kubectl version (`kubectl version`)
   - Error logs
   - Configuration files

---

**Last Updated**: 2024-01-08  
**Vault Version**: 1.17.x  
**Helm Chart**: 0.28.1
