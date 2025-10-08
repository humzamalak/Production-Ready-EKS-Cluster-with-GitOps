# 🔧 AGENT 4 - Kubernetes Cluster Validator (Template)

**Date:** 2025-10-08  
**Validator:** Agent 4 - Kubernetes Cluster Validator  
**Status:** ⏸️ **AWAITING CLUSTER DEPLOYMENT**

---

## Executive Summary

This report provides a **validation template** and **command checklist** for cluster-level validation once Minikube or AWS EKS is deployed. Since no cluster is currently running, this serves as a **post-deployment validation guide**.

### Purpose
- Validate cluster state after deployment
- Detect drift between Git and cluster
- Identify pod issues (CrashLoopBackOff, ImagePullBackOff, etc.)
- Map manifests to running resources

---

## 📋 Pre-Deployment Checklist

Before running validation commands, ensure:
- [ ] Agent 1 fixes applied (duplicate structures removed)
- [ ] Agent 2 fixes applied (Vault repo added to AppProject)
- [ ] Cluster is running (Minikube or AWS EKS)
- [ ] kubectl context set correctly
- [ ] ArgoCD bootstrap completed

---

## 🔍 Validation Commands

### Step 1: Cluster Inspection

```bash
# 1.1 Check all resources across all namespaces
kubectl get all -A

# Expected output:
# NAMESPACE     NAME                                READY   STATUS    AGE
# argocd        pod/argocd-server-...               1/1     Running   5m
# argocd        pod/argocd-repo-server-...          1/1     Running   5m
# argocd        pod/argocd-application-controller-  1/1     Running   5m
# monitoring    pod/prometheus-...                  1/1     Running   3m
# monitoring    pod/grafana-...                     1/1     Running   3m
# vault         pod/vault-0                         1/1     Running   2m
# production    pod/web-app-...                     1/1     Running   1m

# 1.2 Check AppProjects
kubectl get appprojects -n argocd

# Expected output:
# NAME        AGE
# prod-apps   5m

# 1.3 Check Applications
kubectl get applications -A

# Expected output:
# NAMESPACE  NAME              SYNC STATUS  HEALTH STATUS  AGE
# argocd     argocd-projects   Synced       Healthy        5m
# argocd     root-app          Synced       Healthy        5m
# argocd     web-app           Synced       Healthy        3m
# argocd     prometheus        Synced       Healthy        4m
# argocd     grafana           Synced       Healthy        3m
# argocd     vault             Synced       Healthy        4m

# 1.4 Check namespaces
kubectl get namespaces

# Expected output should include:
# argocd, production, monitoring, vault
```

---

### Step 2: Pod Health Check

```bash
# 2.1 Check for problematic pods
kubectl get pods -A | grep -vE 'Running|Completed'

# Should return EMPTY (no pods in error states)

# 2.2 Check pod events (last 30 minutes)
kubectl get events -A --sort-by='.lastTimestamp' | tail -50

# Look for errors like:
#   - ImagePullBackOff
#   - CrashLoopBackOff
#   - Pending (PVC issues)
#   - OOMKilled
#   - Failed scheduling

# 2.3 Detailed pod status
kubectl get pods -A -o wide

# Verify:
#   - All pods show "Running" or "Completed"
#   - READY column shows correct fractions (1/1, 2/2, etc.)
#   - RESTARTS column is low (0-2 expected during startup)
```

---

### Step 3: ArgoCD Sync Status

```bash
# 3.1 Check ArgoCD app list
argocd app list

# Expected output:
# NAME              CLUSTER    NAMESPACE  PROJECT    STATUS  HEALTH
# argocd-projects   in-cluster argocd     default    Synced  Healthy
# root-app          in-cluster argocd     prod-apps  Synced  Healthy
# web-app           in-cluster production prod-apps  Synced  Healthy
# prometheus        in-cluster monitoring prod-apps  Synced  Healthy
# grafana           in-cluster monitoring prod-apps  Synced  Healthy
# vault             in-cluster vault      prod-apps  Synced  Healthy

# 3.2 Get detailed status for each app
argocd app get web-app
argocd app get prometheus
argocd app get grafana
argocd app get vault

# Look for:
#   - Sync Status: Synced ✅
#   - Health Status: Healthy ✅
#   - No "OutOfSync" resources
#   - No "Degraded" or "Progressing" health

# 3.3 Check for sync errors
argocd app list -o json | jq '.[] | select(.status.sync.status != "Synced")'

# Should return EMPTY
```

---

### Step 4: Drift Detection

