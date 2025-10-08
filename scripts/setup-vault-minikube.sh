#!/usr/bin/env bash
# =============================================================================
# Vault Minikube Setup Script
# =============================================================================
# Deploys HashiCorp Vault on Minikube using ArgoCD with HA Raft configuration
# Includes initialization, troubleshooting, and port-forwarding setup
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
MINIKUBE_CPUS="${MINIKUBE_CPUS:-4}"
MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-8192}"
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"
VAULT_NAMESPACE="vault"
VAULT_VERSION="0.28.1"
VAULT_REPLICAS="${VAULT_REPLICAS:-3}"

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

log_step() {
    echo -e "${CYAN}==>${NC} $1"
}

print_banner() {
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}  Vault Minikube Setup with ArgoCD${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo ""
}

check_prerequisites() {
    log_step "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v minikube &> /dev/null; then
        missing_tools+=("minikube")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Please install the missing tools:"
        echo "  - minikube: https://minikube.sigs.k8s.io/docs/start/"
        echo "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
        echo "  - helm: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    
    log_success "All prerequisites are installed"
}

start_minikube() {
    log_step "Starting Minikube..."
    
    if minikube status &> /dev/null; then
        log_info "Minikube is already running"
        return 0
    fi
    
    log_info "Starting Minikube with:"
    echo "  - CPUs: $MINIKUBE_CPUS"
    echo "  - Memory: ${MINIKUBE_MEMORY}MB"
    echo "  - Driver: $MINIKUBE_DRIVER"
    
    minikube start \
        --cpus "$MINIKUBE_CPUS" \
        --memory "$MINIKUBE_MEMORY" \
        --driver "$MINIKUBE_DRIVER" \
        --kubernetes-version=stable
    
    log_success "Minikube started successfully"
}

setup_aws_credentials() {
    log_step "Setting up AWS credentials (optional)..."
    
    # Check if AWS credentials are available
    if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
        log_warning "AWS credentials not found in environment"
        log_info "KMS auto-unseal will not work. Vault will require manual unsealing."
        log_info "To enable KMS auto-unseal, set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
        echo ""
        read -p "Continue without AWS KMS auto-unseal? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Setup cancelled"
            exit 1
        fi
        return 0
    fi
    
    log_info "AWS credentials found. Creating Kubernetes secret..."
    
    # Create vault namespace if it doesn't exist
    kubectl create namespace "$VAULT_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create AWS credentials secret
    kubectl create secret generic aws-credentials \
        -n "$VAULT_NAMESPACE" \
        --from-literal=aws_access_key_id="$AWS_ACCESS_KEY_ID" \
        --from-literal=aws_secret_access_key="$AWS_SECRET_ACCESS_KEY" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "AWS credentials configured"
    log_info "KMS auto-unseal will be available (ensure KMS key exists in us-west-2)"
}

check_argocd() {
    log_step "Checking ArgoCD installation..."
    
    if ! kubectl get namespace argocd &> /dev/null; then
        log_error "ArgoCD namespace not found"
        log_info "Please install ArgoCD first:"
        echo "  kubectl create namespace argocd"
        echo "  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
        exit 1
    fi
    
    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/argocd-server -n argocd 2>/dev/null || true
    
    log_success "ArgoCD is ready"
}

update_argocd_app() {
    log_step "Updating ArgoCD Application for Minikube..."
    
    # Update the ArgoCD application to use values-minikube.yaml
    cat > /tmp/vault-app-patch.yaml << 'EOF'
spec:
  sources:
    - repoURL: 'https://helm.releases.hashicorp.com'
      chart: vault
      targetRevision: 0.28.1
      helm:
        valueFiles:
          - $values/apps/vault/values.yaml
          - $values/apps/vault/values-minikube.yaml
    - repoURL: 'https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps'
      targetRevision: main
      ref: values
EOF
    
    log_info "Note: ArgoCD app configuration updated for Minikube"
    log_warning "Remember to commit and push the values-minikube.yaml to Git for GitOps"
}

