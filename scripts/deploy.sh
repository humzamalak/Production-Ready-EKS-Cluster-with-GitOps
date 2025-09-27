#!/bin/bash

# Production-Ready EKS Cluster with GitOps - Main Deployment Script
# This script orchestrates the deployment of all components using modular scripts
#
# Usage: ./scripts/deploy.sh [OPTIONS]

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Default values
SKIP_INFRASTRUCTURE=false
SKIP_ARGOCD=false
SKIP_APPLICATIONS=false

# Help function
show_help() {
    show_help_header \
        "$(basename "$0")" \
        "Production-Ready EKS Cluster with GitOps - Main Deployment Script"
    
    cat << EOF
ADDITIONAL OPTIONS:
    -s, --skip-infra        Skip infrastructure deployment
    -a, --skip-argocd       Skip ArgoCD installation
    -p, --skip-apps         Skip application deployment
    --create-backend-only   Only create S3 bucket and DynamoDB table for Terraform backend

EXAMPLES:
    $0                      # Full deployment
    $0 --skip-infra         # Skip infrastructure, deploy ArgoCD and apps
    $0 --skip-argocd        # Skip ArgoCD, deploy infrastructure and apps
    $0 --skip-apps          # Skip applications, deploy infrastructure and ArgoCD
    $0 --validate-only      # Only validate prerequisites
    $0 --dry-run            # Show what would be deployed
    $0 -y                   # Full deployment with auto-approval
    $0 --create-backend-only # Only create Terraform backend resources

COMPONENT SCRIPTS:
    backend-management.sh    - Manages Terraform backend resources (S3, DynamoDB)
    infrastructure-deploy.sh - Deploys EKS cluster and infrastructure
    argocd-deploy.sh        - Installs and configures ArgoCD
    applications-deploy.sh  - Deploys applications via ArgoCD

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
            -s|--skip-infra)
                SKIP_INFRASTRUCTURE=true
                shift
                ;;
            -a|--skip-argocd)
                SKIP_ARGOCD=true
                shift
                ;;
            -p|--skip-apps)
                SKIP_APPLICATIONS=true
                shift
                ;;
            --create-backend-only)
                CREATE_BACKEND_ONLY=true
                shift
                ;;
            *)
                parse_common_args "$@"
                break
                ;;
        esac
    done
}

# Run component script with error handling
run_component_script() {
    local script_name="$1"
    local script_path="${SCRIPT_DIR}/${script_name}"
    shift
    
    if [[ ! -f "$script_path" ]]; then
        error "Component script not found: $script_path"
    fi
    
    if [[ ! -x "$script_path" ]]; then
        log "Making script executable: $script_path"
        chmod +x "$script_path"
    fi
    
    log "Running $script_name with arguments: $*"
    
    if ! "$script_path" "$@"; then
        error "Component script failed: $script_name"
    fi
    
    success "Component script completed: $script_name"
}

# Deploy backend resources
deploy_backend() {
    log "=== DEPLOYING BACKEND RESOURCES ==="
    run_component_script "backend-management.sh" "$@"
}

# Deploy infrastructure
deploy_infrastructure() {
    if [[ "$SKIP_INFRASTRUCTURE" == "true" ]]; then
        log "Skipping infrastructure deployment"
        return 0
    fi
    
    log "=== DEPLOYING INFRASTRUCTURE ==="
    run_component_script "infrastructure-deploy.sh" "$@"
}

# Deploy ArgoCD
deploy_argocd() {
    if [[ "$SKIP_ARGOCD" == "true" ]]; then
        log "Skipping ArgoCD deployment"
        return 0
    fi
    
    log "=== DEPLOYING ARGOCD ==="
    run_component_script "argocd-deploy.sh" "$@"
}

# Deploy applications
deploy_applications() {
    if [[ "$SKIP_APPLICATIONS" == "true" ]]; then
        log "Skipping application deployment"
        return 0
    fi
    
    log "=== DEPLOYING APPLICATIONS ==="
    run_component_script "applications-deploy.sh" "$@"
}

