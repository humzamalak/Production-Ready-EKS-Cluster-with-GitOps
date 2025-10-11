# AWS Deployment Guide (Advanced)

> 🚀 **Advanced: Production Deployment on AWS EKS**  
> **New to this repository?** Start with [Local Deployment Guide](local-deployment.md) first  
> **Compatibility**: Kubernetes v1.33.0 (EKS cluster version 1.33)

Complete guide for deploying this GitOps repository on **AWS EKS** for production environments with high availability, auto-scaling, and enterprise features.

## 🎯 Overview

This deployment follows a **7-phase approach** with built-in verification:

| Phase | Component | Duration | Optional |
|-------|-----------|----------|----------|
| **Phase 1** | AWS Infrastructure | 15-20 min | Required |
| **Phase 2** | Bootstrap | 5-10 min | Required |
| **Phase 3** | Monitoring | 5-10 min | Required |
| **Phase 4** | Vault Deployment | 5 min | ⚠️ **Optional** |
| **Phase 5** | Vault Configuration | 10 min | ⚠️ **Optional** |
| **Phase 6** | Web App Deployment | 5 min | Required |
| **Phase 7** | Vault Integration | 10 min | ⚠️ **Optional** |

**Total Time**: ~40 minutes (without Vault) or ~65 minutes (with Vault)

## 🔀 Local vs AWS Comparison

| Feature | Local (Minikube) | AWS EKS (This Guide) |
|---------|------------------|----------------------|
| **Infrastructure** | Single-node Minikube | Multi-AZ EKS cluster with managed nodes |
| **Vault** | Single replica, manual unseal | HA (3 replicas), KMS auto-unseal |
| **Storage** | Local `standard` StorageClass | AWS EBS `gp3` with encryption |
| **Networking** | Port-forward access | ALB Ingress with TLS |
| **Cost** | Free (local resources) | AWS charges apply (~$150-300/month) |
| **Complexity** | ⭐ Easy | ⭐⭐⭐ Advanced |
| **Setup Time** | ~30 minutes | ~60 minutes |
| **Best For** | Learning, development | Production workloads |

**Prerequisites**: Familiarity with local deployment recommended. See [Local Deployment Guide](local-deployment.md).

## 📋 Prerequisites

### Required Tools

```bash
# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
aws --version

# kubectl v1.33+
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm v3.18+
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Terraform >=1.4.0
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Vault CLI
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault
```

### AWS Account Setup

```bash
# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, region (e.g., us-west-2), output format (json)

# Verify access
aws sts get-caller-identity
```

**Required AWS permissions**: EKS, VPC, IAM, EC2, CloudWatch, S3, DynamoDB

## 🚀 Quick Start (Automated)

### Single Command Deployment

```bash
# Run the automated setup script (requires AWS credentials configured)
./scripts/setup-aws.sh
```

This script automatically:
- ✅ Checks prerequisites (AWS CLI, terraform, kubectl, helm)
- ✅ Provisions AWS infrastructure with Terraform
- ✅ Configures kubectl for EKS
- ✅ Deploys ArgoCD
- ✅ Bootstraps GitOps applications
- ✅ Provides access credentials

**Skip to Phase 3** for verification if using the automated script.

---

## 🚀 Phase 1: AWS Infrastructure (Manual)

### Step 1.1: Clone Repository

```bash
git clone https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps.git
cd Production-Ready-EKS-Cluster-with-GitOps
```

### Step 1.2: Configure Terraform

```bash
cd terraform/environments/aws

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
cat > terraform.tfvars <<EOF
project_prefix = "my-eks-cluster"
environment    = "prod"
aws_region     = "us-west-2"

# EKS Configuration (Kubernetes v1.33.0)
kubernetes_version = "1.33"
node_instance_types = ["t3.medium"]
min_size = 2
max_size = 5
desired_size = 3

tags = {
  Owner       = "your-team@example.com"
  Environment = "prod"
  Project     = "eks-gitops"
}
EOF
```

### Step 1.3: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply (takes 15-20 minutes)
terraform apply -auto-approve

# Save outputs
terraform output > terraform-outputs.txt
```

**Using Makefile:**
```bash
# From repository root
make init       # Initialize Terraform
make plan       # Review plan
make apply      # Deploy infrastructure
```

### Step 1.4: Configure kubectl

```bash
# Return to repository root
cd ../../..

# Update kubeconfig
aws eks update-kubeconfig \
  --region us-west-2 \
  --name production-cluster
```

### Step 1.5: Verify Infrastructure

```bash
# Check nodes
kubectl get nodes
# Expected: 3 nodes in Ready state

# Check cluster info
kubectl cluster-info
```

**✅ Phase 1 Complete**: EKS cluster deployed, kubectl configured

## 🔧 Phase 2: ArgoCD Bootstrap

### Step 2.1: (Optional) Update Repository URL

```bash
# If using a fork, update the repository URL in all ArgoCD applications
# For Linux:
find argo-apps/ -name "*.yaml" -type f -exec sed -i 's|https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps|https://github.com/YOUR-ORG/YOUR-REPO|g' {} \;

