#!/bin/bash

# Production-Ready EKS Cluster with GitOps - Automated Deployment Script
# This script automates the entire deployment process from infrastructure to applications

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
ARGO_CD_DIR="${SCRIPT_DIR}/argo-cd"
LOG_FILE="${SCRIPT_DIR}/deployment.log"

# Default values
SKIP_INFRASTRUCTURE=false
SKIP_ARGOCD=false
SKIP_APPLICATIONS=false
AUTO_APPROVE=false
VERBOSE=false
CREATE_BACKEND_ONLY=false
DRY_RUN=false

# Logging function
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

# Help function
show_help() {
    cat << EOF
Production-Ready EKS Cluster with GitOps - Deployment Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -s, --skip-infra        Skip infrastructure deployment
    -a, --skip-argocd       Skip ArgoCD installation
    -p, --skip-apps         Skip application deployment
    -y, --auto-approve      Auto-approve Terraform apply
    -v, --verbose           Enable verbose output
    --validate-only         Only validate prerequisites and configuration
    --dry-run               Show what would be deployed without actually deploying
    --create-backend-only   Only create S3 bucket and DynamoDB table for Terraform backend

EXAMPLES:
    $0                      # Full deployment
    $0 --skip-infra         # Skip infrastructure, deploy ArgoCD and apps
    $0 --validate-only      # Only validate prerequisites
    $0 --dry-run            # Show what would be deployed
    $0 -y                   # Full deployment with auto-approval
    $0 --create-backend-only # Only create Terraform backend resources

PREREQUISITES:
    - AWS CLI configured with appropriate permissions
    - kubectl, Helm, Terraform installed
    - terraform/terraform.tfvars configured
    - IAM role for VPC flow logs created

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
            -y|--auto-approve)
                AUTO_APPROVE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --validate-only)
                VALIDATE_ONLY=true
                shift
                ;;
            --create-backend-only)
                CREATE_BACKEND_ONLY=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
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
    
    # Check if backend resources exist (optional validation)
    if [[ -f "${TERRAFORM_DIR}/terraform.tfvars" ]]; then
        local project_prefix environment aws_region
        project_prefix=$(grep '^project_prefix' "${TERRAFORM_DIR}/terraform.tfvars" | cut -d'"' -f2)
        environment=$(grep '^environment' "${TERRAFORM_DIR}/terraform.tfvars" | cut -d'"' -f2)
        aws_region=$(grep '^aws_region' "${TERRAFORM_DIR}/terraform.tfvars" | cut -d'"' -f2)
        
        local bucket_name table_name
        bucket_name="${project_prefix}-${environment}-tfstate"
        table_name="${project_prefix}-${environment}-tflock"
        
        # Check S3 bucket (try multiple regions)
        local bucket_exists=false
        local bucket_region=""
        
        # Try the configured region first
        if aws s3api head-bucket --bucket "$bucket_name" --region "$aws_region" 2>/dev/null; then
            bucket_exists=true
            # Get the actual bucket region from the response
            bucket_region=$(aws s3api head-bucket --bucket "$bucket_name" --region "$aws_region" 2>&1 | grep -o '"BucketRegion": "[^"]*"' | cut -d'"' -f4)
            log "Backend S3 bucket ${bucket_name} exists in ${bucket_region}"
        # Try us-east-1 (common for S3 buckets)
        elif aws s3api head-bucket --bucket "$bucket_name" --region us-east-1 2>/dev/null; then
            bucket_exists=true
            bucket_region="us-east-1"
            log "Backend S3 bucket ${bucket_name} exists in us-east-1"
        else
            log "Backend S3 bucket ${bucket_name} does not exist (will be created in ${aws_region})"
        fi
        
        # Check DynamoDB table
        if aws dynamodb describe-table --table-name "$table_name" --region "$aws_region" >/dev/null 2>&1; then
            log "Backend DynamoDB table ${table_name} exists"
        else
            log "Backend DynamoDB table ${table_name} does not exist (will be created)"
        fi
    fi
    
    success "Prerequisites validation completed"
}

