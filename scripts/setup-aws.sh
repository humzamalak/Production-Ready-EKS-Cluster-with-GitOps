#!/usr/bin/env bash
# =============================================================================
# AWS EKS Setup Script
# =============================================================================
# Deploys the complete GitOps stack on AWS EKS for production
#
# Components:
#   - ArgoCD (HA)
#   - Prometheus (HA)
#   - Grafana (HA)
#   - Vault (HA with Raft)
#   - Web App (HA)
#
# Prerequisites:
#   - AWS CLI configured
#   - Terraform installed
#   - kubectl installed
#   - helm installed
#   - EKS cluster provisioned
#
# Usage:
#   ./scripts/setup-aws.sh [--skip-terraform]
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps"
CLUSTER_NAME="${CLUSTER_NAME:-production-cluster}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ARGOCD_VERSION="3.1.0"
SKIP_TERRAFORM=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-terraform)
            SKIP_TERRAFORM=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install AWS CLI first."
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null && [ "$SKIP_TERRAFORM" = false ]; then
        log_error "Terraform not found. Please install Terraform or use --skip-terraform."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        log_error "helm not found. Please install helm first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Run 'aws configure' first."
        exit 1
    fi
    
    log_info "All prerequisites met!"
}

provision_infrastructure() {
    if [ "$SKIP_TERRAFORM" = true ]; then
        log_warn "Skipping Terraform infrastructure provisioning"
        return
    fi
    
    log_step "Provisioning AWS infrastructure with Terraform..."
    
    cd terraform/environments/aws
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Plan
    log_info "Creating Terraform plan..."
    terraform plan -out=tfplan
    
    # Apply
    log_info "Applying Terraform configuration..."
    terraform apply tfplan
    
    cd ../../..
    
    log_info "Infrastructure provisioned successfully!"
}

configure_kubectl() {
    log_step "Configuring kubectl for EKS cluster..."
    
    aws eks update-kubeconfig \
        --name "$CLUSTER_NAME" \
        --region "$AWS_REGION"
    
    # Verify connection
    if kubectl cluster-info &> /dev/null; then
        log_info "kubectl configured successfully!"
    else
        log_error "Failed to configure kubectl"
        exit 1
    fi
}

deploy_argocd() {
    log_step "Deploying ArgoCD on EKS..."
    
    # Apply namespaces
    kubectl apply -f argo-apps/install/01-namespaces.yaml
    
    # Wait for namespaces
    kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/argocd --timeout=60s
    
    # Install ArgoCD using official manifest
    log_info "Installing ArgoCD v${ARGOCD_VERSION}..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD to be ready (this may take 3-5 minutes)..."
    kubectl wait --for=condition=available --timeout=600s \
        deployment/argocd-server -n argocd 2>/dev/null || {
        log_warn "Timeout waiting for argocd-server, checking status..."
        kubectl get pods -n argocd
    }
    
    # Wait a bit more for all components
    log_info "Waiting for all ArgoCD components to stabilize..."
    sleep 30
    
    # Get admin password
    log_info "Retrieving ArgoCD admin password..."
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")
    
    if [ -n "$ARGOCD_PASSWORD" ]; then
        log_info "ArgoCD admin password: $ARGOCD_PASSWORD"
        log_warn "Save this password securely!"
    else
        log_warn "Could not retrieve ArgoCD password yet. It may not be ready."
        log_warn "Try again in a minute with: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    fi
}

deploy_applications() {
    log_step "Deploying GitOps applications..."
    
    # Apply projects and root app
    kubectl apply -f argo-apps/install/03-bootstrap.yaml
    
    # Wait for projects to sync
    log_info "Waiting for projects to sync..."
    sleep 15
    
    log_info "Applications deployed! ArgoCD will sync them automatically."
}

configure_ingress() {
    log_step "Configuring AWS ALB Ingress Controller..."
    
    log_warn "Note: AWS Load Balancer Controller must be installed separately."
    log_warn "Follow AWS documentation:"
    log_warn "https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html"
    echo ""
    log_info "After installing, update Ingress annotations in application values:"
    log_info "  - argo-apps/apps/*.yaml - uncomment values-aws.yaml"
    log_info "  - Configure ALB annotations in helm-charts/*/values-aws.yaml"
    log_info "  - Add ACM certificate ARNs"
}

configure_secrets() {
    log_step "Configuring secrets..."
    
    log_warn "Production secrets should be created manually or via AWS Secrets Manager."
    echo ""
    log_info "Required secrets:"
    echo "  1. Grafana admin password:"
    echo "     kubectl create secret generic grafana-admin-secret \\"
    echo "       --from-literal=admin-user=admin \\"
    echo "       --from-literal=admin-password=<your-password> \\"
    echo "       -n monitoring"
    echo ""
    echo "  2. Configure Vault after deployment"
    echo "  3. Configure monitoring secrets"
}

display_access_info() {
    log_info "==================================================================="
    log_info "AWS EKS GitOps Stack Deployment Complete!"
    log_info "==================================================================="
    echo ""
    log_info "Next Steps:"
    echo ""
    echo "  1. Install AWS Load Balancer Controller"
    echo "  2. Configure DNS for your domain"
    echo "  3. Create ACM certificates"
    echo "  4. Update Ingress configurations with your domain"
    echo "  5. Create production secrets"
    echo ""
    log_info "Access Applications (via port-forward until ALB is configured):"
    echo ""
    echo "  ArgoCD:"
    echo "    kubectl port-forward -n argocd svc/argocd-server 8080:443"
    echo "    Username: admin"
    echo "    Password: $ARGOCD_PASSWORD"
    echo ""
    echo "  Grafana:"
    echo "    kubectl port-forward -n monitoring svc/grafana 3000:80"
    echo ""
    echo "  Prometheus:"
    echo "    kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
    echo ""
    echo "  Vault:"
    echo "    kubectl port-forward -n vault svc/vault 8200:8200"
    echo ""
    log_info "Check deployment status:"
    echo "    kubectl get pods -A"
    echo "    kubectl get applications -n argocd"
    echo "    kubectl get ingress -A"
    log_info "==================================================================="
}

# Main execution
main() {
    log_info "Starting AWS EKS GitOps Stack Setup..."
    echo ""
    
    check_prerequisites
    provision_infrastructure
    configure_kubectl
    deploy_argocd
    deploy_applications
    configure_ingress
    configure_secrets
    display_access_info
    
    log_info "Setup complete!"
}

main "$@"



