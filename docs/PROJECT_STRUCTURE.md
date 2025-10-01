# Project Structure Guide

This document provides a comprehensive overview of the cleaned-up and logical project structure for the Production-Ready EKS Cluster with GitOps.

## 🏗️ **Overall Architecture**

The project follows a **GitOps pattern** with clear separation of concerns:

```
Production-Ready-EKS-Cluster-with-GitOps/
├── bootstrap/           # Initial cluster setup and foundational components
├── clusters/           # Environment-specific configurations
├── applications/       # Application deployments organized by domain
├── examples/          # Sample applications and reference implementations
├── infrastructure/    # Terraform modules for AWS infrastructure
├── docs/             # Comprehensive documentation
└── .github/          # CI/CD workflows and automation
```

## 📁 **Directory Structure**

### **`bootstrap/`** - Foundation Layer
**Purpose**: Initial cluster setup and core infrastructure components

```
bootstrap/
├── 00-namespaces.yaml              # Namespace definitions
├── 01-pod-security-standards.yaml # Pod Security Standards
├── 02-network-policy.yaml         # Default network policies
├── 03-helm-repos.yaml            # Helm repository configurations
├── 04-argo-cd-install.yaml       # ArgoCD installation
├── 05-vault-policies.yaml        # Vault policies and authentication
├── 06-etcd-backup.yaml           # etcd backup configuration
├── helm-values/                  # Helm values for bootstrap components
│   └── argo-cd-values.yaml
└── README.md                     # Bootstrap documentation
```

**Key Features**:
- ✅ Numeric prefixes enforce apply order
- ✅ Self-contained foundational components
- ✅ No application-specific configurations

### **`clusters/`** - Environment Configurations
**Purpose**: Environment-specific settings and application discovery

```
clusters/
└── production/                    # Production environment
    ├── app-of-apps.yaml          # Root application discovery
    ├── namespaces.yaml           # Production namespaces
    ├── production-apps-project.yaml # ArgoCD project configuration
    └── README.md                 # Production environment guide
```

**Key Features**:
- ✅ Environment isolation
- ✅ ArgoCD application discovery
- ✅ Environment-specific configurations

### **`applications/`** - Application Deployments
**Purpose**: Organized application deployments by domain

```
applications/
├── monitoring/                   # Monitoring stack
│   ├── grafana/
│   │   └── application.yaml     # Grafana deployment
│   └── prometheus/
│       └── application.yaml     # Prometheus deployment
├── security/                    # Security components
│   └── vault/                   # Vault deployment
│       ├── application.yaml     # Vault application
│       ├── values.yaml          # Production Vault config
│       └── values-dev.yaml      # Development Vault config
└── web-app/                     # Web application
    ├── setup-vault-secrets.sh   # Vault configuration script
    ├── VAULT_INTEGRATION.md     # Vault integration guide
    ├── README.md               # Web app documentation
    └── k8s-web-app/            # Web app Helm chart
        ├── application.yaml     # ArgoCD application
        ├── values.yaml          # Production values
        ├── validate-vault.sh    # Vault validation script
        └── helm/               # Helm chart
            ├── Chart.yaml
            ├── values.yaml
            └── templates/
                ├── deployment.yaml
                ├── service.yaml
                ├── ingress.yaml
                ├── hpa.yaml
                ├── serviceaccount.yaml
                ├── networkpolicy.yaml
                ├── servicemonitor.yaml
                └── vault-agent.yaml
```

**Key Features**:
- ✅ Domain-based organization
- ✅ Self-contained application stacks
- ✅ Production-ready configurations
- ✅ Vault integration with agent injection

### **`examples/`** - Reference Implementations
**Purpose**: Sample applications and development references

```
examples/
└── web-app/                     # Sample web application
    ├── server.js               # Express.js application
    ├── package.json            # Node.js dependencies
    ├── Dockerfile             # Container definition
    ├── build-and-push.sh      # CI/CD script
    ├── DOCKERHUB_SETUP.md     # Container registry setup
    ├── README.md              # Development guide
    ├── k8s/                   # Basic Kubernetes manifests
    │   ├── service.yaml
    │   ├── ingress.yaml
    │   └── hpa.yaml
    └── values/                # Example values
        └── k8s-web-app-values.yaml
```

