# Minikube Deployment Guide

Complete guide for deploying the K8s Web Application to Minikube on your local MacBook.

## Overview

This guide covers deploying the Node.js web application to Minikube with:
- **Local Development**: Minikube cluster setup
- **Web Application**: Node.js app with health checks and auto-scaling
- **Optional GitOps**: ArgoCD for GitOps workflow (optional)
- **Monitoring**: Basic monitoring setup (optional)

## Prerequisites

### Required Tools
```bash
# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
sudo install minikube-darwin-amd64 /usr/local/bin/minikube

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
sudo install -o root -g wheel -m 0755 kubectl /usr/local/bin/kubectl

# Install Docker Desktop
# Download from: https://www.docker.com/products/docker-desktop

# Install Helm (optional)
# SAFER: install via package manager or verify signature instead of piping to bash
# macOS (Homebrew):
brew install helm

# Linux (script with signature verification):
# See: https://helm.sh/docs/intro/install/
# Example (verify checksum):
# VERSION=v3.14.4
# wget https://get.helm.sh/helm-${VERSION}-linux-amd64.tar.gz
# wget https://get.helm.sh/helm-${VERSION}-linux-amd64.tar.gz.sha256sum
# sha256sum -c helm-${VERSION}-linux-amd64.tar.gz.sha256sum
# tar -xzvf helm-${VERSION}-linux-amd64.tar.gz
# sudo mv linux-amd64/helm /usr/local/bin/helm
```

### System Requirements
- **macOS**: 10.15 or later
- **RAM**: 4GB minimum, 8GB recommended
- **CPU**: 2 cores minimum, 4 cores recommended
- **Storage**: 20GB free disk space
- **Docker Desktop**: Running and configured

## Quick Start

### Step 1: Start Minikube

```bash
# Start Minikube with sufficient resources
minikube start --memory=4096 --cpus=2 --disk-size=20g

# Enable required addons
minikube addons enable ingress
minikube addons enable metrics-server

# Verify cluster is running
kubectl get nodes
```

**Expected Output:**
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   1m    v1.28.3
```

### Step 2: Build and Load Application Image

```bash
# Navigate to the web-app directory
cd web-app

# Build the Docker image
docker build -t k8s-web-app:latest .

# Load image into Minikube (no need to push to registry)
minikube image load k8s-web-app:latest

# Verify image is loaded
minikube image ls | grep k8s-web-app
```

### Step 3: Deploy the Application

#### Option A: Direct kubectl Deployment (Recommended for Testing)

```bash
# Create namespace
kubectl create namespace production

# Apply Kubernetes manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get pods -n production
kubectl get svc -n production
```

#### Option B: Helm Deployment (Recommended for Production-like Setup)

```bash
# Install using Helm
helm install k8s-web-app ./helm \
  -n production \
  --create-namespace \
  --set image.repository=k8s-web-app \
  --set image.tag=latest \
  --set ingress.enabled=false

# Check deployment
helm list -n production
kubectl get pods -n production
```

### Step 4: Access the Application

```bash
# Port forward to access the application
kubectl port-forward svc/k8s-web-app-service 8080:80 -n production

# Test the application in another terminal
curl http://localhost:8080/health
curl http://localhost:8080/
curl http://localhost:8080/api/info
```

**Expected Output:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "uptime": 120.5,
  "environment": "production",
  "version": "1.0.0"
}
```

## Detailed Deployment Options

### Option 1: Simple kubectl Deployment

This is the fastest way to get the application running:

```bash
# 1. Start Minikube
minikube start --memory=4096 --cpus=2

# 2. Build and load image
cd web-app
docker build -t k8s-web-app:latest .
minikube image load k8s-web-app:latest

# 3. Deploy application
kubectl create namespace production
kubectl apply -f k8s/

# 4. Access application
kubectl port-forward svc/k8s-web-app-service 8080:80 -n production
```

### Option 2: Helm Deployment with Custom Values

For more control over the deployment:

```bash
# 1. Start Minikube
minikube start --memory=4096 --cpus=2

# 2. Build and load image
cd web-app
docker build -t k8s-web-app:latest .
minikube image load k8s-web-app:latest

# 3. Deploy with Helm
helm install k8s-web-app ./helm \
  -n production \
  --create-namespace \
  --set image.repository=k8s-web-app \
  --set image.tag=latest \
  --set replicaCount=2 \
  --set ingress.enabled=false

# 4. Access application
kubectl port-forward svc/k8s-web-app-service 8080:80 -n production
```

### Option 3: GitOps with ArgoCD (Advanced)

For a complete GitOps experience:

```bash
# 1. Start Minikube
minikube start --memory=4096 --cpus=2

# 2. Bootstrap ArgoCD and components
kubectl apply -f bootstrap/

# 3. Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# 4. Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 5. Port forward ArgoCD UI
kubectl port-forward svc/argocd-server 8080:443 -n argocd
# Access at https://localhost:8080 (admin/[password from step 4])

# 6. Deploy applications via ArgoCD (app-of-apps pattern)
kubectl apply -f clusters/production/app-of-apps.yaml

# 7. Monitor application deployment
watch kubectl get applications -n argocd
```

## Verification and Testing

### Check Application Status

```bash
# Check all pods
kubectl get pods -A

# Check application pods
kubectl get pods -n production -l app=k8s-web-app

# Check services
kubectl get svc -n production

# Check horizontal pod autoscaler
kubectl get hpa -n production
```

