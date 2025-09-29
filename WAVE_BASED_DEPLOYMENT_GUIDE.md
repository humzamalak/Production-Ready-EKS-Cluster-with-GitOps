# Wave-Based GitOps Deployment Guide

This guide provides step-by-step instructions for deploying the production-ready EKS cluster using a wave-based approach with progressive Vault integration.

## 🎯 Overview

The deployment is structured in **5 waves** to ensure proper dependency ordering and avoid YAML parsing errors:

1. **Wave 1**: Bootstrap and Infrastructure
2. **Wave 2**: Monitoring Stack  
3. **Wave 3**: Security Stack (Vault)
4. **Wave 3.5**: Vault Initialization
5. **Wave 5**: Web Applications

## 📋 Prerequisites

- Kubernetes cluster (EKS, Minikube, or local)
- kubectl configured
- Git repository access
- ArgoCD installed (via bootstrap)

## 🚀 Wave 1: Bootstrap and Infrastructure

### What Gets Deployed
- Core namespaces
- Pod Security Standards
- Network Policies
- Helm repositories
- ArgoCD installation

### Instructions

1. **Deploy the root application**:
   ```bash
   kubectl apply -f clusters/production/app-of-apps.yaml
   ```

2. **Verify Wave 1 deployment**:
   ```bash
   kubectl get applications -n argocd
   kubectl get namespaces
   ```

3. **Check ArgoCD is ready**:
   ```bash
   kubectl get pods -n argocd
   # Wait for all pods to be Running
   ```

### Expected Outcome
- ✅ ArgoCD UI accessible
- ✅ All core namespaces created
- ✅ Network policies applied
- ✅ Helm repositories configured

---

## 📊 Wave 2: Monitoring Stack

### What Gets Deployed
- Prometheus for metrics collection
- Grafana for dashboards
- ServiceMonitor configurations

### Instructions

1. **Verify monitoring stack deployment**:
   ```bash
   kubectl get applications -n argocd | grep monitoring
   kubectl get pods -n monitoring
   ```

2. **Access Grafana** (if ingress configured):
   ```bash
   kubectl get ingress -n monitoring
   # Access via browser or port-forward
   kubectl port-forward svc/grafana -n monitoring 3000:80
   ```

### Expected Outcome
- ✅ Prometheus collecting metrics
- ✅ Grafana dashboards accessible
- ✅ ServiceMonitor CRDs installed

---

## 🔒 Wave 3: Security Stack (Vault)

### What Gets Deployed
- HashiCorp Vault server
- Vault agent injector
- RBAC configurations

### Instructions

1. **Verify Vault deployment**:
   ```bash
   kubectl get applications -n argocd | grep vault
   kubectl get pods -n vault
   ```

2. **Check Vault status**:
   ```bash
   kubectl port-forward svc/vault -n vault 8200:8200 &
   vault status
   # Should show "Initialized: false" and "Sealed: true"
   ```

### Expected Outcome
- ✅ Vault server running
- ✅ Vault agent injector ready
- ✅ RBAC configured

---

## 🔧 Wave 3.5: Vault Initialization

### What Gets Deployed
- Vault initialization job
- Kubernetes authentication setup
- Web-app policies and roles
- Sample secrets creation

### Instructions

1. **Deploy Vault initialization**:
   ```bash
   kubectl apply -f applications/security/vault/init-job.yaml
   ```

2. **Monitor initialization job**:
   ```bash
   kubectl get jobs -n vault
   kubectl logs job/vault-init -n vault -f
   ```

3. **Verify Vault is initialized**:
   ```bash
   vault status
   # Should show "Initialized: true" and "Sealed: false"
   ```

4. **Check created secrets**:
   ```bash
   vault kv list secret/production/web-app/
   # Should show: db, api, external
   ```

### Expected Outcome
- ✅ Vault initialized and unsealed
- ✅ Kubernetes auth enabled
- ✅ Web-app role and policy created
- ✅ Sample secrets populated

---

## 🌐 Wave 5: Web Applications

### Phase 1: Deploy Without Vault Integration

### Instructions

1. **Verify web app deployment** (Vault disabled):
   ```bash
   kubectl get applications -n argocd | grep web-app
   kubectl get pods -n production
   ```

2. **Check application logs**:
   ```bash
   kubectl logs -n production deployment/k8s-web-app
   # Should show app running with K8s secrets
   ```

