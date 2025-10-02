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
| **Phase 4** | Vault Deployment | Vault server and agent injector | ⚠️ **Optional** |
| **Phase 5** | Vault Configuration | **Critical**: Initialize, policies, secrets | ⚠️ **Optional** |
| **Phase 6** | Web App Deployment | Deploy application WITHOUT secrets | Required |
| **Phase 7** | Vault Integration | Add Vault secrets to running application | ⚠️ **Optional** |

> **💡 Note:** Vault (Phases 4-5-7) is optional. You can deploy monitoring and applications first, then add Vault later when needed.

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
- Terraform >=1.5.0
- kubectl v1.33+
- Helm v3.12+

#### For Minikube:
- Docker Desktop
- Minikube
- kubectl v1.33+
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

- **[Application Access Guide](APPLICATION_ACCESS_GUIDE.md)** - Comprehensive guide for Prometheus, Grafana, Vault, and ArgoCD
- **[Project Structure Guide](docs/PROJECT_STRUCTURE.md)** - Comprehensive overview of the repository structure
- **[Vault Setup Guide](docs/VAULT_SETUP_GUIDE.md)** - Detailed Vault configuration and troubleshooting
- **[Security Best Practices](docs/security-best-practices.md)** - Security guidelines and recommendations
- **[Disaster Recovery Runbook](docs/disaster-recovery-runbook.md)** - Backup and recovery procedures
- **[GitOps Structure](docs/gitops-structure.md)** - GitOps architecture and patterns
- **[Changelog](docs/CHANGELOG.md)** - Version history and changes

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

# Vault
kubectl port-forward svc/vault -n vault 8200:8200 &
# Access: http://localhost:8200
```

### 🌐 Access the Web App

After `k8s-web-app` is Synced and Healthy in Argo CD, you can access it via:

#### Option A: Ingress (Production)

1) Get the Ingress address
```bash
kubectl get ingress k8s-web-app -n production
```
2) Point your DNS `A`/`CNAME` record to the address and update `helm/values.yaml` host if needed (`ingress.hosts[0].host`).
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