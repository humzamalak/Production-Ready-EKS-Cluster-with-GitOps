#!/bin/bash

# GitOps Health Check Script
# This script performs comprehensive health checks on the deployed applications

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_status "kubectl is available and cluster is accessible"
}

# Function to check Argo CD
check_argocd() {
    print_header "Argo CD Health Check"
    
    # Check if Argo CD namespace exists
    if ! kubectl get namespace argocd &> /dev/null; then
        print_error "Argo CD namespace not found"
        return 1
    fi
    
    # Check Argo CD pods
    print_status "Checking Argo CD pods..."
    if kubectl get pods -n argocd | grep -q "Running"; then
        kubectl get pods -n argocd
        print_status "Argo CD pods are running"
    else
        print_error "Argo CD pods are not running"
        return 1
    fi
    
    # Check Argo CD applications
    print_status "Checking Argo CD applications..."
    if kubectl get applications -n argocd &> /dev/null; then
        kubectl get applications -n argocd
        print_status "Argo CD applications found"
    else
        print_error "Argo CD applications not found"
        return 1
    fi
    
    # Check application sync status
    print_status "Checking application sync status..."
    local unhealthy_apps=0
    while IFS= read -r line; do
        if [[ $line == *"OutOfSync"* ]] || [[ $line == *"Unknown"* ]] || [[ $line == *"Degraded"* ]]; then
            print_warning "Application out of sync: $line"
            ((unhealthy_apps++))
        fi
    done < <(kubectl get applications -n argocd --no-headers)
    
    if [ $unhealthy_apps -eq 0 ]; then
        print_status "All applications are in sync"
    else
        print_warning "$unhealthy_apps applications need attention"
    fi
}

# Function to check monitoring stack
check_monitoring() {
    print_header "Monitoring Stack Health Check"
    
    # Check monitoring namespace
    if ! kubectl get namespace monitoring &> /dev/null; then
        print_error "Monitoring namespace not found"
        return 1
    fi
    
    # Check Prometheus
    print_status "Checking Prometheus..."
    if kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus | grep -q "Running"; then
        kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
        print_status "Prometheus is running"
    else
        print_error "Prometheus is not running"
        return 1
    fi
    
    # Check Grafana
    print_status "Checking Grafana..."
    if kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana | grep -q "Running"; then
        kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
        print_status "Grafana is running"
    else
        print_error "Grafana is not running"
        return 1
    fi
    
    # Check AlertManager
    print_status "Checking AlertManager..."
    if kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager | grep -q "Running"; then
        kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager
        print_status "AlertManager is running"
    else
        print_error "AlertManager is not running"
        return 1
    fi
    
    # Check services
    print_status "Checking monitoring services..."
    kubectl get svc -n monitoring
    
    # Check persistent volumes
    print_status "Checking persistent volumes..."
    kubectl get pv,pvc -n monitoring
}

# Function to check Vault
check_vault() {
    print_header "Vault Health Check"
    
    # Check vault namespace
    if ! kubectl get namespace vault &> /dev/null; then
        print_error "Vault namespace not found"
        return 1
    fi
    
    # Check Vault pods
    print_status "Checking Vault pods..."
    if kubectl get pods -n vault -l app.kubernetes.io/name=vault | grep -q "Running"; then
        kubectl get pods -n vault -l app.kubernetes.io/name=vault
        print_status "Vault pods are running"
    else
        print_error "Vault pods are not running"
        return 1
    fi
    
    # Check Vault status
    print_status "Checking Vault status..."
    if kubectl exec -n vault vault-0 -- vault status &> /dev/null; then
        kubectl exec -n vault vault-0 -- vault status
        print_status "Vault is operational"
    else
        print_warning "Vault may need initialization or unsealing"
        print_status "To initialize Vault: kubectl exec -n vault vault-0 -- vault operator init"
        print_status "To unseal Vault: kubectl exec -n vault vault-0 -- vault operator unseal <key>"
    fi
    
    # Check Vault services
    print_status "Checking Vault services..."
    kubectl get svc -n vault
    
    # Check Vault persistent volumes
    print_status "Checking Vault persistent volumes..."
    kubectl get pv,pvc -n vault
}

# Function to check ingress
check_ingress() {
    print_header "Ingress Health Check"
    
    # Check ingress controllers
    print_status "Checking ingress controllers..."
    kubectl get pods -A | grep -E "(nginx|traefik|istio)" || print_warning "No ingress controller found"
    
    # Check ingress resources
    print_status "Checking ingress resources..."
    kubectl get ingress -n monitoring 2>/dev/null || print_warning "No ingress resources in monitoring namespace"
    kubectl get ingress -n vault 2>/dev/null || print_warning "No ingress resources in vault namespace"
}

