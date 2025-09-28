#!/bin/bash
# Vault Setup Script for EKS Cluster
# This script automates the initial setup of HashiCorp Vault

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
VAULT_NAMESPACE="vault"
VAULT_SERVICE="vault.vault.svc.cluster.local"
VAULT_PORT="8200"
VAULT_ADDR="https://${VAULT_SERVICE}:${VAULT_PORT}"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for Vault to be ready
wait_for_vault() {
    print_status "Waiting for Vault to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if kubectl get pods -n $VAULT_NAMESPACE -l app.kubernetes.io/name=vault | grep -q "Running"; then
            print_status "Vault is ready!"
            return 0
        fi
        
        print_status "Attempt $attempt/$max_attempts - Vault not ready yet, waiting..."
        sleep 10
        ((attempt++))
    done
    
    print_error "Vault failed to become ready after $max_attempts attempts"
    return 1
}

# Function to check if Vault is initialized
is_vault_initialized() {
    vault status 2>/dev/null | grep -q "Initialized.*true"
}

# Function to check if Vault is unsealed
is_vault_unsealed() {
    vault status 2>/dev/null | grep -q "Sealed.*false"
}

# Function to initialize Vault
initialize_vault() {
    print_status "Initializing Vault..."
    
    if is_vault_initialized; then
        print_warning "Vault is already initialized"
        return 0
    fi
    
    # Initialize Vault with 3 key shares and 2 key threshold
    local init_output
    init_output=$(vault operator init -key-shares=3 -key-threshold=2 -format=json)
    
    if [ $? -eq 0 ]; then
        print_status "Vault initialized successfully"
        
        # Extract unseal keys and root token
        local unseal_key_1=$(echo "$init_output" | jq -r '.unseal_keys_b64[0]')
        local unseal_key_2=$(echo "$init_output" | jq -r '.unseal_keys_b64[1]')
        local unseal_key_3=$(echo "$init_output" | jq -r '.unseal_keys_b64[2]')
        local root_token=$(echo "$init_output" | jq -r '.root_token')
        
        # Save credentials to file
        cat > vault-credentials.txt << EOF
# Vault Initialization Credentials
# IMPORTANT: Store these credentials securely!

Root Token: $root_token

Unseal Keys:
1. $unseal_key_1
2. $unseal_key_2
3. $unseal_key_3

# To unseal Vault, run:
# vault operator unseal $unseal_key_1
# vault operator unseal $unseal_key_2
# vault operator unseal $unseal_key_3
EOF
        
        print_status "Credentials saved to vault-credentials.txt"
        print_warning "Please store these credentials securely and delete the file after copying!"
        
        # Unseal Vault
        unseal_vault "$unseal_key_1" "$unseal_key_2" "$unseal_key_3"
        
        # Login with root token
        vault auth "$root_token"
        
    else
        print_error "Failed to initialize Vault"
        return 1
    fi
}

# Function to unseal Vault
unseal_vault() {
    local key1="$1"
    local key2="$2"
    local key3="$3"
    
    print_status "Unsealing Vault..."
    
    if is_vault_unsealed; then
        print_warning "Vault is already unsealed"
        return 0
    fi
    
    vault operator unseal "$key1"
    vault operator unseal "$key2"
    vault operator unseal "$key3"
    
    if is_vault_unsealed; then
        print_status "Vault unsealed successfully"
    else
        print_error "Failed to unseal Vault"
        return 1
    fi
}

# Function to enable KV v2 secret engine
enable_kv_v2() {
    print_status "Enabling KV v2 secret engine..."
    
    if vault secrets list | grep -q "secret/"; then
        print_warning "KV v2 secret engine already enabled"
        return 0
    fi
    
    vault secrets enable -path=secret kv-v2
    
    if [ $? -eq 0 ]; then
        print_status "KV v2 secret engine enabled"
    else
        print_error "Failed to enable KV v2 secret engine"
        return 1
    fi
}

