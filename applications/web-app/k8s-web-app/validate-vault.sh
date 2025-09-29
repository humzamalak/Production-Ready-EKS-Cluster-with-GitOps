#!/bin/bash

# Vault Integration Validation Script for k8s-web-app
# This script validates that Vault agent injection is working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Configuration
NAMESPACE="production"
APP_NAME="k8s-web-app"
VAULT_NAMESPACE="vault"

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    print_status "kubectl is available"
}

# Function to check if vault CLI is available
check_vault() {
    if ! command -v vault &> /dev/null; then
        print_error "Vault CLI is not installed or not in PATH"
        exit 1
    fi
    print_status "Vault CLI is available"
}

# Function to check namespace existence
check_namespace() {
    print_header "Checking namespace existence..."
    
    if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
        print_status "Namespace '$NAMESPACE' exists"
    else
        print_error "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    
    if kubectl get namespace $VAULT_NAMESPACE >/dev/null 2>&1; then
        print_status "Namespace '$VAULT_NAMESPACE' exists"
    else
        print_error "Namespace '$VAULT_NAMESPACE' does not exist"
        exit 1
    fi
}

# Function to check Vault deployment
check_vault_deployment() {
    print_header "Checking Vault deployment..."
    
    if kubectl get deployment vault -n $VAULT_NAMESPACE >/dev/null 2>&1; then
        print_status "Vault deployment exists"
        
        # Check if Vault is ready
        if kubectl get pods -n $VAULT_NAMESPACE -l app=vault | grep -q "Running"; then
            print_status "Vault pods are running"
        else
            print_error "Vault pods are not running"
            exit 1
        fi
    elif kubectl get statefulset vault -n $VAULT_NAMESPACE >/dev/null 2>&1; then
        print_status "Vault statefulset exists"
        
        # Check if Vault is ready
        if kubectl get pods -n $VAULT_NAMESPACE -l app.kubernetes.io/name=vault | grep -q "Running"; then
            print_status "Vault pods are running"
        else
            print_error "Vault pods are not running"
            exit 1
        fi
    else
        print_error "Vault deployment or statefulset does not exist"
        exit 1
    fi
}

# Function to check Vault agent injector
check_vault_injector() {
    print_header "Checking Vault agent injector..."
    
    if kubectl get deployment vault-agent-injector -n $VAULT_NAMESPACE >/dev/null 2>&1; then
        print_status "Vault agent injector deployment exists"
        
        # Check if injector is ready
        if kubectl get pods -n $VAULT_NAMESPACE -l app.kubernetes.io/name=vault-agent-injector | grep -q "Running"; then
            print_status "Vault agent injector pods are running"
        else
            print_error "Vault agent injector pods are not running"
            exit 1
        fi
    else
        print_error "Vault agent injector deployment does not exist"
        exit 1
    fi
}

# Function to check web app deployment
check_web_app_deployment() {
    print_header "Checking web app deployment..."
    
    if kubectl get deployment $APP_NAME -n $NAMESPACE >/dev/null 2>&1; then
        print_status "Web app deployment exists"
        
        # Check if pods are ready
        if kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME | grep -q "Running"; then
            print_status "Web app pods are running"
        else
            print_error "Web app pods are not running"
            exit 1
        fi
    else
        print_error "Web app deployment does not exist"
        exit 1
    fi
}

# Function to check Vault annotations
check_vault_annotations() {
    print_header "Checking Vault annotations on web app pods..."
    
    PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$PODS" ]; then
        print_error "No web app pods found"
        exit 1
    fi
    
    for POD in $PODS; do
        print_status "Checking annotations on pod: $POD"
        
        # Check for Vault injection annotation
        if kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.metadata.annotations.vault\.hashicorp\.com/agent-inject}' | grep -q "true"; then
            print_status "Vault injection annotation found on pod: $POD"
        else
            print_error "Vault injection annotation not found on pod: $POD"
            exit 1
        fi
        
        # Check for Vault role annotation
        if kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.metadata.annotations.vault\.hashicorp\.com/role}' | grep -q "k8s-web-app"; then
            print_status "Vault role annotation found on pod: $POD"
        else
            print_error "Vault role annotation not found on pod: $POD"
            exit 1
        fi
    done
}

