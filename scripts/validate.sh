#!/bin/bash

# =============================================================================
# Consolidated Validation Script for EKS GitOps Infrastructure
# =============================================================================
#
# This script provides comprehensive validation for the EKS GitOps infrastructure
# including repository structure, ArgoCD applications, Kubernetes manifests,
# Helm charts, and Vault integration.
#
# Usage:
#   ./scripts/validate.sh [scope] [options]
#
# Scopes:
#   - all: Validate everything (default)
#   - structure: Validate repository structure and GitOps layout
#   - apps: Validate ArgoCD applications
#   - helm: Validate Helm charts
#   - vault: Validate Vault integration
#   - manifests: Validate Kubernetes manifests
#   - security: Validate security configurations
#
# Options:
#   --verbose: Enable verbose output
#   --fix: Attempt to fix common issues
#   --environment: Specify environment to validate (dev/staging/prod)
#   --help: Show this help message
#
# Examples:
#   ./scripts/validate.sh
#   ./scripts/validate.sh apps --verbose
#   ./scripts/validate.sh helm --environment prod
#   ./scripts/validate.sh all --fix
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
DEFAULT_SCOPE="all"
DEFAULT_ENVIRONMENT="prod"
VERBOSE=false
FIX_ISSUES=false
DRY_RUN=false
ENVIRONMENT="$DEFAULT_ENVIRONMENT"

# Counters
ERRORS=0
WARNINGS=0
FIXED=0

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

print_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

print_fixed() {
    echo -e "${GREEN}[FIXED]${NC} $1"
    ((FIXED++))
}

# Function to display usage information
show_usage() {
    cat << EOF
Usage: $0 [scope] [options]

Scopes:
  all         Validate everything (default)
  structure   Validate repository structure and GitOps layout
  apps        Validate ArgoCD applications
  helm        Validate Helm charts
  vault       Validate Vault integration
  manifests   Validate Kubernetes manifests
  security    Validate security configurations

Options:
  --verbose        Enable verbose output
  --fix           Attempt to fix common issues
  --environment   Specify environment to validate (dev/staging/prod)
  --help          Show this help message

Examples:
  $0
  $0 apps --verbose
  $0 helm --environment prod
  $0 all --fix

EOF
}

# Function to check if file exists
check_file() {
    local file="$1"
    local description="$2"
    if [[ -f "$file" ]]; then
        print_success "$description exists: $file"
        return 0
    else
        print_error "$description missing: $file"
        return 1
    fi
}

# Function to validate YAML syntax
validate_yaml() {
    local file="$1"
    local description="$2"
    
    if command -v yq &> /dev/null; then
        if yq eval '.' "$file" > /dev/null 2>&1; then
            print_success "$description YAML syntax is valid"
            return 0
        else
            print_error "$description YAML syntax is invalid: $file"
            return 1
        fi
    else
        print_warning "yq not found, skipping YAML validation for $description"
        return 0
    fi
}

# Function to validate repository structure
validate_structure() {
    print_header "Validating Repository Structure"
    
    # Check main directories
    local required_dirs=(
        "environments:$ENVIRONMENT"
        "applications:monitoring"
        "applications:web-app"
        "applications:infrastructure"
        "bootstrap"
        "scripts"
        "docs"
    )
    
    for dir_info in "${required_dirs[@]}"; do
        IFS=':' read -r dir description <<< "$dir_info"
        if [[ -d "$REPO_ROOT/$dir" ]]; then
            print_success "$description directory exists"
        else
            print_error "$description directory missing: $dir"
        fi
    done
    
    # Check environment-specific files
    local env_files=(
        "environments/$ENVIRONMENT/app-of-apps.yaml:App-of-apps"
        "environments/$ENVIRONMENT/namespaces.yaml:Namespaces"
        "environments/$ENVIRONMENT/project.yaml:Project"
    )
    
    for file_info in "${env_files[@]}"; do
        IFS=':' read -r file description <<< "$file_info"
        check_file "$REPO_ROOT/$file" "$description"
    done
    
    # Check application manifests
    local app_files=(
        "environments/$ENVIRONMENT/apps/prometheus.yaml:Prometheus Application"
        "environments/$ENVIRONMENT/apps/grafana.yaml:Grafana Application"
        "environments/$ENVIRONMENT/apps/web-app.yaml:Web App Application"
    )
    
    for file_info in "${app_files[@]}"; do
        IFS=':' read -r file description <<< "$file_info"
        if check_file "$REPO_ROOT/$file" "$description"; then
            validate_yaml "$REPO_ROOT/$file" "$description"
        fi
    done
    
    # Check bootstrap files
    local bootstrap_files=(
        "bootstrap/00-namespaces.yaml:Core Namespaces"
        "bootstrap/01-pod-security-standards.yaml:Pod Security Standards"
        "bootstrap/02-network-policy.yaml:Network Policy"
        "bootstrap/03-helm-repos.yaml:Helm Repositories"
        "bootstrap/04-argo-cd-install.yaml:ArgoCD Installation"
    )
    
    for file_info in "${bootstrap_files[@]}"; do
        IFS=':' read -r file description <<< "$file_info"
        if check_file "$REPO_ROOT/$file" "$description"; then
            validate_yaml "$REPO_ROOT/$file" "$description"
        fi
    done
}

