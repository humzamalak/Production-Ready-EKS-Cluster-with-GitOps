#!/bin/bash

# Production-Ready EKS Cluster with GitOps - Infrastructure Deployment Script
# This script deploys the EKS cluster and associated infrastructure using Terraform
#
# Usage: ./scripts/infrastructure-deploy.sh [OPTIONS]

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Help function
show_help() {
    show_help_header \
        "$(basename "$0")" \
        "Production-Ready EKS Cluster with GitOps - Infrastructure Deployment Script"
    
    cat << EOF
EXAMPLES:
    $0                      # Deploy infrastructure
    $0 --validate-only      # Only validate prerequisites and configuration
    $0 --dry-run            # Show what would be deployed
    $0 -v                   # Verbose output
    $0 -y                   # Auto-approve Terraform apply

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

# Initialize Terraform with backend configuration
initialize_terraform_backend() {
    log "Initializing Terraform with backend configuration..."
    
    cd "$TERRAFORM_DIR"
    
    # Load backend configuration or read from terraform.tfvars
    if [[ -f "${SCRIPT_DIR}/backend-config.env" ]]; then
        source "${SCRIPT_DIR}/backend-config.env"
    else
        read_terraform_config
    fi
    
    # Initialize Terraform with backend configuration
    log "Initializing Terraform backend..."
    terraform init \
        -backend-config="bucket=${BUCKET_NAME}" \
        -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
        -backend-config="region=${AWS_REGION}" \
        -backend-config="dynamodb_table=${TABLE_NAME}" \
        -backend-config="encrypt=true"
    
    success "Terraform backend initialized successfully"
}

# Deploy infrastructure
deploy_infrastructure() {
    log "Deploying infrastructure with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform backend
    initialize_terraform_backend
    
    # Validate Terraform configuration
    log "Validating Terraform configuration..."
    terraform validate
    
    # Plan deployment
    log "Creating Terraform plan..."
    if ! terraform plan -var-file="terraform.tfvars" -out=tfplan; then
        error "Terraform plan failed. Check your configuration and try again."
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would deploy the following resources:"
        terraform show tfplan
        return 0
    fi
    
    # Apply infrastructure
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        log "Applying Terraform plan (auto-approved)..."
        if ! terraform apply -auto-approve tfplan; then
            error "Terraform apply failed. Check the logs and try again."
        fi
    else
        log "Applying Terraform plan (interactive)..."
        if ! terraform apply tfplan; then
            error "Terraform apply failed. Check the logs and try again."
        fi
    fi
    
    # Save outputs
    log "Saving Terraform outputs..."
    terraform output -json > "${SCRIPT_DIR}/terraform-outputs.json"
    
    # Configure kubectl
    log "Configuring kubectl for EKS cluster..."
    local aws_region cluster_name
    aws_region=$(terraform output -raw aws_region)
    cluster_name=$(terraform output -raw cluster_name)
    
    if ! aws eks update-kubeconfig --region "$aws_region" --name "$cluster_name"; then
        error "Failed to configure kubectl for EKS cluster"
    fi
    
    # Verify cluster access
    log "Verifying cluster access..."
    wait_for_kubectl
    
    success "Infrastructure deployment completed"
}

# Validate infrastructure configuration
validate_infrastructure_config() {
    log "Validating infrastructure configuration..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if Terraform files exist
    if [[ ! -f "main.tf" ]]; then
        error "Terraform main.tf not found"
    fi
    
    if [[ ! -f "variables.tf" ]]; then
        error "Terraform variables.tf not found"
    fi
    
    if [[ ! -f "terraform.tfvars" ]]; then
        error "Terraform terraform.tfvars not found"
    fi
    
    # Initialize Terraform backend for validation
    initialize_terraform_backend
    
    # Validate Terraform configuration
    log "Validating Terraform configuration..."
    if ! terraform validate; then
        error "Terraform configuration validation failed"
    fi
    
    # Format check
    log "Checking Terraform formatting..."
    if ! terraform fmt -check; then
        warning "Terraform files are not properly formatted. Run 'terraform fmt' to fix."
    fi
    
    success "Infrastructure configuration validation completed"
}

# Show infrastructure status
show_infrastructure_status() {
    log "Infrastructure Status:"
    
    cd "$TERRAFORM_DIR"
    
    if [[ -f "${SCRIPT_DIR}/terraform-outputs.json" ]]; then
        echo ""
        echo "=== TERRAFORM OUTPUTS ==="
        echo ""
        terraform output
        echo ""
    fi
    
    # Check cluster status
    if kubectl get nodes >/dev/null 2>&1; then
        echo "=== CLUSTER STATUS ==="
        echo ""
        kubectl get nodes
        echo ""
        kubectl get namespaces
        echo ""
    else
        warning "Cannot connect to cluster. Make sure kubectl is configured."
    fi
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
        validate_infrastructure_config
        success "Validation completed successfully"
        exit 0
    fi
    
    # Exit if dry run only
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        deploy_infrastructure
        success "Dry run completed successfully"
        exit 0
    fi
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Show status
    show_infrastructure_status
    
    success "Infrastructure deployment completed successfully!"
    log "Check $LOG_FILE for detailed logs"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
