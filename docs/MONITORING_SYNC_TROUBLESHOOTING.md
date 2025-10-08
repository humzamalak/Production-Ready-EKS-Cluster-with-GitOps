# Monitoring Stack Sync Issues - Troubleshooting Guide

## Overview

This guide addresses sync errors with Grafana and Prometheus in ArgoCD deployments.

## Root Causes Identified

### 1. **Incorrect Multi-Source Configuration (FIXED)**

**Issue**: Dev environment applications had malformed multi-source structures.

#### Grafana (Dev) - Before:
```yaml
spec:
  project: dev-apps
  sources:
    - repoURL: 'https://grafana.github.io/helm-charts'
      chart: grafana
      targetRevision: 7.3.7
    - repoURL: 'https://github.com/...'
      targetRevision: main
      path: applications/monitoring/grafana
  helm:  # ❌ WRONG: helm at spec level
    valueFiles:
      - values-production.yaml
```

#### Grafana (Dev) - After:
```yaml
spec:
  project: dev-apps
  sources:
    - repoURL: 'https://grafana.github.io/helm-charts'
      chart: grafana
      targetRevision: 7.3.7
      helm:  # ✅ CORRECT: helm nested under chart source
        valueFiles:
          - $values/applications/monitoring/grafana/values-local.yaml
    - repoURL: 'https://github.com/...'
      targetRevision: main
      ref: values  # ✅ Named reference for $values
```

#### Prometheus (Dev) - Before:
```yaml
spec:
  project: dev-apps
  source:  # ❌ WRONG: single source
    repoURL: 'https://prometheus-community.github.io/helm-charts'
    chart: kube-prometheus-stack
    targetRevision: 61.6.0
    helm:
      valueFiles:
        - applications/monitoring/prometheus/values-production.yaml  # ❌ Path doesn't work
```

#### Prometheus (Dev) - After:
```yaml
spec:
  project: dev-apps
  sources:  # ✅ CORRECT: multi-source
    - repoURL: 'https://prometheus-community.github.io/helm-charts'
      chart: kube-prometheus-stack
      targetRevision: 61.6.0
      helm:
        valueFiles:
          - $values/applications/monitoring/prometheus/values-local.yaml  # ✅ $values reference
    - repoURL: 'https://github.com/...'
      targetRevision: main
      ref: values
```

### 2. **Common Sync Error Scenarios**

Even with correct manifests, sync errors can occur due to:

#### A. **ArgoCD Not Detecting Changes**
- **Symptom**: Applications show "OutOfSync" despite correct Git config
- **Cause**: ArgoCD hasn't refreshed its cache
- **Solution**: Force refresh or wait for auto-refresh interval

#### B. **Helm Chart Repository Issues**
- **Symptom**: "Failed to load target state: failed to get helm charts"
- **Cause**: Helm chart repository not accessible or not added
- **Solution**: Ensure Helm repos are configured in ArgoCD

#### C. **Values File Not Found**
- **Symptom**: "values file not found" or "path does not exist"
- **Cause**: Incorrect path in `valueFiles` or missing `ref: values`
- **Solution**: Verify path exists and `$values` reference is configured

#### D. **Namespace Doesn't Exist**
- **Symptom**: "namespace does not exist" errors
- **Cause**: Target namespace not created
- **Solution**: Ensure `CreateNamespace=true` in syncOptions

#### E. **AppProject Restrictions**
- **Symptom**: "application repo is not permitted"
- **Cause**: Source repository not allowed in AppProject
- **Solution**: Add repository to AppProject's sourceRepos

## Diagnostic Steps

### Quick Check
```bash
# Check application status
kubectl get applications -n argocd | grep -E "(grafana|prometheus)"

# Get detailed status
kubectl get application grafana-dev -n argocd -o yaml
kubectl get application prometheus-dev -n argocd -o yaml
```

### Use Debug Script
```bash
# Run comprehensive diagnostic
./scripts/debug-monitoring-sync.sh dev

# For staging
./scripts/debug-monitoring-sync.sh staging

# For production
./scripts/debug-monitoring-sync.sh prod
```

### Manual Investigation

#### 1. Check Sync Status
```bash
kubectl describe application grafana-dev -n argocd
kubectl describe application prometheus-dev -n argocd
```

#### 2. Check ArgoCD Logs
```bash
# Application controller logs
kubectl logs -n argocd deployment/argocd-application-controller --tail=50

# Server logs
kubectl logs -n argocd deployment/argocd-server --tail=50
```

#### 3. Verify Source Repositories
```bash
# Check AppProject
kubectl get appproject dev-apps -n argocd -o yaml

# Verify allowed source repos
kubectl get appproject dev-apps -n argocd -o jsonpath='{.spec.sourceRepos[*]}'
```

#### 4. Check Helm Repository Access
```bash
# List Helm repos in ArgoCD
kubectl get configmap argocd-cm -n argocd -o yaml | grep -A 10 "helm.repositories"
```

## Resolution Steps