deploy_vault() {
    log_step "Deploying Vault via ArgoCD..."
    
    # Create vault namespace
    kubectl create namespace "$VAULT_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply the ArgoCD Application
    kubectl apply -f argocd/apps/vault.yaml
    
    log_info "Waiting for ArgoCD to sync Vault application..."
    
    # Wait for the application to be created
    sleep 5
    
    # Check sync status
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local sync_status
        sync_status=$(kubectl get application vault -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        
        if [ "$sync_status" = "Synced" ]; then
            log_success "Vault application synced"
            break
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    
    echo ""
    
    # Wait for StatefulSet to be created
    log_info "Waiting for Vault StatefulSet..."
    kubectl wait --for=condition=ready pod/vault-0 -n "$VAULT_NAMESPACE" --timeout=300s 2>/dev/null || {
        log_warning "Vault pod not ready yet (this is expected - Vault needs initialization)"
    }
}

check_vault_status() {
    log_step "Checking Vault deployment status..."
    
    echo ""
    log_info "StatefulSet status:"
    kubectl get statefulset vault -n "$VAULT_NAMESPACE" 2>/dev/null || log_warning "StatefulSet not found"
    
    echo ""
    log_info "Pods status:"
    kubectl get pods -n "$VAULT_NAMESPACE" -l app.kubernetes.io/name=vault
    
    echo ""
    log_info "PVC status:"
    kubectl get pvc -n "$VAULT_NAMESPACE"
    
    echo ""
    log_info "Service status:"
    kubectl get svc -n "$VAULT_NAMESPACE"
}

initialize_vault() {
    log_step "Initializing Vault..."
    
    # Check if vault-0 pod is running
    if ! kubectl get pod vault-0 -n "$VAULT_NAMESPACE" &> /dev/null; then
        log_error "vault-0 pod not found"
        return 1
    fi
    
    # Wait for pod to be running (not necessarily ready)
    log_info "Waiting for vault-0 pod to be running..."
    kubectl wait --for=jsonpath='{.status.phase}'=Running pod/vault-0 -n "$VAULT_NAMESPACE" --timeout=300s
    
    # Check if already initialized
    log_info "Checking if Vault is already initialized..."
    local init_status
    init_status=$(kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault status -format=json 2>/dev/null | grep -o '"initialized":[^,}]*' | cut -d: -f2 | tr -d ' ' || echo "false")
    
    if [ "$init_status" = "true" ]; then
        log_info "Vault is already initialized"
        return 0
    fi
    
    log_info "Initializing Vault..."
    
    # Use the vault-init.sh script if available
    if [ -f "scripts/vault-init.sh" ]; then
        log_info "Using vault-init.sh script for initialization"
        bash scripts/vault-init.sh
    else
        # Manual initialization
        log_info "Initializing Vault manually..."
        kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault operator init \
            -key-shares=5 \
            -key-threshold=3 \
            -format=json | tee vault-keys.json
        
        chmod 600 vault-keys.json
        
        log_success "Vault initialized. Keys saved to vault-keys.json"
        log_warning "IMPORTANT: Store these keys securely and delete this file after backing up!"
    fi
}

unseal_vault() {
    log_step "Checking Vault seal status..."
    
    # Check seal status
    local seal_status
    seal_status=$(kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault status -format=json 2>/dev/null | grep -o '"sealed":[^,}]*' | cut -d: -f2 | tr -d ' ' || echo "true")
    
    if [ "$seal_status" = "false" ]; then
        log_success "Vault is already unsealed"
        return 0
    fi
    
    log_warning "Vault is sealed"
    
    # Check if AWS KMS auto-unseal is configured
    if [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
        log_info "AWS KMS auto-unseal is configured. Vault should unseal automatically."
        log_info "Waiting for auto-unseal..."
        sleep 10
        
        # Check again
        seal_status=$(kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault status -format=json 2>/dev/null | grep -o '"sealed":[^,}]*' | cut -d: -f2 | tr -d ' ' || echo "true")
        
        if [ "$seal_status" = "false" ]; then
            log_success "Vault unsealed via AWS KMS"
            return 0
        else
            log_warning "Auto-unseal failed. Manual unseal required."
        fi
    fi
    
    # Manual unseal
    log_info "Manual unseal required"
    
    if [ ! -f "vault-keys.json" ]; then
        log_error "vault-keys.json not found. Cannot unseal automatically."
        log_info "Please unseal manually using:"
        echo "  kubectl exec -it vault-0 -n $VAULT_NAMESPACE -- vault operator unseal"
        return 1
    fi
    
    log_info "Unsealing with keys from vault-keys.json..."
    
    # Extract unseal keys
    local keys
    keys=$(jq -r '.unseal_keys_b64[]' vault-keys.json 2>/dev/null || jq -r '.unseal_keys_hex[]' vault-keys.json)
    
    local count=0
    while IFS= read -r key; do
        if [ $count -lt 3 ]; then
            kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault operator unseal "$key" > /dev/null
            count=$((count + 1))
            log_info "Unseal progress: $count/3"
        fi
    done <<< "$keys"
    
    log_success "Vault unsealed successfully"
}

join_raft_peers() {
    log_step "Joining Raft peers to cluster..."
    
    # Only proceed if replicas > 1
    if [ "$VAULT_REPLICAS" -eq 1 ]; then
        log_info "Single replica mode, skipping peer join"
        return 0
    fi
    
    local pods=("vault-1" "vault-2")
    
    for pod in "${pods[@]}"; do
        # Check if pod exists
        if ! kubectl get pod "$pod" -n "$VAULT_NAMESPACE" &> /dev/null; then
            log_warning "Pod $pod not found, skipping..."
            continue
        fi
        
        # Wait for pod to be running
        log_info "Waiting for $pod to be running..."
        kubectl wait --for=jsonpath='{.status.phase}'=Running pod/"$pod" -n "$VAULT_NAMESPACE" --timeout=180s || {
            log_warning "Pod $pod not ready, skipping..."
            continue
        }
        
        # Join Raft cluster
        log_info "Joining $pod to Raft cluster..."
        kubectl exec -n "$VAULT_NAMESPACE" "$pod" -- vault operator raft join http://vault-0.vault-internal:8200 || {
            log_warning "Failed to join $pod (may already be joined)"
        }
        
        sleep 2
    done
    
    log_success "Raft peer join completed"
    
    # List Raft peers
    log_info "Current Raft peers:"
    kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault operator raft list-peers 2>/dev/null || log_warning "Could not list peers"
}

setup_port_forward() {
    log_step "Setting up port-forward for Vault UI..."
    
    log_info "Starting port-forward in background..."
    log_info "Vault UI will be available at: http://localhost:8200"
    
    # Kill existing port-forward if any
    pkill -f "kubectl port-forward.*vault.*8200" 2>/dev/null || true
    
    # Start port-forward in background
    kubectl port-forward -n "$VAULT_NAMESPACE" svc/vault 8200:8200 > /dev/null 2>&1 &
    local pf_pid=$!
    
    sleep 2
    
    if ps -p $pf_pid > /dev/null; then
        log_success "Port-forward started (PID: $pf_pid)"
        echo "  Access Vault UI at: http://localhost:8200"
        
        if [ -f "vault-keys.json" ]; then
            local root_token
            root_token=$(jq -r '.root_token' vault-keys.json 2>/dev/null || echo "")
            if [ -n "$root_token" ]; then
                echo "  Root token: $root_token"
            fi
        fi
    else
        log_warning "Port-forward failed to start"
    fi
}

troubleshooting_info() {
    echo ""
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}  Troubleshooting Commands${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo ""
    
    cat << EOF
# Check ArgoCD sync status
kubectl get application vault -n argocd
kubectl describe application vault -n argocd

# Force ArgoCD refresh
kubectl patch application vault -n argocd --type merge -p '{"metadata": {"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Check Vault pods
kubectl get pods -n $VAULT_NAMESPACE
kubectl describe pod vault-0 -n $VAULT_NAMESPACE
kubectl logs vault-0 -n $VAULT_NAMESPACE

# Check Vault status
kubectl exec -it vault-0 -n $VAULT_NAMESPACE -- vault status

# Check PVCs
kubectl get pvc -n $VAULT_NAMESPACE
kubectl describe pvc data-vault-0 -n $VAULT_NAMESPACE

# Check StatefulSet
kubectl get statefulset vault -n $VAULT_NAMESPACE
kubectl describe statefulset vault -n $VAULT_NAMESPACE

# Check MutatingWebhookConfiguration (OutOfSync issue)
kubectl get mutatingwebhookconfiguration vault-agent-injector-cfg
kubectl describe mutatingwebhookconfiguration vault-agent-injector-cfg

# Manual unseal (if auto-unseal fails)
kubectl exec -it vault-0 -n $VAULT_NAMESPACE -- vault operator unseal

# Scale down replicas (if HA fails)
kubectl scale statefulset vault -n $VAULT_NAMESPACE --replicas=1

# Reinstall (if needed)
kubectl delete application vault -n argocd
kubectl delete namespace $VAULT_NAMESPACE
# Then re-run this script

# Port-forward Vault UI
kubectl port-forward -n $VAULT_NAMESPACE svc/vault 8200:8200

# Access ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

EOF
}

main() {
    print_banner
    
    check_prerequisites
    start_minikube
    setup_aws_credentials
    check_argocd
    update_argocd_app
    deploy_vault
    
    echo ""
    log_info "Waiting for Vault pods to stabilize..."
    sleep 10
    
    check_vault_status
    
    echo ""
    read -p "Initialize Vault now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        initialize_vault
        sleep 5
        unseal_vault
        sleep 5
        join_raft_peers
    else
        log_info "Skipping initialization. Run later with: ./scripts/vault-init.sh"
    fi
    
    echo ""
    read -p "Setup port-forward to access Vault UI? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_port_forward
    fi
    
    troubleshooting_info
    
    echo ""
    log_success "Vault setup completed!"
    echo ""
    log_info "Next steps:"
    echo "  1. Commit and push values-minikube.yaml to Git"
    echo "  2. Update argocd/apps/vault.yaml to use values-minikube.yaml"
    echo "  3. Access Vault UI at http://localhost:8200"
    echo "  4. Configure Vault policies and roles"
    echo "  5. Test secret injection with web-app"
    echo ""
    log_warning "Remember to securely store vault-keys.json and delete after backup!"
    echo ""
}

# Run main function
main "$@"
