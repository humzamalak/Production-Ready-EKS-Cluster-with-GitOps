#!/bin/bash

# =============================================================================
# Consolidated Secrets Management Script for EKS GitOps Infrastructure
# =============================================================================
#
# This script provides a unified interface for managing secrets across the
# EKS GitOps infrastructure including monitoring, applications, and Vault.
#
# Usage:
#   ./scripts/secrets.sh [command] [component] [options]
#
# Commands:
#   - create: Create secrets for specified component
#   - rotate: Rotate existing secrets
#   - verify: Verify secrets are properly configured
#   - backup: Backup secrets to secure location
#   - restore: Restore secrets from backup
#   - list: List all secrets in specified namespace/component
#
# Components:
#   - monitoring: Grafana, Prometheus, ArgoCD secrets
#   - web-app: Web application secrets (database, API, external services)
#   - vault: Vault policies and secrets
#   - all: All components
#
# Options:
#   --namespace: Specify Kubernetes namespace (default: component-specific)
#   --environment: Specify environment (dev/staging/prod)
#   --backup-dir: Directory for backup operations
#   --force: Force operation without confirmation
#   --help: Show this help message
#
# Examples:
#   ./scripts/secrets.sh create monitoring
#   ./scripts/secrets.sh rotate web-app --environment prod
#   ./scripts/secrets.sh verify all
#   ./scripts/secrets.sh backup vault --backup-dir /secure/backup
#   ./scripts/secrets.sh list monitoring --namespace monitoring
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

# Default values
DEFAULT_ENVIRONMENT="prod"
DEFAULT_BACKUP_DIR="/tmp/eks-secrets-backup"
FORCE=false
BACKUP_DIR="$DEFAULT_BACKUP_DIR"

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
Usage: $0 [command] [component] [options]

Commands:
  create      Create secrets for specified component
  rotate      Rotate existing secrets
  verify      Verify secrets are properly configured
  backup      Backup secrets to secure location
  restore     Restore secrets from backup
  list        List all secrets in specified namespace/component

Components:
  monitoring  Grafana, Prometheus, ArgoCD secrets
  web-app     Web application secrets (database, API, external services)
  vault       Vault policies and secrets
  all         All components

Options:
  --namespace     Specify Kubernetes namespace (default: component-specific)
  --environment   Specify environment (dev/staging/prod)
  --backup-dir    Directory for backup operations
  --force         Force operation without confirmation
  --help          Show this help message

Examples:
  $0 create monitoring
  $0 rotate web-app --environment prod
  $0 verify all
  $0 backup vault --backup-dir /secure/backup
  $0 list monitoring --namespace monitoring

EOF
}

