#!/bin/bash

# Validation Script for GitOps Fixes
# Validates Helm charts, Kubernetes manifests, and ArgoCD applications
# Author: Production-Ready EKS Cluster with GitOps Team
# Date: 2025-10-07

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to print test results
print_pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
    ((PASS_COUNT++))
}

print_fail() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    ((FAIL_COUNT++))
}

print_warn() {
    echo -e "${YELLOW}⚠️  WARN:${NC} $1"
    ((WARN_COUNT++))
}

print_info() {
    echo -e "${BLUE}ℹ️  INFO:${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local all_tools_available=true
    
    # Check for required tools
    if command -v helm &> /dev/null; then
        HELM_VERSION=$(helm version --short)
        print_pass "Helm is installed: ${HELM_VERSION}"
    else
        print_fail "Helm is not installed"
        all_tools_available=false
    fi
    
    if command -v kubectl &> /dev/null; then
        KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || kubectl version --client)
        print_pass "kubectl is installed: ${KUBECTL_VERSION}"
    else
        print_warn "kubectl is not installed (skipping dry-run tests)"
    fi
    
    if command -v yamllint &> /dev/null; then
        print_pass "yamllint is installed"
    else
        print_warn "yamllint is not installed (skipping YAML syntax checks)"
    fi
    
    if [ "$all_tools_available" = false ]; then
        print_fail "Missing required tools. Please install them and try again."
        exit 1
    fi
}

# Validate Helm charts
validate_helm_charts() {
    print_header "Validating Helm Charts"
    
    # k8s-web-app Helm chart
    print_info "Validating k8s-web-app Helm chart..."
    if helm lint applications/web-app/k8s-web-app/helm/ --strict; then
        print_pass "k8s-web-app Helm chart passed lint"
    else
        print_fail "k8s-web-app Helm chart failed lint"
    fi
    
    # Template the chart to check for rendering errors
    print_info "Templating k8s-web-app chart with production values..."
    if helm template k8s-web-app applications/web-app/k8s-web-app/helm/ \
        -f applications/web-app/k8s-web-app/values.yaml \
        --namespace production > /tmp/k8s-web-app-rendered.yaml 2>&1; then
        print_pass "k8s-web-app chart templates successfully"
    else
        print_fail "k8s-web-app chart failed to template"
        cat /tmp/k8s-web-app-rendered.yaml
    fi
}

# Validate Prometheus values
validate_prometheus_values() {
    print_header "Validating Prometheus Configuration"
    
    # Check ServiceAccount configuration
    print_info "Checking Prometheus ServiceAccount configuration..."
    if grep -q "serviceAccount:" applications/monitoring/prometheus/values-production.yaml; then
        if grep -q "create: true" applications/monitoring/prometheus/values-production.yaml; then
            print_pass "Prometheus ServiceAccount creation is enabled"
        else
            print_fail "Prometheus ServiceAccount creation is disabled"
        fi
        
        if grep -q "name: prometheus-prod-kube-prome-prometheus" applications/monitoring/prometheus/values-production.yaml; then
            print_pass "Prometheus ServiceAccount name is correctly set"
        else
            print_warn "Prometheus ServiceAccount name might not match expected value"
        fi
    else
        print_fail "Prometheus ServiceAccount configuration is missing"
    fi
    
    # Check kubeScheduler rules
    print_info "Checking kubeScheduler rules configuration..."
    if grep -q "kubeScheduler: false" applications/monitoring/prometheus/values-production.yaml; then
        print_pass "kubeScheduler rules are disabled (correct for EKS)"
    else
        print_warn "kubeScheduler rules might be enabled (problematic in EKS)"
    fi
    
    # Check AlertManager ServiceAccount
    print_info "Checking AlertManager ServiceAccount configuration..."
    if grep -A 3 "alertmanager:" applications/monitoring/prometheus/values-production.yaml | grep -q "serviceAccount:"; then
        print_pass "AlertManager ServiceAccount configuration is present"
    else
        print_warn "AlertManager ServiceAccount configuration might be missing"
    fi
}

