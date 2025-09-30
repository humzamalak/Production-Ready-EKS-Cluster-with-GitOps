# AWS EKS Production Deployment Guide

Complete production deployment guide for AWS EKS cluster with GitOps, using a **phase-based approach** to ensure reliable deployment and prevent configuration issues.

> **⚠️ Critical**: Follow each phase in order. **Do not skip verification steps**. Each phase must complete successfully before moving to the next.

## 🎯 Overview

This deployment follows a **6-phase approach** with built-in verification at each step:

| Phase | Component | Purpose | Duration |
|-------|-----------|---------|----------|
| **Phase 1** | AWS Infrastructure | EKS cluster, VPC, IAM | 15-20 min |
| **Phase 2** | Bootstrap | ArgoCD, namespaces, policies | 5-10 min |
| **Phase 3** | Monitoring | Prometheus, Grafana | 5-10 min |
| **Phase 4** | Vault Deployment | Vault server, agent injector | 5 min |
| **Phase 5** | Vault Configuration | Initialize, policies, secrets | 10 min |
| **Phase 6** | Applications | Web app with Vault integration | 10 min |

**Total Time**: ~60 minutes

---

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
kubectl version --client

# Helm v3.12+
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# Terraform >=1.5.0
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
terraform version

# Vault CLI (for secret management)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault
vault version
```

### AWS Account Setup

1. **Configure AWS credentials**:
   ```bash
   aws configure
   # Enter: Access Key ID, Secret Access Key, region (e.g., us-west-2), output format (json)
   
   # Verify access
   aws sts get-caller-identity
   ```

2. **Required AWS permissions**:
   - EKS, VPC, IAM, EC2, CloudWatch, S3, DynamoDB

---

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

# EKS Configuration
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

# Check namespaces
kubectl get namespaces
# Expected: default, kube-system, kube-public, kube-node-lease

# Check storage class
kubectl get storageclass
# Expected: gp2 (default)

# Check cluster info
kubectl cluster-info
```

**✅ Phase 1 Complete Checklist:**
- [ ] 3 nodes in Ready state
- [ ] kubectl commands work
- [ ] Storage class available
- [ ] No errors in kubectl output

**⚠️ STOP**: Do not proceed until all checks pass.

---

## 🔧 Phase 2: Bootstrap (GitOps Foundation)

### Step 2.1: Update Repository URL

```bash
# Navigate back to repo root
cd ../..

# Update repo URL in all manifests (replace with your fork)
find clusters/ applications/ -name "*.yaml" -type f -exec sed -i 's|https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps|https://github.com/YOUR-ORG/YOUR-REPO|g' {} \;
```

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
# Add ArgoCD Helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
helm upgrade --install argo-cd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values bootstrap/helm-values/argo-cd-values.yaml \
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
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443 &

# Access at https://localhost:8080
# Username: admin
# Password: $ARGOCD_PASSWORD
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
# Check all namespaces created
kubectl get namespaces
# Expected: argocd, monitoring, vault, production

# Check ArgoCD applications
kubectl get applications -n argocd
# Expected: production-cluster, monitoring-stack, security-stack

# Check ArgoCD pods
kubectl get pods -n argocd
# Expected: All Running

# Verify network policies
kubectl get networkpolicies -A
```

**✅ Phase 2 Complete Checklist:**
- [ ] ArgoCD UI accessible
- [ ] All namespaces created
- [ ] Root application synced
- [ ] All ArgoCD pods Running
- [ ] Network policies applied

**⚠️ STOP**: Do not proceed until all checks pass.

---

## 📊 Phase 3: Monitoring Stack

### Step 3.1: Wait for Monitoring Deployment

```bash
# Monitor deployment (Wave 2)
kubectl get applications -n argocd -w
# Wait for monitoring-stack to show "Synced" and "Healthy"
# Press Ctrl+C when ready