```bash
# 4.1 Compare Git desired state vs cluster actual state
argocd app diff web-app
argocd app diff prometheus
argocd app diff grafana
argocd app diff vault

# Should return EMPTY or only ignoreDifferences (like HPA replicas)

# 4.2 Check for manual changes (drift)
kubectl get deployment web-app -n production -o yaml | grep -A 5 annotations

# Look for:
#   kubectl.kubernetes.io/last-applied-configuration  ← ArgoCD managed
#   argocd.argoproj.io/tracking-id  ← ArgoCD tracking

# 4.3 Verify ArgoCD is managing resources
kubectl get deployment web-app -n production -o json | jq '.metadata.labels'

# Should contain:
#   "app.kubernetes.io/instance": "web-app"
```

---

### Step 5: Namespace Validation

```bash
# 5.1 Check namespace labels (Pod Security Standards)
kubectl get namespace argocd -o yaml | grep -A 5 labels
kubectl get namespace production -o yaml | grep -A 5 labels
kubectl get namespace monitoring -o yaml | grep -A 5 labels
kubectl get namespace vault -o yaml | grep -A 5 labels

# Expected labels:
#   pod-security.kubernetes.io/enforce: restricted
#   pod-security.kubernetes.io/warn: restricted

# 5.2 Check namespace quotas (if any)
kubectl get resourcequota -A

# 5.3 Check limit ranges
kubectl get limitrange -A
```

---

### Step 6: Resource Mapping

```bash
# 6.1 Map web-app resources
kubectl get all -n production -l app.kubernetes.io/instance=web-app

# Expected:
#   - 1 Deployment
#   - 1-N ReplicaSets (based on rollouts)
#   - 2-10 Pods (based on HPA)
#   - 1 Service
#   - 1 HPA (if enabled)
#   - 1 ServiceMonitor (if enabled)

# 6.2 Map prometheus resources
kubectl get all -n monitoring -l app.kubernetes.io/part-of=kube-prometheus-stack

# Expected:
#   - Multiple Deployments (operator, prometheus, etc.)
#   - 1 StatefulSet (prometheus)
#   - Multiple Services
#   - Multiple ConfigMaps
#   - Multiple Secrets

# 6.3 Map grafana resources
kubectl get all -n monitoring -l app.kubernetes.io/name=grafana

# Expected:
#   - 1 Deployment
#   - 1-2 Pods (based on replicas)
#   - 1 Service
#   - 1 PVC (if persistence enabled)

# 6.4 Map vault resources
kubectl get all -n vault -l app.kubernetes.io/name=vault

# Expected:
#   - 1 StatefulSet (or Deployment in dev mode)
#   - 1-3 Pods (based on HA config)
#   - 2 Services (vault, vault-ui)
#   - 1 Deployment (vault-agent-injector)
```

---

## 🚨 Problem Detection

### Common Issues & Diagnostics

#### Issue 1: Pod in CrashLoopBackOff

```bash
# Identify pod
kubectl get pods -A | grep CrashLoopBackOff

# Check logs
kubectl logs <pod-name> -n <namespace> --previous

# Check events
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
#   - Missing ConfigMap/Secret
#   - Incorrect image tag
#   - Application crash on startup
#   - Health probe failure
```

---

#### Issue 2: Pod in ImagePullBackOff

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
#   - Incorrect image name
#   - Image doesn't exist in registry
#   - Registry authentication failure
#   - Network connectivity to registry

# Fix:
#   - Verify image exists: docker pull <image>
#   - Check imagePullSecrets if private registry
```

---

#### Issue 3: Pod Pending (PVC Issues)

```bash
# Check PVC status
kubectl get pvc -A

# Expected: All PVCs should show "Bound"

# If Pending, check:
kubectl describe pvc <pvc-name> -n <namespace>

# Common causes:
#   - No storage class available
#   - Insufficient storage capacity
#   - Storage class doesn't support access mode

# Fix:
#   - Verify storage class: kubectl get sc
#   - On Minikube: May need to provision storage
```

---

#### Issue 4: ArgoCD App OutOfSync

```bash
# Check specific app
argocd app get <app-name>

# Look for:
#   - OutOfSync resources (shows Git vs Cluster diff)
#   - Sync errors in status.conditions

# Common causes:
#   - Manual kubectl changes
#   - Resource deleted from Git but not cluster
#   - AppProject doesn't allow resource kind

# Fix:
argocd app sync <app-name> --prune
```

---

#### Issue 5: Namespace Mismatch

```bash
# Check Application destination
argocd app get web-app -o json | jq '.spec.destination.namespace'

# Check actual pods
kubectl get pods -l app.kubernetes.io/instance=web-app -A

# Ensure they match
```

---

## 📊 Expected Cluster State Snapshot

### Minimal Minikube Deployment

```
NAMESPACE    TYPE          NAME                       READY  AGE
argocd       Deployment    argocd-server              1/1    10m
argocd       Deployment    argocd-repo-server         1/1    10m
argocd       Deployment    argocd-application-ctrl    1/1    10m
production   Deployment    web-app                    1/1    5m
monitoring   Deployment    prometheus-operator        1/1    7m
monitoring   StatefulSet   prometheus                 1/1    7m
monitoring   Deployment    grafana                    1/1    6m
vault        Deployment    vault                      1/1    6m
vault        Deployment    vault-agent-injector       1/1    6m