# Validate all components
validate_all_components() {
    log "=== VALIDATING ALL COMPONENTS ==="
    
    # Validate prerequisites
    validate_prerequisites
    
    # Validate backend
    log "Validating backend configuration..."
    run_component_script "backend-management.sh" --validate-only
    
    # Validate infrastructure
    if [[ "$SKIP_INFRASTRUCTURE" != "true" ]]; then
        log "Validating infrastructure configuration..."
        run_component_script "infrastructure-deploy.sh" --validate-only
    fi
    
    # Validate ArgoCD
    if [[ "$SKIP_ARGOCD" != "true" ]]; then
        log "Validating ArgoCD configuration..."
        run_component_script "argocd-deploy.sh" --validate-only
    fi
    
    # Validate applications
    if [[ "$SKIP_APPLICATIONS" != "true" ]]; then
        log "Validating applications configuration..."
        run_component_script "applications-deploy.sh" --validate-only
    fi
    
    success "All components validation completed"
}

# Dry run all components
dry_run_all_components() {
    log "=== DRY RUNNING ALL COMPONENTS ==="
    
    # Dry run backend
    log "Dry running backend deployment..."
    run_component_script "backend-management.sh" --dry-run
    
    # Dry run infrastructure
    if [[ "$SKIP_INFRASTRUCTURE" != "true" ]]; then
        log "Dry running infrastructure deployment..."
        run_component_script "infrastructure-deploy.sh" --dry-run
    fi
    
    # Dry run ArgoCD
    if [[ "$SKIP_ARGOCD" != "true" ]]; then
        log "Dry running ArgoCD deployment..."
        run_component_script "argocd-deploy.sh" --dry-run
    fi
    
    # Dry run applications
    if [[ "$SKIP_APPLICATIONS" != "true" ]]; then
        log "Dry running applications deployment..."
        run_component_script "applications-deploy.sh" --dry-run
    fi
    
    success "All components dry run completed"
}

# Main deployment function
main_deployment() {
    log "=== STARTING MAIN DEPLOYMENT ==="
    
    # Deploy backend resources
    deploy_backend "$@"
    
    # Deploy infrastructure
    deploy_infrastructure "$@"
    
    # Deploy ArgoCD
    deploy_argocd "$@"
    
    # Deploy applications
    deploy_applications "$@"
    
    success "Main deployment completed successfully!"
}

# Show final access information
show_final_access_info() {
    log "=== DEPLOYMENT COMPLETED ==="
    
    echo ""
    echo "🎉 Production-Ready EKS Cluster with GitOps deployed successfully!"
    echo ""
    
    # Show access information from common library
    show_access_info
    
    echo "=== NEXT STEPS ==="
    echo ""
    echo "1. Access ArgoCD UI to monitor your applications"
    echo "2. Set up Grafana dashboards for monitoring"
    echo "3. Configure alerting rules in Prometheus"
    echo "4. Review security policies and network configurations"
    echo "5. Set up CI/CD pipelines to deploy your applications"
    echo ""
    echo "📚 Documentation:"
    echo "  - README.md for general information"
    echo "  - docs/ directory for detailed guides"
    echo "  - Check logs at: $LOG_FILE"
    echo ""
}

# Main function
main() {
    # Initialize log file
    init_log_file
    
    # Parse arguments
    parse_args "$@"
    
    # Exit if validation only
    if [[ "${VALIDATE_ONLY:-false}" == "true" ]]; then
        validate_all_components
        success "Validation completed successfully"
        exit 0
    fi
    
    # Exit if backend creation only
    if [[ "${CREATE_BACKEND_ONLY:-false}" == "true" ]]; then
        deploy_backend "$@"
        success "Backend resources creation completed successfully"
        exit 0
    fi
    
    # Exit if dry run only
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        dry_run_all_components
        success "Dry run completed successfully"
        exit 0
    fi
    
    # Main deployment
    main_deployment "$@"
    
    # Show final access information
    show_final_access_info
    
    log "Check $LOG_FILE for detailed logs"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