# For macOS:
find argo-apps/ -name "*.yaml" -type f -exec sed -i '' 's|https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps|https://github.com/YOUR-ORG/YOUR-REPO|g' {} \;
```

> **Note**: If using the main repository without forking, skip this step.

### Step 2.2: Create Namespaces

```bash
# Apply namespace definitions
kubectl apply -f argo-apps/install/01-namespaces.yaml

# Wait for namespaces to be active
kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/argocd --timeout=60s
```

### Step 2.3: Install ArgoCD

```bash
# Install ArgoCD using official manifest
ARGOCD_VERSION="3.1.0"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml

# Wait for ArgoCD to be ready (3-5 minutes on AWS)
kubectl wait --for=condition=available --timeout=600s \
  deployment/argocd-server -n argocd

# Additional wait for full initialization
sleep 30
```

**Using Makefile:**
```bash
make argo-install  # Installs ArgoCD
```

### Step 2.4: Access ArgoCD UI

```bash
# Get admin password
export ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"

# Port forward to access UI (temporary)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
echo "ArgoCD: https://localhost:8080"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
```

**Alternative**: Use the automated login script:
```bash
./scripts/argocd-login.sh
```

### Step 2.5: Bootstrap Applications

```bash
# Deploy all applications via GitOps
kubectl apply -f argo-apps/install/03-bootstrap.yaml

# Wait for applications to appear
sleep 15

# Verify applications
kubectl get applications -n argocd
# Expected: grafana, prometheus, vault, web-app
```

**Using Makefile:**
```bash
make argo-bootstrap  # Deploys all applications
```

**✅ Phase 2 Complete**: ArgoCD installed and applications bootstrapped

## 📊 Phase 3: Applications Deployment

> **Note**: ArgoCD automatically deploys all applications defined in `argo-apps/install/03-bootstrap.yaml`. This includes Prometheus, Grafana, Vault, and the web application. All applications use **upstream Helm charts** (except web-app) with environment-specific values overrides.

### Step 3.1: Update Application Values for AWS

Before syncing, ensure applications use AWS-specific values:

```bash
# Edit each ArgoCD application manifest to use AWS values
vi argo-apps/apps/web-app.yaml
# Uncomment the values-aws.yaml line:
# helm:
#   valueFiles:
#     - values.yaml
#     - values-aws.yaml  # Uncomment this