# Validate Grafana configuration
validate_grafana_config() {
    print_header "Validating Grafana Configuration"
    
    # Check that duplicate ConfigMap is removed
    print_info "Checking for duplicate Grafana ConfigMap..."
    if [ -f "environments/prod/secrets/grafana-configmap.yaml" ]; then
        print_fail "Duplicate Grafana ConfigMap still exists (should be removed)"
    else
        print_pass "Duplicate Grafana ConfigMap has been removed"
    fi
    
    # Check Grafana admin secret exists
    print_info "Checking Grafana admin secret..."
    if [ -f "environments/prod/secrets/grafana-admin-secret.yaml" ]; then
        print_pass "Grafana admin secret exists"
    else
        print_fail "Grafana admin secret is missing"
    fi
}

# Validate security contexts
validate_security_contexts() {
    print_header "Validating Security Contexts"
    
    # Check k8s-web-app values.yaml
    print_info "Checking k8s-web-app security contexts..."
    
    # Check pod-level seccompProfile
    if grep -A 5 "podSecurityContext:" applications/web-app/k8s-web-app/values.yaml | grep -q "type: RuntimeDefault"; then
        print_pass "Pod-level seccompProfile is set in k8s-web-app values.yaml"
    else
        print_fail "Pod-level seccompProfile is missing in k8s-web-app values.yaml"
    fi
    
    # Check container-level seccompProfile
    if grep -A 10 "^securityContext:" applications/web-app/k8s-web-app/values.yaml | grep -q "type: RuntimeDefault"; then
        print_pass "Container-level seccompProfile is set in k8s-web-app values.yaml"
    else
        print_fail "Container-level seccompProfile is missing in k8s-web-app values.yaml"
    fi
    
    # Check helm template values.yaml
    print_info "Checking k8s-web-app Helm template security contexts..."
    
    if grep -A 10 "^securityContext:" applications/web-app/k8s-web-app/helm/values.yaml | grep -q "type: RuntimeDefault"; then
        print_pass "Container-level seccompProfile is set in Helm template values.yaml"
    else
        print_fail "Container-level seccompProfile is missing in Helm template values.yaml"
    fi
    
    # Check runAsNonRoot
    if grep -A 10 "^securityContext:" applications/web-app/k8s-web-app/values.yaml | grep -q "runAsNonRoot: true"; then
        print_pass "runAsNonRoot is set in container securityContext"
    else
        print_warn "runAsNonRoot might be missing in container securityContext"
    fi
}

