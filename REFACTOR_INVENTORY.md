# 📋 Repository Refactor Inventory
## Agent 1: Repository Structure & Inventory Analysis

**Date:** 2025-10-08  
**Purpose:** Complete deep refactor into minimal, production-grade GitOps stack

---

## 🔍 Current State Analysis

### Existing Directory Structure

```
├── applications/          # Application Helm charts and values
│   ├── infrastructure/
│   ├── monitoring/        # Grafana & Prometheus values
│   └── web-app/          # Web app Helm chart
├── bootstrap/            # Initial cluster setup
│   ├── 00-07-*.yaml     # Ordered bootstrap manifests
│   ├── helm-values/
│   └── projects/        # AppProject definitions
├── environments/         # Environment-specific ArgoCD apps
│   ├── prod/
│   └── staging/
├── clusters/            # ⚠️ REDUNDANT - Overlaps with environments/
│   ├── production/
│   └── staging/
├── infrastructure/      # Terraform for AWS EKS
│   └── terraform/
├── scripts/            # Deployment and validation scripts
├── docs/              # Documentation
├── examples/          # Web app example code
└── config/           # Common configuration

**Total Files:** ~100+
**Issues Identified:**
- ❌ No Vault application deployment (only policies)
- ❌ Redundant structure (clusters/ vs environments/)
- ❌ No Minikube-specific setup
- ❌ Staging/Prod duplicate complexity
- ❌ Applications scattered across multiple directories
```

---

## 📊 File-by-File Inventory

### ✅ KEEP (Core Files)

#### ArgoCD Bootstrap
- ✅ `bootstrap/00-namespaces.yaml` - Namespace creation
- ✅ `bootstrap/01-pod-security-standards.yaml` - Security policies
- ✅ `bootstrap/02-network-policy.yaml` - Network security
- ✅ `bootstrap/03-helm-repos.yaml` - Helm repository configs
- ✅ `bootstrap/04-argo-cd-install.yaml` - ArgoCD installation
- ✅ `bootstrap/05-argocd-projects.yaml` - Project bootstrap app
- ✅ `bootstrap/06-vault-policies.yaml` - Vault policies
- ✅ `bootstrap/07-etcd-backup.yaml` - Backup configuration
- ✅ `bootstrap/helm-values/argo-cd-values.yaml` - ArgoCD values

#### ArgoCD Projects
- ✅ `bootstrap/projects/prod-apps-project.yaml` - Prod AppProject
- ✅ `bootstrap/projects/staging-apps-project.yaml` - Staging AppProject

#### Infrastructure
- ✅ `infrastructure/terraform/**` - All Terraform modules (EKS, VPC, IAM)

#### Applications - Helm Charts
- ✅ `applications/web-app/k8s-web-app/helm/**` - Web app chart
- ✅ `applications/monitoring/prometheus/values-*.yaml` - Prometheus values
- ✅ `applications/monitoring/grafana/values-*.yaml` - Grafana values

#### Scripts
- ✅ `scripts/deploy.sh` - Main deployment script
- ✅ `scripts/secrets.sh` - Secrets management
- ✅ `scripts/validate.sh` - Validation
- ✅ `scripts/argo-diagnose.sh` - ArgoCD diagnostics
- ✅ `scripts/config.sh` - Configuration management

#### Documentation
- ✅ `docs/architecture.md` - Architecture overview
- ✅ `docs/aws-deployment.md` - AWS deployment guide
- ✅ `docs/local-deployment.md` - Local deployment guide
- ✅ `docs/troubleshooting.md` - Troubleshooting guide
- ✅ `docs/K8S_VERSION_POLICY.md` - Version policy

#### Root Files
- ✅ `README.md` - Main readme
- ✅ `LICENSE` - License file
- ✅ `Makefile` - Build automation
- ✅ `CHANGELOG.md` - Change history

#### Examples
- ✅ `examples/web-app/**` - Complete example app

---

### 🔄 REFACTOR (Needs Changes)

#### Environment Applications
- 🔄 `environments/prod/app-of-apps.yaml` → Consolidate to single root-app
- 🔄 `environments/staging/app-of-apps.yaml` → Use overlays instead
- 🔄 `environments/prod/apps/*.yaml` → Merge into unified apps/
- 🔄 `environments/staging/apps/*.yaml` → Merge into unified apps/
- 🔄 `environments/prod/project.yaml` → Move to bootstrap/projects/
- 🔄 `environments/staging/project.yaml` → Move to bootstrap/projects/

#### Namespace Configurations
- 🔄 `environments/prod/namespaces.yaml` → Consolidate to bootstrap/
- 🔄 `environments/staging/namespaces.yaml` → Consolidate to bootstrap/

#### Secrets (Templates Only)
- 🔄 `environments/*/secrets/*.yaml` → Document in deployment guide

---

### ❌ DELETE (Redundant/Unused)

#### Redundant Directories
- ❌ `clusters/production/**` - Overlaps with environments/prod
- ❌ `clusters/staging/**` - Overlaps with environments/staging
- ❌ `applications/infrastructure/` - Empty/minimal
- ❌ `applications/monitoring/grafana/staging/application.yaml` - Redundant

#### Duplicate Namespace Configs
- ❌ `clusters/production/namespaces.yaml` - Duplicate
- ❌ `clusters/staging/namespaces.yaml` - Duplicate