**Key Features**:
- ✅ Development and testing reference
- ✅ Basic Kubernetes manifests
- ✅ Container build examples
- ✅ **Note**: Production manifests moved to `applications/`

### **`infrastructure/`** - AWS Infrastructure
**Purpose**: Terraform modules for AWS resources

```
infrastructure/
└── terraform/                  # Terraform configuration
    ├── modules/               # Reusable Terraform modules
    │   ├── vpc/              # VPC and networking
    │   ├── eks/              # EKS cluster
    │   ├── iam/              # IAM roles and policies
    │   └── backup/           # Backup configurations
    └── README.md             # Infrastructure documentation
```

### **`docs/`** - Documentation
**Purpose**: Comprehensive project documentation

```
docs/
├── CHANGELOG.md               # Version history and changes
├── VAULT_SETUP_GUIDE.md      # Comprehensive Vault setup guide
├── gitops-structure.md       # GitOps architecture documentation
├── security-best-practices.md # Security guidelines
└── disaster-recovery-runbook.md # Disaster recovery procedures
```

## 🔄 **GitOps Workflow**

### **1. Bootstrap Phase**
```bash
# Apply foundational components in order
kubectl apply -f bootstrap/00-namespaces.yaml
kubectl apply -f bootstrap/01-pod-security-standards.yaml
kubectl apply -f bootstrap/02-network-policy.yaml
kubectl apply -f bootstrap/03-helm-repos.yaml
kubectl apply -f bootstrap/04-argo-cd-install.yaml
kubectl apply -f bootstrap/05-vault-policies.yaml
kubectl apply -f bootstrap/06-etcd-backup.yaml
```

This sets up:
- ArgoCD installation
- Helm repositories
- Security policies
- Vault integration components

### **2. Application Deployment Phase**
```bash
# Apply root application
kubectl apply -f clusters/production/app-of-apps.yaml
```

This triggers:
- Namespace creation
- Application discovery
- Automated deployment
- Continuous reconciliation

### **3. Application Management Phase**

Applications are managed through:
- Git commits (declarative changes)
- ArgoCD UI (observability)
- Automated reconciliation
- Health monitoring

## 🎯 **GitOps Principles Applied**

### **1. Declarative Configuration**
- All desired state defined in YAML manifests
- No imperative commands required
- Version-controlled configurations

### **2. Version Control**
- All changes tracked in Git
- Immutable infrastructure
- Audit trail for all changes

### **3. Automated Reconciliation**
- ArgoCD continuously monitors Git
- Automatic drift detection and correction
- Self-healing capabilities

### **4. Observable**
- ArgoCD UI for application status
- Prometheus metrics for monitoring
- Grafana dashboards for observability

## 🔧 **Application Structure**

### **App-of-Apps Pattern**

The repository uses a single root App-of-Apps to discover child applications directly:

```
Root App (clusters/production/app-of-apps.yaml)
├── Prometheus (applications/monitoring/prometheus/application.yaml)
├── Grafana (applications/monitoring/grafana/application.yaml)
├── Vault (applications/security/vault/application.yaml)
└── K8s Web App (applications/web-app/k8s-web-app/application.yaml)
```

### **Sync Waves**

Applications are deployed in waves using ArgoCD sync waves:

1. **Wave 1**: Root application and namespaces
2. **Wave 2**: Monitoring stack
3. **Wave 3**: Security stack
4. **Wave 3.5**: Vault initialization
5. **Wave 5**: Web applications

This ensures proper dependency ordering.

## 🚀 **Adding New Applications**

### **1. Create Application Directory**
```bash
mkdir -p applications/new-stack/new-app
```