# Validate ArgoCD applications
validate_argocd_apps() {
    print_header "Validating ArgoCD Applications"
    
    # Check sync waves
    print_info "Checking ArgoCD sync wave order..."
    
    local monitoring_secrets_wave=$(grep "argocd.argoproj.io/sync-wave" environments/prod/apps/monitoring-secrets.yaml | grep -oP '"\K[^"]+')
    local prometheus_wave=$(grep "argocd.argoproj.io/sync-wave" environments/prod/apps/prometheus.yaml | grep -oP '"\K[^"]+')
    local grafana_wave=$(grep "argocd.argoproj.io/sync-wave" environments/prod/apps/grafana.yaml | grep -oP '"\K[^"]+')
    local webapp_wave=$(grep "argocd.argoproj.io/sync-wave" environments/prod/apps/web-app.yaml | grep -oP '"\K[^"]+')
    
    print_info "Sync waves: monitoring-secrets=$monitoring_secrets_wave, prometheus=$prometheus_wave, grafana=$grafana_wave, web-app=$webapp_wave"
    
    if [ "$monitoring_secrets_wave" -lt "$prometheus_wave" ] && [ "$prometheus_wave" -lt "$grafana_wave" ] && [ "$grafana_wave" -lt "$webapp_wave" ]; then
        print_pass "Sync wave order is correct"
    else
        print_warn "Sync wave order might not be optimal"
    fi
    
    # Validate YAML syntax
    print_info "Validating ArgoCD application YAML syntax..."
    for app_file in environments/prod/apps/*.yaml; do
        if command -v yamllint &> /dev/null; then
            if yamllint -d relaxed "$app_file" > /dev/null 2>&1; then
                print_pass "$(basename "$app_file") has valid YAML syntax"
            else
                print_fail "$(basename "$app_file") has invalid YAML syntax"
            fi
        fi
    done
}

# Validate multi-arch documentation
validate_multiarch_docs() {
    print_header "Validating Multi-Arch Build Documentation"
    
    # Check if documentation exists
    if [ -f "examples/web-app/MULTI_ARCH_BUILD.md" ]; then
        print_pass "Multi-arch build documentation exists"
    else
        print_fail "Multi-arch build documentation is missing"
    fi
    
    # Check if build script is updated
    if [ -f "examples/web-app/build-and-push.sh" ]; then
        if grep -q "buildx" examples/web-app/build-and-push.sh; then
            print_pass "Build script supports multi-arch builds"
        else
            print_warn "Build script might not support multi-arch builds"
        fi
    else
        print_fail "Build script is missing"
    fi
    
    # Check if GitHub Actions workflow exists
    if [ -f ".github/workflows/docker-build-push.yaml" ]; then
        print_pass "GitHub Actions workflow for multi-arch builds exists"
    else
        print_warn "GitHub Actions workflow for multi-arch builds is missing"
    fi
}

# Validate kubectl dry-run (if kubectl is available and configured)
validate_kubectl_dryrun() {
    if ! command -v kubectl &> /dev/null; then
        print_warn "kubectl not available, skipping dry-run validation"
        return
    fi
    
    print_header "Validating Kubernetes Manifests (kubectl dry-run)"
    
    # Try to validate rendered manifests
    if [ -f "/tmp/k8s-web-app-rendered.yaml" ]; then
        print_info "Validating rendered k8s-web-app manifests..."
        if kubectl apply --dry-run=client -f /tmp/k8s-web-app-rendered.yaml > /dev/null 2>&1; then
            print_pass "Rendered k8s-web-app manifests are valid"
        else
            print_warn "Could not validate rendered manifests (cluster context might be missing)"
        fi
    fi
}

# Generate summary report
generate_summary() {
    print_header "Validation Summary"
    
    echo ""
    echo "Results:"
    echo -e "  ${GREEN}✅ Passed: ${PASS_COUNT}${NC}"
    echo -e "  ${RED}❌ Failed: ${FAIL_COUNT}${NC}"
    echo -e "  ${YELLOW}⚠️  Warnings: ${WARN_COUNT}${NC}"
    echo ""
    
    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "${GREEN}🎉 All critical validations passed!${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Review any warnings above"
        echo "  2. Rebuild Docker image with multi-arch support (see examples/web-app/MULTI_ARCH_BUILD.md)"
        echo "  3. Commit changes and create PR"
        echo "  4. Deploy to staging for testing"
        echo "  5. Deploy to production after validation"
        return 0
    else
        echo -e "${RED}❌ Some validations failed. Please fix the issues above before proceeding.${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║   GitOps Deployment Fixes - Validation Script                ║"
    echo "║   Production-Ready EKS Cluster with GitOps                   ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    
    check_prerequisites
    validate_helm_charts
    validate_prometheus_values
    validate_grafana_config
    validate_security_contexts
    validate_argocd_apps
    validate_multiarch_docs
    validate_kubectl_dryrun
    generate_summary
}

# Run main function
main
exit_code=$?

# Clean up temporary files
rm -f /tmp/k8s-web-app-rendered.yaml

exit $exit_code

