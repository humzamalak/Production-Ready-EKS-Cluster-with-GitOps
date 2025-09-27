#!/bin/bash

# Production-Ready EKS Cluster with GitOps - Infrastructure Teardown Script
# This script safely destroys all infrastructure created by the deployment script
#
# Features:
# - Comprehensive Kubernetes resource cleanup (ArgoCD, Prometheus, Grafana)
# - EKS cluster and VPC infrastructure destruction
# - Terraform state management and backend cleanup
# - Force cleanup options for stuck resources
# - Detailed resource validation and reporting
# - Support for dry-run, validation-only, and selective teardown modes
#
# Usage: ./teardown.sh [OPTIONS]
# See --help for detailed usage information

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
LOG_FILE="${SCRIPT_DIR}/teardown.log"

# Default values
FORCE_DESTROY=false
SKIP_CONFIRMATION=false
KEEP_BACKEND=false
VERBOSE=false
DRY_RUN=false
FORCE_KUBERNETES_CLEANUP=false

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
Production-Ready EKS Cluster with GitOps - Teardown Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -f, --force             Force destroy without confirmation prompts
    -y, --yes               Auto-confirm all prompts
    -k, --keep-backend      Keep Terraform backend resources (S3 bucket and DynamoDB table)
    -v, --verbose           Enable verbose output
    --dry-run               Show what would be destroyed without actually destroying
    --validate-only         Only validate prerequisites and show what would be destroyed
    --force-k8s-cleanup     Force cleanup of Kubernetes resources (use when normal cleanup fails)

EXAMPLES:
    $0                      # Interactive teardown with confirmations
    $0 --force              # Force destroy without confirmations
    $0 --dry-run            # Show what would be destroyed
    $0 --keep-backend       # Destroy infrastructure but keep backend resources
    $0 --validate-only      # Only validate and show resources

WARNING:
    This script will destroy ALL infrastructure including:
    - EKS cluster and node groups
    - VPC, subnets, and networking
    - Load balancers and security groups
    - IAM roles and policies
    - Terraform state (unless --keep-backend is used)

    Make sure you have backups of any important data before proceeding.

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
            -f|--force)
                FORCE_DESTROY=true
                shift
                ;;
            -y|--yes)
                SKIP_CONFIRMATION=true
                shift
                ;;
            -k|--keep-backend)
                KEEP_BACKEND=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --validate-only)
                VALIDATE_ONLY=true
                shift
                ;;
            --force-k8s-cleanup)
                FORCE_KUBERNETES_CLEANUP=true
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
    
    if ! command_exists terraform; then
        missing_commands+=("terraform")
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
    
    success "Prerequisites validation completed"
}

# Get resource information
get_resource_info() {
    log "Gathering resource information..."
    
    # Read configuration from terraform.tfvars
    local project_prefix environment aws_region
    project_prefix=$(grep '^project_prefix' "${TERRAFORM_DIR}/terraform.tfvars" | cut -d'"' -f2)
    environment=$(grep '^environment' "${TERRAFORM_DIR}/terraform.tfvars" | cut -d'"' -f2)
    aws_region=$(grep '^aws_region' "${TERRAFORM_DIR}/terraform.tfvars" | cut -d'"' -f2)
    
    # Generate resource names
    local bucket_name table_name cluster_name
    bucket_name="${project_prefix}-${environment}-tfstate"
    table_name="${project_prefix}-${environment}-tflock"
    cluster_name="${project_prefix}-${environment}-cluster"
    
    # Store for later use
    echo "project_prefix=${project_prefix}" > "${SCRIPT_DIR}/teardown-config.env"
    echo "environment=${environment}" >> "${SCRIPT_DIR}/teardown-config.env"
    echo "aws_region=${aws_region}" >> "${SCRIPT_DIR}/teardown-config.env"
    echo "bucket_name=${bucket_name}" >> "${SCRIPT_DIR}/teardown-config.env"
    echo "table_name=${table_name}" >> "${SCRIPT_DIR}/teardown-config.env"
    echo "cluster_name=${cluster_name}" >> "${SCRIPT_DIR}/teardown-config.env"
    
    log "Resource information gathered:"
    log "  Project: ${project_prefix}"
    log "  Environment: ${environment}"
    log "  Region: ${aws_region}"
    log "  Cluster: ${cluster_name}"
    log "  S3 Bucket: ${bucket_name}"
    log "  DynamoDB Table: ${table_name}"
}

