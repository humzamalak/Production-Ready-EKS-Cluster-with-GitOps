# ArgoCD CLI Setup Guide (Windows Git Bash)

This guide explains how to use the automated ArgoCD CLI setup script for Windows Git Bash environments.

## Overview

The `argocd-login.sh` script automates the complete setup process for accessing ArgoCD via CLI, including:

- Killing any process using port 8080
- Starting port-forward to the ArgoCD server
- Retrieving the admin password
- Logging in via ArgoCD CLI
- Syncing Prometheus and Vault applications
- Verifying the connection

## Prerequisites

Before running the script, ensure you have:

1. **Git Bash for Windows** installed
2. **kubectl** installed and configured
   ```bash
   kubectl version --client
   ```

3. **ArgoCD CLI** installed
   ```bash
   argocd version --client
   ```
   
   If not installed, download from: https://argo-cd.readthedocs.io/en/stable/cli_installation/

4. **Kubernetes cluster** with ArgoCD deployed
   - Use `setup-minikube.sh` for local deployment
   - Use `setup-aws.sh` for AWS EKS deployment

5. **kubectl context** configured for your cluster
   ```bash
   kubectl config current-context
   kubectl get pods -n argocd
   ```

## Installation

### Installing ArgoCD CLI on Windows

Download the latest Windows binary:

```bash
# Using PowerShell
$version = (Invoke-RestMethod https://api.github.com/repos/argoproj/argo-cd/releases/latest).tag_name
$url = "https://github.com/argoproj/argo-cd/releases/download/" + $version + "/argocd-windows-amd64.exe"
Invoke-WebRequest -Uri $url -OutFile "$env:USERPROFILE\bin\argocd.exe"

# Add to PATH if needed
```

Or using Git Bash:

```bash
# Download and install to /usr/local/bin
VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
curl -sSL -o /usr/local/bin/argocd.exe "https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-windows-amd64.exe"
chmod +x /usr/local/bin/argocd.exe
```

Verify installation:

```bash
argocd version --client
```

## Usage

### Basic Usage

Simply run the script from the repository root:

```bash
./scripts/argocd-login.sh
```

The script will:

1. ✅ Check prerequisites (kubectl, argocd CLI, cluster connection)
2. ✅ Kill any process using port 8080
3. ✅ Start port-forward to ArgoCD server (port 8080 → 443)
4. ✅ Retrieve ArgoCD admin password from Kubernetes secret
5. ✅ Login to ArgoCD CLI with automatic retry (3 attempts)
6. ✅ Sync Prometheus and Vault applications
7. ✅ Verify connection and list all applications
8. ✅ Display access information and helpful commands

### Output Example

```
[STEP] Checking prerequisites...
[SUCCESS] All prerequisites met!

[STEP] Checking for processes using port 8080...
[INFO] Port 8080 is available

[STEP] Checking if ArgoCD server is ready...
[SUCCESS] ArgoCD server is ready!

[STEP] Starting port-forward to ArgoCD server...
[INFO] Waiting for port-forward to establish...
[SUCCESS] Port-forward established on port 8080 (PID: 12345)

[STEP] Retrieving ArgoCD admin password...
[SUCCESS] ArgoCD admin password retrieved (hidden for security)

[STEP] Logging in to ArgoCD CLI...
[INFO] Login attempt 1/3...
[SUCCESS] Successfully logged in to ArgoCD!

[STEP] Syncing applications...
[STEP] Syncing ArgoCD application: prometheus...
[INFO] Application 'prometheus' found, starting sync...
[SUCCESS] Successfully synced 'prometheus'

[STEP] Syncing ArgoCD application: vault...
[INFO] Application 'vault' found, starting sync...
[SUCCESS] Successfully synced 'vault'

[SUCCESS] All applications synced successfully!

[STEP] Verifying ArgoCD connection...
[INFO] Current user:
Logged In: true
Username: admin

[SUCCESS] Connection verified!

[INFO] ArgoCD Applications:
NAME          CLUSTER                         NAMESPACE   PROJECT     STATUS  HEALTH   SYNCPOLICY  CONDITIONS
prometheus    https://kubernetes.default.svc  monitoring  prod-apps   Synced  Healthy  Auto        <none>
vault         https://kubernetes.default.svc  vault       prod-apps   Synced  Healthy  Auto        <none>
web-app       https://kubernetes.default.svc  production  prod-apps   Synced  Healthy  Auto        <none>

===================================================================
[INFO] ArgoCD CLI Setup Complete!
===================================================================

[INFO] Access Information:

  ArgoCD UI:
    URL: https://localhost:8080
    Username: admin
    Password: xxxxxxxxxxx

  CLI Commands:
    List apps:        argocd app list
    Get app status:   argocd app get <app-name>
    Sync app:         argocd app sync <app-name>
    Delete app:       argocd app delete <app-name>
    View logs:        argocd app logs <app-name>

[INFO] Port-forward is running in background (PID: 12345)
[WARN] To stop port-forward: pkill -f 'kubectl port-forward.*argocd-server'

===================================================================
[SUCCESS] Setup complete!
```

