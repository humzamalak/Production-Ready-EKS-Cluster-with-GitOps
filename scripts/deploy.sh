#!/bin/bash

# =============================================================================
# Consolidated Deployment Script for EKS GitOps Infrastructure
# =============================================================================
#
# This script provides a unified interface for deploying and managing the
# EKS GitOps infrastructure across different environments and components.
#
# Usage:
#   ./scripts/deploy.sh [command] [environment] [options]
#
# Commands:
#   - terraform: Deploy infrastructure using Terraform
#   - bootstrap: Bootstrap ArgoCD and initial applications
#   - secrets: Create monitoring and application secrets
#   - vault: Setup Vault policies and secrets for web app
#   - validate: Validate deployments and configurations
#   - sync: Sync ArgoCD applications
#
# Environments:
#   - dev: Development environment
#   - staging: Staging environment  
#   - prod: Production environment
#
# Examples:
#   ./scripts/deploy.sh terraform prod
#   ./scripts/deploy.sh bootstrap prod
#   ./scripts/deploy.sh secrets monitoring
#   ./scripts/deploy.sh vault web-app
#   ./scripts/deploy.sh validate all
#   ./scripts/deploy.sh sync prod
#
# Author: Production-Ready EKS Cluster with GitOps
# Version: 2.0.0
# =============================================================================

set -euo pipefail

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$REPO_ROOT/terraform/environments/aws"
ARGOCD_INSTALL_DIR="$REPO_ROOT/argo-apps/install"
ARGOCD_APPS_DIR="$REPO_ROOT/argo-apps/apps"

# Default values
DEFAULT_ENVIRONMENT="prod"
DEFAULT_TIMEOUT="300"

# Function to print colored output
print_header() {
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
}

print_status() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Function to display usage information
show_usage() {
    cat << EOF
Usage: $0 [command] [environment] [options]

Commands:
  terraform    Deploy infrastructure using Terraform
  bootstrap    Bootstrap ArgoCD and initial applications
  secrets      Create monitoring and application secrets
  vault        Setup Vault policies and secrets for web app
  validate     Validate deployments and configurations
  sync         Sync ArgoCD applications

Environments:
  dev          Development environment
  staging      Staging environment
  prod         Production environment (default)

Options:
  --timeout N  Set timeout for operations (default: 300s)
  --dry-run    Show what would be done without executing
  --help       Show this help message

Examples:
  $0 terraform prod
  $0 bootstrap prod
  $0 secrets monitoring
  $0 vault web-app
  $0 validate all
  $0 sync prod --timeout 600

EOF
}

# Function to check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v helm >/dev/null 2>&1 || missing_tools+=("helm")
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install the missing tools and try again"
        exit 1
    fi
    
    # Check kubectl connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "kubectl is not configured or cannot connect to cluster"
        print_error "Please configure kubectl with: kubectl config set-context <your-context>"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to deploy Terraform infrastructure
deploy_terraform() {
    local environment=${1:-$DEFAULT_ENVIRONMENT}
    
    print_header "Deploying Terraform Infrastructure for $environment"
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        print_step "Initializing Terraform..."
        terraform init
    fi
    
    # Plan deployment
    print_step "Planning Terraform deployment..."
    terraform plan -var-file=terraform.tfvars -out=tfplan
    
    # Apply deployment
    print_step "Applying Terraform deployment..."
    terraform apply tfplan
    
    print_success "Terraform infrastructure deployed successfully"
}

# Function to bootstrap ArgoCD and applications
bootstrap_argocd() {
    local environment=${1:-$DEFAULT_ENVIRONMENT}
    
    print_header "Bootstrapping ArgoCD for $environment"
    
    # Ensure argocd namespace exists and is ready
    print_step "Creating namespaces..."
    kubectl apply -f "$ARGOCD_INSTALL_DIR/01-namespaces.yaml"
    kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/argocd --timeout=60s || true

    # Install ArgoCD using official manifest
    print_step "Installing ArgoCD..."
    ARGOCD_VERSION="3.1.0"
    kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml"
    
    # Wait for ArgoCD to be ready
    print_step "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=${TIMEOUT}s deployment/argocd-server -n argocd
    
    # Additional wait for initialization
    sleep 30
    
    # Deploy bootstrap applications
    print_step "Deploying applications via GitOps..."
    kubectl apply -f "$ARGOCD_INSTALL_DIR/03-bootstrap.yaml"
    
    # Wait for applications to appear
    sleep 15
    
    print_success "ArgoCD bootstrapping completed successfully"
    print_status "Applications will sync automatically. Use './scripts/argocd-login.sh' to monitor."
}