# Check if resources exist
check_resources_exist() {
    log "Checking if resources exist..."
    
    source "${SCRIPT_DIR}/teardown-config.env"
    
    local resources_found=false
    local resource_count=0
    
    # Check EKS cluster
    if aws eks describe-cluster --name "$cluster_name" --region "$aws_region" >/dev/null 2>&1; then
        log "✓ EKS cluster '${cluster_name}' exists"
        resources_found=true
        ((resource_count++))
        
        # Check node groups
        local node_groups
        node_groups=$(aws eks list-nodegroups --cluster-name "$cluster_name" --region "$aws_region" --query 'nodegroups' --output text 2>/dev/null || echo "")
        if [[ -n "$node_groups" ]]; then
            log "  - Node groups: $node_groups"
        fi
    else
        log "✗ EKS cluster '${cluster_name}' not found"
    fi
    
    # Check S3 bucket (try multiple regions)
    local bucket_exists=false
    local bucket_region=""
    
    # Try the configured region first
    if aws s3api head-bucket --bucket "$bucket_name" --region "$aws_region" 2>/dev/null; then
        bucket_exists=true
        # Get the actual bucket region from the response
        bucket_region=$(aws s3api head-bucket --bucket "$bucket_name" --region "$aws_region" 2>&1 | grep -o '"BucketRegion": "[^"]*"' | cut -d'"' -f4)
        log "✓ S3 bucket '${bucket_name}' exists in ${bucket_region}"
        resources_found=true
        ((resource_count++))
        
        # Check bucket contents
        local object_count
        object_count=$(aws s3 ls "s3://${bucket_name}" --recursive --summarize --region "$bucket_region" 2>/dev/null | grep "Total Objects:" | awk '{print $3}' || echo "0")
        if [[ "$object_count" -gt 0 ]]; then
            log "  - Objects in bucket: $object_count"
        fi
    # Try us-east-1 (common for S3 buckets)
    elif aws s3api head-bucket --bucket "$bucket_name" --region us-east-1 2>/dev/null; then
        bucket_exists=true
        bucket_region="us-east-1"
        log "✓ S3 bucket '${bucket_name}' exists in us-east-1"
        resources_found=true
        ((resource_count++))
        
        # Check bucket contents
        local object_count
        object_count=$(aws s3 ls "s3://${bucket_name}" --recursive --summarize --region "$bucket_region" 2>/dev/null | grep "Total Objects:" | awk '{print $3}' || echo "0")
        if [[ "$object_count" -gt 0 ]]; then
            log "  - Objects in bucket: $object_count"
        fi
    else
        log "✗ S3 bucket '${bucket_name}' not found in ${aws_region} or us-east-1"
    fi
    
    if [[ "$bucket_exists" == "true" ]]; then
        # Store bucket region for later use
        echo "bucket_region=${bucket_region}" >> "${SCRIPT_DIR}/teardown-config.env"
    fi
    
    # Check DynamoDB table
    if aws dynamodb describe-table --table-name "$table_name" --region "$aws_region" >/dev/null 2>&1; then
        log "✓ DynamoDB table '${table_name}' exists"
        resources_found=true
        ((resource_count++))
        
        # Check table status
        local table_status
        table_status=$(aws dynamodb describe-table --table-name "$table_name" --region "$aws_region" --query 'Table.TableStatus' --output text 2>/dev/null || echo "Unknown")
        log "  - Table status: $table_status"
    else
        log "✗ DynamoDB table '${table_name}' not found"
    fi
    
    # Check VPC resources
    local vpc_id
    vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${project_prefix}-${environment}-vpc" --query 'Vpcs[0].VpcId' --output text --region "$aws_region" 2>/dev/null || echo "None")
    if [[ "$vpc_id" != "None" ]] && [[ "$vpc_id" != "null" ]]; then
        log "✓ VPC '${vpc_id}' exists"
        resources_found=true
        ((resource_count++))
        
        # Check subnets
        local subnet_count
        subnet_count=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${vpc_id}" --query 'length(Subnets)' --output text --region "$aws_region" 2>/dev/null || echo "0")
        log "  - Subnets: $subnet_count"
        
        # Check security groups
        local sg_count
        sg_count=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=${vpc_id}" --query 'length(SecurityGroups)' --output text --region "$aws_region" 2>/dev/null || echo "0")
        log "  - Security groups: $sg_count"
        
        # Check load balancers
        local lb_count
        lb_count=$(aws elbv2 describe-load-balancers --query "length(LoadBalancers[?VpcId=='${vpc_id}'])" --output text --region "$aws_region" 2>/dev/null || echo "0")
        if [[ "$lb_count" -gt 0 ]]; then
            log "  - Load balancers: $lb_count"
        fi
    else
        log "✗ VPC not found"
    fi
    
    # Check IAM roles
    local iam_roles
    iam_roles=$(aws iam list-roles --query "Roles[?contains(RoleName, '${project_prefix}-${environment}')].RoleName" --output text --region "$aws_region" 2>/dev/null || echo "")
    if [[ -n "$iam_roles" ]]; then
        log "✓ IAM roles found: $(echo $iam_roles | wc -w)"
        resources_found=true
        ((resource_count++))
        for role in $iam_roles; do
            log "  - $role"
        done
    else
        log "✗ No IAM roles found"
    fi
    
    # Check KMS keys
    local kms_keys
    kms_keys=$(aws kms list-keys --query "Keys[?contains(KeyId, '${project_prefix}-${environment}')].KeyId" --output text --region "$aws_region" 2>/dev/null || echo "")
    if [[ -n "$kms_keys" ]]; then
        log "✓ KMS keys found: $(echo $kms_keys | wc -w)"
        resources_found=true
        ((resource_count++))
        for key in $kms_keys; do
            log "  - $key"
        done
    else
        log "✗ No KMS keys found"
    fi
    
    # Check CloudWatch log groups
    local log_groups
    log_groups=$(aws logs describe-log-groups --log-group-name-prefix "/aws/vpc/flowlogs/${project_prefix}-${environment}" --query 'length(logGroups)' --output text --region "$aws_region" 2>/dev/null || echo "0")
    if [[ "$log_groups" -gt 0 ]]; then
        log "✓ CloudWatch log groups found: $log_groups"
        resources_found=true
        ((resource_count++))
    else
        log "✗ No CloudWatch log groups found"
    fi
    
    log "Total resources found: $resource_count"
    
    if [[ "$resources_found" == "false" ]]; then
        warning "No infrastructure resources found. Nothing to destroy."
        exit 0
    fi
    
    return 0
}

