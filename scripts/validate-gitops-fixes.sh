#!/bin/bash

# GitOps Fixes Validation Script
# This script validates all the fixes applied to resolve Argo CD deployment failures

set -e

echo "=================================="
echo "GitOps Fixes Validation Script"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Function to check if a file exists and contains a pattern
check_file_contains() {
    local file=$1
    local pattern=$2
    local description=$3
    
    if [ -f "$file" ]; then
        if grep -q "$pattern" "$file"; then
            echo -e "${GREEN}✓${NC} $description"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}✗${NC} $description - Pattern not found"
            ((FAILED++))
            return 1
        fi
    else
        echo -e "${RED}✗${NC} $description - File not found: $file"
        ((FAILED++))
        return 1
    fi
}

# Function to check if a file exists
check_file_exists() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description - File not found: $file"
        ((FAILED++))
        return 1
    fi
}

echo "=== 1. PodSecurity Compliance Checks ==="
echo ""

# Check web-app values
check_file_contains \
    "applications/web-app/k8s-web-app/helm/values.yaml" \
    "seccompProfile:" \
    "Web-app values.yaml has seccompProfile"

check_file_contains \
    "applications/web-app/k8s-web-app/helm/values.yaml" \
    "type: RuntimeDefault" \
    "Web-app values.yaml uses RuntimeDefault"

# Check web-app deployment
check_file_contains \
    "applications/web-app/k8s-web-app/helm/templates/deployment.yaml" \
    "seccompProfile:" \
    "Web-app deployment has seccompProfile for init container"

# Check Grafana production
check_file_contains \
    "applications/monitoring/grafana/values-production.yaml" \
    "seccompProfile:" \
    "Grafana production values has seccompProfile"

# Check Grafana staging
check_file_contains \
    "applications/monitoring/grafana/staging/values-staging.yaml" \
    "seccompProfile:" \
    "Grafana staging values has seccompProfile"

# Check Prometheus production
check_file_contains \
    "applications/monitoring/prometheus/values-production.yaml" \
    "seccompProfile:" \
    "Prometheus production values has seccompProfile"

# Check Prometheus staging
check_file_contains \
    "applications/monitoring/prometheus/staging/values-staging.yaml" \
    "seccompProfile:" \
    "Prometheus staging values has seccompProfile"

# Check Argo CD values
check_file_contains \
    "bootstrap/helm-values/argo-cd-values.yaml" \
    "seccompProfile:" \
    "Argo CD values has seccompProfile"

# Check ETCD backup
check_file_contains \
    "bootstrap/06-etcd-backup.yaml" \
    "seccompProfile:" \
    "ETCD backup CronJob has seccompProfile"

echo ""
echo "=== 2. Namespace Permission Checks ==="
echo ""

# Check production project
check_file_contains \
    "environments/prod/project.yaml" \
    "namespace: kube-system" \
    "Production project allows kube-system namespace"

# Check staging project
check_file_contains \
    "environments/staging/project.yaml" \
    "namespace: kube-system" \
    "Staging project allows kube-system namespace"

echo ""
echo "=== 3. Missing Resources Checks ==="
echo ""

# Check production secrets
check_file_exists \
    "environments/prod/secrets/grafana-admin-secret.yaml" \
    "Production Grafana admin secret exists"

check_file_exists \
    "environments/prod/apps/monitoring-secrets.yaml" \
    "Production monitoring secrets Application exists"

# Check staging secrets
check_file_exists \
    "environments/staging/secrets/grafana-admin-secret.yaml" \
    "Staging Grafana admin secret exists"

check_file_exists \
    "environments/staging/apps/monitoring-secrets.yaml" \
    "Staging monitoring secrets Application exists"

echo ""
echo "=== 4. Environment Configuration Checks ==="
echo ""

# Check production namespaces
check_file_contains \
    "environments/prod/namespaces.yaml" \
    "pod-security.kubernetes.io/enforce: restricted" \
    "Production namespaces have PodSecurity labels"

# Check staging namespaces
check_file_contains \
    "environments/staging/namespaces.yaml" \
    "pod-security.kubernetes.io/enforce: restricted" \
    "Staging namespaces have PodSecurity labels"

# Check staging Prometheus app
check_file_contains \
    "environments/staging/apps/prometheus.yaml" \
    "staging/values-staging.yaml" \
    "Staging Prometheus uses staging-specific values"

echo ""
echo "=== 5. File Structure Checks ==="
echo ""

# Check new directories exist
if [ -d "applications/monitoring/prometheus/staging" ]; then
    echo -e "${GREEN}✓${NC} Prometheus staging directory exists"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Prometheus staging directory not found"
    ((FAILED++))
fi

if [ -d "environments/prod/secrets" ]; then
    echo -e "${GREEN}✓${NC} Production secrets directory exists"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Production secrets directory not found"
    ((FAILED++))
fi

if [ -d "environments/staging/secrets" ]; then
    echo -e "${GREEN}✓${NC} Staging secrets directory exists"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Staging secrets directory not found"
    ((FAILED++))
fi

echo ""
echo "=== 6. Security Best Practices Checks ==="
echo ""

# Check for non-root users
check_file_contains \
    "applications/web-app/k8s-web-app/helm/values.yaml" \
    "runAsNonRoot: true" \
    "Web-app runs as non-root user"

# Check for capability drops
check_file_contains \
    "applications/web-app/k8s-web-app/helm/values.yaml" \
    "drop:" \
    "Web-app drops capabilities"

# Check for read-only root filesystem
check_file_contains \
    "applications/web-app/k8s-web-app/helm/values.yaml" \
    "readOnlyRootFilesystem: true" \
    "Web-app uses read-only root filesystem"

echo ""
echo "=================================="
echo "Validation Summary"
echo "=================================="
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
fi
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    echo "The repository is ready for deployment."
    exit 0
else
    echo -e "${RED}✗ Some validation checks failed.${NC}"
    echo "Please review the failed checks and fix the issues before deploying."
    exit 1
fi

