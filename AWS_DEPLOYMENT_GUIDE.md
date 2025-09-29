# AWS EKS Deployment Guide

Complete step-by-step guide for deploying a production-ready EKS cluster with GitOps, Vault, Prometheus, and Grafana on AWS.

> **⚠️ Important**: This guide has been updated to use a **wave-based deployment approach**. For the most reliable deployment experience, we recommend following the **[Wave-Based Deployment Guide](WAVE_BASED_DEPLOYMENT_GUIDE.md)** first, then using this guide for AWS-specific infrastructure setup.

## 🎯 Overview

This guide will walk you through:
1. **Infrastructure Setup**: Creating EKS cluster, VPC, and supporting AWS resources
2. **GitOps Bootstrap**: Installing ArgoCD and core cluster components
3. **Monitoring Stack**: Deploying Prometheus and Grafana (Wave 2)
4. **Security Stack**: Setting up Vault server and agent injector (Wave 3)
5. **Vault Initialization**: Initializing Vault with policies and secrets (Wave 3.5)
6. **Web Application**: Deploying with progressive Vault integration (Wave 5)
7. **Verification**: Testing all components and access

## 📋 Prerequisites

### Required Tools

```bash
# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# kubectl v1.28+
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm v3.12+
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Terraform >=1.5.0
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Vault CLI (for secret management)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault
```

### AWS Account Setup

#### 1. Configure AWS Credentials
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, region (e.g., us-west-2), and output format (json)

# Verify AWS access
aws sts get-caller-identity
```

#### 2. Create Required IAM Role for VPC Flow Logs
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

# Get the role ARN (save this for later)
aws iam get-role --role-name flow-logs-role --query 'Role.Arn' --output text
```

#### 3. Required AWS Permissions
Your AWS user/role needs permissions for:
- EKS (Elastic Kubernetes Service)
- VPC (Virtual Private Cloud)
- IAM (Identity and Access Management)
- EC2 (Elastic Compute Cloud)
- CloudWatch
- S3 (for Terraform state)
- DynamoDB (for Terraform state locking)

## 🏗️ Part 1: Infrastructure Deployment

### Step 1: Clone Repository and Configure

```bash
# Clone the repository
git clone https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps.git
cd Production-Ready-EKS-Cluster-with-GitOps

# Navigate to infrastructure directory
cd infrastructure/terraform
```

### Step 2: Configure Terraform Variables

Create `terraform.tfvars`:

```hcl
# Basic Configuration
project_prefix = "my-eks-cluster"
environment    = "prod"
aws_region     = "us-west-2"

# REQUIRED: Replace with your actual IAM role ARN for VPC flow logs
flow_log_iam_role_arn = "arn:aws:iam::YOUR_ACCOUNT_ID:role/flow-logs-role"

# EKS Configuration
cluster_version = "1.28"
node_instance_types = ["t3.medium"]
min_size = 2
max_size = 5
desired_size = 3

# Optional: Custom tags for all resources
tags = {
  Owner       = "your-team@example.com"
  Environment = "prod"
  CostCenter  = "1234"
  Project     = "eks-gitops"
}
```

**Important**: Replace `YOUR_ACCOUNT_ID` with your actual AWS account ID from the flow logs role ARN.

### Step 3: Deploy Infrastructure

```bash
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
- EKS cluster with 3 worker nodes
- VPC with public/private subnets across 2 AZs
- Security groups and IAM roles
- S3 bucket for Terraform state
- DynamoDB table for state locking

### Step 4: Verify Infrastructure

```bash
# Check cluster status
kubectl get nodes -o wide

# Check cluster info
kubectl cluster-info

# Check available storage classes
kubectl get storageclass

# Check available namespaces
kubectl get namespaces
```

## 🚀 Part 2: GitOps Bootstrap

### Step 1: Deploy Core Components

```bash
# Navigate back to repository root
cd ../..

# Apply core namespaces and security policies
kubectl apply -f bootstrap/00-namespaces.yaml
kubectl apply -f bootstrap/01-pod-security-standards.yaml
kubectl apply -f bootstrap/02-network-policy.yaml
kubectl apply -f bootstrap/03-helm-repos.yaml

# Verify namespaces were created
kubectl get namespaces
```

### Step 2: Install ArgoCD

```bash
# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD with custom values
helm upgrade --install argo-cd argo/argo-cd \
  -n argocd --create-namespace \
  -f bootstrap/helm-values/argo-cd-values.yaml

# Wait for ArgoCD server to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argo-cd-argocd-server -n argocd

# Verify ArgoCD installation
kubectl get pods -n argocd
kubectl get svc -n argocd
```

### Step 3: Access ArgoCD

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Port-forward ArgoCD UI
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443 --address=127.0.0.1

# Access ArgoCD at https://localhost:8080
# Username: admin
# Password: (from the command above)
```