# Function to enable Kubernetes authentication
enable_kubernetes_auth() {
    print_status "Enabling Kubernetes authentication..."
    
    if vault auth list | grep -q "kubernetes/"; then
        print_warning "Kubernetes authentication already enabled"
        return 0
    fi
    
    vault auth enable kubernetes
    
    if [ $? -eq 0 ]; then
        print_status "Kubernetes authentication enabled"
    else
        print_error "Failed to enable Kubernetes authentication"
        return 1
    fi
}

# Function to configure Kubernetes authentication
configure_kubernetes_auth() {
    print_status "Configuring Kubernetes authentication..."
    
    # Get Kubernetes service account token
    local sa_token=$(kubectl get secret -n $VAULT_NAMESPACE -o jsonpath='{.items[?(@.metadata.annotations.kubernetes\.io/service-account\.name=="vault")].data.token}' | base64 -d)
    
    if [ -z "$sa_token" ]; then
        print_error "Failed to get service account token"
        return 1
    fi
    
    # Configure Kubernetes auth
    vault write auth/kubernetes/config \
        kubernetes_host="https://kubernetes.default.svc.cluster.local" \
        kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
        token_reviewer_jwt="$sa_token"
    
    if [ $? -eq 0 ]; then
        print_status "Kubernetes authentication configured"
    else
        print_error "Failed to configure Kubernetes authentication"
        return 1
    fi
}

