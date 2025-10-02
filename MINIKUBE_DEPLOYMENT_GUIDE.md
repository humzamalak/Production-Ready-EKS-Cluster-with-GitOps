# Minikube Local Development Deployment Guide

Complete local development deployment guide for Minikube with GitOps, using a **phase-based approach** optimized for local development with limited resources.

> **⚠️ Critical**: Follow each phase in order. **Do not skip verification steps**. Each phase must complete successfully before moving to the next.

## 🎯 Overview

This deployment follows a **7-phase approach** optimized for local development:

| Phase | Component | Purpose | Duration | Optional |
|-------|-----------|---------|----------|----------|
| **Phase 1** | Local Infrastructure | Minikube cluster, addons | 5 min | Required |
| **Phase 2** | Bootstrap | ArgoCD, namespaces, policies | 5-10 min | Required |
| **Phase 3** | Monitoring | Prometheus, Grafana (optimized) | 5 min | Required |
| **Phase 4** | Vault Deployment | Vault server, agent injector | 5 min | ⚠️ **Optional** |
| **Phase 5** | Vault Configuration | Initialize, policies, secrets | 10 min | ⚠️ **Optional** |
| **Phase 6** | Web App Deployment | Deploy app WITHOUT secrets | 5 min | Required |
| **Phase 7** | Vault Integration | Add Vault secrets to web app | 10 min | ⚠️ **Optional** |

**Total Time**: 
- **Without Vault**: ~25 minutes (Phases 1-3, 6)
- **With Vault**: ~45 minutes (All phases)

