#!/bin/bash

# =============================================================================
# ArgoCD Rollback Script
# =============================================================================
#
# Automated rollback from ArgoCD v3.1.0 to v2.13.0
#
# Usage:
#   ./scripts/rollback-argocd.sh [--force]
#
# Options:
#   --force: Skip confirmation prompt
#
# What it does:
#   1. Backs up current Applications and Projects
#   2. Uninstalls current ArgoCD version
#   3. Reinstalls ArgoCD v2.13.0
#   4. Restores Applications and Projects
#   5. Verifies rollback success
#
# Author: Production-Ready EKS Cluster with GitOps
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
ROLLBACK_VERSION="2.13.0"
BACKUP_DIR="/tmp/argocd-rollback-backup-$(date +%Y%m%d-%H%M%S)"
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

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

# Function to confirm rollback
confirm_rollback() {
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    echo ""
    print_warning "This will rollback ArgoCD from current version to v${ROLLBACK_VERSION}"
    print_warning "Applications and Projects will be backed up and restored"
    echo ""
    read -p "Are you sure you want to proceed? (yes/no): " response
    
    case "$response" in
        yes|YES|y|Y)
            return 0
            ;;
        *)
            print_status "Rollback cancelled"
            exit 0
            ;;
    esac
}

# Function to backup ArgoCD resources
backup_resources() {
    print_header "Backing Up ArgoCD Resources"
    
    mkdir -p "$BACKUP_DIR"
    print_status "Backup directory: $BACKUP_DIR"
    
    # Backup Applications
    print_status "Backing up Applications..."
    kubectl get applications -n argocd -o yaml > "$BACKUP_DIR/applications.yaml" 2>/dev/null || print_warning "No Applications to backup"
    
    # Backup AppProjects
    print_status "Backing up AppProjects..."
    kubectl get appprojects -n argocd -o yaml > "$BACKUP_DIR/appprojects.yaml" 2>/dev/null || print_warning "No AppProjects to backup"
    
    # Backup ConfigMaps
    print_status "Backing up ConfigMaps..."
    kubectl get configmap -n argocd -o yaml > "$BACKUP_DIR/configmaps.yaml" 2>/dev/null || print_warning "No ConfigMaps to backup"
    
    # Backup Secrets (excluding initial admin secret - will be regenerated)
    print_status "Backing up Secrets..."
    kubectl get secrets -n argocd -o yaml > "$BACKUP_DIR/secrets.yaml" 2>/dev/null || print_warning "No Secrets to backup"
    
    print_success "Backup completed: $BACKUP_DIR"
}

# Function to get current ArgoCD version
get_current_version() {
    if kubectl get deployment argocd-server -n argocd &> /dev/null; then
        kubectl get deployment argocd-server -n argocd -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown"
    else
        echo "not-installed"
    fi
}

# Function to uninstall current ArgoCD
uninstall_argocd() {
    local current_version=$(get_current_version)
    
    print_header "Uninstalling Current ArgoCD"
    
    if [ "$current_version" = "not-installed" ]; then
        print_warning "ArgoCD is not currently installed"
        return 0
    fi
    
    print_status "Uninstalling ArgoCD v$current_version..."
    
    # Try to uninstall using the current version manifest
    if [ "$current_version" != "unknown" ]; then
        kubectl delete -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/v${current_version}/manifests/install.yaml" 2>/dev/null || print_warning "Failed to uninstall using v${current_version} manifest"
    fi
    
    # Fallback: delete all ArgoCD resources
    print_status "Cleaning up remaining resources..."
    kubectl delete all --all -n argocd 2>/dev/null || true
    kubectl delete configmap --all -n argocd 2>/dev/null || true
    kubectl delete secret --all -n argocd 2>/dev/null || true
    
    # Wait for cleanup
    print_status "Waiting for resources to be cleaned up..."
    sleep 10
    
    print_success "ArgoCD uninstalled"
}

# Function to install ArgoCD v2.13.0
install_argocd_2_13() {
    print_header "Installing ArgoCD v${ROLLBACK_VERSION}"
    
    # Install ArgoCD
    print_status "Applying ArgoCD v${ROLLBACK_VERSION} manifest..."
    kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/v${ROLLBACK_VERSION}/manifests/install.yaml"
    
    # Wait for deployment
    print_status "Waiting for ArgoCD to be ready (this may take 3-5 minutes)..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd 2>/dev/null || {
        print_warning "Timeout waiting for argocd-server, checking status..."
        kubectl get pods -n argocd
    }
    
    # Additional wait for initialization
    sleep 30
    
    print_success "ArgoCD v${ROLLBACK_VERSION} installed"
}

# Function to restore ArgoCD resources
restore_resources() {
    print_header "Restoring ArgoCD Resources"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "Backup directory not found: $BACKUP_DIR"
        return 1
    fi
    
    # Restore AppProjects first (Applications depend on them)
    if [ -f "$BACKUP_DIR/appprojects.yaml" ]; then
        print_status "Restoring AppProjects..."
        kubectl apply -f "$BACKUP_DIR/appprojects.yaml" 2>/dev/null || print_warning "Failed to restore AppProjects"
    fi
    
    # Wait for projects to be created
    sleep 5
    
    # Restore Applications
    if [ -f "$BACKUP_DIR/applications.yaml" ]; then
        print_status "Restoring Applications..."
        kubectl apply -f "$BACKUP_DIR/applications.yaml" 2>/dev/null || print_warning "Failed to restore Applications"
    fi
    
    print_success "Resources restored from backup"
}

# Function to verify rollback
verify_rollback() {
    print_header "Verifying Rollback"
    
    # Check version
    local current_version=$(get_current_version)
    print_status "Current ArgoCD version: v$current_version"
    
    if [ "$current_version" = "$ROLLBACK_VERSION" ]; then
        print_success "Rollback to v${ROLLBACK_VERSION} successful!"
    else
        print_error "Rollback verification failed. Current version: v$current_version"
        return 1
    fi
    
    # Check Applications
    local app_count=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
    print_status "Applications restored: $app_count"
    
    # Check ArgoCD health
    if kubectl get pods -n argocd | grep -q "Running"; then
        print_success "ArgoCD pods are running"
    else
        print_warning "Some ArgoCD pods may not be running yet"
    fi
}

# Main execution
main() {
    print_header "ArgoCD Rollback Script"
    print_status "Rolling back to ArgoCD v${ROLLBACK_VERSION}"
    echo ""
    
    # Prerequisites check
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Not connected to Kubernetes cluster"
        exit 1
    fi
    
    # Confirm rollback
    confirm_rollback
    echo ""
    
    # Execute rollback
    backup_resources
    echo ""
    
    uninstall_argocd
    echo ""
    
    install_argocd_2_13
    echo ""
    
    restore_resources
    echo ""
    
    verify_rollback
    echo ""
    
    print_header "Rollback Complete"
    print_success "ArgoCD has been rolled back to v${ROLLBACK_VERSION}"
    print_status "Backup location: $BACKUP_DIR"
    echo ""
    print_status "Next steps:"
    echo "  1. Get admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    echo "  2. Login: ./scripts/argocd-login.sh"
    echo "  3. Verify applications: kubectl get applications -n argocd"
}

# Run main function
main "$@"