# Alternatively, wait with timeout
kubectl wait --for=condition=Synced --timeout=600s \
  application/monitoring-stack -n argocd
```

### Step 3.2: Verify Monitoring Pods

```bash
# Check monitoring namespace
kubectl get pods -n monitoring

# Wait for all pods to be ready
kubectl wait --for=condition=ready --timeout=600s \
  pod -l app.kubernetes.io/part-of=kube-prometheus-stack -n monitoring
```

### Step 3.3: Access Prometheus

```bash
# Port forward to Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus \
  -n monitoring 9090:9090 &

# Test Prometheus (in another terminal)
curl -s http://localhost:9090/-/healthy
# Expected: Prometheus is Healthy

# Access UI at http://localhost:9090
```

### Step 3.4: Access Grafana

```bash
# Get Grafana admin password
export GRAFANA_PASSWORD=$(kubectl get secret grafana-admin -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d)
echo "Grafana Password: $GRAFANA_PASSWORD"

# Port forward to Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80 &

# Access UI at http://localhost:3000
# Username: admin
# Password: $GRAFANA_PASSWORD
```

### Step 3.5: Verify Monitoring

```bash
# Check ServiceMonitors
kubectl get servicemonitors -n monitoring

# Check Prometheus targets (via UI or API)
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'
# Expected: > 0

# Verify Grafana datasource
# In Grafana UI: Configuration → Data Sources → Prometheus (should be green)
```

**✅ Phase 3 Complete Checklist:**
- [ ] All monitoring pods Running
- [ ] Prometheus accessible and healthy
- [ ] Grafana accessible with dashboards
- [ ] ServiceMonitors created
- [ ] Prometheus collecting metrics

**⚠️ STOP**: Do not proceed until all checks pass.

---

## 🔒 Phase 4: Vault Deployment (Security Stack)

### Step 4.1: Wait for Vault Deployment

```bash
# Monitor Vault deployment (Wave 3)
kubectl wait --for=condition=Synced --timeout=600s \
  application/security-stack -n argocd

# Check Vault pods
kubectl get pods -n vault -w
# Wait for vault-0 to be Running (may show 0/1 Ready - this is expected)
# Press Ctrl+C when Running
```

### Step 4.2: Verify Vault Pods

```bash
# Check Vault StatefulSet
kubectl get statefulsets -n vault

# Check Vault pods (will be sealed and uninitialized)
kubectl get pods -n vault
# Expected: vault-0 Running but 0/1 Ready (sealed)

# Check Vault agent injector
kubectl get pods -n vault -l app.kubernetes.io/name=vault-agent-injector
# Expected: Running and 1/1 Ready
```

### Step 4.3: Port Forward to Vault

```bash
# Set up port forward
kubectl port-forward svc/vault -n vault 8200:8200 &

# Export Vault address
export VAULT_ADDR="http://localhost:8200"
```

### Step 4.4: Check Vault Status

```bash
# Check status (should show sealed and uninitialized)
vault status
# Expected:
# Initialized: false
# Sealed: true
```

**✅ Phase 4 Complete Checklist:**
- [ ] Vault pod Running (even if 0/1 Ready)
- [ ] Vault agent injector Running (1/1 Ready)
- [ ] Vault accessible via port-forward
- [ ] vault status shows Initialized: false, Sealed: true

**⚠️ STOP**: Do not proceed until Vault is deployed and accessible.

---

## 🔧 Phase 5: Vault Configuration (Critical Phase)

> **⚠️ Important**: This phase initializes Vault with policies and secrets. Follow steps exactly.

### Step 5.1: Initialize Vault

```bash
# Initialize Vault (SAVE THE OUTPUT!)
vault operator init -key-shares=1 -key-threshold=1 > vault-keys.txt

# Extract root token and unseal key
export VAULT_TOKEN=$(grep 'Initial Root Token:' vault-keys.txt | awk '{print $NF}')
export VAULT_UNSEAL_KEY=$(grep 'Unseal Key 1:' vault-keys.txt | awk '{print $NF}')

