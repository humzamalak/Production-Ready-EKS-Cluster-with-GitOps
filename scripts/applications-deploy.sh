#!/bin/bash

# Production-Ready EKS Cluster with GitOps - Applications Deployment Script
# This script deploys all applications using ArgoCD's app-of-apps pattern
#
# Usage: ./scripts/applications-deploy.sh [OPTIONS]

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Help function
show_help() {
    show_help_header \
        "$(basename "$0")" \
        "Production-Ready EKS Cluster with GitOps - Applications Deployment Script"
    
    cat << EOF
EXAMPLES:
    $0                      # Deploy all applications
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

# Check if ArgoCD is running
check_argocd_running() {
    log "Checking if ArgoCD is running..."
    
    if ! kubectl get pods -n argocd | grep -q "Running"; then
        error "ArgoCD is not running. Please deploy ArgoCD first using argocd-deploy.sh"
    fi
    
    success "ArgoCD is running"
}

# Create monitoring namespace
create_monitoring_namespace() {
    log "Creating monitoring namespace..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would create monitoring namespace"
        return 0
    fi
    
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    success "Monitoring namespace created"
}

# Create Grafana admin secret
create_grafana_admin_secret() {
    log "Creating Grafana admin secret..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would create Grafana admin secret"
        return 0
    fi
    
    if ! kubectl get secret grafana-admin -n monitoring >/dev/null 2>&1; then
        log "Creating default Grafana admin credentials..."
        kubectl create secret generic grafana-admin -n monitoring \
            --from-literal=admin-user=admin \
            --from-literal=admin-password=admin123 \
            --dry-run=client -o yaml | kubectl apply -f -
        warning "Using default Grafana credentials. Change them in production!"
    else
        log "Grafana admin secret already exists"
    fi
    
    success "Grafana admin secret configured"
}

# Apply root application (app-of-apps pattern)
apply_root_application() {
    log "Applying root application (app-of-apps pattern)..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would apply root application from ${ARGO_CD_DIR}/apps/root-app.yaml"
        return 0
    fi
    
    if ! kubectl apply -f "${ARGO_CD_DIR}/apps/root-app.yaml"; then
        error "Failed to apply root application"
    fi
    
    success "Root application applied successfully"
}

# Wait for applications to be created
wait_for_applications_created() {
    log "Waiting for applications to be created..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would wait for applications to be created"
        return 0
    fi
    
    # ArgoCD needs time to discover and create the child applications
    sleep 30
    
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        local total_apps
        total_apps=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
        
        if [[ "$total_apps" -gt 0 ]]; then
            log "Found $total_apps ArgoCD applications"
            break
        fi
        
        log "Attempt $attempt/$max_attempts: Waiting for applications to be discovered..."
        sleep 15
        ((attempt++))
        
        if [[ $attempt -gt $max_attempts ]]; then
            warning "Applications not discovered within timeout. Check ArgoCD UI for details."
            break
        fi
    done
}

# Monitor application deployment
monitor_application_deployment() {
    log "Monitoring application deployment..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would monitor application deployment"
        return 0
    fi
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        local total_apps synced_apps
        total_apps=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
        synced_apps=$(kubectl get applications -n argocd --no-headers 2>/dev/null | grep -c "Synced" || echo "0")
        
        log "Application sync progress: $synced_apps/$total_apps applications synced (attempt $attempt/$max_attempts)"
        
        if [[ "$synced_apps" -eq "$total_apps" ]] && [[ "$total_apps" -gt 0 ]]; then
            success "All applications synced successfully"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            warning "Not all applications synced within timeout. Check ArgoCD UI for details."
            kubectl get applications -n argocd 2>/dev/null || true
            break
        fi
        
        sleep 30
        ((attempt++))
    done
}

# Verify monitoring stack
verify_monitoring_stack() {
    log "Verifying monitoring stack deployment..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would verify monitoring stack"
        return 0
    fi
    
    local prometheus_ready=false
    local grafana_ready=false
    
    # Check Prometheus
    if kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null | grep -q "Running"; then
        prometheus_ready=true
        log "Prometheus is running"
    else
        warning "Prometheus is not ready yet"
    fi
    
    # Check Grafana
    if kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | grep -q "Running"; then
        grafana_ready=true
        log "Grafana is running"
    else
        warning "Grafana is not ready yet"
    fi
    
    if [[ "$prometheus_ready" == "true" ]] && [[ "$grafana_ready" == "true" ]]; then
        success "Prometheus and Grafana are successfully deployed and running"
    else
        warning "Some monitoring components are not ready. Check pod status:"
        kubectl get pods -n monitoring 2>/dev/null || true
    fi
}

# Deploy applications
deploy_applications() {
    log "Deploying applications with ArgoCD..."
    
    # Check if ArgoCD is running
    check_argocd_running
    
    # Create monitoring namespace
    create_monitoring_namespace
    
    # Create Grafana admin secret
    create_grafana_admin_secret
    
    # Apply root application
    apply_root_application
    
    # Wait for applications to be created
    wait_for_applications_created
    
    # Monitor deployment
    monitor_application_deployment
    
    # Verify monitoring stack
    verify_monitoring_stack
    
    success "Application deployment completed"
}

# Validate applications configuration
validate_applications_config() {
    log "Validating applications configuration..."
    
    # Check if root app manifest exists
    if [[ ! -f "${ARGO_CD_DIR}/apps/root-app.yaml" ]]; then
        error "Root application manifest not found: ${ARGO_CD_DIR}/apps/root-app.yaml"
    fi
    
    # Check if ArgoCD is accessible
    if ! kubectl get pods -n argocd >/dev/null 2>&1; then
        error "Cannot access ArgoCD. Make sure ArgoCD is deployed and running."
    fi
    
    # Check if cluster is accessible
    if ! kubectl get nodes >/dev/null 2>&1; then
        error "Cannot access EKS cluster. Make sure kubectl is configured."
    fi
    
    success "Applications configuration validation completed"
}

# Show applications status
show_applications_status() {
    log "Applications Status:"
    
    echo ""
    echo "=== ARGOCD APPLICATIONS ==="
    echo ""
    
    # Check ArgoCD applications
    if kubectl get applications -n argocd >/dev/null 2>&1; then
        kubectl get applications -n argocd
        echo ""
    else
        warning "Cannot get ArgoCD applications status"
    fi
    
    # Check monitoring pods
    if kubectl get pods -n monitoring >/dev/null 2>&1; then
        echo "=== MONITORING PODS ==="
        echo ""
        kubectl get pods -n monitoring
        echo ""
    else
        warning "Cannot get monitoring pods status"
    fi
    
    # Show access information
    echo "=== ACCESS INFORMATION ==="
    echo ""
    echo "Grafana:"
    echo "  kubectl port-forward svc/grafana -n monitoring 3000:80"
    echo "  http://localhost:3000"
    echo "  Username: admin"
    echo "  Password: admin123 (default - change in production!)"
    echo ""
    echo "Prometheus:"
    echo "  kubectl port-forward svc/prometheus-server -n monitoring 9090:9090"
    echo "  http://localhost:9090"
    echo ""
    echo "AlertManager:"
    echo "  kubectl port-forward svc/alertmanager -n monitoring 9093:9093"
    echo "  http://localhost:9093"
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
        validate_applications_config
        success "Validation completed successfully"
        exit 0
    fi
    
    # Exit if dry run only
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        deploy_applications
        success "Dry run completed successfully"
        exit 0
    fi
    
    # Deploy applications
    deploy_applications
    
    # Show status
    show_applications_status
    
    success "Applications deployment completed successfully!"
    log "Check $LOG_FILE for detailed logs"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
