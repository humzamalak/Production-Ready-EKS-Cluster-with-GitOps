# Root Cause Analysis - GitOps Deployment Failures

**Analysis Date**: 2025-10-07  
**Analyst**: DevOps/Kubernetes Architect  
**Priority**: P0 - Critical Production Issues

## Executive Summary

Six critical deployment issues were identified affecting production monitoring stack and web application. All issues stem from configuration mismatches, resource ownership conflicts, and incomplete security compliance. This document provides detailed root-cause analysis and remediation plans for each failure.

---

## Issue 1: SharedResourceWarning - ConfigMap/grafana-prod

### Error Message
```
SharedResourceWarning: ConfigMap/grafana-prod is part of applications argocd/grafana-prod and monitoring-secrets-prod
```

### Root Cause

**Files Involved:**
- `environments/prod/secrets/grafana-configmap.yaml` (Lines 1-35)
- `environments/prod/apps/monitoring-secrets.yaml` (Lines 1-34)
- `environments/prod/apps/grafana.yaml` (Lines 1-48)

**Why It Happens:**

1. **Dual Ownership Conflict**: The ConfigMap `grafana-prod` is explicitly defined in `environments/prod/secrets/grafana-configmap.yaml`
2. **ArgoCD Management**: The `monitoring-secrets-prod` Application (sync-wave: 2) manages the `environments/prod/secrets` directory, which includes this ConfigMap
3. **Helm Chart Conflict**: The `grafana-prod` Application (sync-wave: 4) deploys the Grafana Helm chart, which also attempts to create a ConfigMap named `grafana-prod` based on `values-production.yaml` configuration (lines 54-68)
4. **ArgoCD Behavior**: ArgoCD detects that two Applications claim ownership of the same resource, violating the single-owner principle in GitOps

**Impact:** Medium - ArgoCD cannot determine authoritative source; causes sync failures and prevents automated healing

### Remediation Priority: HIGH

**Automated Fix Strategy:**
- **Option 1 (Recommended)**: Delete the explicit ConfigMap file and let Grafana Helm chart manage it via values
- **Option 2**: Create a dedicated `monitoring-shared` Application (sync-wave: 1) for shared resources

**Selected Approach**: Option 1 - Simpler and follows Helm best practices

---

## Issue 2: Missing Resource - ServiceAccount prometheus-prod-kube-prome-prometheus

### Error Message
```
Resource not found in cluster: v1/ServiceAccount:prometheus-prod-kube-prome-prometheus
```

### Root Cause

**Files Involved:**
- `applications/monitoring/prometheus/values-production.yaml` (Lines 1-223)
- `environments/prod/apps/prometheus.yaml` (Lines 1-48)

**Why It Happens:**

1. **Missing Configuration**: The `values-production.yaml` file does NOT contain explicit `prometheus.serviceAccount` configuration
2. **Chart Default Behavior**: The `kube-prometheus-stack` Helm chart (v61.6.0) creates a ServiceAccount by default with a generated name pattern: `{release-name}-kube-prome-prometheus`
3. **Release Name**: The release name is `prometheus-prod` (from Application metadata), so the expected ServiceAccount name is `prometheus-prod-kube-prome-prometheus`
4. **Creation Failure**: The ServiceAccount is not being created because:
   - ServiceAccount creation might be disabled in default chart values
   - RBAC resources might be failing to create due to permissions
   - ArgoCD may be pruning the resource if not explicitly tracked

**Referenced By:**
- Grafana datasource configuration at line 77 of `applications/monitoring/grafana/values-production.yaml` references `prometheus-prod-kube-prome-prometheus.monitoring.svc.cluster.local`
- Prometheus pods require this ServiceAccount for RBAC permissions

**Impact:** Critical - Prometheus pods cannot start without valid ServiceAccount; monitoring stack is non-functional

### Remediation Priority: CRITICAL

**Automated Fix Strategy:**
1. Add explicit ServiceAccount configuration to `values-production.yaml`:
   ```yaml
   prometheus:
     serviceAccount:
       create: true
       name: prometheus-prod-kube-prome-prometheus
   ```
2. Ensure RBAC resources are enabled in chart values

---

## Issue 3: Missing Resource - PrometheusRule kube-scheduler.rules

### Error Message
```
Resource not found in cluster: monitoring.coreos.com/v1/PrometheusRule:prometheus-prod-kube-prome-kube-scheduler.rules
```

### Root Cause

**Files Involved:**
- `applications/monitoring/prometheus/values-production.yaml` (Line 215)

**Why It Happens:**

1. **Configuration Mismatch**: Line 215 enables kube-scheduler rules: `kubeScheduler: true`
2. **EKS Architecture**: In AWS EKS (managed Kubernetes), the kube-scheduler runs on AWS-managed control plane nodes
3. **Metrics Unavailability**: EKS does not expose kube-scheduler metrics endpoint (`/metrics`) to customer-managed pods for security reasons
4. **Chart Behavior**: When `kubeScheduler: true`, the Helm chart attempts to create PrometheusRule resources that scrape scheduler metrics
5. **Creation Failure**: The ServiceMonitor for kube-scheduler fails health checks because the metrics endpoint is unreachable, causing the associated PrometheusRule to not be created or to fail validation

