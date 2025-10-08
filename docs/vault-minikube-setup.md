# Vault Minikube Setup Guide

## Overview

This guide provides step-by-step instructions for deploying HashiCorp Vault on Minikube using ArgoCD with GitOps. The configuration includes:

- **HA Mode**: 3 replicas with Raft storage (scalable to 1 for resource constraints)
- **Raft Storage**: Integrated consensus storage backend
- **AWS KMS Auto-Unseal**: Optional for production-like testing
- **GitOps**: Managed by ArgoCD for declarative deployment
- **Minikube Optimized**: Resource limits and storage class configured for local development

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Manual Setup](#manual-setup)
4. [Troubleshooting](#troubleshooting)
5. [Common Issues](#common-issues)
6. [Configuration Options](#configuration-options)

---

## Prerequisites

### Required Tools

- **Minikube** >= 1.30.0
- **kubectl** >= 1.28.0
- **Helm** >= 3.12.0
- **ArgoCD** (installed in cluster)
- **jq** (for JSON parsing)

### System Requirements

- **CPU**: 4 cores minimum (for 3 replicas)
- **Memory**: 8GB minimum
- **Disk**: 30GB free space

### Optional

- **AWS Credentials**: For KMS auto-unseal (optional, can use manual unseal)

---

## Quick Start

### Automated Setup

Use the provided setup script for a one-command deployment:

```bash
# Clone the repository
git clone https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps
cd Production-Ready-EKS-Cluster-with-GitOps

# Run the setup script
chmod +x scripts/setup-vault-minikube.sh
./scripts/setup-vault-minikube.sh
```

The script will:
1. Start Minikube with proper resources
2. Configure AWS credentials (if available)
3. Deploy Vault via ArgoCD
4. Initialize and unseal Vault
5. Setup port-forwarding for UI access

---

## Manual Setup

### Step 1: Start Minikube

```bash
# Start Minikube with sufficient resources
minikube start --cpus 4 --memory 8192 --driver=docker

# Verify Minikube is running
minikube status
```

### Step 2: Configure AWS Credentials (Optional)

For AWS KMS auto-unseal:

```bash
# Export AWS credentials
export AWS_ACCESS_KEY_ID=<your-access-key>
export AWS_SECRET_ACCESS_KEY=<your-secret-key>

# Create Kubernetes secret
kubectl create namespace vault
kubectl create secret generic aws-credentials \
  -n vault \
  --from-literal=aws_access_key_id=$AWS_ACCESS_KEY_ID \
  --from-literal=aws_secret_access_key=$AWS_SECRET_ACCESS_KEY
```

**Note**: Ensure you have a KMS key in `us-west-2` named `vault-kms-key` or update the configuration.

### Step 3: Update ArgoCD Application

Edit `argocd/apps/vault.yaml` to use Minikube values:

```yaml
spec:
  sources:
    - repoURL: 'https://helm.releases.hashicorp.com'
      chart: vault
      targetRevision: 0.28.1
      helm:
        valueFiles:
          - $values/apps/vault/values.yaml
          - $values/apps/vault/values-minikube.yaml  # Add this line
    - repoURL: 'https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps'
      targetRevision: main
      ref: values
```

### Step 4: Deploy Vault via ArgoCD

```bash
# Apply the ArgoCD application
kubectl apply -f argocd/apps/vault.yaml

# Watch the sync status
kubectl get application vault -n argocd -w

# Check pods
kubectl get pods -n vault
```

### Step 5: Initialize Vault

Once the `vault-0` pod is running:

```bash
# Initialize Vault
kubectl exec -it vault-0 -n vault -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json | tee vault-keys.json

# Set permissions
chmod 600 vault-keys.json
```

**IMPORTANT**: Save the output securely! You'll need the unseal keys and root token.

### Step 6: Unseal Vault

#### With AWS KMS Auto-Unseal

If AWS credentials are configured correctly, Vault should auto-unseal. Wait 10-15 seconds and check:

```bash
kubectl exec -it vault-0 -n vault -- vault status
```

If `Sealed: false`, auto-unseal worked!

#### Manual Unseal

If auto-unseal fails or isn't configured:

```bash
# Unseal with 3 of the 5 keys
kubectl exec -it vault-0 -n vault -- vault operator unseal <key1>
kubectl exec -it vault-0 -n vault -- vault operator unseal <key2>
kubectl exec -it vault-0 -n vault -- vault operator unseal <key3>

# Verify
kubectl exec -it vault-0 -n vault -- vault status
```

### Step 7: Join Raft Peers (HA Mode)

If running with 3 replicas:

```bash
# Wait for all pods to be running
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/vault-1 -n vault --timeout=300s
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/vault-2 -n vault --timeout=300s

# Join vault-1
kubectl exec -it vault-1 -n vault -- vault operator raft join http://vault-0.vault-internal:8200

# Join vault-2
kubectl exec -it vault-2 -n vault -- vault operator raft join http://vault-0.vault-internal:8200

# List Raft peers
kubectl exec -it vault-0 -n vault -- vault operator raft list-peers
```

### Step 8: Access Vault UI

```bash
# Port-forward to local machine
kubectl port-forward -n vault svc/vault 8200:8200

# Open browser
open http://localhost:8200

# Login with root token from vault-keys.json
```

---

## Troubleshooting

### Issue 1: ArgoCD Application OutOfSync

**Symptom**: ArgoCD shows Vault as `OutOfSync` due to `MutatingWebhookConfiguration` drift.

**Cause**: The `caBundle` field in the webhook configuration is dynamically managed by Kubernetes.

**Solution**: Already configured in `argocd/apps/vault.yaml`:

```yaml
ignoreDifferences:
  - group: admissionregistration.k8s.io
    kind: MutatingWebhookConfiguration
    jsonPointers:
      - /webhooks/0/clientConfig/caBundle
      - /webhooks/1/clientConfig/caBundle
```

Force a sync:

```bash
kubectl patch application vault -n argocd --type merge \
  -p '{"metadata": {"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Issue 2: Vault Pod Not Ready (0/1)

**Symptom**: `vault-0` pod shows `Running` but not `Ready` (0/1).

**Cause**: Vault is sealed or not initialized.

**Solution**:

1. Check if initialized:
   ```bash
   kubectl exec -it vault-0 -n vault -- vault status
   ```

2. If not initialized, initialize:
   ```bash
   kubectl exec -it vault-0 -n vault -- vault operator init
   ```

3. If sealed, unseal (see Step 6 above).

### Issue 3: StatefulSet Stuck in Progressing

**Symptom**: StatefulSet shows `READY: 0/3` and pods won't start.

**Possible Causes**:
- PVC not binding
- Insufficient resources
- Storage provisioner issue

**Solutions**:

1. Check PVCs:
   ```bash
   kubectl get pvc -n vault
   kubectl describe pvc data-vault-0 -n vault
   ```

2. Check storage class:
   ```bash
   kubectl get storageclass
   # Ensure 'standard' exists (default in Minikube)
   ```

3. Check pod events:
   ```bash
   kubectl describe pod vault-0 -n vault
   ```

4. Scale down replicas if resource constrained:
   ```bash
   kubectl scale statefulset vault -n vault --replicas=1
   ```

   Or update `apps/vault/values-minikube.yaml`:
   ```yaml
   server:
     ha:
       replicas: 1
   ```

### Issue 4: AWS KMS Auto-Unseal Fails

**Symptom**: Vault remains sealed despite AWS credentials being configured.

**Possible Causes**:
- Invalid AWS credentials
- KMS key doesn't exist
- Insufficient IAM permissions
- Wrong region

**Solutions**:

1. Verify AWS credentials:
   ```bash
   kubectl get secret aws-credentials -n vault -o yaml
   ```

2. Check Vault logs:
   ```bash
   kubectl logs vault-0 -n vault | grep -i kms
   ```

3. Test KMS access (from local machine):
   ```bash
   aws kms describe-key --key-id alias/vault-kms-key --region us-west-2
   ```

4. Required IAM permissions:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "kms:Encrypt",
           "kms:Decrypt",
           "kms:DescribeKey"
         ],
         "Resource": "arn:aws:kms:us-west-2:ACCOUNT_ID:key/*"
       }
     ]
   }
   ```

5. Fallback to manual unseal:
   - Comment out the `seal "awskms"` block in `values-minikube.yaml`
   - Redeploy and unseal manually

### Issue 5: Minikube Resource Constraints

**Symptom**: Pods stuck in `Pending` or `CrashLoopBackOff`.

**Solution**:

1. Check Minikube resources:
   ```bash
   kubectl top nodes
   kubectl describe node minikube
   ```

2. Increase Minikube resources:
   ```bash
   minikube delete
   minikube start --cpus 6 --memory 12288
   ```

3. Or scale down Vault:
   ```yaml
   # apps/vault/values-minikube.yaml
   server:
     ha:
       replicas: 1
     resources:
       requests:
         memory: 256Mi
         cpu: 250m
       limits:
         memory: 1Gi
         cpu: 1000m
   ```

---

## Common Issues

### Storage Provisioner Not Working

```bash
# Check storage provisioner
minikube addons list | grep storage

# Enable if disabled
minikube addons enable storage-provisioner
minikube addons enable default-storageclass

# Verify
kubectl get storageclass
```

### Port-Forward Keeps Disconnecting

```bash
# Use a more robust port-forward
while true; do 
  kubectl port-forward -n vault svc/vault 8200:8200 2>&1 | grep -v "Handling connection"
  sleep 1
done
```

### Can't Access Vault UI from Browser

1. Check port-forward is running:
   ```bash
   ps aux | grep "kubectl port-forward"
   ```

2. Try `127.0.0.1` instead of `localhost`:
   ```
   http://127.0.0.1:8200
   ```

3. Check firewall settings

---

## Configuration Options

### Scaling Replicas

Edit `apps/vault/values-minikube.yaml`:

```yaml
server:
  ha:
    replicas: 1  # Change to 1 or 3
```

### Changing Storage Size

```yaml
server:
  dataStorage:
    size: 5Gi  # Reduce for smaller environments
  auditStorage:
    size: 5Gi
```

### Enabling TLS

```yaml
global:
  tlsDisable: false

server:
  ha:
    raft:
      config: |
        listener "tcp" {
          tls_disable = 0
          address = "[::]:8200"
          tls_cert_file = "/vault/tls/tls.crt"
          tls_key_file = "/vault/tls/tls.key"
        }
```

Create TLS secret:

```bash
kubectl create secret generic vault-tls \
  -n vault \
  --from-file=tls.crt=path/to/cert.crt \
  --from-file=tls.key=path/to/cert.key
```

### Adjusting Resources

```yaml
server:
  resources:
    requests:
      memory: 256Mi  # Minimum for testing
      cpu: 250m
    limits:
      memory: 1Gi
      cpu: 1000m
```

---

## Useful Commands

### Vault Operations

```bash
# Check status
kubectl exec -it vault-0 -n vault -- vault status

# Login with root token
kubectl exec -it vault-0 -n vault -- vault login <root-token>

# List secrets engines
kubectl exec -it vault-0 -n vault -- vault secrets list

# Enable KV v2
kubectl exec -it vault-0 -n vault -- vault secrets enable -path=secret kv-v2

# Write a secret
kubectl exec -it vault-0 -n vault -- vault kv put secret/myapp password=secret123

# Read a secret
kubectl exec -it vault-0 -n vault -- vault kv get secret/myapp
```

### Raft Operations

```bash
# List Raft peers
kubectl exec -it vault-0 -n vault -- vault operator raft list-peers

# Check Raft configuration
kubectl exec -it vault-0 -n vault -- vault operator raft configuration

# Snapshot (backup)
kubectl exec -it vault-0 -n vault -- vault operator raft snapshot save /tmp/vault-snapshot.snap
kubectl cp vault/vault-0:/tmp/vault-snapshot.snap ./vault-snapshot.snap
```

### ArgoCD Operations

```bash
# Get application status
kubectl get application vault -n argocd

# Describe application
kubectl describe application vault -n argocd

# Force sync
kubectl patch application vault -n argocd --type merge \
  -p '{"operation": {"sync": {"syncStrategy": {"hook": {}}}}}'

# Hard refresh
kubectl patch application vault -n argocd --type merge \
  -p '{"metadata": {"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

---

## Next Steps

After successfully deploying Vault:

1. **Configure Kubernetes Auth**:
   ```bash
   ./scripts/vault-init.sh
   ```

2. **Create Policies**:
   ```bash
   kubectl exec -it vault-0 -n vault -- vault policy write myapp-policy - <<EOF
   path "secret/data/myapp/*" {
     capabilities = ["read", "list"]
   }
   EOF
   ```

3. **Create Roles**:
   ```bash
   kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/role/myapp \
     bound_service_account_names=myapp \
     bound_service_account_namespaces=default \
     policies=myapp-policy \
     ttl=24h
   ```

4. **Test with Web-App**:
   - Deploy the web-app with Vault annotations
   - Verify secrets are injected

5. **Backup**:
   - Save `vault-keys.json` securely
   - Take Raft snapshots regularly
   - Test disaster recovery

---

## Security Considerations

### Minikube vs Production

**Minikube Configuration**:
- TLS disabled (for ease of local testing)
- Single-node (no pod anti-affinity)
- Root token stored locally
- Manual unseal acceptable

**Production Configuration** (see `values-aws.yaml`):
- TLS enabled with valid certificates
- Multi-node with pod anti-affinity
- AWS KMS auto-unseal
- IAM roles for authentication
- Regular backups and monitoring

### Securing Vault Keys

1. **Never commit** `vault-keys.json` to Git
2. **Use `.gitignore`**:
   ```
   vault-keys.json
   *.snap
   ```
3. **Store securely**:
   - Password manager
   - Hardware security module (HSM)
   - AWS Secrets Manager (for production)

### Revoking Root Token

After initial setup:

```bash
# Create admin user
kubectl exec -it vault-0 -n vault -- vault auth enable userpass
kubectl exec -it vault-0 -n vault -- vault write auth/userpass/users/admin \
  password=<strong-password> \
  policies=admin-policy

# Revoke root token
kubectl exec -it vault-0 -n vault -- vault token revoke <root-token>
```

---

## References

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Vault Helm Chart](https://github.com/hashicorp/vault-helm)
- [Raft Storage Backend](https://www.vaultproject.io/docs/configuration/storage/raft)
- [AWS KMS Seal](https://www.vaultproject.io/docs/configuration/seal/awskms)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

---

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review Vault logs: `kubectl logs vault-0 -n vault`
3. Check ArgoCD UI: `kubectl port-forward -n argocd svc/argocd-server 8080:443`
4. Open an issue on GitHub

---

**Last Updated**: 2024-01-08