# Create Terraform backend resources (S3 bucket and DynamoDB table)
create_backend_resources() {
    log "Creating Terraform backend resources..."
    
    # Read configuration from terraform.tfvars
    local project_prefix environment aws_region
    project_prefix=$(grep '^project_prefix' "${TERRAFORM_DIR}/terraform.tfvars" | cut -d'"' -f2)
    environment=$(grep '^environment' "${TERRAFORM_DIR}/terraform.tfvars" | cut -d'"' -f2)
    aws_region=$(grep '^aws_region' "${TERRAFORM_DIR}/terraform.tfvars" | cut -d'"' -f2)
    
    # Generate resource names
    local bucket_name table_name
    bucket_name="${project_prefix}-${environment}-tfstate"
    table_name="${project_prefix}-${environment}-tflock"
    
    log "Backend resources to create:"
    log "  S3 Bucket: ${bucket_name}"
    log "  DynamoDB Table: ${table_name}"
    log "  Region: ${aws_region}"
    
    # Check if S3 bucket already exists
    if aws s3api head-bucket --bucket "$bucket_name" --region "$aws_region" 2>/dev/null; then
        log "S3 bucket ${bucket_name} already exists"
    else
        log "Creating S3 bucket: ${bucket_name}"
        if [[ "$aws_region" == "us-east-1" ]]; then
            # us-east-1 doesn't need LocationConstraint
            aws s3api create-bucket --bucket "$bucket_name" --region "$aws_region"
        else
            # For eu-west-1 and other regions, use LocationConstraint
            aws s3api create-bucket --bucket "$bucket_name" --region "$aws_region" \
                --create-bucket-configuration LocationConstraint="$aws_region"
        fi
        
        # Enable versioning
        aws s3api put-bucket-versioning --bucket "$bucket_name" \
            --versioning-configuration Status=Enabled
        
        # Enable server-side encryption
        aws s3api put-bucket-encryption --bucket "$bucket_name" \
            --server-side-encryption-configuration '{
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256"
                        }
                    }
                ]
            }'
        
        # Block public access
        aws s3api put-public-access-block --bucket "$bucket_name" \
            --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
        
        success "S3 bucket ${bucket_name} created successfully"
    fi
    
    # Check if DynamoDB table already exists
    if aws dynamodb describe-table --table-name "$table_name" --region "$aws_region" >/dev/null 2>&1; then
        log "DynamoDB table ${table_name} already exists"
    else
        log "Creating DynamoDB table: ${table_name}"
        aws dynamodb create-table \
            --table-name "$table_name" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
            --region "$aws_region" \
            --tags Key=Name,Value="${table_name}" Key=Environment,Value="${environment}" Key=Project,Value="${project_prefix}"
        
        # Wait for table to be active
        log "Waiting for DynamoDB table to be active..."
        aws dynamodb wait table-exists --table-name "$table_name" --region "$aws_region"
        
        success "DynamoDB table ${table_name} created successfully"
    fi
    
    # Store backend configuration for later use
    echo "bucket_name=${bucket_name}" > "${SCRIPT_DIR}/backend-config.env"
    echo "table_name=${table_name}" >> "${SCRIPT_DIR}/backend-config.env"
    echo "aws_region=${aws_region}" >> "${SCRIPT_DIR}/backend-config.env"
    
    success "Backend resources creation completed"
}

