# Vault Integration Guide

This document provides a comprehensive guide to the Vault integration for the k8s-web-app deployment.

## Overview

The web application is integrated with HashiCorp Vault for secure secret management using Vault Agent Injection. This provides:

- **Automatic Secret Injection**: Secrets are automatically injected into application pods
- **Kubernetes Authentication**: Uses Kubernetes service account tokens for authentication
- **Policy-based Access Control**: Granular access control to secrets
- **Secret Templates**: Customizable secret formatting and rendering
- **Token Renewal**: Automatic token refresh and renewal

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web App Pod   │    │  Vault Agent    │    │  HashiCorp      │
│                 │    │   (Sidecar)     │    │     Vault       │
│  ┌───────────┐  │    │                 │    │                 │
│  │   App     │  │◄───┤  ┌───────────┐  │◄───┤  ┌───────────┐  │
│  │ Container │  │    │  │Secret     │  │    │  │   KV v2   │  │
│  └───────────┘  │    │  │Templates  │  │    │  │  Secrets  │  │
│                 │    │  └───────────┘  │    │  └───────────┘  │
│  ┌───────────┐  │    │                 │    │                 │
│  │ Vault     │  │◄───┤  ┌───────────┐  │    │  ┌───────────┐  │
│  │ Secrets   │  │    │  │ Kubernetes│  │◄───┤  │ Kubernetes│  │
│  │(Env Vars) │  │    │  │    Auth   │  │    │  │    Auth   │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Components

### 1. Vault Agent Injector

The Vault Agent Injector is deployed as part of the Vault Helm chart and provides:

- **Webhook Controller**: Intercepts pod creation events
- **Secret Injection**: Automatically injects Vault agent sidecar containers
- **Template Rendering**: Processes secret templates and creates Kubernetes secrets

### 2. Vault Agent (Sidecar)

The Vault Agent runs as a sidecar container in each web app pod and:

- **Authenticates**: Uses Kubernetes service account token
- **Fetches Secrets**: Retrieves secrets from Vault
- **Renders Templates**: Processes secret templates
- **Creates Secrets**: Generates Kubernetes secrets for the application
- **Renews Tokens**: Automatically refreshes authentication tokens

### 3. Vault Policies

The following Vault policies control access to secrets:

- **`k8s-web-app`**: Policy for the web application
  - Read access to `secret/data/production/web-app/*`
  - List access to `secret/production/web-app/*`
  - Authentication and token renewal permissions

### 4. Kubernetes Role

The `k8s-web-app` role in Vault:

- **Bound Service Account**: `k8s-web-app` in `production` namespace
- **Policies**: Associates the `k8s-web-app` policy
- **TTL**: 1 hour token lifetime, 24 hour maximum

## Secret Paths

The application accesses secrets from these Vault paths:

### Database Secrets
- **Path**: `secret/data/production/web-app/db`
- **Keys**: `host`, `port`, `name`, `username`, `password`
- **Template**: Renders as environment variables

### API Secrets
- **Path**: `secret/data/production/web-app/api`
- **Keys**: `jwt_secret`, `encryption_key`, `api_key`
- **Template**: Renders as environment variables

### External Services
- **Path**: `secret/data/production/web-app/external`
- **Keys**: `smtp_host`, `smtp_port`, `smtp_username`, `smtp_password`, `redis_url`
- **Template**: Renders as environment variables

## Configuration

### Helm Values

The Vault integration is configured in `values.yaml`:

```yaml
vault:
  enabled: true
  address: "http://vault.vault.svc.cluster.local:8200"
  role: "k8s-web-app"
  authPath: "auth/kubernetes"
  secrets:
    - secretPath: "secret/data/production/web-app/db"
      mountPath: "/vault/secrets/db"
      template: |
        {{- with secret "secret/data/production/web-app/db" -}}
        DB_HOST={{ .Data.data.host }}
        DB_PORT={{ .Data.data.port }}
        # ... more variables
        {{- end }}
```

### Pod Annotations