**Comparison with Staging:**
- `applications/monitoring/prometheus/staging/values-staging.yaml:197` correctly sets `kubeScheduler: false`
- Staging environment acknowledges this EKS limitation

**Impact:** Low-Medium - Monitoring functionality degraded (missing scheduler metrics), but Prometheus core functionality remains operational

### Remediation Priority: MEDIUM

**Automated Fix Strategy:**
1. Set `kubeScheduler: false` in production values to match staging
2. Add comment explaining EKS limitation
3. Alternative: Create PrometheusRule resources manually if scheduler becomes accessible

---

## Issue 4: PodSecurity Violation - Missing seccompProfile

### Error Message
```
pods "k8s-web-app-prod-..." is forbidden: violates PodSecurity "restricted:latest": 
seccompProfile (pod or container "k8s-web-app" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

### Root Cause

**Files Involved:**
- `applications/web-app/k8s-web-app/helm/values.yaml` (Lines 89-124)
- `applications/web-app/k8s-web-app/helm/templates/deployment.yaml` (Lines 93-98)

**Why It Happens:**

1. **Namespace Policy**: The `production` namespace is configured with PodSecurity admission mode `restricted:latest` (likely via bootstrap policies)
2. **Current Configuration**: 
   - Pod-level securityContext at lines 89-101 of `values.yaml` DOES include `seccompProfile: type: RuntimeDefault`
   - Container-level securityContext at lines 108-124 DOES include `seccompProfile: type: RuntimeDefault`
   - Init container `vault-wait` at lines 66-75 of `deployment.yaml` DOES include `seccompProfile: type: RuntimeDefault`
3. **Inconsistency**: The deployment.yaml correctly references `{{- toYaml .Values.podSecurityContext | nindent 8 }}` at line 94
4. **Actual Issue**: There may be an environment-specific override OR the image itself might be launching processes that don't respect the seccomp profile

**Additional Analysis Required:**
- Check if there's a production-specific values override file
- Verify the actual rendered manifest

**Impact:** Critical - Pods cannot start in production namespace; application is non-functional

### Remediation Priority: CRITICAL

**Automated Fix Strategy:**
1. Verify current configuration is correct (already has seccompProfile)
2. Check for environment-specific overrides that might remove seccompProfile
3. Ensure no values.yaml inheritance issues
4. Add explicit seccompProfile to ALL containers including init containers as fallback

**Note:** This may already be fixed in current configuration; requires validation

---

## Issue 5: Image Pull Failure - Multi-Architecture Manifest Missing

### Error Message
```
Back-off pulling image "windrunner101/k8s-web-app:latest": 
ErrImagePull: no matching manifest for linux/amd64 in the manifest list entries
```

### Root Cause

**Files Involved:**
- `examples/web-app/Dockerfile` (Lines 1-36)
- `applications/web-app/k8s-web-app/helm/values.yaml` (Line 32, 41)
- `examples/web-app/build-and-push.sh` (Build script)

**Why It Happens:**

1. **Image Build Platform**: The Docker image `windrunner101/k8s-web-app:latest` was built on a non-amd64 platform (likely ARM64/M1 Mac)
2. **Dockerfile Architecture**: The Dockerfile uses `FROM node:18-alpine` which supports multi-arch, but the build process didn't create a multi-arch manifest
3. **Build Process**: The `build-and-push.sh` script likely uses standard `docker build` without `--platform` flags
4. **Cluster Architecture**: Production EKS nodes run on linux/amd64 instances
5. **Manifest Mismatch**: Docker Hub contains only the ARM64 image in the manifest list, no amd64 variant

**Pull Process Flow:**
```
kubelet → docker pull windrunner101/k8s-web-app:latest
         → Check manifest list
         → Look for linux/amd64
         → NOT FOUND → ErrImagePull