## Common Use Cases

### 1. Initial Setup After Deploying ArgoCD

After deploying ArgoCD with `setup-minikube.sh` or `setup-aws.sh`:

```bash
./scripts/argocd-login.sh
```

This sets up CLI access and syncs monitoring applications.

### 2. Re-establishing Connection

If your port-forward session ended or you restarted your terminal:

```bash
./scripts/argocd-login.sh
```

The script is idempotent - it safely kills old port-forwards and establishes new ones.

### 3. Syncing Applications

The script automatically syncs Prometheus and Vault. To manually sync other apps:

```bash
# After running argocd-login.sh
argocd app sync web-app
argocd app sync grafana
```

### 4. Accessing ArgoCD UI

After running the script, access the UI at:

```
URL: https://localhost:8080
Username: admin
Password: (displayed in script output)
```

## Useful ArgoCD CLI Commands

After logging in, you can use these commands:

### Application Management

```bash
# List all applications
argocd app list

# Get detailed app status
argocd app get prometheus

# Sync an application
argocd app sync prometheus --force --prune

# Watch sync status
argocd app sync prometheus --watch

# Delete an application
argocd app delete web-app

# Get application logs
argocd app logs prometheus -f
```

### Application Status

```bash
# Get sync status
argocd app get prometheus --show-operation

# Get health status
argocd app get prometheus --refresh

# View diff before sync
argocd app diff prometheus
```

### Project Management

```bash
# List projects
argocd proj list

# Get project details
argocd proj get prod-apps

# Create new project
argocd proj create my-project
```

### Repository Management

```bash
# List repositories
argocd repo list

# Add new repository
argocd repo add https://github.com/your-org/your-repo
```

### Account Management

```bash
# Get current user info
argocd account get-user-info

# Update password
argocd account update-password
```

## Troubleshooting

### Port 8080 Already in Use

**Problem**: Another process is using port 8080

**Solution**: The script automatically kills processes on port 8080. If issues persist:

```bash
# Manually find and kill the process
netstat -ano | grep :8080
taskkill //PID <PID> //F

# Or use a different port (edit script LOCAL_PORT variable)
```

### ArgoCD Server Pod Not Found

**Problem**: `ArgoCD server pod not found in namespace 'argocd'`

**Solution**: Verify ArgoCD is deployed:

```bash
kubectl get pods -n argocd
kubectl get deployment argocd-server -n argocd

# If not deployed, run setup script first
./scripts/setup-minikube.sh  # or setup-aws.sh
```

### Login Failed After 3 Attempts

**Problem**: `Failed to login to ArgoCD after 3 attempts`

**Solution**:

1. Verify port-forward is working:
   ```bash
   curl -k https://localhost:8080
   ```