### **2. Create Application Manifest**
```yaml
# applications/new-stack/new-app/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: new-app
  namespace: argocd
spec:
  project: production-apps
  source:
    repoURL: https://github.com/your-org/your-repo
    chart: your-chart
    targetRevision: 1.0.0
  destination:
    server: https://kubernetes.default.svc
    namespace: your-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### **3. Update App-of-Apps**
Add the new application under the root `clusters/production/app-of-apps.yaml` include path so it is discovered.

### **4. Commit and Deploy**
```bash
git add .
git commit -m "Add new application"
git push
```

ArgoCD will automatically detect and deploy the new application.

## 🛠️ **Troubleshooting**

### **Common Issues**

1. **Application Not Syncing**
   - Check ArgoCD UI for errors
   - Verify repository access
   - Check namespace permissions

2. **Resource Conflicts**
   - Review resource quotas
   - Check for naming conflicts
   - Verify RBAC permissions

3. **Bootstrap Issues**
   - Ensure ArgoCD is installed
   - Check bootstrap manifests
   - Verify cluster connectivity

### **Debug Commands**
```bash
# Check ArgoCD application status
kubectl get applications -n argocd

# View application details
kubectl describe application <app-name> -n argocd

# Check sync status
argocd app get <app-name>

# Force sync
argocd app sync <app-name>
```

## 🧹 **Cleanup Summary**

### **Files Removed** (Redundant/Deprecated)
- ❌ `examples/web-app/k8s/deployment.yaml` - Superseded by Helm chart
- ❌ `examples/web-app/values/k8s-web-app-values.yaml` - Superseded by production values
- ❌ `applications/web-app/k8s-web-app/secrets-example.yaml` - Deprecated (using Vault)
- ❌ `bootstrap/vault-setup-script.sh` - Redundant with web app specific script
- ❌ `applications/web-app/vault-config.yaml` - Redundant with script approach
- ❌ `docs/gitops-structure.md` - Merged into PROJECT_STRUCTURE.md
- ❌ `applications/*/app-of-apps.yaml` - Redundant after consolidating to a single root App-of-Apps
- ❌ `applications/web-app/k8s-web-app/helm/values.yaml` - Redundant with production values file
- ❌ `WAVE_BASED_DEPLOYMENT_GUIDE.md` - Merged into AWS and Minikube deployment guides
- ❌ `LOCAL_DEVELOPMENT_OPTIMIZATION.md` - Merged into Minikube deployment guide

### **Benefits of Cleanup**
- ✅ **Reduced Confusion**: Clear separation between examples and production configs
- ✅ **Maintainability**: Single source of truth for each component
- ✅ **Consistency**: Standardized approach across all applications
- ✅ **Security**: Vault integration replaces Kubernetes secrets
- ✅ **Documentation**: Clear guidance on where to find configurations

## 🎯 **Best Practices**

### **Adding New Applications**
1. Create domain directory under `applications/`
2. Ensure the root `clusters/production/app-of-apps.yaml` discovers your new application's `application.yaml`
3. Create Helm chart or Kubernetes manifests
4. Add ArgoCD `application.yaml` files
5. Update documentation

### **Environment Management**
- Use `clusters/` for environment-specific configurations
- Maintain separate values files for different environments
- Use ArgoCD projects for environment isolation

### **Secret Management**
- Use Vault agent injection for automatic secret injection
- Create application-specific Vault policies
- Use dedicated service accounts for Vault authentication

### **Documentation**
- Keep README files updated with current configurations
- Document any changes in `CHANGELOG.md`
- Provide troubleshooting guides for complex components

## 🔐 **Security Considerations**

- **Pod Security Standards**: Enforced via bootstrap configuration
- **Network Policies**: Default deny with explicit allow rules
- **Vault Integration**: Automatic secret injection without Kubernetes secrets
- **RBAC**: Service accounts with minimal required permissions
- **IRSA**: IAM roles for service accounts for AWS integration

## 📊 **Monitoring and Observability**

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Dashboards and visualization
- **ArgoCD**: GitOps application monitoring
- **Vault**: Audit logging and secret access tracking

This structure provides a clean, maintainable, and scalable foundation for production Kubernetes deployments using GitOps principles.
