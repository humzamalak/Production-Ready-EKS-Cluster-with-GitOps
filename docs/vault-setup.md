# HashiCorp Vault Setup Guide (AWS Production)

> ⚠️ **AWS/Production Deployment Only**  
> **For local Minikube setup**, see [Vault Local Setup Guide](vault-local-setup.md)

Complete guide for deploying production-grade HashiCorp Vault on **AWS EKS** with HA, Raft storage, and KMS auto-unseal.

## 🔀 Vault Deployment Options

| Feature | [Local (Minikube)](vault-local-setup.md) | AWS Production (This Guide) |
|---------|------------------------------------------|------------------------------|
| **Replicas** | Single (1) | High Availability (3) |
| **Storage** | File backend | Raft consensus |
| **Unseal** | Manual | AWS KMS auto-unseal |
| **TLS** | Disabled | Enabled |
| **StorageClass** | `standard` | AWS EBS `gp3` |
| **Best For** | Development, Learning | Production workloads |

**Starting out?** Use [Vault Local Setup](vault-local-setup.md) for learning and testing.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [AWS Resources Setup](#aws-resources-setup)
- [Deployment](#deployment)
- [Initialization](#initialization)
- [Verification](#verification)
- [Post-Installation](#post-installation)
- [Troubleshooting](#troubleshooting)

## Overview

This deployment configures **production-grade** HashiCorp Vault with:

- **High Availability (HA)**: 3 replicas with Raft consensus
- **Persistent Storage**: AWS EBS volumes (gp3) for each replica
- **Auto-Unseal**: AWS KMS for automatic unsealing (no manual intervention)
- **Service Account**: IRSA (IAM Roles for Service Accounts) for KMS access
- **Agent Injector**: Automatic secret injection into pods
- **GitOps**: ArgoCD management with automatic sync

## Prerequisites

### Required Tools

- `kubectl` (v1.33+)
- `aws-cli` (v2+)
- `terraform` (for infrastructure)
- `argocd` CLI

### AWS Resources

1. **EKS Cluster**: Running and accessible
2. **KMS Key**: For auto-unseal
3. **IAM Role**: For Vault service account with KMS access
4. **Storage Class**: `gp3` configured in cluster

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   EKS Cluster                       │
│                                                     │
│  ┌────────────────────────────────────────────┐   │
│  │          Vault Namespace                   │   │
│  │                                            │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐│   │
│  │  │ vault-0  │  │ vault-1  │  │ vault-2  ││   │
│  │  │  (Raft)  │◄─┤  (Raft)  │◄─┤  (Raft)  ││   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘│   │
│  │       │             │             │       │   │
│  │  ┌────▼─────┐  ┌───▼──────┐  ┌───▼─────┐│   │
│  │  │ EBS PVC  │  │ EBS PVC  │  │ EBS PVC ││   │
│  │  └──────────┘  └──────────┘  └─────────┘│   │
│  │                                            │   │
│  │  ┌──────────────────────────────────────┐│   │
│  │  │    Vault Agent Injector (2 pods)    ││   │
│  │  │  (MutatingWebhookConfiguration)      ││   │
│  │  └──────────────────────────────────────┘│   │
│  └────────────────────────────────────────────┘   │
│                         │                          │
│                         ▼                          │
│              ┌──────────────────┐                 │
│              │   AWS KMS Key    │                 │
│              │  (Auto-Unseal)   │                 │
│              └──────────────────┘                 │
└─────────────────────────────────────────────────────┘
```

## AWS Resources Setup

### 1. Create KMS Key

```bash
# Create KMS key
aws kms create-key \
  --description "Vault Auto-Unseal Key" \
  --region us-west-2

# Create alias
aws kms create-alias \
  --alias-name alias/vault-kms-key \
  --target-key-id <key-id> \
  --region us-west-2

# Note the Key ARN for next steps
export VAULT_KMS_KEY_ARN="arn:aws:kms:us-west-2:ACCOUNT_ID:key/KEY_ID"
```

### 2. Create IAM Policy for KMS Access

Create `vault-kms-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:us-west-2:ACCOUNT_ID:key/KEY_ID"
    }
  ]
}
```

Create the policy:

```bash
aws iam create-policy \
  --policy-name VaultKMSUnsealPolicy \
  --policy-document file://vault-kms-policy.json
```

### 3. Create IAM Role with IRSA

```bash
# Get OIDC provider
export OIDC_PROVIDER=$(aws eks describe-cluster \
  --name your-cluster-name \
  --query "cluster.identity.oidc.issuer" \
  --output text | sed 's|https://||')

# Create trust policy
cat > vault-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:vault:vault-server",
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name VaultKMSUnsealRole \
  --assume-role-policy-document file://vault-trust-policy.json

# Attach policy to role
aws iam attach-role-policy \
  --role-name VaultKMSUnsealRole \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/VaultKMSUnsealPolicy

# Note the Role ARN
export VAULT_ROLE_ARN="arn:aws:iam::ACCOUNT_ID:role/VaultKMSUnsealRole"
```

### 4. Update Vault Values

Edit `apps/vault/values-aws.yaml` and add the IAM role ARN:

```yaml
server:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/VaultKMSUnsealRole"
```

Also verify the KMS configuration:

```yaml
seal "awskms" {
  region     = "us-west-2"
  kms_key_id = "alias/vault-kms-key"
}
```

## Deployment

### 1. Commit Changes

```bash
# Add changes
git add argocd/apps/vault.yaml apps/vault/values-aws.yaml

# Commit
git commit -m "Configure Vault with Raft storage and AWS KMS auto-unseal"

# Push
git push origin main
```

### 2. Sync ArgoCD Application

```bash
# Sync Vault application
argocd app sync vault

# Watch sync progress
argocd app get vault --watch
```

ArgoCD will deploy:
- Vault StatefulSet (3 replicas)
- Vault Agent Injector deployment
- Services and PVCs
- MutatingWebhookConfiguration

### 3. Wait for Pods

```bash
# Wait for pods to be running (they won't be ready until initialized)
kubectl wait --for=condition=PodScheduled pod/vault-0 -n vault --timeout=300s

# Check pod status
kubectl get pods -n vault
```

Expected output:
```
NAME                                    READY   STATUS    RESTARTS   AGE
vault-0                                 0/1     Running   0          2m
vault-1                                 0/1     Running   0          2m
vault-2                                 0/1     Running   0          2m
vault-agent-injector-XXXXX-XXXXX        1/1     Running   0          2m
vault-agent-injector-XXXXX-XXXXX        1/1     Running   0          2m
```

> **Note**: Vault pods show `0/1 Ready` until initialized and unsealed.

## Initialization

### 1. Run Verification Script

```bash
./scripts/verify-vault.sh
```

This checks:
- ArgoCD sync status
- Pod status
- Services and PVCs
- Vault seal status
- Recent events and logs

### 2. Initialize Vault

```bash
./scripts/vault-init.sh
```

This script will:
1. Check prerequisites
2. Wait for vault-0 pod
3. Initialize Vault with Raft storage
4. Save recovery keys to `vault-keys.json`
5. Wait for AWS KMS auto-unseal
6. Join vault-1 and vault-2 to Raft cluster
7. Enable audit logging
8. Configure Kubernetes authentication
9. Enable KV v2 secrets engine

**Important**: Save the recovery keys and root token securely, then delete `vault-keys.json`.

### 3. Verify Initialization

```bash
# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# Expected output:
# Initialized: true
# Sealed: false
# HA Enabled: true
# HA Cluster: https://vault-0.vault-internal:8201

# List Raft peers
kubectl exec -n vault vault-0 -- vault operator raft list-peers
```

Expected output:
```
Node       Address                        State     Voter
----       -------                        -----     -----
vault-0    vault-0.vault-internal:8201    leader    true
vault-1    vault-1.vault-internal:8201    follower  true
vault-2    vault-2.vault-internal:8201    follower  true
```

## Verification

### 1. Check ArgoCD Application

```bash
# Check sync status
kubectl get application vault -n argocd

# Detailed view
argocd app get vault
```

Expected:
- **Sync Status**: `Synced`
- **Health Status**: `Healthy`

### 2. Verify All Pods Ready

```bash
kubectl get pods -n vault
```

Expected output:
```
NAME                                    READY   STATUS    RESTARTS   AGE
vault-0                                 1/1     Running   0          10m
vault-1                                 1/1     Running   0          10m
vault-2                                 1/1     Running   0          10m
vault-agent-injector-XXXXX-XXXXX        1/1     Running   0          10m
vault-agent-injector-XXXXX-XXXXX        1/1     Running   0          10m
```

### 3. Access Vault UI

```bash
# Port forward
kubectl port-forward -n vault svc/vault 8200:8200

# Open browser
open http://localhost:8200
```

Login with the root token from initialization.

## Post-Installation

### 1. Configure Kubernetes Auth

```bash
# Set Vault address
export VAULT_ADDR=http://localhost:8200

# Login with root token
vault login <root-token>

# Verify Kubernetes auth is enabled
vault auth list
```

### 2. Create Example Policy

```bash
# Create policy for application
vault policy write webapp-policy - <<EOF
path "secret/data/webapp/*" {
  capabilities = ["read"]
}
EOF

# Create Kubernetes role
vault write auth/kubernetes/role/webapp \
  bound_service_account_names=webapp \
  bound_service_account_namespaces=default \
  policies=webapp-policy \
  ttl=24h
```

### 3. Store Example Secret

```bash
# Write secret
vault kv put secret/webapp/config \
  db_username=admin \
  db_password=changeme
```

### 4. Test Secret Injection

Create test pod with annotation:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-test
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "webapp"
    vault.hashicorp.com/agent-inject-secret-config: "secret/data/webapp/config"
spec:
  serviceAccountName: webapp
  containers:
  - name: app
    image: nginx:alpine
    command: ["sleep", "3600"]
```

## Troubleshooting

### Issue 1: Pods Not Ready

**Symptom**: Vault pods show `0/1 Ready`

**Causes**:
- Vault not initialized
- Vault sealed
- KMS auto-unseal not working

**Solution**:
```bash
# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# If not initialized, run:
./scripts/vault-init.sh

# If sealed, check KMS permissions:
kubectl logs -n vault vault-0
```

### Issue 2: OutOfSync MutatingWebhookConfiguration

**Symptom**: ArgoCD shows `vault-agent-injector-cfg` as OutOfSync

**Cause**: Kubernetes dynamically manages the `caBundle` field

**Solution**: Already fixed in `argocd/apps/vault.yaml` with `ignoreDifferences`

### Issue 3: KMS Access Denied

**Symptom**: Logs show "Error making API request" for KMS

**Causes**:
- IAM role not attached to service account
- IAM policy doesn't allow KMS operations
- IRSA not configured correctly

**Solution**:
```bash
# Verify service account annotation
kubectl get sa vault-server -n vault -o yaml

# Should show:
# annotations:
#   eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/VaultKMSUnsealRole

# Test KMS access from pod
kubectl exec -n vault vault-0 -- sh -c '
  aws kms describe-key --key-id alias/vault-kms-key --region us-west-2
'
```

### Issue 4: Raft Cluster Not Forming

**Symptom**: Only vault-0 shows as peer

**Solution**:
```bash
# Manually join peers
kubectl exec -n vault vault-1 -- \
  vault operator raft join http://vault-0.vault-internal:8200

kubectl exec -n vault vault-2 -- \
  vault operator raft join http://vault-0.vault-internal:8200

# Verify
kubectl exec -n vault vault-0 -- vault operator raft list-peers
```

### Issue 5: StatefulSet Stuck at 0/3

**Symptom**: StatefulSet shows `0/3` ready replicas

**Cause**: Pods are waiting for initialization

**Solution**: This is expected. Run initialization script:
```bash
./scripts/vault-init.sh
```

## Commands Reference

### Vault Operations

```bash
# Check status
kubectl exec -n vault vault-0 -- vault status

# List Raft peers
kubectl exec -n vault vault-0 -- vault operator raft list-peers

# View audit log
kubectl exec -n vault vault-0 -- cat /vault/audit/audit.log | tail -n 20

# Backup Raft data
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/backup.snap
kubectl cp vault/vault-0:/tmp/backup.snap ./vault-backup-$(date +%Y%m%d).snap
```

### ArgoCD Operations

```bash
# Sync application
argocd app sync vault

# Refresh application
argocd app get vault --refresh

# View diff
argocd app diff vault

# Set to manual sync
argocd app set vault --sync-policy none
```

### Debugging

```bash
# Pod logs
kubectl logs -n vault vault-0 -f

# Describe pod
kubectl describe pod -n vault vault-0

# Events
kubectl get events -n vault --sort-by='.lastTimestamp'

# Exec into pod
kubectl exec -n vault vault-0 -it -- sh
```

## Backup and Recovery

### Automated Snapshots

Consider setting up automated Raft snapshots:

```bash
# Create CronJob for daily backups
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: vault-backup
  namespace: vault
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: vault-server
          containers:
          - name: backup
            image: hashicorp/vault:1.17.0
            env:
            - name: VAULT_ADDR
              value: "http://vault:8200"
            command:
            - /bin/sh
            - -c
            - |
              vault operator raft snapshot save /tmp/vault-backup-\$(date +%Y%m%d).snap
              # Upload to S3 or backup location
          restartPolicy: OnFailure
EOF
```

## Security Best Practices

1. **Root Token**: Revoke after initial setup
2. **Recovery Keys**: Store in secure location (e.g., AWS Secrets Manager)
3. **TLS**: Enable TLS in production (currently disabled for testing)
4. **Network Policies**: Restrict access to Vault pods
5. **Audit Logs**: Monitor and ship to centralized logging
6. **Regular Backups**: Automate Raft snapshots
7. **Rotation**: Regularly rotate KMS keys and credentials

## Additional Resources

- [Vault Documentation](https://www.vaultproject.io/docs)
- [Vault on Kubernetes Guide](https://learn.hashicorp.com/tutorials/vault/kubernetes-raft-deployment-guide)
- [Vault Helm Chart](https://github.com/hashicorp/vault-helm)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
