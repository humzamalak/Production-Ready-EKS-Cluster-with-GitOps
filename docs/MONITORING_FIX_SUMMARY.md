# Monitoring Applications Fix Summary

This document describes the fixes applied to resolve "Out of Sync" errors in Grafana and Prometheus/Alertmanager Argo CD applications.

## Issues Identified

### 1. Grafana ConfigMap Missing
**Error**: ConfigMap `grafana-prod` not found

**Root Cause**: 
- Grafana Helm chart was not configured with a `fullnameOverride`, leading to unpredictable ConfigMap naming
- The ConfigMap was not being created with the expected name

**Fix Applied**:
- Added `fullnameOverride: "grafana-prod"` and `nameOverride: "grafana-prod"` to ensure consistent resource naming
- Created a backup ConfigMap manifest in `environments/prod/secrets/grafana-configmap.yaml` that will be deployed via the monitoring-secrets Argo CD application (sync-wave 2, before Grafana at sync-wave 4)

### 2. Alertmanager Secret Missing
**Error**: Secret `alertmanager-prometheus-prod-kube-prome-alertmanager` not found

**Root Cause**:
- The kube-prometheus-stack chart should automatically create this secret from inline configuration
- The secret name follows the pattern: `alertmanager-{release-name}-kube-prome-alertmanager`
- With release name `prometheus-prod`, the expected secret is `alertmanager-prometheus-prod-kube-prome-alertmanager`

**Fix Applied**:
- Created explicit Secret manifest in `environments/prod/secrets/alertmanager-secret.yaml`
- The secret contains the complete Alertmanager configuration
- Deployed via monitoring-secrets application (sync-wave 2, before Prometheus at sync-wave 3)
- Kept inline configuration in Helm values as fallback

### 3. Service Name Mismatches
**Error**: Grafana datasources pointing to non-existent services

**Root Cause**:
- Grafana was configured to connect to `prometheus-server` and `prometheus-alertmanager`
- kube-prometheus-stack creates services with pattern: `{release-name}-kube-prome-{component}`
- Correct service names: `prometheus-prod-kube-prome-prometheus` and `prometheus-prod-kube-prome-alertmanager`

**Fix Applied**:
- Updated Grafana datasource URLs to use correct service names:
  - Prometheus: `http://prometheus-prod-kube-prome-prometheus.monitoring.svc.cluster.local:9090`
  - AlertManager: `http://prometheus-prod-kube-prome-alertmanager.monitoring.svc.cluster.local:9093`

## Files Modified

### 1. `applications/monitoring/grafana/values-production.yaml`
```yaml
# Added naming overrides
fullnameOverride: "grafana-prod"
nameOverride: "grafana-prod"

# Updated datasource URLs
datasources:
  datasources.yaml:
    datasources:
      - name: Prometheus
        url: http://prometheus-prod-kube-prome-prometheus.monitoring.svc.cluster.local:9090
      - name: AlertManager
        url: http://prometheus-prod-kube-prome-alertmanager.monitoring.svc.cluster.local:9093
```

### 2. `environments/prod/secrets/grafana-configmap.yaml` (NEW)
- ConfigMap for Grafana configuration
- Contains grafana.ini with production settings
- Ensures ConfigMap exists before Grafana deployment

### 3. `environments/prod/secrets/alertmanager-secret.yaml` (NEW)
- Secret for Alertmanager configuration
- Contains complete alertmanager.yaml configuration
- Matches expected naming convention: `alertmanager-prometheus-prod-kube-prome-alertmanager`

## Sync Wave Configuration

The deployment order ensures dependencies are met:

1. **Wave 2**: `monitoring-secrets-prod` - Deploys Secrets and ConfigMaps
   - `grafana-admin` (already existed)
   - `grafana-configmap.yaml` (NEW)
   - `alertmanager-secret.yaml` (NEW)

2. **Wave 3**: `prometheus-prod` - Deploys Prometheus & Alertmanager
   - References: alertmanager secret from Wave 2

3. **Wave 4**: `grafana-prod` - Deploys Grafana
   - References: grafana-admin secret from Wave 2
   - References: grafana-prod ConfigMap from Wave 2
   - Connects to: Prometheus and Alertmanager services from Wave 3

## Deployment Instructions

