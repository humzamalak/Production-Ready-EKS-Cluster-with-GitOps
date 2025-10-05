#!/bin/bash

# GitOps Repository Structure Validation Script
# Validates the repository structure, ArgoCD applications, and Kubernetes manifests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0

echo "🔍 GitOps Repository Structure Validation"
echo "=========================================="

# Function to print status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "ERROR")
            echo -e "${RED}❌ ERROR:${NC} $message"
            ((ERRORS++))
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  WARNING:${NC} $message"
            ((WARNINGS++))
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ SUCCESS:${NC} $message"
            ;;
    esac
}

# Function to check if file exists
check_file() {
    local file=$1
    local description=$2
    if [[ -f "$file" ]]; then
        print_status "SUCCESS" "$description exists"
    else
        print_status "ERROR" "$description missing: $file"
    fi
}

# Function to validate YAML syntax
validate_yaml() {
    local file=$1
    local description=$2
    if command -v yq &> /dev/null; then
        if yq eval '.' "$file" > /dev/null 2>&1; then
            print_status "SUCCESS" "$description YAML syntax is valid"
        else
            print_status "ERROR" "$description YAML syntax is invalid: $file"
        fi
    else
        print_status "WARNING" "yq not found, skipping YAML validation for $description"
    fi
}

# Function to validate ArgoCD Application
validate_argocd_app() {
    local file=$1
    local description=$2
    
    # Check required fields
    if grep -q "kind: Application" "$file"; then
        if grep -q "repoURL:" "$file" && grep -q "targetRevision:" "$file"; then
            print_status "SUCCESS" "$description has required ArgoCD fields"
        else
            print_status "ERROR" "$description missing required ArgoCD fields (repoURL, targetRevision): $file"
        fi
        
        # Check for project reference
        if grep -q "project:" "$file"; then
            print_status "SUCCESS" "$description has project reference"
        else
            print_status "WARNING" "$description missing project reference: $file"
        fi
        
        # Check for sync wave
        if grep -q "argocd.argoproj.io/sync-wave:" "$file"; then
            print_status "SUCCESS" "$description has sync wave annotation"
        else
            print_status "WARNING" "$description missing sync wave annotation: $file"
        fi
    fi
}

echo ""
echo "📁 Checking Repository Structure..."
echo "----------------------------------"

# Check main directories
check_file "README.md" "Main README"
# Refactor: environments-based layout replaces clusters/*
check_file "environments/prod/app-of-apps.yaml" "Prod app-of-apps"
check_file "environments/prod/namespaces.yaml" "Prod namespaces"
check_file "environments/prod/project.yaml" "Prod project"
check_file "environments/staging/app-of-apps.yaml" "Staging app-of-apps"
check_file "environments/staging/namespaces.yaml" "Staging namespaces"
check_file "environments/staging/project.yaml" "Staging project"
check_file "environments/dev/app-of-apps.yaml" "Dev app-of-apps"
check_file "environments/dev/namespaces.yaml" "Dev namespaces"
check_file "environments/dev/project.yaml" "Dev project"

echo ""
echo "🚀 Checking ArgoCD Applications..."
echo "---------------------------------"

# Check application manifests (env-scoped)
APPS=(
    "environments/prod/apps/prometheus.yaml:Prometheus Application (prod)"
    "environments/prod/apps/grafana.yaml:Grafana Application (prod)"
    "environments/prod/apps/web-app.yaml:Web App Application (prod)"
    "environments/staging/apps/prometheus.yaml:Prometheus Application (staging)"
    "environments/staging/apps/grafana.yaml:Grafana Application (staging)"
    "environments/staging/apps/web-app.yaml:Web App Application (staging)"
    "environments/dev/apps/prometheus.yaml:Prometheus Application (dev)"
    "environments/dev/apps/grafana.yaml:Grafana Application (dev)"
    "environments/dev/apps/web-app.yaml:Web App Application (dev)"
    "bootstrap/04-argo-cd-install.yaml:ArgoCD Installation"
)

for app in "${APPS[@]}"; do
    IFS=':' read -r file description <<< "$app"
    if [[ -f "$file" ]]; then
        validate_argocd_app "$file" "$description"
        validate_yaml "$file" "$description"
    else
        print_status "ERROR" "$description missing: $file"
    fi
done

echo ""
echo "📋 Checking Kubernetes Manifests..."
echo "----------------------------------"

# Check key Kubernetes manifests
MANIFESTS=(
    "applications/web-app/k8s-web-app/helm/templates/deployment.yaml:Web App Deployment"
    "applications/web-app/k8s-web-app/helm/templates/service.yaml:Web App Service"
    "applications/web-app/k8s-web-app/helm/templates/ingress.yaml:Web App Ingress"
    "applications/web-app/k8s-web-app/helm/templates/hpa.yaml:Web App HPA"
    "bootstrap/00-namespaces.yaml:Core Namespaces"
    "bootstrap/01-pod-security-standards.yaml:Pod Security Standards"
)

for manifest in "${MANIFESTS[@]}"; do
    IFS=':' read -r file description <<< "$manifest"
    if [[ -f "$file" ]]; then
        validate_yaml "$file" "$description"
    else
        print_status "ERROR" "$description missing: $file"
    fi
done

echo ""
echo "📚 Checking Documentation..."
echo "---------------------------"

# Check documentation files
DOCS=(
    "docs/README.md:Documentation README"
    "docs/architecture.md:Architecture Guide"
    "docs/local-deployment.md:Local Deployment Guide"
    "docs/aws-deployment.md:AWS Deployment Guide"
    "docs/troubleshooting.md:Troubleshooting Guide"
    "clusters/staging/README.md:Staging Environment README"
    "applications/infrastructure/README.md:Infrastructure README"
)

for doc in "${DOCS[@]}"; do
    IFS=':' read -r file description <<< "$doc"
    if [[ -f "$file" ]]; then
        print_status "SUCCESS" "$description exists"
    else
        print_status "WARNING" "$description missing: $file"
    fi
done

echo ""
echo "🔧 Checking Scripts..."
echo "---------------------"

# Check validation scripts
check_file "scripts/validate-argocd-apps.sh" "ArgoCD Apps Validation Script"
check_file "scripts/create-monitoring-secrets.sh" "Monitoring Secrets Script"

echo ""
echo "📊 Validation Summary"
echo "===================="

if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    print_status "SUCCESS" "All validations passed! Repository structure is correct."
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    print_status "WARNING" "Validation completed with $WARNINGS warnings. No errors found."
    exit 0
else
    print_status "ERROR" "Validation failed with $ERRORS errors and $WARNINGS warnings."
    exit 1
fi