Vault injection is controlled by pod annotations:

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "k8s-web-app"
  vault.hashicorp.com/agent-inject-secret-db: "secret/data/production/web-app/db"
  vault.hashicorp.com/agent-inject-template-db: |
    {{- with secret "secret/data/production/web-app/db" -}}
    DB_HOST={{ .Data.data.host }}
    # ... template content
    {{- end }}
```

## Setup Instructions

### 1. Deploy Vault

Ensure Vault is deployed with the agent injector enabled:

```bash
kubectl apply -f applications/security/vault/
```

### 2. Initialize Vault

Run the Vault setup script:

```bash
cd applications/web-app
./setup-vault-secrets.sh
```

This script will:
- Create Vault policies
- Set up Kubernetes authentication
- Create the `k8s-web-app` role
- Create sample secrets

### 3. Update Secrets

Replace sample secrets with actual values:

```bash
vault kv put secret/production/web-app/db \
  host="your-production-db.amazonaws.com" \
  port="5432" \
  name="your_database" \
  username="your_user" \
  password="your_password"
```

### 4. Deploy Web App

Deploy the web application:

```bash
kubectl apply -f applications/web-app/
```

## Monitoring and Troubleshooting

### Check Vault Agent Status

```bash
# View Vault agent logs
kubectl logs -f deployment/k8s-web-app -c vault-agent -n production

# Check injected secrets
kubectl get secrets -n production | grep vault-secret
```

### Verify Secret Injection

```bash
# Check pod annotations
kubectl get pod -n production -l app.kubernetes.io/name=k8s-web-app -o yaml | grep vault

# View environment variables
kubectl exec -it deployment/k8s-web-app -n production -- env | grep -E "(DB_|JWT_|API_)"
```

### Validate Vault Integration

Run the validation script:

```bash
cd applications/web-app/k8s-web-app
./validate-vault.sh
```

## Security Considerations

### 1. Service Account Permissions

The web app service account has minimal permissions:
- Only access to secrets in the production namespace
- No cluster-level permissions

### 2. Vault Policies

Policies follow the principle of least privilege:
- Read-only access to specific secret paths
- No write or delete permissions
- Limited token lifetime

### 3. Secret Encryption

- Secrets encrypted at rest in Vault
- Secrets encrypted in transit
- No secrets stored in Git or container images

### 4. Token Management

- Short-lived tokens (1 hour TTL)
- Automatic token renewal
- No long-term credentials stored

## Best Practices

### 1. Secret Rotation

Implement regular secret rotation:

```bash
# Rotate database password
vault kv put secret/production/web-app/db \
  password="new-secure-password"
```

### 2. Monitoring

Monitor Vault agent health:
- Set up alerts for authentication failures
- Monitor secret access patterns
- Track token renewal success rates

### 3. Backup

Ensure Vault data is backed up:
- Regular snapshots of Vault storage
- Backup of unseal keys
- Documented recovery procedures

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Check service account permissions
   - Verify Vault role configuration
   - Ensure Kubernetes auth is enabled

2. **Secret Injection Issues**
   - Check Vault agent injector logs
   - Verify pod annotations
   - Confirm secrets exist in Vault

3. **Template Rendering Errors**
   - Validate template syntax
   - Check secret key names
   - Verify Vault policy permissions

### Debug Commands

```bash
# Check Vault status
vault status

# List secrets
vault kv list secret/production/web-app/

# Test authentication
vault auth -method=kubernetes role=k8s-web-app

# View policies
vault policy read k8s-web-app
```

## Migration from Kubernetes Secrets

If migrating from Kubernetes secrets to Vault:

1. **Create Vault secrets** with the same data
2. **Update application configuration** to use Vault
3. **Deploy with Vault integration** enabled
4. **Verify secret injection** is working
5. **Remove old Kubernetes secrets**

## References

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Vault Agent Injector](https://www.vaultproject.io/docs/platform/k8s/injector)
- [Kubernetes Authentication](https://www.vaultproject.io/docs/auth/kubernetes)
- [Secret Templates](https://www.vaultproject.io/docs/agent/template)
