# GitOps Repository - Production-Ready EKS Cluster

This repository follows GitOps principles to manage a production-ready EKS cluster with monitoring, security, and observability components.

## 🏗️ Repository Structure

```
├── 📁 clusters/                    # Environment-specific configurations
│   └── 📁 production/              # Production cluster configuration
│       ├── 📄 app-of-apps.yaml     # Root application bootstrap
│       ├── 📄 namespaces.yaml      # Required namespaces
│       └── 📄 production-apps-project.yaml # ArgoCD project config
├── 📁 applications/                # Application definitions
│   ├── 📁 monitoring/              # Monitoring stack applications
│   │   ├── 📄 app-of-apps.yaml     # Monitoring stack bootstrap
│   │   ├── 📁 prometheus/          # Prometheus monitoring
│   │   └── 📁 grafana/             # Grafana dashboards
│   ├── 📁 security/                # Security applications
│   │   ├── 📄 app-of-apps.yaml     # Security stack bootstrap
│   │   └── 📁 vault/               # HashiCorp Vault
│   └── 📁 web-app/                 # Web application deployments
│       ├── 📄 app-of-apps.yaml     # Web app stack bootstrap
│       ├── 📄 namespace.yaml       # Production namespace
│       └── 📁 k8s-web-app/         # Node.js web application
├── 📁 bootstrap/                   # Bootstrap manifests
│   ├── 📄 00-namespaces.yaml       # Core namespaces with PSS labels
│   ├── 📄 01-pod-security-standards.yaml # Security standards
│   ├── 📄 02-network-policy.yaml   # Network policies
│   ├── 📄 05-argo-cd-install.yaml  # Argo CD installation
│   ├── 📄 20-etcd-backup.yaml      # etcd backup cronjob
│   └── 📁 helm-values/             # Helm values (not applied via kubectl)
├── 📁 infrastructure/              # Infrastructure as Code (Terraform)
├── 📁 examples/                    # Example applications and scripts
└── 📁 docs/                        # Documentation
```

## 🚀 Quick Start

Choose your deployment platform and follow the comprehensive step-by-step guide:

### 📖 Deployment Guides

- **[AWS EKS Deployment Guide](AWS_DEPLOYMENT_GUIDE.md)** - Complete production deployment on AWS
- **[Minikube Deployment Guide](MINIKUBE_DEPLOYMENT_GUIDE.md)** - Local development environment

Both guides cover:
- **Infrastructure Setup**: Creating cluster and supporting resources
- **GitOps Bootstrap**: Installing ArgoCD and core components  
- **Monitoring Stack**: Deploying Prometheus and Grafana
- **Security Stack**: Setting up Vault with agent injection
- **Web Application**: Deploying production-ready Node.js app
- **Verification**: Testing all components and access

### Prerequisites

#### For AWS EKS:
- AWS CLI configured with appropriate permissions
- Terraform >=1.5.0
- kubectl v1.28+
- Helm v3.12+

#### For Minikube:
- Docker Desktop
- Minikube
- kubectl v1.28+
- Helm v3.12+

### Quick Start Commands

#### AWS EKS:
```bash
# Clone repository
git clone https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps.git
cd Production-Ready-EKS-Cluster-with-GitOps

# Follow the AWS Deployment Guide
open AWS_DEPLOYMENT_GUIDE.md
```

#### Minikube:
```bash
# Clone repository
git clone https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps.git
cd Production-Ready-EKS-Cluster-with-GitOps

# Follow the Minikube Deployment Guide
open MINIKUBE_DEPLOYMENT_GUIDE.md
```

## 📚 Documentation

- **[Project Structure Guide](docs/PROJECT_STRUCTURE.md)** - Comprehensive overview of the repository structure
- **[Vault Setup Guide](docs/VAULT_SETUP_GUIDE.md)** - Detailed Vault configuration and troubleshooting
- **[Security Best Practices](docs/security-best-practices.md)** - Security guidelines and recommendations
- **[Disaster Recovery Runbook](docs/disaster-recovery-runbook.md)** - Backup and recovery procedures
- **[GitOps Structure](docs/gitops-structure.md)** - GitOps architecture and patterns
- **[Changelog](docs/CHANGELOG.md)** - Version history and changes

## 🔧 Application Access

After deployment, access your applications:

#### ArgoCD UI
```bash
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443
# Access: https://localhost:8080 (admin / password from secret)
```

#### Prometheus
```bash
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus -n monitoring 9090:9090
# Access: http://localhost:9090
```

#### Grafana
```bash
kubectl port-forward svc/grafana -n monitoring 3000:80
# Access: http://localhost:3000 (admin / password from secret)
```

#### Vault
```bash
kubectl port-forward svc/vault -n vault 8200:8200
# Access: http://localhost:8200 (root / root)
```

## 📋 Applications Managed

### Monitoring Stack
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Dashboards and visualization  
- **AlertManager**: Alert routing and notification

### Security Stack
- **HashiCorp Vault**: Secrets management with agent injection
- **Pod Security Standards**: Restricted security contexts
- **Network Policies**: Traffic isolation between components

### Web Application
- **Node.js Application**: Production-ready with health checks
- **Auto-scaling**: Horizontal Pod Autoscaler configuration
- **Vault Integration**: Automatic secret injection

## 🔒 Security Features

- **Pod Security Standards**: Restricted mode enforced
- **Network Policies**: Traffic isolation between components
- **RBAC**: Role-based access control
- **Vault Agent Injection**: Secure secret management without Kubernetes Secrets
- **TLS Encryption**: All communications encrypted

## 🏷️ GitOps Principles

This repository follows GitOps best practices:

- ✅ **Declarative**: All desired state defined in Git
- ✅ **Versioned**: All changes tracked in version control
- ✅ **Automated**: Continuous reconciliation with desired state
- ✅ **Observable**: Full audit trail of all changes
- ✅ **Secure**: Immutable infrastructure with proper access controls

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following GitOps principles
4. Test in a development environment
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [ArgoCD](https://argoproj.github.io/cd/) - GitOps continuous delivery
- [Prometheus](https://prometheus.io/) - Monitoring and alerting
- [Grafana](https://grafana.com/) - Observability platform
- [HashiCorp Vault](https://www.vaultproject.io/) - Secrets management