#### Old Documentation
- ❌ `ARGOCD_PROJECT_FIX.md` - Interim fix doc
- ❌ `INVESTIGATION_SUMMARY.md` - Investigation notes
- ❌ `QUICK_FIX_GUIDE.md` - Temporary guide
- ❌ `REPOSITORY_IMPROVEMENTS_SUMMARY.md` - Old summary
- ❌ `MONITORING_FIX_SUMMARY.md` - Old summary

---

## 🎯 Target Structure (Minimal & Production-Grade)

```
/
├── argocd/                    # ✨ NEW - Consolidated ArgoCD manifests
│   ├── install/
│   │   ├── 01-namespaces.yaml
│   │   ├── 02-argocd-install.yaml
│   │   └── 03-bootstrap.yaml
│   ├── projects/
│   │   └── prod-apps.yaml     # Single unified project
│   └── apps/
│       ├── root-app.yaml      # App-of-Apps root
│       ├── web-app.yaml
│       ├── prometheus.yaml
│       ├── grafana.yaml
│       └── vault.yaml         # ✨ NEW - Vault deployment
│
├── apps/                      # ✨ NEW - All application manifests
│   ├── web-app/
│   │   ├── Chart.yaml
│   │   ├── values.yaml        # Default values
│   │   ├── values-minikube.yaml
│   │   ├── values-aws.yaml
│   │   └── templates/
│   ├── prometheus/
│   │   ├── values.yaml
│   │   ├── values-minikube.yaml
│   │   └── values-aws.yaml
│   ├── grafana/
│   │   ├── values.yaml
│   │   ├── values-minikube.yaml
│   │   └── values-aws.yaml
│   └── vault/                 # ✨ NEW - Vault application
│       ├── values.yaml
│       ├── values-minikube.yaml
│       └── values-aws.yaml
│
├── environments/              # ✨ SIMPLIFIED - Environment configs
│   ├── minikube/
│   │   ├── kustomization.yaml
│   │   └── values-overrides.yaml
│   └── aws/
│       ├── kustomization.yaml
│       └── values-overrides.yaml
│
├── infrastructure/            # ✅ KEEP - Terraform unchanged
│   └── terraform/
│
├── scripts/                   # ✨ ENHANCED - Improved scripts
│   ├── setup-minikube.sh      # ✨ NEW
│   ├── setup-aws.sh          # ✨ NEW
│   ├── deploy.sh             # ✅ KEEP (enhanced)
│   ├── validate.sh           # ✅ KEEP (enhanced)
│   └── argo-diagnose.sh      # ✅ KEEP
│
├── docs/                      # ✨ CONSOLIDATED
│   └── deployment-guide.md    # Single unified guide
│
├── examples/                  # ✅ KEEP - Example app
│   └── web-app/
│
├── README.md                  # 🔄 REFACTOR - Updated structure
├── CHANGELOG.md              # 🔄 REFACTOR - Add refactor notes
├── Makefile                  # 🔄 REFACTOR - Updated targets
└── LICENSE                   # ✅ KEEP
```

---

## 📈 Comparison: Before vs After

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| **Top-level dirs** | 12 | 7 | -42% |
| **Total files** | ~100+ | ~60 | -40% |
| **ArgoCD apps** | Scattered | Centralized | 📍 |
| **Environments** | 2 (prod/staging) | 2 (minikube/aws) | 🔄 |
| **Documentation** | 7+ files | 1 unified | -86% |
| **Vault support** | Policies only | Full deployment | ✨ |
| **Minikube support** | None | Full | ✨ |

---

## 🚀 Migration Strategy

### Phase 1: Create New Structure
1. Create `argocd/` directory with clean App-of-Apps
2. Create `apps/` directory with all Helm charts
3. Create environment overlays for minikube/aws
4. Add Vault application deployment

### Phase 2: Migrate Content
1. Move web-app Helm chart to `apps/web-app/`
2. Consolidate monitoring values to `apps/prometheus/` and `apps/grafana/`
3. Create Vault application in `apps/vault/`
4. Migrate ArgoCD manifests to `argocd/`

### Phase 3: Update References
1. Update all ArgoCD application paths
2. Update documentation references
3. Update script paths
4. Update Makefile targets

### Phase 4: Cleanup
1. Remove `clusters/` directory
2. Remove old `environments/prod/` and `environments/staging/`
3. Remove redundant documentation
4. Clean up bootstrap directory

### Phase 5: Validation
1. Validate all manifests with kubectl dry-run
2. Test Minikube deployment
3. Validate ArgoCD sync
4. Generate validation report

---

## ✅ Success Criteria

- [ ] Single App-of-Apps root application
- [ ] 4 child applications (web-app, prometheus, grafana, vault)
- [ ] Minikube and AWS use same manifests (different values)
- [ ] All YAML valid and K8s 1.33+ compatible
- [ ] Clean, minimal structure
- [ ] Unified documentation
- [ ] All validation scripts pass

---

## 📝 Notes

**Key Decisions:**
1. **Eliminate staging environment** - Use Minikube for dev/test, AWS for prod
2. **Single AppProject** - Simplify RBAC with one `prod-apps` project
3. **Values-based differentiation** - Same charts, different values files
4. **Vault inclusion** - Add full Vault deployment (was missing)
5. **Documentation consolidation** - Single comprehensive guide

**Risk Mitigation:**
- Keep old structure temporarily during migration
- Validate each phase before proceeding
- Document rollback procedures
- Test on Minikube before AWS

---

**Status:** ✅ Inventory Complete - Ready for Agent 2

