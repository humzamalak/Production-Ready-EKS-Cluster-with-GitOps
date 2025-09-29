#!/bin/bash

# Validation script for k8s-web-app Helm chart
# This script validates the Helm chart configuration

set -e

echo "🔍 Validating k8s-web-app Helm chart..."

# Change to the helm directory
cd "$(dirname "$0")/helm"

# Validate Helm chart syntax
echo "📋 Validating Helm chart syntax..."
helm lint .

# Template the chart with production values
echo "📋 Templating chart with production values..."
helm template k8s-web-app . -f ../values.yaml --dry-run

# Check for required templates
echo "📋 Checking required templates..."
required_templates=(
    "deployment.yaml"
    "service.yaml"
    "ingress.yaml"
    "hpa.yaml"
    "serviceaccount.yaml"
    "networkpolicy.yaml"
    "servicemonitor.yaml"
)

for template in "${required_templates[@]}"; do
    if [ -f "templates/$template" ]; then
        echo "✅ Found $template"
    else
        echo "❌ Missing $template"
        exit 1
    fi
done

# Validate YAML syntax
echo "📋 Validating YAML syntax..."
for yaml_file in templates/*.yaml; do
    if [ -f "$yaml_file" ]; then
        echo "Validating $(basename "$yaml_file")..."
        helm template k8s-web-app . -f ../values.yaml | kubectl apply --dry-run=client -f -
    fi
done

echo "✅ All validations passed!"
echo ""
echo "📋 Summary:"
echo "- Helm chart syntax: ✅"
echo "- Template rendering: ✅"
echo "- Required templates: ✅"
echo "- YAML syntax: ✅"
echo ""
echo "🚀 The k8s-web-app is ready for deployment!"
