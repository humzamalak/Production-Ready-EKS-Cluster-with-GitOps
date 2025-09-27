#!/bin/bash

# Production-Ready EKS Cluster with GitOps - ArgoCD Deployment Script
# This script installs and configures ArgoCD for GitOps workflow
#
# Usage: ./scripts/argocd-deploy.sh [OPTIONS]

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Help function
show_help() {
    show_help_header \
        "$(basename "$0")" \
        "Production-Ready EKS Cluster with GitOps - ArgoCD Deployment Script"
    
    cat << EOF
EXAMPLES:
    $0                      # Deploy ArgoCD
    $0 --validate-only      # Only validate prerequisites and configuration
    $0 --dry-run            # Show what would be deployed
    $0 -v                   # Verbose output

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                parse_common_args "$@"
                break
                ;;
        esac
    done
}

# Check if cluster is accessible
check_cluster_access() {
    log "Checking cluster access..."
    
    if ! kubectl get nodes >/dev/null 2>&1; then
        error "Cannot access EKS cluster. Make sure kubectl is configured and the cluster is running."
    fi
    
    success "Cluster access verified"
}

# Add ArgoCD Helm repository
add_argocd_helm_repo() {
    log "Adding ArgoCD Helm repository..."
    
    if ! helm repo add argo https://argoproj.github.io/argo-helm; then
        error "Failed to add ArgoCD Helm repository"
    fi
    
    if ! helm repo update; then
        error "Failed to update Helm repositories"
    fi
    
    success "ArgoCD Helm repository added and updated"
}

# Install ArgoCD
install_argocd() {
    log "Installing ArgoCD with Helm..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would install ArgoCD with the following command:"
        log "helm upgrade --install argocd argo/argo-cd \\"
        log "    --namespace argocd \\"
        log "    --create-namespace \\"
        log "    --values ${ARGO_CD_DIR}/bootstrap/values.yaml \\"
        log "    --wait \\"
        log "    --timeout=10m"
        return 0
    fi
    
    if ! helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        --values "${ARGO_CD_DIR}/bootstrap/values.yaml" \
        --wait \
        --timeout=10m; then
        error "Failed to install ArgoCD with Helm"
    fi
    
    success "ArgoCD installed successfully"
}

# Wait for ArgoCD to be ready
wait_for_argocd() {
    log "Waiting for ArgoCD to be ready..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would wait for ArgoCD server deployment to be available"
        return 0
    fi
    
    if ! kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd; then
        error "ArgoCD server failed to become available within timeout"
    fi
    
    success "ArgoCD is ready"
}

# Get and store ArgoCD admin password
get_argocd_admin_password() {
    log "Retrieving ArgoCD admin password..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would retrieve ArgoCD admin password"
        return 0
    fi
    
    local admin_password
    admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Password not available")
    
    if [[ -n "$admin_password" ]]; then
        echo "ArgoCD Admin Password: $admin_password" | tee -a "$LOG_FILE"
        echo "$admin_password" > "${SCRIPT_DIR}/argocd-admin-password.txt"
        chmod 600 "${SCRIPT_DIR}/argocd-admin-password.txt"
        success "ArgoCD admin password retrieved and stored"
    else
        warning "Could not retrieve ArgoCD admin password"
    fi
}

# Deploy ArgoCD
deploy_argocd() {
    log "Deploying ArgoCD..."
    
    # Check cluster access
    check_cluster_access
    
    # Add ArgoCD Helm repository
    add_argocd_helm_repo
    
    # Install ArgoCD
    install_argocd
    
    # Wait for ArgoCD to be ready
    wait_for_argocd
    
    # Get admin password
    get_argocd_admin_password
    
    success "ArgoCD deployment completed"
}

# Validate ArgoCD configuration
validate_argocd_config() {
    log "Validating ArgoCD configuration..."
    
    # Check if values file exists
    if [[ ! -f "${ARGO_CD_DIR}/bootstrap/values.yaml" ]]; then
        error "ArgoCD values file not found: ${ARGO_CD_DIR}/bootstrap/values.yaml"
    fi
    
    # Check if cluster is accessible
    if ! kubectl get nodes >/dev/null 2>&1; then
        error "Cannot access EKS cluster. Make sure kubectl is configured."
    fi
    
    # Check if Helm is available
    if ! command_exists helm; then
        error "Helm is not installed or not in PATH"
    fi
    
    # Check if ArgoCD namespace exists (optional)
    if kubectl get namespace argocd >/dev/null 2>&1; then
        log "ArgoCD namespace already exists"
    else
        log "ArgoCD namespace will be created"
    fi
    
    success "ArgoCD configuration validation completed"
}

# Show ArgoCD status
show_argocd_status() {
    log "ArgoCD Status:"
    
    echo ""
    echo "=== ARGOCD STATUS ==="
    echo ""
    
    # Check ArgoCD pods
    if kubectl get pods -n argocd >/dev/null 2>&1; then
        kubectl get pods -n argocd
        echo ""
    else
        warning "Cannot get ArgoCD pods status"
    fi
    
    # Check ArgoCD services
    if kubectl get services -n argocd >/dev/null 2>&1; then
        kubectl get services -n argocd
        echo ""
    else
        warning "Cannot get ArgoCD services status"
    fi
    
    # Show access information
    echo "ArgoCD UI Access:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  https://localhost:8080"
    echo "  Username: admin"
    echo "  Password: $(cat "${SCRIPT_DIR}/argocd-admin-password.txt" 2>/dev/null || echo "Check log file")"
    echo ""
}

# Main function
main() {
    # Initialize log file
    init_log_file
    
    # Parse arguments
    parse_args "$@"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Exit if validation only
    if [[ "${VALIDATE_ONLY:-false}" == "true" ]]; then
        validate_argocd_config
        success "Validation completed successfully"
        exit 0
    fi
    
    # Exit if dry run only
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        deploy_argocd
        success "Dry run completed successfully"
        exit 0
    fi
    
    # Deploy ArgoCD
    deploy_argocd
    
    # Show status
    show_argocd_status
    
    success "ArgoCD deployment completed successfully!"
    log "Check $LOG_FILE for detailed logs"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
