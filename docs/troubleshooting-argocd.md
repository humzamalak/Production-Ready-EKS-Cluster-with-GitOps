# ArgoCD Troubleshooting Guide

This guide covers common issues encountered when deploying and managing ArgoCD in Kubernetes clusters, particularly in minikube environments.

## Table of Contents

1. [Common Pod Issues](#common-pod-issues)
2. [Application Sync Issues](#application-sync-issues)
3. [Secret Management](#secret-management)
4. [PodSecurity Policy Issues](#podsecurity-policy-issues)
5. [Network and Connectivity Issues](#network-and-connectivity-issues)
6. [Monitoring Stack Issues](#monitoring-stack-issues)

## Common Pod Issues

### CreateContainerConfigError

**Symptoms:**
- Pods stuck in `CreateContainerConfigError` status
- Error messages about missing secrets or config maps

**Common Causes and Solutions:**

#### Missing Redis Secret
```bash
# Check if argocd-redis secret exists
kubectl get secret argocd-redis -n argocd

# Create if missing
kubectl create secret generic argocd-redis \
  --namespace=argocd \
  --from-literal=auth=$(openssl rand -base64 32)
```

#### Missing Grafana Admin Secret
```bash
# Check if grafana-admin secret exists
kubectl get secret grafana-admin -n monitoring

# Create if missing
kubectl create secret generic grafana-admin \
  --namespace=monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=$(openssl rand -base64 16)
```

### CrashLoopBackOff

**Symptoms:**
- Pods restarting repeatedly
- Application failing to start

**Debugging Steps:**
```bash
# Check pod logs
kubectl logs -l app.kubernetes.io/name=argocd-server -n argocd --tail=50

# Check pod events
kubectl describe pod <pod-name> -n argocd

# Check resource usage
kubectl top pods -n argocd
```

## Application Sync Issues

### OutOfSync Status

**Symptoms:**
- Applications showing `OutOfSync` status
- Changes not being applied

**Solutions:**

#### Force Refresh
```bash
# Refresh application from Git
kubectl patch application <app-name> -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

#### Check Git Repository
```bash
# Verify repository connectivity
kubectl describe application <app-name> -n argocd

# Check for authentication issues
kubectl logs -l app.kubernetes.io/name=argocd-repo-server -n argocd
```

### Project Reference Errors

**Symptoms:**
- Applications referencing non-existent projects
- Error: "Application referencing project X which does not exist"

**Solution:**
Update application to use `default` project:
```yaml
spec:
  project: default  # Instead of production-apps
```

## Secret Management

### Automated Secret Creation

Use the provided script to create all required secrets:

```bash
# Run the secret creation script
./scripts/create-monitoring-secrets.sh
```

### Manual Secret Creation

#### ArgoCD Redis Secret
```bash
kubectl create secret generic argocd-redis \
  --namespace=argocd \
  --from-literal=auth=$(openssl rand -base64 32)
```

#### Grafana Admin Secret
```bash
kubectl create secret generic grafana-admin \
  --namespace=monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=$(openssl rand -base64 16)
```

## PodSecurity Policy Issues

### Node Exporter Issues

**Symptoms:**
- Node exporter pods failing to start
- PodSecurity policy violations

**Minikube Solution:**
Node exporter is disabled by default in minikube due to PodSecurity policy restrictions:

```yaml
nodeExporter:
  enabled: false  # Disabled for minikube compatibility
```

**Production Solution:**
For production environments, configure appropriate PodSecurity policies or use privileged namespaces.

### Security Context Issues

**Symptoms:**
- Pods failing due to security context violations
- ReadOnlyRootFilesystem errors

**Solutions:**
```yaml
# For development/minikube
securityContext:
  runAsNonRoot: false
  runAsUser: 0
  readOnlyRootFilesystem: false

# For production
securityContext:
  runAsNonRoot: true
  runAsUser: 999
  readOnlyRootFilesystem: true
```

## Network and Connectivity Issues

### Ingress Configuration

**Symptoms:**
- Applications not accessible via ingress
- TLS certificate issues

**Debugging:**
```bash
# Check ingress status
kubectl get ingress -A

# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress events
kubectl describe ingress <ingress-name> -n <namespace>
```

### Service Connectivity

**Symptoms:**
- Services not accessible
- DNS resolution issues

**Debugging:**
```bash
# Check service endpoints
kubectl get endpoints -A

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- nslookup <service-name>.<namespace>.svc.cluster.local
```

## Monitoring Stack Issues

### Grafana Configuration Issues

**Symptoms:**
- Grafana failing to start
- Datasource connection errors

**Solutions:**

#### Check Grafana Logs
```bash
kubectl logs -l app.kubernetes.io/name=grafana -n monitoring
```

#### Verify Datasource Configuration
```bash
# Check if Prometheus service is accessible
kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring

# Test connectivity from Grafana pod
kubectl exec -it <grafana-pod> -n monitoring -- curl http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/api/v1/status/config
```

### Prometheus Issues

**Symptoms:**
- Prometheus pods not starting
- CRD validation errors

**Solutions:**

#### Check CRD Status
```bash
# List all CRDs
kubectl get crd | grep monitoring.coreos.com

# Check specific CRD
kubectl describe crd prometheuses.monitoring.coreos.com
```

#### Verify Storage Classes
```bash
# Check available storage classes
kubectl get storageclass

# For minikube, ensure 'standard' storage class exists
kubectl get storageclass standard -o yaml
```

## Quick Diagnostic Commands

### Check Overall Cluster Health
```bash
# Check all pods status
kubectl get pods -A | grep -E "(Error|CrashLoop|Pending|CreateContainerConfig)"

# Check application status
kubectl get applications -A

# Check services
kubectl get svc -A | grep -E "(argocd|grafana|prometheus|k8s-web-app)"
```

### Check Resource Usage
```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -A

# Check events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

### Verify GitOps Workflow
```bash
# Check ArgoCD server logs
kubectl logs -l app.kubernetes.io/name=argocd-server -n argocd --tail=50

# Check application controller logs
kubectl logs -l app.kubernetes.io/name=argocd-application-controller -n argocd --tail=50
```

## Prevention Best Practices

1. **Always check prerequisites** before deploying applications
2. **Use the provided scripts** for secret creation (`./scripts/create-monitoring-secrets.sh`)
3. **Monitor application sync status** regularly
4. **Keep resource limits appropriate** for your environment
5. **Test configurations** in development before production
6. **Document custom configurations** for team members
7. **Review code comments** in configuration files for guidance
8. **Use comprehensive logging** to troubleshoot issues
9. **Implement proper monitoring** with Prometheus and Grafana
10. **Follow security best practices** with Pod Security Standards

## Getting Help

If you encounter issues not covered in this guide:

1. Check the application logs for specific error messages
2. Verify all prerequisites are met
3. Ensure configurations match your environment (minikube vs production)
4. Consult the official ArgoCD documentation
5. Check Kubernetes and Helm chart documentation for specific components