### 1. Force Application Refresh
```bash
# Soft refresh (refresh cache)
kubectl patch application grafana-dev -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}'

# Hard refresh (clear cache)
argocd app get grafana-dev --hard-refresh
```

### 2. Manual Sync
```bash
# Sync application
argocd app sync grafana-dev

# Sync with prune
argocd app sync grafana-dev --prune
```

### 3. Delete and Recreate Application
```bash
# Delete application (keeps deployed resources)
kubectl delete application grafana-dev -n argocd

# Reapply from Git
kubectl apply -f environments/dev/apps/grafana.yaml
```

### 4. Fix Source Repository Issues

#### Add Helm Repository to ArgoCD
```bash
kubectl patch configmap argocd-cm -n argocd --type merge -p '
data:
  repositories: |
    - url: https://grafana.github.io/helm-charts
      name: grafana
      type: helm
    - url: https://prometheus-community.github.io/helm-charts
      name: prometheus-community
      type: helm
'
```

#### Update AppProject
```bash
kubectl patch appproject dev-apps -n argocd --type merge -p '
spec:
  sourceRepos:
    - "https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps"
    - "https://grafana.github.io/helm-charts"
    - "https://prometheus-community.github.io/helm-charts"
'
```

### 5. Restart ArgoCD Components
```bash
# Restart application controller
kubectl rollout restart deployment argocd-application-controller -n argocd

# Restart server
kubectl rollout restart deployment argocd-server -n argocd

# Restart repo server
kubectl rollout restart deployment argocd-repo-server -n argocd
```

## Verification

After applying fixes, verify sync status:

```bash
# Check application status
kubectl get application grafana-dev prometheus-dev -n argocd

# Check deployed resources
kubectl get pods -n dev-monitoring

# Check application health
argocd app list | grep -E "(grafana|prometheus)"

# View in UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open browser: https://localhost:8080
```

## Common Error Messages and Solutions

| Error Message | Cause | Solution |
|---------------|-------|----------|
| "application repo is not permitted" | Repo not in AppProject sourceRepos | Add repo to AppProject |
| "failed to load target state" | Helm chart or values issue | Check Helm repo config and values path |
| "namespace does not exist" | Target namespace missing | Add CreateNamespace=true to syncOptions |
| "values file not found" | Incorrect values file path | Verify path and $values reference |
| "chart not found" | Helm repo not configured | Add Helm repo to ArgoCD |
| "ComparisonError" | Multiple sources misconfigured | Check multi-source structure |

## Prevention Best Practices

1. **Use Multi-Source Pattern**: Always use multi-source for Helm charts with Git values
2. **Consistent Structure**: Maintain same structure across all environments
3. **Automated Sync**: Enable automated sync with selfHeal
4. **Sync Waves**: Use sync waves for dependencies (Prometheus before Grafana)
5. **Validation**: Use dry-run validation before committing:
   ```bash
   kubectl apply --dry-run=client -f environments/dev/apps/grafana.yaml
   ```

## Environment-Specific Notes

### Dev Environment
- Uses `values-local.yaml` for reduced resources
- Namespace: `dev-monitoring`
- Lower retention periods

### Staging Environment
- Uses `staging/values-staging.yaml`
- Namespace: `staging-monitoring`
- Production-like configuration with lower resources

### Production Environment
- Uses `values-production.yaml`
- Namespace: `monitoring`
- Full resources and HA configuration

## Related Files

- Application Manifests:
  - `environments/dev/apps/grafana.yaml`
  - `environments/dev/apps/prometheus.yaml`
  - `environments/staging/apps/grafana.yaml`
  - `environments/staging/apps/prometheus.yaml`
  - `environments/prod/apps/grafana.yaml`
  - `environments/prod/apps/prometheus.yaml`

- Values Files:
  - `applications/monitoring/grafana/values-local.yaml`
  - `applications/monitoring/grafana/values-production.yaml`
  - `applications/monitoring/grafana/staging/values-staging.yaml`
  - `applications/monitoring/prometheus/values-local.yaml`
  - `applications/monitoring/prometheus/values-production.yaml`
  - `applications/monitoring/prometheus/staging/values-staging.yaml`

- AppProjects:
  - `environments/dev/project.yaml`
  - `environments/staging/project.yaml`
  - `environments/prod/project.yaml`

## Additional Resources

- [ArgoCD Multi-Source Applications](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/)
- [Helm Values Files](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)
- [ArgoCD Sync Options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
- [Troubleshooting ArgoCD](https://argo-cd.readthedocs.io/en/stable/operator-manual/troubleshooting/)

## Need Help?

If sync errors persist after trying these solutions:

1. Run the debug script: `./scripts/debug-monitoring-sync.sh <environment>`
2. Check ArgoCD logs for detailed error messages
3. Verify all prerequisites are met (namespaces, secrets, AppProjects)
4. Compare working environment (prod/staging) with problematic one (dev)
5. Review recent Git commits for configuration changes