echo "Root Token: $VAULT_TOKEN"
echo "Unseal Key: $VAULT_UNSEAL_KEY"

# ⚠️ IMPORTANT: Backup vault-keys.txt securely and DELETE from local system after backing up
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
# Expected: secret/ listed with type kv-v2
```

### Step 5.4: Enable Kubernetes Authentication

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc.cluster.local"

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

### Step 5.7: Create Application Secrets

```bash
# Create database secrets
vault kv put secret/production/web-app/db \
  host="your-production-db.amazonaws.com" \
  port="5432" \
  name="k8s_web_app_prod" \
  username="k8s_web_app_user" \
  password="$(openssl rand -base64 32)"

# Create API secrets
vault kv put secret/production/web-app/api \
  jwt_secret="$(openssl rand -base64 64)" \
  encryption_key="$(openssl rand -base64 32)" \
  api_key="$(openssl rand -base64 32)"

# Create external services secrets
vault kv put secret/production/web-app/external \
  smtp_host="smtp.your-provider.com" \
  smtp_port="587" \
  smtp_username="your-smtp-username" \
  smtp_password="$(openssl rand -base64 24)" \
  redis_url="redis://your-redis-host:6379"
```

### Step 5.8: Verify Secrets

```bash
# List secrets
vault kv list secret/production/web-app/
# Expected: db, api, external

# Test read secret (without revealing values)
vault kv get -format=json secret/production/web-app/db | jq '.data.data | keys'
# Expected: ["host", "name", "password", "port", "username"]
```

### Step 5.9: Test Vault Integration

```bash
# Create test pod with Vault injection
kubectl run vault-test --image=alpine --restart=Never -n production -- sleep 3600

# Check if Vault is accessible from pod
kubectl exec vault-test -n production -- wget -q -O- http://vault.vault.svc.cluster.local:8200/v1/sys/health

# Cleanup test pod
kubectl delete pod vault-test -n production
```

**✅ Phase 5 Complete Checklist:**
- [ ] Vault initialized (vault-keys.txt saved securely)
- [ ] Vault unsealed (Sealed: false)
- [ ] KV v2 secrets engine enabled
- [ ] Kubernetes auth enabled and configured
- [ ] k8s-web-app policy created
- [ ] k8s-web-app role created
- [ ] All application secrets created and accessible
- [ ] Vault accessible from within cluster

**⚠️ CRITICAL**: Backup vault-keys.txt before proceeding. If lost, you cannot recover Vault data.

---

## 🌐 Phase 6: Application Deployment

### Step 6.1: Deploy Web Application (Phase 1 - Without Vault)

```bash
# The application should already be syncing from Phase 2
# Check application status
kubectl get applications -n argocd | grep k8s-web-app

# Wait for app to sync (defaults to Vault disabled)
kubectl wait --for=condition=Synced --timeout=600s \
  application/k8s-web-app -n argocd

# Check pods
kubectl get pods -n production
# Expected: k8s-web-app pods Running (1 container per pod)
```

### Step 6.2: Verify Application (Without Vault)

```bash
# Check pod logs
kubectl logs -n production deployment/k8s-web-app --tail=20

# Port forward to application
kubectl port-forward svc/k8s-web-app -n production 8080:80 &

# Test application
curl http://localhost:8080/health
# Expected: {"status":"ok"}

curl http://localhost:8080/
# Expected: HTML response
```

### Step 6.3: Enable Vault Integration (Phase 2)

```bash
# Update application to use Vault
kubectl patch application k8s-web-app -n argocd --type merge -p '
{
  "spec": {
    "source": {
      "helm": {
        "valueFiles": ["../values.yaml", "../values-vault-enabled.yaml"]
      }
    }
  }
}'

# Wait for sync
kubectl wait --for=condition=Synced --timeout=300s \
  application/k8s-web-app -n argocd