### Option 1: Automatic Sync (Recommended for Production)
If Argo CD auto-sync is enabled, the changes will be applied automatically upon git push:

```bash
git add .
git commit -m "fix: resolve Grafana and Alertmanager out of sync errors

- Add fullnameOverride for consistent Grafana resource naming
- Create explicit ConfigMap for grafana-prod
- Create explicit Secret for alertmanager configuration
- Update Grafana datasource URLs to match kube-prometheus-stack naming
"
git push origin main
```

Argo CD will:
1. Sync monitoring-secrets-prod first (wave 2)
2. Then sync prometheus-prod (wave 3)
3. Finally sync grafana-prod (wave 4)

### Option 2: Manual Sync
If auto-sync is disabled, sync applications manually in order:

```bash
# Sync secrets first
argocd app sync monitoring-secrets-prod

# Wait for completion, then sync Prometheus
argocd app sync prometheus-prod

# Wait for completion, then sync Grafana
argocd app sync grafana-prod
```

## Validation

After deployment, verify the following:

### 1. Check Resources Exist
```bash
# Check Grafana ConfigMap
kubectl get configmap grafana-prod -n monitoring

# Check Alertmanager Secret
kubectl get secret alertmanager-prometheus-prod-kube-prome-alertmanager -n monitoring

# Check Services
kubectl get svc -n monitoring | grep -E "prometheus|alertmanager|grafana"
```

### 2. Check Pod Status
```bash
# Grafana pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Prometheus pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Alertmanager pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager
```

### 3. Check Argo CD Application Status
```bash
# All monitoring apps should show "Synced" and "Healthy"
argocd app list | grep -E "grafana|prometheus|monitoring-secrets"
```

### 4. Verify Grafana Connectivity
```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/grafana-prod 3000:80

# Open http://localhost:3000
# Login with credentials from grafana-admin secret
# Check that Prometheus and AlertManager datasources are working
```

### 5. Check Logs
```bash
# Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=50

# Alertmanager logs
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager --tail=50
```

## Expected Outcomes

After applying these fixes:

✅ Grafana ConfigMap `grafana-prod` exists and is correctly mounted  
✅ Alertmanager Secret `alertmanager-prometheus-prod-kube-prome-alertmanager` exists  
✅ Grafana datasources successfully connect to Prometheus and Alertmanager  
✅ No "Out of Sync" errors in Argo CD  
✅ All monitoring pods are running and healthy  
✅ Metrics are being collected and dashboards display data  
✅ Alertmanager configuration is properly loaded  

## Troubleshooting

### If Grafana Still Shows Out of Sync

1. Check if ConfigMap was created:
   ```bash
   kubectl get configmap -n monitoring | grep grafana
   ```

2. Check Grafana pod events:
   ```bash
   kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana
   ```

3. Force Argo CD to sync:
   ```bash
   argocd app sync grafana-prod --force
   ```

### If Alertmanager Shows Out of Sync

1. Check if Secret was created with correct name:
   ```bash
   kubectl get secret -n monitoring | grep alertmanager
   ```

2. Verify secret content:
   ```bash
   kubectl get secret alertmanager-prometheus-prod-kube-prome-alertmanager -n monitoring -o yaml
   ```

3. Check Alertmanager pod logs:
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager
   ```

### If Services Don't Match Expected Names

Check actual service names created by kube-prometheus-stack:
```bash
kubectl get svc -n monitoring
```

Update Grafana datasource URLs in `values-production.yaml` if service names differ.

## Production Safety Notes

- ✅ All changes are declarative and managed via GitOps
- ✅ Sync waves ensure proper deployment order
- ✅ Backup manifests ensure resources exist even if Helm fails to create them
- ✅ No manual cluster modifications required
- ✅ Changes can be rolled back via git revert
- ✅ Argo CD self-heal will maintain desired state

## Additional Improvements for Future

1. **Vault Integration**: Move secrets to HashiCorp Vault
2. **External Secrets Operator**: Sync secrets from external secret stores
3. **Custom Grafana Dashboards**: Add application-specific dashboards
4. **Alert Rules**: Configure Prometheus alert rules for critical metrics
5. **Notification Channels**: Configure real SMTP/Slack/PagerDuty for alerts