## 📊 Part 3: Monitoring Stack Deployment

### Step 1: Create ArgoCD Project

```bash
# Create the project used by applications
kubectl apply -f clusters/production/production-apps-project.yaml

# Verify project was created
kubectl get appproject -n argocd
```

### Step 2: Deploy Root Application

```bash
# Deploy the root application (app-of-apps pattern)
kubectl apply -f clusters/production/app-of-apps.yaml

# Monitor application deployment
kubectl get applications -n argocd
watch kubectl get applications -n argocd
```

### Step 3: Monitor Deployment Progress

Applications deploy in sync waves:
- **Wave 1**: Production cluster bootstrap
- **Wave 2**: Monitoring stack (Prometheus, Grafana)
- **Wave 3**: Security stack (Vault)
- **Wave 4**: Web application

```bash
# Check application sync status
kubectl get applications -n argocd -o wide

# Wait for monitoring applications to sync
kubectl wait --for=condition=Synced --timeout=600s application/monitoring-stack -n argocd

# Check monitoring pods
kubectl get pods -n monitoring
```

### Step 4: Access Monitoring Stack

```bash
# Access Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus -n monitoring 9090:9090
# Access at http://localhost:9090

# Access Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80
# Access at http://localhost:3000
# Username: admin
# Password: Get with: kubectl get secret grafana-admin -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d

# Access AlertManager
kubectl port-forward svc/prometheus-kube-prometheus-stack-alertmanager -n monitoring 9093:9093
# Access at http://localhost:9093
```

## 🔐 Part 4: Vault Security Stack (Wave 3)

### Step 1: Deploy Vault

```bash
# Wait for Vault application to sync
kubectl wait --for=condition=Synced --timeout=600s application/security-stack -n argocd

# Check Vault pods
kubectl get pods -n vault

# Wait for Vault to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault --timeout=300s

# Check Vault status (should show "Initialized: false" and "Sealed: true")
kubectl port-forward svc/vault -n vault 8200:8200 &
export VAULT_ADDR="http://localhost:8200"
vault status
```

### Expected Outcome
- ✅ Vault server running
- ✅ Vault agent injector ready
- ✅ RBAC configured
- ✅ Vault is sealed and uninitialized

---

## 🔧 Part 4.5: Vault Initialization (Wave 3.5)

### Step 1: Deploy Vault Initialization

```bash
# Deploy Vault initialization job
kubectl apply -f applications/security/vault/init-job.yaml

# Monitor initialization job
kubectl get jobs -n vault
kubectl logs job/vault-init -n vault -f
```

### Step 2: Verify Vault Initialization

```bash
# Verify Vault is initialized and unsealed
vault status
# Should show "Initialized: true" and "Sealed: false"

# Check created secrets
vault kv list secret/production/web-app/
# Should show: db, api, external
```

### Expected Outcome
- ✅ Vault initialized and unsealed
- ✅ Kubernetes auth enabled
- ✅ Web-app role and policy created
- ✅ Sample secrets populated

## 🌐 Part 5: Web Application Deployment (Wave 5)

### Phase 1: Deploy Without Vault Integration

```bash
# Wait for web application to sync
kubectl wait --for=condition=Synced --timeout=600s application/k8s-web-app -n argocd

# Check web application pods
kubectl get pods -n production -l app.kubernetes.io/name=k8s-web-app

# Check application logs (should show app running with K8s secrets)
kubectl logs -n production deployment/k8s-web-app

# Test application access
kubectl port-forward svc/k8s-web-app -n production 8080:80
# Access http://localhost:8080
```

### Expected Outcome
- ✅ Web application running
- ✅ Using Kubernetes secrets (not Vault)
- ✅ All health checks passing

### Phase 2: Enable Vault Integration

```bash
# Update web app to use Vault
kubectl patch application k8s-web-app -n argocd --type merge -p '
{
  "spec": {
    "source": {
      "helm": {
        "valueFiles": ["values.yaml", "values-vault-enabled.yaml"]
      }
    }
  }
}'

# Wait for sync and verify
kubectl get pods -n production
kubectl logs -n production deployment/k8s-web-app
# Should show Vault integration working

# Verify Vault secrets are injected
kubectl exec -n production deployment/k8s-web-app -- env | grep DB_
# Should show database environment variables from Vault

# Check Vault agent logs
kubectl logs -n production deployment/k8s-web-app -c vault-agent
```

### Expected Outcome
- ✅ Web application using Vault secrets
- ✅ Vault agent injection working
- ✅ Zero-downtime migration

## ✅ Part 6: Verification and Testing

### Step 1: Comprehensive Health Check

