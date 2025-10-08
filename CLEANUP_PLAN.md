# 🧹 Cleanup Plan - Files to Remove

This document lists all files and directories that should be removed as part of the refactoring cleanup.

## ❌ Files to Delete

### Old Bootstrap Files (Replaced by argocd/install/)
- [ ] `bootstrap/00-namespaces.yaml` → Replaced by `argocd/install/01-namespaces.yaml`
- [ ] `bootstrap/01-pod-security-standards.yaml` → Consolidated into namespace labels
- [ ] `bootstrap/02-network-policy.yaml` → Handled by application-level NetworkPolicies
- [ ] `bootstrap/03-helm-repos.yaml` → No longer needed (ArgoCD manages repos)
- [ ] `bootstrap/04-argo-cd-install.yaml` → Replaced by `argocd/install/02-argocd-install.yaml`
- [ ] `bootstrap/05-argocd-projects.yaml` → Replaced by `argocd/install/03-bootstrap.yaml`
- [ ] `bootstrap/06-vault-policies.yaml` → Will be part of Vault app configuration
- [ ] `bootstrap/07-etcd-backup.yaml` → Optional, can be added later if needed
- [ ] `bootstrap/projects/prod-apps-project.yaml` → Replaced by `argocd/projects/prod-apps.yaml`
- [ ] `bootstrap/projects/staging-apps-project.yaml` → Removed (only one project now)

### Old Application Directory (Replaced by apps/)
- [ ] `applications/web-app/` → Replaced by `apps/web-app/`
- [ ] `applications/monitoring/` → Replaced by `apps/prometheus/` and `apps/grafana/`
- [ ] `applications/infrastructure/` → Empty/unused

### Old Environment Directories (Replaced by argocd/apps/)
- [ ] `environments/prod/` → ArgoCD apps moved to `argocd/apps/`
- [ ] `environments/staging/` → Removed (only minikube/aws now)

### Redundant Cluster Directories
- [ ] `clusters/production/` → Overlaps with environments
- [ ] `clusters/staging/` → Overlaps with environments

### Old Documentation (Consolidated)
- [ ] `ARGOCD_PROJECT_FIX.md` → Interim fix doc (no longer needed)
- [ ] `INVESTIGATION_SUMMARY.md` → Investigation notes (no longer needed)
- [ ] `QUICK_FIX_GUIDE.md` → Temporary guide (no longer needed)
- [ ] `REPOSITORY_IMPROVEMENTS_SUMMARY.md` → Old summary (no longer needed)
- [ ] `docs/MONITORING_FIX_SUMMARY.md` → Old summary (no longer needed)

### Scripts to Remove/Archive
- [ ] `scripts/validate-argocd-apps.sh` → Can be consolidated into validate.sh
- [ ] `scripts/validate-deployment.sh` → Can be consolidated into validate.sh
- [ ] `scripts/validate-fixes.sh` → No longer needed (fixes applied)
- [ ] `scripts/validate-gitops-fixes.sh` → No longer needed
- [ ] `scripts/validate-gitops-structure.sh` → No longer needed
- [ ] `scripts/redeploy.sh` → Use setup scripts instead

### Config Directory
- [ ] `config/common.yaml` → Not used in refactored structure

---

## 🔄 Files to Keep (But May Need Updates)

### Infrastructure
- ✅ `infrastructure/terraform/` - Keep as-is (AWS provisioning)

### Examples
- ✅ `examples/web-app/` - Keep as-is (useful example)

### Scripts
- ✅ `scripts/deploy.sh` - Update to reference new structure
- ✅ `scripts/secrets.sh` - Keep, may need path updates
- ✅ `scripts/validate.sh` - Update to validate new structure
- ✅ `scripts/argo-diagnose.sh` - Keep for troubleshooting
- ✅ `scripts/config.sh` - Keep if still used

### Documentation
- ✅ `docs/architecture.md` - Update to reflect new structure
- ✅ `docs/aws-deployment.md` - Can be consolidated into DEPLOYMENT_GUIDE.md
- ✅ `docs/local-deployment.md` - Can be consolidated into DEPLOYMENT_GUIDE.md
- ✅ `docs/troubleshooting.md` - Keep and update
- ✅ `docs/K8S_VERSION_POLICY.md` - Keep as-is
- ✅ `docs/README.md` - Update with new structure

### Root Files
- ✅ `README.md` - Update with new structure
- ✅ `CHANGELOG.md` - Add refactor entry
- ✅ `Makefile` - Update targets for new structure
- ✅ `LICENSE` - Keep as-is

---

## 📊 Summary

| Category | Files to Delete | Files to Keep/Update |
|----------|----------------|---------------------|
| Bootstrap | 10 | 0 |
| Applications | 3 dirs | 0 |
| Environments | 2 dirs | 0 |
| Clusters | 2 dirs | 0 |
| Documentation | 5 | 6 |
| Scripts | 5 | 5 |
| Config | 1 | 0 |
| **Total** | **28 items** | **11 items** |

---

## ⚠️ Important Notes

1. **Backup Before Deletion**: Create a git tag before deleting files
2. **Test First**: Ensure new structure works before cleanup
3. **Gradual Cleanup**: Can delete in phases if needed
4. **Git History**: Files remain in git history even after deletion

---

## 🚀 Cleanup Execution Plan

### Phase 1: Validation (Before Cleanup)
1. Validate all new manifests
2. Test Minikube deployment
3. Document any issues

### Phase 2: Safe Cleanup (Low Risk)
1. Remove old documentation files
2. Remove unused scripts
3. Remove config directory

### Phase 3: Structural Cleanup (Medium Risk)
1. Remove old bootstrap directory
2. Remove old applications directory
3. Update references in remaining files

### Phase 4: Final Cleanup (Test Thoroughly)
1. Remove old environments directory
2. Remove clusters directory
3. Final validation

### Phase 5: Documentation Update
1. Update README.md
2. Update CHANGELOG.md
3. Update remaining docs

---

**Status:** Ready for execution  
**Created:** 2025-10-08  
**Last Updated:** 2025-10-08

