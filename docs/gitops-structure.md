# GitOps Repository Structure

This document explains the GitOps repository structure and how it follows GitOps best practices.

## 🏗️ Directory Structure

### `clusters/` - Environment-Specific Configurations

Contains environment-specific configurations following the GitOps pattern of separating cluster configurations.

```
clusters/
└── production/                 # Production cluster
    ├── app-of-apps.yaml        # Root application bootstrap
    ├── namespaces.yaml         # Required namespaces
    └── production-apps-project.yaml # ArgoCD project configuration
```

**Purpose**: 
- Environment-specific configurations
- Cluster-specific settings
- ArgoCD project definitions
- Root application manifests

### `applications/` - Application Definitions

Contains all application definitions organized by functional area.

```
applications/
├── monitoring/                 # Monitoring stack
│   ├── app-of-apps.yaml       # Monitoring stack bootstrap
│   ├── prometheus/            # Prometheus application
│   │   └── application.yaml   # Prometheus ArgoCD application
│   └── grafana/               # Grafana application
│       └── application.yaml   # Grafana ArgoCD application
└── security/                  # Security stack
    ├── app-of-apps.yaml       # Security stack bootstrap
    └── vault/                 # Vault application
        ├── application.yaml   # Vault ArgoCD application
        └── values.yaml        # Vault Helm values
```

**Purpose**:
- Application definitions
- Helm chart configurations
- Application-specific values
- Functional grouping of applications

### `bootstrap/` - Bootstrap Manifests

Contains manifests required to bootstrap the GitOps environment.

```
bootstrap/
├── 00-namespaces.yaml          # Core namespaces with PSS labels
├── 01-pod-security-standards.yaml # Pod Security Standards
├── 02-network-policy.yaml      # Network policies
├── 05-argo-cd-install.yaml     # Argo CD installation
├── 10-external-secrets-operator.yaml # ESO scaffolding note
├── 20-etcd-backup.yaml         # etcd backup cronjob
└── helm-values/                # Helm values (not applied via kubectl)
```

**Purpose**:
- Initial cluster setup
- ArgoCD installation
- Prerequisites for applications
- Security policies

## 🔄 GitOps Workflow

### 1. Bootstrap Phase

```bash
kubectl apply -f bootstrap/00-namespaces.yaml
kubectl apply -f bootstrap/01-pod-security-standards.yaml
kubectl apply -f bootstrap/02-network-policy.yaml
kubectl apply -f bootstrap/05-argo-cd-install.yaml
kubectl apply -f bootstrap/20-etcd-backup.yaml
```

This sets up:
- ArgoCD installation
- External secrets operator
- Helm repositories
- Security policies

### 2. Application Deployment Phase

```bash
# Apply root application
kubectl apply -f clusters/production/app-of-apps.yaml
```

This triggers:
- Namespace creation
- Application discovery
- Automated deployment
- Continuous reconciliation

### 3. Application Management Phase

Applications are managed through:
- Git commits (declarative changes)
- ArgoCD UI (observability)
- Automated reconciliation
- Health monitoring

## 🎯 GitOps Principles Applied

### 1. Declarative Configuration
- All desired state defined in YAML manifests
- No imperative commands required
- Version-controlled configurations

### 2. Version Control
- All changes tracked in Git
- Immutable infrastructure
- Audit trail for all changes

### 3. Automated Reconciliation
- ArgoCD continuously monitors Git
- Automatic drift detection and correction
- Self-healing capabilities

### 4. Observable
- ArgoCD UI for application status
- Prometheus metrics for monitoring
- Grafana dashboards for observability

## 🔧 Application Structure

### App-of-Apps Pattern

The repository uses the app-of-apps pattern for hierarchical application management:

```
Root App (clusters/production/app-of-apps.yaml)
├── Monitoring Stack (applications/monitoring/app-of-apps.yaml)
│   ├── Prometheus (applications/monitoring/prometheus/application.yaml)
│   └── Grafana (applications/monitoring/grafana/application.yaml)
└── Security Stack (applications/security/app-of-apps.yaml)
    └── Vault (applications/security/vault/application.yaml)
```

### Sync Waves

Applications are deployed in waves using ArgoCD sync waves:

1. **Wave 1**: Root application and namespaces
2. **Wave 2**: Monitoring stack
3. **Wave 3**: Security stack

This ensures proper dependency ordering.

## 🚀 Adding New Applications

### 1. Create Application Directory

```bash
mkdir -p applications/new-stack/new-app
```

### 2. Create Application Manifest

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

### 3. Update App-of-Apps

Add the new application to the appropriate app-of-apps.yaml file.

### 4. Commit and Deploy

```bash
git add .
git commit -m "Add new application"
git push
```

ArgoCD will automatically detect and deploy the new application.

## 🔒 Security Considerations

### Namespace Isolation
- Each application deployed to its own namespace
- Network policies for traffic isolation
- Pod security standards enforced

### Access Control
- ArgoCD projects restrict source repositories
- RBAC for cluster access
- External secrets for credential management

### Compliance
- All changes tracked in Git
- Immutable infrastructure
- Audit trail for compliance

## 📊 Monitoring and Observability

### ArgoCD Monitoring
- Application sync status
- Health checks
- Resource utilization

### Application Monitoring
- Prometheus metrics collection
- Grafana dashboards
- AlertManager notifications

### Logging
- Centralized logging (if configured)
- Audit logs for all changes
- Application logs

## 🛠️ Troubleshooting

### Common Issues

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

### Debug Commands

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

## 📚 Best Practices

### 1. Repository Organization
- Use clear directory structure
- Separate environments
- Group related applications

### 2. Application Design
- Use Helm charts for complex applications
- Keep values files organized
- Use app-of-apps for related applications

### 3. Security
- Implement proper RBAC
- Use external secrets
- Apply security policies

### 4. Monitoring
- Enable health checks
- Set up proper alerts
- Monitor resource usage

### 5. Documentation
- Document all applications
- Keep README files updated
- Provide troubleshooting guides
