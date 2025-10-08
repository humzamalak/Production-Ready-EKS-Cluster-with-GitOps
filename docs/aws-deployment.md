# AWS Deployment Guide

> Compatibility: Kubernetes v1.33.0 (EKS cluster version 1.33)

Complete guide for deploying this GitOps repository on **AWS EKS** for production environments.

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

## 🚀 Phase 1: AWS Infrastructure

### Step 1.1: Clone Repository

```bash
git clone https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps.git
cd Production-Ready-EKS-Cluster-with-GitOps
```

### Step 1.2: Configure Terraform

```bash
cd infrastructure/terraform

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
project_prefix = "my-eks-cluster"
environment    = "prod"
aws_region     = "us-west-2"

# EKS Configuration (Kubernetes v1.33.0)
cluster_version = "1.33"
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
terraform plan -var-file="terraform.tfvars"

# Apply (takes 15-20 minutes)
terraform apply -var-file="terraform.tfvars" -auto-approve

# Save outputs
terraform output > ../infrastructure-outputs.txt
```

### Step 1.4: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --region $(terraform output -raw aws_region) \
  --name $(terraform output -raw cluster_name)
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

## 🔧 Phase 2: Bootstrap (GitOps Foundation)

### Step 2.1: Update Repository URL

```bash
# Navigate back to repo root
cd ../..

# Update repo URL in all manifests (replace with your fork)
# For Linux/Mac:
find environments/ applications/ bootstrap/ -name "*.yaml" -type f -exec sed -i 's|https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps|https://github.com/YOUR-ORG/YOUR-REPO|g' {} \;

# For macOS (requires '' after -i):
# find environments/ applications/ bootstrap/ -name "*.yaml" -type f -exec sed -i '' 's|https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps|https://github.com/YOUR-ORG/YOUR-REPO|g' {} \;
```

> **Note**: If you're using the repository directly without forking, you can skip this step. ArgoCD will pull from the main repository.

### Step 2.2: Deploy Core Components

```bash
# Apply in order (critical for dependencies)
kubectl apply -f bootstrap/00-namespaces.yaml
kubectl apply -f bootstrap/01-pod-security-standards.yaml
kubectl apply -f bootstrap/02-network-policy.yaml
kubectl apply -f bootstrap/03-helm-repos.yaml
```

### Step 2.3: Install ArgoCD

```bash
# Ensure namespace exists and is ready
kubectl get ns argocd >/dev/null 2>&1 || kubectl create ns argocd
kubectl wait --for=condition=ready ns/argocd --timeout=60s

# Add ArgoCD Helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
helm upgrade --install argo-cd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values bootstrap/helm-values/argo-cd-values.yaml \
  --wait --timeout=10m
```

> **Note**: ArgoCD will auto-generate a random admin password and store it in the `argocd-initial-admin-secret` secret on first installation.

### Step 2.4: Create Monitoring Secrets

```bash
# Create monitoring secrets before deploying apps
./scripts/secrets.sh create monitoring
```

### Step 2.5: Deploy ArgoCD Projects via GitOps

```bash
# Deploy the projects bootstrap Application (manages all AppProjects via GitOps)
kubectl apply -f bootstrap/05-argocd-projects.yaml

# Wait for projects to be synced (ArgoCD will create prod-apps and staging-apps)
sleep 15

# Verify project creation
kubectl get appprojects -n argocd
# Expected output:
#   NAME           AGE
#   default        Xm
#   prod-apps      Xs
#   staging-apps   Xs
```

> **✅ What Changed**: AppProjects are now managed by Argo CD via GitOps (from `bootstrap/projects/`), eliminating manual kubectl apply steps.

### Step 2.6: Access ArgoCD UI

```bash
# Get auto-generated admin password
export ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"

# Port forward to access UI
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443 &
echo "ArgoCD: https://localhost:8080"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
```

### Step 2.7: Deploy Root Application

```bash
# Deploy the root app-of-apps
kubectl apply -f environments/prod/app-of-apps.yaml

# Wait for root app to sync
kubectl wait --for=condition=Synced --timeout=300s \
  application/prod-cluster -n argocd

# Verify child applications are discovered
# You should see: prometheus-prod, grafana-prod, k8s-web-app-prod
kubectl get applications -n argocd
```

**✅ Phase 2 Complete**: ArgoCD installed, root application synced

## 📊 Phase 3: Monitoring Stack

### Step 3.1: Wait for Monitoring Deployment

