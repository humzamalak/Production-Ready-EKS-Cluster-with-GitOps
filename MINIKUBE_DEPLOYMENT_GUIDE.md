# Minikube Deployment Guide

Complete step-by-step guide for deploying the Production-Ready EKS Cluster with GitOps, Vault, Prometheus, and Grafana on Minikube for local development.

> **⚠️ Important**: This guide has been updated to use a **wave-based deployment approach**. For the most reliable deployment experience, we recommend following the **[Wave-Based Deployment Guide](WAVE_BASED_DEPLOYMENT_GUIDE.md)** first, then using this guide for Minikube-specific setup.

## 🎯 Overview

This guide will walk you through:
1. **Local Infrastructure Setup**: Creating Minikube cluster with required addons
2. **GitOps Bootstrap**: Installing ArgoCD and core cluster components
3. **Monitoring Stack**: Deploying Prometheus and Grafana (Wave 2)
4. **Security Stack**: Setting up Vault server and agent injector (Wave 3)
5. **Vault Initialization**: Initializing Vault with policies and secrets (Wave 3.5)
6. **Web Application**: Deploying with progressive Vault integration (Wave 5)
7. **Verification**: Testing all components and access

## 📋 Prerequisites

### Required Tools

```bash
# Install Minikube
# macOS
brew install minikube

# Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Windows (using Chocolatey)
choco install minikube

# Install kubectl
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Docker Desktop
# Download from: https://www.docker.com/products/docker-desktop

# Install Helm
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Vault CLI (for secret management)
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/vault

# Linux
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault
```

### System Requirements

- **macOS**: 10.15 or later
- **Linux**: Ubuntu 18.04+ or equivalent
- **Windows**: Windows 10/11 with WSL2
- **RAM**: 4GB minimum, 8GB recommended
- **CPU**: 2 cores minimum, 4 cores recommended
- **Storage**: 30GB free disk space
- **Docker Desktop**: Running and configured

## 🏗️ Part 1: Local Infrastructure Setup

### Step 1: Start Minikube

```bash
# Start Minikube with optimized resources for local development
minikube start --memory=4096 --cpus=2 --disk-size=30g --driver=docker

# Enable required addons
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable storage-provisioner
minikube addons enable default-storageclass

# Verify cluster is running
kubectl get nodes
kubectl cluster-info
```

**Expected Output:**
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   1m    v1.28.3
```

### Step 2: Verify Minikube Setup

```bash
# Check Minikube status
minikube status

# Check available addons
minikube addons list

# Check storage classes
kubectl get storageclass

# Check if metrics server is working
kubectl top nodes
```

### Step 3: Build and Load Application Image

```bash
# Navigate to the web-app directory
cd examples/web-app

# Build the Docker image
docker build -t k8s-web-app:latest .

# Load image into Minikube (no need to push to registry)
minikube image load k8s-web-app:latest

# Verify image is loaded
minikube image ls | grep k8s-web-app

# Navigate back to repository root
cd ../..
```

## 🚀 Part 2: GitOps Bootstrap

### Step 1: Deploy Core Components

```bash
# Apply core namespaces first
kubectl apply -f bootstrap/00-namespaces.yaml

# Verify namespaces were created
kubectl get namespaces

# Apply security policies and configurations
kubectl apply -f bootstrap/01-pod-security-standards.yaml
kubectl apply -f bootstrap/02-network-policy.yaml
kubectl apply -f bootstrap/03-helm-repos.yaml
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

### Customize Resource Limits for Local Development

For local development with limited resources, use the optimized values files:

```bash
# Use optimized values for web application
helm upgrade --install k8s-web-app applications/web-app/k8s-web-app/helm \
  -n production \
  -f applications/web-app/k8s-web-app/values-local.yaml

# Use optimized values for Vault
helm upgrade --install vault applications/security/vault/helm \
  -n vault \
  -f applications/security/vault/values-local.yaml

# Use optimized values for Prometheus
helm upgrade --install prometheus applications/monitoring/prometheus/helm \
  -n monitoring \
  -f applications/monitoring/prometheus/values-local.yaml

# Use optimized values for Grafana
helm upgrade --install grafana applications/monitoring/grafana/helm \
  -n monitoring \
  -f applications/monitoring/grafana/values-local.yaml
```

