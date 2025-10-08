#!/usr/bin/env bash
# =============================================================================
# ArgoCD CLI Login & Sync Script (Windows Git Bash)
# =============================================================================
# Automates the setup of Argo CD CLI for Kubernetes cluster, including:
#   - Port-forwarding to Argo CD server
#   - CLI login authentication
#   - Syncing Prometheus and Vault applications
#
# Prerequisites:
#   - kubectl installed and configured
#   - argocd CLI installed
#   - Kubernetes cluster with ArgoCD deployed
#   - Git Bash on Windows
#
# Usage:
#   ./scripts/argocd-login.sh
#
# Notes:
#   - Script is idempotent - safe to run multiple times
#   - Kills existing port-forward on 8080 before starting
#   - Works with both Minikube and AWS EKS clusters
# =============================================================================

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ARGOCD_NAMESPACE="argocd"
LOCAL_PORT="8080"
POD_PORT="443"
ARGOCD_SERVER="localhost:${LOCAL_PORT}"
LOGIN_RETRIES=3
RETRY_DELAY=5

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    # Check argocd CLI
    if ! command -v argocd &> /dev/null; then
        log_error "argocd CLI not found. Please install ArgoCD CLI first."
        log_error "Installation: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
        exit 1
    fi
    
    # Verify kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "kubectl not connected to a cluster. Please configure kubectl first."
        exit 1
    fi
    
    # Check if ArgoCD namespace exists
    if ! kubectl get namespace "${ARGOCD_NAMESPACE}" &> /dev/null; then
        log_error "ArgoCD namespace '${ARGOCD_NAMESPACE}' not found."
        log_error "Please deploy ArgoCD first using setup-minikube.sh or setup-aws.sh"
        exit 1
    fi
    
    log_success "All prerequisites met!"
}

# Kill any process using port 8080
kill_port_process() {
    log_step "Checking for processes using port ${LOCAL_PORT}..."
    
    # Windows Git Bash compatible - use netstat to find process
    # The netstat output format in Windows: TCP    0.0.0.0:8080    0.0.0.0:0    LISTENING    1234
    local pid=$(netstat -ano | grep ":${LOCAL_PORT}" | grep "LISTENING" | awk '{print $5}' | head -n 1)
    
    if [ -n "$pid" ]; then
        log_warn "Found process ${pid} using port ${LOCAL_PORT}"
        log_info "Killing process ${pid}..."
        
        # Use taskkill for Windows
        if command -v taskkill.exe &> /dev/null; then
            taskkill.exe //PID "${pid}" //F &> /dev/null || true
            log_success "Killed process ${pid}"
        else
            log_warn "taskkill not found, attempting alternative method..."
            kill -9 "${pid}" &> /dev/null || true
        fi
        
        # Wait a moment for port to be released
        sleep 2
    else
        log_info "Port ${LOCAL_PORT} is available"
    fi
}