# Function to check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v openssl >/dev/null 2>&1 || missing_tools+=("openssl")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    # Check kubectl connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "kubectl is not configured or cannot connect to cluster"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to generate secure password
generate_password() {
    local length=${1:-32}
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Function to create monitoring secrets
create_monitoring_secrets() {
    local namespace=${1:-"monitoring"}
    
    print_header "Creating Monitoring Secrets"
    
    # Ensure namespace exists
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        print_step "Creating $namespace namespace..."
        kubectl create namespace "$namespace"
    fi
    
    # Generate passwords
    local grafana_password=$(generate_password 16)
    local prometheus_password=$(generate_password 16)
    
    # Create Grafana admin secret
    print_step "Creating Grafana admin secret..."
    kubectl create secret generic grafana-admin \
        --namespace="$namespace" \
        --from-literal=admin-user=admin \
        --from-literal=admin-password="$grafana_password" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create Prometheus admin secret
    print_step "Creating Prometheus admin secret..."
    kubectl create secret generic prometheus-admin \
        --namespace="$namespace" \
        --from-literal=admin-user=admin \
        --from-literal=admin-password="$prometheus_password" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ArgoCD Redis secret if needed
    if ! kubectl get secret argocd-redis -n argocd >/dev/null 2>&1; then
        print_step "Creating ArgoCD Redis secret..."
        local redis_auth=$(generate_password 32)
        kubectl create secret generic argocd-redis \
            --namespace=argocd \
            --from-literal=auth="$redis_auth" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    
    print_success "Monitoring secrets created successfully"
    echo "Grafana password: $grafana_password"
    echo "Prometheus password: $prometheus_password"
}

# Function to create web app secrets
create_web_app_secrets() {
    local namespace=${1:-"production"}
    
    print_header "Creating Web App Secrets"
    
    # Ensure namespace exists
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        print_step "Creating $namespace namespace..."
        kubectl create namespace "$namespace"
    fi
    
    # Generate passwords and keys
    local db_password=$(generate_password 32)
    local jwt_secret=$(generate_password 64)
    local encryption_key=$(generate_password 32)
    local api_key=$(generate_password 32)
    
    # Create database secret
    print_step "Creating database secret..."
    kubectl create secret generic web-app-db-secret \
        --namespace="$namespace" \
        --from-literal=host="your-production-db-host.amazonaws.com" \
        --from-literal=port="5432" \
        --from-literal=name="k8s_web_app_prod" \
        --from-literal=username="k8s_web_app_user" \
        --from-literal=password="$db_password" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create API secret
    print_step "Creating API secret..."
    kubectl create secret generic web-app-api-secret \
        --namespace="$namespace" \
        --from-literal=jwt-secret="$jwt_secret" \
        --from-literal=encryption-key="$encryption_key" \
        --from-literal=api-key="$api_key" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create external services secret
    print_step "Creating external services secret..."
    kubectl create secret generic web-app-external-secret \
        --namespace="$namespace" \
        --from-literal=smtp-host="smtp.your-provider.com" \
        --from-literal=smtp-port="587" \
        --from-literal=smtp-username="your-smtp-username" \
        --from-literal=smtp-password="$(generate_password 16)" \
        --from-literal=redis-url="redis://your-redis-host:6379" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "Web app secrets created successfully"
}

# Function to setup Vault secrets
setup_vault_secrets() {
    local environment=${1:-"prod"}
    
    print_header "Setting up Vault Secrets"
    
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
    vault auth "$VAULT_TOKEN"
    
    # Create web app policy
    print_step "Creating web app Vault policy..."
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
    print_step "Creating Kubernetes role for web app..."
    vault write auth/kubernetes/role/k8s-web-app \
        bound_service_account_names=k8s-web-app \
        bound_service_account_namespaces=production \
        policies=k8s-web-app \
        ttl=1h \
        max_ttl=24h
    
    # Create web app secrets in Vault
    print_step "Creating web app secrets in Vault..."
    vault kv put secret/production/web-app/db \
        host="your-production-db-host.amazonaws.com" \
        port="5432" \
        name="k8s_web_app_prod" \
        username="k8s_web_app_user" \
        password="$(generate_password 32)"
    
    vault kv put secret/production/web-app/api \
        jwt_secret="$(generate_password 64)" \
        encryption_key="$(generate_password 32)" \
        api_key="$(generate_password 32)"
    
    vault kv put secret/production/web-app/external \
        smtp_host="smtp.your-provider.com" \
        smtp_port="587" \
        smtp_username="your-smtp-username" \
        smtp_password="$(generate_password 16)" \
        redis_url="redis://your-redis-host:6379"
    
    # Cleanup
    kill $port_forward_pid 2>/dev/null || true
    
    print_success "Vault secrets setup completed successfully"
}

# Function to rotate secrets
rotate_secrets() {
    local component=$1
    local namespace=${2:-""}
    
    print_header "Rotating Secrets for $component"
    
    case $component in
        monitoring)
            namespace=${namespace:-"monitoring"}
            print_step "Rotating monitoring secrets in namespace $namespace..."
            
            # Delete existing secrets
            kubectl delete secret grafana-admin -n "$namespace" --ignore-not-found=true
            kubectl delete secret prometheus-admin -n "$namespace" --ignore-not-found=true
            
            # Recreate secrets
            create_monitoring_secrets "$namespace"
            ;;
        web-app)
            namespace=${namespace:-"production"}
            print_step "Rotating web app secrets in namespace $namespace..."
            
            # Delete existing secrets
            kubectl delete secret web-app-db-secret -n "$namespace" --ignore-not-found=true
            kubectl delete secret web-app-api-secret -n "$namespace" --ignore-not-found=true
            kubectl delete secret web-app-external-secret -n "$namespace" --ignore-not-found=true
            
            # Recreate secrets
            create_web_app_secrets "$namespace"
            ;;
        vault)
            print_step "Rotating Vault secrets..."
            setup_vault_secrets "$ENVIRONMENT"
            ;;
        all)
            rotate_secrets "monitoring"
            echo ""
            rotate_secrets "web-app"
            echo ""
            rotate_secrets "vault"
            ;;
        *)
            print_error "Unknown component: $component"
            exit 1
            ;;
    esac
    
    print_success "Secret rotation completed for $component"
}

