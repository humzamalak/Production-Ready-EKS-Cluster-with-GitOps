# Vault Setup Guide

This guide provides comprehensive instructions for setting up HashiCorp Vault with agent injection for secure secret management in your GitOps environment.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Web App Integration](#web-app-integration)
6. [Validation](#validation)
7. [Troubleshooting](#troubleshooting)
8. [Production Considerations](#production-considerations)

## Overview

This setup provides:

- **Vault Server**: HashiCorp Vault for secure secret storage
- **Agent Injector**: Automatic secret injection into application pods
- **Kubernetes Authentication**: Secure authentication using service accounts
- **Policy-based Access**: Fine-grained permissions for different applications
- **Secret Templates**: Customizable secret formatting and rendering

## Prerequisites

### Required Tools

- **kubectl** (v1.31+) - Kubernetes CLI
- **Helm** (v3.18+) - Package manager
- **Vault CLI** (v1.16+) - HashiCorp Vault CLI
- **openssl** - For generating random secrets

### Install Vault CLI

**macOS (using Homebrew)**:
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/vault
```

**Linux**:
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault
```

**Windows (using Chocolatey)**:
```bash
choco install vault
```

## Installation

### 1. Add HashiCorp Helm Repository

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
```

### 2. Deploy Vault with Agent Injector

**Development Mode (Recommended for testing)**:
```bash
helm install vault hashicorp/vault -n vault --create-namespace \
  --set "server.dev.enabled=true" \
  --set "server.dev.devRootToken=root" \
  --set "injector.enabled=true"
```

**Production Mode**:
```bash
helm install vault hashicorp/vault -n vault --create-namespace \
  -f applications/security/vault/values.yaml
```

### 3. Wait for Vault to be Ready

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault-agent-injector -n vault --timeout=300s
```

### 4. Verify Deployment

```bash
kubectl get pods -n vault
kubectl get svc -n vault
```

Expected output:
```
NAME                                    READY   STATUS    RESTARTS   AGE
vault-0                                 1/1     Running   0          2m
vault-agent-injector-556c5dd8fb-g2slf   1/1     Running   0          2m
```

## Configuration

### 1. Set Up Port Forwarding

```bash
kubectl port-forward -n vault svc/vault 8200:8200 &
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="root"  # Development mode only
```

### 2. Verify Vault Status

```bash
vault status
```

Expected output:
```
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.20.4
Storage Type    inmem
HA Enabled      false
```

### 3. Enable KV v2 Secrets Engine

```bash
vault secrets enable -path=secret kv-v2
```

### 4. Enable Kubernetes Authentication

```bash
vault auth enable kubernetes
vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc.cluster.local"
```

### 5. Create Web App Policy

```bash
vault policy write k8s-web-app - <<EOF
# Allow read access to web app secrets
path "secret/data/production/web-app/*" {
  capabilities = ["read"]
}

# Allow read access to secret metadata
path "secret/metadata/production/web-app/*" {
  capabilities = ["read", "list"]
}

# Allow authentication via Kubernetes
path "auth/kubernetes/login" {
  capabilities = ["create", "update"]
}

# Allow token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Allow token lookup
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF
```

### 6. Create Kubernetes Role

```bash
vault write auth/kubernetes/role/k8s-web-app \
  bound_service_account_names=k8s-web-app \
  bound_service_account_namespaces=production \
  policies=k8s-web-app \
  ttl=1h \
  max_ttl=24h
```

## Web App Integration

### 1. Create Sample Secrets

**Database Secrets** (using environment variables for security):
```bash
# Set environment variables for production values
export DB_HOST="${DB_HOST:-your-production-db.amazonaws.com}"
export DB_PORT="${DB_PORT:-5432}"
export DB_NAME="${DB_NAME:-k8s_web_app_prod}"
export DB_USERNAME="${DB_USERNAME:-k8s_web_app_user}"
export DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -base64 32)}"

vault kv put secret/production/web-app/db \
  host="$DB_HOST" \
  port="$DB_PORT" \
  name="$DB_NAME" \
  username="$DB_USERNAME" \
  password="$DB_PASSWORD"
```

**API Secrets** (generate random values for demo):
```bash
export JWT_SECRET="${JWT_SECRET:-$(openssl rand -base64 64)}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY:-$(openssl rand -base64 32)}"
export API_KEY="${API_KEY:-$(openssl rand -base64 32)}"

vault kv put secret/production/web-app/api \
  jwt_secret="$JWT_SECRET" \
  encryption_key="$ENCRYPTION_KEY" \
  api_key="$API_KEY"
```

**External Services Secrets** (using environment variables):
```bash
export SMTP_HOST="${SMTP_HOST:-smtp.your-provider.com}"
export SMTP_PORT="${SMTP_PORT:-587}"
export SMTP_USERNAME="${SMTP_USERNAME:-your-smtp-username}"
export SMTP_PASSWORD="${SMTP_PASSWORD:-your-smtp-password}"
export REDIS_URL="${REDIS_URL:-redis://your-redis-host:6379}"

vault kv put secret/production/web-app/external \
  smtp_host="$SMTP_HOST" \
  smtp_port="$SMTP_PORT" \
  smtp_username="$SMTP_USERNAME" \
  smtp_password="$SMTP_PASSWORD" \
  redis_url="$REDIS_URL"
```

### 2. Verify Secrets

```bash
vault kv list secret/production/web-app/
vault kv get secret/production/web-app/db
```

### 3. Deploy Web App

```bash
kubectl apply -f applications/web-app/
```

## Validation

### 1. Run Validation Script

```bash
cd applications/web-app/k8s-web-app
./validate-vault.sh
```

### 2. Manual Verification

**Check Vault Agent Injector**:
```bash
kubectl get pods -n vault -l app.kubernetes.io/name=vault-agent-injector
kubectl get mutatingwebhookconfigurations | grep vault
```

**Check Web App Pods**:
```bash
kubectl get pods -n production -l app.kubernetes.io/name=k8s-web-app
kubectl get pod <pod-name> -n production -o yaml | grep vault
```

**Check Injected Secrets**:
```bash
kubectl get secrets -n production | grep vault-secret
kubectl exec -it deployment/k8s-web-app -n production -- env | grep -E "(DB_|JWT_|API_)"
```

## Troubleshooting

### Common Issues

#### 1. Vault Pod Not Starting

**Symptoms**: Vault pod in CrashLoopBackOff or Pending state

**Solutions**:
```bash
# Check pod logs
kubectl logs vault-0 -n vault

# Check resource constraints
kubectl describe pod vault-0 -n vault

# Check if port 8200 is in use
kubectl get svc -n vault
```

#### 2. Agent Injector Not Working

**Symptoms**: Secrets not being injected into application pods

**Solutions**:
```bash
# Check injector logs
kubectl logs -n vault deployment/vault-agent-injector

# Verify webhook configuration
kubectl get mutatingwebhookconfigurations vault-agent-injector-cfg

# Check pod annotations
kubectl get pod <pod-name> -n production -o yaml | grep vault
```

#### 3. Authentication Failures

**Symptoms**: Vault authentication errors in logs

**Solutions**:
```bash
# Check service account
kubectl get sa k8s-web-app -n production -o yaml

# Verify Vault role
vault read auth/kubernetes/role/k8s-web-app

# Test authentication manually
vault write auth/kubernetes/login role=k8s-web-app jwt=$(kubectl get sa k8s-web-app -n production -o jsonpath='{.secrets[0].name}' | xargs kubectl get secret -n production -o jsonpath='{.data.token}' | base64 -d)
```

#### 4. Secret Injection Issues

**Symptoms**: Secrets not appearing in pod environment

**Solutions**:
```bash
# Check Vault agent logs in pod
kubectl logs <pod-name> -c vault-agent -n production

# Verify secrets exist in Vault
vault kv list secret/production/web-app/

# Check secret templates
kubectl get pod <pod-name> -n production -o yaml | grep -A 10 vault.hashicorp.com/agent-inject-template
```

### Debug Commands

```bash
# Vault status and configuration
vault status
vault auth list
vault secrets list
vault policy list

# Kubernetes resources
kubectl get all -n vault
kubectl get all -n production
kubectl get secrets -n production | grep vault

# Pod inspection
kubectl describe pod <pod-name> -n production
kubectl logs <pod-name> -c vault-agent -n production
```

## Production Considerations

### 1. High Availability

For production, configure Vault in HA mode:

```bash
helm upgrade vault hashicorp/vault -n vault \
  --set "server.ha.enabled=true" \
  --set "server.ha.replicas=3" \
  --set "server.ha.raft.enabled=true"
```

### 2. External Storage

Configure external storage (e.g., AWS S3, Azure Blob, etc.):

```yaml
server:
  ha:
    enabled: true
    raft:
      enabled: true
      config: |
        storage "raft" {
          path = "/vault/data"
          retry_join {
            auto_join = "provider=aws region=us-west-2 tag_key=vault tag_value=server"
          }
        }
```

### 3. TLS Configuration

Enable TLS for production:

```bash
helm upgrade vault hashicorp/vault -n vault \
  --set "global.tlsDisable=false" \
  --set "server.ingress.enabled=true" \
  --set "server.ingress.tls[0].secretName=vault-tls"
```

### 4. Backup Strategy

Implement regular backups:

```bash
# Create backup
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/vault-backup.snap

# Copy backup
kubectl cp vault/vault-0:/tmp/vault-backup.snap ./vault-backup-$(date +%Y%m%d).snap
```

### 5. Monitoring

Set up monitoring for Vault:

```bash
# Enable Prometheus metrics
vault write sys/config/ui headers='{"X-Vault-Monitor": "true"}'

# Configure monitoring in Grafana
# Import Vault dashboard: https://grafana.com/grafana/dashboards/11007
```

### 6. Security Hardening

- Use strong, unique root tokens
- Implement proper RBAC policies
- Enable audit logging
- Regular security updates
- Network segmentation
- Encryption at rest and in transit

## References

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Vault Agent Injector](https://www.vaultproject.io/docs/platform/k8s/injector)
- [Kubernetes Authentication](https://www.vaultproject.io/docs/auth/kubernetes)
- [Vault Helm Chart](https://github.com/hashicorp/vault-helm)
- [Production Hardening](https://www.vaultproject.io/docs/guides/production)
