# Monitoring Sync Errors - Analysis & Resolution

## Status: ✅ MANIFESTS FIXED (Git HEAD)

The ArgoCD application manifests for Grafana and Prometheus have been corrected in recent commits.

## What Was Fixed

### 1. Dev Grafana Application
**File**: `environments/dev/apps/grafana.yaml`

**Problem**: Malformed multi-source structure with `helm` block at spec level
**Solution**: Corrected to proper multi-source pattern with `helm` nested under chart source

### 2. Dev Prometheus Application  
**File**: `environments/dev/apps/prometheus.yaml`

**Problem**: Single source with broken values file reference
**Solution**: Converted to multi-source with proper `$values` reference

## Current Repository State

```bash
✓ Production   - Correct multi-source (working)
✓ Staging      - Correct multi-source (working)
✓ Dev          - NOW FIXED - multi-source pattern matches prod/staging
```

## Why You're Still Seeing Sync Errors

Since the manifests are already fixed in Git, your sync errors are likely due to:

1. **ArgoCD hasn't refreshed** - ArgoCD may not have detected the latest changes
2. **Resource conflicts** - Existing resources may conflict with new configuration
3. **AppProject restrictions** - Source repos may not be allowed
4. **Namespace issues** - Target namespace may need to be recreated
5. **Helm repo not configured** - ArgoCD may not have Helm chart repos added

## Immediate Action Required

### Option 1: Run Diagnostic Script (RECOMMENDED)

```bash
# Run comprehensive diagnostic
./scripts/debug-monitoring-sync.sh dev

# This will:
# - Check ArgoCD status
# - Verify application configuration
# - Show detailed error messages
# - Offer to force refresh applications
```

### Option 2: Manual Quick Fix

```bash
# 1. Force refresh applications
kubectl patch application grafana-dev -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}'

kubectl patch application prometheus-dev -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}'

# 2. Check status
kubectl get applications -n argocd | grep -E "(grafana|prometheus)"

# 3. View detailed errors
kubectl describe application grafana-dev -n argocd
kubectl describe application prometheus-dev -n argocd
```

### Option 3: ArgoCD UI Investigation

```bash
# 1. Port forward to ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 2. Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# 3. Open browser: https://localhost:8080
# 4. Login as 'admin' with the password from step 2
# 5. Check grafana-dev and prometheus-dev applications
# 6. Look at "Sync Status" and "Last Sync Result"
```

## What to Look For

When running diagnostics, check for these common issues:

### 1. Sync Status
```bash
kubectl get application grafana-dev -n argocd -o jsonpath='{.status.sync.status}'
# Should show: Synced
# If shows: OutOfSync, Unknown, or Error - need to investigate
```

### 2. Health Status
```bash
kubectl get application grafana-dev -n argocd -o jsonpath='{.status.health.status}'
# Should show: Healthy
# If shows: Degraded, Progressing, or Missing - need to investigate
```

### 3. Sync Error Messages
```bash
kubectl get application grafana-dev -n argocd \
  -o jsonpath='{.status.conditions[*].message}'
# Look for error messages
```

### 4. ArgoCD Logs
```bash
kubectl logs -n argocd deployment/argocd-application-controller --tail=50 \
  | grep -i -E "(grafana|prometheus|error)"
```

## Common Fixes

### Fix 1: Restart ArgoCD Components
```bash
kubectl rollout restart deployment argocd-application-controller -n argocd
kubectl rollout restart deployment argocd-repo-server -n argocd
```

### Fix 2: Delete and Recreate Applications
```bash
# Delete (keeps deployed resources)
kubectl delete application grafana-dev prometheus-dev -n argocd

# Recreate from Git
kubectl apply -f environments/dev/apps/grafana.yaml
kubectl apply -f environments/dev/apps/prometheus.yaml
```

### Fix 3: Add Helm Repositories to ArgoCD
```bash
# Check if Helm repos are configured
kubectl get configmap argocd-cm -n argocd -o yaml | grep -A 20 "repositories"

# If not found, add them (see troubleshooting guide)
```

### Fix 4: Update AppProject
```bash
# Ensure source repos are allowed
kubectl get appproject dev-apps -n argocd -o yaml

# Should include:
# - https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps
# - https://grafana.github.io/helm-charts
# - https://prometheus-community.github.io/helm-charts
```

## Documentation

For comprehensive troubleshooting, see:
- **Full Guide**: `docs/MONITORING_SYNC_TROUBLESHOOTING.md`
- **Debug Script**: `scripts/debug-monitoring-sync.sh`

## Next Steps

1. **Run diagnostic script** to identify the exact issue
2. **Check ArgoCD UI** for visual status and error messages
3. **Review logs** for detailed error information
4. **Apply appropriate fix** based on error type
5. **Verify resolution** using the diagnostic script again

## Need Immediate Help?

Run these commands and share the output:

```bash
# Quick status check
echo "=== Application Status ==="
kubectl get applications -n argocd | grep -E "(grafana|prometheus)"

echo "\n=== Detailed Grafana Status ==="
kubectl describe application grafana-dev -n argocd | tail -30

echo "\n=== Detailed Prometheus Status ==="
kubectl describe application prometheus-dev -n argocd | tail -30

echo "\n=== Recent ArgoCD Logs ==="
kubectl logs -n argocd deployment/argocd-application-controller --tail=20
```

---

**Status**: Configuration fixed in Git ✅  
**Action Required**: Diagnose why ArgoCD isn't syncing properly  
**Tools**: Debug script and troubleshooting guide available  

