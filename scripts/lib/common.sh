#!/bin/bash

# Production-Ready EKS Cluster with GitOps - Common Library
# This script contains shared functions used across all deployment scripts
#
# Usage: source this script in other deployment scripts

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
ARGO_CD_DIR="${SCRIPT_DIR}/argo-cd"
LOG_FILE="${SCRIPT_DIR}/deployment.log"

# Default values
VERBOSE=false
AUTO_APPROVE=false

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate prerequisites
validate_prerequisites() {
    log "Validating prerequisites..."
    
    # Check required commands
    local missing_commands=()
    
    if ! command_exists aws; then
        missing_commands+=("aws")
    fi
    
    if ! command_exists kubectl; then
        missing_commands+=("kubectl")
    fi
    
    if ! command_exists helm; then
        missing_commands+=("helm")
    fi
    
    if ! command_exists terraform; then
        missing_commands+=("terraform")
    fi
    
    if ! command_exists git; then
        missing_commands+=("git")
    fi
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing_commands[*]}"
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        error "AWS credentials not configured or invalid"
    fi
    
    # Check terraform.tfvars exists
    if [[ ! -f "${TERRAFORM_DIR}/terraform.tfvars" ]]; then
        error "terraform.tfvars not found in ${TERRAFORM_DIR}"
    fi
    
    # Check for placeholder values in terraform.tfvars
    if grep -q "123456789012" "${TERRAFORM_DIR}/terraform.tfvars"; then
        warning "Placeholder AWS account ID found in terraform.tfvars"
    fi
    
    if grep -q "YOUR_ORG" "${ARGO_CD_DIR}/apps/root-app.yaml"; then
        warning "Placeholder YOUR_ORG found in ArgoCD manifests"
    fi
    
    # Check Terraform version
    local terraform_version
    terraform_version=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
    if [[ "$terraform_version" == "unknown" ]] || [[ "$(echo "$terraform_version" | cut -d. -f1)" -lt 1 ]] || [[ "$(echo "$terraform_version" | cut -d. -f2)" -lt 4 ]]; then
        warning "Terraform version $terraform_version may not be compatible (requires >=1.4.0)"
    fi
    
    success "Prerequisites validation completed"
}

# Read Terraform configuration
read_terraform_config() {
    local project_prefix environment aws_region
    project_prefix=$(grep '^project_prefix' "${TERRAFORM_DIR}/terraform.tfvars" | cut -d'"' -f2)
    environment=$(grep '^environment' "${TERRAFORM_DIR}/terraform.tfvars" | cut -d'"' -f2)
    aws_region=$(grep '^aws_region' "${TERRAFORM_DIR}/terraform.tfvars" | cut -d'"' -f2)
    
    # Generate resource names
    local bucket_name table_name
    bucket_name="${project_prefix}-${environment}-tfstate"
    table_name="${project_prefix}-${environment}-tflock"
    
    # Export variables for use in calling script
    export PROJECT_PREFIX="$project_prefix"
    export ENVIRONMENT="$environment"
    export AWS_REGION="$aws_region"
    export BUCKET_NAME="$bucket_name"
    export TABLE_NAME="$table_name"
}

# Parse common command line arguments
parse_common_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -y|--auto-approve)
                AUTO_APPROVE=true
                shift
                ;;
            --validate-only)
                VALIDATE_ONLY=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                # Unknown option, let calling script handle it
                break
                ;;
        esac
    done
    
    # Set verbose mode
    if [[ "$VERBOSE" == "true" ]]; then
        set -x
    fi
}

# Show help header
show_help_header() {
    local script_name="$1"
    local description="$2"
    
    cat << EOF
$description

USAGE:
    $script_name [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -y, --auto-approve      Auto-approve operations
    --validate-only         Only validate prerequisites and configuration
    --dry-run               Show what would be deployed without actually deploying

PREREQUISITES:
    - AWS CLI configured with appropriate permissions
    - kubectl, Helm, Terraform installed
    - terraform/terraform.tfvars configured

EOF
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    rm -f "${TERRAFORM_DIR}/tfplan"
    rm -f "${SCRIPT_DIR}/backend-config.env"
}

# Initialize log file
init_log_file() {
    echo "Deployment started at $(date)" > "$LOG_FILE"
}

# Wait for kubectl to be ready
wait_for_kubectl() {
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if kubectl get nodes >/dev/null 2>&1; then
            success "Successfully connected to EKS cluster"
            return 0
        fi
        
        log "Attempt $attempt/$max_attempts: Waiting for cluster to be ready..."
        sleep 30
        ((attempt++))
        
        if [[ $attempt -gt $max_attempts ]]; then
            error "Failed to access EKS cluster after $max_attempts attempts"
        fi
    done
}

# Show access information
show_access_info() {
    log "Deployment completed! Access information:"
    
    echo ""
    echo "=== ACCESS INFORMATION ==="
    echo ""
    
    echo "ArgoCD UI:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  https://localhost:8080"
    echo "  Username: admin"
    echo "  Password: $(cat "${SCRIPT_DIR}/argocd-admin-password.txt" 2>/dev/null || echo "Check log file")"
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
    
    echo "=== USEFUL COMMANDS ==="
    echo ""
    echo "Check cluster status:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods -A"
    echo ""
    echo "Check ArgoCD applications:"
    echo "  kubectl get applications -n argocd"
    echo ""
    echo "Check monitoring pods:"
    echo "  kubectl get pods -n monitoring"
    echo ""
    echo "View logs:"
    echo "  tail -f $LOG_FILE"
    echo ""
}
