# Web Application Stack

This directory contains the ArgoCD applications and Helm charts for deploying web applications to the production EKS cluster.

## Structure

```
web-app/
├── namespace.yaml                # Production namespace definition
└── k8s-web-app/                 # Node.js web application
    ├── application.yaml          # ArgoCD Application manifest
    ├── values.yaml              # Production Helm values
    ├── values-local.yaml        # Local development values
    ├── values-vault-enabled.yaml # Vault integration override
    └── helm/                    # Helm chart
        ├── Chart.yaml
        ├── values.yaml          # Default Helm chart values
        └── templates/
            ├── deployment.yaml
            ├── service.yaml
            ├── ingress.yaml
            ├── hpa.yaml
            ├── serviceaccount.yaml
            ├── networkpolicy.yaml
            └── servicemonitor.yaml
```

## Applications

### K8s Web App

A production-ready Node.js web application with the following features:

- **High Availability**: 3 replicas with anti-affinity rules
- **Auto-scaling**: HPA based on CPU and memory usage
- **Security**: Network policies, non-root containers, read-only filesystem
- **Monitoring**: Prometheus metrics and ServiceMonitor
- **Ingress**: NGINX ingress with SSL/TLS and rate limiting
- **Health Checks**: Liveness and readiness probes

## Configuration

### Prerequisites

1. **Domain**: Update the ingress host in `values.yaml`:
   ```yaml
   ingress:
     hosts:
       - host: k8s-web-app.yourdomain.com  # Update this
   ```

2. **Vault Setup**: The application uses Vault for secret management:
   ```bash
   # Install Vault CLI (if not already installed)
   brew tap hashicorp/tap
   brew install hashicorp/tap/vault
   
   # Deploy Vault with agent injector
   helm repo add hashicorp https://helm.releases.hashicorp.com
   helm repo update
   helm install vault hashicorp/vault -n vault --create-namespace \
     --set "server.dev.enabled=true" \
     --set "server.dev.devRootToken=root" \
     --set "injector.enabled=true"
   
   # Wait for Vault to be ready
   kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault --timeout=300s
   
   # Configure Vault for web app integration
   kubectl port-forward -n vault svc/vault 8200:8200 &
   export VAULT_ADDR="http://localhost:8200"
   export VAULT_TOKEN="root"
   
   # Enable secrets engine and authentication
   vault secrets enable -path=secret kv-v2
   vault auth enable kubernetes
   vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc.cluster.local"
   
   # Create policy and role
   vault policy write k8s-web-app - <<EOF
   path "secret/data/production/web-app/*" { capabilities = ["read"] }
   path "secret/metadata/production/web-app/*" { capabilities = ["read", "list"] }
   path "auth/kubernetes/login" { capabilities = ["create", "update"] }
   path "auth/token/renew-self" { capabilities = ["update"] }
   EOF
   
   vault write auth/kubernetes/role/k8s-web-app \
     bound_service_account_names=k8s-web-app \
     bound_service_account_namespaces=production \
     policies=k8s-web-app ttl=1h max_ttl=24h
   ```

3. **Vault Secrets**: Update the secrets in Vault with your actual values:
   ```bash
   # Database secrets
   vault kv put secret/production/web-app/db \
     host="your-production-db-host.amazonaws.com" \
     port="5432" \
     name="k8s_web_app_prod" \
     username="k8s_web_app_user" \
     password="your-secure-password"

   # API secrets
   vault kv put secret/production/web-app/api \
     jwt_secret="your-jwt-secret" \
     encryption_key="your-encryption-key" \
     api_key="your-api-key"

   # External services secrets
   vault kv put secret/production/web-app/external \
     smtp_host="smtp.your-provider.com" \
     smtp_port="587" \
     smtp_username="your-smtp-username" \
     smtp_password="your-smtp-password" \
     redis_url="redis://your-redis-host:6379"
   ```

