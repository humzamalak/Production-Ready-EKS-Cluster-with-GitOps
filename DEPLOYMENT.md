# 🚀 Production-Ready EKS Cluster Deployment Guide

**Updated**: 2025-10-08  
**Version**: 2.0 (Refactored Structure)

This guide provides step-by-step instructions for deploying the GitOps stack on both Minikube (local development) and AWS EKS (production).

---

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Minikube Deployment](#minikube-deployment)
- [AWS EKS Deployment](#aws-eks-deployment)
- [Accessing Applications](#accessing-applications)
- [Troubleshooting](#troubleshooting)

---

## ⚡ Quick Start

### Automated Deployment

**Minikube (Local)**:
```bash
./scripts/setup-minikube.sh
```

**AWS EKS (Production)**:
```bash
./scripts/setup-aws.sh
```

### Manual Deployment

Follow the detailed sections below for step-by-step manual deployment.

---

## 🏠 Minikube Deployment

### Prerequisites

- Minikube installed
- kubectl installed (v1.33+)
- Helm installed (v3+)
- Docker installed
- 8GB RAM available

### Step 1: Start Minikube

```bash
# Start Minikube with recommended resources
minikube start --cpus=4 --memory=8192 --disk-size=20g

# Enable required addons
minikube addons enable ingress
minikube addons enable metrics-server
```

### Step 2: Create Namespaces

```bash
# Create all required namespaces
kubectl apply -f argocd/install/01-namespaces.yaml

# Verify namespaces
kubectl get namespaces
# Expected: argocd, monitoring, production, vault
```

### Step 3: Install ArgoCD

```bash
# Apply ArgoCD installation manifest
kubectl apply -f argocd/install/02-argocd-install.yaml

# Wait for ArgoCD to be ready (2-3 minutes)
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get ArgoCD admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"
```

### Step 4: Bootstrap GitOps

```bash
# Deploy projects and root app
kubectl apply -f argocd/install/03-bootstrap.yaml

# Wait for applications to sync
sleep 30

# Check application status
kubectl get applications -n argocd
```

### Step 5: Configure for Minikube

To use Minikube-specific values, update the ArgoCD Application manifests:

**For Web App**:
Edit `argocd/apps/web-app.yaml` and uncomment the Minikube values file:
```yaml
helm:
  valueFiles:
    - values.yaml
    - values-minikube.yaml  # <-- Uncomment this line
```

**For Prometheus, Grafana, and Vault**:
Similarly, uncomment `values-minikube.yaml` in their respective Application manifests.

Then sync the applications:
```bash
# Using ArgoCD CLI
argocd app sync root-app --force

# Or wait for auto-sync (2-3 minutes)
```

### Step 6: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -A

# Check ArgoCD applications
kubectl get applications -n argocd

# All apps should show Status: Synced, Health: Healthy
```

---

## ☁️ AWS EKS Deployment

### Prerequisites

- AWS CLI configured
- Terraform installed (v1.5+)
- kubectl installed (v1.33+)
- Helm installed (v3+)
- AWS account with appropriate permissions

### Step 1: Provision Infrastructure

```bash
# Navigate to Terraform directory
cd infrastructure/terraform

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# - AWS region
# - Cluster name
# - VPC CIDR
# - etc.

# Initialize Terraform
terraform init

# Plan infrastructure
terraform plan -out=tfplan

# Apply infrastructure (creates VPC, EKS cluster, IAM roles)
terraform apply tfplan

# This will take 15-20 minutes
```

### Step 2: Configure kubectl

```bash
# Update kubeconfig for new EKS cluster
aws eks update-kubeconfig \
  --name production-cluster \
  --region us-east-1

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Step 3: Deploy ArgoCD

```bash
# Navigate back to repository root
cd ../..

# Create namespaces
kubectl apply -f argocd/install/01-namespaces.yaml

# Install ArgoCD
kubectl apply -f argocd/install/02-argocd-install.yaml

# Wait for ArgoCD (3-5 minutes for AWS)
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# Get admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"
echo "Save this password securely!"
```

### Step 4: Bootstrap Applications

```bash
# Deploy projects and root app
kubectl apply -f argocd/install/03-bootstrap.yaml

# Applications will auto-sync
```

### Step 5: Configure for AWS

Update ArgoCD Application manifests to use AWS-specific values:

**For each application** (`web-app`, `prometheus`, `grafana`, `vault`):
1. Edit `argocd/apps/<app>.yaml`
2. Uncomment the AWS values file:
   ```yaml
   helm:
     valueFiles:
       - values.yaml
       - values-aws.yaml  # <-- Uncomment this line
   ```

Then sync:
```bash
argocd app sync root-app --force
```

### Step 6: Configure AWS Load Balancer Controller

```bash
# Install AWS Load Balancer Controller
# Follow AWS documentation:
# https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

# After installation, ALB Ingress will work for web-app
```

### Step 7: Update Ingress with Domain

Edit `apps/web-app/values-aws.yaml` and configure:
- Your domain name
- ACM certificate ARN

```yaml
ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:REGION:ACCOUNT:certificate/CERT-ID"
  hosts:
    - host: app.yourdomain.com
```

Commit and push changes. ArgoCD will auto-sync.

---

## 🔐 Accessing Applications

### ArgoCD

**Port Forward**:
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

**Access**: https://localhost:8080  
**Username**: `admin`  
**Password**: Retrieved from secret (see deployment steps above)

### Prometheus

**Port Forward**:
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

**Access**: http://localhost:9090

### Grafana

**Port Forward**:
```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
```

**Access**: http://localhost:3000  
**Username**: `admin`  
**Password**: `admin` (default, change in production)

### Vault

**Port Forward**:
```bash
kubectl port-forward -n vault svc/vault 8200:8200
```

**Access**: http://localhost:8200  
**Token**: `root` (dev mode) or initialize Vault for production

### Web Application

**Minikube**:
```bash
minikube service -n production web-app
```

**AWS** (with ALB configured):
Access via configured domain (e.g., `https://app.yourdomain.com`)

---

## 🔧 Troubleshooting

### ArgoCD Not Syncing

```bash
# Check application status
argocd app get root-app

# Check for sync errors
argocd app sync root-app --dry-run

# Force sync
argocd app sync root-app --force
```

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -A

# Describe problematic pod
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>
```

### Out of Sync Applications

```bash
# View diff
argocd app diff <app-name>

# Sync specific app
argocd app sync <app-name>

# Refresh app
argocd app get <app-name> --refresh
```

### Helm Chart Errors

```bash
# Lint web-app chart
helm lint apps/web-app

# Template render test
helm template web-app apps/web-app --values apps/web-app/values.yaml
```

---

## 📚 Additional Resources

- **Architecture**: See [docs/architecture.md](docs/architecture.md)
- **Troubleshooting Guide**: See [docs/troubleshooting.md](docs/troubleshooting.md)
- **Kubernetes Version Policy**: See [docs/K8S_VERSION_POLICY.md](docs/K8S_VERSION_POLICY.md)

---

## 🆘 Support

For issues and questions:
1. Check the troubleshooting guide
2. Review ArgoCD logs: `kubectl logs -n argocd deployment/argocd-server`
3. Open a GitHub issue with details

---

**Repository Structure**:
```
argocd/
  install/       # ArgoCD installation manifests
  projects/      # ArgoCD Projects
  apps/          # ArgoCD Applications

apps/
  web-app/       # Web app Helm chart
  prometheus/    # Prometheus values
  grafana/       # Grafana values
  vault/         # Vault values

infrastructure/
  terraform/     # AWS EKS infrastructure

scripts/
  setup-minikube.sh  # Automated Minikube deployment
  setup-aws.sh       # Automated AWS deployment
  deploy.sh          # Unified deployment interface
  validate.sh        # Validation script
  secrets.sh         # Secrets management
```

**Key Differences from Previous Version**:
- ✅ No `bootstrap/` directory - moved to `argocd/install/`
- ✅ No `environments/` directory - values in `apps/*/values-*.yaml`
- ✅ No `examples/` directory - using pre-built Docker image
- ✅ Simplified structure with clear separation of concerns
- ✅ Environment switching via value file selection