# Monitor pod restart (will have 2 containers now)
kubectl get pods -n production -w
# Wait for new pods with 2/2 Ready
# Press Ctrl+C when ready
```

### Step 6.4: Verify Vault Integration

```bash
# Check pod has Vault agent sidecar
kubectl get pods -n production -l app.kubernetes.io/name=k8s-web-app \
  -o jsonpath='{.items[0].spec.containers[*].name}'
# Expected: k8s-web-app vault-agent

# Check Vault agent logs
kubectl logs -n production deployment/k8s-web-app -c vault-agent --tail=50
# Expected: "renewal loop" or "template render" messages

# Check if secrets are injected
kubectl exec -n production deployment/k8s-web-app -- ls -la /vault/secrets/
# Expected: db, api, external directories

# Verify environment variables from Vault
kubectl exec -n production deployment/k8s-web-app -- sh -c 'env | grep DB_HOST'
# Expected: DB_HOST=your-production-db.amazonaws.com
```

### Step 6.5: Test Application with Vault

```bash
# Test application endpoints
curl http://localhost:8080/health
# Expected: {"status":"ok","vault":"connected"}

curl http://localhost:8080/api/info
# Expected: Application info with Vault status
```

### Step 6.6: Verify HPA and Scaling

```bash
# Check HorizontalPodAutoscaler
kubectl get hpa -n production

# Check current metrics
kubectl top pods -n production

# Verify autoscaling works (optional load test)
# kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://k8s-web-app.production; done"
```

**✅ Phase 6 Complete Checklist:**
- [ ] Application deployed and Running
- [ ] Application accessible (without Vault)
- [ ] Vault integration enabled
- [ ] Pods have 2/2 containers (app + vault-agent)
- [ ] Vault agent logs show successful auth
- [ ] Secrets injected at /vault/secrets/
- [ ] Application can read Vault secrets
- [ ] HPA configured and working

---

## ✅ Deployment Complete - Final Verification

### System Health Check

```bash
# Check all applications
kubectl get applications -n argocd
# Expected: All "Synced" and "Healthy"

# Check all pods
kubectl get pods -A | grep -v "Running\|Completed"
# Expected: No output (all pods Running or Completed)

# Check node resources
kubectl top nodes

# Check persistent volumes
kubectl get pv
```

### Access All Services

```bash
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

### Test End-to-End

```bash
# Full integration test
echo "Testing complete deployment..."

# 1. Check Vault is accessible
vault status > /dev/null && echo "✅ Vault: OK" || echo "❌ Vault: FAIL"

# 2. Check Prometheus is scraping
curl -s http://localhost:9090/-/healthy > /dev/null && echo "✅ Prometheus: OK" || echo "❌ Prometheus: FAIL"

# 3. Check Grafana is accessible
curl -s http://localhost:3000/api/health | grep -q "ok" && echo "✅ Grafana: OK" || echo "❌ Grafana: FAIL"

# 4. Check application is healthy
curl -s http://localhost:8081/health | grep -q "ok" && echo "✅ Application: OK" || echo "❌ Application: FAIL"

echo "Deployment verification complete!"
```

---

## 🔧 Configuration Updates

### Update Vault Secrets

```bash
# Update database password
vault kv patch secret/production/web-app/db password="$(openssl rand -base64 32)"

# Application will automatically get new secret (may take up to 60s)
```

### Update Application Configuration

```bash
# Edit values
vi applications/web-app/k8s-web-app/values.yaml

# Commit changes
git add applications/web-app/k8s-web-app/values.yaml
git commit -m "Update application configuration"
git push

# ArgoCD will auto-sync (or force sync)
kubectl patch application k8s-web-app -n argocd -p '{"operation":{"sync":{}}}' --type merge
```

### Scale Application

```bash
# Manual scaling
kubectl scale deployment k8s-web-app -n production --replicas=5

# Or update HPA
kubectl patch hpa k8s-web-app -n production --patch '{"spec":{"maxReplicas":30}}'
```

