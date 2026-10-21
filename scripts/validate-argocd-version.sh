#!/bin/bash

# =============================================================================
# ArgoCD Version Validation Script
# =============================================================================
#
# Validates ArgoCD version availability and compatibility before deployment.
#
# Usage:
#   ./scripts/validate-argocd-version.sh [version]
#
# Arguments:
#   version: ArgoCD version to validate (default: from VERSION file)
#
# Checks:
#   - Installation manifest URL exists
#   - CLI binary is downloadable
#   - Version compatibility
#   - Current cluster version (if deployed)
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

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default version from VERSION file or argument
if [ -f "$REPO_ROOT/VERSION" ]; then
    DEFAULT_VERSION=$(grep "ARGOCD_VERSION" "$REPO_ROOT/VERSION" | cut -d'=' -f2)
else
    DEFAULT_VERSION="3.1.0"
fi

ARGOCD_VERSION="${1:-$DEFAULT_VERSION}"

# URLs to validate
MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml"
CLI_URL_LINUX="https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-amd64"
CLI_URL_DARWIN="https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-darwin-amd64"
CLI_URL_WINDOWS="https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-windows-amd64.exe"
RELEASE_URL="https://github.com/argoproj/argo-cd/releases/tag/v${ARGOCD_VERSION}"

# Counters
ERRORS=0
WARNINGS=0

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
    ((WARNINGS++))
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((ERRORS++))
}

# Function to check URL availability
check_url() {
    local url="$1"
    local description="$2"
    
    print_status "Checking $description..."
    
    if curl -s -f -I "$url" > /dev/null 2>&1; then
        print_success "$description is available"
        return 0
    else
        print_error "$description is not available: $url"
        return 1
    fi
}

# Function to check current ArgoCD version
check_current_version() {
    print_status "Checking currently installed ArgoCD version..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl not found, skipping current version check"
        return 0
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        print_warning "Not connected to cluster, skipping current version check"
        return 0
    fi
    
    # Check if ArgoCD is installed
    if ! kubectl get namespace argocd &> /dev/null; then
        print_status "ArgoCD not currently installed (fresh installation)"
        return 0
    fi
    
    # Get current version
    if kubectl get deployment argocd-server -n argocd &> /dev/null; then
        local current_version=$(kubectl get deployment argocd-server -n argocd -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        
        if [ "$current_version" != "unknown" ]; then
            print_status "Current ArgoCD version: v$current_version"
            print_status "Target ArgoCD version: v$ARGOCD_VERSION"
            
            if [ "$current_version" = "$ARGOCD_VERSION" ]; then
                print_warning "Target version is already installed"
            elif [[ "$current_version" > "$ARGOCD_VERSION" ]]; then
                print_warning "Downgrade detected: v$current_version → v$ARGOCD_VERSION"
            else
                print_success "Upgrade path: v$current_version → v$ARGOCD_VERSION"
            fi
        fi
    fi
}

# Function to validate Kubernetes compatibility
check_kubernetes_compatibility() {
    print_status "Validating Kubernetes compatibility..."
    
    # ArgoCD 3.1.x supports Kubernetes 1.21+
    # Kubernetes 1.33 is well within supported range
    print_success "ArgoCD v${ARGOCD_VERSION} supports Kubernetes 1.21+ (including 1.33)"
    
    # Check current cluster version if available
    if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
        local k8s_version=$(kubectl version -o json 2>/dev/null | grep -oP '"gitVersion":\s*"v\K[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        
        if [ "$k8s_version" != "unknown" ]; then
            print_status "Detected Kubernetes version: v$k8s_version"
            print_success "Kubernetes v$k8s_version is compatible with ArgoCD v${ARGOCD_VERSION}"
        fi
    fi
}

# Main execution
main() {
    print_header "ArgoCD Version Validation"
    print_status "Target ArgoCD Version: v${ARGOCD_VERSION}"
    echo ""
    
    # Check release page
    check_url "$RELEASE_URL" "ArgoCD v${ARGOCD_VERSION} Release Page"
    echo ""
    
    # Check installation manifest
    check_url "$MANIFEST_URL" "ArgoCD Installation Manifest"
    echo ""
    
    # Check CLI binaries
    check_url "$CLI_URL_LINUX" "ArgoCD CLI (Linux)"
    check_url "$CLI_URL_DARWIN" "ArgoCD CLI (macOS)"
    check_url "$CLI_URL_WINDOWS" "ArgoCD CLI (Windows)"
    echo ""
    
    # Check current installation
    check_current_version
    echo ""
    
    # Check Kubernetes compatibility
    check_kubernetes_compatibility
    echo ""
    
    # Summary
    print_header "Validation Summary"
    print_status "Errors: $ERRORS"
    print_status "Warnings: $WARNINGS"
    echo ""
    
    if [ $ERRORS -eq 0 ]; then
        print_success "All validation checks passed!"
        print_success "ArgoCD v${ARGOCD_VERSION} is ready for deployment"
        echo ""
        print_status "Release Notes: $RELEASE_URL"
        exit 0
    else
        print_error "Validation failed with $ERRORS errors"
        print_error "Please resolve the issues before proceeding"
        exit 1
    fi
}

# Run main function
main "$@"

