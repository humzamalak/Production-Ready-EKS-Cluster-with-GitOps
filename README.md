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
│   ├── 📁 security/                # Security applications (optional)
│   │   ├── 📄 app-of-apps.yaml     # Security stack bootstrap (optional)
│   │   └── 📁 vault/               # HashiCorp Vault (optional; currently disabled by default)
│   └── 📁 web-app/                 # Web application deployments
│       ├── 📄 namespace.yaml       # Production namespace
│       └── 📁 k8s-web-app/         # Node.js web application
│           └── 📁 helm/            # Helm chart
│               └── 📄 values.yaml  # Single consolidated values (Vault optional)
├── 📁 bootstrap/                   # Bootstrap manifests
│   ├── 📄 00-namespaces.yaml       # Core namespaces with PSS labels
│   ├── 📄 01-pod-security-standards.yaml # Security standards
│   ├── 📄 02-network-policy.yaml   # Network policies
│   ├── 📄 03-helm-repos.yaml       # Helm repository configurations
│   ├── 📄 04-argo-cd-install.yaml  # ArgoCD installation (Helm-based)
│   ├── 📄 05-vault-policies.yaml   # Vault policies and authentication
│   ├── 📄 06-etcd-backup.yaml      # etcd backup cronjob
│   └── 📁 helm-values/             # Helm values for bootstrap components
│       └── 📄 argo-cd-values.yaml  # Production ArgoCD configuration
├── 📁 infrastructure/              # Infrastructure as Code (Terraform)
├── 📁 examples/                    # Example applications and scripts
└── 📁 docs/                        # Documentation
```

## 🚀 Quick Start

### 📖 Deployment Guides

Choose your deployment platform:

- **[AWS EKS Deployment Guide](AWS_DEPLOYMENT_GUIDE.md)** - Complete production deployment on AWS (7 phases, ~65 min)
- **[Minikube Deployment Guide](MINIKUBE_DEPLOYMENT_GUIDE.md)** - Local development environment (7 phases, ~45 min)

Both guides follow a **7-phase approach** to ensure reliable deployment:

| Phase | Component | Purpose | Optional |
|-------|-----------|---------|----------|
| **Phase 1** | Infrastructure | Cluster setup and configuration | Required |
| **Phase 2** | Bootstrap | ArgoCD and GitOps foundation | Required |
| **Phase 3** | Monitoring | Prometheus and Grafana | Required |
| **Phase 4** | Vault Deployment | Vault server and agent injector | ⚠️ **Optional (disabled by default)** |
| **Phase 5** | Vault Configuration | **Critical**: Initialize, policies, secrets | ⚠️ **Optional (disabled by default)** |
| **Phase 6** | Web App Deployment | Deploy application WITHOUT secrets | Required |
| **Phase 7** | Vault Integration | Add Vault secrets to running application | ⚠️ **Optional** |

> **💡 Note:** Vault (Phases 4-5-7) is optional and currently disabled by default in this repo. Deploy monitoring and applications first; add Vault later when ready.

**Key Features:**
- ✅ Built-in verification at each phase
- ✅ Deploy applications first, add secrets later
- ✅ Prevents Vault initialization issues
- ✅ Zero-downtime Vault integration
- ✅ Clear separation of deployment concerns
- ✅ Comprehensive troubleshooting with ArgoCD error solutions

### Prerequisites

#### For AWS EKS:
- AWS CLI configured with appropriate permissions
- Terraform >=1.4.0
- kubectl v1.31+
- Helm v3.18+

#### For Minikube:
- Docker Desktop
- Minikube
- kubectl v1.31+
- Helm v3.18+

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

- **[Application Access Guide](APPLICATION_ACCESS_GUIDE.md)** - Comprehensive guide for Prometheus, Grafana, ArgoCD, and optional Vault
- **[Project Structure Guide](docs/PROJECT_STRUCTURE.md)** - Comprehensive overview of the repository structure
- **[Vault Setup Guide](docs/VAULT_SETUP_GUIDE.md)** - Detailed Vault configuration and troubleshooting
- **[Security Best Practices](docs/security-best-practices.md)** - Security guidelines and recommendations
- **[Disaster Recovery Runbook](docs/disaster-recovery-runbook.md)** - Backup and recovery procedures
- **[Changelog](CHANGELOG.md)** - Version history and changes
- **[Pull Request Summary](PULL_REQUEST_SUMMARY.md)** - Recent fixes and improvements
- **[Documentation Update Summary](DOCUMENTATION_UPDATE_SUMMARY.md)** - Documentation changes and updates

## 🔧 Application Access

After deployment, access your applications:

#### Quick Access
```bash
# ArgoCD UI
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443 &
# Access: https://localhost:8080 (admin / password from secret)

# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus -n monitoring 9090:9090 &
# Access: http://localhost:9090

# Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80 &
# Access: http://localhost:3000 (admin / password from secret)

# Vault (optional; only if enabled)
# kubectl port-forward svc/vault -n vault 8200:8200 &
# Access: http://localhost:8200
```

### 🌐 Access the Web App

After `k8s-web-app` is Synced and Healthy in Argo CD, you can access it via:

#### Option A: Ingress (Production)

1) Get the Ingress address
```bash
kubectl get ingress k8s-web-app -n production
```
2) Point your DNS `A`/`CNAME` record to the address and update `applications/web-app/k8s-web-app/helm/values.yaml` host if needed (`ingress.hosts[0].host`).
3) Browse to: https://<your-host>

#### Option B: Port-forward (Quick test)
```bash
kubectl port-forward svc/k8s-web-app -n production 8081:80 &
echo "Web App: http://localhost:8081"
curl -s http://localhost:8081/health
```

### 📖 Comprehensive Access Guide

For detailed usage guides including PromQL queries, Grafana dashboards, Vault secret management, and more:

**→ [Application Access Guide](APPLICATION_ACCESS_GUIDE.md)**

This guide covers:
- **Prometheus**: PromQL queries, targets, alerts, metrics API
- **Grafana**: Dashboard creation, data sources, importing community dashboards
- **Vault**: Secret CRUD operations, policies, Kubernetes auth, audit logs
- **ArgoCD**: Application management, CLI operations, sync strategies
- **Troubleshooting**: Common access and connectivity issues

## 📋 Applications Managed

### Monitoring Stack
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Dashboards and visualization  
- **AlertManager**: Alert routing and notification

### Security Stack (optional)
- **HashiCorp Vault**: Secrets management with agent injection (currently disabled by default)
- **Pod Security Standards**: Restricted security contexts
- **Network Policies**: Traffic isolation between components

### Web Application
- **Node.js Application**: Production-ready with health checks and security contexts
- **Auto-scaling**: Horizontal Pod Autoscaler configuration
- **Vault Integration**: Enhanced with environment variable support and improved security practices
- **Security**: Pod Security Standards, network policies, and proper RBAC configurations

## 🔒 Security Features

- **Pod Security Standards**: Restricted mode enforced
- **Network Policies**: Traffic isolation between components
- **RBAC**: Role-based access control
- **Vault Agent Injection**: Secure secret management without Kubernetes Secrets (when Vault is enabled)
- **TLS Encryption**: All communications encrypted

## 🏷️ GitOps Principles

This repository follows GitOps best practices:

- ✅ **Declarative**: All desired state defined in Git
- ✅ **Versioned**: All changes tracked in version control
- ✅ **Automated**: Continuous reconciliation with desired state
- ✅ **Observable**: Full audit trail of all changes
- ✅ **Secure**: Immutable infrastructure with proper access controls
- ✅ **Production-Ready**: Enhanced security, reliability, and maintainability

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following GitOps principles
4. Follow YAML linting standards (`.yamllint` configuration)
5. Test in a development environment
6. Update documentation as needed
7. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [ArgoCD](https://argoproj.github.io/cd/) - GitOps continuous delivery
- [Prometheus](https://prometheus.io/) - Monitoring and alerting
- [Grafana](https://grafana.com/) - Observability platform
- [HashiCorp Vault](https://www.vaultproject.io/) - Secrets management