# Handle Terraform state and backend issues
handle_terraform_state() {
    log "Handling Terraform state and backend configuration..."
    
    cd "$TERRAFORM_DIR"
    
    # Load backend configuration
    if [[ ! -f "${SCRIPT_DIR}/backend-config.env" ]]; then
        error "Backend configuration not found. Run create_backend_resources first."
    fi
    
    source "${SCRIPT_DIR}/backend-config.env"
    
    # Check if we have a valid Terraform state
    local state_valid=false
    
    # Try to access current state
    if terraform show >/dev/null 2>&1; then
        log "Terraform state is accessible"
        state_valid=true
    else
        log "Terraform state is not accessible, attempting to initialize..."
        
        # Check if backend resources exist
        if aws s3api head-bucket --bucket "$bucket_name" --region "$aws_region" 2>/dev/null; then
            log "Backend resources exist, initializing Terraform..."
            
            # Try to initialize with backend
            if terraform init \
                -backend-config="bucket=${bucket_name}" \
                -backend-config="key=${environment}/terraform.tfstate" \
                -backend-config="region=${aws_region}" \
                -backend-config="dynamodb_table=${table_name}" \
                -backend-config="encrypt=true" >/dev/null 2>&1; then
                
                # Test if state is now accessible
                if terraform show >/dev/null 2>&1; then
                    log "Successfully initialized Terraform state"
                    state_valid=true
                else
                    log "Still cannot access state after initialization"
                fi
            else
                log "Failed to initialize with backend"
            fi
        else
            log "Backend resources do not exist, state may be lost"
        fi
    fi
    
    if [[ "$state_valid" == "false" ]]; then
        warning "Cannot access Terraform state. This may mean:"
        warning "1. The infrastructure was never deployed"
        warning "2. The state file is corrupted or lost"
        warning "3. Backend resources were deleted"
        warning ""
        warning "Proceeding with fresh initialization..."
        
        # Initialize without state
        terraform init \
            -backend-config="bucket=${bucket_name}" \
            -backend-config="key=${environment}/terraform.tfstate" \
            -backend-config="region=${aws_region}" \
            -backend-config="dynamodb_table=${table_name}" \
            -backend-config="encrypt=true"
    fi
    
    return 0
}

# Initialize Terraform with backend configuration
initialize_terraform_backend() {
    log "Initializing Terraform with backend configuration..."
    
    cd "$TERRAFORM_DIR"
    
    # Load backend configuration
    if [[ ! -f "${SCRIPT_DIR}/backend-config.env" ]]; then
        error "Backend configuration not found. Run create_backend_resources first."
    fi
    
    source "${SCRIPT_DIR}/backend-config.env"
    
    # Initialize Terraform with backend configuration
    log "Initializing Terraform backend..."
    terraform init \
        -backend-config="bucket=${bucket_name}" \
        -backend-config="key=${environment}/terraform.tfstate" \
        -backend-config="region=${aws_region}" \
        -backend-config="dynamodb_table=${table_name}" \
        -backend-config="encrypt=true"
    
    success "Terraform backend initialized successfully"
}

# Deploy infrastructure
deploy_infrastructure() {
    if [[ "$SKIP_INFRASTRUCTURE" == "true" ]]; then
        log "Skipping infrastructure deployment"
        return 0
    fi
    
    log "Deploying infrastructure with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Create backend resources first
    create_backend_resources
    
    # Handle Terraform state and backend issues
    handle_terraform_state
    
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
        if ! terraform apply tfplan; then
            error "Terraform apply failed. Check the logs and try again."
        fi
    else
        log "Applying Terraform plan..."
        if ! terraform apply -var-file="terraform.tfvars"; then
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
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if kubectl get nodes >/dev/null 2>&1; then
            success "Successfully connected to EKS cluster"
            break
        fi
        
        log "Attempt $attempt/$max_attempts: Waiting for cluster to be ready..."
        sleep 30
        ((attempt++))
        
        if [[ $attempt -gt $max_attempts ]]; then
            error "Failed to access EKS cluster after $max_attempts attempts"
        fi
    done
    
    success "Infrastructure deployment completed"
}

