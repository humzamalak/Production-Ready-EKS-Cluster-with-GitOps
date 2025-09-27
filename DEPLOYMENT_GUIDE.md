# Deployment Guide - Production-Ready EKS Cluster with GitOps

This guide provides step-by-step instructions for deploying the Production-Ready EKS Cluster with GitOps, including automated deployment scripts.

## 🚀 Quick Start

### Option 1: Automated Deployment (Recommended)

Use the provided deployment scripts for automated deployment:

```bash
# Full automated deployment (EKS + ArgoCD + Prometheus + Grafana)
./deploy.sh

# Quick deployment with minimal configuration
./quick-deploy.sh

# Validate prerequisites only
./deploy.sh --validate-only

# Dry run to see what would be deployed
./deploy.sh --dry-run

# Skip infrastructure deployment (if already deployed)
./deploy.sh --skip-infra

# Skip ArgoCD installation
./deploy.sh --skip-argocd

# Skip application deployment
./deploy.sh --skip-apps

# Auto-approve all prompts (recommended to avoid Vim prompts)
./deploy.sh -y
# or
./deploy.sh --auto-approve

# Create only Terraform backend resources
./deploy.sh --create-backend-only
```

### Option 2: Manual Deployment

Follow the manual steps outlined below.

## 📋 Prerequisites

### Required Tools

Install the following tools on your system:

```bash
# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# kubectl v1.27+
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm v3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

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

## ⚙️ Configuration

### 1. Update Terraform Configuration

Edit `terraform/terraform.tfvars`:

```hcl
project_prefix = "my-eks-cluster"
environment    = "prod"
aws_region     = "eu-west-1"

# REQUIRED: Replace with your actual IAM role ARN for VPC flow logs
flow_log_iam_role_arn = "arn:aws:iam::YOUR_ACCOUNT_ID:role/flow-logs-role"

# Optional: Custom tags for all resources
tags = {
  Owner       = "your-team@example.com"
  Environment = "prod"
  CostCenter  = "1234"
}
```

### 2. Update ArgoCD Configuration

Replace `YOUR_ORG` in ArgoCD manifests with your GitHub organization:

```bash
# Update root application
sed -i 's/YOUR_ORG/your-github-org/g' argo-cd/apps/root-app.yaml

# Update other applications if needed
find argo-cd/apps -name "*.yaml" -exec sed -i 's/YOUR_ORG/your-github-org/g' {} \;
```

### 3. (Optional) Customize ArgoCD Values

Edit `argo-cd/bootstrap/values.yaml` to customize:
- High availability settings
- Resource limits
- RBAC policies
- Ingress configuration
- SSO/OIDC settings

## 🚀 Deployment Steps

### Step 1: Infrastructure Deployment

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan -var-file="terraform.tfvars"

# Apply the infrastructure (takes 15-20 minutes)
terraform apply -var-file="terraform.tfvars"

# Configure kubectl for the new cluster
aws eks update-kubeconfig --region $(terraform output -raw aws_region) --name $(terraform output -raw cluster_name)

# Verify cluster access
kubectl get nodes
```

### Step 2: ArgoCD Installation

```bash
# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD with production configuration
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values argo-cd/bootstrap/values.yaml \
  --wait

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

### Step 3: Application Bootstrap

```bash
# Apply the root application (app-of-apps pattern)
kubectl apply -f argo-cd/apps/root-app.yaml

# Monitor application deployment
kubectl get applications -n argocd
watch kubectl get applications -n argocd
```

## 🔍 Verification

### Check Cluster Status

```bash
# Check nodes
kubectl get nodes

# Check all pods
kubectl get pods -A

# Check ArgoCD applications
kubectl get applications -n argocd

# Check monitoring stack
kubectl get pods -n monitoring

# Check Prometheus status
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Check Grafana status
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
```

### Access Applications

#### ArgoCD UI
```bash
# Port-forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at https://localhost:8080
# Username: admin
# Password: [from Step 2]
```

#### Grafana
```bash
# Port-forward Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# Access at http://localhost:3000
# Username: admin
# Password: admin123 (default - change in production!)
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

#### AlertManager
```bash
# Port-forward AlertManager
kubectl port-forward svc/alertmanager -n monitoring 9093:9093

# Access at http://localhost:9093
```

