#!/bin/bash

# Vault Setup Script for Web App
# This script configures Vault policies and secrets for the k8s-web-app

set -e

# Configuration
VAULT_NAMESPACE="vault"
VAULT_ADDR="http://vault.vault.svc.cluster.local:8200"
ROOT_TOKEN="root"  # In production, use proper token management

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Vault is accessible
check_vault() {
    print_status "Checking Vault connectivity..."
    
    if ! kubectl get pods -n $VAULT_NAMESPACE | grep -q "vault.*Running"; then
        print_error "Vault is not running in namespace $VAULT_NAMESPACE"
        return 1
    fi
    
    # Port forward to Vault
    print_status "Setting up port forward to Vault..."
    kubectl port-forward -n $VAULT_NAMESPACE svc/vault 8200:8200 &
    PORT_FORWARD_PID=$!
    sleep 5
    
    # Set Vault address
    export VAULT_ADDR="http://localhost:8200"
    
    # Check if Vault is accessible
    if ! vault status >/dev/null 2>&1; then
        print_error "Cannot connect to Vault at $VAULT_ADDR"
        kill $PORT_FORWARD_PID 2>/dev/null || true
        return 1
    fi
    
    print_status "Vault is accessible"
}

# Function to authenticate with Vault
authenticate_vault() {
    print_status "Authenticating with Vault..."
    
    # In production, use proper authentication method
    # For now, using root token (development only)
    vault auth $ROOT_TOKEN
    
    if [ $? -eq 0 ]; then
        print_status "Successfully authenticated with Vault"
    else
        print_error "Failed to authenticate with Vault"
        return 1
    fi
}

# Function to create web app policy
create_web_app_policy() {
    print_status "Creating web app Vault policy..."
    
    vault policy write k8s-web-app - <<EOF
# Allow read access to web app database secrets
path "secret/data/production/web-app/db" {
  capabilities = ["read"]
}

# Allow read access to web app API secrets
path "secret/data/production/web-app/api" {
  capabilities = ["read"]
}

# Allow read access to web app external service secrets
path "secret/data/production/web-app/external" {
  capabilities = ["read"]
}

# Allow read access to secret metadata
path "secret/metadata/production/web-app/*" {
  capabilities = ["read", "list"]
}

# Allow list access to web app secret paths
path "secret/production/web-app/*" {
  capabilities = ["list"]
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

    if [ $? -eq 0 ]; then
        print_status "Web app policy created successfully"
    else
        print_error "Failed to create web app policy"
        return 1
    fi
}

# Function to create Kubernetes role
create_kubernetes_role() {
    print_status "Creating Kubernetes role for web app..."
    
    vault write auth/kubernetes/role/k8s-web-app \
        bound_service_account_names=k8s-web-app \
        bound_service_account_namespaces=production \
        policies=k8s-web-app \
        ttl=1h \
        max_ttl=24h
    
    if [ $? -eq 0 ]; then
        print_status "Kubernetes role created successfully"
    else
        print_error "Failed to create Kubernetes role"
        return 1
    fi
}

# Function to create web app secrets
create_web_app_secrets() {
    print_status "Creating web app secrets in Vault..."
    
    # Database secrets
    print_status "Creating database secrets..."
    vault kv put secret/production/web-app/db \
        host="your-production-db-host.amazonaws.com" \
        port="5432" \
        name="k8s_web_app_prod" \
        username="k8s_web_app_user" \
        password="$(openssl rand -base64 32)"
    
    # API secrets
    print_status "Creating API secrets..."
    vault kv put secret/production/web-app/api \
        jwt_secret="$(openssl rand -base64 64)" \
        encryption_key="$(openssl rand -base64 32)" \
        api_key="$(openssl rand -base64 32)"
    
    # External services secrets
    print_status "Creating external services secrets..."
    vault kv put secret/production/web-app/external \
        smtp_host="smtp.your-provider.com" \
        smtp_port="587" \
        smtp_username="your-smtp-username" \
        smtp_password="your-smtp-password" \
        redis_url="redis://your-redis-host:6379"
    
    print_status "Web app secrets created successfully"
}

# Function to verify secrets
verify_secrets() {
    print_status "Verifying secrets..."
    
    # Check database secrets
    if vault kv get secret/production/web-app/db >/dev/null 2>&1; then
        print_status "Database secrets verified"
    else
        print_error "Database secrets verification failed"
        return 1
    fi
    
    # Check API secrets
    if vault kv get secret/production/web-app/api >/dev/null 2>&1; then
        print_status "API secrets verified"
    else
        print_error "API secrets verification failed"
        return 1
    fi
    
    # Check external services secrets
    if vault kv get secret/production/web-app/external >/dev/null 2>&1; then
        print_status "External services secrets verified"
    else
        print_error "External services secrets verification failed"
        return 1
    fi
    
    print_status "All secrets verified successfully"
}

# Function to display secret information
display_secret_info() {
    print_status "Secret Information:"
    echo ""
    echo "Database Secrets:"
    vault kv get -field=host secret/production/web-app/db
    vault kv get -field=port secret/production/web-app/db
    vault kv get -field=name secret/production/web-app/db
    vault kv get -field=username secret/production/web-app/db
    echo "Password: [HIDDEN]"
    echo ""
    echo "API Secrets:"
    echo "JWT Secret: [HIDDEN]"
    echo "Encryption Key: [HIDDEN]"
    echo "API Key: [HIDDEN]"
    echo ""
    echo "External Services Secrets:"
    vault kv get -field=smtp_host secret/production/web-app/external
    vault kv get -field=smtp_port secret/production/web-app/external
    vault kv get -field=smtp_username secret/production/web-app/external
    echo "SMTP Password: [HIDDEN]"
    vault kv get -field=redis_url secret/production/web-app/external
}

# Main execution
main() {
    print_status "Starting Vault setup for k8s-web-app..."
    
    # Check prerequisites
    if ! command -v vault &> /dev/null; then
        print_error "Vault CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Setup Vault
    check_vault || exit 1
    authenticate_vault || exit 1
    create_web_app_policy || exit 1
    create_kubernetes_role || exit 1
    create_web_app_secrets || exit 1
    verify_secrets || exit 1
    
    # Display information
    display_secret_info
    
    # Cleanup
    kill $PORT_FORWARD_PID 2>/dev/null || true
    
    print_status "Vault setup completed successfully!"
    print_warning "Remember to update the secret values with your actual production values!"
}

# Run main function
main "$@"
