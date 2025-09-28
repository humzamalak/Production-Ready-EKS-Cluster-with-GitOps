#!/bin/bash

# GitOps Repository Configuration Script
# This script helps configure the deployment for your specific environment

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

# Function to validate input
validate_domain() {
    if [[ $1 =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_aws_account_id() {
    if [[ $1 =~ ^[0-9]{12}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to update files
update_file() {
    local file=$1
    local search=$2
    local replace=$3
    
    if [ -f "$file" ]; then
        sed -i.bak "s|$search|$replace|g" "$file"
        print_status "Updated $file"
    else
        print_warning "File $file not found, skipping..."
    fi
}

# Main configuration function
configure_deployment() {
    print_header "GitOps Repository Configuration"
    
    # Check if we're in the right directory
    if [ ! -f "app-of-apps.yaml" ]; then
        print_error "Please run this script from the repository root directory"
        exit 1
    fi
    
    print_status "Starting configuration process..."
    
    # Get domain name
    echo
    print_header "Domain Configuration"
    while true; do
        read -p "Enter your domain name (e.g., example.com): " DOMAIN
        if validate_domain "$DOMAIN"; then
            break
        else
            print_error "Invalid domain format. Please try again."
        fi
    done
    
    # Get AWS Account ID
    echo
    print_header "AWS Configuration"
    read -p "Enter your AWS Account ID (12 digits, or press Enter to skip): " AWS_ACCOUNT_ID
    
    if [ -n "$AWS_ACCOUNT_ID" ]; then
        if validate_aws_account_id "$AWS_ACCOUNT_ID"; then
            print_status "AWS Account ID validated"
        else
            print_error "Invalid AWS Account ID format. Must be 12 digits."
            exit 1
        fi
    else
        print_warning "Skipping AWS Account ID configuration"
        AWS_ACCOUNT_ID="ACCOUNT_ID"
    fi
    
    # Get repository URL
    echo
    print_header "Repository Configuration"
    read -p "Enter your repository URL (or press Enter to use default): " REPO_URL
    
    if [ -z "$REPO_URL" ]; then
        REPO_URL="https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps"
        print_status "Using default repository URL"
    fi
    
    # Get Grafana admin password
    echo
    print_header "Security Configuration"
    read -s -p "Enter Grafana admin password (or press Enter to use default): " GRAFANA_PASSWORD
    echo
    
    if [ -z "$GRAFANA_PASSWORD" ]; then
        GRAFANA_PASSWORD="changeme"
        print_warning "Using default Grafana password. Please change this in production!"
    fi
    
    # Confirm configuration
    echo
    print_header "Configuration Summary"
    echo "Domain: $DOMAIN"
    echo "AWS Account ID: $AWS_ACCOUNT_ID"
    echo "Repository URL: $REPO_URL"
    echo "Grafana Password: [HIDDEN]"
    echo
    
    read -p "Do you want to apply these configurations? (y/N): " CONFIRM
    
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        print_status "Configuration cancelled"
        exit 0
    fi
    
    # Apply configurations
    print_header "Applying Configurations"
    
    # Update domain names
    print_status "Updating domain names..."
    find apps -name "*.yaml" -type f -exec sed -i.bak "s/your-domain\.com/$DOMAIN/g" {} \;
    find apps -name "*.yaml" -type f -exec sed -i.bak "s/your-domain\.com/$DOMAIN/g" {} \;
    
    # Update AWS Account ID
    if [ "$AWS_ACCOUNT_ID" != "ACCOUNT_ID" ]; then
        print_status "Updating AWS Account ID..."
        find apps -name "*.yaml" -type f -exec sed -i.bak "s/ACCOUNT_ID/$AWS_ACCOUNT_ID/g" {} \;
    fi
    
    # Update repository URL
    print_status "Updating repository URL..."
    sed -i.bak "s|https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps|$REPO_URL|g" app-of-apps.yaml
    
    # Update Grafana password
    print_status "Updating Grafana password..."
    sed -i.bak "s/adminPassword: \"changeme\"/adminPassword: \"$GRAFANA_PASSWORD\"/g" apps/grafana/application.yaml
    
    # Clean up backup files
    print_status "Cleaning up backup files..."
    find . -name "*.bak" -type f -delete
    
    # Create configuration summary
    cat > deployment-config.env << EOF
# GitOps Deployment Configuration
# Generated on $(date)

DOMAIN=$DOMAIN
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
REPO_URL=$REPO_URL
GRAFANA_PASSWORD=[HIDDEN]

# Deployment commands
kubectl apply -f namespaces.yaml
kubectl apply -f app-of-apps.yaml

# Verification commands
kubectl get applications -n argocd
kubectl get pods -n monitoring
kubectl get pods -n vault
EOF
    
    print_header "Configuration Complete!"
    print_status "Configuration saved to deployment-config.env"
    print_status "You can now deploy your applications:"
    echo
    echo "  kubectl apply -f namespaces.yaml"
    echo "  kubectl apply -f app-of-apps.yaml"
    echo
    print_status "To verify deployment:"
    echo "  kubectl get applications -n argocd"
    echo
    print_warning "Remember to:"
    echo "  1. Initialize and unseal Vault after deployment"
    echo "  2. Change Grafana password in production"
    echo "  3. Configure TLS certificates for ingress"
    echo "  4. Set up backup strategies"
}

# Health check function
health_check() {
    print_header "Health Check"
    
    print_status "Checking Argo CD applications..."
    if kubectl get applications -n argocd > /dev/null 2>&1; then
        kubectl get applications -n argocd
    else
        print_error "Argo CD applications not found. Is Argo CD installed?"
        return 1
    fi
    
    echo
    print_status "Checking monitoring stack..."
    if kubectl get pods -n monitoring > /dev/null 2>&1; then
        kubectl get pods -n monitoring
    else
        print_error "Monitoring namespace not found"
        return 1
    fi
    
    echo
    print_status "Checking Vault..."
    if kubectl get pods -n vault > /dev/null 2>&1; then
        kubectl get pods -n vault
    else
        print_error "Vault namespace not found"
        return 1
    fi
    
    print_status "Health check complete!"
}

# Main script logic
case "${1:-configure}" in
    "configure")
        configure_deployment
        ;;
    "health")
        health_check
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [configure|health|help]"
        echo
        echo "Commands:"
        echo "  configure  - Configure deployment settings (default)"
        echo "  health     - Run health check on deployed applications"
        echo "  help       - Show this help message"
        echo
        echo "Examples:"
        echo "  $0                    # Configure deployment"
        echo "  $0 configure          # Configure deployment"
        echo "  $0 health             # Check deployment health"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
