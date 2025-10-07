# Local Deployment Guide

> Compatibility: Kubernetes v1.33.0 (Minikube or compatible local cluster)

Complete guide for deploying this GitOps repository on **Minikube** or similar local Kubernetes clusters.

## 🎯 Overview

This deployment follows a **7-phase approach** optimized for local development:

| Phase | Component | Duration | Optional |
|-------|-----------|----------|----------|
| **Phase 1** | Local Infrastructure | 5 min | Required |
| **Phase 2** | Bootstrap | 5-10 min | Required |
| **Phase 3** | Monitoring | 5 min | Required |
| **Phase 4** | Vault Deployment | 5 min | ⚠️ **Optional** |
| **Phase 5** | Vault Configuration | 10 min | ⚠️ **Optional** |
| **Phase 6** | Web App Deployment | 5 min | Required |
| **Phase 7** | Vault Integration | 10 min | ⚠️ **Optional** |

**Total Time**: ~25 minutes (without Vault) or ~45 minutes (with Vault)

## 📋 Prerequisites

### System Requirements
- **RAM**: 4GB minimum, 8GB recommended
- **CPU**: 2 cores minimum, 4 cores recommended
- **Storage**: 30GB free disk space

### Required Tools

```bash
# macOS installation
brew install minikube kubectl helm vault

# Linux installation
# Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# kubectl v1.33+
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Vault CLI
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault
```

## 🚀 Phase 1: Local Infrastructure

### Step 1.1: Start Minikube

```bash
# Start Minikube with optimized resources
minikube start \
  --memory=4096 \
  --cpus=2 \
  --disk-size=30g \
  --driver=docker \
  --kubernetes-version=v1.33.0
```

### Step 1.2: Enable Required Addons

```bash
# Enable essential addons
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable storage-provisioner
minikube addons enable default-storageclass
```

### Step 1.3: Build Application Image

```bash
# Navigate to example app
cd examples/web-app

# Build Docker image (use Minikube's Docker daemon)
eval $(minikube docker-env)
docker build -t k8s-web-app:latest .

# Navigate back to root
cd ../..

```

**✅ Phase 1 Complete**: Minikube running, addons enabled, application image built

## 🔧 Phase 2: Bootstrap (GitOps Foundation)

### Step 2.1: Deploy Core Components

```bash
# Apply in order (critical for dependencies)
kubectl apply -f bootstrap/00-namespaces.yaml
kubectl apply -f bootstrap/01-pod-security-standards.yaml
kubectl apply -f bootstrap/02-network-policy.yaml
kubectl apply -f bootstrap/03-helm-repos.yaml
```

### Step 2.2: Install ArgoCD

```bash
# Ensure namespace exists and is ready
kubectl get ns argocd >/dev/null 2>&1 || kubectl create ns argocd
kubectl wait --for=condition=ready ns/argocd --timeout=60s

# Add ArgoCD Helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD with local-optimized values
helm upgrade --install argo-cd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values bootstrap/helm-values/argo-cd-values.yaml \
  --set server.resources.requests.cpu=50m \
  --set server.resources.requests.memory=128Mi \
  --wait --timeout=10m
```

> **Note**: ArgoCD will auto-generate a random admin password and store it in the `argocd-initial-admin-secret` secret on first installation.

### Step 2.3: Create Required Secrets

```bash
# Create monitoring secrets (consolidated secrets script)
./scripts/secrets.sh create monitoring
```

### Step 2.4: Access ArgoCD UI

```bash
# Get auto-generated admin password
export ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"

# Port forward to access UI
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443 &
echo "ArgoCD UI: https://localhost:8080"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
```

### Step 2.5: Deploy Root Application (dev)

```bash
# Deploy the root app-of-apps for the dev environment
kubectl apply -f environments/dev/app-of-apps.yaml

# Verify discovery (view apps in Argo CD)
kubectl get applications -n argocd
```

## 📊 Phase 3: Monitoring Stack

### Step 3.1: Wait for Monitoring Deployment

```bash
# Wait for monitoring stack to deploy
kubectl wait --for=condition=Synced --timeout=600s \
  application/monitoring-stack -n argocd

# Check pods
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

**✅ Phase 3 Complete**: Monitoring stack deployed and accessible

## 🔒 Phase 4: Vault Deployment (Optional)

> **💡 Skip This Phase If**: You want to deploy just monitoring and web app first.

### Step 4.1: Wait for Vault Deployment

```bash
# Wait for Vault deployment
kubectl wait --for=condition=Synced --timeout=600s \
  application/security-stack -n argocd

# Check Vault pods
kubectl get pods -n vault
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
# Initialize Vault with single key for local development
vault operator init -key-shares=1 -key-threshold=1 > vault-keys-local.txt

# Extract credentials
export VAULT_TOKEN=$(grep 'Initial Root Token:' vault-keys-local.txt | awk '{print $NF}')
export VAULT_UNSEAL_KEY=$(grep 'Unseal Key 1:' vault-keys-local.txt | awk '{print $NF}')

