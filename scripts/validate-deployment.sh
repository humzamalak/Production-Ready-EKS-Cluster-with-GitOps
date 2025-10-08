#!/bin/bash

# =============================================================================
# Deployment Validation Script
# =============================================================================
#
# This script validates that all Argo CD sync and deployment issues have been
# fixed and the cluster is in a healthy state.
#
# Usage: ./scripts/validate-deployment.sh [environment]
#   environment: prod or staging (default: prod)
#
# Author: Production-Ready EKS Cluster with GitOps
# Version: 1.0.0
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Environment (default: prod)
ENVIRONMENT="${1:-prod}"

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Print functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED++))
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED++))
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARNINGS++))
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if argocd CLI is available
if ! command -v argocd &> /dev/null; then
    print_warning "argocd CLI is not installed. Some checks will be skipped."
fi

# Set namespaces based on environment
if [ "$ENVIRONMENT" = "prod" ]; then
    APP_NAMESPACE="production"
    MONITORING_NAMESPACE="monitoring"
    APP_PREFIX="prod"
else
    APP_NAMESPACE="staging"
    MONITORING_NAMESPACE="staging-monitoring"
    APP_PREFIX="staging"
fi

print_header "Validating Deployment - $ENVIRONMENT Environment"

# =============================================================================
# Test 1: Check Core Namespaces Exist
# =============================================================================
print_info "Test 1: Checking core namespaces..."

for ns in argocd $MONITORING_NAMESPACE $APP_NAMESPACE; do
    if kubectl get namespace $ns &> /dev/null; then
        print_success "Namespace '$ns' exists"
    else
        print_error "Namespace '$ns' does not exist"
    fi
done

# =============================================================================
# Test 2: Check Pod Security Labels
# =============================================================================
print_info "Test 2: Checking Pod Security labels..."

for ns in $MONITORING_NAMESPACE $APP_NAMESPACE; do
    ENFORCE_LABEL=$(kubectl get namespace $ns -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "missing")
    if [ "$ENFORCE_LABEL" = "restricted" ]; then
        print_success "Namespace '$ns' has correct Pod Security enforcement (restricted)"
    else
        print_error "Namespace '$ns' has incorrect Pod Security enforcement: $ENFORCE_LABEL"
    fi
done

# =============================================================================
# Test 3: Check Argo CD Applications
# =============================================================================
print_info "Test 3: Checking Argo CD applications..."

if command -v argocd &> /dev/null; then
    # Try to login first (may already be logged in)
    argocd cluster list &> /dev/null || print_warning "Not logged in to Argo CD. Application checks may fail."
    
    APPS=("prometheus-${APP_PREFIX}" "grafana-${APP_PREFIX}" "k8s-web-app-${APP_PREFIX}")
    
    for app in "${APPS[@]}"; do
        if argocd app get $app &> /dev/null; then
            HEALTH=$(argocd app get $app -o json 2>/dev/null | jq -r '.status.health.status')
            SYNC=$(argocd app get $app -o json 2>/dev/null | jq -r '.status.sync.status')
            
            if [ "$HEALTH" = "Healthy" ] && [ "$SYNC" = "Synced" ]; then
                print_success "Application '$app' is Healthy and Synced"
            else
                print_error "Application '$app' - Health: $HEALTH, Sync: $SYNC"
            fi
        else
            print_error "Application '$app' does not exist"
        fi
    done
else
    print_warning "Skipping Argo CD application checks (argocd CLI not available)"
fi

# =============================================================================
# Test 4: Check ServiceAccount Resources
# =============================================================================
print_info "Test 4: Checking ServiceAccount resources..."

SA_NAMES=(
    "prometheus-${APP_PREFIX}-kube-prome-prometheus"
    "prometheus-${APP_PREFIX}-kube-prome-alertmanager"
)

for sa in "${SA_NAMES[@]}"; do
    if kubectl get serviceaccount $sa -n $MONITORING_NAMESPACE &> /dev/null; then
        print_success "ServiceAccount '$sa' exists in namespace '$MONITORING_NAMESPACE'"
    else
        print_error "ServiceAccount '$sa' not found in namespace '$MONITORING_NAMESPACE'"
    fi
done

# =============================================================================
# Test 5: Check Prometheus Services
# =============================================================================
print_info "Test 5: Checking Prometheus services..."

PROM_SERVICE="prometheus-${APP_PREFIX}-kube-prometheus-prometheus"
ALERT_SERVICE="prometheus-${APP_PREFIX}-kube-prometheus-alertmanager"

