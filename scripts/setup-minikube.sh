#!/usr/bin/env bash
# =============================================================================
# Minikube Setup Script
# =============================================================================
# Deploys the complete GitOps stack on Minikube for local development
#
# Components:
#   - ArgoCD
#   - Prometheus
#   - Grafana
#   - Vault (dev mode)
#   - Web App
#
# Prerequisites:
#   - minikube installed
#   - kubectl installed
#   - helm installed
#
# Usage:
#   ./scripts/setup-minikube.sh
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps"
ARGOCD_VERSION="2.13.0"

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

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v minikube &> /dev/null; then
        log_error "minikube not found. Please install minikube first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        log_error "helm not found. Please install helm first."
        exit 1
    fi
    
    log_info "All prerequisites met!"
}

start_minikube() {
    log_info "Checking Minikube status..."
    
    if minikube status | grep -q "Running"; then
        log_info "Minikube is already running"
    else
        log_info "Starting Minikube with recommended resources..."
        minikube start --cpus=4 --memory=8192 --disk-size=20g
    fi
    
    # Enable ingress addon
    log_info "Enabling ingress addon..."
    minikube addons enable ingress
    
    # Enable metrics-server
    log_info "Enabling metrics-server addon..."
    minikube addons enable metrics-server
}

deploy_argocd() {
    log_info "Deploying ArgoCD..."
    
    # Apply namespaces
    kubectl apply -f argocd/install/01-namespaces.yaml
    
    # Wait for namespaces
    kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/argocd --timeout=60s
    
    # Apply ArgoCD installation
    kubectl apply -f argocd/install/02-argocd-install.yaml
    
    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD to be ready (this may take 2-3 minutes)..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/argocd-server -n argocd || true
    
    # Get admin password
    log_info "Retrieving ArgoCD admin password..."
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")
    
    if [ -n "$ARGOCD_PASSWORD" ]; then
        log_info "ArgoCD admin password: $ARGOCD_PASSWORD"
        log_info "ArgoCD will be available at: http://localhost:8080"
        log_info "Run: kubectl port-forward -n argocd svc/argocd-server 8080:443"
    fi
}

deploy_applications() {
    log_info "Deploying bootstrap applications..."
    
    # Apply projects and root app
    kubectl apply -f argocd/install/03-bootstrap.yaml
    
    # Wait for projects to sync
    log_info "Waiting for projects to sync..."
    sleep 10
    
    log_info "Applications deployed! Check ArgoCD UI for sync status."
}

configure_applications() {
    log_info "Configuring applications for Minikube..."
    
    # Update ArgoCD applications to use Minikube values
    # This would typically be done via kustomize or environment-specific overlays
    
    log_warn "Note: Applications are using default values."
    log_warn "To use Minikube-specific values, update the ArgoCD applications to reference:"
    log_warn "  - apps/web-app/values-minikube.yaml"
    log_warn "  - apps/prometheus/values-minikube.yaml"
    log_warn "  - apps/grafana/values-minikube.yaml"
    log_warn "  - apps/vault/values-minikube.yaml"
}

display_access_info() {
    log_info "==================================================================="
    log_info "Minikube GitOps Stack Deployment Complete!"
    log_info "==================================================================="
    echo ""
    log_info "Access your applications:"
    echo ""
    echo "  ArgoCD:"
    echo "    kubectl port-forward -n argocd svc/argocd-server 8080:443"
    echo "    URL: http://localhost:8080"
    echo "    Username: admin"
    echo "    Password: $ARGOCD_PASSWORD"
    echo ""
    echo "  Grafana:"
    echo "    kubectl port-forward -n monitoring svc/grafana 3000:80"
    echo "    URL: http://localhost:3000"
    echo "    Username: admin"
    echo "    Password: admin"
    echo ""
    echo "  Prometheus:"
    echo "    kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
    echo "    URL: http://localhost:9090"
    echo ""
    echo "  Vault:"
    echo "    kubectl port-forward -n vault svc/vault 8200:8200"
    echo "    URL: http://localhost:8200"
    echo "    Token: root (dev mode)"
    echo ""
    echo "  Web App:"
    echo "    minikube service -n production web-app"
    echo ""
    log_info "==================================================================="
    log_info "Check deployment status:"
    echo "    kubectl get pods -A"
    echo "    kubectl get applications -n argocd"
    log_info "==================================================================="
}

# Main execution
main() {
    log_info "Starting Minikube GitOps Stack Setup..."
    
    check_prerequisites
    start_minikube
    deploy_argocd
    deploy_applications
    configure_applications
    display_access_info
    
    log_info "Setup complete!"
}

main "$@"