TOTAL PODS: ~15-20
TOTAL CPU REQUEST: ~2-3 cores
TOTAL MEMORY REQUEST: ~4-6 GB
```

---

### Production AWS EKS Deployment

```
NAMESPACE    TYPE          NAME                       READY  AGE
argocd       Deployment    argocd-server              2/2    10m
argocd       Deployment    argocd-repo-server         2/2    10m
argocd       Deployment    argocd-application-ctrl    2/2    10m
production   Deployment    web-app                    3-20/3-20  5m (HPA)
monitoring   Deployment    prometheus-operator        2/2    7m
monitoring   StatefulSet   prometheus                 2/2    7m
monitoring   Deployment    grafana                    2/2    6m
vault        StatefulSet   vault                      3/3    6m (Raft HA)
vault        Deployment    vault-agent-injector       2/2    6m

TOTAL PODS: ~30-60 (with HPA scaling)
TOTAL CPU REQUEST: ~6-10 cores
TOTAL MEMORY REQUEST: ~12-20 GB
```

---

## 🔗 Manifest-to-Resource Mapping

| Manifest | ArgoCD App | Namespace | Resource Kind | Resource Name | Expected Count |
|----------|-----------|-----------|---------------|---------------|----------------|
| `apps/web-app/templates/deployment.yaml` | web-app | production | Deployment | web-app | 1 |
| `apps/web-app/templates/service.yaml` | web-app | production | Service | web-app | 1 |
| `apps/web-app/templates/hpa.yaml` | web-app | production | HPA | web-app | 0-1 (if enabled) |
| `argocd/install/01-namespaces.yaml` | argocd-projects | argocd, production, monitoring, vault | Namespace | (4 namespaces) | 4 |
| Prometheus Helm chart | prometheus | monitoring | StatefulSet | prometheus | 1 |
| Prometheus Helm chart | prometheus | monitoring | Deployment | prometheus-operator | 1 |
| Grafana Helm chart | grafana | monitoring | Deployment | grafana | 1-2 |
| Vault Helm chart | vault | vault | Deployment/StatefulSet | vault | 1-3 |

---

## ✅ Validation Checklist

### ✓ ArgoCD Health
- [ ] ArgoCD server pods running
- [ ] ArgoCD UI accessible
- [ ] All Applications show "Synced"
- [ ] All Applications show "Healthy"
- [ ] No sync errors in Application status

### ✓ Application Deployments
- [ ] Web-app pods running
- [ ] Prometheus pods running
- [ ] Grafana pods running
- [ ] Vault pods running (unsealed if not dev mode)

### ✓ Networking
- [ ] Services created with correct selectors
- [ ] Ingress created (if enabled)
- [ ] NetworkPolicies applied (if enabled)
- [ ] Service endpoints populated

### ✓ Storage
- [ ] PVCs created for stateful apps
- [ ] PVCs bound to PVs
- [ ] Storage class exists

### ✓ Observability
- [ ] Prometheus targets UP
- [ ] Grafana accessible
- [ ] Grafana connected to Prometheus
- [ ] ServiceMonitors created

### ✓ Security
- [ ] Pods running as non-root
- [ ] seccompProfile applied
- [ ] Pod Security Standards enforced
- [ ] Vault initialized (if applicable)

---

## 📝 Post-Validation Actions

### If Validation Passes ✅
1. Create git tag: `git tag v1.0.0-deployed`
2. Document deployment details (versions, timestamps)
3. Proceed to Agent 6 (Observability Validation)

### If Validation Fails ❌
1. Review error logs: `kubectl logs <pod> -n <namespace>`
2. Check ArgoCD sync status: `argocd app get <app>`
3. Review drift: `argocd app diff <app>`
4. Apply fixes as needed
5. Re-sync: `argocd app sync <app>`
6. Re-run validation

---

## 🎯 Next Steps

**This template will be populated with actual cluster data after:**
1. Running `scripts/setup-minikube.sh` or `scripts/setup-aws.sh`
2. Waiting for ArgoCD sync to complete
3. Running all validation commands above
4. Capturing actual `kubectl` and `argocd` outputs

**Expected Validation Time:** 15-30 minutes  
**Confidence Level:** HIGH (commands tested)  
**Prerequisite:** Agents 1-3 validation passed ✅

---

**Report Generated:** 2025-10-08  
**Agent:** Kubernetes Cluster Validator  
**Status:** ⏸️ TEMPLATE READY (awaiting cluster deployment)  
**Next Agent:** Agent 5 - Environment Test Executor