4. **IRSA Role**: Update the service account annotation in `values.yaml`:
   ```yaml
   serviceAccount:
     annotations:
       eks.amazonaws.com/role-arn: arn:aws:iam::YOUR_ACCOUNT_ID:role/k8s-web-app-irsa-role
   ```

### Customization

The application can be customized by modifying the `values.yaml` file:

- **Replica Count**: Adjust `replicaCount` for initial replicas
- **Resources**: Modify CPU/memory limits and requests
- **Auto-scaling**: Configure HPA parameters
- **Environment Variables**: Add/modify environment variables
- **Health Checks**: Customize probe settings
- **Network Policies**: Configure network security rules

## Deployment

The web application is automatically deployed when ArgoCD syncs the applications. The sync order is:

1. Namespace creation (sync-wave: "0")
2. Web app deployment (sync-wave: "1")

## Monitoring

The application includes:

- **Prometheus Metrics**: Available at `/metrics` endpoint
- **ServiceMonitor**: Automatically scrapes metrics
- **Health Endpoints**: `/health` and `/ready` for monitoring

## Security

Security features include:

- **Network Policies**: Restrict ingress/egress traffic
- **Pod Security Context**: Non-root user, read-only filesystem
- **Security Context**: Drop all capabilities
- **IRSA**: IAM roles for service accounts
- **Vault Integration**: Secure secret management with automatic injection
- **Secret Encryption**: All secrets encrypted at rest and in transit
- **RBAC**: Role-based access control for Vault secrets

## Vault Integration

The web application is integrated with HashiCorp Vault for secure secret management:

### Features

- **Automatic Secret Injection**: Secrets are automatically injected into pods
- **Kubernetes Authentication**: Uses Kubernetes service account tokens
- **Policy-based Access**: Granular access control to secrets
- **Secret Templates**: Customizable secret formatting
- **Token Renewal**: Automatic token refresh and renewal

### Secret Paths

The application accesses secrets from the following Vault paths:

- `secret/data/production/web-app/db` - Database credentials
- `secret/data/production/web-app/api` - API keys and JWT secrets
- `secret/data/production/web-app/external` - External service credentials

### Vault Agent

The Vault agent runs as a sidecar container and:

- Authenticates using Kubernetes service account
- Fetches secrets from Vault
- Renders secrets using templates
- Injects secrets as environment variables
- Handles token renewal automatically

## Troubleshooting

### Common Issues

1. **Image Pull Errors**: Ensure the Docker image is accessible
2. **Health Check Failures**: Verify the application responds to `/health` and `/ready`
3. **Ingress Issues**: Check NGINX ingress controller and cert-manager
4. **Vault Authentication Issues**: 
   - Verify Vault is running: `kubectl get pods -n vault`
   - Check Vault status: `kubectl port-forward -n vault svc/vault 8200:8200 & vault status`
   - Verify Kubernetes auth is enabled: `vault auth list`
   - Check service account permissions: `kubectl get sa k8s-web-app -n production -o yaml`
   - Ensure Vault policy and role are configured: `vault read auth/kubernetes/role/k8s-web-app`
5. **Secret Injection Issues**:
   - Check Vault agent injector: `kubectl get pods -n vault -l app.kubernetes.io/name=vault-agent-injector`
   - Verify webhook is configured: `kubectl get mutatingwebhookconfigurations | grep vault`
   - Check pod annotations: `kubectl get pod <pod-name> -n production -o yaml | grep vault`
   - Verify secrets exist: `vault kv list secret/production/web-app/`
   - Check injected secrets: `kubectl get secrets -n production | grep vault-secret`

### Logs

```bash
# View application logs
kubectl logs -f deployment/k8s-web-app -n production

# View Vault agent logs
kubectl logs -f deployment/k8s-web-app -c vault-agent -n production

# View ArgoCD application status
kubectl get application k8s-web-app -n argocd

# View all resources
kubectl get all -n production -l app.kubernetes.io/name=k8s-web-app

# Check Vault secrets
vault kv list secret/production/web-app/
vault kv get secret/production/web-app/db

# Verify Vault authentication
vault auth -method=kubernetes role=k8s-web-app
```
