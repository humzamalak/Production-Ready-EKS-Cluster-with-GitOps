# AWS EKS Deployment Guide

Complete guide for deploying the Production-Ready EKS Cluster with GitOps to AWS.

## Overview

This guide covers deploying a production-ready EKS cluster with:
- **Infrastructure as Code**: Terraform modules for VPC, EKS, IAM, and backup
- **GitOps with ArgoCD**: Declarative application management
- **Monitoring Stack**: Prometheus, Grafana, AlertManager
- **Security**: Pod Security Standards, IRSA, Vault Agent Injector
- **Web Application**: Node.js app with auto-scaling

## Prerequisites

### Required Tools
```bash
# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# kubectl v1.31+
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm v3
# SAFER: install via package manager or verify signature instead of piping to bash
# Ubuntu/Debian (APT):
sudo snap install helm --classic || {
  wget https://get.helm.sh/helm-v3.14.4-linux-amd64.tar.gz && \
  wget https://get.helm.sh/helm-v3.14.4-linux-amd64.tar.gz.sha256sum && \
  sha256sum -c helm-v3.14.4-linux-amd64.tar.gz.sha256sum && \
  tar -xzvf helm-v3.14.4-linux-amd64.tar.gz && \
  sudo mv linux-amd64/helm /usr/local/bin/helm;
}

# Terraform >=1.4.0
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### AWS Requirements

1. **AWS Account** with permissions for:
   - EKS (Elastic Kubernetes Service)
   - VPC (Virtual Private Cloud)
   - IAM (Identity and Access Management)
   - EC2 (Elastic Compute Cloud)
   - CloudWatch
   - S3 (for Terraform state)

2. **IAM Role for VPC Flow Logs** (required):
   ```bash
   # Create IAM role for VPC flow logs
   aws iam create-role --role-name flow-logs-role --assume-role-policy-document '{
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Service": "vpc-flow-logs.amazonaws.com"
         },
         "Action": "sts:AssumeRole"
       }
     ]
   }'
   
   # Attach policy for CloudWatch Logs
   aws iam attach-role-policy --role-name flow-logs-role --policy-arn arn:aws:iam::aws:policy/service-role/VPCFlowLogsDeliveryRole
   
   # Get the role ARN
   aws iam get-role --role-name flow-logs-role --query 'Role.Arn' --output text
   ```

3. **Configure AWS Credentials**:
   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret Access Key, and region (e.g., eu-west-1)
   
   # Verify AWS access
   aws sts get-caller-identity
   ```

## Configuration

### 1. Update Terraform Configuration

Edit `terraform/terraform.tfvars`:

```hcl
# Basic Configuration
project_prefix = "my-eks-cluster"
environment    = "prod"
aws_region     = "eu-west-1"

# REQUIRED: Replace with your actual IAM role ARN for VPC flow logs
flow_log_iam_role_arn = "arn:aws:iam::YOUR_ACCOUNT_ID:role/flow-logs-role"

# EKS Configuration
cluster_version = "1.28"
node_instance_types = ["t3.medium"]
min_size = 1
max_size = 3
desired_size = 2

# Optional: Custom tags for all resources
tags = {
  Owner       = "your-team@example.com"
  Environment = "prod"
  CostCenter  = "1234"
  Project     = "eks-gitops"
}
```

**Important Notes:**
- Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID
- The `flow_log_iam_role_arn` must be created before deployment (see prerequisites)
- Adjust `node_instance_types` and sizing based on your workload requirements
- The `cluster_version` should be compatible with your kubectl version

### 2. Update ArgoCD Configuration

Replace the repository URL in ArgoCD manifests with your GitHub organization:

```bash
# Update root application
sed -i 's|https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps|https://github.com/your-org/your-repo|g' clusters/production/app-of-apps.yaml

# Update monitoring applications
sed -i 's|https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps|https://github.com/your-org/your-repo|g' applications/monitoring/app-of-apps.yaml

# Update security applications
sed -i 's|https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps|https://github.com/your-org/your-repo|g' applications/security/app-of-apps.yaml
```

## Deployment Steps

### Step 1: Infrastructure Deployment

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the plan (this will show all resources to be created)
terraform plan -var-file="terraform.tfvars"

# Apply the infrastructure (takes 15-20 minutes)
terraform apply -var-file="terraform.tfvars"

# Save important outputs for reference
terraform output > ../infrastructure-outputs.txt

# Configure kubectl for the new cluster
aws eks update-kubeconfig --region $(terraform output -raw aws_region) --name $(terraform output -raw cluster_name)

# Verify cluster access
kubectl get nodes
kubectl get namespaces
```

**Expected Output:**
- EKS cluster with worker nodes
- VPC with public/private subnets
- Security groups and IAM roles
- S3 bucket for Terraform state
- DynamoDB table for state locking

### Step 2: Bootstrap Argo CD and Components

```bash
# Core namespaces/security
kubectl apply -f bootstrap/00-namespaces.yaml
kubectl apply -f bootstrap/01-pod-security-standards.yaml
kubectl apply -f bootstrap/02-network-policy.yaml
kubectl apply -f bootstrap/03-helm-repos.yaml

# Install Argo CD (full) via Helm
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argo-cd argo/argo-cd \
  -n argocd --create-namespace \
  -f bootstrap/helm-values/argo-cd-values.yaml

# Wait for Argo CD server
kubectl wait --for=condition=available --timeout=300s deployment/argo-cd-argocd-server -n argocd

# Verify Argo CD installation
kubectl get pods -n argocd
kubectl get svc -n argocd