# Function to verify secrets
verify_secrets() {
    local component=$1
    local namespace=${2:-""}
    
    print_header "Verifying Secrets for $component"
    
    case $component in
        monitoring)
            namespace=${namespace:-"monitoring"}
            print_step "Verifying monitoring secrets in namespace $namespace..."
            
            if kubectl get secret grafana-admin -n "$namespace" >/dev/null 2>&1; then
                print_success "Grafana admin secret exists"
            else
                print_error "Grafana admin secret missing"
            fi
            
            if kubectl get secret prometheus-admin -n "$namespace" >/dev/null 2>&1; then
                print_success "Prometheus admin secret exists"
            else
                print_error "Prometheus admin secret missing"
            fi
            
            if kubectl get secret argocd-redis -n argocd >/dev/null 2>&1; then
                print_success "ArgoCD Redis secret exists"
            else
                print_warning "ArgoCD Redis secret missing"
            fi
            ;;
        web-app)
            namespace=${namespace:-"production"}
            print_step "Verifying web app secrets in namespace $namespace..."
            
            if kubectl get secret web-app-db-secret -n "$namespace" >/dev/null 2>&1; then
                print_success "Web app database secret exists"
            else
                print_error "Web app database secret missing"
            fi
            
            if kubectl get secret web-app-api-secret -n "$namespace" >/dev/null 2>&1; then
                print_success "Web app API secret exists"
            else
                print_error "Web app API secret missing"
            fi
            
            if kubectl get secret web-app-external-secret -n "$namespace" >/dev/null 2>&1; then
                print_success "Web app external services secret exists"
            else
                print_error "Web app external services secret missing"
            fi
            ;;
        vault)
            print_step "Verifying Vault secrets..."
            # Note: Vault verification would require port-forwarding and Vault CLI
            print_status "Vault verification requires manual inspection"
            ;;
        all)
            verify_secrets "monitoring"
            echo ""
            verify_secrets "web-app"
            echo ""
            verify_secrets "vault"
            ;;
        *)
            print_error "Unknown component: $component"
            exit 1
            ;;
    esac
    
    print_success "Secret verification completed for $component"
}

# Function to backup secrets
backup_secrets() {
    local component=$1
    
    print_header "Backing up Secrets for $component"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    case $component in
        monitoring)
            print_step "Backing up monitoring secrets..."
            kubectl get secret grafana-admin -n monitoring -o yaml > "$BACKUP_DIR/grafana-admin-secret.yaml" 2>/dev/null || true
            kubectl get secret prometheus-admin -n monitoring -o yaml > "$BACKUP_DIR/prometheus-admin-secret.yaml" 2>/dev/null || true
            kubectl get secret argocd-redis -n argocd -o yaml > "$BACKUP_DIR/argocd-redis-secret.yaml" 2>/dev/null || true
            ;;
        web-app)
            print_step "Backing up web app secrets..."
            kubectl get secret web-app-db-secret -n production -o yaml > "$BACKUP_DIR/web-app-db-secret.yaml" 2>/dev/null || true
            kubectl get secret web-app-api-secret -n production -o yaml > "$BACKUP_DIR/web-app-api-secret.yaml" 2>/dev/null || true
            kubectl get secret web-app-external-secret -n production -o yaml > "$BACKUP_DIR/web-app-external-secret.yaml" 2>/dev/null || true
            ;;
        vault)
            print_step "Backing up Vault secrets..."
            print_status "Vault backup requires manual process due to security considerations"
            ;;
        all)
            backup_secrets "monitoring"
            backup_secrets "web-app"
            backup_secrets "vault"
            ;;
        *)
            print_error "Unknown component: $component"
            exit 1
            ;;
    esac
    
    print_success "Secrets backup completed for $component"
    print_status "Backup location: $BACKUP_DIR"
}