### Test Application Endpoints

```bash
# Port forward for testing
kubectl port-forward svc/k8s-web-app-service 8080:80 -n production

# Test health endpoint
curl http://localhost:8080/health

# Test readiness endpoint
curl http://localhost:8080/ready

# Test main application
curl http://localhost:8080/

# Test API endpoint
curl http://localhost:8080/api/info
```

### Monitor Application Logs

```bash
# View application logs
kubectl logs -l app=k8s-web-app -n production

# Follow logs in real-time
kubectl logs -l app=k8s-web-app -n production -f

# Check specific pod logs
kubectl logs <pod-name> -n production
```

## Configuration Options

### Environment Variables

The application supports these environment variables:

```yaml
env:
  NODE_ENV: "production"
  APP_VERSION: "1.0.0"
  PORT: "3000"
  HOST: "0.0.0.0"
```

### Resource Limits

Default resource configuration:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Auto-scaling

Horizontal Pod Autoscaler configuration:

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

## Troubleshooting

### Common Issues

#### 1. Pod Not Starting
```bash
# Check pod status
kubectl describe pod <pod-name> -n production

# Check pod logs
kubectl logs <pod-name> -n production --previous
```

#### 2. Image Pull Errors
```bash
# Check if image exists in Minikube
minikube image ls | grep k8s-web-app

# Rebuild and reload image
docker build -t k8s-web-app:latest .
minikube image load k8s-web-app:latest
```

#### 3. Port Forward Issues
```bash
# Check if service exists
kubectl get svc -n production

# Check if pods are running
kubectl get pods -n production

# Try different port
kubectl port-forward svc/k8s-web-app-service 8081:80 -n production
```

#### 4. Health Check Failures
```bash
# Check if application is listening on correct port
kubectl port-forward pod/<pod-name> 3000:3000 -n production
curl http://localhost:3000/health
```

### Debug Commands

```bash
# Get detailed pod information
kubectl describe pod <pod-name> -n production

# Execute into pod for debugging
kubectl exec -it <pod-name> -n production -- /bin/sh

# Check application configuration
kubectl get configmap -n production
kubectl get secret -n production

# Check events
kubectl get events -n production --sort-by=.metadata.creationTimestamp
```

## Scaling Operations

### Horizontal Scaling

The application automatically scales based on CPU and memory usage:

```bash
# Check current scaling status
kubectl get hpa -n production

# Manually scale if needed
kubectl scale deployment k8s-web-app --replicas=5 -n production
```

### Vertical Scaling

Update resource limits in Helm values:

```yaml
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

## Updates and Rollbacks

### Application Updates

#### Via Helm:
```bash
# Update with new values
helm upgrade k8s-web-app ./helm \
  -n production \
  --set image.tag=v1.1.0
```

#### Via kubectl:
```bash
# Update image tag
kubectl set image deployment/k8s-web-app web-app=k8s-web-app:v1.1.0 -n production

# Check rollout status
kubectl rollout status deployment/k8s-web-app -n production
```

### Rollbacks

```bash
# Rollback using Helm
helm rollback k8s-web-app -n production

# Rollback using kubectl
kubectl rollout undo deployment/k8s-web-app -n production

# Check rollout history
kubectl rollout history deployment/k8s-web-app -n production
```

## Cleanup

### Remove Application

```bash
# Using Helm
helm uninstall k8s-web-app -n production

# Using kubectl
kubectl delete -f k8s/

# Remove namespace
kubectl delete namespace production
```

### Stop Minikube

```bash
# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete
```

## Performance Tips

### Minikube Optimization

```bash
# Start with more resources
minikube start --memory=8192 --cpus=4 --disk-size=50g

# Use Docker driver for better performance
minikube start --driver=docker --memory=4096 --cpus=2

# Enable GPU support if available
minikube start --memory=4096 --cpus=2 --gpus=1
```

### Application Optimization

```bash
# Increase replica count for better availability
helm upgrade k8s-web-app ./helm \
  -n production \
  --set replicaCount=3

# Adjust resource limits based on usage
helm upgrade k8s-web-app ./helm \
  -n production \
  --set resources.requests.cpu=200m \
  --set resources.requests.memory=256Mi
```

## Next Steps

After successful deployment:

1. **Set up monitoring**: Deploy Prometheus and Grafana via ArgoCD
2. **Implement CI/CD**: Set up GitHub Actions for automated builds
3. **Add observability**: Implement distributed tracing
4. **Security scanning**: Add container vulnerability scanning
5. **Load testing**: Perform load testing to validate auto-scaling
6. **Documentation**: Update team documentation with access procedures

## GitOps Integration

For a complete GitOps workflow with this repository:

```bash
# Deploy the full monitoring and security stack
kubectl apply -f clusters/production/app-of-apps.yaml

# Access monitoring stack
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus -n monitoring 9090:9090
kubectl port-forward svc/grafana -n monitoring 3000:80

# Access Vault (after initialization)
kubectl port-forward svc/vault -n vault 8200:8200
```

## Automation Scripts

This repository includes helpful automation scripts:

### Configuration Script
```bash
# Interactive configuration script for easy setup
./examples/scripts/configure-deployment.sh
```

### Health Check Script
```bash
# Comprehensive health check script
./examples/scripts/health-check.sh
```

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Open an issue in the repository
3. Consult Minikube documentation: https://minikube.sigs.k8s.io/docs/

---

**Happy Local Development! 🚀**