```bash
# Check all pods across all namespaces
kubectl get pods -A

# Check ArgoCD applications status
kubectl get applications -n argocd

# Check monitoring stack
kubectl get pods -n monitoring

# Check Vault
kubectl get pods -n vault

# Check web application
kubectl get pods -n production
```

### Step 2: Test Application Endpoints

```bash
# Test web application health
curl -s http://localhost:8080/health | jq

# Test web application readiness
curl -s http://localhost:8080/ready | jq

# Test web application info
curl -s http://localhost:8080/api/info | jq
```

### Step 3: Verify Monitoring

```bash
# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health == "up")'

# Check Grafana datasources
curl -s -u admin:$(kubectl get secret grafana-admin -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d) \
  http://localhost:3000/api/datasources
```

### Step 4: Verify Vault Integration

```bash
# Check Vault status
vault status

# List available secrets
vault kv list secret/production/web-app/

# Test secret retrieval
vault kv get secret/production/web-app/db
```

## 🔧 Configuration and Customization

### Update Repository URLs

If you've forked the repository, update the URLs:

```bash
# Update repository URL in all application manifests
sed -i 's|https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps|https://github.com/your-org/your-repo|g' \
  clusters/production/app-of-apps.yaml \
  applications/monitoring/app-of-apps.yaml \
  applications/security/app-of-apps.yaml \
  applications/web-app/k8s-web-app/application.yaml
```

### Configure Domain Names

Update domain names for production use:

```bash
# Update domain references
sed -i 's/yourdomain\.com/your-actual-domain.com/g' \
  applications/web-app/k8s-web-app/values.yaml
```

### Customize Resource Limits

Update resource limits based on your requirements:

```bash
# Edit web application values
vim applications/web-app/k8s-web-app/values.yaml

# Update resource limits
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 256Mi
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Terraform Deployment Fails
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check Terraform state
terraform state list

# Review Terraform plan
terraform plan -var-file="terraform.tfvars"
```

#### 2. ArgoCD Applications Not Syncing
```bash
# Check application status
kubectl describe application <app-name> -n argocd

# Force sync
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller
```

#### 3. Pods Not Starting
```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace> --previous

# Check events
kubectl get events -n <namespace> --sort-by=.metadata.creationTimestamp
```

#### 4. Vault Integration Issues
```bash
# Check Vault agent logs
kubectl logs -n production -l app.kubernetes.io/name=k8s-web-app -c vault-agent

# Verify Vault connectivity
kubectl exec -n vault vault-0 -- vault status

# Check service account
kubectl get sa k8s-web-app-vault-sa -n production
```

### Debug Commands

```bash
# Get detailed pod information
kubectl describe pod <pod-name> -n <namespace>

# Execute into pod for debugging
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Check resource usage
kubectl top pods -n <namespace>
kubectl top nodes

# Check persistent volumes
kubectl get pv,pvc -A
```

## 💰 Cost Estimation

**Estimated Monthly Costs:**
- EKS Cluster: ~$73/month (control plane)
- Worker Nodes (3x t3.medium): ~$150/month
- Load Balancers: ~$30/month
- Storage (EBS): ~$20/month
- Data Transfer: ~$10/month
- CloudWatch Logs: ~$15/month

**Total: ~$300/month** (varies by usage and region)

## 🧹 Cleanup

### Destroy Infrastructure

```bash
# Navigate to terraform directory
cd infrastructure/terraform

# Review what will be destroyed
terraform plan -destroy -var-file="terraform.tfvars"

# Destroy infrastructure
terraform destroy -var-file="terraform.tfvars"

# Clean up local files
rm -f ../infrastructure-outputs.txt
```

### Manual Kubernetes Cleanup

Before destroying infrastructure:

```bash
# Delete ArgoCD applications
kubectl delete applications --all -n argocd

# Delete namespaces
kubectl delete namespace monitoring
kubectl delete namespace vault
kubectl delete namespace production
kubectl delete namespace argocd
```

**⚠️ Warning:** This will permanently delete all resources and data.

## 📚 Next Steps

After successful deployment:

1. **Configure Ingress**: Set up domain names and SSL certificates
2. **Implement CI/CD**: Set up GitHub Actions for automated builds
3. **Add Observability**: Implement distributed tracing with Jaeger
4. **Security Scanning**: Add container vulnerability scanning
5. **Load Testing**: Perform load testing to validate auto-scaling
6. **Backup Strategy**: Implement application data backup procedures
7. **Monitoring**: Configure alerts and dashboards
8. **Documentation**: Update team documentation with access procedures

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review the [TROUBLESHOOTING.md](TROUBLESHOOTING.md) file
3. Open an issue in the repository
4. Consult AWS EKS documentation

---

**🎉 Congratulations!** You now have a production-ready EKS cluster with GitOps, monitoring, security, and a sample application deployed and running!

**Happy Deploying! 🚀**