#!/bin/bash

# Quick Deployment Script for Production-Ready EKS Cluster with GitOps
# This is a simplified version for quick deployment with minimal configuration

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 Production-Ready EKS Cluster with GitOps - Quick Deploy${NC}"
echo "================================================================"

# Check if terraform.tfvars exists and has been configured
if [[ ! -f "terraform/terraform.tfvars" ]]; then
    echo -e "${RED}❌ terraform.tfvars not found!${NC}"
    echo "Please create and configure terraform/terraform.tfvars first."
    exit 1
fi

# Check for placeholder values
if grep -q "123456789012" terraform/terraform.tfvars; then
    echo -e "${YELLOW}⚠️  Warning: Placeholder AWS account ID found in terraform.tfvars${NC}"
    echo "Please update terraform/terraform.tfvars with your actual values."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for YOUR_ORG placeholder
if grep -q "YOUR_ORG" argo-cd/apps/root-app.yaml; then
    echo -e "${YELLOW}⚠️  Warning: Placeholder YOUR_ORG found in ArgoCD manifests${NC}"
    echo "Please update argo-cd/apps/root-app.yaml with your GitHub organization."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}✅ Starting deployment...${NC}"

# Step 1: Deploy Infrastructure
echo -e "${GREEN}📦 Step 1: Deploying Infrastructure with Terraform${NC}"
cd terraform
terraform init
terraform plan -var-file="terraform.tfvars"
echo -e "${YELLOW}⚠️  This will create AWS resources. Estimated cost: $150-400/month${NC}"
read -p "Continue with infrastructure deployment? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    terraform apply -var-file="terraform.tfvars"
    
    # Configure kubectl
    echo -e "${GREEN}🔧 Configuring kubectl...${NC}"
    aws eks update-kubeconfig --region $(terraform output -raw aws_region) --name $(terraform output -raw cluster_name)
    
    # Verify cluster access
    kubectl get nodes
    echo -e "${GREEN}✅ Infrastructure deployed successfully!${NC}"
else
    echo -e "${RED}❌ Infrastructure deployment cancelled${NC}"
    exit 1
fi

cd ..

# Step 2: Deploy ArgoCD
echo -e "${GREEN}🚢 Step 2: Deploying ArgoCD${NC}"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
    --namespace argocd \
    --create-namespace \
    --values argo-cd/bootstrap/values.yaml \
    --wait

# Wait for ArgoCD to be ready
echo -e "${GREEN}⏳ Waiting for ArgoCD to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get admin password
echo -e "${GREEN}🔑 Getting ArgoCD admin password...${NC}"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"
echo "$ARGOCD_PASSWORD" > argocd-admin-password.txt
chmod 600 argocd-admin-password.txt

echo -e "${GREEN}✅ ArgoCD deployed successfully!${NC}"

# Step 3: Deploy Applications
echo -e "${GREEN}📱 Step 3: Deploying Applications${NC}"
kubectl apply -f argo-cd/apps/root-app.yaml

echo -e "${GREEN}⏳ Waiting for applications to sync...${NC}"
sleep 30

# Monitor applications
echo -e "${GREEN}📊 Monitoring application deployment...${NC}"
for i in {1..10}; do
    echo "Check $i/10:"
    kubectl get applications -n argocd
    echo ""
    sleep 30
done

echo -e "${GREEN}🎉 Deployment completed!${NC}"
echo ""
echo "=== ACCESS INFORMATION ==="
echo ""
echo "ArgoCD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  https://localhost:8080"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo ""
echo "Grafana:"
echo "  kubectl port-forward svc/grafana -n monitoring 3000:80"
echo "  http://localhost:3000"
echo ""
echo "Prometheus:"
echo "  kubectl port-forward svc/prometheus-server -n monitoring 9090:9090"
echo "  http://localhost:9090"
echo ""
echo "=== USEFUL COMMANDS ==="
echo "kubectl get nodes"
echo "kubectl get pods -A"
echo "kubectl get applications -n argocd"
echo ""
echo -e "${GREEN}✅ All done! Check the ArgoCD UI to monitor your applications.${NC}"
