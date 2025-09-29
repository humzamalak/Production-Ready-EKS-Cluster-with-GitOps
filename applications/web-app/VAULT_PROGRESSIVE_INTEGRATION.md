# Progressive Vault Integration Guide

This guide explains the progressive Vault integration approach used in the web application deployment to avoid YAML parsing errors and ensure reliable GitOps deployment.

## 🎯 Overview

The web application supports two deployment phases:

1. **Phase 1**: Deploy without Vault integration (using Kubernetes secrets)
2. **Phase 2**: Enable Vault integration after Vault is fully configured

## 📁 File Structure

```
applications/web-app/k8s-web-app/
├── values.yaml                    # Phase 1: Vault disabled, K8s secrets
├── values-vault-enabled.yaml      # Phase 2: Vault enabled override
├── values-local.yaml             # Local development values
└── helm/templates/
    ├── deployment.yaml           # Conditional Vault integration
    └── vault-agent.yaml         # Vault agent templates
```

## 🔄 Phase 1: Initial Deployment (Vault Disabled)

### Configuration
- `vault.enabled: false`
- `vault.ready: false`
- Uses Kubernetes secrets via `secretRefs`

### Deployment
```bash
# Deploy with default values (Vault disabled)
kubectl apply -f clusters/production/app-of-apps.yaml
```

### Expected Outcome
- ✅ Web application deploys successfully
- ✅ Uses Kubernetes secrets for configuration
- ✅ No Vault dependencies
- ✅ All health checks passing

## 🔄 Phase 2: Enable Vault Integration

### Prerequisites
- Vault deployed and initialized (Wave 3.5)
- Vault policies and roles configured
- Sample secrets created in Vault

### Configuration Update
```bash
# Update ArgoCD application to use vault-enabled values
kubectl patch application k8s-web-app -n argocd --type merge -p '
{
  "spec": {
    "source": {
      "helm": {
        "valueFiles": ["values.yaml", "values-vault-enabled.yaml"]
      }
    }
  }
}'
```

### Expected Outcome
- ✅ Web application migrates to Vault secrets
- ✅ Vault agent injection working
- ✅ Zero-downtime migration
- ✅ Environment variables from Vault

## 🔧 Template Logic

### Conditional Vault Integration

The deployment template uses conditional logic to handle both phases:

```yaml
# Only enable Vault when both enabled AND ready
{{- if and .Values.vault.enabled .Values.vault.ready }}

# Vault annotations
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: {{ .Values.vault.role }}
  # ... other Vault annotations

# Vault readiness check
initContainers:
- name: vault-wait
  image: busybox:1.35
  command: ['sh', '-c']
  args:
  - |
    until nc -z vault.vault.svc.cluster.local 8200; do
      echo "Vault not ready, waiting..."
      sleep 5
    done

{{- else }}

# Fallback to Kubernetes secrets
annotations:
  {{- with .Values.podAnnotations }}
  {{- toYaml . | nindent 2 }}
  {{- end }}

{{- end }}
```

## 🛠️ Troubleshooting

### Phase 1 Issues

#### Web App Not Deploying
```bash
# Check application status
kubectl get applications -n argocd | grep web-app

# Check deployment logs
kubectl logs -n production deployment/k8s-web-app

# Verify Kubernetes secrets exist
kubectl get secrets -n production | grep web-app
```

#### Kubernetes Secrets Missing
```bash
# Create sample secrets for testing
kubectl create secret generic web-app-db-secret -n production \
  --from-literal=DB_HOST=localhost \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=webapp \
  --from-literal=DB_USERNAME=user \
  --from-literal=DB_PASSWORD=password
```

### Phase 2 Issues

#### Vault Integration Failing
```bash
# Check Vault connectivity
kubectl exec -n production deployment/k8s-web-app -- nc -z vault.vault.svc.cluster.local 8200

# Check Vault status
kubectl port-forward svc/vault -n vault 8200:8200 &
vault status

# Check Vault logs
kubectl logs -n production deployment/k8s-web-app | grep -i vault
```

#### Vault Secrets Not Injected
```bash
# Check Vault agent logs
kubectl logs -n production deployment/k8s-web-app -c vault-agent

# Verify secrets exist in Vault
vault kv list secret/production/web-app/

# Check environment variables
kubectl exec -n production deployment/k8s-web-app -- env | grep DB_
```

### Recovery Procedures

#### Revert to Phase 1
```bash
# Remove vault-enabled values
kubectl patch application k8s-web-app -n argocd --type merge -p '
{
  "spec": {
    "source": {
      "helm": {
        "valueFiles": ["values.yaml"]
      }
    }
  }
}'
```

#### Fix Vault Configuration
```bash
# Check Vault initialization job
kubectl get jobs -n vault
kubectl logs job/vault-init -n vault

# Re-run Vault initialization
kubectl delete job vault-init -n vault
kubectl apply -f applications/security/vault/init-job.yaml
```

## 📊 Verification Commands

### Phase 1 Verification
```bash
# Check application is running
kubectl get pods -n production

# Verify K8s secrets are used
kubectl exec -n production deployment/k8s-web-app -- env | grep DB_

# Check application logs
kubectl logs -n production deployment/k8s-web-app | grep -i "database\|secret"
```

### Phase 2 Verification
```bash
# Check Vault agent is running
kubectl exec -n production deployment/k8s-web-app -- ps aux | grep vault

# Verify Vault secrets are injected
kubectl exec -n production deployment/k8s-web-app -- env | grep DB_

# Check Vault agent logs
kubectl logs -n production deployment/k8s-web-app -c vault-agent
```

## 🔗 Related Documentation

- [Wave-Based Deployment Guide](../../WAVE_BASED_DEPLOYMENT_GUIDE.md)
- [Vault Setup Guide](../../docs/VAULT_SETUP_GUIDE.md)
- [Security Best Practices](../../docs/security-best-practices.md)
- [Troubleshooting Guide](../../TROUBLESHOOTING.md)