# Function to create Vault policies
create_policies() {
    print_status "Creating Vault policies..."
    
    # Policy for External Secrets Operator
    vault policy write external-secrets-operator - <<EOF
path "secret/data/*" {
  capabilities = ["read"]
}
path "secret/metadata/*" {
  capabilities = ["read", "list"]
}
path "secret/*" {
  capabilities = ["list"]
}
path "auth/kubernetes/login" {
  capabilities = ["create", "update"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF
    
    # Policy for production namespace
    vault policy write production-secrets - <<EOF
path "secret/data/production/*" {
  capabilities = ["read"]
}
path "secret/metadata/production/*" {
  capabilities = ["read", "list"]
}
path "secret/production/*" {
  capabilities = ["list"]
}
path "auth/kubernetes/login" {
  capabilities = ["create", "update"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF
    
    # Policy for monitoring namespace
    vault policy write monitoring-secrets - <<EOF
path "secret/data/monitoring/*" {
  capabilities = ["read"]
}
path "secret/metadata/monitoring/*" {
  capabilities = ["read", "list"]
}
path "secret/monitoring/*" {
  capabilities = ["list"]
}
path "auth/kubernetes/login" {
  capabilities = ["create", "update"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF
    
    # Policy for staging namespace
    vault policy write staging-secrets - <<EOF
path "secret/data/staging/*" {
  capabilities = ["read"]
}
path "secret/metadata/staging/*" {
  capabilities = ["read", "list"]
}
path "secret/staging/*" {
  capabilities = ["list"]
}
path "auth/kubernetes/login" {
  capabilities = ["create", "update"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF
    
    print_status "Vault policies created"
}

# Function to create Kubernetes roles
create_kubernetes_roles() {
    print_status "Creating Kubernetes roles..."
    
    # Role for External Secrets Operator
    vault write auth/kubernetes/role/external-secrets-operator \
        bound_service_account_names=external-secrets-sa \
        bound_service_account_namespaces=external-secrets-system \
        policies=external-secrets-operator \
        ttl=1h
    
    # Role for production namespace
    vault write auth/kubernetes/role/production-secrets-role \
        bound_service_account_names=production-vault-sa \
        bound_service_account_namespaces=production \
        policies=production-secrets \
        ttl=1h
    
    # Role for monitoring namespace
    vault write auth/kubernetes/role/monitoring-secrets-role \
        bound_service_account_names=monitoring-vault-sa \
        bound_service_account_namespaces=monitoring \
        policies=monitoring-secrets \
        ttl=1h
    
    # Role for staging namespace
    vault write auth/kubernetes/role/staging-secrets-role \
        bound_service_account_names=staging-vault-sa \
        bound_service_account_namespaces=staging \
        policies=staging-secrets \
        ttl=1h
    
    print_status "Kubernetes roles created"
}

# Function to create sample secrets
create_sample_secrets() {
    print_status "Creating sample secrets..."
    
    # Production database secret
    vault kv put secret/production/db \
        username="prod_user" \
        password="prod_password_123" \
        host="prod-db.example.com" \
        port="5432"
    
    # Monitoring Grafana secret
    vault kv put secret/monitoring/grafana \
        admin-user="admin" \
        admin-password="grafana_admin_123"
    
    # Staging database secret
    vault kv put secret/staging/db \
        username="staging_user" \
        password="staging_password_123" \
        host="staging-db.example.com" \
        port="5432"
    
    print_status "Sample secrets created"
}

# Function to enable audit logging
enable_audit_logging() {
    print_status "Enabling audit logging..."
    
    if vault audit list | grep -q "file/"; then
        print_warning "File audit device already enabled"
        return 0
    fi
    
    vault audit enable file file_path=/vault/audit/audit.log
    
    if [ $? -eq 0 ]; then
        print_status "Audit logging enabled"
    else
        print_error "Failed to enable audit logging"
        return 1
    fi
}

# Function to verify setup
verify_setup() {
    print_status "Verifying Vault setup..."
    
    # Check Vault status
    if ! is_vault_initialized; then
        print_error "Vault is not initialized"
        return 1
    fi
    
    if ! is_vault_unsealed; then
        print_error "Vault is sealed"
        return 1
    fi
    
    # Check secret engine
    if ! vault secrets list | grep -q "secret/"; then
        print_error "KV v2 secret engine not enabled"
        return 1
    fi
    
    # Check authentication
    if ! vault auth list | grep -q "kubernetes/"; then
        print_error "Kubernetes authentication not enabled"
        return 1
    fi
    
    # Check policies
    if ! vault policy list | grep -q "external-secrets-operator"; then
        print_error "Policies not created"
        return 1
    fi
    
    # Check roles
    if ! vault list auth/kubernetes/role | grep -q "external-secrets-operator"; then
        print_error "Kubernetes roles not created"
        return 1
    fi
    
    print_status "Vault setup verification completed successfully"
}

# Main function
main() {
    print_status "Starting Vault setup for EKS cluster..."
    
    # Check prerequisites
    if ! command_exists kubectl; then
        print_error "kubectl is required but not installed"
        exit 1
    fi
    
    if ! command_exists vault; then
        print_error "vault CLI is required but not installed"
        exit 1
    fi
    
    if ! command_exists jq; then
        print_error "jq is required but not installed"
        exit 1
    fi
    
    # Set Vault address
    export VAULT_ADDR="$VAULT_ADDR"
    export VAULT_SKIP_VERIFY=true  # For development only
    
    # Wait for Vault to be ready
    wait_for_vault
    
    # Initialize Vault if not already initialized
    if ! is_vault_initialized; then
        initialize_vault
    else
        print_warning "Vault is already initialized"
        print_warning "If you need to unseal, use the unseal keys from vault-credentials.txt"
    fi
    
    # Enable KV v2 secret engine
    enable_kv_v2
    
    # Enable Kubernetes authentication
    enable_kubernetes_auth
    
    # Configure Kubernetes authentication
    configure_kubernetes_auth
    
    # Create policies
    create_policies
    
    # Create Kubernetes roles
    create_kubernetes_roles
    
    # Create sample secrets
    create_sample_secrets
    
    # Enable audit logging
    enable_audit_logging
    
    # Verify setup
    verify_setup
    
    print_status "Vault setup completed successfully!"
    print_status "You can now use Vault with External Secrets Operator"
    print_warning "Remember to store the credentials from vault-credentials.txt securely!"
}

# Run main function
main "$@"