if kubectl get svc $PROM_SERVICE -n $MONITORING_NAMESPACE &> /dev/null; then
    print_success "Prometheus service '$PROM_SERVICE' exists"
else
    print_error "Prometheus service '$PROM_SERVICE' not found"
fi

if kubectl get svc $ALERT_SERVICE -n $MONITORING_NAMESPACE &> /dev/null; then
    print_success "AlertManager service '$ALERT_SERVICE' exists"
else
    print_error "AlertManager service '$ALERT_SERVICE' not found"
fi

# =============================================================================
# Test 6: Check Grafana Service
# =============================================================================
print_info "Test 6: Checking Grafana service..."

if [ "$ENVIRONMENT" = "prod" ]; then
    GRAFANA_SERVICE="grafana"
else
    GRAFANA_SERVICE="grafana-staging"
fi

if kubectl get svc $GRAFANA_SERVICE -n $MONITORING_NAMESPACE &> /dev/null; then
    print_success "Grafana service '$GRAFANA_SERVICE' exists"
else
    print_error "Grafana service '$GRAFANA_SERVICE' not found"
fi

# =============================================================================
# Test 7: Check Pod Health
# =============================================================================
print_info "Test 7: Checking pod health..."

# Check Prometheus pods
PROM_PODS=$(kubectl get pods -n $MONITORING_NAMESPACE -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null | wc -l)
PROM_READY=$(kubectl get pods -n $MONITORING_NAMESPACE -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null | grep -c "Running" || echo 0)

if [ "$PROM_PODS" -gt 0 ] && [ "$PROM_READY" -eq "$PROM_PODS" ]; then
    print_success "Prometheus pods are running ($PROM_READY/$PROM_PODS)"
else
    print_error "Prometheus pods are not healthy ($PROM_READY/$PROM_PODS running)"
fi

# Check Grafana pods
GRAFANA_PODS=$(kubectl get pods -n $MONITORING_NAMESPACE -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | wc -l)
GRAFANA_READY=$(kubectl get pods -n $MONITORING_NAMESPACE -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | grep -c "Running" || echo 0)

if [ "$GRAFANA_PODS" -gt 0 ] && [ "$GRAFANA_READY" -eq "$GRAFANA_PODS" ]; then
    print_success "Grafana pods are running ($GRAFANA_READY/$GRAFANA_PODS)"
else
    print_error "Grafana pods are not healthy ($GRAFANA_READY/$GRAFANA_PODS running)"
fi

# Check web app pods
WEBAPP_PODS=$(kubectl get pods -n $APP_NAMESPACE -l app.kubernetes.io/name=k8s-web-app --no-headers 2>/dev/null | wc -l)
WEBAPP_READY=$(kubectl get pods -n $APP_NAMESPACE -l app.kubernetes.io/name=k8s-web-app --no-headers 2>/dev/null | grep -c "Running" || echo 0)

if [ "$WEBAPP_PODS" -gt 0 ] && [ "$WEBAPP_READY" -eq "$WEBAPP_PODS" ]; then
    print_success "Web app pods are running ($WEBAPP_READY/$WEBAPP_PODS)"
elif [ "$WEBAPP_PODS" -eq 0 ]; then
    print_warning "No web app pods found (may not be deployed yet)"
else
    print_error "Web app pods are not healthy ($WEBAPP_READY/$WEBAPP_PODS running)"
fi

# =============================================================================
# Test 8: Check PodSecurity Compliance
# =============================================================================
print_info "Test 8: Checking PodSecurity compliance..."

# Check if any pods are violating Pod Security policies
POD_VIOLATIONS=$(kubectl get events -n $APP_NAMESPACE --field-selector reason=FailedCreate 2>/dev/null | grep -c "violates PodSecurity" || echo 0)

if [ "$POD_VIOLATIONS" -eq 0 ]; then
    print_success "No PodSecurity violations detected"
else
    print_error "Found $POD_VIOLATIONS PodSecurity violations"
    kubectl get events -n $APP_NAMESPACE --field-selector reason=FailedCreate | grep "violates PodSecurity"
fi

# =============================================================================
# Test 9: Check Image Pull Status
# =============================================================================
print_info "Test 9: Checking image pull status..."

IMAGE_PULL_ERRORS=$(kubectl get events -n $APP_NAMESPACE --field-selector reason=Failed 2>/dev/null | grep -c "Failed to pull image\|no matching manifest" || echo 0)

