#!/usr/bin/env bash
# =============================================================================
# ArgoCD CLI Login Script - Minikube Optimized
# =============================================================================
# Simplified version specifically for Minikube with better timeout handling
# =============================================================================

set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ARGOCD_NAMESPACE="argocd"
LOCAL_PORT="8080"
ARGOCD_SERVER="localhost:${LOCAL_PORT}"

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1" >&2; }

# Find ArgoCD CLI
find_argocd() {
    local argocd_path=""
    
    # Try standard command
    if command -v argocd &> /dev/null; then
        argocd_path=$(command -v argocd)
    elif command -v argocd.exe &> /dev/null; then
        argocd_path=$(command -v argocd.exe)
    elif [ -f "/c/WINDOWS/system32/argocd.exe" ]; then
        argocd_path="/c/WINDOWS/system32/argocd.exe"
    else
        log_error "ArgoCD CLI not found!"
        exit 1
    fi
    
    echo "$argocd_path"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi
    
    ARGOCD_CMD=$(find_argocd)
    log_info "Found ArgoCD CLI: $ARGOCD_CMD"
    
    if ! kubectl get namespace "${ARGOCD_NAMESPACE}" &> /dev/null; then
        log_error "ArgoCD namespace not found. Please run setup-minikube.sh first"
        exit 1
    fi
}

# Wait for ArgoCD to be fully ready
wait_for_argocd() {
    log_step "Waiting for ArgoCD server to be fully ready..."
    
    local max_wait=120
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        # Check if all argocd-server pods are ready
        local ready_pods=$(kubectl get pods -n "${ARGOCD_NAMESPACE}" \
            -l app.kubernetes.io/name=argocd-server \
            -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        
        if echo "$ready_pods" | grep -q "True"; then
            # Give it a bit more time for internal initialization
            log_info "ArgoCD pods are ready, waiting 15 more seconds for internal initialization..."
            sleep 15
            log_info "ArgoCD should be fully ready now"
            return 0
        fi
        
        echo -n "." >&2
        sleep 2
        waited=$((waited + 2))
    done
    
    log_error "ArgoCD server did not become ready within ${max_wait} seconds"
    log_error "Check status with: kubectl get pods -n argocd"
    exit 1
}

# Kill process on port
kill_port_process() {
    log_step "Checking port ${LOCAL_PORT}..."
    
    local pid=$(netstat -ano 2>/dev/null | grep ":${LOCAL_PORT}" | grep "LISTENING" | awk '{print $5}' | head -n 1)
    
    if [ -n "$pid" ]; then
        log_warn "Port ${LOCAL_PORT} in use by process ${pid}, stopping it..."
        taskkill.exe //PID "${pid}" //F &> /dev/null || kill -9 "${pid}" &> /dev/null || true
        sleep 2
    fi
}

# Start port forward
start_port_forward() {
    log_step "Starting port-forward..."
    
    # Kill existing port-forwards
    pkill -f "kubectl port-forward.*argocd-server" &> /dev/null || true
    sleep 1
    
    # Start new port-forward
    kubectl port-forward -n "${ARGOCD_NAMESPACE}" \
        svc/argocd-server "${LOCAL_PORT}:443" > /dev/null 2>&1 &
    
    local pf_pid=$!
    log_info "Port-forward started (PID: ${pf_pid})"
    
    # Wait for port to be listening
    log_info "Waiting for port-forward to establish..."
    local max_wait=30
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        if netstat -ano 2>/dev/null | grep ":${LOCAL_PORT}" | grep -q "LISTENING"; then
            log_info "Port-forward established successfully"
            # Give it a moment to fully stabilize
            sleep 3
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done
    
    log_error "Port-forward failed to establish"
    exit 1
}

# Get ArgoCD password
get_password() {
    log_step "Retrieving ArgoCD admin password..."
    
    local password=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    
    if [ -z "$password" ]; then
        log_error "Failed to retrieve password"
        exit 1
    fi
    
    echo "$password"
}

# Login to ArgoCD
login_argocd() {
    local password=$1
    log_step "Logging in to ArgoCD CLI..."
    
    # Give the connection a moment to stabilize
    sleep 2
    
    # Try login with increased timeout
    log_info "Attempting login (this may take up to 30 seconds)..."
    
    # Use --grpc-web and disable TLS verification
    if "$ARGOCD_CMD" login "${ARGOCD_SERVER}" \
        --username admin \
        --password "$password" \
        --insecure \
        --grpc-web 2>&1 | grep -q "Logged in"; then
        log_info "Login successful!"
        return 0
    fi
    
    # Alternative: Try without --grpc-web
    log_warn "First attempt failed, trying without gRPC-web..."
    if "$ARGOCD_CMD" login "${ARGOCD_SERVER}" \
        --username admin \
        --password "$password" \
        --insecure 2>&1 | grep -q "Logged in"; then
        log_info "Login successful!"
        return 0
    fi
    
    log_error "Login failed"
    log_error ""
    log_error "Manual troubleshooting:"
    log_error "  1. Check ArgoCD status: kubectl get pods -n argocd"
    log_error "  2. View logs: kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server"
    log_error "  3. Test port-forward manually in another terminal:"
    log_error "     kubectl port-forward -n argocd svc/argocd-server 8080:443"
    log_error "  4. Access UI in browser: https://localhost:8080"
    log_error "     Username: admin"
    log_error "     Password: $password"
    exit 1
}

# Verify connection
verify_connection() {
    log_step "Verifying connection..."
    
    if "$ARGOCD_CMD" app list &> /dev/null; then
        log_info "Connection verified successfully!"
        echo "" >&2
        log_info "Available applications:"
        "$ARGOCD_CMD" app list
        return 0
    else
        log_warn "Could not list applications yet"
        return 1
    fi
}

# Display info
display_info() {
    local password=$1
    
    echo "" >&2
    log_info "================================================================"
    log_info "ArgoCD CLI Login Complete!"
    log_info "================================================================"
    echo "" >&2
    log_info "Access Information:"
    echo "" >&2
    echo "  ArgoCD UI: https://localhost:${LOCAL_PORT}" >&2
    echo "  Username:  admin" >&2
    echo "  Password:  $password" >&2
    echo "" >&2
    log_info "Common Commands:"
    echo "  List apps:     argocd app list" >&2
    echo "  Sync app:      argocd app sync <app-name>" >&2
    echo "  Get app:       argocd app get <app-name>" >&2
    echo "  Delete app:    argocd app delete <app-name>" >&2
    echo "" >&2
    log_info "================================================================"
}

# Main execution
main() {
    log_info "ArgoCD CLI Login Script (Minikube)"
    echo "" >&2
    
    check_prerequisites
    wait_for_argocd
    kill_port_process
    start_port_forward
    
    PASSWORD=$(get_password)
    login_argocd "$PASSWORD"
    verify_connection || log_warn "Verification failed but login succeeded"
    
    display_info "$PASSWORD"
    log_info "Setup complete!"
}

main "$@"