# Function to check Vault agent sidecar
check_vault_agent_sidecar() {
    print_header "Checking Vault agent sidecar containers..."
    
    PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME -o jsonpath='{.items[*].metadata.name}')
    
    for POD in $PODS; do
        print_status "Checking sidecar containers on pod: $POD"
        
        # Check if vault-agent container exists
        if kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.spec.containers[*].name}' | grep -q "vault-agent"; then
            print_status "Vault agent sidecar found on pod: $POD"
        else
            print_error "Vault agent sidecar not found on pod: $POD"
            exit 1
        fi
    done
}

# Function to check Vault secrets
check_vault_secrets() {
    print_header "Checking Vault secrets..."
    
    # Port forward to Vault
    print_status "Setting up port forward to Vault..."
    kubectl port-forward -n $VAULT_NAMESPACE svc/vault 8200:8200 &
    PORT_FORWARD_PID=$!
    sleep 5
    
    # Set Vault address
    export VAULT_ADDR="http://localhost:8200"
    export VAULT_TOKEN="root"  # In production, use proper authentication
    
    # Check if secrets exist
    if vault kv list secret/production/web-app/ >/dev/null 2>&1; then
        print_status "Web app secrets exist in Vault"
        
        # Check specific secrets
        if vault kv get secret/production/web-app/db >/dev/null 2>&1; then
            print_status "Database secrets exist"
        else
            print_error "Database secrets do not exist"
            exit 1
        fi
        
        if vault kv get secret/production/web-app/api >/dev/null 2>&1; then
            print_status "API secrets exist"
        else
            print_error "API secrets do not exist"
            exit 1
        fi
        
        if vault kv get secret/production/web-app/external >/dev/null 2>&1; then
            print_status "External service secrets exist"
        else
            print_error "External service secrets do not exist"
            exit 1
        fi
    else
        print_error "Web app secrets do not exist in Vault"
        exit 1
    fi
    
    # Cleanup
    kill $PORT_FORWARD_PID 2>/dev/null || true
}

# Function to check injected secrets
check_injected_secrets() {
    print_header "Checking injected secrets in pods..."
    
    PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME -o jsonpath='{.items[*].metadata.name}')
    
    for POD in $PODS; do
        print_status "Checking injected secrets on pod: $POD"
        
        # Check if vault-secret-* secrets exist
        if kubectl get secrets -n $NAMESPACE | grep -q "vault-secret-db"; then
            print_status "Vault database secrets found"
        else
            print_error "Vault database secrets not found"
            exit 1
        fi
        
        if kubectl get secrets -n $NAMESPACE | grep -q "vault-secret-api"; then
            print_status "Vault API secrets found"
        else
            print_error "Vault API secrets not found"
            exit 1
        fi
        
        if kubectl get secrets -n $NAMESPACE | grep -q "vault-secret-external"; then
            print_status "Vault external service secrets found"
        else
            print_error "Vault external service secrets not found"
            exit 1
        fi
    done
}

# Function to check Vault agent logs
check_vault_agent_logs() {
    print_header "Checking Vault agent logs..."
    
    PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME -o jsonpath='{.items[*].metadata.name}')
    
    for POD in $PODS; do
        print_status "Checking Vault agent logs on pod: $POD"
        
        # Get logs from vault-agent container
        if kubectl logs $POD -c vault-agent -n $NAMESPACE --tail=10 | grep -q "successfully"; then
            print_status "Vault agent logs show successful operation on pod: $POD"
        else
            print_warning "Vault agent logs may indicate issues on pod: $POD"
            print_status "Recent logs from vault-agent on pod: $POD"
            kubectl logs $POD -c vault-agent -n $NAMESPACE --tail=5
        fi
    done
}

# Main execution
main() {
    print_status "Starting Vault integration validation for k8s-web-app..."
    echo ""
    
    # Prerequisites
    check_kubectl
    check_vault
    echo ""
    
    # Infrastructure checks
    check_namespace
    echo ""
    
    check_vault_deployment
    echo ""
    
    check_vault_injector
    echo ""
    
    check_web_app_deployment
    echo ""
    
    # Vault integration checks
    check_vault_annotations
    echo ""
    
    check_vault_agent_sidecar
    echo ""
    
    check_vault_secrets
    echo ""
    
    check_injected_secrets
    echo ""
    
    check_vault_agent_logs
    echo ""
    
    print_status "Vault integration validation completed successfully!"
    print_status "The k8s-web-app is properly configured with Vault agent injection."
}

# Run main function
main "$@"