if [ "$IMAGE_PULL_ERRORS" -eq 0 ]; then
    print_success "No image pull errors detected"
else
    print_error "Found $IMAGE_PULL_ERRORS image pull errors"
    kubectl get events -n $APP_NAMESPACE --field-selector reason=Failed | grep "Failed to pull image\|no matching manifest"
fi

# =============================================================================
# Test 10: Check Grafana Datasources
# =============================================================================
print_info "Test 10: Checking Grafana datasources..."

# Get Grafana pod
GRAFANA_POD=$(kubectl get pods -n $MONITORING_NAMESPACE -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$GRAFANA_POD" ]; then
    # Check if Prometheus datasource is configured (check configmap)
    DATASOURCE_CONFIG=$(kubectl get configmap -n $MONITORING_NAMESPACE -l app.kubernetes.io/name=grafana -o jsonpath='{.items[*].data}' 2>/dev/null | grep -c "prometheus-${APP_PREFIX}-kube-prometheus-prometheus" || echo 0)
    
    if [ "$DATASOURCE_CONFIG" -gt 0 ]; then
        print_success "Grafana datasource configured for Prometheus"
    else
        print_warning "Grafana datasource configuration not found"
    fi
else
    print_warning "Grafana pod not found, skipping datasource check"
fi

# =============================================================================
# Test 11: Check Secrets
# =============================================================================
print_info "Test 11: Checking secrets..."

if [ "$ENVIRONMENT" = "prod" ]; then
    SECRET_NAME="grafana-admin"
else
    SECRET_NAME="grafana-admin-staging"
fi

if kubectl get secret $SECRET_NAME -n $MONITORING_NAMESPACE &> /dev/null; then
    print_success "Secret '$SECRET_NAME' exists"
else
    print_error "Secret '$SECRET_NAME' not found"
fi

# =============================================================================
# Test 12: Check PrometheusRules
# =============================================================================
print_info "Test 12: Checking PrometheusRules..."

PROM_RULES=$(kubectl get prometheusrule -n $MONITORING_NAMESPACE --no-headers 2>/dev/null | wc -l)

if [ "$PROM_RULES" -gt 0 ]; then
    print_success "PrometheusRules are deployed ($PROM_RULES rules)"
    
    # Check if kube-scheduler rule exists (it should NOT for EKS)
    SCHEDULER_RULE=$(kubectl get prometheusrule -n $MONITORING_NAMESPACE -o json 2>/dev/null | grep -c "kube-scheduler.rules" || echo 0)
    
    if [ "$SCHEDULER_RULE" -eq 0 ]; then
        print_success "kube-scheduler rule correctly disabled (EKS compatibility)"
    else
        print_warning "kube-scheduler rule is present (may cause issues on EKS)"
    fi
else
    print_error "No PrometheusRules found"
fi

# =============================================================================
# Test 13: Check for SharedResourceWarnings
# =============================================================================
print_info "Test 13: Checking for SharedResourceWarnings..."

if command -v argocd &> /dev/null; then
    SHARED_WARNINGS=0
    
    for app in "${APPS[@]}"; do
        if argocd app get $app &> /dev/null; then
            WARNINGS_COUNT=$(argocd app get $app -o json 2>/dev/null | jq -r '.status.conditions[]? | select(.type=="SharedResourceWarning") | .type' | wc -l)
            SHARED_WARNINGS=$((SHARED_WARNINGS + WARNINGS_COUNT))
        fi
    done
    
    if [ "$SHARED_WARNINGS" -eq 0 ]; then
        print_success "No SharedResourceWarnings detected"
    else
        print_error "Found $SHARED_WARNINGS SharedResourceWarnings"
    fi
else
    print_warning "Skipping SharedResourceWarning check (argocd CLI not available)"
fi

# =============================================================================
# Summary
# =============================================================================
print_header "Validation Summary"

TOTAL=$((PASSED + FAILED))

echo -e "${GREEN}✅ Passed: $PASSED${NC}"
echo -e "${RED}❌ Failed: $FAILED${NC}"
echo -e "${YELLOW}⚠️  Warnings: $WARNINGS${NC}"
echo -e "Total checks: $TOTAL"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}🎉 All critical checks passed! Deployment is healthy.${NC}"
    exit 0
else
    echo -e "${RED}❌ Some checks failed. Please review the errors above.${NC}"
    exit 1
fi

