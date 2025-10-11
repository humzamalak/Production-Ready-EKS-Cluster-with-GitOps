<!-- Docs Update: 2025-10-11 — Minikube-first documentation overhaul. -->
# Production-Ready Kubernetes with GitOps

> **Primary Focus**: Local development with Minikube  
> **Production Ready**: AWS EKS deployment available for advanced users  
> **Compatibility**: Kubernetes v1.33.0 (validated)

A comprehensive GitOps repository for learning and deploying Kubernetes with ArgoCD, Vault, and observability. Start locally with Minikube, scale to production on AWS EKS.

## 🚀 Quick Start: Local Development (Recommended)

**Get a complete stack running locally in ~25 minutes:**

```bash
# 1. Clone repository
git clone https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps.git
cd Production-Ready-EKS-Cluster-with-GitOps

# 2. Start Minikube
minikube start --memory=4096 --cpus=2 --disk-size=30g

# 3. Deploy everything
./scripts/setup-minikube.sh

# 4. Access services
# Follow the output for URLs and credentials
```

**What you get:**
- ✅ ArgoCD for GitOps
- ✅ Prometheus & Grafana for monitoring
- ✅ HashiCorp Vault for secrets
- ✅ Sample web application
- ✅ Complete local development environment

**Next Steps**: [Complete Local Deployment Guide](docs/local-deployment.md)

---

## 🎯 Deployment Paths

| Path | Best For | Time | Complexity |
|------|----------|------|------------|
| **[🖥️ Local (Minikube)](docs/local-deployment.md)** | Learning, Development, Testing | ~25 min | ⭐ Easy |
| **[☁️ AWS EKS (Production)](docs/aws-deployment.md)** | Production Workloads | ~60 min | ⭐⭐⭐ Advanced |

### Development vs Production Comparison

| Feature | Local (Minikube) | Production (AWS EKS) |
|---------|------------------|----------------------|
| **Infrastructure** | Single-node Minikube | Multi-AZ EKS cluster |
| **Vault** | Single replica, file storage, manual unseal | HA with Raft, AWS KMS auto-unseal |
| **Storage** | Local `standard` StorageClass | AWS EBS with `gp3` |
| **High Availability** | Single instance | Multi-replica with load balancing |
| **Cost** | Free (local resources) | AWS resource charges apply |
| **Setup Time** | ~25 minutes | ~60 minutes |
| **Best For** | Learning, testing, development | Production workloads |

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **[Local Deployment](docs/local-deployment.md)** | Complete Minikube setup guide (⭐ START HERE) |
| **[Vault Local Setup](docs/vault-local-setup.md)** | Local Vault configuration and manual unseal |
| **[Troubleshooting](docs/troubleshooting.md)** | Common issues: Vault, PVCs, Argo CD sync |
| **[Architecture Guide](docs/architecture.md)** | Repository structure and GitOps patterns |
| **[AWS Deployment](docs/aws-deployment.md)** | Advanced: Production EKS deployment |
| **[Vault AWS Setup](docs/vault-setup.md)** | Advanced: AWS Vault with HA and KMS |
| **[ArgoCD CLI Setup](docs/argocd-cli-setup.md)** | Cross-platform ArgoCD CLI access |
| **[K8s Version Policy](docs/K8S_VERSION_POLICY.md)** | Kubernetes version compatibility |
| **[Changelog](CHANGELOG.md)** | Version history and migration guides |

## 🏗️ What's Included

### Core Stack
- **🚀 ArgoCD v3.1.0** - GitOps continuous delivery with automated sync
- **📊 Prometheus & Grafana** - Complete observability stack with dashboards
- **🔐 HashiCorp Vault** - Secrets management
  - **Local**: Single replica, file storage, manual unseal
  - **AWS**: HA with Raft storage, KMS auto-unseal
- **📦 Sample Web App** - Production-ready Helm chart with ServiceMonitor

### Environment Support
- **Local Development (Minikube)** - PRIMARY: Single-node setup for learning and testing
- **Production (AWS EKS)** - OPTIONAL: Multi-AZ cluster with enterprise features

### Security Features
- **Pod Security Standards** - Namespace-level enforcement (baseline/restricted)
- **Network Policies** - Zero-trust networking with explicit allow rules
- **RBAC** - Least-privilege access control
- **Vault Integration** - Manual unseal (local) or KMS auto-unseal (AWS)

## 🛠️ Prerequisites

### For Local Development (Minikube)
**System Requirements:**
- RAM: 4GB minimum (8GB recommended)
- CPU: 2 cores minimum (4 cores recommended)
- Disk: 30GB free space