# Function to restore secrets
restore_secrets() {
    local component=$1
    
    print_header "Restoring Secrets for $component"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "Backup directory does not exist: $BACKUP_DIR"
        exit 1
    fi
    
    case $component in
        monitoring)
            print_step "Restoring monitoring secrets..."
            kubectl apply -f "$BACKUP_DIR/grafana-admin-secret.yaml" 2>/dev/null || print_warning "Grafana admin secret backup not found"
            kubectl apply -f "$BACKUP_DIR/prometheus-admin-secret.yaml" 2>/dev/null || print_warning "Prometheus admin secret backup not found"
            kubectl apply -f "$BACKUP_DIR/argocd-redis-secret.yaml" 2>/dev/null || print_warning "ArgoCD Redis secret backup not found"
            ;;
        web-app)
            print_step "Restoring web app secrets..."
            kubectl apply -f "$BACKUP_DIR/web-app-db-secret.yaml" 2>/dev/null || print_warning "Web app database secret backup not found"
            kubectl apply -f "$BACKUP_DIR/web-app-api-secret.yaml" 2>/dev/null || print_warning "Web app API secret backup not found"
            kubectl apply -f "$BACKUP_DIR/web-app-external-secret.yaml" 2>/dev/null || print_warning "Web app external services secret backup not found"
            ;;
        vault)
            print_step "Restoring Vault secrets..."
            print_status "Vault restore requires manual process due to security considerations"
            ;;
        all)
            restore_secrets "monitoring"
            restore_secrets "web-app"
            restore_secrets "vault"
            ;;
        *)
            print_error "Unknown component: $component"
            exit 1
            ;;
    esac
    
    print_success "Secrets restore completed for $component"
}

# Function to list secrets
list_secrets() {
    local component=$1
    local namespace=${2:-""}
    
    print_header "Listing Secrets for $component"
    
    case $component in
        monitoring)
            namespace=${namespace:-"monitoring"}
            print_step "Secrets in namespace $namespace:"
            kubectl get secrets -n "$namespace" | grep -E "(grafana|prometheus|argocd)" || print_status "No monitoring secrets found"
            ;;
        web-app)
            namespace=${namespace:-"production"}
            print_step "Secrets in namespace $namespace:"
            kubectl get secrets -n "$namespace" | grep "web-app" || print_status "No web app secrets found"
            ;;
        vault)
            print_step "Vault secrets:"
            print_status "Vault secrets listing requires manual inspection"
            ;;
        all)
            list_secrets "monitoring"
            echo ""
            list_secrets "web-app"
            echo ""
            list_secrets "vault"
            ;;
        *)
            print_error "Unknown component: $component"
            exit 1
            ;;
    esac
}

# Parse command line arguments
COMMAND=""
COMPONENT=""
NAMESPACE=""
ENVIRONMENT="$DEFAULT_ENVIRONMENT"

while [[ $# -gt 0 ]]; do
    case $1 in
        create|rotate|verify|backup|restore|list)
            COMMAND="$1"
            shift
            ;;
        monitoring|web-app|vault|all)
            COMPONENT="$1"
            shift
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --force)
            FORCE=true
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

# Validate required arguments
if [ -z "$COMMAND" ] || [ -z "$COMPONENT" ]; then
    print_error "Command and component are required"
    show_usage
    exit 1
fi

# Main execution
main() {
    print_header "EKS GitOps Infrastructure Secrets Management"
    print_status "Command: $COMMAND"
    print_status "Component: $COMPONENT"
    print_status "Environment: $ENVIRONMENT"
    print_status "Namespace: ${NAMESPACE:-"component-specific"}"
    print_status "Backup Directory: $BACKUP_DIR"
    print_status "Force: $FORCE"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    echo ""
    
    # Execute command
    case $COMMAND in
        create)
            case $COMPONENT in
                monitoring)
                    create_monitoring_secrets "$NAMESPACE"
                    ;;
                web-app)
                    create_web_app_secrets "$NAMESPACE"
                    ;;
                vault)
                    setup_vault_secrets "$ENVIRONMENT"
                    ;;
                all)
                    create_monitoring_secrets
                    echo ""
                    create_web_app_secrets
                    echo ""
                    setup_vault_secrets "$ENVIRONMENT"
                    ;;
                *)
                    print_error "Unknown component: $COMPONENT"
                    exit 1
                    ;;
            esac
            ;;
        rotate)
            rotate_secrets "$COMPONENT" "$NAMESPACE"
            ;;
        verify)
            verify_secrets "$COMPONENT" "$NAMESPACE"
            ;;
        backup)
            backup_secrets "$COMPONENT"
            ;;
        restore)
            restore_secrets "$COMPONENT"
            ;;
        list)
            list_secrets "$COMPONENT" "$NAMESPACE"
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            show_usage
            exit 1
            ;;
    esac
    
    echo ""
    print_header "Secrets Management Completed Successfully"
}

# Run main function
main "$@"
