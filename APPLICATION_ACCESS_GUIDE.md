# Application Access Guide

Comprehensive guide for accessing and using Prometheus, Grafana, Vault, and ArgoCD after deployment.

## 📋 Table of Contents

- [Quick Access Summary](#quick-access-summary)
- [ArgoCD](#argocd)
- [Prometheus](#prometheus)
- [Grafana](#grafana)
- [HashiCorp Vault](#hashicorp-vault)
- [Web Application](#web-application)
- [Troubleshooting Access](#troubleshooting-access)

---

## 🚀 Quick Access Summary

After completing deployment, use these commands to access all services:

```bash
# Stop any existing port forwards
pkill -f "kubectl port-forward"

# ArgoCD
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443 > /dev/null 2>&1 &

# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus -n monitoring 9090:9090 > /dev/null 2>&1 &

# Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80 > /dev/null 2>&1 &

# Vault
kubectl port-forward svc/vault -n vault 8200:8200 > /dev/null 2>&1 &

# Web Application
kubectl port-forward svc/k8s-web-app -n production 8081:80 > /dev/null 2>&1 &

# Give services a moment to start
sleep 3

echo "✅ All services are accessible:"
echo "   ArgoCD:      https://localhost:8080"
echo "   Prometheus:  http://localhost:9090"
echo "   Grafana:     http://localhost:3000"
echo "   Vault:       http://localhost:8200"
echo "   Web App:     http://localhost:8081"
```

---

## 🔵 ArgoCD

### Access ArgoCD UI

```bash
# Port forward to ArgoCD server
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443 &

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

**Access:**
- **URL**: https://localhost:8080
- **Username**: `admin`
- **Password**: Retrieved from the command above

### ArgoCD Common Operations

#### View All Applications
```bash
kubectl get applications -n argocd
```

#### Check Application Status
```bash
# Detailed status
kubectl describe application <app-name> -n argocd

# Quick status check
kubectl get application <app-name> -n argocd -o jsonpath='{.status.sync.status}'
```

#### Force Sync an Application
```bash
# Via kubectl
kubectl patch application <app-name> -n argocd \
  --type merge -p '{"operation":{"sync":{}}}'

# Via ArgoCD CLI (if installed)
argocd app sync <app-name>
```

#### View Application Logs
```bash
# Application controller logs
kubectl logs -n argocd deployment/argocd-application-controller --tail=100

# Server logs
kubectl logs -n argocd deployment/argocd-server --tail=100
```

### ArgoCD CLI Setup (Optional)

```bash
# Install ArgoCD CLI
# macOS
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd /usr/local/bin/argocd

# Login
argocd login localhost:8080 \
  --username admin \
  --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) \
  --insecure

# List applications
argocd app list

# Get application details
argocd app get <app-name>
```

---

## 📊 Prometheus

### Access Prometheus UI

```bash
# Port forward to Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus \
  -n monitoring 9090:9090 &
```

**Access:**
- **URL**: http://localhost:9090
- **Authentication**: None (default)

### Prometheus Features & Usage

#### 1. Status & Health Check

```bash
# Check Prometheus health
curl -s http://localhost:9090/-/healthy

# Check readiness
curl -s http://localhost:9090/-/ready

# View configuration
# Navigate to: Status → Configuration in UI
```

#### 2. Targets & Service Discovery

**Navigate to**: Status → Targets

This shows all discovered targets and their health:
- Kubernetes API server
- Node exporters
- Pod metrics
- Service monitors
- Custom application metrics

```bash
# Query active targets via API
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'
```

#### 3. Useful Prometheus Queries (PromQL)

Access the query interface at http://localhost:9090/graph

**Cluster Resources:**
```promql
# CPU usage by node
sum(rate(container_cpu_usage_seconds_total[5m])) by (node)

# Memory usage by namespace
sum(container_memory_usage_bytes) by (namespace)

# Pod CPU usage
rate(container_cpu_usage_seconds_total{namespace="production"}[5m])

# Pod memory usage
container_memory_usage_bytes{namespace="production"}
```

**Application Metrics:**
```promql
# HTTP request rate
rate(http_requests_total[5m])

# Error rate
rate(http_requests_total{status=~"5.."}[5m])

# Request duration (95th percentile)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

**Kubernetes Metrics:**
```promql
# Number of pods per namespace
count(kube_pod_info) by (namespace)

# Pod restart count
kube_pod_container_status_restarts_total

# Node status
kube_node_status_condition{condition="Ready"}

# Persistent volume usage
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes
```

#### 4. Alerts

**Navigate to**: Alerts

View active and pending alerts:
```bash
# Query alerts via API
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.type=="alerting")'

# View firing alerts
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.state=="firing")'
```

#### 5. Query API

```bash
# Instant query
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.'

# Range query (last hour)
curl -s 'http://localhost:9090/api/v1/query_range?query=up&start=$(date -u -d "1 hour ago" +%s)&end=$(date +%s)&step=15s' | jq '.'

# Label values
curl -s 'http://localhost:9090/api/v1/label/job/values' | jq '.'
```

### Prometheus Configuration

```bash
# View Prometheus config
kubectl get configmap prometheus-kube-prometheus-stack-prometheus-rulefiles-0 \
  -n monitoring -o yaml

# View ServiceMonitors
kubectl get servicemonitors -n monitoring

# Describe a ServiceMonitor
kubectl describe servicemonitor prometheus-kube-prometheus-stack-prometheus \
  -n monitoring
```

---

## 📈 Grafana

### Access Grafana UI

```bash
# Get Grafana admin password
kubectl get secret grafana-admin -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d && echo

# Port forward to Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80 &
```

**Access:**
- **URL**: http://localhost:3000
- **Username**: `admin`
- **Password**: Retrieved from the command above

### Grafana Features & Usage

#### 1. Default Dashboards

After logging in, navigate to **Dashboards** → **Browse**

**Pre-installed Kubernetes Dashboards:**
- **Kubernetes / Compute Resources / Cluster** - Overall cluster metrics
- **Kubernetes / Compute Resources / Namespace (Pods)** - Per-namespace resource usage
- **Kubernetes / Compute Resources / Node (Pods)** - Per-node resource usage
- **Kubernetes / Compute Resources / Pod** - Individual pod metrics
- **Kubernetes / Networking / Cluster** - Network traffic and throughput
- **Kubernetes / Networking / Namespace (Pods)** - Namespace-level networking
- **Node Exporter / Nodes** - Detailed node metrics (CPU, memory, disk, network)

**Application Dashboards:**
- **Kubernetes / Views / Pods** - Pod status and lifecycle
- **Kubernetes / Persistent Volumes** - Storage metrics

#### 2. Data Sources

**Navigate to**: Configuration → Data Sources

**Verify Prometheus Connection:**
```bash
# Should show "Prometheus" with green checkmark
# Default URL: http://prometheus-kube-prometheus-stack-prometheus:9090
```

**Test data source:**
1. Click on "Prometheus" data source
2. Scroll to bottom
3. Click "Save & Test"
4. Should show "Data source is working"

#### 3. Create Custom Dashboard

**Steps:**
1. Click **+** (Create) → **Dashboard**
2. Click **Add new panel**
3. Enter PromQL query in "Metrics browser"
4. Configure visualization type (Time series, Gauge, Stat, etc.)
5. Click **Apply** to save panel
6. Click **Save dashboard** (disk icon) in top right

**Example Panel - Pod Memory Usage:**
```promql
sum(container_memory_usage_bytes{namespace="production", pod=~"k8s-web-app.*"}) by (pod)
```

**Example Panel - HTTP Request Rate:**
```promql
sum(rate(http_requests_total{namespace="production"}[5m])) by (service)
```

#### 4. Alerting in Grafana

**Navigate to**: Alerting → Alert rules

**Create an Alert:**
1. Go to panel edit mode
2. Click "Alert" tab
3. Configure alert condition
4. Set evaluation interval
5. Add notification channel
6. Save dashboard

**View Alert Status:**
```bash
# Get Grafana alerts via API
curl -s -u admin:$(kubectl get secret grafana-admin -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d) \
  http://localhost:3000/api/alerts | jq '.'
```

#### 5. Grafana Explore

**Navigate to**: Explore (compass icon)

Use Explore mode to:
- Run ad-hoc PromQL queries
- Visualize metrics without creating dashboards
- Debug and test queries
- View logs (if Loki is configured)

**Example Explore Queries:**
```promql
# CPU usage trend
rate(container_cpu_usage_seconds_total{namespace="production"}[5m])

# Memory usage by pod
container_memory_usage_bytes{namespace="production"}

# Network traffic
rate(container_network_transmit_bytes_total{namespace="production"}[5m])
```

#### 6. Import Community Dashboards

**Navigate to**: Dashboards → Import

**Popular Dashboard IDs:**
- **1860** - Node Exporter Full
- **8588** - Kubernetes Deployment Statefulset Daemonset metrics
- **11074** - Node Exporter for Prometheus Dashboard
- **7249** - Kubernetes Cluster Monitoring
- **6417** - Kubernetes Cluster Overview

**Import Steps:**
1. Click "Import"
2. Enter dashboard ID
3. Click "Load"
4. Select "Prometheus" as data source
5. Click "Import"

### Grafana Configuration

```bash
# View Grafana config
kubectl get configmap grafana -n monitoring -o yaml

# View Grafana logs
kubectl logs -n monitoring deployment/grafana --tail=100

# Restart Grafana
kubectl rollout restart deployment/grafana -n monitoring
```

---

## 🔐 HashiCorp Vault

### Access Vault UI

```bash
# Port forward to Vault
kubectl port-forward svc/vault -n vault 8200:8200 &

# Export Vault address
export VAULT_ADDR="http://localhost:8200"
```

**Access:**
- **URL**: http://localhost:8200
- **Token**: Root token from initialization

### Vault CLI Operations

#### 1. Check Vault Status

```bash
vault status
```

**Expected Output:**
```
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             false
Total Shares       1
Threshold          1
...
```

#### 2. Login to Vault

```bash
# Login with root token (stored from Phase 5)
vault login

# Or set token as environment variable
export VAULT_TOKEN="your-root-token"
```

#### 3. Manage Secrets

**List Secrets:**
```bash
# List all secrets in a path
vault kv list secret/production/web-app/

# Expected output:
# Keys
# ----
# api
# db
# external
```

**Read Secrets:**
```bash
# Read a secret
vault kv get secret/production/web-app/db

# Read in JSON format
vault kv get -format=json secret/production/web-app/db | jq '.'

# Get only the data
vault kv get -format=json secret/production/web-app/db | jq '.data.data'

# Get specific field
vault kv get -field=password secret/production/web-app/db
```

**Write Secrets:**
```bash
# Create new secret
vault kv put secret/production/web-app/new-service \
  api_key="my-api-key" \
  endpoint="https://api.example.com"

# Update existing secret (overwrites all fields)
vault kv put secret/production/web-app/db \
  host="new-db-host" \
  port="5432" \
  name="mydb" \
  username="dbuser" \
  password="newpassword"

# Patch secret (update only specific fields)
vault kv patch secret/production/web-app/db \
  password="updated-password"
```

**Delete Secrets:**
```bash
# Soft delete (can be undeleted)
vault kv delete secret/production/web-app/new-service

# Undelete
vault kv undelete -versions=1 secret/production/web-app/new-service

# Permanent delete
vault kv metadata delete secret/production/web-app/new-service
```

#### 4. Manage Policies

**List Policies:**
```bash
vault policy list
```

**Read a Policy:**
```bash
vault policy read k8s-web-app
```

**Create/Update Policy:**
```bash
vault policy write my-app-policy - <<EOF
# Allow read access to my-app secrets
path "secret/data/production/my-app/*" {
  capabilities = ["read"]
}
path "secret/metadata/production/my-app/*" {
  capabilities = ["read", "list"]
}
EOF
```

**Delete Policy:**
```bash
vault policy delete my-app-policy
```

#### 5. Kubernetes Authentication

**List Kubernetes Roles:**
```bash
vault list auth/kubernetes/role
```

**Read a Role:**
```bash
vault read auth/kubernetes/role/k8s-web-app
```

**Create/Update Role:**
```bash
vault write auth/kubernetes/role/my-app \
  bound_service_account_names=my-app-sa \
  bound_service_account_namespaces=production \
  policies=my-app-policy \
  ttl=1h \
  max_ttl=24h
```

**Delete Role:**
```bash
vault delete auth/kubernetes/role/my-app
```

#### 6. Audit Logs

**Enable Audit Logging:**
```bash
vault audit enable file file_path=/vault/logs/audit.log
```

**List Audit Devices:**
```bash
vault audit list
```

**View Audit Logs:**
```bash
kubectl exec -n vault vault-0 -- cat /vault/logs/audit.log | tail -n 50
```

#### 7. Secret Versioning

**View Secret History:**
```bash
vault kv metadata get secret/production/web-app/db
```

**Get Specific Version:**
```bash
vault kv get -version=1 secret/production/web-app/db
```

**Rollback to Previous Version:**
```bash
# Get previous version
vault kv get -version=1 secret/production/web-app/db

# Rollback (creates new version with old data)
vault kv rollback -version=1 secret/production/web-app/db
```

### Vault UI Features

#### 1. Secrets Engine

**Navigate to**: Secrets → secret/

- Browse secrets hierarchy
- Create/edit secrets via UI
- View secret versions
- Manage metadata

#### 2. Access Control

**Navigate to**: Policies

- View all policies
- Create new policies
- Edit existing policies
- Test policy capabilities

#### 3. Authentication Methods

**Navigate to**: Access → Auth Methods

- View enabled auth methods
- Configure Kubernetes auth
- Manage roles and bindings

### Vault Agent Injection in Pods

**Check if Vault agent is injected:**
```bash
# List containers in pod
kubectl get pods -n production -l app.kubernetes.io/name=k8s-web-app \
  -o jsonpath='{.items[0].spec.containers[*].name}'
# Expected: k8s-web-app vault-agent

# Check init containers
kubectl get pods -n production -l app.kubernetes.io/name=k8s-web-app \
  -o jsonpath='{.items[0].spec.initContainers[*].name}'
# Expected: vault-wait vault-agent-init
```

**View injected secrets:**
```bash
# List secret files
kubectl exec -n production deployment/k8s-web-app -- ls -la /vault/secrets/

# View a secret file
kubectl exec -n production deployment/k8s-web-app -- cat /vault/secrets/db
```

**Check Vault agent logs:**
```bash
# Init container logs
kubectl logs -n production -l app.kubernetes.io/name=k8s-web-app \
  -c vault-agent-init --tail=50

# Sidecar logs
kubectl logs -n production -l app.kubernetes.io/name=k8s-web-app \
  -c vault-agent --tail=50 --follow
```

### Vault Maintenance

**Unseal Vault (after restart):**
```bash
vault operator unseal <unseal-key>
```

**Seal Vault (for maintenance):**
```bash
vault operator seal
```

**Check Vault Pods:**
```bash
kubectl get pods -n vault
kubectl describe pod vault-0 -n vault
kubectl logs vault-0 -n vault --tail=100
```

---

## 🌐 Web Application

### Access Web Application

```bash
# Port forward to web app
kubectl port-forward svc/k8s-web-app -n production 8081:80 &
```

**Access:**
- **URL**: http://localhost:8081
- **Health Check**: http://localhost:8081/health

### Web Application Operations

**Check Application Health:**
```bash
curl http://localhost:8081/health
# Expected: {"status":"ok"}
```

**View Application Logs:**
```bash
# Recent logs
kubectl logs -n production deployment/k8s-web-app -c k8s-web-app --tail=50

# Follow logs
kubectl logs -n production deployment/k8s-web-app -c k8s-web-app --follow

# Previous pod logs (if crashed)
kubectl logs -n production deployment/k8s-web-app -c k8s-web-app --previous
```

**Check Environment Variables:**
```bash
# List all env vars
kubectl exec -n production deployment/k8s-web-app -- env

# Check specific env vars
kubectl exec -n production deployment/k8s-web-app -- env | grep -E "DB_|JWT_|NODE_ENV"
```

**Scale Application:**
```bash
# Manual scaling
kubectl scale deployment k8s-web-app -n production --replicas=3

# Check HPA status
kubectl get hpa -n production
kubectl describe hpa k8s-web-app -n production
```

**Restart Application:**
```bash
kubectl rollout restart deployment k8s-web-app -n production
kubectl rollout status deployment k8s-web-app -n production
```

---

## 🚨 Troubleshooting Access

### Port Forward Issues

**Problem**: Port forward dies or hangs

**Solution:**
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

### Cannot Access Service

**Check Service Status:**
```bash
# List services
kubectl get svc -n <namespace>

# Describe service
kubectl describe svc <service-name> -n <namespace>

# Check endpoints
kubectl get endpoints <service-name> -n <namespace>
```

**Check Pod Status:**
```bash
# List pods
kubectl get pods -n <namespace>

# Check pod details
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace> --tail=50
```

### Authentication Issues

**ArgoCD:**
```bash
# Reset admin password
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": ""}}'

# Restart ArgoCD server
kubectl rollout restart deployment/argo-cd-argocd-server -n argocd
```

**Grafana:**
```bash
# Get password
kubectl get secret grafana-admin -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d

# Reset admin password
kubectl delete secret grafana-admin -n monitoring
kubectl rollout restart deployment/grafana -n monitoring
```

**Vault:**
```bash
# Check if sealed
vault status

# Unseal if needed
vault operator unseal <unseal-key>

# Check token
echo $VAULT_TOKEN
```

### Network Issues

**Test Service Connectivity:**
```bash
# From within cluster
kubectl run test-pod --image=busybox --rm -it --restart=Never -- \
  wget -O- http://prometheus-kube-prometheus-stack-prometheus.monitoring:9090/-/healthy

# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it --restart=Never -- \
  nslookup prometheus-kube-prometheus-stack-prometheus.monitoring
```

### Resource Issues

**Check Resource Usage:**
```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -A

# Check resource limits
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Limits:"
```

---

## 📚 Additional Resources

### Official Documentation
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Vault Documentation](https://www.vaultproject.io/docs)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

### Query Languages
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [PromQL Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [Grafana Query Editor](https://grafana.com/docs/grafana/latest/panels/query-a-data-source/)

### Community Resources
- [Grafana Community Dashboards](https://grafana.com/grafana/dashboards/)
- [Prometheus Exporters](https://prometheus.io/docs/instrumenting/exporters/)
- [Vault Tutorials](https://learn.hashicorp.com/vault)

---

## 💾 Save Your Credentials

Create a secure file to save your credentials:

```bash
cat > ~/.cluster-credentials <<EOF
# EKS Cluster Credentials
export CLUSTER_NAME="your-cluster-name"
export AWS_REGION="us-west-2"

# ArgoCD
export ARGOCD_PASSWORD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"

# Grafana
export GRAFANA_PASSWORD="$(kubectl get secret grafana-admin -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d)"

# Vault
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="your-vault-root-token"
export VAULT_UNSEAL_KEY="your-unseal-key"

# Quick Access Commands
alias argocd-ui='kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443'
alias prometheus-ui='kubectl port-forward svc/prometheus-kube-prometheus-stack-prometheus -n monitoring 9090:9090'
alias grafana-ui='kubectl port-forward svc/grafana -n monitoring 3000:80'
alias vault-ui='kubectl port-forward svc/vault -n vault 8200:8200'
alias webapp-ui='kubectl port-forward svc/k8s-web-app -n production 8081:80'
EOF

# Make it readable only by you
chmod 600 ~/.cluster-credentials

# Load credentials
source ~/.cluster-credentials
```

---

**Note**: This guide assumes you've completed the deployment using either the [AWS Deployment Guide](AWS_DEPLOYMENT_GUIDE.md) or [Minikube Deployment Guide](MINIKUBE_DEPLOYMENT_GUIDE.md).