# Save for later use
echo "export VAULT_TOKEN=$VAULT_TOKEN" >> ~/.vault-local-env
echo "export VAULT_UNSEAL_KEY=$VAULT_UNSEAL_KEY" >> ~/.vault-local-env
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
  kubernetes_host="https://$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}' | sed 's|https://||')" \
  kubernetes_ca_cert="$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d)" \
  token_reviewer_jwt="$(kubectl get secret -n vault $(kubectl get sa vault -n vault -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d)"
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
  host="localhost" \
  port="5432" \
  name="k8s_web_app_dev" \
  username="dev_user" \
  password="dev_password_123"

vault kv put secret/production/web-app/api \
  jwt_secret="dev-jwt-secret-$(openssl rand -hex 16)" \
  encryption_key="dev-encryption-key-$(openssl rand -hex 16)" \
  api_key="dev-api-key-$(openssl rand -hex 8)"
```

**✅ Phase 5 Complete**: Vault configured with policies and secrets

## 🌐 Phase 6: Web Application Deployment

### Step 6.1: Deploy Web Application

```bash
# Wait for app to sync (using values without Vault secrets)
kubectl wait --for=condition=Synced --timeout=600s \
  application/k8s-web-app -n argocd

# Check pods
kubectl get pods -n production
```

### Step 6.2: Access the Web Application

```bash
# Port-forward to web app
kubectl port-forward svc/k8s-web-app -n production 8081:80 &
echo "Web App: http://localhost:8081"

# Test application
curl -s http://localhost:8081/health
```

**✅ Phase 6 Complete**: Web application deployed and accessible

## 🔐 Phase 7: Vault Integration (Optional)

> ⚠️ Prerequisites: Vault is deployed and initialized.

### Step 7.1: Enable Vault in Web App

```bash
# Toggle Vault in the chart values and commit
vi applications/web-app/k8s-web-app/helm/values.yaml
# Set:
# vault:
#   enabled: true
#   ready: true

git add applications/web-app/k8s-web-app/helm/values.yaml
git commit -m "Enable Vault for web app (local)"
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

# Verify web app has correct number of containers
kubectl get pods -n production -l app.kubernetes.io/name=k8s-web-app
```

### Access All Services

```bash
# Stop any existing port-forwards
pkill -f "kubectl port-forward"

# Get passwords
export ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
export GRAFANA_PASSWORD=$(kubectl get secret grafana-admin -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d)

# Start all port-forwards
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus -n monitoring 9090:9090 > /dev/null 2>&1 &
kubectl port-forward svc/grafana -n monitoring 3000:80 > /dev/null 2>&1 &
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &
kubectl port-forward svc/k8s-web-app -n production 8081:80 > /dev/null 2>&1 &

echo "✅ All services accessible:"
echo "   ArgoCD:      https://localhost:8080 (admin / $ARGOCD_PASSWORD)"
echo "   Prometheus:  http://localhost:9090"
echo "   Grafana:     http://localhost:3000 (admin / $GRAFANA_PASSWORD)"
echo "   Vault:       http://localhost:8200"
echo "   Web App:     http://localhost:8081"
```

## 🚨 Troubleshooting

### Common Issues

#### Minikube Not Starting
```bash
# Check status and logs
minikube status
minikube logs

# Try recreating
minikube delete
minikube start --memory=4096 --cpus=2 --disk-size=30g --driver=docker
```

#### Out of Resources
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A

# Reduce monitoring resources or stop temporarily
kubectl scale statefulset prometheus-kube-prometheus-stack-prometheus -n monitoring --replicas=0
```

#### Vault Sealed After Restart
```bash
# Load keys and unseal
source ~/.vault-local-env
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &
vault operator unseal $VAULT_UNSEAL_KEY
```

## 🧹 Cleanup

### Full Cleanup
```bash
# Delete Minikube cluster
minikube delete

# Remove local files
rm -f vault-keys-local.txt
rm -f ~/.vault-local-env
```

### Partial Cleanup (Keep Minikube)
```bash
# Delete applications
kubectl delete -f environments/prod/app-of-apps.yaml

# Delete ArgoCD
helm uninstall argo-cd -n argocd

# Delete namespaces
kubectl delete namespace argocd monitoring vault production
```

## 🔧 Daily Operations

### Starting Your Environment
```bash
# Start Minikube
minikube start

# Unseal Vault (if using Vault)
source ~/.vault-local-env
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &
vault operator unseal $VAULT_UNSEAL_KEY

# Start port forwards (create a script with the port-forward commands above)
```

### Updating Application
```bash
# Rebuild image
cd examples/web-app
eval $(minikube docker-env)
docker build -t k8s-web-app:latest .

# Restart deployment
kubectl rollout restart deployment k8s-web-app -n production
```

---

**Next Steps**: See [Troubleshooting Guide](troubleshooting.md) for common issues and [Architecture Guide](architecture.md) for understanding the repository structure.