The local values files include:
- **Reduced memory requirements**: 64Mi-512Mi instead of 128Mi-1Gi
- **Reduced CPU requirements**: 25m-250m instead of 50m-1000m
- **Single replicas**: Disabled HA and autoscaling for local development
- **Simplified configurations**: Disabled ingress, network policies, and complex features
- **Reduced storage**: 1Gi-5Gi instead of 5Gi-20Gi

### Configure Local Storage

For persistent storage in Minikube:

```bash
# Check available storage classes
kubectl get storageclass

# Create a persistent volume for development
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /data
EOF
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Minikube Start Issues
```bash
# Check Minikube status
minikube status

# Check Docker status
docker ps

# Restart Minikube
minikube stop
minikube start --memory=4096 --cpus=2 --driver=docker

# Check logs
minikube logs
```

#### 2. Namespace Not Found Errors
```bash
# Error: namespaces "argocd" not found
# Solution: Ensure namespaces are created first

# Check if namespaces exist
kubectl get namespaces

# If argocd namespace is missing, apply namespaces first
kubectl apply -f bootstrap/00-namespaces.yaml

# Verify all required namespaces exist
kubectl get namespaces | grep -E "(argocd|vault|monitoring|production)"

# Then proceed with other bootstrap components
kubectl apply -f bootstrap/01-pod-security-standards.yaml
kubectl apply -f bootstrap/02-network-policy.yaml
kubectl apply -f bootstrap/03-helm-repos.yaml
```

#### 3. Pod Startup Issues
```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace> --previous

# Check events
kubectl get events -n <namespace> --sort-by=.metadata.creationTimestamp
```

#### 4. Image Pull Issues
```bash
# Check if image exists in Minikube
minikube image ls | grep k8s-web-app

# Rebuild and reload image
cd examples/web-app
docker build -t k8s-web-app:latest .
minikube image load k8s-web-app:latest
```

#### 5. Port Forward Issues
```bash
# Check if service exists
kubectl get svc -n <namespace>

# Check if pods are running
kubectl get pods -n <namespace>

# Try different port
kubectl port-forward svc/<service-name> 8081:80 -n <namespace>
```

#### 6. ArgoCD Applications Not Syncing
```bash
# Check application status
kubectl describe application <app-name> -n argocd

# Force sync
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller
```

#### 7. Vault Integration Issues
```bash
# Check Vault agent logs
kubectl logs -n production -l app.kubernetes.io/name=k8s-web-app -c vault-agent

# Verify Vault connectivity
kubectl exec -n vault vault-0 -- vault status

# Check service account
kubectl get sa k8s-web-app-vault-sa -n production
```

#### 8. ArgoCD Finalizer Warnings
```bash
# Warning: metadata.finalizers: "resources-finalizer.argocd.argoproj.io": prefer a domain-qualified finalizer name

# This is a warning, not an error. The application will still work correctly.
# The warning occurs because Kubernetes prefers more specific finalizer names to avoid conflicts.
# This is a cosmetic warning from Kubernetes - ArgoCD applications work perfectly fine with this finalizer.

# The warning is safe to ignore. Your GitOps deployment will function correctly.
# To verify the application is working:
kubectl get applications -n argocd
kubectl describe application production-cluster -n argocd

# Note: This warning is common with ArgoCD and doesn't affect functionality.
```

#### 9. YAML Syntax Errors in Helm Templates
```bash
# Error: Failed to unmarshal "deployment.yaml": yaml: line X: did not find expected node content

# This error indicates malformed YAML in Helm templates.
# Common causes:
# 1. Duplicate YAML keys (like duplicate 'annotations:' sections)
# 2. Incorrect indentation in Helm template loops
# 3. Malformed Helm template syntax

# To debug:
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd

# Check ArgoCD logs for more details:
kubectl logs -n argocd deployment/argocd-repo-server

# Fix by correcting the YAML syntax in the problematic template file.
# The deployment.yaml template has been fixed to resolve this issue.

#### 10. Helm Template Configuration Issues
```bash
# Issue: Hardcoded values in Helm templates instead of using values.yaml
# This can cause configuration drift and inconsistent deployments

# Common problems:
# 1. HPA behavior values hardcoded in template instead of using .Values.autoscaling.behavior
# 2. Duplicate annotations sections causing YAML parsing errors
# 3. Incorrect conditional logic in Helm templates

# To debug Helm template issues:
helm template <release-name> <chart-path> --values <values-file>

# To validate Helm templates:
helm lint <chart-path>

# Check rendered output:
helm template k8s-web-app applications/web-app/k8s-web-app/helm \
  --values applications/web-app/k8s-web-app/values.yaml

# The HPA template has been fixed to use values from values.yaml instead of hardcoded values.
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

# Check Minikube addons
minikube addons list
```

