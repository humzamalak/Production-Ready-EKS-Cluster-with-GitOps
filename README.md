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
| [**Troubleshooting**](docs/troubleshooting.md) | Common issues and solutions with detailed diagnostics |
| [**K8s Version Policy**](docs/K8S_VERSION_POLICY.md) | Kubernetes version compatibility and upgrade guidelines |
| [**Changelog**](CHANGELOG.md) | Complete version history and migration guides |

## 🏗️ What's Included

### Core Infrastructure Components
- **🚀 ArgoCD** - GitOps continuous delivery with automated synchronization
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
- kubectl, helm, and ArgoCD CLI
- yq for YAML processing

### For AWS Deployment
- AWS CLI v2, Terraform, kubectl (>=1.33)
- AWS account with appropriate permissions
- yq for configuration management

## 📁 Repository Structure

```
├── argocd/                  # ArgoCD GitOps Configuration
│   ├── install/            # ArgoCD installation manifests
│   ├── projects/           # ArgoCD Projects (RBAC, repos, destinations)
│   └── apps/               # ArgoCD Applications (web-app, prometheus, grafana, vault)
├── apps/                    # Application Helm Charts & Values
│   ├── web-app/            # Custom web app Helm chart
│   ├── prometheus/         # Prometheus values (default, minikube, AWS)
│   ├── grafana/            # Grafana values (default, minikube, AWS)
│   └── vault/              # Vault values (default, minikube, AWS)
├── infrastructure/          # Terraform for AWS EKS
│   └── terraform/          # Terraform modules (VPC, EKS, IAM)
├── scripts/                 # Deployment & management scripts
│   ├── setup-minikube.sh   # Minikube deployment
│   ├── setup-aws.sh        # AWS EKS deployment
│   ├── deploy.sh           # Unified deployment interface
│   ├── validate.sh         # Validation script
│   └── secrets.sh          # Secrets management
└── docs/                    # Comprehensive documentation
```

## 🚦 Getting Started

1. **Choose your deployment target** from the documentation above
2. **Follow the step-by-step guide** for your chosen environment
3. **Verify deployment** using the provided validation scripts
4. **Access applications** through the provided URLs

## 🔧 Management Scripts

This repository includes consolidated management scripts for common operations:

### **Deployment Script** (`scripts/deploy.sh`)
Unified interface for deploying and managing infrastructure:
```bash
./scripts/deploy.sh terraform prod          # Deploy infrastructure
./scripts/deploy.sh bootstrap prod          # Bootstrap ArgoCD
./scripts/deploy.sh secrets monitoring      # Create secrets
./scripts/deploy.sh validate all            # Validate deployment
./scripts/deploy.sh sync prod               # Sync applications
```

### **Validation Script** (`scripts/validate.sh`)
Comprehensive validation across all components:
```bash
./scripts/validate.sh all                   # Validate everything
./scripts/validate.sh apps                  # Validate ArgoCD apps
./scripts/validate.sh helm                  # Validate Helm charts
./scripts/validate.sh security              # Validate security configs
```

### **Secrets Management** (`scripts/secrets.sh`)
Complete secrets lifecycle management:
```bash
./scripts/secrets.sh create monitoring      # Create secrets
./scripts/secrets.sh rotate web-app         # Rotate secrets
./scripts/secrets.sh verify all             # Verify secrets
./scripts/secrets.sh backup vault           # Backup secrets
```

### **ArgoCD Diagnostics** (`scripts/argo-diagnose.sh`)
ArgoCD connection and diagnostic tool:
```bash
./scripts/argo-diagnose.sh                       # Connect to ArgoCD and list apps
```

### **Makefile Targets**
Convenient Make targets for common operations:
```bash
make validate-all                           # Validate all components
make create-secrets                         # Create all secrets
make deploy-infra ENV=prod                  # Deploy infrastructure
make bootstrap-cluster ENV=prod             # Bootstrap cluster
make generate-config ENV=prod               # Generate configurations
```

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