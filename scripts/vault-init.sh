#!/usr/bin/env bash
# =============================================================================
# Vault Initialization and Management Script
# =============================================================================
# Initializes HashiCorp Vault in HA mode with Raft storage and AWS KMS auto-unseal
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="${VAULT_NAMESPACE:-vault}"
POD_NAME="${VAULT_POD:-vault-0}"
KEYS_FILE="${VAULT_KEYS_FILE:-vault-keys.json}"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warning "jq not found. JSON parsing may not work correctly."
        log_info "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    fi
    
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' not found."
        log_info "Create namespace with: kubectl create namespace $NAMESPACE"
        exit 1
    fi
    
    if ! kubectl get pod -n "$NAMESPACE" "$POD_NAME" &> /dev/null; then
        log_error "Pod '$POD_NAME' not found in namespace '$NAMESPACE'."
        log_info "Deploy Vault first with: kubectl apply -f argocd/apps/vault.yaml"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

wait_for_vault() {
    log_info "Waiting for Vault pod to be running..."
    
    kubectl wait --for=condition=ready pod/"$POD_NAME" -n "$NAMESPACE" --timeout=300s 2>/dev/null || true
    
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local status
        status=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.status.phase}')
        
        if [ "$status" = "Running" ]; then
            log_success "Vault pod is running"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    
    log_error "Vault pod did not become ready in time"
    return 1
}

check_vault_status() {
    log_info "Checking Vault status..."
    
    local status_output
    status_output=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- vault status -format=json 2>/dev/null || echo '{}')
    
    local initialized
    initialized=$(echo "$status_output" | grep -o '"initialized":[^,}]*' | cut -d: -f2 | tr -d ' ')
    
    local sealed
    sealed=$(echo "$status_output" | grep -o '"sealed":[^,}]*' | cut -d: -f2 | tr -d ' ')
    
    echo "$initialized|$sealed"
}

initialize_vault() {
    log_info "Initializing Vault with Raft storage..."
    
    # Initialize Vault with 5 key shares and 3 key threshold
    # With AWS KMS auto-unseal, these recovery keys are for emergency access
    local init_output
    init_output=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- vault operator init \
        -key-shares=5 \
        -key-threshold=3 \
        -format=json 2>&1)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to initialize Vault: $init_output"
        return 1
    fi
    
    # Save keys to file
    echo "$init_output" > "$KEYS_FILE"
    chmod 600 "$KEYS_FILE"
    
    log_success "Vault initialized successfully"
    log_warning "Recovery keys saved to: $KEYS_FILE"
    log_warning "IMPORTANT: Store these keys securely and delete this file after backing up!"
    
    # Extract and display root token
    local root_token
    root_token=$(echo "$init_output" | grep -o '"root_token":"[^"]*"' | cut -d'"' -f4)
    
    echo ""
    log_info "Root Token: $root_token"
    log_warning "Save this root token securely!"
    echo ""
    
    return 0
}

check_seal_status() {
    log_info "Checking seal status..."
    
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- vault status || {
        log_warning "Could not get Vault status. Pod may not be ready yet."
        return 1
    }
}

join_raft_peers() {
    log_info "Joining Raft peers to the cluster..."
    
    local pods=("vault-1" "vault-2")
    
    for pod in "${pods[@]}"; do
        log_info "Joining $pod to Raft cluster..."
        
        # Check if pod exists and is running
        if ! kubectl get pod -n "$NAMESPACE" "$pod" &> /dev/null; then
            log_warning "Pod $pod not found, skipping..."
            continue
        fi
        
        # Join the Raft cluster
        kubectl exec -n "$NAMESPACE" "$pod" -- vault operator raft join http://vault-0.vault-internal:8200 || {
            log_warning "Failed to join $pod to cluster (may already be joined)"
        }
        
        sleep 2
    done
    
    log_success "Raft peer join commands completed"
}

list_raft_peers() {
    log_info "Listing Raft peers..."
    
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- vault operator raft list-peers
}

enable_audit_log() {
    log_info "Enabling audit logging..."
    
    local root_token
    if [ -f "$KEYS_FILE" ]; then
        root_token=$(grep -o '"root_token":"[^"]*"' "$KEYS_FILE" | cut -d'"' -f4)
    else
        log_error "Keys file not found. Please provide root token manually."
        read -rsp "Enter root token: " root_token
        echo
    fi
    
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- sh -c "
        export VAULT_TOKEN='$root_token'
        vault audit enable file file_path=/vault/audit/audit.log
    " || log_warning "Audit log may already be enabled"
    
    log_success "Audit logging configuration completed"
}

setup_kubernetes_auth() {
    log_info "Setting up Kubernetes authentication..."
    
    local root_token
    if [ -f "$KEYS_FILE" ]; then
        root_token=$(grep -o '"root_token":"[^"]*"' "$KEYS_FILE" | cut -d'"' -f4)
    else
        log_error "Keys file not found. Please provide root token manually."
        read -rsp "Enter root token: " root_token
        echo
    fi
    
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- sh -c "
        export VAULT_TOKEN='$root_token'
        
        # Enable Kubernetes auth
        vault auth enable kubernetes || true
        
        # Configure Kubernetes auth
        vault write auth/kubernetes/config \
            kubernetes_host=\"https://\$KUBERNETES_PORT_443_TCP_ADDR:443\"
        
        # Enable KV v2 secrets engine
        vault secrets enable -path=secret kv-v2 || true
    "
    
    log_success "Kubernetes authentication configured"
}

main() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Vault Initialization Script${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
    
    check_prerequisites
    wait_for_vault
    
    # Check current status
    local status
    status=$(check_vault_status)
    local initialized
    initialized=$(echo "$status" | cut -d'|' -f1)
    local sealed
    sealed=$(echo "$status" | cut -d'|' -f2)
    
    echo ""
    log_info "Current Status:"
    echo "  - Initialized: $initialized"
    echo "  - Sealed: $sealed"
    echo ""
    
    # Initialize if needed
    if [ "$initialized" = "false" ]; then
        log_warning "Vault is not initialized. Proceeding with initialization..."
        initialize_vault
        
        # Wait a moment for initialization to complete
        sleep 5
        
        # With AWS KMS auto-unseal, Vault should unseal automatically
        # For Minikube without KMS, manual unseal will be required
        log_info "Waiting for auto-unseal to complete (if KMS configured)..."
        log_info "If using Minikube without KMS, Vault will remain sealed (manual unseal required)"
        sleep 10
        
        # Join Raft peers
        join_raft_peers
        
        # Wait for peers to stabilize
        sleep 5
        
        # List peers
        list_raft_peers
        
        # Enable audit logging
        enable_audit_log
        
        # Setup Kubernetes auth
        setup_kubernetes_auth
        
    else
        log_info "Vault is already initialized"
        
        if [ "$sealed" = "true" ]; then
            log_warning "Vault is sealed. With AWS KMS auto-unseal, this should resolve automatically."
            log_info "If seal persists, check IAM permissions for KMS access."
        else
            log_success "Vault is initialized and unsealed"
            
            # Optionally list peers
            read -p "List Raft peers? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                list_raft_peers
            fi
        fi
    fi
    
    echo ""
    check_seal_status
    
    echo ""
    log_success "Vault initialization script completed!"
    echo ""
    log_info "Next steps:"
    echo "  1. Save the recovery keys and root token securely"
    echo "  2. Delete the $KEYS_FILE file after backup"
    echo "  3. Configure Vault policies and roles for your applications"
    echo "  4. Test Vault access: kubectl port-forward -n $NAMESPACE svc/vault 8200:8200"
    echo ""
}

# Run main function
main "$@"