2. Check ArgoCD server logs:
   ```bash
   kubectl logs -n argocd deployment/argocd-server
   ```

3. Verify the password secret exists:
   ```bash
   kubectl get secret argocd-initial-admin-secret -n argocd
   ```

### Application Not Found

**Problem**: `Application 'prometheus' not found in ArgoCD`

**Solution**: Deploy the ArgoCD applications:

```bash
# Apply ArgoCD bootstrap
kubectl apply -f argocd/install/03-bootstrap.yaml

# Verify apps exist
kubectl get applications -n argocd
```

### kubectl Not Connected

**Problem**: `kubectl not connected to a cluster`

**Solution**:

For Minikube:
```bash
minikube status
minikube start
kubectl config use-context minikube
```

For AWS EKS:
```bash
aws eks update-kubeconfig --name production-cluster --region us-east-1
kubectl cluster-info
```

### ArgoCD CLI Not Found

**Problem**: `argocd CLI not found`

**Solution**: Install ArgoCD CLI (see Installation section above)

## Script Customization

### Changing Default Port

Edit `scripts/argocd-login.sh` and modify:

```bash
LOCAL_PORT="8080"  # Change to desired port, e.g., "9090"
```

### Adding More Applications to Sync

Edit the `sync_apps()` function:

```bash
sync_apps() {
    log_step "Syncing applications..."
    
    local apps=("prometheus" "vault" "grafana" "web-app")  # Add more apps
    # ... rest of function
}
```

### Adjusting Retry Settings

Modify retry configuration:

```bash
LOGIN_RETRIES=3      # Number of login attempts
RETRY_DELAY=5        # Seconds between retries
```

## Background Port-Forward Management

The script runs port-forward in the background. To manage it:

### Check if Port-Forward is Running

```bash
ps aux | grep "kubectl port-forward.*argocd-server"
netstat -ano | grep :8080
```

### Stop Port-Forward

```bash
# Kill all ArgoCD port-forwards
pkill -f "kubectl port-forward.*argocd-server"

# Or kill specific PID (shown in script output)
kill -9 <PID>
```

### Restart Port-Forward Only

```bash
# Kill existing
pkill -f "kubectl port-forward.*argocd-server"

# Start new port-forward
kubectl port-forward -n argocd svc/argocd-server 8080:443 &
```

## Security Considerations

1. **Password Security**: The script displays the admin password. Consider:
   - Changing the default password after first login
   - Using SSO/OIDC for production environments
   - Deleting the initial admin secret after setting up SSO

2. **Insecure Connection**: The script uses `--insecure` flag for local development. For production:
   - Configure proper TLS certificates
   - Use secure ingress
   - Remove `--insecure` flag

3. **Background Processes**: Port-forward runs in background. Remember to stop it when done:
   ```bash
   pkill -f "kubectl port-forward.*argocd-server"
   ```

## Integration with CI/CD

### GitHub Actions Example

```yaml
- name: Setup ArgoCD CLI
  run: |
    ./scripts/argocd-login.sh
    
- name: Sync Applications
  run: |
    argocd app sync prometheus --force
    argocd app wait prometheus --health
```

### Jenkins Pipeline Example

```groovy
stage('ArgoCD Sync') {
    steps {
        sh './scripts/argocd-login.sh'
        sh 'argocd app sync prometheus --force'
    }
}
```

## Related Documentation

- [Local Deployment Guide](local-deployment.md) - Deploy ArgoCD on Minikube
- [AWS Deployment Guide](aws-deployment.md) - Deploy ArgoCD on EKS
- [Troubleshooting Guide](troubleshooting.md) - Common issues and solutions
- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/) - Comprehensive ArgoCD documentation

## Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section above
2. Review [ArgoCD logs](#troubleshooting)
3. Consult the main [Troubleshooting Guide](troubleshooting.md)
4. Open a GitHub issue with detailed error messages

---

**Ready to start?** Run `./scripts/argocd-login.sh` to begin!