```bash
# Wait for Prometheus to deploy
kubectl wait --for=condition=Synced --timeout=600s \
  application/prometheus-prod -n argocd

# Wait for Grafana to deploy
kubectl wait --for=condition=Synced --timeout=600s \
  application/grafana-prod -n argocd

# Check monitoring pods
kubectl get pods -n monitoring
```

### Step 3.2: Access Monitoring Services

```bash
# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus \
  -n monitoring 9090:9090 &
echo "Prometheus: http://localhost:9090"

# Grafana
export GRAFANA_PASSWORD=$(kubectl get secret grafana-admin -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d)
kubectl port-forward svc/grafana -n monitoring 3000:80 &
echo "Grafana: http://localhost:3000 (admin / $GRAFANA_PASSWORD)"
```

### Step 3.3: Verify Monitoring

```bash
# Check ServiceMonitors
kubectl get servicemonitors -n monitoring

# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'
```

**✅ Phase 3 Complete**: Monitoring stack deployed and collecting metrics

## 🔒 Phase 4: Vault Deployment (Optional)

> **⚠️ Important**: Vault is currently disabled in this repository. The `vault` namespace is commented out in `bootstrap/00-namespaces.yaml`. To enable Vault, uncomment the vault namespace section and create a separate Vault Application manifest in `environments/prod/apps/`.

> **💡 Skip This Phase**: Vault integration is not yet implemented. Proceed to Phase 6 to deploy the web application without Vault secrets.

### Step 4.1: Wait for Vault Deployment (Not Currently Available)

```bash
# Note: Vault is not currently deployed via ArgoCD in this repository
# If you manually deploy Vault, you can check the pods with:
# kubectl get pods -n vault
```

### Step 4.2: Port Forward to Vault

```bash
# Set up port forward
kubectl port-forward svc/vault -n vault 8200:8200 &
export VAULT_ADDR="http://localhost:8200"
```

**✅ Phase 4 Complete**: Vault deployed and accessible

## 🔧 Phase 5: Vault Configuration (Optional)

> **⚠️ Prerequisites**: Phase 4 must be complete.

### Step 5.1: Initialize Vault

```bash
# Initialize Vault (SAVE THE OUTPUT!)
vault operator init -key-shares=1 -key-threshold=1 > vault-keys.txt

# Extract credentials
export VAULT_TOKEN=$(grep 'Initial Root Token:' vault-keys.txt | awk '{print $NF}')
export VAULT_UNSEAL_KEY=$(grep 'Unseal Key 1:' vault-keys.txt | awk '{print $NF}')

echo "Root Token: $VAULT_TOKEN"
echo "Unseal Key: $VAULT_UNSEAL_KEY"

# ⚠️ IMPORTANT: Backup vault-keys.txt securely
```

### Step 5.2: Unseal and Configure Vault

```bash
# Unseal Vault
vault operator unseal $VAULT_UNSEAL_KEY

# Enable secrets engine
vault secrets enable -path=secret kv-v2

# Enable Kubernetes authentication
vault auth enable kubernetes
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc.cluster.local"
```

### Step 5.3: Create Policies and Secrets

```bash
# Create web app policy
vault policy write k8s-web-app - <<EOF
path "secret/data/production/web-app/*" {
  capabilities = ["read"]
}
path "secret/metadata/production/web-app/*" {
  capabilities = ["read", "list"]
}
path "auth/kubernetes/login" {
  capabilities = ["create", "update"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

# Create Kubernetes role
vault write auth/kubernetes/role/k8s-web-app \
  bound_service_account_names=k8s-web-app \
  bound_service_account_namespaces=production \
  policies=k8s-web-app \
  ttl=1h \
  max_ttl=24h

# Create application secrets
vault kv put secret/production/web-app/db \
  host="your-production-db.amazonaws.com" \
  port="5432" \
  name="k8s_web_app_prod" \
  username="k8s_web_app_user" \
  password="$(openssl rand -base64 32)"

vault kv put secret/production/web-app/api \
  jwt_secret="$(openssl rand -base64 64)" \
  encryption_key="$(openssl rand -base64 32)" \
  api_key="$(openssl rand -base64 32)"
```

**✅ Phase 5 Complete**: Vault configured with policies and secrets

## 🌐 Phase 6: Web Application Deployment

### Step 6.1: Deploy Web Application

```bash
# Wait for app to sync (using values without Vault secrets)
kubectl wait --for=condition=Synced --timeout=600s \
  application/k8s-web-app-prod -n argocd

# Check pods
kubectl get pods -n production
```

### Step 6.2: Access the Web Application

```bash
# Option A: Ingress (recommended in production)
kubectl get ingress k8s-web-app -n production
# Point DNS to the address and browse to the host

# Option B: Port-forward (quick test)
kubectl port-forward svc/k8s-web-app -n production 8081:80 &
echo "Web App: http://localhost:8081"

# Test application
curl -s http://localhost:8081/health
```

