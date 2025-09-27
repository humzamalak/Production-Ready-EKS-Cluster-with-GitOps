#!/bin/bash

# Production-Ready EKS Cluster with GitOps - Backend Management Script
# This script manages Terraform backend resources (S3 bucket and DynamoDB table)
#
# Usage: ./scripts/backend-management.sh [OPTIONS]

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Default values
CREATE_BACKEND_ONLY=false

# Help function
show_help() {
    show_help_header \
        "$(basename "$0")" \
        "Production-Ready EKS Cluster with GitOps - Backend Management Script"
    
    cat << EOF
ADDITIONAL OPTIONS:
    --create-backend-only   Only create S3 bucket and DynamoDB table for Terraform backend

EXAMPLES:
    $0                      # Create backend resources
    $0 --validate-only      # Only validate prerequisites
    $0 --dry-run            # Show what would be created
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

# Check backend resources exist
check_backend_resources() {
    log "Checking backend resources..."
    
    read_terraform_config
    
    # Check S3 bucket
    local bucket_exists=false
    local bucket_region=""
    
    # Try the configured region first
    if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null; then
        bucket_exists=true
        bucket_region="$AWS_REGION"
        log "Backend S3 bucket ${BUCKET_NAME} exists in ${bucket_region}"
    # Try us-east-1 (common for S3 buckets)
    elif aws s3api head-bucket --bucket "$BUCKET_NAME" --region us-east-1 2>/dev/null; then
        bucket_exists=true
        bucket_region="us-east-1"
        log "Backend S3 bucket ${BUCKET_NAME} exists in us-east-1"
    else
        log "Backend S3 bucket ${BUCKET_NAME} does not exist (will be created in ${AWS_REGION})"
    fi
    
    # Check DynamoDB table
    if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        log "Backend DynamoDB table ${TABLE_NAME} exists"
    else
        log "Backend DynamoDB table ${TABLE_NAME} does not exist (will be created)"
    fi
    
    return 0
}

# Create S3 bucket for Terraform state
create_s3_bucket() {
    log "Creating S3 bucket: ${BUCKET_NAME}"
    
    if [[ "$AWS_REGION" == "us-east-1" ]]; then
        # us-east-1 doesn't need LocationConstraint
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"
    else
        # For other regions, use LocationConstraint
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    
    # Enable versioning
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    # Enable server-side encryption
    aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" \
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
    aws s3api put-public-access-block --bucket "$BUCKET_NAME" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    success "S3 bucket ${BUCKET_NAME} created successfully"
}

# Create DynamoDB table for Terraform state locking
create_dynamodb_table() {
    log "Creating DynamoDB table: ${TABLE_NAME}"
    
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$AWS_REGION" \
        --tags Key=Name,Value="${TABLE_NAME}" Key=Environment,Value="${ENVIRONMENT}" Key=Project,Value="${PROJECT_PREFIX}"
    
    # Wait for table to be active
    log "Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$AWS_REGION"
    
    success "DynamoDB table ${TABLE_NAME} created successfully"
}

# Create backend resources
create_backend_resources() {
    log "Creating Terraform backend resources..."
    
    read_terraform_config
    
    log "Backend resources to create:"
    log "  S3 Bucket: ${BUCKET_NAME}"
    log "  DynamoDB Table: ${TABLE_NAME}"
    log "  Region: ${AWS_REGION}"
    
    # Check if S3 bucket already exists
    if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null; then
        log "S3 bucket ${BUCKET_NAME} already exists"
    else
        create_s3_bucket
    fi
    
    # Check if DynamoDB table already exists
    if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        log "DynamoDB table ${TABLE_NAME} already exists"
    else
        create_dynamodb_table
    fi
    
    # Store backend configuration for later use
    echo "bucket_name=${BUCKET_NAME}" > "${SCRIPT_DIR}/backend-config.env"
    echo "table_name=${TABLE_NAME}" >> "${SCRIPT_DIR}/backend-config.env"
    echo "aws_region=${AWS_REGION}" >> "${SCRIPT_DIR}/backend-config.env"
    
    success "Backend resources creation completed"
}

# Handle Terraform state and backend issues
handle_terraform_state() {
    log "Handling Terraform state and backend configuration..."
    
    cd "$TERRAFORM_DIR"
    
    # Load backend configuration or read from terraform.tfvars
    if [[ -f "${SCRIPT_DIR}/backend-config.env" ]]; then
        source "${SCRIPT_DIR}/backend-config.env"
    else
        read_terraform_config
    fi
    
    # Check if we have a valid Terraform state
    local state_valid=false
    
    # Try to access current state
    if terraform show >/dev/null 2>&1; then
        log "Terraform state is accessible"
        state_valid=true
    else
        log "Terraform state is not accessible, attempting to initialize..."
        
        # Check if backend resources exist
        if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null; then
            log "Backend resources exist, initializing Terraform..."
            
            # Try to initialize with backend
            if terraform init \
                -backend-config="bucket=${BUCKET_NAME}" \
                -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
                -backend-config="region=${AWS_REGION}" \
                -backend-config="dynamodb_table=${TABLE_NAME}" \
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
            -backend-config="bucket=${BUCKET_NAME}" \
            -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
            -backend-config="region=${AWS_REGION}" \
            -backend-config="dynamodb_table=${TABLE_NAME}" \
            -backend-config="encrypt=true"
    fi
    
    return 0
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
        check_backend_resources
        success "Validation completed successfully"
        exit 0
    fi
    
    # Exit if dry run only
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log "DRY RUN: Would create the following backend resources:"
        read_terraform_config
        log "  S3 Bucket: ${BUCKET_NAME}"
        log "  DynamoDB Table: ${TABLE_NAME}"
        log "  Region: ${AWS_REGION}"
        success "Dry run completed successfully"
        exit 0
    fi
    
    # Create backend resources
    create_backend_resources
    
    # Handle Terraform state
    handle_terraform_state
    
    success "Backend management completed successfully!"
    log "Check $LOG_FILE for detailed logs"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