# Deploy ArgoCD
deploy_argocd() {
    if [[ "$SKIP_ARGOCD" == "true" ]]; then
        log "Skipping ArgoCD deployment"
        return 0
    fi
    
    log "Deploying ArgoCD..."
    
    # Add ArgoCD Helm repository
    log "Adding ArgoCD Helm repository..."
    if ! helm repo add argo https://argoproj.github.io/argo-helm; then
        error "Failed to add ArgoCD Helm repository"
    fi
    
    if ! helm repo update; then
        error "Failed to update Helm repositories"
    fi
    
    # Install ArgoCD
    log "Installing ArgoCD with Helm..."
    if ! helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        --values "${ARGO_CD_DIR}/bootstrap/values.yaml" \
        --wait \
        --timeout=10m; then
        error "Failed to install ArgoCD with Helm"
    fi
    
    # Wait for ArgoCD to be ready
    log "Waiting for ArgoCD to be ready..."
    if ! kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd; then
        error "ArgoCD server failed to become available within timeout"
    fi
    
    # Get admin password
    log "Retrieving ArgoCD admin password..."
    local admin_password
    admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Password not available")
    
    if [[ -n "$admin_password" ]]; then
        echo "ArgoCD Admin Password: $admin_password" | tee -a "$LOG_FILE"
        echo "$admin_password" > "${SCRIPT_DIR}/argocd-admin-password.txt"
        chmod 600 "${SCRIPT_DIR}/argocd-admin-password.txt"
    fi
    
    success "ArgoCD deployment completed"
}

# Deploy applications
deploy_applications() {
    if [[ "$SKIP_APPLICATIONS" == "true" ]]; then
        log "Skipping application deployment"
        return 0
    fi
    
    log "Deploying applications with ArgoCD..."
    
    # Apply root application
    log "Applying root application (app-of-apps pattern)..."
    if ! kubectl apply -f "${ARGO_CD_DIR}/apps/root-app.yaml"; then
        error "Failed to apply root application"
    fi
    
    # Wait for applications to be created
    log "Waiting for applications to be created..."
    sleep 30
    
    # Monitor application deployment
    log "Monitoring application deployment..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        local total_apps synced_apps
        total_apps=$(kubectl get applications -n argocd --no-headers | wc -l)
        synced_apps=$(kubectl get applications -n argocd --no-headers | grep -c "Synced" || echo "0")
        
        log "Application sync progress: $synced_apps/$total_apps applications synced (attempt $attempt/$max_attempts)"
        
        if [[ "$synced_apps" -eq "$total_apps" ]] && [[ "$total_apps" -gt 0 ]]; then
            success "All applications synced successfully"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            warning "Not all applications synced within timeout. Check ArgoCD UI for details."
            kubectl get applications -n argocd
            break
        fi
        
        sleep 30
        ((attempt++))
    done
    
    success "Application deployment completed"
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
    echo "View logs:"
    echo "  tail -f $LOG_FILE"
    echo ""
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    rm -f "${TERRAFORM_DIR}/tfplan"
    rm -f "${SCRIPT_DIR}/backend-config.env"
}

# Main function
main() {
    # Initialize log file
    echo "Deployment started at $(date)" > "$LOG_FILE"
    
    # Parse arguments
    parse_args "$@"
    
    # Set verbose mode
    if [[ "$VERBOSE" == "true" ]]; then
        set -x
    fi
    
    # Validate prerequisites
    validate_prerequisites
    
    # Exit if validation only
    if [[ "${VALIDATE_ONLY:-false}" == "true" ]]; then
        success "Validation completed successfully"
        exit 0
    fi
    
    # Exit if backend creation only
    if [[ "${CREATE_BACKEND_ONLY:-false}" == "true" ]]; then
        create_backend_resources
        success "Backend resources creation completed successfully"
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
    
    # Deploy ArgoCD
    deploy_argocd
    
    # Deploy applications
    deploy_applications
    
    # Show access information
    show_access_info
    
    # Cleanup
    cleanup
    
    success "Deployment completed successfully!"
    log "Check $LOG_FILE for detailed logs"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