# Get Argo CD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# (Optional) Port-forward UI locally
# If 8080 is busy, use 8443 instead
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443 --address=127.0.0.1
# Open: https://localhost:8080 (user: admin, pass: above)
```

**Expected Output:**
- ArgoCD server, application controller, and repo server pods running
- ArgoCD services exposed
- Admin password for initial login

### Step 3: Application Bootstrap

```bash
# Apply the root application (app-of-apps pattern)
kubectl apply -f clusters/production/app-of-apps.yaml

# Monitor application deployment - applications deploy in sync waves:
# Wave 1: Production cluster bootstrap
# Wave 2: Monitoring stack (Prometheus, Grafana)
# Wave 3: Security stack (Vault)
kubectl get applications -n argocd
watch kubectl get applications -n argocd

# Check application sync status
kubectl get applications -n argocd -o wide

# Wait for applications to be synced
kubectl wait --for=condition=Synced --timeout=600s application/production-cluster -n argocd
```

**Expected Output:**
- Root application created in ArgoCD
- Monitoring stack (Prometheus, Grafana, AlertManager) deployed
- Sample applications deployed
- All applications showing "Synced" status

### Step 4: Web Application Deployment

```bash
# Deploy the web application via ArgoCD
kubectl apply -f examples/web-app/helm/

# Check web application status
kubectl get applications -n argocd | grep k8s-web-app

# Monitor web application deployment
kubectl get pods -n production -l app=k8s-web-app
```

## Verification

### Check Cluster Status

```bash
# Check nodes
kubectl get nodes

# Check all pods across all namespaces
kubectl get pods -A

# Check ArgoCD applications
kubectl get applications -n argocd

# Check monitoring stack
kubectl get pods -n monitoring

# Check web application
kubectl get pods -n production -l app=k8s-web-app
```

### Access Applications

#### ArgoCD UI (full install)
```bash
# Port-forward ArgoCD UI
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443

# Access at https://localhost:8080
# Username: admin
# Password: (retrieve via)
# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

#### Grafana
```bash
# Port-forward Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# Access at http://localhost:3000
# Username: admin
# Password: [Generated randomly - check deployment log or grafana-admin-password.txt]
# 
# To get the actual password:
kubectl get secret grafana-admin -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d
```

#### Prometheus
```bash
# Port-forward Prometheus
kubectl port-forward svc/prometheus-server -n monitoring 9090:9090

# Access at http://localhost:9090
```

#### Web Application
```bash
# Port-forward web application
kubectl port-forward svc/k8s-web-app-service -n production 8080:80

# Test the application
curl http://localhost:8080/health
curl http://localhost:8080/
```

## Cost Estimation

**Estimated Monthly Costs:**
- EKS Cluster: ~$73/month (control plane)
- Worker Nodes: ~$50-200/month (depending on instance types)
- Load Balancers: ~$20-50/month
- Storage: ~$10-30/month
- Data Transfer: ~$5-20/month

**Total: $150-400/month** (varies by usage)

## Troubleshooting

### Common Issues

1. **Terraform fails with IAM permissions**
   ```bash
   # Check AWS credentials
   aws sts get-caller-identity
   
   # Verify IAM permissions
   aws iam list-attached-user-policies --user-name YOUR_USERNAME
   ```

2. **ArgoCD applications not syncing**
   ```bash
   # Check application status
   kubectl describe application <app-name> -n argocd
   
   # Check ArgoCD logs
   kubectl logs -n argocd deployment/argocd-application-controller
   ```

3. **Pods not starting**
   ```bash
   # Check pod status
   kubectl describe pod <pod-name> -n <namespace>
   
   # Check pod logs
   kubectl logs <pod-name> -n <namespace>
   ```

4. **Cluster access issues**
   ```bash
   # Reconfigure kubectl
   aws eks update-kubeconfig --region <region> --name <cluster_name>
   
   # Check cluster status
   aws eks describe-cluster --name <cluster_name> --region <region>
   ```

## Teardown

To destroy the infrastructure:

```bash
# Destroy infrastructure using Makefile (recommended)
make destroy

# Or manually with Terraform
cd terraform

# Review what will be destroyed
terraform plan -destroy -var-file="terraform.tfvars"

# Destroy infrastructure (interactive)
terraform destroy -var-file="terraform.tfvars"

# Force destroy without confirmations
terraform destroy -var-file="terraform.tfvars" -auto-approve
```

### Manual Kubernetes Cleanup

Before destroying infrastructure, clean up Kubernetes resources:

```bash
# Delete ArgoCD applications
kubectl delete applications --all -n argocd

# Delete monitoring stack
kubectl delete namespace monitoring

# Delete ArgoCD namespace
kubectl delete namespace argocd
```

**⚠️ Warning:** This will permanently delete all resources and data.

## Next Steps

After successful deployment:

1. **Set up monitoring**: Configure Prometheus and Grafana dashboards
2. **Implement CI/CD**: Set up GitHub Actions for automated builds
3. **Add observability**: Implement distributed tracing with Jaeger
4. **Security scanning**: Add container vulnerability scanning
5. **Backup strategy**: Implement application data backup procedures
6. **Load testing**: Perform load testing to validate auto-scaling
7. **Documentation**: Update team documentation with access procedures

## Automation Scripts

This repository includes helpful automation scripts:

### Configuration Script
```bash
# Interactive configuration script for easy setup
# Note: Scripts may need to be created or updated for current setup
# ./examples/scripts/configure-deployment.sh
```

### Health Check Script
```bash
# Comprehensive health check script
# Note: Scripts may need to be created or updated for current setup
# ./examples/scripts/health-check.sh
```

## Support

For issues and questions:
1. Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Open an issue in the repository
3. Consult the documentation in the `docs/` directory

---

**Happy Deploying! 🚀**