# Find ArgoCD server pod
find_argocd_pod() {
    log_step "Finding ArgoCD server pod..."
    
    local pod_name=$(kubectl get pods -n "${ARGOCD_NAMESPACE}" \
        -l app.kubernetes.io/name=argocd-server \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        log_error "ArgoCD server pod not found in namespace '${ARGOCD_NAMESPACE}'"
        log_error "Check pod status: kubectl get pods -n ${ARGOCD_NAMESPACE}"
        exit 1
    fi
    
    log_info "Found ArgoCD server pod: ${pod_name}"
    echo "$pod_name"
}

# Check if ArgoCD server is ready
check_argocd_ready() {
    log_step "Checking if ArgoCD server is ready..."
    
    local ready=$(kubectl get deployment argocd-server -n "${ARGOCD_NAMESPACE}" \
        -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
    
    if [ "$ready" != "True" ]; then
        log_error "ArgoCD server is not ready yet"
        log_error "Check status: kubectl get deployment argocd-server -n ${ARGOCD_NAMESPACE}"
        exit 1
    fi
    
    log_success "ArgoCD server is ready!"
}

# Start port-forward in background
start_port_forward() {
    log_step "Starting port-forward to ArgoCD server..."
    
    # Kill any existing kubectl port-forward processes
    pkill -f "kubectl port-forward.*argocd-server" &> /dev/null || true
    sleep 1
    
    # Start port-forward in background
    kubectl port-forward -n "${ARGOCD_NAMESPACE}" \
        svc/argocd-server "${LOCAL_PORT}:${POD_PORT}" \
        > /dev/null 2>&1 &
    
    local pf_pid=$!
    
    # Wait for port-forward to establish
    log_info "Waiting for port-forward to establish..."
    local max_wait=15
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        if netstat -ano | grep ":${LOCAL_PORT}" | grep "LISTENING" &> /dev/null; then
            log_success "Port-forward established on port ${LOCAL_PORT} (PID: ${pf_pid})"
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done
    
    log_error "Port-forward failed to establish within ${max_wait} seconds"
    exit 1
}

# Retrieve ArgoCD admin password
get_argocd_password() {
    log_step "Retrieving ArgoCD admin password..."
    
    local password=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    
    if [ -z "$password" ]; then
        log_error "Failed to retrieve ArgoCD admin password"
        log_error "Check if secret exists: kubectl get secret argocd-initial-admin-secret -n ${ARGOCD_NAMESPACE}"
        exit 1
    fi
    
    log_success "ArgoCD admin password retrieved (hidden for security)"
    echo "$password"
}

# Login to ArgoCD CLI
login_argocd() {
    local password=$1
    log_step "Logging in to ArgoCD CLI..."
    
    local attempt=1
    while [ $attempt -le $LOGIN_RETRIES ]; do
        log_info "Login attempt ${attempt}/${LOGIN_RETRIES}..."
        
        if echo "$password" | argocd login "${ARGOCD_SERVER}" \
            --username admin \
            --password "$password" \
            --insecure 2>/dev/null; then
            log_success "Successfully logged in to ArgoCD!"
            return 0
        fi
        
        if [ $attempt -lt $LOGIN_RETRIES ]; then
            log_warn "Login failed, retrying in ${RETRY_DELAY} seconds..."
            sleep $RETRY_DELAY
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "Failed to login to ArgoCD after ${LOGIN_RETRIES} attempts"
    log_error "Verify port-forward is working: curl -k https://localhost:${LOCAL_PORT}"
    exit 1
}

# Check if an ArgoCD application exists
app_exists() {
    local app_name=$1
    argocd app get "$app_name" &> /dev/null
}

# Sync ArgoCD application
sync_app() {
    local app_name=$1
    log_step "Syncing ArgoCD application: ${app_name}..."
    
    if ! app_exists "$app_name"; then
        log_warn "Application '${app_name}' not found in ArgoCD, skipping sync"
        return 0
    fi
    
    log_info "Application '${app_name}' found, starting sync..."
    
    if argocd app sync "$app_name" --force --prune --timeout 300; then
        log_success "Successfully synced '${app_name}'"
        
        # Show app status
        log_info "Current status of '${app_name}':"
        argocd app get "$app_name" --show-operation
    else
        log_error "Failed to sync '${app_name}'"
        return 1
    fi
}

# Sync multiple applications
sync_apps() {
    log_step "Syncing applications..."
    
    local apps=("prometheus" "vault")
    local failed_apps=()
    
    for app in "${apps[@]}"; do
        if ! sync_app "$app"; then
            failed_apps+=("$app")
        fi
        echo ""
    done
    
    # Report results
    if [ ${#failed_apps[@]} -eq 0 ]; then
        log_success "All applications synced successfully!"
    else
        log_warn "Some applications failed to sync: ${failed_apps[*]}"
    fi
}

# Verify ArgoCD connection and list apps
verify_connection() {
    log_step "Verifying ArgoCD connection..."
    
    # Get current user
    log_info "Current user:"
    if argocd account get-user-info; then
        log_success "Connection verified!"
    else
        log_error "Failed to verify connection"
        return 1
    fi
    
    echo ""
    
    # List all applications
    log_info "ArgoCD Applications:"
    argocd app list
}

# Display access information
display_access_info() {
    local password=$1
    
    echo ""
    log_info "==================================================================="
    log_info "ArgoCD CLI Setup Complete!"
    log_info "==================================================================="
    echo ""
    log_info "Access Information:"
    echo ""
    echo "  ArgoCD UI:"
    echo "    URL: https://localhost:${LOCAL_PORT}"
    echo "    Username: admin"
    echo "    Password: ${password}"
    echo ""
    echo "  CLI Commands:"
    echo "    List apps:        argocd app list"
    echo "    Get app status:   argocd app get <app-name>"
    echo "    Sync app:         argocd app sync <app-name>"
    echo "    Delete app:       argocd app delete <app-name>"
    echo "    View logs:        argocd app logs <app-name>"
    echo ""
    log_info "Port-forward is running in background (PID: $(pgrep -f 'kubectl port-forward.*argocd-server' | head -n 1))"
    log_warn "To stop port-forward: pkill -f 'kubectl port-forward.*argocd-server'"
    echo ""
    log_info "==================================================================="
}

# Cleanup handler
cleanup() {
    log_warn "Script interrupted, cleaning up..."
    # Note: We intentionally keep port-forward running
    exit 1
}

# Set trap for cleanup on exit signals
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    log_info "Starting ArgoCD CLI Login & Sync Script..."
    echo ""
    
    # Execute steps
    check_prerequisites
    echo ""
    
    kill_port_process
    echo ""
    
    check_argocd_ready
    echo ""
    
    start_port_forward
    echo ""
    
    ARGOCD_PASSWORD=$(get_argocd_password)
    echo ""
    
    login_argocd "$ARGOCD_PASSWORD"
    echo ""
    
    sync_apps
    echo ""
    
    verify_connection
    echo ""
    
    display_access_info "$ARGOCD_PASSWORD"
    
    log_success "Setup complete!"
}

main "$@"