# Repeat for prometheus, grafana, vault
```

Or use sed to update all at once:
```bash
# Uncomment values-aws.yaml in all application manifests
sed -i 's|# *- values-aws.yaml|- values-aws.yaml|g' argo-apps/apps/*.yaml
```

### Step 3.2: Monitor Application Sync

```bash
# Watch applications as they sync
watch kubectl get applications -n argocd

# Check sync status
kubectl get applications -n argocd -o wide
```

### Step 3.3: Wait for All Pods

```bash
# Check all pods are running
kubectl get pods -A

# Verify monitoring stack
kubectl get pods -n monitoring

# Verify web application
kubectl get pods -n production
```

**Using Makefile:**
```bash
make argo-sync     # Sync all applications
make status        # Check deployment status
```

## ✅ Final Verification

### System Health Check

```bash
# Check all applications
kubectl get applications -n argocd

# Check all pods
kubectl get pods -A | grep -v "Running\|Completed"

# Check node resources
kubectl top nodes
```

### Access All Services

```bash
# Get passwords
export ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
export GRAFANA_PASSWORD=$(kubectl get secret grafana-admin -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d)

# ArgoCD
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443 &
echo "ArgoCD: https://localhost:8080 (admin / $ARGOCD_PASSWORD)"

# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus -n monitoring 9090:9090 &
echo "Prometheus: http://localhost:9090"

# Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80 &
echo "Grafana: http://localhost:3000 (admin / $GRAFANA_PASSWORD)"

# Vault
kubectl port-forward svc/vault -n vault 8200:8200 &
echo "Vault: http://localhost:8200"

# Web Application
kubectl port-forward svc/k8s-web-app -n production 8081:80 &
echo "Web App: http://localhost:8081"
```

### Access All Services

```bash
# Get credentials
export ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

# ArgoCD (temporary - use ALB Ingress for production)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
echo "ArgoCD: https://localhost:8080 (admin / $ARGOCD_PASSWORD)"

# Prometheus
kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090 &
echo "Prometheus: http://localhost:9090"

# Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80 &
echo "Grafana: http://localhost:3000"

# Vault
kubectl port-forward svc/vault -n vault 8200:8200 &
echo "Vault: http://localhost:8200"

# Web App
kubectl port-forward svc/web-app -n production 8081:80 &
echo "Web App: http://localhost:8081"
```

**Using Makefile:**
```bash
make port-forward-argocd   # Quick access to ArgoCD
make port-forward-grafana  # Quick access to Grafana
```

## 🔧 Configuration Updates

### Update Application Configuration

```bash
# Edit AWS-specific values
vi helm-charts/web-app/values-aws.yaml

# Commit changes (ArgoCD auto-sync applies)
git add helm-charts/web-app/values-aws.yaml
git commit -m "Update web app AWS configuration"
git push

# Monitor sync
kubectl get application web-app -n argocd -w
```

### Scale Application

```bash
# View current HPA configuration
kubectl get hpa -n production

# Manual scaling (bypasses HPA)
kubectl scale deployment web-app -n production --replicas=5

# Update HPA for automatic scaling
vi helm-charts/web-app/values-aws.yaml
# Update autoscaling.minReplicas and maxReplicas
```

## 🚨 Troubleshooting

### ArgoCD Application Not Syncing

```bash
# Check application status
kubectl describe application web-app -n argocd

# View sync diff
kubectl get application web-app -n argocd -o yaml

# Force sync
kubectl patch application web-app -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

### Terraform Issues

**State Lock Errors**:
```bash
# Check DynamoDB lock table
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (use with caution)
cd terraform/environments/aws
terraform force-unlock <lock-id>
```

### Infrastructure Issues

**Nodes Not Ready**:
```bash
# Check node status
kubectl describe nodes

# Check EKS cluster
aws eks describe-cluster --name production-cluster --region us-west-2

# Check node group
aws eks describe-nodegroup \
  --cluster-name production-cluster \
  --nodegroup-name production-node-group \
  --region us-west-2
```

**For more troubleshooting**: See [Troubleshooting Guide](troubleshooting.md)

## 🧹 Cleanup

### Destroy Everything

```bash
# Delete all applications
kubectl delete -f argo-apps/install/03-bootstrap.yaml

# Wait for applications to be removed
sleep 30

# Delete ArgoCD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.0/manifests/install.yaml

# Delete namespaces
kubectl delete -f argo-apps/install/01-namespaces.yaml

# Destroy AWS infrastructure
cd terraform/environments/aws
terraform destroy -auto-approve
```

**Using Makefile:**
```bash
make destroy  # Destroy Terraform infrastructure
```

### Cleanup Specific Components

```bash
# Remove single application
kubectl delete application web-app -n argocd

# Remove monitoring stack
kubectl delete application prometheus -n argocd
kubectl delete application grafana -n argocd

# Remove vault
kubectl delete application vault -n argocd
```

## 📚 Additional Resources

### Documentation
- **[Architecture Guide](architecture.md)** - Repository structure and GitOps flow
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions
- **[ArgoCD CLI Setup](argocd-cli-setup.md)** - Cross-platform ArgoCD CLI
- **[Scripts Documentation](scripts.md)** - Detailed script usage
- **[CI/CD Pipeline](ci_cd_pipeline.md)** - GitHub Actions automation
- **[Vault Setup Guide](vault-setup.md)** - Vault integration details

### Makefile Commands

```bash
# Show all available commands
make help

# Common AWS deployment commands
make deploy-aws              # Full automated AWS deployment
make deploy-infra ENV=prod   # Deploy infrastructure only
make deploy-bootstrap ENV=prod # Bootstrap ArgoCD
make validate-all            # Validate everything
make version                 # Show version information
```

### GitHub Actions CI/CD

This repository includes automated workflows for:
- **Validation**: YAML, Helm, Terraform syntax on every PR
- **Documentation**: Link checking and markdown linting
- **Terraform Plan**: Automatic plan comments on PRs
- **Terraform Apply**: Automated deployment on merge to main
- **ArgoCD Deploy**: Application sync on changes
- **Security Scan**: Weekly security scans and vulnerability checks

See [CI/CD Pipeline Documentation](ci_cd_pipeline.md) for details.

### Helm Chart Information

This repository uses **upstream Helm charts** with local values overrides:
- **Prometheus**: prometheus-community/kube-prometheus-stack (values in `helm-charts/prometheus/`)
- **Grafana**: grafana/grafana (values in `helm-charts/grafana/`)
- **Vault**: hashicorp/vault (values in `helm-charts/vault/`)
- **Web App**: Custom chart (complete chart in `helm-charts/web-app/`)

Only values files are maintained locally - no chart duplication.

## 📝 Next Steps

1. **Configure ALB Ingress Controller**: For production access without port-forwarding
2. **Set up Route53 DNS**: Point domains to application load balancers
3. **Enable GitHub Actions**: Configure secrets and enable CI/CD workflows
4. **Configure Monitoring Alerts**: Set up AlertManager rules
5. **Implement Backup Strategy**: Automated backups for Vault and etcd
6. **Security Hardening**: Review and implement additional security measures

---

**Next Steps**: See [Troubleshooting Guide](troubleshooting.md) for common issues and [Architecture Guide](architecture.md) for understanding the repository structure.
