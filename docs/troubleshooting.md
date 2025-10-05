# Troubleshooting Guide

Comprehensive guide for diagnosing and resolving common issues in GitOps deployments with ArgoCD, Kubernetes, and Vault.

## 📋 Table of Contents

1. [Quick Diagnostic Commands](#quick-diagnostic-commands)
2. [ArgoCD Issues](#argocd-issues)
3. [Kubernetes Issues](#kubernetes-issues)
4. [Vault Issues](#vault-issues)
5. [Monitoring Issues](#monitoring-issues)
6. [Network Issues](#network-issues)
7. [Resource Issues](#resource-issues)
8. [Application Issues](#application-issues)

## 🚨 Quick Reference

### Most Common Issues
1. **ArgoCD Applications not syncing** → [Force refresh](#force-refresh)
2. **Pods stuck in Pending** → [Check resources](#pods-stuck-in-pending)
3. **Vault sealed** → [Unseal Vault](#vault-sealed)
4. **CRD annotation size errors** → [Use external values](#crd-annotation-size-issues)
5. **Port forward issues** → [Kill and restart](#port-forward-issues)

### Quick Diagnostic Commands

### Overall Cluster Health

```bash
# Check all pods status
kubectl get pods -A | grep -v "Running\|Completed"

# Check all applications
kubectl get applications -n argocd

# Check services
kubectl get svc -A | grep -E "(argocd|grafana|prometheus|k8s-web-app)"

# Check events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

### Resource Usage

```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -A

# Check resource limits
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Limits:"
```

### Network Connectivity

```bash
# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it --restart=Never -- \
  nslookup kubernetes.default.svc.cluster.local

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- \
  wget -O- http://prometheus-kube-prometheus-stack-prometheus.monitoring:9090/-/healthy
```

## 🔵 ArgoCD Issues

### CRD Annotation Size Issues

#### Symptoms
```
CustomResourceDefinition.apiextensions.k8s.io "prometheuses.monitoring.coreos.com" is invalid: 
metadata.annotations: Too long: may not be more than 262144 bytes
```

#### Root Cause
Kubernetes has a hard limit of **262,144 bytes (256KB)** for annotations on any resource, including CustomResourceDefinitions (CRDs). When ArgoCD Applications have large inline Helm values, these values are stored in annotations, which can exceed this limit.

#### Solutions

**Use External Values Files**:
```bash
# Check current valueFiles being used
kubectl get application <app-name> -n argocd -o jsonpath='{.spec.source.helm.valueFiles}'

# Update to use external values file
kubectl patch application <app-name> -n argocd --type merge -p '
{
  "spec": {
    "sources": [
      {
        "repoURL": "https://github.com/your-org/your-repo",
        "path": "applications/monitoring/prometheus"
      },
      {
        "repoURL": "https://github.com/your-org/your-repo", 
        "path": "applications/monitoring/prometheus"
      }
    ],
    "helm": {
      "valueFiles": ["values.yaml"]
    }
  }
}'
```

**Choose Lighter Charts**:
- Use `prometheus` instead of `kube-prometheus-stack`
- Use individual charts instead of umbrella charts
- Avoid charts with inherently large CRDs

**Split Complex Applications**:
```bash
# Instead of one large application, create multiple focused ones
# monitoring-prometheus.yaml
# monitoring-grafana.yaml
# logging-promtail.yaml
```

**Validate Before Deploy**:
```bash
# Check annotation size
kubectl get application <app-name> -n argocd -o yaml | wc -c

# Use validation script
./scripts/validate-argocd-apps.sh
```

### Application Not Syncing

#### Symptoms
- Applications showing `OutOfSync` status
- Changes not being applied
- Sync failures

#### Solutions

**Force Refresh**:
```bash
# Via kubectl
kubectl patch application <app-name> -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Via ArgoCD CLI
argocd app sync <app-name>
```

**Check Repository Connectivity**:
```bash
# Verify repository access
kubectl describe application <app-name> -n argocd

# Check for authentication issues
kubectl logs -n argocd deployment/argocd-repo-server --tail=100
```

**Project Reference Errors**:
```bash
# Check if project exists
kubectl get appproject -n argocd

# Update application to use default project if needed
kubectl patch application <app-name> -n argocd --type merge -p '
{
  "spec": {
    "project": "default"
  }
}'
```

### Application Stuck in "Progressing" State

#### Symptoms
- Application shows "Progressing" for extended period
- No error messages visible

#### Solutions

```bash
# Check application status
kubectl get application <app-name> -n argocd -o jsonpath='{.status.sync.status}'

# Check detailed sync status
kubectl describe application <app-name> -n argocd | grep -A 20 "Status:"

# Check if pods are running
kubectl get pods -n <target-namespace>

# View ArgoCD application controller logs
kubectl logs -n argocd deployment/argocd-application-controller --tail=100 | grep <app-name>
```

### Secret Reference Errors

#### Symptoms
```
Failed sync attempt: Deployment.apps "k8s-web-app" is invalid: 
spec.template.spec.containers[0].env[3].valueFrom.secretKeyRef.name: 
Invalid value: "": a lowercase RFC 1123 subdomain must consist of...
```

#### Solutions

**Check Values Configuration**:
```bash
# Check current valueFiles being used
kubectl get application k8s-web-app -n argocd -o jsonpath='{.spec.source.helm.valueFiles}'

# For production WITHOUT Vault: should show ["values.yaml"]
# For production WITH Vault: should show ["values.yaml","values-vault-enabled.yaml"]
```

**Update Application Configuration**:
```bash
# Update if incorrect (production without Vault)
kubectl patch application k8s-web-app -n argocd --type merge -p '
{
  "spec": {
    "source": {
      "helm": {
        "valueFiles": ["values.yaml"]
      }
    }
  }
}'

# Wait for sync
kubectl wait --for=condition=Synced --timeout=300s application/k8s-web-app -n argocd
```

**Debug Helm Template**:
```bash
# Check helm values being used
cd applications/web-app/k8s-web-app
helm template ./helm -f values.yaml | grep -A 10 "secretKeyRef"

# Verify values file has correct configuration
cat values.yaml | grep -A 5 "vault:"
# Should show: vault.enabled: false (if not using Vault yet)
```

### ArgoCD Pod Issues

#### CreateContainerConfigError

**Symptoms**: ArgoCD pods stuck in `CreateContainerConfigError` status

**Solutions**:

**Missing Redis Secret**:
```bash
# Check if argocd-redis secret exists
kubectl get secret argocd-redis -n argocd

# Create if missing
kubectl create secret generic argocd-redis \
  --namespace=argocd \
  --from-literal=auth=$(openssl rand -base64 32)
```

**Missing Grafana Admin Secret**:
```bash
# Check if grafana-admin secret exists
kubectl get secret grafana-admin -n monitoring

# Create if missing
kubectl create secret generic grafana-admin \
  --namespace=monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=$(openssl rand -base64 16)
```

#### CrashLoopBackOff

**Debugging Steps**:
```bash
# Check pod logs
kubectl logs -l app.kubernetes.io/name=argocd-server -n argocd --tail=50

# Check pod events
kubectl describe pod <pod-name> -n argocd

# Check resource usage
kubectl top pods -n argocd
```

## ☸️ Kubernetes Issues

### Pod Issues

#### Pods Stuck in Pending

**Symptoms**: Pods remain in Pending state

**Solutions**:
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl describe node <node-name>

# Check resource quotas
kubectl describe quota -n <namespace>

# Check storage classes
kubectl get storageclass
```

#### Pods CrashLoopBackOff

**Symptoms**: Pods restarting repeatedly

**Solutions**:
```bash
# Check pod logs
kubectl logs <pod-name> -n <namespace> --tail=50

# Check previous pod logs (if crashed)
kubectl logs <pod-name> -n <namespace> --previous

# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check resource limits
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Limits:"
```

### Node Issues

#### Nodes Not Ready

**Symptoms**: Nodes show NotReady status

**Solutions**:
```bash
# Check node status
kubectl describe node <node-name>

# Check node events
kubectl get events --field-selector involvedObject.name=<node-name>

# For EKS, check cluster status
aws eks describe-cluster --name <cluster-name> --region <region>
```

### Storage Issues

#### Persistent Volume Issues

**Symptoms**: PVCs stuck in Pending state

**Solutions**:
```bash
# Check PVC status
kubectl get pvc -n <namespace>
kubectl describe pvc <pvc-name> -n <namespace>

# Check storage classes
kubectl get storageclass

# Check PV status
kubectl get pv
```

## 🔐 Vault Issues

### Vault Not Starting

#### Symptoms
- Vault pod in CrashLoopBackOff or Pending state
- Vault inaccessible

**Solutions**:
```bash
# Check pod logs
kubectl logs vault-0 -n vault

# Check resource constraints
kubectl describe pod vault-0 -n vault

# Check if port 8200 is in use
kubectl get svc -n vault

# Check storage class
kubectl get storageclass
```

### Vault Sealed

#### Symptoms
- Vault returns "Vault is sealed" error
- Cannot access secrets

**Solutions**:
```bash
# Check Vault status
vault status

# Unseal Vault
vault operator unseal <unseal-key>

# For multiple keys (production)
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
vault operator unseal <unseal-key-3>
```

### Vault Agent Not Injecting Secrets

#### Symptoms
- Secrets not appearing in application pods
- Vault agent logs show errors

**Solutions**:
```bash
# Check annotations on pod
kubectl get pod <pod-name> -n <namespace> -o yaml | grep vault.hashicorp.com

# Check vault-agent logs
kubectl logs <pod-name> -n <namespace> -c vault-agent

# Check vault-agent-init logs
kubectl logs <pod-name> -n <namespace> -c vault-agent-init

# Verify Vault role exists
vault read auth/kubernetes/role/k8s-web-app

# Verify secrets exist
vault kv list secret/production/web-app/
```

### Vault Authentication Failures

#### Symptoms
- Vault authentication errors in logs
- Cannot access Vault from pods

**Solutions**:
```bash
# Check service account
kubectl get sa k8s-web-app -n production -o yaml

# Verify Vault role
vault read auth/kubernetes/role/k8s-web-app

# Test authentication manually
vault write auth/kubernetes/login role=k8s-web-app jwt=$(kubectl get sa k8s-web-app -n production -o jsonpath='{.secrets[0].name}' | xargs kubectl get secret -n production -o jsonpath='{.data.token}' | base64 -d)
```

### Vault CSI Provider Issues

#### Symptoms
- `kubectl -n vault rollout status ds/vault-csi-provider` hangs
- Pod Security Admission violations

**Solutions**:
```bash
# Check DaemonSet status
kubectl -n vault get ds vault-csi-provider -o wide
kubectl -n vault describe ds vault-csi-provider

# Check events
kubectl -n vault get events --sort-by=.lastTimestamp | tail -n 100

# Force clean stuck resources
kubectl -n vault delete pod -l app.kubernetes.io/name=vault-csi-provider --force --grace-period=0

# If DaemonSet controller is wedged
kubectl -n vault delete ds vault-csi-provider --grace-period=0 --force --cascade=orphan
```

## 📊 Monitoring Issues

### Prometheus Issues

#### Prometheus Pods Not Starting

**Symptoms**: Prometheus pods crashlooping or pending

**Solutions**:
```bash
# Check pod logs
kubectl logs -n monitoring statefulset/prometheus-kube-prometheus-stack-prometheus

# Check PVC and storage
kubectl get pvc -n monitoring
kubectl describe pvc prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0 -n monitoring

# Check CRD status
kubectl get crd | grep monitoring.coreos.com
```

#### Prometheus Not Collecting Metrics

**Symptoms**: No targets in Prometheus UI

**Solutions**:
```bash
# Check ServiceMonitors
kubectl get servicemonitors -n monitoring

# Check targets via API
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'

# Check Prometheus config
kubectl get configmap prometheus-kube-prometheus-stack-prometheus-rulefiles-0 -n monitoring -o yaml
```

### Grafana Issues

#### Grafana Not Starting

**Symptoms**: Grafana pods failing to start

**Solutions**:
```bash
# Check pod logs
kubectl logs -l app.kubernetes.io/name=grafana -n monitoring

# Check secret
kubectl get secret grafana-admin -n monitoring

# Restart Grafana
kubectl rollout restart deployment/grafana -n monitoring
```

#### Grafana Datasource Issues

**Symptoms**: Prometheus datasource not working

**Solutions**:
```bash
# Check if Prometheus service is accessible
kubectl get svc prometheus-kube-prometheus-stack-prometheus -n monitoring

# Test connectivity from Grafana pod
kubectl exec -it <grafana-pod> -n monitoring -- curl http://prometheus-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/status/config
```

## 🌐 Network Issues

### Ingress Configuration

#### Symptoms
- Applications not accessible via ingress
- TLS certificate issues

**Solutions**:
```bash
# Check ingress status
kubectl get ingress -A

# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress events
kubectl describe ingress <ingress-name> -n <namespace>

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### Service Connectivity

#### Symptoms
- Services not accessible
- DNS resolution issues

**Solutions**:
```bash
# Check service endpoints
kubectl get endpoints -A

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- nslookup <service-name>.<namespace>.svc.cluster.local

# Check service configuration
kubectl describe svc <service-name> -n <namespace>
```

## 💾 Resource Issues

### Out of Resources

#### Symptoms
- Pods stuck in Pending
- Node pressure conditions

**Solutions**:
```bash
# Check node resources
kubectl top nodes
kubectl describe nodes

# Check resource quotas
kubectl get quota -A

# Reduce resource requests
kubectl patch deployment <deployment-name> -n <namespace> -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<container-name>",
          "resources": {
            "requests": {
              "cpu": "50m",
              "memory": "128Mi"
            }
          }
        }]
      }
    }
  }
}'
```

### Storage Issues

#### Symptoms
- PVCs stuck in Pending
- Storage class issues

**Solutions**:
```bash
# Check storage classes
kubectl get storageclass

# Check PV status
kubectl get pv

# For minikube, ensure 'standard' storage class exists
kubectl get storageclass standard -o yaml

# For EKS, check EBS volumes
aws ec2 describe-volumes --region <region>
```

## 🌐 Application Issues

### Web Application Issues

#### Application Not Starting

**Symptoms**: Web app pods not running

**Solutions**:
```bash
# Check pod logs
kubectl logs -n production deployment/k8s-web-app --tail=50

# Check pod events
kubectl describe pod -n production -l app.kubernetes.io/name=k8s-web-app

# Check environment variables
kubectl exec -n production deployment/k8s-web-app -- env
```

#### Application Can't Read Secrets

**Symptoms**: Application errors about missing environment variables

**Solutions**:
```bash
# Check if secrets exist in pod
kubectl exec -n production deployment/k8s-web-app -- ls -R /vault/secrets/

# Check vault-agent logs
kubectl logs -n production deployment/k8s-web-app -c vault-agent

# Restart deployment
kubectl rollout restart deployment k8s-web-app -n production
```

### Port Forward Issues

#### Symptoms
- Port forward dies or hangs
- Cannot access services

**Solutions**:
```bash
# Kill all existing port forwards
pkill -f "kubectl port-forward"

# Check if ports are in use
lsof -i :8080  # ArgoCD
lsof -i :9090  # Prometheus
lsof -i :3000  # Grafana
lsof -i :8200  # Vault
lsof -i :8081  # Web App

# Kill process using port
kill -9 <PID>

# Restart port forward
kubectl port-forward svc/<service-name> -n <namespace> <local-port>:<service-port> &
```

## 🔧 Prevention Best Practices

### Regular Maintenance

1. **Monitor Resource Usage**: Regularly check `kubectl top nodes` and `kubectl top pods -A`
2. **Review Events**: Check `kubectl get events -A` for warnings
3. **Validate Configurations**: Use `helm lint` and `kubectl apply --dry-run=client`
4. **Test Connectivity**: Regularly test service connectivity and DNS resolution

### Proactive Monitoring

1. **Set up Alerts**: Configure AlertManager rules for critical issues
2. **Monitor Application Health**: Use health checks and readiness probes
3. **Log Aggregation**: Centralize logs for easier troubleshooting
4. **Backup Strategies**: Regular backups of etcd and Vault

### Documentation

1. **Keep Documentation Updated**: Document any custom configurations
2. **Record Troubleshooting Steps**: Keep track of solutions for future reference
3. **Share Knowledge**: Ensure team members know common troubleshooting procedures

---

**Need More Help?** Check the [Architecture Guide](architecture.md) for understanding the repository structure or refer to the official documentation for specific components.
