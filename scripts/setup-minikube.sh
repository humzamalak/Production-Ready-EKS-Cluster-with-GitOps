#!/usr/bin/env bash
# =============================================================================
# Minikube Setup Script - Improved
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
ARGOCD_VERSION="2.13.0"

# Helper functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v minikube &> /dev/null; then
        log_error "minikube not found"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        log_error "helm not found"
        exit 1
    fi
    
    log_info "All prerequisites met!"
}

start_minikube() {
    log_info "Checking Minikube status..."
    
    if minikube status | grep -q "Running"; then
        log_info "Minikube is already running"
    else
        log_info "Starting Minikube..."
        minikube start --cpus=4 --memory=8192 --disk-size=20g
    fi
    
    log_info "Enabling addons..."
    minikube addons enable ingress
    minikube addons enable metrics-server
}

deploy_argocd() {
    log_info "Deploying ArgoCD..."
    
    # Apply namespaces
    kubectl apply -f argo-apps/install/01-namespaces.yaml
    kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/argocd --timeout=60s
    
    # Install ArgoCD
    log_info "Installing ArgoCD v${ARGOCD_VERSION}..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml
    
    # Wait for ArgoCD with proper timeout
    log_info "Waiting for ArgoCD deployments to be ready (this may take 3-5 minutes)..."
    
    # Wait for each critical component
    kubectl wait --for=condition=available --timeout=300s \
        deployment/argocd-server -n argocd || {
        log_warn "argocd-server timeout, checking status..."
        kubectl get pods -n argocd
    }
    
    kubectl wait --for=condition=available --timeout=300s \
        deployment/argocd-repo-server -n argocd || true
    
    kubectl wait --for=condition=available --timeout=300s \
        deployment/argocd-applicationset-controller -n argocd || true
    
    # Wait for all pods to be ready
    log_info "Waiting for all ArgoCD pods to be fully ready..."
    local max_wait=180
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        # Count pods with Ready=True condition (using grep instead of jq)
        local ready_count=$(kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c "True" || echo 0)
        
        local total_count=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l)
        
        if [ "$ready_count" -eq "$total_count" ] && [ "$ready_count" -gt 0 ]; then
            log_info "All ArgoCD pods are ready!"
            # Extra wait for internal initialization
            log_info "Waiting additional 30 seconds for internal initialization..."
            sleep 30
            break
        fi
        
        echo -n "."
        sleep 5
        waited=$((waited + 5))
    done
    
    echo ""
    
    # Get admin password
    log_info "Retrieving ArgoCD admin password..."
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")
    
    if [ -n "$ARGOCD_PASSWORD" ]; then
        log_info "ArgoCD is ready!"
        log_info "Admin password: $ARGOCD_PASSWORD"
    else
        log_warn "Could not retrieve password yet"
    fi
}

deploy_applications() {
    log_info "Deploying bootstrap applications..."
    
    kubectl apply -f argo-apps/install/03-bootstrap.yaml
    
    log_info "Waiting for applications to sync..."
    sleep 10
    
    log_info "Applications deployed!"
}

display_access_info() {
    log_info "==================================================================="
    log_info "Minikube GitOps Stack Deployment Complete!"
    log_info "==================================================================="
    echo ""
    log_info "Next Steps:"
    echo ""
    echo "  1. Login to ArgoCD CLI:"
    echo "     ./scripts/argocd-login.sh"
    echo ""
    echo "  2. Or access ArgoCD UI manually:"
    echo "     kubectl port-forward -n argocd svc/argocd-server 8080:443"
    echo "     URL: https://localhost:8080"
    echo "     Username: admin"
    echo "     Password: $ARGOCD_PASSWORD"
    echo ""
    log_info "Check status:"
    echo "     kubectl get pods -A"
    echo "     kubectl get applications -n argocd"
    log_info "==================================================================="
}

# Main execution
main() {
    log_info "Starting Minikube GitOps Stack Setup..."
    
    check_prerequisites
    start_minikube
    deploy_argocd
    deploy_applications
    display_access_info
    
    log_info "Setup complete!"
    log_info ""
    log_info "IMPORTANT: Wait a few minutes before running argocd-login.sh"
    log_info "ArgoCD needs time to fully initialize all components."
}

main "$@"