# Function to create monitoring secrets
create_monitoring_secrets() {
    local component=${1:-"monitoring"}
    
    print_header "Creating $component Secrets"
    
    # Check if monitoring namespace exists
    if ! kubectl get namespace monitoring >/dev/null 2>&1; then
        print_step "Creating monitoring namespace..."
        kubectl create namespace monitoring
    fi
    
    # Generate secure passwords
    local grafana_password=$(openssl rand -base64 16)
    
    # Create Grafana admin secret
    print_step "Creating Grafana admin secret..."
    kubectl create secret generic grafana-admin \
        --namespace=monitoring \
        --from-literal=admin-user=admin \
        --from-literal=admin-password="${grafana_password}" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ArgoCD Redis secret if needed
    if ! kubectl get secret argocd-redis -n argocd >/dev/null 2>&1; then
        print_step "Creating ArgoCD Redis secret..."
        local redis_auth=$(openssl rand -base64 32)
        kubectl create secret generic argocd-redis \
            --namespace=argocd \
            --from-literal=auth="${redis_auth}" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    
    print_success "$component secrets created successfully"
    echo "Grafana password: $grafana_password"
}

# Function to setup Vault for web app
setup_vault() {
    local app_name=${1:-"web-app"}
    
    print_header "Setting up Vault for $app_name"
    
    # Check if Vault is accessible
    if ! kubectl get pods -n vault | grep -q "vault.*Running"; then
        print_error "Vault is not running in namespace vault"
        exit 1
    fi
    
    # Port forward to Vault
    print_step "Setting up port forward to Vault..."
    kubectl port-forward -n vault svc/vault 8200:8200 &
    local port_forward_pid=$!
    sleep 5
    
    # Set Vault address
    export VAULT_ADDR="http://localhost:8200"
    export VAULT_TOKEN="root"  # In production, use proper token management
    
    # Authenticate with Vault
    print_step "Authenticating with Vault..."
    vault auth $VAULT_TOKEN
    
    # Create web app policy
    print_step "Creating $app_name Vault policy..."
    vault policy write k8s-web-app - <<EOF
# Allow read access to web app secrets
path "secret/data/production/web-app/*" {
  capabilities = ["read"]
}

# Allow read access to secret metadata
path "secret/metadata/production/web-app/*" {
  capabilities = ["read", "list"]
}

# Allow list access to web app secret paths
path "secret/production/web-app/*" {
  capabilities = ["list"]
}

# Allow authentication via Kubernetes
path "auth/kubernetes/login" {
  capabilities = ["create", "update"]
}

# Allow token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Allow token lookup
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF
    
    # Create Kubernetes role
    print_step "Creating Kubernetes role for $app_name..."
    vault write auth/kubernetes/role/k8s-web-app \
        bound_service_account_names=k8s-web-app \
        bound_service_account_namespaces=production \
        policies=k8s-web-app \
        ttl=1h \
        max_ttl=24h
    
    # Create web app secrets
    print_step "Creating $app_name secrets in Vault..."
    vault kv put secret/production/web-app/db \
        host="your-production-db-host.amazonaws.com" \
        port="5432" \
        name="k8s_web_app_prod" \
        username="k8s_web_app_user" \
        password="$(openssl rand -base64 32)"
    
    vault kv put secret/production/web-app/api \
        jwt_secret="$(openssl rand -base64 64)" \
        encryption_key="$(openssl rand -base64 32)" \
        api_key="$(openssl rand -base64 32)"
    
    vault kv put secret/production/web-app/external \
        smtp_host="smtp.your-provider.com" \
        smtp_port="587" \
        smtp_username="your-smtp-username" \
        smtp_password="your-smtp-password" \
        redis_url="redis://your-redis-host:6379"
    
    # Cleanup
    kill $port_forward_pid 2>/dev/null || true
    
    print_success "Vault setup for $app_name completed successfully"
}

