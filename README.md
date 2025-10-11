<!-- Docs Update: 2025-10-05 — Verified structure, scripts, and cross-links. Keep high-level only. -->
# Production-Ready EKS Cluster with GitOps

> Compatibility: Kubernetes v1.33.0 (validated). See section below for notes.

A comprehensive GitOps repository for deploying production-ready Kubernetes clusters on AWS EKS with ArgoCD, monitoring, and security best practices.

## 🚀 Quick Start

Choose your deployment path based on your target environment:

- **[Local Deployment](docs/local-deployment.md)** - Deploy on Minikube for development and testing
- **[AWS Deployment](docs/aws-deployment.md)** - Deploy on AWS EKS for production environments
- **[Architecture Guide](docs/architecture.md)** - Understand the repository structure and GitOps patterns

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [**Architecture Guide**](docs/architecture.md) | Repository structure, GitOps flow, and environment overlays |
| [**Local Deployment**](docs/local-deployment.md) | Step-by-step instructions for Minikube/local clusters |
| [**AWS Deployment**](docs/aws-deployment.md) | Complete AWS EKS deployment guide with Terraform |
| [**ArgoCD CLI Setup**](docs/argocd-cli-setup.md) | Automated ArgoCD CLI access for Windows Git Bash |
| [**Troubleshooting**](docs/troubleshooting.md) | Common issues and solutions with detailed diagnostics |
| [**K8s Version Policy**](docs/K8S_VERSION_POLICY.md) | Kubernetes version compatibility and upgrade guidelines |
| [**Changelog**](CHANGELOG.md) | Complete version history and migration guides |

## 🏗️ What's Included

### Core Infrastructure Components
- **🚀 ArgoCD v3.1.0** - GitOps continuous delivery with automated synchronization
- **📊 Prometheus & Grafana** - Comprehensive monitoring, metrics, and alerting
- **🔐 Vault** - HashiCorp Vault for secrets management (optional, documented for future integration)
- **📦 Sample Web Application** - Production-ready Node.js app with complete Helm charts

### Multi-Environment Support
- **Development** - Local Kubernetes (Minikube) for rapid iteration and testing
- **Staging** - Pre-production environment for validation and integration testing
- **Production** - AWS EKS with enterprise-grade security and high availability

### Security & Compliance
- **Pod Security Standards** - Enforced at namespace level (baseline/restricted policies)
- **Network Policies** - Default-deny with explicit allow rules for zero-trust networking
- **RBAC** - Role-based access control with least-privilege principles
- **Secrets Management** - Documentation and integration points for Vault
- **Encryption** - KMS-based encryption for EKS secrets and EBS volumes

## 🛠️ Prerequisites

### For Local Deployment
- Minikube or similar local Kubernetes (k8s v1.33.0)
- kubectl (v1.33+), helm (v3.x), ArgoCD CLI (v3.1+)
- yq for YAML processing

### For AWS Deployment
- AWS CLI v2, Terraform (v1.5+), kubectl (v1.33+)
- ArgoCD CLI (v3.1+)
- AWS account with appropriate permissions
- yq for configuration management

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

## 🚦 Getting Started

1. **Choose your deployment target** from the documentation above
2. **Follow the step-by-step guide** for your chosen environment
3. **Verify deployment** using the provided validation scripts
4. **Access applications** through the provided URLs

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

This repository includes **6 GitHub Actions workflows** for automated validation and deployment:

- **validate.yaml** - YAML, Helm, Terraform, and ArgoCD validation on every PR
- **docs-lint.yaml** - Markdown linting and broken link detection
- **terraform-plan.yaml** - Automatic Terraform plan on PRs with policy checks
- **terraform-apply.yaml** - Automated infrastructure deployment with version tagging
- **deploy-argocd.yaml** - Application deployment and sync automation
- **security-scan.yaml** - Container scanning, dependency checks, and security linting

See [CI/CD Pipeline Documentation](docs/ci_cd_pipeline.md) for details.

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

## 🆘 Support

- **Documentation**: Check the [docs/](docs/) directory
- **Issues**: Use GitHub issues for bug reports
- **Troubleshooting**: See [troubleshooting guide](docs/troubleshooting.md)

---

**Ready to deploy?** Start with [Local Deployment](docs/local-deployment.md) or [AWS Deployment](docs/aws-deployment.md).

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