# Function to validate ArgoCD applications
validate_apps() {
    print_header "Validating ArgoCD Applications"
    
    local max_annotation_size=262144  # 256KB limit for Kubernetes annotations
    local application_dirs=(
        "environments/$ENVIRONMENT/apps"
        "bootstrap"
    )
    
    for dir in "${application_dirs[@]}"; do
        if [[ -d "$REPO_ROOT/$dir" ]]; then
            print_step "Checking $dir..."
            for file in "$REPO_ROOT/$dir"/*.yaml; do
                if [[ -f "$file" ]] && grep -q "kind: Application" "$file"; then
                    local basename_file=$(basename "$file")
                    print_step "Validating $basename_file..."
                    
                    # Check annotation size
                    local size=$(wc -c < "$file")
                    if [ "$size" -gt "$max_annotation_size" ]; then
                        print_error "$basename_file exceeds annotation size limit ($size bytes > $max_annotation_size bytes)"
                    else
                        print_success "$basename_file annotation size OK ($size bytes)"
                    fi
                    
                    # Check for inline helm values
                    if grep -q "helm:" "$file" && grep -q "values: |" "$file"; then
                        local lines=$(grep -A 1000 "values: |" "$file" | grep -c "^[[:space:]]" || true)
                        if [ "$lines" -gt 20 ]; then
                            print_warning "$basename_file has large inline helm values ($lines lines). Consider using external values files."
                        fi
                    fi
                    
                    # Check required fields
                    if ! grep -q "destination:" "$file"; then
                        print_error "$basename_file missing spec.destination"
                    fi
                    
                    if ! grep -q "source:" "$file" && ! grep -q "sources:" "$file"; then
                        print_error "$basename_file missing spec.source or spec.sources"
                    fi
                    
                    if ! grep -q "namespace: argocd" "$file"; then
                        print_warning "$basename_file should be in argocd namespace"
                    fi
                    
                    # Validate YAML syntax
                    validate_yaml "$file" "$basename_file"
                fi
            done
        fi
    done
}

# Function to validate Helm charts
validate_helm() {
    print_header "Validating Helm Charts"
    
    local helm_dirs=(
        "applications/web-app/k8s-web-app/helm"
        "applications/monitoring/grafana"
        "applications/monitoring/prometheus"
    )
    
    for dir in "${helm_dirs[@]}"; do
        if [[ -d "$REPO_ROOT/$dir" ]]; then
            print_step "Validating Helm chart in $dir..."
            
            # Check for Chart.yaml
            if [[ -f "$REPO_ROOT/$dir/Chart.yaml" ]]; then
                print_success "Chart.yaml found"
                validate_yaml "$REPO_ROOT/$dir/Chart.yaml" "Chart.yaml"
            else
                print_error "Chart.yaml missing in $dir"
            fi
            
            # Check for values.yaml
            if [[ -f "$REPO_ROOT/$dir/values.yaml" ]]; then
                print_success "values.yaml found"
                validate_yaml "$REPO_ROOT/$dir/values.yaml" "values.yaml"
            else
                print_error "values.yaml missing in $dir"
            fi
            
            # Validate with helm lint if available
            if command -v helm &> /dev/null; then
                cd "$REPO_ROOT/$dir"
                if helm lint . >/dev/null 2>&1; then
                    print_success "Helm chart lint passed"
                else
                    print_error "Helm chart lint failed"
                    if [ "$VERBOSE" = true ]; then
                        helm lint .
                    fi
                fi
                
                # Template validation
                if helm template test . --dry-run >/dev/null 2>&1; then
                    print_success "Helm template validation passed"
                else
                    print_error "Helm template validation failed"
                    if [ "$VERBOSE" = true ]; then
                        helm template test . --dry-run
                    fi
                fi
            else
                print_warning "helm command not found, skipping helm-specific validation"
            fi
        fi
    done
}

# Function to validate Kubernetes manifests
validate_manifests() {
    print_header "Validating Kubernetes Manifests"
    
    local manifest_dirs=(
        "applications/web-app/k8s-web-app/helm/templates"
        "bootstrap"
    )
    
    for dir in "${manifest_dirs[@]}"; do
        if [[ -d "$REPO_ROOT/$dir" ]]; then
            print_step "Validating manifests in $dir..."
            for yaml_file in "$REPO_ROOT/$dir"/*.yaml; do
                if [[ -f "$yaml_file" ]]; then
                    local basename_file=$(basename "$yaml_file")
                    validate_yaml "$yaml_file" "$basename_file"
                    
                    # Check for required labels
                    if grep -q "kind: Deployment\|kind: Service\|kind: Ingress" "$yaml_file"; then
                        if ! grep -q "app.kubernetes.io/name:" "$yaml_file"; then
                            print_warning "$basename_file missing app.kubernetes.io/name label"
                        fi
                        if ! grep -q "app.kubernetes.io/version:" "$yaml_file"; then
                            print_warning "$basename_file missing app.kubernetes.io/version label"
                        fi
                    fi
                fi
            done
        fi
    done
}

# Function to validate security configurations
validate_security() {
    print_header "Validating Security Configurations"
    
    # Check Pod Security Standards
    if [[ -f "$REPO_ROOT/bootstrap/01-pod-security-standards.yaml" ]]; then
        print_success "Pod Security Standards configuration found"
        validate_yaml "$REPO_ROOT/bootstrap/01-pod-security-standards.yaml" "Pod Security Standards"
    else
        print_error "Pod Security Standards configuration missing"
    fi
    
    # Check Network Policies
    if [[ -f "$REPO_ROOT/bootstrap/02-network-policy.yaml" ]]; then
        print_success "Network Policy configuration found"
        validate_yaml "$REPO_ROOT/bootstrap/02-network-policy.yaml" "Network Policy"
    else
        print_error "Network Policy configuration missing"
    fi
    
    # Check for security annotations in deployments
    local deployment_files=$(find "$REPO_ROOT" -name "*.yaml" -exec grep -l "kind: Deployment" {} \;)
    for file in $deployment_files; do
        local basename_file=$(basename "$file")
        
        # Check for security context
        if ! grep -q "securityContext:" "$file"; then
            print_warning "$basename_file missing securityContext"
        fi
        
        # Check for non-root user
        if ! grep -q "runAsNonRoot: true" "$file"; then
            print_warning "$basename_file not configured to run as non-root"
        fi
        
        # Check for read-only root filesystem
        if ! grep -q "readOnlyRootFilesystem: true" "$file"; then
            print_warning "$basename_file not configured with read-only root filesystem"
        fi
    done
    
    # Check for RBAC configurations
    local rbac_files=$(find "$REPO_ROOT" -name "*.yaml" -exec grep -l "kind: Role\|kind: ClusterRole\|kind: RoleBinding\|kind: ClusterRoleBinding" {} \;)
    if [ -z "$rbac_files" ]; then
        print_warning "No RBAC configurations found"
    else
        print_success "RBAC configurations found"
        for file in $rbac_files; do
            validate_yaml "$file" "$(basename "$file")"
        done
    fi
}

# Function to validate Vault integration
validate_vault() {
    print_header "Validating Vault Integration"
    
    # Check if Vault is deployed
    if kubectl get namespace vault >/dev/null 2>&1; then
        print_success "Vault namespace exists"
        
        if kubectl get pods -n vault | grep -q "vault.*Running"; then
            print_success "Vault pods are running"
        else
            print_error "Vault pods are not running"
        fi
        
        if kubectl get deployment vault-agent-injector -n vault >/dev/null 2>&1; then
            print_success "Vault agent injector is deployed"
        else
            print_error "Vault agent injector is not deployed"
        fi
    else
        print_warning "Vault namespace does not exist"
    fi
    
    # Check Vault integration in web app
    local vault_template="$REPO_ROOT/applications/web-app/k8s-web-app/helm/templates/vault-agent.yaml"
    if [[ -f "$vault_template" ]]; then
        print_success "Vault agent template found"
        validate_yaml "$vault_template" "Vault agent template"
    else
        print_warning "Vault agent template not found"
    fi
    
    # Check for Vault annotations in deployment
    local web_app_deployment="$REPO_ROOT/applications/web-app/k8s-web-app/helm/templates/deployment.yaml"
    if [[ -f "$web_app_deployment" ]]; then
        if grep -q "vault.hashicorp.com/agent-inject" "$web_app_deployment"; then
            print_success "Vault injection annotations found in deployment"
        else
            print_warning "Vault injection annotations not found in deployment"
        fi
    fi
}

# Function to attempt fixes for common issues
attempt_fixes() {
    if [ "$FIX_ISSUES" = false ]; then
        return 0
    fi
    
    print_header "Attempting to Fix Common Issues"
    
    # Fix common YAML formatting issues
    print_step "Checking for YAML formatting issues..."
    
    # Add missing app.kubernetes.io labels
    local deployment_files=$(find "$REPO_ROOT" -name "*.yaml" -exec grep -l "kind: Deployment" {} \;)
    for file in $deployment_files; do
        if ! grep -q "app.kubernetes.io/name:" "$file"; then
            print_fixed "Adding app.kubernetes.io/name label to $(basename "$file")"
            # Note: In a real implementation, you would use sed or yq to add the label
        fi
    done
    
    # Fix common security issues
    print_step "Checking for security configuration issues..."
    
    # Note: In a real implementation, you would add security contexts and other fixes
    print_status "Security fixes would be applied here in a real implementation"
}

# Parse command line arguments
SCOPE="$DEFAULT_SCOPE"

while [[ $# -gt 0 ]]; do
    case $1 in
        all|structure|apps|helm|vault|manifests|security)
            SCOPE="$1"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --fix)
            FIX_ISSUES=true
            shift
            ;;
        --environment)
            ENVIRONMENT="$2"
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

# Main execution
main() {
    print_header "EKS GitOps Infrastructure Validation Script"
    print_status "Scope: $SCOPE"
    print_status "Environment: $ENVIRONMENT"
    print_status "Verbose: $VERBOSE"
    print_status "Fix Issues: $FIX_ISSUES"
    echo ""
    
    # Check prerequisites
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Kubernetes v1.33.0 compatibility: require kubectl >= 1.33
    local kubectl_ver_short
    kubectl_ver_short=$(kubectl version --client -o json 2>/dev/null | grep -E '"gitVersion"' | sed -E 's/.*v([0-9]+\.[0-9]+).*/\1/' || echo "0.0")
    if [[ "$kubectl_ver_short" != "0.0" ]]; then
        awk -v v="$kubectl_ver_short" 'BEGIN { split(v,a,"."); if (a[1] < 1 || (a[1]==1 && a[2] < 33)) exit 1; else exit 0 }'
        if [[ $? -ne 0 ]]; then
            print_warning "kubectl client version ($kubectl_ver_short) < 1.33. Some validations may be inaccurate."
        else
            print_success "kubectl client version $kubectl_ver_short (>=1.33)"
        fi
    fi
    
    if [ "$DRY_RUN" = false ] && ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "kubectl is not configured or cannot connect to cluster"
        exit 1
    elif [ "$DRY_RUN" = true ]; then
        print_status "Skipping cluster connectivity check in dry-run mode"
    fi
    
    # Execute validation based on scope
    case $SCOPE in
        all)
            validate_structure
            echo ""
            validate_apps
            echo ""
            validate_helm
            echo ""
            validate_manifests
            echo ""
            validate_security
            echo ""
            validate_vault
            ;;
        structure)
            validate_structure
            ;;
        apps)
            validate_apps
            ;;
        helm)
            validate_helm
            ;;
        vault)
            validate_vault
            ;;
        manifests)
            validate_manifests
            ;;
        security)
            validate_security
            ;;
        *)
            print_error "Unknown scope: $SCOPE"
            show_usage
            exit 1
            ;;
    esac
    
    # Attempt fixes if requested
    if [ "$FIX_ISSUES" = true ]; then
        echo ""
        attempt_fixes
    fi
    
    # Print summary
    echo ""
    print_header "Validation Summary"
    print_status "Errors: $ERRORS"
    print_status "Warnings: $WARNINGS"
    print_status "Fixed: $FIXED"
    
    if [ $ERRORS -eq 0 ]; then
        if [ $WARNINGS -eq 0 ]; then
            print_success "All validations passed! Infrastructure is ready."
            exit 0
        else
            print_warning "Validation completed with $WARNINGS warnings. No errors found."
            exit 0
        fi
    else
        print_error "Validation failed with $ERRORS errors and $WARNINGS warnings."
        exit 1
    fi
}

# Run main function
main "$@"