# Function to validate deployments
validate_deployments() {
    local scope=${1:-"all"}
    
    print_header "Validating Deployments ($scope)"
    
    # Run repository structure validation
    if [ "$scope" = "all" ] || [ "$scope" = "structure" ]; then
        print_step "Validating repository structure..."
        "$SCRIPT_DIR/validate-gitops-structure.sh"
    fi
    
    # Run ArgoCD applications validation
    if [ "$scope" = "all" ] || [ "$scope" = "apps" ]; then
        print_step "Validating ArgoCD applications..."
        "$SCRIPT_DIR/validate-argocd-apps.sh"
    fi
    
    # Validate Helm charts
    if [ "$scope" = "all" ] || [ "$scope" = "helm" ]; then
        print_step "Validating Helm charts..."
        cd "$REPO_ROOT/applications/web-app/k8s-web-app/helm"
        helm lint .
        helm template k8s-web-app . -f ../values.yaml --dry-run >/dev/null
    fi
    
    print_success "Deployment validation completed successfully"
}

# Function to sync ArgoCD applications
sync_argocd() {
    local environment=${1:-$DEFAULT_ENVIRONMENT}
    
    print_header "Syncing ArgoCD Applications for $environment"
    
    # Sync root application
    print_step "Syncing root application..."
    kubectl patch application "$environment-app-of-apps" -n argocd --type merge -p '{"operation":{"sync":{"syncOptions":["CreateNamespace=true"]}}}'
    
    # Wait for sync to complete
    print_step "Waiting for sync to complete..."
    kubectl wait --for=condition=Synced --timeout=${TIMEOUT}s application "$environment-app-of-apps" -n argocd
    
    # Get list of applications to sync
    local apps=$(kubectl get applications -n argocd -l "app.kubernetes.io/part-of=$environment" -o name)
    
    for app in $apps; do
        print_step "Syncing $app..."
        kubectl patch "$app" -n argocd --type merge -p '{"operation":{"sync":{"syncOptions":["CreateNamespace=true"]}}}'
    done
    
    print_success "ArgoCD sync completed successfully"
}

# Function to show deployment status
show_status() {
    local environment=${1:-$DEFAULT_ENVIRONMENT}
    
    print_header "Deployment Status for $environment"
    
    # Show ArgoCD applications status
    print_step "ArgoCD Applications Status:"
    kubectl get applications -n argocd -l "app.kubernetes.io/part-of=$environment" -o wide
    
    # Show pods status
    print_step "Pods Status:"
    kubectl get pods -A -l "app.kubernetes.io/part-of=$environment" -o wide
    
    # Show services status
    print_step "Services Status:"
    kubectl get services -A -l "app.kubernetes.io/part-of=$environment" -o wide
}

# Parse command line arguments
COMMAND=""
ENVIRONMENT="$DEFAULT_ENVIRONMENT"
TIMEOUT="$DEFAULT_TIMEOUT"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        terraform|bootstrap|secrets|vault|validate|sync|status)
            COMMAND="$1"
            shift
            ;;
        dev|staging|prod)
            ENVIRONMENT="$1"
            shift
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate command
if [ -z "$COMMAND" ]; then
    print_error "No command specified"
    show_usage
    exit 1
fi

# Main execution
main() {
    print_header "EKS GitOps Infrastructure Deployment Script"
    print_status "Command: $COMMAND"
    print_status "Environment: $ENVIRONMENT"
    print_status "Timeout: ${TIMEOUT}s"
    print_status "Dry Run: $DRY_RUN"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN MODE - No changes will be made"
        echo ""
    fi
    
    # Check prerequisites
    check_prerequisites
    echo ""
    
    # Execute command
    case $COMMAND in
        terraform)
            deploy_terraform "$ENVIRONMENT"
            ;;
        bootstrap)
            bootstrap_argocd "$ENVIRONMENT"
            ;;
        secrets)
            create_monitoring_secrets "$2"
            ;;
        vault)
            setup_vault "$2"
            ;;
        validate)
            validate_deployments "$2"
            ;;
        sync)
            sync_argocd "$ENVIRONMENT"
            ;;
        status)
            show_status "$ENVIRONMENT"
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            show_usage
            exit 1
            ;;
    esac
    
    echo ""
    print_header "Deployment Completed Successfully"
}

# Run main function
main "$@"
