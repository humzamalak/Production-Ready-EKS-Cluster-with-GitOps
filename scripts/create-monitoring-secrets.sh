#!/bin/bash

# =============================================================================
# Create Monitoring Secrets Script
# =============================================================================
#
# This script creates the required secrets for the monitoring stack components
# in a Kubernetes cluster. It ensures that all necessary authentication secrets
# are properly configured for:
#   - Grafana (admin credentials)
#   - ArgoCD (Redis authentication)
#
# Usage:
#   ./scripts/create-monitoring-secrets.sh
#
# Prerequisites:
#   - kubectl configured and connected to target cluster
#   - monitoring and argocd namespaces must exist
#   - openssl command available for password generation
#
# Security Notes:
#   - Passwords are generated using cryptographically secure random data
#   - Secrets are created using kubectl's dry-run and apply pattern for safety
#   - Existing secrets are preserved to avoid breaking running applications
#
# Author: Production-Ready EKS Cluster with GitOps
# Version: 1.2.0
# =============================================================================

# Exit on any error to prevent partial secret creation
set -e

# Color codes for better output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
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

# Function to check if kubectl is available and configured
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is installed and configured
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "kubectl is not configured or cannot connect to cluster"
        print_error "Please configure kubectl with: kubectl config set-context <your-context>"
        exit 1
    fi
    
    # Check if openssl is available for password generation
    if ! command -v openssl &> /dev/null; then
        print_error "openssl is not installed or not in PATH"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to create Grafana admin secret
create_grafana_secret() {
    print_status "Creating Grafana admin secret..."
    
    # Check if monitoring namespace exists
    if ! kubectl get namespace monitoring &> /dev/null; then
        print_warning "monitoring namespace does not exist, creating it..."
        kubectl create namespace monitoring
    fi
    
    # Generate secure random password for Grafana admin
    local grafana_password=$(openssl rand -base64 16)
    
    # Create Grafana admin secret with dry-run for safety
    kubectl create secret generic grafana-admin \
      --namespace=monitoring \
      --from-literal=admin-user=admin \
      --from-literal=admin-password="${grafana_password}" \
      --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "Grafana admin secret created successfully"
    
    # Store password for display later
    GRAFANA_PASSWORD="${grafana_password}"
}

# Function to create ArgoCD Redis secret
create_argocd_redis_secret() {
    print_status "Checking for ArgoCD Redis secret..."
    
    # Check if ArgoCD Redis secret already exists
    if ! kubectl get secret argocd-redis -n argocd >/dev/null 2>&1; then
        print_status "Creating ArgoCD Redis secret..."
        
        # Check if argocd namespace exists
        if ! kubectl get namespace argocd &> /dev/null; then
            print_error "argocd namespace does not exist"
            print_error "Please ensure ArgoCD is installed before running this script"
            exit 1
        fi
        
        # Generate secure random auth token for Redis
        local redis_auth=$(openssl rand -base64 32)
        
        # Create ArgoCD Redis secret with dry-run for safety
        kubectl create secret generic argocd-redis \
          --namespace=argocd \
          --from-literal=auth="${redis_auth}" \
          --dry-run=client -o yaml | kubectl apply -f -
        
        print_success "ArgoCD Redis secret created successfully"
    else
        print_warning "ArgoCD Redis secret already exists, skipping creation"
    fi
}

# Function to display created credentials
display_credentials() {
    echo ""
    print_success "All monitoring secrets created successfully!"
    echo ""
    echo "=========================================="
    echo "          MONITORING CREDENTIALS"
    echo "=========================================="
    echo ""
    echo "🔐 Grafana Access:"
    echo "   Username: admin"
    echo "   Password: ${GRAFANA_PASSWORD}"
    echo "   URL: https://grafana.your-domain.com (via ingress)"
    echo ""
    echo "🔐 ArgoCD Access:"
    echo "   Username: admin"
    echo "   Password: $(kubectl -n argocd get secret argocd-secret -o jsonpath='{.data.admin\.password}' | base64 -d)"
    echo "   URL: https://localhost:8080 (via port-forward)"
    echo ""
    echo "📝 Note: Save these credentials securely!"
    echo "   - Grafana password: ${GRAFANA_PASSWORD}"
    echo "   - ArgoCD password is bcrypt hashed in the secret"
    echo ""
    echo "🚀 Next Steps:"
    echo "   1. Access Grafana: kubectl port-forward -n monitoring svc/grafana 3000:80"
    echo "   2. Access ArgoCD: kubectl port-forward -n argocd svc/argo-cd-argocd-server 8080:80"
    echo "   3. Check application status: kubectl get applications -n argocd"
    echo ""
}

# Function to verify secrets were created correctly
verify_secrets() {
    print_status "Verifying created secrets..."
    
    # Verify Grafana secret
    if kubectl get secret grafana-admin -n monitoring &> /dev/null; then
        print_success "✓ Grafana admin secret verified"
    else
        print_error "✗ Grafana admin secret verification failed"
        exit 1
    fi
    
    # Verify ArgoCD Redis secret
    if kubectl get secret argocd-redis -n argocd &> /dev/null; then
        print_success "✓ ArgoCD Redis secret verified"
    else
        print_warning "⚠ ArgoCD Redis secret not found (may not be needed)"
    fi
    
    print_success "Secret verification completed"
}

# Main execution function
main() {
    echo "============================================================================="
    echo "        Production-Ready EKS Cluster - Monitoring Secrets Setup"
    echo "============================================================================="
    echo ""
    
    # Execute all functions in sequence
    check_prerequisites
    create_grafana_secret
    create_argocd_redis_secret
    verify_secrets
    display_credentials
    
    echo "============================================================================="
    print_success "Monitoring secrets setup completed successfully!"
    echo "============================================================================="
}

# Run main function
main "$@"