**Required Tools:**
- [Minikube](https://minikube.sigs.k8s.io/docs/start/) (v1.30+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (v1.33+)
- [Helm](https://helm.sh/docs/intro/install/) (v3.x)
- [Docker](https://docs.docker.com/get-docker/) (for Minikube driver)

**Optional:**
- ArgoCD CLI (v3.1+) - for CLI management
- Vault CLI - for Vault operations

### For AWS Deployment (Advanced)
See [AWS Deployment Guide](docs/aws-deployment.md) for complete requirements including AWS CLI, Terraform, and IAM permissions.

## 📁 Repository Structure

```
├── argo-apps/               # ArgoCD GitOps Configuration
│   ├── install/            # ArgoCD installation manifests
│   ├── projects/           # ArgoCD Projects (RBAC, repos, destinations)
│   └── apps/               # ArgoCD Applications (web-app, prometheus, grafana, vault)
├── helm-charts/             # Helm Charts & Values
│   ├── web-app/            # Custom web app Helm chart
│   ├── prometheus/         # Prometheus values (upstream chart: prometheus-community)
│   ├── grafana/            # Grafana values (upstream chart: grafana)
│   └── vault/              # Vault values (upstream chart: hashicorp)
├── terraform/               # Infrastructure as Code (Multi-Cloud Ready)
│   ├── environments/
│   │   └── aws/            # AWS-specific Terraform configuration
│   └── modules/            # Reusable Terraform modules (VPC, EKS, IAM)
├── .github/workflows/       # CI/CD Automation
│   ├── validate.yaml       # Validation on PR/push
│   ├── docs-lint.yaml      # Documentation quality checks
│   ├── terraform-plan.yaml # Infrastructure planning
│   ├── terraform-apply.yaml# Infrastructure deployment
│   ├── deploy-argocd.yaml  # Application deployment
│   └── security-scan.yaml  # Security scanning
├── scripts/                 # Deployment & Management Scripts
│   ├── deploy.sh           # Unified deployment interface
│   ├── setup-minikube.sh   # Minikube deployment
│   ├── setup-aws.sh        # AWS EKS deployment
│   ├── argocd-login.sh     # ArgoCD CLI login (cross-platform)
│   ├── validate.sh         # Comprehensive validation
│   └── cleanup.sh          # Safe file cleanup with backup
├── docs/                    # Comprehensive Documentation
│   ├── deployment.md       # Consolidated deployment guide
│   ├── architecture.md     # System architecture
│   ├── ci_cd_pipeline.md   # GitHub Actions documentation
│   ├── scripts.md          # Scripts usage guide
│   └── troubleshooting.md  # Common issues & solutions
└── reports/                 # Audit & Cleanup Reports
    ├── AUDIT_SUMMARY.md    # Repository audit summary
    └── CLEANUP_MANIFEST.md # File removal tracking
```

## 🚨 Common Issues Quick Reference

| Issue | Solution | Guide Link |
|-------|----------|------------|
| Vault pod not ready | Unseal Vault manually | [Vault Local Setup](docs/vault-local-setup.md#unsealing-vault) |
| PVC binding failed | Use `standard` storageClass | [Troubleshooting: PVC](docs/troubleshooting.md#vault-pvc-binding-issues) |
| Argo CD app stuck syncing | Hard refresh application | [Troubleshooting: Sync](docs/troubleshooting.md#application-not-syncing) |
| `/vault/data` permission error | Check init container logs | [Troubleshooting: Vault](docs/troubleshooting.md#vault-permission-errors) |

**More help:** See complete [Troubleshooting Guide](docs/troubleshooting.md)

## 🚦 Getting Started

1. **Start here**: [Local Deployment Guide](docs/local-deployment.md) - Get Minikube stack running
2. **Learn Vault**: [Vault Local Setup](docs/vault-local-setup.md) - Understand manual unsealing
3. **Troubleshoot**: [Troubleshooting Guide](docs/troubleshooting.md) - Fix common issues
4. **Advanced**: [AWS Deployment](docs/aws-deployment.md) - Deploy to production

## 🔧 Management Scripts

This repository includes streamlined scripts and Makefile targets for common operations:

### **Quick Commands via Makefile**

```bash
make help                    # Show all available commands (auto-generated)
make deploy-minikube         # Deploy complete stack to Minikube
make deploy-aws              # Deploy complete stack to AWS EKS
make validate-all            # Validate all components
make argo-login              # Login to ArgoCD CLI
make port-forward-argocd     # Access ArgoCD UI
make version                 # Show version information
```

### **Core Scripts**

**Deployment Script** (`scripts/deploy.sh`)
Unified interface for infrastructure and application deployment:
```bash
./scripts/deploy.sh terraform prod          # Deploy infrastructure
./scripts/deploy.sh bootstrap prod          # Bootstrap ArgoCD
./scripts/deploy.sh secrets monitoring      # Create secrets
./scripts/deploy.sh validate all            # Validate deployment
./scripts/deploy.sh sync prod               # Sync applications
```

**Setup Scripts**
Environment-specific automated deployment:
```bash
./scripts/setup-minikube.sh                 # Complete Minikube setup
./scripts/setup-aws.sh                      # Complete AWS EKS setup
```

**Validation Script** (`scripts/validate.sh`)
Comprehensive validation across all components:
```bash
./scripts/validate.sh all                   # Validate everything
./scripts/validate.sh apps                  # Validate ArgoCD apps
./scripts/validate.sh helm                  # Validate Helm charts
./scripts/validate.sh security              # Validate security configs
```

**ArgoCD CLI Login** (`scripts/argocd-login.sh`)
Automated ArgoCD CLI setup with cross-platform support:
```bash
./scripts/argocd-login.sh                   # Setup port-forward, login, and list apps
./scripts/argocd-login.sh --verbose         # Run with detailed logging
```

**Cross-Platform Support:**
- ✅ **Linux** - Native `argocd` binary
- ✅ **macOS** - Native `argocd` binary  
- ✅ **Windows Git Bash** - Automatic `argocd.exe` detection with intelligent wrapper
  - Auto-detects using `where.exe`
  - Tests direct execution and `cmd.exe` wrapper
  - Converts Windows paths to Git Bash format
  - See [ArgoCD CLI Setup](docs/argocd-cli-setup.md) for details

## 🤖 CI/CD Automation

**Status**: ⚠️ AWS workflows currently inactive (local development focus)

This repository includes **6 GitHub Actions workflows**:

- **validate.yaml** - YAML, Helm, Terraform validation
- **docs-lint.yaml** - Markdown linting and link checking
- **terraform-plan.yaml** - Infrastructure planning (AWS only)
- **terraform-apply.yaml** - Infrastructure deployment (AWS only)
- **deploy-argocd.yaml** - Application deployment automation
- **security-scan.yaml** - Security scanning and vulnerability checks

**Reactivation**: To use AWS workflows, configure GitHub secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY). See [CI/CD Pipeline Documentation](docs/ci_cd_pipeline.md) for details.

## 🔧 Maintenance

- **Update manifests** in the appropriate environment directories
- **Use consolidated scripts** for common operations (deploy, validate, secrets)
- **Monitor applications** through ArgoCD UI
- **Troubleshoot issues** using the troubleshooting guide
- **Validate configurations** before deployment using `./scripts/validate.sh`
- **Rotate secrets** regularly using `./scripts/secrets.sh rotate`
- **Scale resources** as needed for your workload

## 📝 Contributing

1. Make changes to the appropriate environment or application directories
2. Test changes in development environment first
3. Update documentation if needed
4. Submit pull request with clear description

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support & Help

- **Quick Start**: [Local Deployment Guide](docs/local-deployment.md) - 25 minute setup
- **Troubleshooting**: [Common Issues & Solutions](docs/troubleshooting.md)
- **Vault Help**: [Local Vault Setup](docs/vault-local-setup.md) - Manual unseal guide
- **Architecture**: [Repository Structure](docs/architecture.md)
- **Issues**: Use GitHub issues for bug reports

---

**Ready to start?** Follow the [Local Deployment Guide](docs/local-deployment.md) to get your stack running in ~25 minutes.

## Kubernetes v1.33.0 Compatibility Notes

- Updated APIs used:
  - networking.k8s.io/v1 for `Ingress`
  - autoscaling/v2 for `HorizontalPodAutoscaler`
  - batch/v1 for `CronJob` and `Job`
  - apps/v1 for `Deployment`
  - rbac.authorization.k8s.io/v1 for RBAC resources
  - networking.k8s.io/v1 for `NetworkPolicy`
- Removed/avoided deprecated resources and beta APIs (e.g., PodSecurityPolicy, v1beta1 variants)
- Helm templates and scripts validated with `kubectl --dry-run=client` and `helm lint`
- Use `scripts/validate.sh all` to run schema and best-practice checks.