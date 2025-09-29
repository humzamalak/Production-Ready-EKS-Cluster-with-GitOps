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
│   └── 📁 security/                # Security applications
│       ├── 📄 app-of-apps.yaml     # Security stack bootstrap
│       └── 📁 vault/               # HashiCorp Vault
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

### Prerequisites

- Kubernetes cluster (EKS recommended)
- ArgoCD installed and configured
- kubectl configured with cluster access

### 1. Bootstrap Core (see DEPLOYMENT_GUIDE.md for full steps)

```bash
# Core namespaces, security, Argo CD
kubectl apply -f bootstrap/00-namespaces.yaml
kubectl apply -f bootstrap/01-pod-security-standards.yaml
kubectl apply -f bootstrap/02-network-policy.yaml
kubectl apply -f bootstrap/04-argo-cd-install.yaml
kubectl apply -f bootstrap/05-vault-policies.yaml
kubectl apply -f bootstrap/06-etcd-backup.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### 2. Deploy Applications

```bash
# Apply the root application (app-of-apps pattern)
kubectl apply -f clusters/production/app-of-apps.yaml

# ArgoCD will automatically discover and deploy all applications in sync waves:
# Wave 1: Production cluster bootstrap
# Wave 2: Monitoring stack (Prometheus, Grafana)
# Wave 3: Security stack (Vault)
```

### 3. Access Applications

#### ArgoCD UI
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access: https://localhost:8080 (admin / get password with kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
```

#### Prometheus
```bash
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus -n monitoring 9090:9090
# Access: http://localhost:9090
```

#### Grafana
```bash
kubectl port-forward svc/grafana -n monitoring 3000:80
# Access: http://localhost:3000 (admin / changeme)
```

#### Vault
```bash
kubectl port-forward svc/vault -n vault 8200:8200
# Access: https://localhost:8200
```

## 📋 Applications Managed

### Monitoring Stack
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Dashboards and visualization
- **AlertManager**: Alert routing and notification

### Security Stack
- **HashiCorp Vault**: Secrets management
- **Vault Agent Injector**: Pod-level secret injection without Kubernetes Secret objects

## 🔧 Configuration

### Customizing Applications

1. **Modify Helm Values**: Edit values files in application directories
2. **Add New Applications**: Create new directories under `applications/`
3. **Environment-Specific Configs**: Use `clusters/` for environment differences

### Required Customizations

Before deploying, update the following:

1. **Repository URL**: Update `repoURL` in `clusters/production/app-of-apps.yaml`
2. **Domain Names**: Update ingress hosts in application manifests
3. **AWS Account ID**: Update IAM role ARNs in Vault configuration
4. **TLS Certificates**: Configure cert-manager or provide your own certificates

### Quick Configuration Script

For easy setup, use the provided configuration script:

```bash
# Run the interactive configuration script
./examples/scripts/configure-deployment.sh
```

## 🔒 Security Features

- **Pod Security Standards**: Restricted mode enforced
- **Network Policies**: Traffic isolation between components
- **RBAC**: Role-based access control
- **External Secrets**: Secure secret management via Vault
- **TLS Encryption**: All communications encrypted

## 📚 Documentation

- [Deployment Guide](DEPLOYMENT_GUIDE.md) - Comprehensive deployment instructions
- [AWS Deployment Guide](AWS_DEPLOYMENT_GUIDE.md) - AWS-specific setup
- [Minikube Guide](MINIKUBE_DEPLOYMENT_GUIDE.md) - Local development setup
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
- [GitOps Structure](docs/gitops-structure.md) - Detailed repository structure guide
- [Security Best Practices](docs/security-best-practices.md) - Security guidelines
- [Disaster Recovery](docs/disaster-recovery-runbook.md) - Disaster recovery procedures
- [Changelog](docs/CHANGELOG.md) - Version history and changes

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