**✅ Phase 6 Complete**: Web application deployed and accessible

## 🔐 Phase 7: Vault Integration (Optional)

> **⚠️ Prerequisites**: Phases 4, 5, and 6 must be complete.

### Step 7.1: Enable Vault in Web App

```bash
# Edit the production values file to enable Vault, then commit
vi applications/web-app/k8s-web-app/values.yaml
# Set:
# vault:
#   enabled: true
#   ready: true

git add applications/web-app/k8s-web-app/values.yaml
git commit -m "Enable Vault for web app (prod)"
git push

# Argo CD will reconcile automatically; verify status
kubectl get applications -n argocd
```

### Step 7.2: Verify Vault Integration

```bash
# Check pod has 2 containers now (app + vault-agent)
kubectl get pods -n production -l app.kubernetes.io/name=k8s-web-app \
  -o jsonpath='{.items[0].spec.containers[*].name}'

# Check secrets are injected
kubectl exec -n production deployment/k8s-web-app -- ls -la /vault/secrets/

# Test application still works
curl -s http://localhost:8081/health
```

**✅ Phase 7 Complete**: Vault integration enabled and working

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

## 🔧 Configuration Updates

### Update Application Configuration

```bash
# Edit production values
vi applications/web-app/k8s-web-app/values.yaml

# Commit changes (Argo CD auto-sync applies)
git add applications/web-app/k8s-web-app/values.yaml
git commit -m "Update application configuration"
git push
```

### Scale Application

```bash
# Manual scaling
kubectl scale deployment k8s-web-app -n production --replicas=5

# Or update HPA
kubectl patch hpa k8s-web-app -n production --patch '{"spec":{"maxReplicas":30}}'
```

## 🚨 Troubleshooting

### Common Issues

#### ArgoCD Application Sync Errors

**Secret Reference Errors**:
```bash
# Check application configuration
kubectl get application k8s-web-app-prod -n argocd -o yaml

# Force refresh
kubectl patch application k8s-web-app-prod -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

#### Vault Issues

**Vault Not Unsealed**:
```bash
# Check status
vault status

# Unseal if needed
vault operator unseal $VAULT_UNSEAL_KEY
```

**Authentication Failures**:
```bash
# Check service account
kubectl get sa k8s-web-app -n production -o yaml

# Verify Vault role
vault read auth/kubernetes/role/k8s-web-app
```

### Infrastructure Issues

**Nodes Not Ready**:
```bash
# Check node status
kubectl describe nodes

# Check EKS cluster
aws eks describe-cluster --name $(terraform output -raw cluster_name) --region $(terraform output -raw aws_region)
```

## 🧹 Cleanup

### Destroy Everything

```bash
# Delete applications
kubectl delete -f environments/prod/app-of-apps.yaml

# Delete ArgoCD
helm uninstall argo-cd -n argocd

# Delete namespaces
kubectl delete namespace argocd monitoring vault production

# Destroy infrastructure
cd infrastructure/terraform
terraform destroy -var-file="terraform.tfvars" -auto-approve
```

### Cleanup Specific Components

```bash
# Remove application only
kubectl delete application k8s-web-app-prod -n argocd

# Remove Prometheus
kubectl delete application prometheus-prod -n argocd

# Remove Grafana
kubectl delete application grafana-prod -n argocd
```

## 🔐 Adding Vault Later

If you skipped Phases 4-5-7 and want to add Vault later:

### Prerequisites
Your deployment should have:
- ✅ Infrastructure (Phase 1)
- ✅ ArgoCD (Phase 2)
- ✅ Monitoring (Phase 3)
- ✅ Web App running without secrets (Phase 6)

### Steps
1. **Deploy Vault**: The security-stack should auto-appear from your root app
2. **Configure Vault**: Follow Phase 5 steps to initialize and configure
3. **Enable Vault in Web App**: Follow Phase 7 steps to integrate

## 📚 Next Steps

1. **Configure SSL/TLS**: Set up cert-manager for automatic certificate management
2. **Set up CI/CD**: Integrate with GitHub Actions for automated deployments
3. **Configure Backups**: Set up automated backups for etcd and Vault
4. **Set up Alerts**: Configure AlertManager rules for production monitoring
5. **Security Hardening**: Review and implement security best practices
6. **Add More Applications**: Deploy additional services using the same pattern

---

**Next Steps**: See [Troubleshooting Guide](troubleshooting.md) for common issues and [Architecture Guide](architecture.md) for understanding the repository structure.