> **💡 Note:** Phases 4-5-7 (Vault) are optional. You can deploy Prometheus, Grafana, and your web app without Vault, then add Vault later when you need secret management. See [Adding Vault Later](#adding-vault-later-optional) section.

---

## 📋 Prerequisites

### System Requirements

- **RAM**: 4GB minimum, 8GB recommended
- **CPU**: 2 cores minimum, 4 cores recommended
- **Storage**: 30GB free disk space
- **OS**: macOS 10.15+, Ubuntu 18.04+, Windows 10/11 with WSL2

### Required Tools

```bash
# macOS installation
brew install minikube kubectl helm

# Linux installation
# Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Vault CLI
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/vault

# Linux
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault

# Verify installations
minikube version
kubectl version --client
helm version
vault version
```

---

## 🚀 Phase 1: Local Infrastructure

### Step 1.1: Start Minikube

```bash
# Start Minikube with optimized resources for local development
minikube start \
  --memory=4096 \
  --cpus=2 \
  --disk-size=30g \
  --driver=docker \
  --kubernetes-version=v1.33.0

# This takes 2-3 minutes on first run
```

### Step 1.2: Enable Required Addons

```bash
# Enable essential addons
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable storage-provisioner
minikube addons enable default-storageclass

# Verify addons
minikube addons list | grep enabled
```

### Step 1.3: Verify Cluster

```bash
# Check cluster status
minikube status
# Expected: host, kubelet, apiserver all Running

# Check nodes
kubectl get nodes
# Expected: 1 node in Ready state (Kubernetes v1.33.0)

# Check system pods
kubectl get pods -n kube-system
# Expected: All Running

# Check storage class
kubectl get storageclass
# Expected: standard (default)
```

### Step 1.4: Clone Repository

```bash
# Clone repository
git clone https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps.git
cd Production-Ready-EKS-Cluster-with-GitOps
```

### Step 1.5: Build and Load Application Image

```bash
# Navigate to example app
cd examples/web-app

# Build Docker image (use Minikube's Docker daemon)
eval $(minikube docker-env)
docker build -t k8s-web-app:latest .

# Verify image is built
docker images | grep k8s-web-app

# Navigate back to root
cd ../..
```

**✅ Phase 1 Complete Checklist:**
- [ ] Minikube running
- [ ] All addons enabled
- [ ] Node in Ready state
- [ ] Application image built and loaded
- [ ] kubectl commands work

**⚠️ STOP**: Do not proceed until all checks pass.

---

## 🔧 Phase 2: Bootstrap (GitOps Foundation)

### Step 2.1: Update Repository URL

```bash
# Update repo URL in all manifests (if using your fork)
# find clusters/ applications/ -name "*.yaml" -type f -exec sed -i '' 's|https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps|https://github.com/YOUR-ORG/YOUR-REPO|g' {} \;

# For local development, you can keep the original repo URL
```

### Step 2.2: Deploy Core Components

```bash
# Apply in order (critical for dependencies)
kubectl apply -f bootstrap/00-namespaces.yaml
kubectl apply -f bootstrap/01-pod-security-standards.yaml
kubectl apply -f bootstrap/02-network-policy.yaml
kubectl apply -f bootstrap/03-helm-repos.yaml

# Wait for namespaces to be created
kubectl get namespaces
# Expected: argocd, monitoring, vault, production
```

### Step 2.3: Install ArgoCD

```bash
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
  --set controller.resources.requests.cpu=100m \
  --set controller.resources.requests.memory=256Mi \
  --wait --timeout=10m

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=600s \
  deployment/argo-cd-argocd-server -n argocd
```

### Step 2.4: Access ArgoCD UI

```bash
# Get initial admin password
export ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"

# Port forward to access UI
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
echo "ArgoCD UI: https://localhost:8080 (admin / $ARGOCD_PASSWORD)"

# Give it a moment to start
sleep 3
```

### Step 2.5: Deploy Root Application

```bash
# Deploy the root app-of-apps
kubectl apply -f clusters/production/app-of-apps.yaml

# Wait for root app to sync
kubectl wait --for=condition=Synced --timeout=300s \
  application/production-cluster -n argocd
```

### Step 2.6: Verify Bootstrap

```bash
# Check ArgoCD applications
kubectl get applications -n argocd
# Expected: production-cluster, monitoring-stack, security-stack

# Check all namespaces
kubectl get namespaces | grep -E "argocd|monitoring|vault|production"

# Check ArgoCD pods
kubectl get pods -n argocd
# Expected: All Running
```

**✅ Phase 2 Complete Checklist:**
- [ ] All namespaces created
- [ ] ArgoCD UI accessible
- [ ] Root application synced
- [ ] All ArgoCD pods Running
- [ ] Applications discovered

**⚠️ STOP**: Do not proceed until all checks pass.

---

## 📊 Phase 3: Monitoring Stack (Optimized)

### Step 3.1: Apply Local Optimizations

```bash
# The monitoring stack will use local-optimized values automatically
# Check the values in applications/monitoring/*/values-local.yaml
```

### Step 3.2: Wait for Monitoring Deployment

```bash
# Monitor deployment (Wave 2)
echo "Waiting for monitoring stack to deploy..."
kubectl wait --for=condition=Synced --timeout=600s \
  application/monitoring-stack -n argocd

# Watch pods come up
kubectl get pods -n monitoring -w
# Wait for all pods to be Running (this may take 3-5 minutes)
# Press Ctrl+C when ready
```

### Step 3.3: Verify Monitoring Pods

```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# Expected pods (with reduced resource usage):
# - prometheus-kube-prometheus-stack-prometheus-0
# - prometheus-kube-prometheus-stack-operator-*
# - grafana-*

# Wait for Prometheus to be ready
kubectl wait --for=condition=ready --timeout=600s \
  pod -l app.kubernetes.io/name=prometheus -n monitoring
```

### Step 3.4: Access Prometheus

```bash
# Port forward to Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus \
  -n monitoring 9090:9090 > /dev/null 2>&1 &
echo "Prometheus UI: http://localhost:9090"

# Test Prometheus
sleep 3
curl -s http://localhost:9090/-/healthy
# Expected: Prometheus is Healthy
```

### Step 3.5: Access Grafana

```bash
# Get Grafana admin password
export GRAFANA_PASSWORD=$(kubectl get secret grafana-admin -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d)
echo "Grafana Password: $GRAFANA_PASSWORD"

# Port forward to Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80 > /dev/null 2>&1 &
echo "Grafana UI: http://localhost:3000 (admin / $GRAFANA_PASSWORD)"
```

### Step 3.6: Verify Monitoring

```bash
# Check Prometheus is scraping metrics
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'
# Expected: > 0

# Check Grafana datasource (via UI)
# Navigate to Configuration → Data Sources → Prometheus should be green
```

**✅ Phase 3 Complete Checklist:**
- [ ] All monitoring pods Running
- [ ] Prometheus accessible and collecting metrics
- [ ] Grafana accessible with dashboards
- [ ] Resource usage within limits (check with: kubectl top pods -n monitoring)

**⚠️ STOP**: Do not proceed until all checks pass.

---

## 🔒 Phase 4: Vault Deployment (Security Stack) - ⚠️ OPTIONAL

> **💡 Skip This Phase If:** You want to deploy just monitoring and web app first. You can add Vault later - see [Adding Vault Later](#adding-vault-later-optional).

> **✅ Complete This Phase If:** You want full secret management with Vault agent injection.

### Step 4.1: Wait for Vault Deployment

```bash
# Monitor Vault deployment (Wave 3)
kubectl wait --for=condition=Synced --timeout=600s \
  application/security-stack -n argocd

# Watch Vault pods
kubectl get pods -n vault -w
# Wait for vault-0 to be Running (may show 0/1 Ready - this is expected)
# Press Ctrl+C when Running
```

### Step 4.2: Verify Vault Pods

```bash
# Check Vault StatefulSet
kubectl get statefulsets -n vault
# Expected: vault with 1 replica

# Check Vault pods (will be sealed and uninitialized)
kubectl get pods -n vault
# Expected: 
# - vault-0: Running but 0/1 Ready (sealed)
# - vault-agent-injector-*: Running and 1/1 Ready
```

### Step 4.3: Port Forward to Vault

```bash
# Set up port forward
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &

# Export Vault address
export VAULT_ADDR="http://localhost:8200"

# Give it a moment
sleep 3
```

### Step 4.4: Check Vault Status

```bash
# Check status (should show sealed and uninitialized)
vault status
# Expected:
# Initialized: false
# Sealed: true
# Error: Vault is sealed
```

**✅ Phase 4 Complete Checklist:**
- [ ] Vault pod Running (even if 0/1 Ready)
- [ ] Vault agent injector Running (1/1 Ready)
- [ ] Vault accessible via port-forward
- [ ] vault status shows Initialized: false, Sealed: true

**⚠️ STOP**: Do not proceed until Vault is deployed and accessible.

---

## 🔧 Phase 5: Vault Configuration (Critical Phase) - ⚠️ OPTIONAL

> **⚠️ Prerequisites**: Phase 4 must be complete. Skip if you skipped Phase 4.

> **⚠️ Important**: This phase initializes Vault with policies and secrets. Follow steps exactly.

### Step 5.1: Initialize Vault

```bash
# Initialize Vault with single key for local development
vault operator init -key-shares=1 -key-threshold=1 > vault-keys-local.txt

# Extract root token and unseal key
export VAULT_TOKEN=$(grep 'Initial Root Token:' vault-keys-local.txt | awk '{print $NF}')
export VAULT_UNSEAL_KEY=$(grep 'Unseal Key 1:' vault-keys-local.txt | awk '{print $NF}')

echo "Root Token: $VAULT_TOKEN"
echo "Unseal Key: $VAULT_UNSEAL_KEY"

# Save for later use
echo "export VAULT_TOKEN=$VAULT_TOKEN" >> ~/.vault-local-env
echo "export VAULT_UNSEAL_KEY=$VAULT_UNSEAL_KEY" >> ~/.vault-local-env
```

### Step 5.2: Unseal Vault

```bash
# Unseal Vault
vault operator unseal $VAULT_UNSEAL_KEY

# Verify unsealed status
vault status
# Expected: Sealed: false, Initialized: true
```

### Step 5.3: Enable Secrets Engine

```bash
# Enable KV v2 secrets engine
vault secrets enable -path=secret kv-v2

# Verify
vault secrets list
# Expected: secret/ with type kv
```

### Step 5.4: Enable Kubernetes Authentication

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Get Kubernetes service account info
KUBE_CA_CERT=$(kubectl get secret -n vault \
  $(kubectl get sa vault -n vault -o jsonpath='{.secrets[0].name}') \
  -o jsonpath='{.data.ca\.crt}' | base64 -d)

KUBE_TOKEN=$(kubectl get secret -n vault \
  $(kubectl get sa vault -n vault -o jsonpath='{.secrets[0].name}') \
  -o jsonpath='{.data.token}' | base64 -d)

# Configure Kubernetes auth
vault write auth/kubernetes/config \
  kubernetes_host="https://$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}' | sed 's|https://||')" \
  kubernetes_ca_cert="$KUBE_CA_CERT" \
  token_reviewer_jwt="$KUBE_TOKEN"

# Verify
vault auth list
# Expected: kubernetes/ listed
```

### Step 5.5: Create Web App Policy

```bash
# Create policy for web app
vault policy write k8s-web-app - <<EOF
# Allow read access to web app secrets
path "secret/data/production/web-app/*" {
  capabilities = ["read"]
}
path "secret/metadata/production/web-app/*" {
  capabilities = ["read", "list"]
}
# Allow authentication
path "auth/kubernetes/login" {
  capabilities = ["create", "update"]
}
# Allow token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

# Verify policy
vault policy list
# Expected: k8s-web-app listed
```

### Step 5.6: Create Kubernetes Role

```bash
# Create role for k8s-web-app service account
vault write auth/kubernetes/role/k8s-web-app \
  bound_service_account_names=k8s-web-app \
  bound_service_account_namespaces=production \
  policies=k8s-web-app \
  ttl=1h \
  max_ttl=24h

# Verify role
vault read auth/kubernetes/role/k8s-web-app
```

### Step 5.7: Create Application Secrets (Local Development)

```bash
# Create database secrets (local development values)
vault kv put secret/production/web-app/db \
  host="localhost" \
  port="5432" \
  name="k8s_web_app_dev" \
  username="dev_user" \
  password="dev_password_123"

# Create API secrets
vault kv put secret/production/web-app/api \
  jwt_secret="dev-jwt-secret-$(openssl rand -hex 16)" \
  encryption_key="dev-encryption-key-$(openssl rand -hex 16)" \
  api_key="dev-api-key-$(openssl rand -hex 8)"

# Create external services secrets
vault kv put secret/production/web-app/external \
  smtp_host="localhost" \
  smtp_port="1025" \
  smtp_username="dev-smtp" \
  smtp_password="dev-smtp-pass" \
  redis_url="redis://localhost:6379"
```

### Step 5.8: Verify Secrets

```bash
# List secrets
vault kv list secret/production/web-app/
# Expected: db, api, external

# Test read secret
vault kv get -format=json secret/production/web-app/db | jq '.data.data'
# Expected: JSON with all fields
```

### Step 5.9: Test Vault Integration

```bash
# Create test pod with Vault service account
kubectl run vault-test \
  --image=alpine \
  --restart=Never \
  --serviceaccount=vault \
  -n vault \
  -- sleep 3600

# Wait for pod
kubectl wait --for=condition=ready pod/vault-test -n vault --timeout=60s

# Test connectivity
kubectl exec vault-test -n vault -- wget -q -O- http://vault:8200/v1/sys/health

# Cleanup
kubectl delete pod vault-test -n vault
```

**✅ Phase 5 Complete Checklist:**
- [ ] Vault initialized (vault-keys-local.txt saved)
- [ ] Vault unsealed (Sealed: false)
- [ ] KV v2 secrets engine enabled
- [ ] Kubernetes auth enabled and configured
- [ ] k8s-web-app policy created
- [ ] k8s-web-app role created
- [ ] All application secrets created
- [ ] Vault accessible from within cluster

**⚠️ STOP**: Keep vault-keys-local.txt safe. You'll need it to unseal Vault after Minikube restarts.

---

## 🌐 Phase 6: Web Application Deployment (Without Secrets)

> **Note**: This phase deploys the web app WITHOUT any secret dependencies. Vault integration is added in Phase 7.

### Step 6.1: Verify Application Configuration

```bash
# Check the application is configured to use values-local.yaml
kubectl get application k8s-web-app -n argocd -o yaml | grep -A 5 valueFiles
# Expected: valueFiles: [values-local.yaml]
```

### Step 6.2: Deploy Web Application

```bash
# The application should already be syncing from Phase 2
# Check application status
kubectl get applications -n argocd | grep k8s-web-app

# Wait for app to sync (using values-local.yaml with no secrets)
kubectl wait --for=condition=Synced --timeout=600s \
  application/k8s-web-app -n argocd

# Check pods
kubectl get pods -n production
# Expected: k8s-web-app pods Running (1/1 container per pod - NO vault-agent yet)
```

### Step 6.3: Verify Application Health

```bash
# Check pod logs
kubectl logs -n production deployment/k8s-web-app --tail=20

# Verify only 1 container per pod (no Vault sidecar yet)
kubectl get pods -n production -l app.kubernetes.io/name=k8s-web-app \
  -o jsonpath='{.items[0].spec.containers[*].name}'
# Expected: k8s-web-app (only one container)

# Check pod status
kubectl describe pod -n production -l app.kubernetes.io/name=k8s-web-app | grep -A 10 "Containers:"
# Expected: Only k8s-web-app container, State: Running
```

### Step 6.4: Test Application

```bash
# Port forward to application
kubectl port-forward svc/k8s-web-app -n production 8081:80 > /dev/null 2>&1 &
echo "Web App: http://localhost:8081"

# Test application health
sleep 3
curl -s http://localhost:8081/health
# Expected: {"status":"ok"}

# Test application endpoint
curl -s http://localhost:8081/
# Expected: HTML response or welcome message
```

### Step 6.5: Verify No Secret Dependencies

```bash
# Check environment variables (should only have basic env vars from values-local.yaml)
kubectl exec -n production deployment/k8s-web-app -- env | grep -E "NODE_ENV|APP_VERSION|PORT"
# Expected:
# NODE_ENV=development
# APP_VERSION=1.0.0
# PORT=3000

# Verify NO secret-related env vars
kubectl exec -n production deployment/k8s-web-app -- env | grep -E "DB_|JWT_|API_KEY|SMTP_|REDIS"
# Expected: (empty - no secret env vars yet)
```

**✅ Phase 6 Complete Checklist:**
- [ ] Application deployed and Running (1/1 containers)
- [ ] Application accessible at http://localhost:8081
- [ ] Health check returns {"status":"ok"}
- [ ] No Vault sidecar container present
- [ ] No secret environment variables configured
- [ ] Application works without any secrets

---

## 🔐 Phase 7: Adding Vault Secrets to Web Application - ⚠️ OPTIONAL

> **⚠️ Prerequisites**: Phases 4, 5, and 6 must be complete. Vault must be initialized and unsealed.

> **💡 Skip This Phase If:** You skipped Phases 4-5. Your web app will work fine without Vault secrets.

This phase demonstrates how to add Vault secret injection to an already-deployed application.

### Step 7.1: Verify Vault is Ready

```bash
# Port forward to Vault (if not already running)
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &

# Load Vault credentials
source ~/.vault-local-env

# Verify Vault status
vault status
# Expected: Initialized: true, Sealed: false

# Verify web app secrets exist in Vault
vault kv list secret/production/web-app/
# Expected: api, db, external

# Check a sample secret
vault kv get secret/production/web-app/db
# Expected: host, port, name, username, password fields
```

### Step 7.2: Understand the Values Files

Before making changes, let's understand the configuration files:

```bash
# View current config (no secrets)
cat applications/web-app/k8s-web-app/values-local.yaml | grep -A 5 "vault:"
# Shows: vault.enabled: false

# View Vault-enabled config
cat applications/web-app/k8s-web-app/values-vault-enabled.yaml | grep -A 20 "vault:"
# Shows: vault.enabled: true, vault.ready: true, vault secrets configuration
```

### Step 7.3: Update Application to Enable Vault

Now we'll update the ArgoCD application to use both values files:

```bash
# Update application to merge values-local.yaml + values-vault-enabled.yaml
kubectl patch application k8s-web-app -n argocd --type merge -p '
{
  "spec": {
    "source": {
      "helm": {
        "valueFiles": ["values-local.yaml", "values-vault-enabled.yaml"]
      }
    }
  }
}'

# Verify the patch applied
kubectl get application k8s-web-app -n argocd -o jsonpath='{.spec.source.helm.valueFiles}'
# Expected: ["values-local.yaml","values-vault-enabled.yaml"]
```

### Step 7.4: Monitor the Deployment Update

```bash
# Watch application sync in ArgoCD
kubectl get application k8s-web-app -n argocd -w
# Wait until STATUS shows "Synced"
# Press Ctrl+C when ready

# Or wait programmatically
kubectl wait --for=condition=Synced --timeout=300s \
  application/k8s-web-app -n argocd

# Monitor pod rollout (pods will restart with 2 containers now)
kubectl get pods -n production -l app.kubernetes.io/name=k8s-web-app -w
# Wait for new pods showing 2/2 Ready (app + vault-agent)
# Press Ctrl+C when ready
```

### Step 7.5: Verify Vault Sidecar Injection

```bash
# Check pod now has 2 containers
kubectl get pods -n production -l app.kubernetes.io/name=k8s-web-app \
  -o jsonpath='{.items[0].spec.containers[*].name}'
# Expected: k8s-web-app vault-agent

# Check Vault annotations on pod
kubectl get pod -n production -l app.kubernetes.io/name=k8s-web-app \
  -o jsonpath='{.items[0].metadata.annotations}' | grep vault
# Expected: vault.hashicorp.com/agent-inject: "true", vault.hashicorp.com/role: "web-app-role"

# Verify init containers ran
kubectl get pods -n production -l app.kubernetes.io/name=k8s-web-app \
  -o jsonpath='{.items[0].spec.initContainers[*].name}'
# Expected: vault-wait vault-agent-init
```

### Step 7.6: Verify Vault Agent Logs

```bash
# Check Vault agent init logs
kubectl logs -n production -l app.kubernetes.io/name=k8s-web-app \
  -c vault-agent-init --tail=30
# Expected: "rendering" and "created" messages for secrets

# Check Vault agent sidecar logs
kubectl logs -n production -l app.kubernetes.io/name=k8s-web-app \
  -c vault-agent --tail=30 --follow
# Expected: "renewal loop" and "template render" messages
# Press Ctrl+C to stop following logs
```

### Step 7.7: Verify Secrets Are Injected

```bash
# List injected secret files
kubectl exec -n production deployment/k8s-web-app -- ls -la /vault/secrets/
# Expected: db, api, external files

# Check database secrets
kubectl exec -n production deployment/k8s-web-app -- cat /vault/secrets/db
# Expected: DB_HOST=..., DB_PORT=5432, DB_NAME=..., etc.

# Check API secrets
kubectl exec -n production deployment/k8s-web-app -- cat /vault/secrets/api
# Expected: JWT_SECRET=..., ENCRYPTION_KEY=..., API_KEY=...

# Check external service secrets
kubectl exec -n production deployment/k8s-web-app -- cat /vault/secrets/external
# Expected: SMTP_HOST=..., REDIS_URL=..., etc.
```

### Step 7.8: Verify Environment Variables

The deployment template is configured to read secrets from Vault-injected files. Verify:

```bash
# Check environment variables now include secrets from Vault
kubectl exec -n production deployment/k8s-web-app -- env | grep -E "DB_|JWT_|API_KEY|SMTP_|REDIS" | sort
# Expected: All secret environment variables populated from Vault

# Compare with before (should see many more env vars now)
kubectl exec -n production deployment/k8s-web-app -- env | wc -l
# Expected: More environment variables than before
```

### Step 7.9: Test Application with Secrets

```bash
# Test application still responds
curl -s http://localhost:8081/health
# Expected: {"status":"ok"}

# Test application functionality
curl -s http://localhost:8081/
# Expected: HTML response or welcome message

# Check application logs for any secret-related errors
kubectl logs -n production deployment/k8s-web-app -c k8s-web-app --tail=50
# Expected: No errors, application should be using secrets
```

### Step 7.10: Verify Secret Rotation (Optional)

Test that the application can handle secret updates:

```bash
# Update a secret in Vault
vault kv patch secret/production/web-app/db port=5433

# Restart pods to pick up new secrets
kubectl rollout restart deployment k8s-web-app -n production

# Wait for rollout
kubectl rollout status deployment k8s-web-app -n production

# Verify updated secret
kubectl exec -n production deployment/k8s-web-app -- cat /vault/secrets/db | grep DB_PORT
# Expected: DB_PORT=5433 (updated value)

# Revert change
vault kv patch secret/production/web-app/db port=5432
kubectl rollout restart deployment k8s-web-app -n production
```

**✅ Phase 7 Complete Checklist:**
- [ ] Application updated to use Vault secrets
- [ ] Pods have 2/2 containers (app + vault-agent)
- [ ] Vault agent init container completed successfully
- [ ] Vault agent logs show successful authentication
- [ ] Secrets injected at /vault/secrets/ (db, api, external)
- [ ] Environment variables populated from Vault
- [ ] Application functions correctly with secrets
- [ ] No errors in application or Vault agent logs

---

## 📝 How to Add Vault Secrets to Any Application

The web app integration serves as a template. To add Vault secrets to your own applications:

### 1. Create Your Application Values Files

**Base values file** (`values.yaml` or `values-local.yaml`):
```yaml
vault:
  enabled: false  # Start with Vault disabled
  ready: false
  role: "your-app-role"
  secrets: []

# No secret environment variables
secretRefs: []
```

**Vault-enabled values file** (`values-vault-enabled.yaml`):
```yaml
vault:
  enabled: true   # Enable Vault
  ready: true
  role: "your-app-role"
  secrets:
    - secretPath: "secret/data/production/your-app/db"
      mountPath: "/vault/secrets/db"
      template: |
        {{- with secret "secret/data/production/your-app/db" -}}
        DB_HOST={{ .Data.data.host }}
        DB_PORT={{ .Data.data.port }}
        {{- end }}
```

### 2. Update Deployment Template

Add Vault annotations in your `deployment.yaml`:
```yaml
{{- if and .Values.vault.enabled .Values.vault.ready }}
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: {{ .Values.vault.role }}
  vault.hashicorp.com/agent-inject-secret-db: "secret/data/production/your-app/db"
  vault.hashicorp.com/agent-inject-template-db: |
    {{- range .Values.vault.secrets -}}
    {{- if eq .secretPath "secret/data/production/your-app/db" -}}
    {{- .template | nindent 10 }}
    {{- end -}}
    {{- end }}
{{- end }}
```

### 3. Configure Vault

```bash
# Create secrets in Vault
vault kv put secret/production/your-app/db \
  host="your-db-host" \
  port="5432"

# Create Vault policy
vault policy write your-app-policy - <<EOF
path "secret/data/production/your-app/*" {
  capabilities = ["read"]
}
EOF

# Create Kubernetes auth role
vault write auth/kubernetes/role/your-app-role \
  bound_service_account_names=your-app-sa \
  bound_service_account_namespaces=production \
  policies=your-app-policy \
  ttl=24h
```

### 4. Deploy and Enable Vault

```bash
# Deploy without Vault first
helm install your-app ./your-app-chart -f values-local.yaml

# Verify it works
kubectl get pods -n production

# Then enable Vault
helm upgrade your-app ./your-app-chart \
  -f values-local.yaml \
  -f values-vault-enabled.yaml

# Verify Vault integration
kubectl logs -n production deployment/your-app -c vault-agent
```

---

## ✅ Deployment Complete - Final Verification

> **Note**: Complete this after finishing Phase 7 (Vault integration). If you've only completed Phase 6, the web app will have 1/1 containers instead of 2/2.

### System Health Check

```bash
# Check all applications
kubectl get applications -n argocd
# Expected: All "Synced" and "Healthy"

# Check all pods across namespaces
kubectl get pods -A | grep -v "Running\|Completed"
# Expected: Empty (all pods Running or Completed)

# Verify web app has Vault sidecar (if Phase 7 complete)
kubectl get pods -n production -l app.kubernetes.io/name=k8s-web-app
# Expected: 2/2 Ready (with Vault) or 1/1 Ready (without Vault)

# Check resource usage
kubectl top nodes
kubectl top pods -A

# Verify local resource limits are respected
```

### Access All Services

```bash
# Stop any existing port-forwards
pkill -f "kubectl port-forward"

# Start all port-forwards
echo "Starting port forwards..."

# ArgoCD
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
echo "✅ ArgoCD: https://localhost:8080 (admin / $ARGOCD_PASSWORD)"

# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus -n monitoring 9090:9090 > /dev/null 2>&1 &
echo "✅ Prometheus: http://localhost:9090"

# Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80 > /dev/null 2>&1 &
echo "✅ Grafana: http://localhost:3000 (admin / $GRAFANA_PASSWORD)"

# Vault
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &
echo "✅ Vault: http://localhost:8200"

# Web Application
kubectl port-forward svc/k8s-web-app -n production 8081:80 > /dev/null 2>&1 &
echo "✅ Web App: http://localhost:8081"

sleep 3
echo ""
echo "All services are accessible!"
```

### 📖 Comprehensive Access Guide

For detailed guides on using Prometheus, Grafana, and Vault, see:

**[Application Access Guide](APPLICATION_ACCESS_GUIDE.md)**

This comprehensive guide includes:
- ✅ **Prometheus**: Query language (PromQL), targets, alerts, API usage, useful queries
- ✅ **Grafana**: Dashboard creation, data sources, alerting, community dashboards, Explore mode
- ✅ **Vault**: Secret management, policies, Kubernetes auth, audit logs, versioning
- ✅ **ArgoCD**: Application management, CLI usage, sync operations
- ✅ **Troubleshooting**: Common access issues and solutions
- ✅ **Credential Management**: Save and load your credentials securely

### Test End-to-End

```bash
echo "Testing complete deployment..."

# 1. Check Vault
vault status > /dev/null 2>&1 && echo "✅ Vault: OK" || echo "❌ Vault: FAIL"

# 2. Check Prometheus
curl -s http://localhost:9090/-/healthy > /dev/null && echo "✅ Prometheus: OK" || echo "❌ Prometheus: FAIL"

# 3. Check Grafana
curl -s -k http://localhost:3000/api/health | grep -q "ok" && echo "✅ Grafana: OK" || echo "❌ Grafana: FAIL"

# 4. Check application
curl -s http://localhost:8081/health | grep -q "ok" && echo "✅ Application: OK" || echo "❌ Application: FAIL"

echo ""
echo "Deployment verification complete!"
```

---

## 🔧 Daily Operations

### Starting Your Environment

```bash
# Start Minikube
minikube start

# Wait for cluster to be ready
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Unseal Vault (required after restart)
source ~/.vault-local-env
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &
sleep 3
vault operator unseal $VAULT_UNSEAL_KEY

# Start port forwards
./start-portforwards.sh  # Create this script with the port-forward commands above
```

### Stopping Your Environment

```bash
# Stop port forwards
pkill -f "kubectl port-forward"

# Stop Minikube
minikube stop
```

### Updating Application

```bash
# Rebuild image
cd examples/web-app
eval $(minikube docker-env)
docker build -t k8s-web-app:latest .

# Restart deployment
kubectl rollout restart deployment k8s-web-app -n production

# Watch rollout
kubectl rollout status deployment k8s-web-app -n production
```

### Updating Secrets

```bash
# Update Vault secret
vault kv patch secret/production/web-app/db password="new-password"

# Application will automatically get new secret (may take up to 60s)
# Or force restart
kubectl rollout restart deployment k8s-web-app -n production
```

---

## 🚨 Troubleshooting

### ArgoCD Application Sync Errors

#### Secret Reference Errors (Invalid secretKeyRef.name)

**Symptom**: ArgoCD shows sync error with multiple "Invalid value: ""  for secretKeyRef.name"

```
Failed sync attempt: Deployment.apps "k8s-web-app" is invalid: 
spec.template.spec.containers[0].env[3].valueFrom.secretKeyRef.name: 
Invalid value: "": a lowercase RFC 1123 subdomain must consist of...
```

**Cause**: Helm template has empty secret names, usually due to:
1. Missing or incorrect values file configuration
2. Helm template bug in nested loops
3. Secret references when secrets don't exist

**Solution 1 - Use values-local.yaml** (Recommended for Minikube):
```bash
# Update ArgoCD to use local values (no secrets)
kubectl patch application k8s-web-app -n argocd --type merge -p '
{
  "spec": {
    "source": {
      "helm": {
        "valueFiles": ["values-local.yaml"]
      }
    }
  }
}'

# Wait for sync
kubectl wait --for=condition=Synced --timeout=300s application/k8s-web-app -n argocd
```

**Solution 2 - Debug the Helm Template**:
```bash
# View the rendered manifest
kubectl get application k8s-web-app -n argocd -o yaml

# Check helm values being used
helm template applications/web-app/k8s-web-app/helm \
  -f applications/web-app/k8s-web-app/values-local.yaml | grep -A 10 "secretKeyRef"

# Verify values file has correct configuration
cat applications/web-app/k8s-web-app/values-local.yaml | grep -A 5 "vault:"
# Should show: vault.enabled: false

cat applications/web-app/k8s-web-app/values-local.yaml | grep "secretRefs"
# Should show: secretRefs: []
```

**Solution 3 - Force Refresh**:
```bash
# Hard refresh ArgoCD application
kubectl delete application k8s-web-app -n argocd
kubectl apply -f applications/web-app/k8s-web-app/application.yaml

# Wait for sync
kubectl wait --for=condition=Synced --timeout=300s application/k8s-web-app -n argocd
```

#### Application Stuck in "Progressing" State

**Symptom**: Application shows "Progressing" for extended period

**Solution**:
```bash
# Check application status
kubectl get application k8s-web-app -n argocd -o jsonpath='{.status.sync.status}'

# Check detailed sync status
kubectl describe application k8s-web-app -n argocd | grep -A 20 "Status:"

# Check if pods are running
kubectl get pods -n production

# View ArgoCD application events
kubectl logs -n argocd deployment/argocd-application-controller | grep k8s-web-app
```

#### "OutOfSync" Despite No Changes

**Symptom**: Application shows "OutOfSync" even after sync

**Solution**:
```bash
# Check diff
argocd app diff k8s-web-app

# Sync with replace
argocd app sync k8s-web-app --replace

# Or force sync via kubectl
kubectl patch application k8s-web-app -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'
```

### Minikube Not Starting

```bash
# Check status
minikube status

# Check logs
minikube logs

# Try deleting and recreating
minikube delete
minikube start --memory=4096 --cpus=2 --disk-size=30g --driver=docker
```

### Out of Resources

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A

# Reduce monitoring resources
helm upgrade prometheus -n monitoring \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m

# Or stop monitoring temporarily
kubectl scale statefulset prometheus-kube-prometheus-stack-prometheus -n monitoring --replicas=0
```

### Vault Sealed After Restart

```bash
# This is normal behavior
# Load your keys
source ~/.vault-local-env

# Port forward
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &

# Unseal
vault operator unseal $VAULT_UNSEAL_KEY

# Verify
vault status
```

### Application Can't Read Secrets

```bash
# Check Vault agent logs
kubectl logs -n production deployment/k8s-web-app -c vault-agent --tail=50

# Check if secrets exist in pod
kubectl exec -n production deployment/k8s-web-app -- ls -R /vault/secrets/

# Restart deployment
kubectl rollout restart deployment k8s-web-app -n production
```

### Pods Stuck in Pending

```bash
# Check pod events
kubectl describe pod -n <namespace> <pod-name>

# Check node resources
kubectl describe node minikube

# May need to increase Minikube resources
minikube stop
minikube delete
minikube start --memory=6144 --cpus=3 --disk-size=40g
```

---

## 🧹 Cleanup

### Full Cleanup

```bash
# Delete Minikube cluster (removes everything)
minikube delete

# Remove local files
rm -f vault-keys-local.txt
rm -f ~/.vault-local-env
```

### Partial Cleanup (Keep Minikube)

```bash
# Delete applications
kubectl delete -f clusters/production/app-of-apps.yaml

# Delete ArgoCD
helm uninstall argo-cd -n argocd

# Delete namespaces
kubectl delete namespace argocd monitoring vault production
```

---

## 📚 Local Development Tips & Optimization

### Resource Optimization Details

The Minikube deployment uses optimized values files to reduce resource usage by 60-70% compared to production:

#### Minikube Cluster Requirements

| Resource | Production | Local Development | Reduction |
|----------|------------|-------------------|-----------|
| Memory | 8GB | 4GB | 50% |
| CPU | 4 cores | 2 cores | 50% |
| Disk | 50GB | 30GB | 40% |

#### Application Resource Reductions

| Application | Production | Local | Reduction |
|-------------|-----------|-------|-----------|
| Web App | 1Gi / 1000m CPU | 256Mi / 250m CPU | 75% / 75% |
| Vault | 1Gi / 1000m CPU | 256Mi / 200m CPU | 75% / 80% |
| Prometheus | 1Gi / 500m CPU | 512Mi / 250m CPU | 50% / 50% |
| Grafana | 512Mi / 250m CPU | 256Mi / 100m CPU | 50% / 60% |

#### Features Disabled for Local Development

- ❌ **High Availability**: Single replicas instead of multiple
- ❌ **Autoscaling**: HPA disabled for all applications
- ❌ **Ingress**: Use port-forward instead
- ❌ **Complex Network Policies**: Simplified for local use
- ❌ **TLS for Vault**: HTTP only (not for production!)
- ❌ **Extended Retention**: Prometheus 7d vs 15d

#### Local Values Files Used

The deployment automatically uses these optimized files:
- `applications/web-app/k8s-web-app/values-local.yaml`
- `applications/security/vault/values-local.yaml`
- `applications/monitoring/prometheus/values-local.yaml`
- `applications/monitoring/grafana/values-local.yaml`

### Fast Iteration Workflow

```bash
# 1. Make code changes in examples/web-app/

# 2. Use Minikube's Docker daemon
eval $(minikube docker-env)

# 3. Rebuild image
cd examples/web-app
docker build -t k8s-web-app:latest .

# 4. Restart deployment
kubectl rollout restart deployment k8s-web-app -n production

# 5. Watch logs
kubectl logs -f deployment/k8s-web-app -n production

# 6. Test changes
curl http://localhost:8081
```

### Advanced Customization

You can further optimize based on your system:

```bash
# Even lower resources (2GB RAM)
minikube start --memory=2048 --cpus=2

# Then scale down Prometheus
kubectl scale statefulset prometheus-kube-prometheus-stack-prometheus \
  -n monitoring --replicas=0

# Or disable monitoring temporarily
kubectl delete application monitoring-stack -n argocd
```

### Switching to Production Values

To test with production-like settings:

```bash
# Stop Minikube
minikube stop

# Start with more resources
minikube start --memory=8192 --cpus=4 --disk-size=50g

# Update application to use production values
kubectl patch application k8s-web-app -n argocd --type merge -p '
{
  "spec": {
    "source": {
      "helm": {
        "valueFiles": ["../values.yaml"]
      }
    }
  }
}'
```

### ⚠️ Important Limitations

**Local development optimizations should NEVER be used in production:**

| Limitation | Impact |
|------------|--------|
| Single replicas | No high availability or fault tolerance |
| No autoscaling | Can't handle load spikes |
| HTTP Vault | Secrets transmitted unencrypted |
| Reduced monitoring | Fewer metrics and shorter retention |
| Simplified security | Network policies and security contexts reduced |

**Memory Usage Comparison:**
- **Production**: ~6-8GB total memory
- **Local**: ~2-3GB total memory
- **Savings**: 60-70% reduction

---

## 🔐 Adding Vault Later (Optional)

If you skipped Phases 4-5-7 and want to add Vault secret management later, follow the comprehensive guide in the AWS deployment documentation:

**See:** [AWS Deployment Guide - Adding Vault Later](AWS_DEPLOYMENT_GUIDE.md#adding-vault-later-optional)

The steps are identical for Minikube, with these minor differences:

### Quick Steps for Minikube

1. **Deploy Vault:**
   ```bash
   # Check if security-stack exists
   kubectl get application security-stack -n argocd
   
   # If not, apply AppProject first
   kubectl apply -f clusters/production/production-apps-project.yaml
   
   # Force sync
   kubectl patch application security-stack -n argocd \
     --type merge -p '{"operation":{"sync":{}}}'
   ```

2. **Configure Vault:**
   ```bash
   # Port forward
   kubectl port-forward svc/vault -n vault 8200:8200 &
   export VAULT_ADDR="http://localhost:8200"
   
   # Initialize (save output!)
   vault operator init -key-shares=1 -key-threshold=1 > vault-keys-local.txt
   
   # Extract credentials
   export VAULT_TOKEN=$(grep 'Initial Root Token:' vault-keys-local.txt | awk '{print $NF}')
   export VAULT_UNSEAL_KEY=$(grep 'Unseal Key 1:' vault-keys-local.txt | awk '{print $NF}')
   
   # Unseal
   vault operator unseal $VAULT_UNSEAL_KEY
   
   # Save for later use
   echo "export VAULT_TOKEN=$VAULT_TOKEN" >> ~/.vault-local-env
   echo "export VAULT_UNSEAL_KEY=$VAULT_UNSEAL_KEY" >> ~/.vault-local-env
   ```

3. **Follow Phase 5 steps** to enable secrets engine, Kubernetes auth, policies, and create secrets

4. **Enable Vault in web app:**
   ```bash
   kubectl patch application k8s-web-app -n argocd --type merge -p '
   {
     "spec": {
       "source": {
         "helm": {
           "valueFiles": ["values-local.yaml", "values-vault-enabled.yaml"]
         }
       }
     }
   }'
   ```

5. **Verify integration:**
   ```bash
   kubectl get pods -n production
   # Should see 2/2 Ready (app + vault-agent)
   
   kubectl exec -n production deployment/k8s-web-app -- ls /vault/secrets/
   # Should see: api, db, external
   ```

### Minikube-Specific Notes

**Vault After Minikube Restart:**
```bash
# Vault will be sealed after Minikube restarts
# Reload credentials
source ~/.vault-local-env

# Port forward
kubectl port-forward svc/vault -n vault 8200:8200 &

# Unseal
vault operator unseal $VAULT_UNSEAL_KEY
```

**For detailed instructions, see the AWS Deployment Guide section: [Adding Vault Later](AWS_DEPLOYMENT_GUIDE.md#adding-vault-later-optional)**

---

## 📖 Related Documentation

- **[Application Access Guide](APPLICATION_ACCESS_GUIDE.md)** - Comprehensive Prometheus, Grafana, and Vault usage guide
- [AWS Deployment Guide](AWS_DEPLOYMENT_GUIDE.md) - Production AWS deployment
- [AWS Guide: Adding Vault Later](AWS_DEPLOYMENT_GUIDE.md#adding-vault-later-optional) - Complete Vault addition steps
- [Project Structure](docs/PROJECT_STRUCTURE.md) - Repository organization
- [Vault Setup Guide](docs/VAULT_SETUP_GUIDE.md) - Detailed Vault configuration
- [Security Best Practices](docs/security-best-practices.md) - Security guidelines