---

## 🚨 Troubleshooting

### Phase 1 Issues: Infrastructure

**Nodes not ready:**
```bash
kubectl describe nodes
# Check events for errors
aws eks describe-cluster --name $(terraform output -raw cluster_name) --region $(terraform output -raw aws_region)
```

### Phase 2 Issues: Bootstrap

**ArgoCD not starting:**
```bash
kubectl logs -n argocd deployment/argo-cd-argocd-server
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server
```

**Root application not syncing:**
```bash
kubectl describe application production-cluster -n argocd
# Check repository access and sync status
```

### Phase 3 Issues: Monitoring

**Prometheus pods crashlooping:**
```bash
kubectl logs -n monitoring statefulset/prometheus-kube-prometheus-stack-prometheus
kubectl describe pod -n monitoring -l app.kubernetes.io/name=prometheus
# Check PVC and resource limits
```

### Phase 4 Issues: Vault Deployment

**Vault pod not starting:**
```bash
kubectl logs -n vault vault-0
kubectl describe pod -n vault vault-0
# Check storage class and PVC
```

### Phase 5 Issues: Vault Configuration

**Cannot initialize Vault:**
```bash
# Check if already initialized
vault status

# If sealed, unseal
vault operator unseal $VAULT_UNSEAL_KEY

# Check connectivity
kubectl exec -n vault vault-0 -- vault status
```

**Secrets not accessible:**
```bash
# Verify policy
vault policy read k8s-web-app

# Verify role
vault read auth/kubernetes/role/k8s-web-app

# Test from pod
kubectl run vault-test --image=vault --restart=Never -n production -- sh
kubectl exec vault-test -n production -- vault kv get secret/production/web-app/db
```

### Phase 6 Issues: Application

**Vault agent not injecting secrets:**
```bash
# Check annotations
kubectl get pod -n production -l app.kubernetes.io/name=k8s-web-app -o yaml | grep vault.hashicorp.com

# Check vault-agent logs
kubectl logs -n production deployment/k8s-web-app -c vault-agent

# Check service account
kubectl get sa k8s-web-app -n production
```

**Application can't read secrets:**
```bash
# Check if secrets exist in pod
kubectl exec -n production deployment/k8s-web-app -- ls -R /vault/secrets/

# Check file permissions
kubectl exec -n production deployment/k8s-web-app -- ls -la /vault/secrets/

# Check vault-agent config
kubectl exec -n production deployment/k8s-web-app -c vault-agent -- cat /vault/configs/agent.config
```

---

## 🧹 Cleanup

### Destroy Everything

```bash
# Delete applications
kubectl delete -f clusters/production/app-of-apps.yaml

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
kubectl delete application k8s-web-app -n argocd

# Remove monitoring stack
kubectl delete application monitoring-stack -n argocd

# Remove security stack  
kubectl delete application security-stack -n argocd
```

---

## 📚 Next Steps

1. **Configure SSL/TLS**: Set up cert-manager for automatic certificate management
2. **Set up CI/CD**: Integrate with GitHub Actions for automated deployments
3. **Configure Backups**: Set up automated backups for etcd and Vault
4. **Set up Alerts**: Configure AlertManager rules for production monitoring
5. **Security Hardening**: Review and implement security best practices
6. **Add More Applications**: Deploy additional services using the same pattern

---

## 📖 Related Documentation

- [Minikube Deployment Guide](MINIKUBE_DEPLOYMENT_GUIDE.md) - Local development deployment
- [Project Structure](docs/PROJECT_STRUCTURE.md) - Repository organization
- [Vault Setup Guide](docs/VAULT_SETUP_GUIDE.md) - Detailed Vault configuration
- [Security Best Practices](docs/security-best-practices.md) - Security guidelines
- [Troubleshooting Guide](TROUBLESHOOTING.md) - Common issues and solutions