```

**Impact:** Critical - Application pods cannot start; complete service outage

### Remediation Priority: CRITICAL

**Manual Remediation Required:**

This issue CANNOT be fixed by editing manifests. It requires rebuilding and pushing the Docker image with multi-architecture support.

**Required Actions:**

1. **Update build-and-push.sh**:
   ```bash
   docker buildx build --platform linux/amd64,linux/arm64 \
     -t windrunner101/k8s-web-app:latest \
     -t windrunner101/k8s-web-app:v1.0.0 \
     --push .
   ```

2. **Alternative - Build on CI/CD**:
   - Create GitHub Actions workflow with multi-arch buildx
   - Use QEMU emulation for cross-platform builds
   - Push to Docker Hub with proper manifest

3. **Immediate Workaround**:
   - Build image on amd64 Linux machine
   - Push with version tag instead of `latest`
   - Update values.yaml to use specific version

**Documentation Required:**
- Create `examples/web-app/MULTI_ARCH_BUILD.md`
- Update `build-and-push.sh` with buildx support
- Create GitHub Actions workflow for automated builds

---

## Issue 6: Out-of-Sync Status - Grafana and Prometheus

### Error Message
```
Grafana and Prometheus show out-of-sync in ArgoCD
```

### Root Cause

**Cascading Failure:**

This is NOT a root issue but a symptom of Issues 1, 2, and 3.

**Why Out-of-Sync:**

1. **ConfigMap Conflict (Issue 1)**: ArgoCD cannot determine desired state due to dual ownership
2. **Missing ServiceAccount (Issue 2)**: Prometheus Application cannot achieve healthy state
3. **Missing PrometheusRule (Issue 3)**: Rule creation fails, causing partial sync
4. **Dependency Chain**: 
   - `monitoring-secrets-prod` (wave 2) conflicts with `grafana-prod` (wave 4)
   - `prometheus-prod` (wave 3) fails to create ServiceAccount
   - `grafana-prod` (wave 4) depends on Prometheus being healthy

**ArgoCD Sync Logic:**
```
monitoring-secrets-prod: OutOfSync (ConfigMap conflict)
        ↓
prometheus-prod: OutOfSync (Missing SA, Missing Rule)
        ↓
grafana-prod: OutOfSync (Depends on prometheus-prod, ConfigMap conflict)
```

**Impact:** High - Entire monitoring stack is degraded; manual intervention required for each sync

### Remediation Priority: HIGH (Resolved by fixing Issues 1, 2, 3)

**Automated Fix Strategy:**
- Fix Issues 1, 2, and 3
- Force ArgoCD sync after fixes
- Verify sync-wave ordering (2 → 3 → 4)

---

## Fix Implementation Plan

### Phase 1: Critical Fixes (Issues 2, 4, 5)
**Priority**: P0 - Blocks application deployment

1. ✅ Add Prometheus ServiceAccount configuration
2. ✅ Verify/fix k8s-web-app securityContext
3. ⚠️ Document multi-arch build process (manual user action required)

### Phase 2: High Priority Fixes (Issues 1, 6)
**Priority**: P1 - Monitoring stack degradation

4. ✅ Remove duplicate grafana-prod ConfigMap
5. ✅ Verify ArgoCD sync status after fixes

### Phase 3: Medium Priority Fixes (Issue 3)
**Priority**: P2 - Feature completeness

6. ✅ Disable kubeScheduler rules in production

### Phase 4: Validation & Documentation
**Priority**: P1 - Ensure reliability

7. ✅ Run `helm lint` on all charts
8. ✅ Run `kubectl apply --dry-run=client` on all manifests
9. ✅ Create validation summary
10. ✅ Document rollback procedures

---

## Validation Checklist

- [ ] All Helm charts pass `helm lint`
- [ ] All manifests pass `kubectl apply --dry-run=client`
- [ ] No SharedResourceWarnings in ArgoCD
- [ ] Prometheus ServiceAccount created successfully
- [ ] PrometheusRule status verified
- [ ] k8s-web-app pods start successfully (after image rebuild)
- [ ] Grafana and Prometheus sync to "Synced" status
- [ ] Multi-arch build documentation created

---

## Rollback Plan

### Rollback Commands (if fixes cause issues)

```bash
# Restore original Grafana ConfigMap
git revert <commit-hash-for-configmap-deletion>
git push origin main

# Revert Prometheus values changes
git revert <commit-hash-for-prometheus-sa>
git push origin main

# Force ArgoCD to previous revision
argocd app rollback prometheus-prod <previous-revision>
argocd app rollback grafana-prod <previous-revision>
```

### Rollback Triggers

- ArgoCD Applications fail to sync after 3 retry attempts
- Prometheus pods crash-loop after ServiceAccount changes
- Grafana cannot connect to datasources
- Increased error rate in monitoring stack logs

---

## Risk Assessment

| Issue | Risk Level | Blast Radius | Rollback Complexity |
|-------|-----------|--------------|---------------------|
| Issue 1 | Medium | Monitoring only | Low |
| Issue 2 | High | Monitoring only | Low |
| Issue 3 | Low | Monitoring only | Low |
| Issue 4 | Critical | Application tier | Low |
| Issue 5 | Critical | Application tier | N/A (requires new build) |
| Issue 6 | Medium | Monitoring only | Low |

---

## Conclusion

All six issues are interconnected, with Issues 1, 2, and 3 causing cascading failure (Issue 6). Issues 4 and 5 are independent but equally critical for application deployment.

**Automated Fixes**: Issues 1, 2, 3, 4, 6 can be fixed by editing configuration files  
**Manual Actions Required**: Issue 5 requires rebuilding Docker image with multi-arch support

**Estimated Fix Time**: 2-3 hours (excluding image rebuild time)  
**Estimated Testing Time**: 1-2 hours  
**Total Downtime**: 0 hours (changes can be applied without downtime if staged properly)

---

**End of Root Cause Analysis**