3. **Test application access**:
   ```bash
   kubectl port-forward svc/k8s-web-app -n production 8080:80
   # Access http://localhost:8080
   ```

### Expected Outcome
- ✅ Web application running
- ✅ Using Kubernetes secrets (not Vault)
- ✅ All health checks passing

### Phase 2: Enable Vault Integration

### Instructions

1. **Update web app to use Vault**:
   ```bash
   # Edit the ArgoCD application to use vault-enabled values
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
   ```

2. **Wait for sync and verify**:
   ```bash
   kubectl get pods -n production
   kubectl logs -n production deployment/k8s-web-app
   # Should show Vault integration working
   ```

3. **Verify Vault secrets are injected**:
   ```bash
   kubectl exec -n production deployment/k8s-web-app -- env | grep DB_
   # Should show database environment variables from Vault
   ```

### Expected Outcome
- ✅ Web application using Vault secrets
- ✅ Vault agent injection working
- ✅ Zero-downtime migration

---

## 🔄 Deployment Verification

### Complete System Check

1. **All applications healthy**:
   ```bash
   kubectl get applications -n argocd
   # All should show "Synced" and "Healthy"
   ```

2. **All pods running**:
   ```bash
   kubectl get pods --all-namespaces
   # All pods should be Running
   ```

3. **Vault integration working**:
   ```bash
   kubectl logs -n production deployment/k8s-web-app | grep -i vault
   # Should show successful Vault connections
   ```

4. **Monitoring working**:
   ```bash
   kubectl port-forward svc/grafana -n monitoring 3000:80
   # Access Grafana and verify dashboards
   ```

---

## 🛠️ Troubleshooting

### Common Issues

#### Wave 1: Bootstrap Issues
```bash
# Check ArgoCD installation
kubectl describe application production-cluster -n argocd

# Check bootstrap logs
kubectl logs -n argocd deployment/argo-cd-argocd-server
```

#### Wave 2: Monitoring Issues
```bash
# Check Prometheus status
kubectl get pods -n monitoring
kubectl logs -n monitoring deployment/prometheus

# Check Grafana access
kubectl port-forward svc/grafana -n monitoring 3000:80
```

#### Wave 3: Vault Issues
```bash
# Check Vault status
kubectl get pods -n vault
kubectl logs -n vault deployment/vault

# Check Vault health
kubectl port-forward svc/vault -n vault 8200:8200 &
vault status
```

#### Wave 3.5: Vault Init Issues
```bash
# Check initialization job
kubectl get jobs -n vault
kubectl logs job/vault-init -n vault

# Manually initialize if needed
kubectl exec -n vault deployment/vault -- vault operator init
```

#### Wave 5: Web App Issues
```bash
# Check web app deployment
kubectl get pods -n production
kubectl describe pod -n production -l app.kubernetes.io/name=k8s-web-app

# Check Vault integration
kubectl logs -n production deployment/k8s-web-app | grep -i vault
```

### Recovery Procedures

#### If Vault Initialization Fails
1. **Check job logs**:
   ```bash
   kubectl logs job/vault-init -n vault
   ```

2. **Manually initialize**:
   ```bash
   kubectl exec -n vault deployment/vault -- vault operator init
   ```

3. **Re-run initialization job**:
   ```bash
   kubectl delete job vault-init -n vault
   kubectl apply -f applications/security/vault/init-job.yaml
   ```

#### If Web App Vault Integration Fails
1. **Revert to K8s secrets**:
   ```bash
   kubectl patch application k8s-web-app -n argocd --type merge -p '
   {
     "spec": {
       "source": {
         "helm": {
           "valueFiles": ["values.yaml"]
         }
       }
     }
   }'
   ```

2. **Debug Vault connectivity**:
   ```bash
   kubectl exec -n production deployment/k8s-web-app -- nc -z vault.vault.svc.cluster.local 8200
   ```

---

## 📚 Next Steps

After successful deployment:

1. **Configure monitoring alerts**
2. **Set up backup procedures**
3. **Implement security scanning**
4. **Add more applications**
5. **Configure CI/CD pipelines**

---

## 🔗 Related Documentation

- [AWS Deployment Guide](AWS_DEPLOYMENT_GUIDE.md)
- [Minikube Deployment Guide](MINIKUBE_DEPLOYMENT_GUIDE.md)
- [Vault Setup Guide](docs/VAULT_SETUP_GUIDE.md)
- [Security Best Practices](docs/security-best-practices.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
