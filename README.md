# Production-Ready EKS Cluster with GitOps

A comprehensive GitOps repository for deploying production-ready Kubernetes clusters on AWS EKS with ArgoCD, monitoring, and security best practices.

## 🚀 Quick Start

Choose your deployment target:

- **[Local Deployment](docs/local-deployment.md)** - Deploy on Minikube for development and testing
- **[AWS Deployment](docs/aws-deployment.md)** - Deploy on AWS EKS for production environments

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [**Architecture Guide**](docs/architecture.md) | Repository structure, GitOps flow, and environment overlays |
| [**Local Deployment**](docs/local-deployment.md) | Step-by-step instructions for Minikube/local clusters |
| [**AWS Deployment**](docs/aws-deployment.md) | Complete AWS EKS deployment guide |
| [**Troubleshooting**](docs/troubleshooting.md) | Common issues and solutions |

## 🏗️ What's Included

### Core Components
- **ArgoCD** - GitOps continuous delivery
- **Prometheus & Grafana** - Monitoring and alerting
- **Vault** - Secrets management (optional)
- **Web Application** - Sample Node.js app with Helm charts

### Environments
- **Development** - Local testing with Minikube
- **Staging** - Pre-production validation
- **Production** - AWS EKS with full security

### Security Features
- Pod Security Standards
- Network Policies
- RBAC configurations
- Vault integration for secrets

## 🛠️ Prerequisites

### For Local Deployment
- Minikube or similar local Kubernetes
- kubectl, helm, and ArgoCD CLI
- yq for YAML processing

### For AWS Deployment
- AWS CLI v2, Terraform, kubectl
- AWS account with appropriate permissions
- yq for configuration management

## 📁 Repository Structure

```
├── environments/           # Environment-specific configurations
│   ├── dev/               # Development environment
│   ├── staging/           # Staging environment
│   └── prod/              # Production environment
├── applications/          # Application deployments
│   ├── monitoring/        # Prometheus & Grafana
│   ├── infrastructure/    # Infrastructure components
│   └── web-app/          # Web application stack
├── bootstrap/            # Initial cluster setup
├── infrastructure/       # Terraform for AWS resources
├── config/               # Common configuration files
├── scripts/              # Consolidated management scripts
└── docs/                # Consolidated documentation
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

### **Configuration Management** (`scripts/config.sh`)
Environment-specific configuration handling:
```bash
./scripts/config.sh generate --environment prod  # Generate configs
./scripts/config.sh validate --environment prod  # Validate configs
./scripts/config.sh merge --environment prod     # Merge configs
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