# Function to check storage
check_storage() {
    print_header "Storage Health Check"
    
    # Check storage classes
    print_status "Checking storage classes..."
    kubectl get storageclass
    
    # Check persistent volumes
    print_status "Checking all persistent volumes..."
    kubectl get pv
    
    # Check persistent volume claims
    print_status "Checking persistent volume claims..."
    kubectl get pvc -A
}

# Function to check network policies
check_network_policies() {
    print_header "Network Policies Health Check"
    
    # Check network policies
    print_status "Checking network policies..."
    kubectl get networkpolicies -n monitoring 2>/dev/null || print_warning "No network policies in monitoring namespace"
    kubectl get networkpolicies -n vault 2>/dev/null || print_warning "No network policies in vault namespace"
}

# Function to check resource usage
check_resources() {
    print_header "Resource Usage Check"
    
    # Check node resources
    print_status "Checking node resources..."
    if kubectl top nodes &> /dev/null; then
        kubectl top nodes
    else
        print_warning "Metrics server not available for resource monitoring"
    fi
    
    # Check pod resources
    print_status "Checking pod resources..."
    if kubectl top pods -n monitoring &> /dev/null; then
        kubectl top pods -n monitoring
    fi
    
    if kubectl top pods -n vault &> /dev/null; then
        kubectl top pods -n vault
    fi
}

# Function to check security
check_security() {
    print_header "Security Health Check"
    
    # Check pod security standards
    print_status "Checking pod security standards..."
    kubectl get ns monitoring vault -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.pod-security\.kubernetes\.io/enforce}{"\n"}{end}'
    
    # Check service accounts
    print_status "Checking service accounts..."
    kubectl get sa -n monitoring
    kubectl get sa -n vault
    
    # Check RBAC
    print_status "Checking RBAC..."
    kubectl get roles,rolebindings,clusterroles,clusterrolebindings -n monitoring
    kubectl get roles,rolebindings,clusterroles,clusterrolebindings -n vault
}

# Function to generate health report
generate_report() {
    print_header "Health Check Report"
    
    local report_file="health-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
GitOps Health Check Report
Generated: $(date)
Cluster: $(kubectl cluster-info --request-timeout=5s | head -n1)

=== Argo CD Status ===
$(kubectl get applications -n argocd 2>/dev/null || echo "Argo CD not accessible")

=== Monitoring Stack Status ===
$(kubectl get pods -n monitoring 2>/dev/null || echo "Monitoring namespace not found")

=== Vault Status ===
$(kubectl get pods -n vault 2>/dev/null || echo "Vault namespace not found")
$(kubectl exec -n vault vault-0 -- vault status 2>/dev/null || echo "Vault status unavailable")

=== Storage Status ===
$(kubectl get pv,pvc -A 2>/dev/null || echo "Storage information unavailable")

=== Resource Usage ===
$(kubectl top nodes 2>/dev/null || echo "Node metrics unavailable")
$(kubectl top pods -n monitoring 2>/dev/null || echo "Pod metrics unavailable")
$(kubectl top pods -n vault 2>/dev/null || echo "Pod metrics unavailable")
EOF
    
    print_status "Health report generated: $report_file"
}

# Main function
main() {
    print_header "GitOps Health Check"
    print_status "Starting comprehensive health check..."
    
    # Basic checks
    check_kubectl
    
    # Component checks
    check_argocd
    check_monitoring
    check_vault
    check_ingress
    check_storage
    check_network_policies
    check_resources
    check_security
    
    # Generate report
    generate_report
    
    print_header "Health Check Complete"
    print_status "All health checks completed. Review the output above for any issues."
    print_status "Health report saved for future reference."
}

# Script usage
usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -r, --report   Generate health report only"
    echo "  -q, --quiet    Quiet mode (minimal output)"
    echo
    echo "Examples:"
    echo "  $0              # Run full health check"
    echo "  $0 --report     # Generate report only"
    echo "  $0 --quiet      # Run in quiet mode"
}

# Parse command line arguments
QUIET=false
REPORT_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -r|--report)
            REPORT_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Override print functions for quiet mode
if [ "$QUIET" = true ]; then
    print_status() { echo "[INFO] $1"; }
    print_warning() { echo "[WARNING] $1"; }
    print_error() { echo "[ERROR] $1"; }
    print_header() { echo "=== $1 ==="; }
fi

# Run appropriate function
if [ "$REPORT_ONLY" = true ]; then
    generate_report
else
    main
fi