## 🛠️ Automation Scripts

### Full Deployment Script (`deploy.sh`)

Comprehensive deployment script with validation and error handling:

```bash
# Full deployment
./deploy.sh

# Skip infrastructure (if already deployed)
./deploy.sh --skip-infra

# Auto-approve Terraform apply
./deploy.sh --auto-approve

# Validate prerequisites only
./deploy.sh --validate-only

# Verbose output
./deploy.sh --verbose
```

**Features:**
- ✅ Prerequisites validation
- ✅ Infrastructure deployment
- ✅ ArgoCD installation
- ✅ Application deployment
- ✅ Error handling and logging
- ✅ Access information display
- ✅ Configurable options

### Quick Deployment Script (`quick-deploy.sh`)

Simplified script for quick deployment:

```bash
./quick-deploy.sh
```

**Features:**
- ✅ Interactive prompts
- ✅ Basic validation
- ✅ Step-by-step deployment
- ✅ Access information display

## 📊 Cost Estimation

**Estimated Monthly Costs:**
- EKS Cluster: ~$73/month (control plane)
- Worker Nodes: ~$50-200/month (depending on instance types)
- Load Balancers: ~$20-50/month
- Storage: ~$10-30/month
- Data Transfer: ~$5-20/month

**Total: $150-400/month** (varies by usage)

## 🔧 Troubleshooting

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

### Useful Commands

```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A

# Check ArgoCD status
kubectl get applications -n argocd
kubectl get pods -n argocd

# Check monitoring stack
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# View logs
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n monitoring deployment/prometheus-server
```

## 🧹 Teardown

To destroy the infrastructure:

```bash
# Interactive teardown with confirmations
./teardown.sh

# Force teardown without confirmations
./teardown.sh --force

# Keep backend resources (S3 bucket and DynamoDB table)
./teardown.sh --keep-backend

# Dry run to see what would be destroyed
./teardown.sh --dry-run

# Validate and show resources without destroying
./teardown.sh --validate-only

# Force cleanup of stuck Kubernetes resources
./teardown.sh --force-k8s-cleanup

# Auto-confirm all prompts (recommended to avoid Vim prompts)
./teardown.sh -y
# or
./teardown.sh --yes
```

### Teardown Process

The teardown script performs the following steps in order:

1. **Prerequisites Validation**: Checks for required tools and AWS credentials
2. **Resource Discovery**: Identifies all infrastructure resources to be destroyed
3. **Kubernetes Cleanup**: 
   - Deletes ArgoCD applications and Helm releases
   - Removes monitoring stack (Prometheus, Grafana, AlertManager)
   - Cleans up all namespaces and resources
   - Force cleanup options for stuck resources
4. **Terraform Destruction**: Destroys EKS cluster, VPC, and all AWS resources
5. **Backend Cleanup**: Optionally removes S3 bucket and DynamoDB table
6. **Verification**: Provides commands to verify complete teardown

### Force Cleanup Options

If normal teardown fails, use these options:

```bash
# Force cleanup of Kubernetes resources
./teardown.sh --force-k8s-cleanup

# Force destroy without Terraform state
./teardown.sh --force

# Combine both for maximum cleanup
./teardown.sh --force --force-k8s-cleanup
```

### Manual Cleanup (Alternative)

If the automated teardown script fails, you can manually clean up resources:

```bash
# Destroy infrastructure
cd terraform
terraform destroy -var-file="terraform.tfvars" -auto-approve

# Or for interactive mode (may open Vim for confirmation)
terraform destroy -var-file="terraform.tfvars"
```

**⚠️ Warning:** This will permanently delete all resources and data.

## 📚 Additional Resources

- [Onboarding Guide](docs/onboarding.md)
- [ArgoCD Configuration](docs/argocd-configuration.md)
- [Monitoring & Alerting](docs/monitoring-alerting.md)
- [Security Best Practices](docs/security-best-practices.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [FAQ](FAQ.md)

## 🆘 Support

For issues and questions:
1. Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review the [FAQ](FAQ.md)
3. Open an issue in the repository
4. Consult the documentation in the `docs/` directory

---

**Happy Deploying! 🚀**