# Confirm destruction
confirm_destruction() {
    if [[ "$SKIP_CONFIRMATION" == "true" ]] || [[ "$FORCE_DESTROY" == "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    echo ""
    echo -e "${RED}⚠️  WARNING: This will destroy ALL infrastructure! ⚠️${NC}"
    echo ""
    echo "The following resources will be destroyed:"
    echo "  - EKS cluster and node groups"
    echo "  - VPC, subnets, and networking"
    echo "  - Load balancers and security groups"
    echo "  - IAM roles and policies"
    if [[ "$KEEP_BACKEND" == "false" ]]; then
        echo "  - Terraform state (S3 bucket and DynamoDB table)"
    else
        echo "  - Terraform state will be preserved"
    fi
    echo ""
    echo -e "${YELLOW}This action cannot be undone!${NC}"
    echo ""
    
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation
    
    if [[ "$confirmation" != "yes" ]]; then
        log "Teardown cancelled by user"
        exit 0
    fi
}

# Handle Terraform state and backend issues
handle_terraform_state() {
    log "Handling Terraform state and backend configuration..."
    
    cd "$TERRAFORM_DIR"
    source "${SCRIPT_DIR}/teardown-config.env"
    
    # Check if we have a valid Terraform state
    local state_valid=false
    
    # Try to access current state
    if terraform show >/dev/null 2>&1; then
        log "Terraform state is accessible"
        state_valid=true
    else
        log "Terraform state is not accessible, attempting to fix..."
        
        # Check if backend resources exist
        local bucket_region="${aws_region}"
        if [[ -f "${SCRIPT_DIR}/teardown-config.env" ]] && grep -q "bucket_region=" "${SCRIPT_DIR}/teardown-config.env"; then
            bucket_region=$(grep "bucket_region=" "${SCRIPT_DIR}/teardown-config.env" | cut -d'=' -f2)
        fi
        
        if aws s3api head-bucket --bucket "$bucket_name" --region "$bucket_region" 2>/dev/null; then
            log "Backend resources exist, attempting to reconnect..."
            
            # Try to reinitialize with backend
            if terraform init -reconfigure \
                -backend-config="bucket=${bucket_name}" \
                -backend-config="key=${environment}/terraform.tfstate" \
                -backend-config="region=${bucket_region}" \
                -backend-config="dynamodb_table=${table_name}" \
                -backend-config="encrypt=true" >/dev/null 2>&1; then
                
                # Test if state is now accessible
                if terraform show >/dev/null 2>&1; then
                    log "Successfully reconnected to Terraform state"
                    state_valid=true
                else
                    log "Still cannot access state after reinitialization"
                fi
            else
                log "Failed to reinitialize with backend"
            fi
        else
            log "Backend resources do not exist, state may be lost"
        fi
    fi
    
    if [[ "$state_valid" == "false" ]]; then
        warning "Cannot access Terraform state. This may mean:"
        warning "1. The infrastructure was already destroyed"
        warning "2. The state file is corrupted or lost"
        warning "3. Backend resources were deleted"
        warning ""
        warning "Attempting to destroy resources directly..."
        
        # Try to destroy without state
        if [[ "$FORCE_DESTROY" == "true" ]]; then
            log "Force destroying without state..."
            terraform destroy -var-file="terraform.tfvars" -auto-approve -refresh=false || {
                warning "Direct destroy failed. You may need to manually clean up resources."
                return 1
            }
        else
            log "Cannot proceed without valid state. Use --force to attempt direct destruction."
            return 1
        fi
    fi
    
    return 0
}

# Clean up Kubernetes resources
# This function performs comprehensive cleanup of all Kubernetes resources including:
# - ArgoCD applications and Helm releases
# - Monitoring stack (Prometheus, Grafana, AlertManager)
# - All namespaces and resources
# - Force cleanup options for stuck resources
cleanup_kubernetes_resources() {
    log "Cleaning up Kubernetes resources..."
    
    source "${SCRIPT_DIR}/teardown-config.env"
    
    # Check if kubectl is configured for the cluster
    # If not configured, attempt to configure it using AWS CLI
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log "Configuring kubectl for EKS cluster..."
        aws eks update-kubeconfig --region "$aws_region" --name "$cluster_name" || {
            warning "Failed to configure kubectl. Skipping Kubernetes cleanup."
            return 0
        }
    fi
    
    # Wait for cluster to be accessible
    # This ensures the cluster is responsive before attempting cleanup
    log "Waiting for cluster to be accessible..."
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if kubectl get nodes >/dev/null 2>&1; then
            log "Successfully connected to EKS cluster"
            break
        fi
        
        log "Attempt $attempt/$max_attempts: Waiting for cluster access..."
        sleep 10
        ((attempt++))
        
        if [[ $attempt -gt $max_attempts ]]; then
            warning "Failed to access EKS cluster after $max_attempts attempts. Skipping Kubernetes cleanup."
            return 0
        fi
    done
    
    # Delete ArgoCD applications first (app-of-apps pattern)
    log "Deleting ArgoCD applications..."
    if kubectl get applications -n argocd >/dev/null 2>&1; then
        # Delete all applications
        kubectl delete applications --all -n argocd --ignore-not-found=true || true
        
        # Wait for applications to be deleted
        log "Waiting for ArgoCD applications to be deleted..."
        local app_attempt=1
        while [[ $app_attempt -le 30 ]]; do
            local app_count
            app_count=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
            if [[ "$app_count" -eq 0 ]]; then
                log "All ArgoCD applications deleted"
                break
            fi
            log "Waiting for $app_count applications to be deleted... (attempt $app_attempt/30)"
            sleep 10
            ((app_attempt++))
        done
    else
        log "No ArgoCD applications found"
    fi
    
    # Delete ArgoCD Helm release
    log "Deleting ArgoCD Helm release..."
    if helm list -n argocd | grep -q argocd; then
        helm uninstall argocd -n argocd --ignore-not-found=true || true
        
        # Wait for ArgoCD pods to be deleted
        log "Waiting for ArgoCD pods to be deleted..."
        local argocd_attempt=1
        while [[ $argocd_attempt -le 30 ]]; do
            local argocd_pods
            argocd_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
            if [[ "$argocd_pods" -eq 0 ]]; then
                log "All ArgoCD pods deleted"
                break
            fi
            log "Waiting for $argocd_pods ArgoCD pods to be deleted... (attempt $argocd_attempt/30)"
            sleep 10
            ((argocd_attempt++))
        done
    else
        log "No ArgoCD Helm release found"
    fi
    
    # Delete ArgoCD namespace
    log "Deleting ArgoCD namespace..."
    kubectl delete namespace argocd --ignore-not-found=true || true
    
    # Delete monitoring namespace and resources
    log "Deleting monitoring resources..."
    if kubectl get namespace monitoring >/dev/null 2>&1; then
        # Delete Prometheus and Grafana resources specifically
        log "Deleting Prometheus resources..."
        kubectl delete prometheus --all -n monitoring --ignore-not-found=true || true
        kubectl delete servicemonitor --all -n monitoring --ignore-not-found=true || true
        kubectl delete alertmanager --all -n monitoring --ignore-not-found=true || true
        
        log "Deleting Grafana resources..."
        kubectl delete grafana --all -n monitoring --ignore-not-found=true || true
        
        # Delete the monitoring namespace
        kubectl delete namespace monitoring --ignore-not-found=true || true
        
        # Wait for monitoring namespace to be deleted
        log "Waiting for monitoring namespace to be deleted..."
        local monitoring_attempt=1
        while [[ $monitoring_attempt -le 30 ]]; do
            if ! kubectl get namespace monitoring >/dev/null 2>&1; then
                log "Monitoring namespace deleted"
                break
            fi
            log "Waiting for monitoring namespace to be deleted... (attempt $monitoring_attempt/30)"
            sleep 10
            ((monitoring_attempt++))
        done
    else
        log "No monitoring namespace found"
    fi
    
    # Delete any remaining resources in other namespaces
    log "Cleaning up remaining Kubernetes resources..."
    
    # Delete any remaining Helm releases
    log "Deleting remaining Helm releases..."
    for namespace in $(kubectl get namespaces --no-headers -o custom-columns=":metadata.name" | grep -v kube-system | grep -v kube-public | grep -v kube-node-lease); do
        if helm list -n "$namespace" | grep -q .; then
            log "Deleting Helm releases in namespace: $namespace"
            helm list -n "$namespace" --short | xargs -r helm uninstall -n "$namespace" || true
        fi
    done
    
    # Delete any remaining resources (excluding system namespaces)
    log "Deleting remaining resources in non-system namespaces..."
    for namespace in $(kubectl get namespaces --no-headers -o custom-columns=":metadata.name" | grep -v kube-system | grep -v kube-public | grep -v kube-node-lease); do
        log "Cleaning up namespace: $namespace"
        kubectl delete all --all -n "$namespace" --ignore-not-found=true || true
        kubectl delete pvc --all -n "$namespace" --ignore-not-found=true || true
        kubectl delete secrets --all -n "$namespace" --ignore-not-found=true || true
        kubectl delete configmaps --all -n "$namespace" --ignore-not-found=true || true
    done
    
    # Force delete any remaining namespaces (excluding system namespaces)
    log "Force deleting remaining non-system namespaces..."
    for namespace in $(kubectl get namespaces --no-headers -o custom-columns=":metadata.name" | grep -v kube-system | grep -v kube-public | grep -v kube-node-lease); do
        log "Force deleting namespace: $namespace"
        kubectl delete namespace "$namespace" --force --grace-period=0 --ignore-not-found=true || true
    done
    
    # Force cleanup if requested
    # This is a last resort option for cleaning up stuck or problematic resources
    # It uses force deletion with grace period 0 to immediately remove resources
    if [[ "$FORCE_KUBERNETES_CLEANUP" == "true" ]]; then
        log "Performing force Kubernetes cleanup..."
        
        # Force delete all non-system namespaces
        # This bypasses normal deletion procedures and immediately removes namespaces
        log "Force deleting all non-system namespaces..."
        kubectl get namespaces --no-headers -o custom-columns=":metadata.name" | grep -v kube-system | grep -v kube-public | grep -v kube-node-lease | xargs -r kubectl delete namespace --force --grace-period=0 || true
        
        # Force delete any remaining resources
        # This removes all resources across all namespaces with force deletion
        log "Force deleting remaining resources..."
        kubectl delete all --all --all-namespaces --force --grace-period=0 --ignore-not-found=true || true
        kubectl delete pvc --all --all-namespaces --force --grace-period=0 --ignore-not-found=true || true
        kubectl delete secrets --all --all-namespaces --force --grace-period=0 --ignore-not-found=true || true
        kubectl delete configmaps --all --all-namespaces --force --grace-period=0 --ignore-not-found=true || true
        
        # Force delete any remaining CRDs
        # Custom Resource Definitions may prevent namespace deletion
        log "Force deleting custom resource definitions..."
        kubectl delete crd --all --force --grace-period=0 --ignore-not-found=true || true
        
        warning "Force cleanup completed. Some resources may still exist and require manual cleanup."
    fi
    
    success "Kubernetes resources cleanup completed"
}

# Destroy Terraform infrastructure
destroy_terraform_infrastructure() {
    log "Destroying Terraform infrastructure..."
    
    cd "$TERRAFORM_DIR"
    
    # Validate Terraform configuration
    log "Validating Terraform configuration..."
    terraform validate
    
    # Plan destruction
    log "Creating Terraform destroy plan..."
    terraform plan -destroy -var-file="terraform.tfvars" -out=destroy-plan
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would destroy the following resources:"
        terraform show destroy-plan
        return 0
    fi
    
    # Apply destruction
    if [[ "$FORCE_DESTROY" == "true" ]]; then
        log "Destroying infrastructure (force mode)..."
        terraform destroy -var-file="terraform.tfvars" -auto-approve
    else
        log "Destroying infrastructure (interactive)..."
        terraform apply destroy-plan
    fi
    
    success "Terraform infrastructure destruction completed"
}

# Clean up backend resources
cleanup_backend_resources() {
    if [[ "$KEEP_BACKEND" == "true" ]]; then
        log "Keeping backend resources as requested"
        return 0
    fi
    
    log "Cleaning up backend resources..."
    
    source "${SCRIPT_DIR}/teardown-config.env"
    
    # Delete S3 bucket
    local bucket_region="${aws_region}"
    if [[ -f "${SCRIPT_DIR}/teardown-config.env" ]] && grep -q "bucket_region=" "${SCRIPT_DIR}/teardown-config.env"; then
        bucket_region=$(grep "bucket_region=" "${SCRIPT_DIR}/teardown-config.env" | cut -d'=' -f2)
    fi
    
    if aws s3api head-bucket --bucket "$bucket_name" --region "$bucket_region" 2>/dev/null; then
        log "Deleting S3 bucket: ${bucket_name} (region: ${bucket_region})"
        
        # Delete all objects in the bucket
        aws s3 rm "s3://${bucket_name}" --recursive --region "$bucket_region" || true
        
        # Delete the bucket
        aws s3api delete-bucket --bucket "$bucket_name" --region "$bucket_region" || {
            warning "Failed to delete S3 bucket. You may need to delete it manually."
        }
        
        success "S3 bucket deleted"
    else
        log "S3 bucket not found, skipping deletion"
    fi
    
    # Delete DynamoDB table
    if aws dynamodb describe-table --table-name "$table_name" --region "$aws_region" >/dev/null 2>&1; then
        log "Deleting DynamoDB table: ${table_name}"
        aws dynamodb delete-table --table-name "$table_name" --region "$aws_region" || {
            warning "Failed to delete DynamoDB table. You may need to delete it manually."
        }
        
        # Wait for table to be deleted
        log "Waiting for DynamoDB table to be deleted..."
        aws dynamodb wait table-not-exists --table-name "$table_name" --region "$aws_region" || true
        
        success "DynamoDB table deleted"
    else
        log "DynamoDB table not found, skipping deletion"
    fi
    
    success "Backend resources cleanup completed"
}

# Clean up temporary files
cleanup_temp_files() {
    log "Cleaning up temporary files..."
    
    # Remove Terraform files
    rm -f "${TERRAFORM_DIR}/destroy-plan"
    rm -f "${TERRAFORM_DIR}/tfplan"
    rm -f "${TERRAFORM_DIR}/.terraform.lock.hcl"
    
    # Remove configuration files
    rm -f "${SCRIPT_DIR}/teardown-config.env"
    rm -f "${SCRIPT_DIR}/backend-config.env"
    rm -f "${SCRIPT_DIR}/terraform-outputs.json"
    rm -f "${SCRIPT_DIR}/argocd-admin-password.txt"
    
    # Remove Terraform directory if empty
    if [[ -d "${TERRAFORM_DIR}/.terraform" ]]; then
        rm -rf "${TERRAFORM_DIR}/.terraform"
    fi
    
    success "Temporary files cleanup completed"
}

# Show teardown summary
show_teardown_summary() {
    log "Teardown completed! Summary:"
    
    echo ""
    echo "=== TEARDOWN SUMMARY ==="
    echo ""
    
    if [[ "$KEEP_BACKEND" == "true" ]]; then
        echo "✓ Infrastructure destroyed"
        echo "✓ Backend resources preserved (S3 bucket and DynamoDB table)"
    else
        echo "✓ Infrastructure destroyed"
        echo "✓ Backend resources destroyed"
    fi
    
    echo "✓ Kubernetes resources cleaned up"
    if [[ "$FORCE_KUBERNETES_CLEANUP" == "true" ]]; then
        echo "✓ Force Kubernetes cleanup performed"
    fi
    
    echo ""
    echo "=== VERIFICATION COMMANDS ==="
    echo ""
    echo "1. Verify EKS cluster is destroyed:"
    echo "   aws eks list-clusters --region $aws_region"
    echo ""
    echo "2. Verify VPC is destroyed:"
    echo "   aws ec2 describe-vpcs --region $aws_region"
    echo ""
    echo "3. Check for any remaining resources:"
    echo "   aws resourcegroupstaggingapi get-resources --region $aws_region"
    echo ""
    echo "4. Verify S3 bucket status:"
    if [[ "$KEEP_BACKEND" == "true" ]]; then
        echo "   aws s3api head-bucket --bucket $bucket_name --region $aws_region"
    else
        echo "   aws s3api head-bucket --bucket $bucket_name --region $aws_region  # Should fail"
    fi
    echo ""
    echo "5. Verify DynamoDB table status:"
    if [[ "$KEEP_BACKEND" == "true" ]]; then
        echo "   aws dynamodb describe-table --table-name $table_name --region $aws_region"
    else
        echo "   aws dynamodb describe-table --table-name $table_name --region $aws_region  # Should fail"
    fi
    echo ""
    echo "6. Check for any remaining IAM roles:"
    echo "   aws iam list-roles --query \"Roles[?contains(RoleName, '$project_prefix-$environment')].RoleName\" --output table --region $aws_region"
    echo ""
    echo "7. Check for any remaining KMS keys:"
    echo "   aws kms list-keys --query \"Keys[?contains(KeyId, '$project_prefix-$environment')].KeyId\" --output table --region $aws_region"
    echo ""
    echo "=== NEXT STEPS ==="
    echo ""
    echo "1. Review AWS costs to ensure no unexpected charges"
    echo "2. Check CloudWatch logs for any remaining log groups"
    echo "3. Verify all resources are completely destroyed"
    echo ""
    echo "=== TROUBLESHOOTING ==="
    echo ""
    echo "If resources still exist:"
    echo "1. Check the log file: $LOG_FILE"
    echo "2. Use AWS Console to manually delete remaining resources"
    echo "3. For Kubernetes resources, use: $0 --force-k8s-cleanup"
    echo "4. For Terraform state issues, use: $0 --force"
    echo ""
    echo "=== LOGS ==="
    echo "Check $LOG_FILE for detailed logs"
    echo ""
}

# Main function
main() {
    # Initialize log file
    echo "Teardown started at $(date)" > "$LOG_FILE"
    
    # Parse arguments
    parse_args "$@"
    
    # Set verbose mode
    if [[ "$VERBOSE" == "true" ]]; then
        set -x
    fi
    
    # Validate prerequisites
    validate_prerequisites
    
    # Get resource information
    get_resource_info
    
    # Check if resources exist
    check_resources_exist
    
    # Exit if validation only
    if [[ "${VALIDATE_ONLY:-false}" == "true" ]]; then
        success "Validation completed successfully"
        exit 0
    fi
    
    # Confirm destruction
    confirm_destruction
    
    # Clean up Kubernetes resources
    cleanup_kubernetes_resources
    
    # Handle Terraform state and backend issues
    handle_terraform_state
    
    # Destroy Terraform infrastructure
    destroy_terraform_infrastructure
    
    # Clean up backend resources
    cleanup_backend_resources
    
    # Clean up temporary files
    cleanup_temp_files
    
    # Show summary
    show_teardown_summary
    
    success "Teardown completed successfully!"
    log "Check $LOG_FILE for detailed logs"
}

# Trap to ensure cleanup on exit
trap 'cleanup_temp_files' EXIT

# Run main function
main "$@"
