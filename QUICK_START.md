# 🚀 Quick Start Guide

**Welcome to the refactored Production-Ready GitOps Stack!**

---

## ⚡ TL;DR

### Minikube (2 minutes)
```bash
minikube start --cpus=4 --memory=8192 --disk-size=20g
./scripts/setup-minikube.sh
```

### AWS EKS (10 minutes)
```bash
cd infrastructure/terraform && terraform apply && cd ../..
./scripts/setup-aws.sh
```

---

## 📁 New Structure Overview

```
├── argocd/              # All ArgoCD manifests
│   ├── install/        # Bootstrap (3 files)
│   ├── projects/       # AppProject
│   └── apps/           # 4 applications
├── apps/               # Helm charts
│   ├── web-app/
│   ├── prometheus/
│   ├── grafana/
│   └── vault/         # NEW!
├── environments/
│   ├── minikube/      # Local dev
│   └── aws/           # Production
└── scripts/
    ├── setup-minikube.sh  # NEW!
    └── setup-aws.sh       # NEW!
```

---

## 🎯 What Changed?

| Before | After |
|--------|-------|
| `applications/` | `apps/` |
| `environments/prod/` | `environments/aws/` |
| `environments/staging/` | `environments/minikube/` |
| `bootstrap/00-07-*.yaml` | `argocd/install/01-03-*.yaml` |
| 2 AppProjects | 1 AppProject |
| No Vault app | Full Vault deployment |

---

## 📚 Essential Documentation

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **DEPLOYMENT_GUIDE.md** | Complete deployment instructions | Start here |
| REFACTOR_SUMMARY.md | What changed and why | Understanding changes |
| VALIDATION_REPORT.md | What was validated | Confidence in changes |
| CLEANUP_PLAN.md | What to delete | After testing |

---

## ✅ Deployment Steps

### Minikube

1. **Start Minikube**
   ```bash
   minikube start --cpus=4 --memory=8192 --disk-size=20g
   minikube addons enable ingress
   minikube addons enable metrics-server
   ```

2. **Deploy Stack**
   ```bash
   ./scripts/setup-minikube.sh
   ```

3. **Access ArgoCD**
   ```bash
   kubectl port-forward -n argocd svc/argocd-server 8080:443
   # Username: admin
   # Password: (shown by script)
   ```

4. **Access Grafana**
   ```bash
   kubectl port-forward -n monitoring svc/grafana 3000:80
   # Username: admin
   # Password: admin
   ```

### AWS EKS

1. **Configure AWS**
   ```bash
   aws configure
   export AWS_REGION=us-east-1
   ```

2. **Deploy Infrastructure**
   ```bash
   cd infrastructure/terraform
   terraform init
   terraform apply
   cd ../..
   ```

3. **Deploy Stack**
   ```bash
   ./scripts/setup-aws.sh
   ```

4. **Configure DNS** (see DEPLOYMENT_GUIDE.md)

---

## 🎛️ ArgoCD Applications

| Application | Sync Wave | Namespace | Purpose |
|-------------|-----------|-----------|---------|
| vault | 2 | vault | Secrets management |
| prometheus | 3 | monitoring | Metrics collection |
| grafana | 4 | monitoring | Dashboards |
| web-app | 5 | production | Sample app |

All managed by the **root-app** (App-of-Apps pattern).

---

## 🔧 Common Tasks

### Check Status
```bash
kubectl get applications -n argocd
kubectl get pods -A
```

### Sync All Apps
```bash
kubectl get applications -n argocd -o name | xargs -I {} kubectl patch {} -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

### View Logs
```bash
kubectl logs -n <namespace> <pod-name>
```

### Access Applications
```bash
# ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Vault
kubectl port-forward -n vault svc/vault 8200:8200
```

---

## 🆘 Troubleshooting

### App Not Syncing
```bash
kubectl describe application <app-name> -n argocd
```

### Pods Not Starting
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Network Issues
```bash
kubectl get networkpolicies -A
kubectl get ingress -A
```

---

## 📖 Next Steps

1. ✅ Read `docs/DEPLOYMENT_GUIDE.md` for detailed instructions
2. ✅ Test deployment on Minikube
3. ✅ Review `VALIDATION_REPORT.md` for what was validated
4. ✅ Clean up old files using `CLEANUP_PLAN.md`
5. ✅ Deploy to AWS EKS (optional)

---

## 🎉 You're Ready!

The refactored repository is:
- ✅ **Minimal** - 40% fewer files
- ✅ **Production-Grade** - Security best practices
- ✅ **Multi-Environment** - Minikube + AWS
- ✅ **Well-Documented** - Comprehensive guides
- ✅ **Validated** - All manifests tested

Start deploying! 🚀

---

**Questions?** Check `docs/DEPLOYMENT_GUIDE.md` or open an issue.

