#!/bin/bash

# ArgoCD Application Validation Script
# Prevents CRD annotation size issues by validating application manifests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MAX_ANNOTATION_SIZE=262144  # 256KB limit for Kubernetes annotations
APPLICATION_DIRS=(
    "applications/monitoring"
    "applications/web-app"
    "clusters/production"
)

echo -e "${GREEN}🔍 ArgoCD Application Validation Script${NC}"
echo "Checking for annotation size issues and best practices..."
echo

# Function to check annotation size
check_annotation_size() {
    local file="$1"
    local size=$(wc -c < "$file")
    
    if [ "$size" -gt "$MAX_ANNOTATION_SIZE" ]; then
        echo -e "${RED}❌ FAIL: $file exceeds annotation size limit ($size bytes > $MAX_ANNOTATION_SIZE bytes)${NC}"
        return 1
    else
        echo -e "${GREEN}✅ PASS: $file annotation size OK ($size bytes)${NC}"
        return 0
    fi
}

# Function to check for inline helm values
check_inline_values() {
    local file="$1"
    
    if grep -q "helm:" "$file" && grep -q "values: |" "$file"; then
        local lines=$(grep -A 1000 "values: |" "$file" | grep -c "^[[:space:]]" || true)
        if [ "$lines" -gt 20 ]; then
            echo -e "${YELLOW}⚠️  WARNING: $file has large inline helm values ($lines lines). Consider using external values files.${NC}"
            return 1
        fi
    fi
    return 0
}

# Function to check for required fields
check_required_fields() {
    local file="$1"
    local errors=0
    
    # Check for spec.destination
    if ! grep -q "destination:" "$file"; then
        echo -e "${RED}❌ FAIL: $file missing spec.destination${NC}"
        errors=$((errors + 1))
    fi
    
    # Check for spec.source or spec.sources
    if ! grep -q "source:" "$file" && ! grep -q "sources:" "$file"; then
        echo -e "${RED}❌ FAIL: $file missing spec.source or spec.sources${NC}"
        errors=$((errors + 1))
    fi
    
    # Check for proper namespace
    if ! grep -q "namespace: argocd" "$file"; then
        echo -e "${YELLOW}⚠️  WARNING: $file should be in argocd namespace${NC}"
    fi
    
    return $errors
}

# Function to suggest improvements
suggest_improvements() {
    local file="$1"
    
    echo -e "${YELLOW}💡 Suggestions for $file:${NC}"
    
    if grep -q "helm:" "$file" && grep -q "values: |" "$file"; then
        echo "   - Move helm values to external file (e.g., values.yaml)"
        echo "   - Use sources with valueFiles instead of inline values"
        echo "   - Example:"
        echo "     sources:"
        echo "       - repoURL: 'https://charts.example.com'"
        echo "         chart: my-chart"
        echo "       - repoURL: 'https://github.com/user/repo'"
        echo "         path: charts/my-app"
        echo "     helm:"
        echo "       valueFiles:"
        echo "         - values.yaml"
    fi
    
    if grep -q "kube-prometheus-stack" "$file"; then
        echo "   - Consider using 'prometheus' chart instead of 'kube-prometheus-stack'"
        echo "   - kube-prometheus-stack has large CRDs that may exceed annotation limits"
    fi
}

# Main validation
total_files=0
failed_files=0

echo "📁 Scanning application directories..."
for dir in "${APPLICATION_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "   Checking $dir..."
        for file in "$dir"/*/application.yaml; do
            if [ -f "$file" ]; then
                total_files=$((total_files + 1))
                echo
                echo "🔍 Validating $file..."
                
                file_errors=0
                
                # Run all checks
                check_annotation_size "$file" || file_errors=$((file_errors + 1))
                check_inline_values "$file" || file_errors=$((file_errors + 1))
                check_required_fields "$file" || file_errors=$((file_errors + file_errors))
                
                if [ $file_errors -gt 0 ]; then
                    failed_files=$((failed_files + 1))
                    suggest_improvements "$file"
                fi
            fi
        done
    fi
done

echo
echo "📊 Validation Summary:"
echo "   Total files checked: $total_files"
echo "   Files with issues: $failed_files"

if [ $failed_files -eq 0 ]; then
    echo -e "${GREEN}🎉 All applications passed validation!${NC}"
    exit 0
else
    echo -e "${RED}❌ $failed_files files need attention${NC}"
    echo
    echo "📚 Best Practices:"
    echo "   1. Use external values files instead of inline helm values"
    echo "   2. Keep application manifests under 256KB"
    echo "   3. Use sources with valueFiles for complex configurations"
    echo "   4. Consider lighter charts for better compatibility"
    exit 1
fi