## 📊 Performance Optimization

### Memory Optimization for Local Development

This deployment has been optimized for local development with the following memory reductions:

**Minikube Cluster:**
- Memory: 8GB → 4GB (50% reduction)
- CPU: 4 cores → 2 cores (50% reduction)
- Disk: 50GB → 30GB (40% reduction)

**Application Resources:**
- Web App: 1Gi → 256Mi memory (75% reduction)
- Vault: 1Gi → 256Mi memory (75% reduction)
- Prometheus: 1Gi → 512Mi memory (50% reduction)
- Grafana: 512Mi → 256Mi memory (50% reduction)

**Total Estimated Memory Usage:**
- **Before optimization**: ~6-8GB
- **After optimization**: ~2-3GB
- **Savings**: ~60-70% reduction

### Minikube Optimization

```bash
# Start with more resources (if you have them available)
minikube start --memory=8192 --cpus=4 --disk-size=50g

# Use Docker driver for better performance
minikube start --driver=docker --memory=4096 --cpus=2

# Enable GPU support if available
minikube start --memory=4096 --cpus=2 --gpus=1

# Use HyperKit driver on macOS for better performance
minikube start --driver=hyperkit --memory=4096 --cpus=2
```

### Application Optimization

```bash
# Increase replica count for better availability
helm upgrade k8s-web-app applications/web-app/k8s-web-app/helm \
  -n production \
  --set replicaCount=3

# Adjust resource limits based on usage
helm upgrade k8s-web-app applications/web-app/k8s-web-app/helm \
  -n production \
  --set resources.requests.cpu=200m \
  --set resources.requests.memory=256Mi
```

## 🔄 Updates and Rollbacks

### Application Updates

#### Via ArgoCD:
```bash
# Update image tag in values file
vim applications/web-app/k8s-web-app/values.yaml

# Force sync in ArgoCD
kubectl patch application web-app-stack -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'
```

#### Via Helm:
```bash
# Update with new values
helm upgrade k8s-web-app applications/web-app/k8s-web-app/helm \
  -n production \
  --set image.tag=v1.1.0
```

### Rollbacks

```bash
# Rollback using ArgoCD
kubectl patch application web-app-stack -n argocd --type merge -p '{"operation":{"sync":{"revision":"<previous-revision>"}}}'

# Rollback using kubectl
kubectl rollout undo deployment/k8s-web-app -n production

# Check rollout history
kubectl rollout history deployment/k8s-web-app -n production
```

## 🧹 Cleanup

### Remove Applications

```bash
# Delete ArgoCD applications
kubectl delete applications --all -n argocd

# Delete namespaces
kubectl delete namespace monitoring
kubectl delete namespace vault
kubectl delete namespace production
kubectl delete namespace argocd
```

### Stop Minikube

```bash
# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete

# Clean up Docker images
docker system prune -a
```

## 📚 Development Workflow

### Local Development

```bash
# Start development environment
minikube start --memory=4096 --cpus=2

# Deploy applications
kubectl apply -f clusters/production/app-of-apps.yaml

# Make changes to code
cd examples/web-app
# Edit server.js or other files

# Rebuild and reload image
docker build -t k8s-web-app:latest .
minikube image load k8s-web-app:latest

# Restart deployment
kubectl rollout restart deployment/k8s-web-app -n production
```

### Testing Changes

```bash
# Test locally
kubectl port-forward svc/k8s-web-app-service -n production 8080:80
curl http://localhost:8080/health

# Check logs
kubectl logs -l app.kubernetes.io/name=k8s-web-app -n production -f
```

## 🎯 Next Steps

After successful deployment:

1. **Set up CI/CD**: Configure GitHub Actions for automated builds
2. **Add Testing**: Implement unit and integration tests
3. **Add Observability**: Implement distributed tracing
4. **Security Scanning**: Add container vulnerability scanning
5. **Load Testing**: Perform load testing to validate auto-scaling
6. **Documentation**: Update team documentation with access procedures

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review the [TROUBLESHOOTING.md](TROUBLESHOOTING.md) file
3. Open an issue in the repository
4. Consult Minikube documentation: https://minikube.sigs.k8s.io/docs/

---

**🎉 Congratulations!** You now have a complete local development environment with GitOps, monitoring, security, and a sample application deployed and running!

**Happy Local Development! 🚀**