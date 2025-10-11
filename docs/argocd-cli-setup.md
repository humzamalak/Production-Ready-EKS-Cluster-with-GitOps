# ArgoCD CLI Setup for Windows Git Bash

## Overview

This document explains how the ArgoCD login script (`scripts/argocd-login.sh`) has been enhanced to work seamlessly in Git Bash on Windows, even when the ArgoCD CLI is installed as `argocd.exe` in `C:\Windows\System32`.

## Problem Statement

When running bash scripts in Git Bash on Windows, the following issues commonly occur with Windows executables:

1. **PATH Resolution**: Git Bash may not automatically include Windows System32 in its PATH
2. **Extension Handling**: The `.exe` extension may not be automatically resolved when calling `argocd`
3. **Command Detection**: Standard `command -v argocd` checks may fail even when `argocd.exe` is installed

## Solution Implemented

The script now includes intelligent environment detection and CLI path resolution:

### 1. Environment Detection

```bash
is_git_bash_windows() {
    # Check for MSYSTEM environment variable (set by Git Bash)
    # and verify we're on Windows by checking for common Windows paths
    if [[ -n "${MSYSTEM}" ]] || [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]]; then
        return 0
    fi
    return 1
}
```

**How it works:**
- Checks for `MSYSTEM` environment variable (unique to Git Bash/MSYS2)
- Validates against `uname -s` output for MINGW/MSYS patterns
- Returns success (0) if running in Git Bash on Windows

### 2. ArgoCD CLI Detection

```bash
find_argocd_cli() {
    # 1. Try standard PATH lookup
    # 2. Try with .exe extension explicitly
    # 3. Search common Windows installation paths
    # 4. Use Windows 'where.exe' command to locate argocd.exe
    # 5. Convert Windows paths to Git Bash compatible Unix-style paths
}
```

**Search Strategy:**
1. **PATH Check**: `command -v argocd` - works if already in PATH
2. **Extension Check**: `command -v argocd.exe` - explicitly includes .exe
3. **Path Search**: Searches common Windows locations:
   - `/c/Windows/System32/argocd.exe`
   - `/c/Program Files/argocd/argocd.exe`
   - `/c/Program Files (x86)/argocd/argocd.exe`
   - `$HOME/bin/argocd.exe`
   - `/usr/local/bin/argocd.exe`
4. **Windows Command**: Uses `where.exe argocd.exe` to find the executable
5. **Path Conversion**: Converts Windows paths like `C:\Windows\System32\argocd.exe` to Git Bash paths like `/c/Windows/System32/argocd.exe`

### 3. Wrapper Function

```bash
setup_argocd_cli() {
    # Find the ArgoCD CLI
    ARGOCD_CMD=$(find_argocd_cli)
    
    # Create a wrapper function
    argocd() {
        "$ARGOCD_CMD" "$@"
    }
    
    # Export for use in subshells
    export -f argocd 2>/dev/null || true
}
```

**Benefits:**
- Creates a shell function named `argocd` that calls the found executable
- All subsequent `argocd` commands in the script work transparently
- No need to modify existing script logic
- Works regardless of where `argocd.exe` is located

### 4. Enhanced Error Handling

The script now provides clear error messages if ArgoCD CLI is not found:

```
[ERROR] ArgoCD CLI not found!
[ERROR] 
[ERROR] Installation instructions:
[ERROR]   1. Download from: https://github.com/argoproj/argo-cd/releases
[ERROR]   2. Place argocd.exe in C:\Windows\System32 or add to PATH
[ERROR]   3. Or use: choco install argocd-cli (if using Chocolatey)
```

## Usage

### Prerequisites

1. **Install ArgoCD CLI** using one of these methods:

   **Option A: Manual Installation**
   ```bash
   # Download the latest Windows binary
   curl -sSL -o argocd.exe https://github.com/argoproj/argo-cd/releases/latest/download/argocd-windows-amd64.exe
   
   # Move to System32 (requires admin privileges)
   mv argocd.exe /c/Windows/System32/
   ```

   **Option B: Chocolatey**
   ```bash
   choco install argocd-cli
   ```

   **Option C: Custom Location**
   ```bash
   # Download to a custom location
   mkdir -p ~/bin
   curl -sSL -o ~/bin/argocd.exe https://github.com/argoproj/argo-cd/releases/latest/download/argocd-windows-amd64.exe
   
   # Add to PATH in ~/.bashrc
   echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

2. **Install kubectl** and configure it to connect to your Kubernetes cluster

3. **Deploy ArgoCD** to your cluster using:
   ```bash
   ./scripts/setup-minikube.sh  # For Minikube
   # OR
   ./scripts/setup-aws.sh       # For AWS EKS
   ```

### Running the Script

Simply execute the script from Git Bash:

```bash
./scripts/argocd-login.sh
```

### Script Workflow

The script performs the following steps:

1. **Environment Detection**: Identifies if running in Git Bash on Windows
2. **CLI Setup**: Locates and configures ArgoCD CLI
3. **Prerequisites Check**: Verifies kubectl and cluster connectivity
4. **Port Cleanup**: Kills any processes using port 8080
5. **ArgoCD Health Check**: Ensures ArgoCD server is ready
6. **Port-Forward**: Establishes connection to ArgoCD server on localhost:8080
7. **Password Retrieval**: Gets admin password from Kubernetes secret
8. **Login**: Authenticates to ArgoCD CLI (with 3 retries)
9. **App Sync**: Synchronizes Prometheus and Vault applications
10. **Verification**: Lists all ArgoCD applications
11. **Access Info**: Displays UI and CLI access information

### Expected Output

```
[INFO] Starting ArgoCD CLI Login & Sync Script...
[INFO] Environment: Git Bash on Windows (MINGW64_NT-10.0-26100)

[STEP] Checking prerequisites...
[STEP] Setting up ArgoCD CLI...
[INFO] Detected Git Bash on Windows, searching for argocd.exe...
[SUCCESS] Found argocd.exe using where.exe: /c/Windows/System32/argocd.exe
[SUCCESS] ArgoCD CLI configured: /c/Windows/System32/argocd.exe
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
[SUCCESS] Successfully synced 'prometheus'

[STEP] Syncing ArgoCD application: vault...
[SUCCESS] Successfully synced 'vault'

[SUCCESS] All applications synced successfully!

[STEP] Verifying ArgoCD connection...
[INFO] Current user:
Logged In: true
Username: admin

[INFO] ArgoCD Applications:
NAME         CLUSTER                         NAMESPACE    PROJECT     STATUS  HEALTH   SYNCPOLICY  CONDITIONS  REPO
grafana      https://kubernetes.default.svc  monitoring   prod-apps   Synced  Healthy  Auto        <none>      https://github.com/...
prometheus   https://kubernetes.default.svc  monitoring   prod-apps   Synced  Healthy  Auto        <none>      https://github.com/...
vault        https://kubernetes.default.svc  vault        prod-apps   Synced  Healthy  Auto        <none>      https://github.com/...
web-app      https://kubernetes.default.svc  default      prod-apps   Synced  Healthy  Auto        <none>      https://github.com/...

===================================================================
ArgoCD CLI Setup Complete!
===================================================================

Access Information:

  ArgoCD UI:
    URL: https://localhost:8080
    Username: admin
    Password: <your-password-here>

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

## Troubleshooting

### Issue: "ArgoCD CLI not found"

**Solution:**
1. Verify installation:
   ```bash
   where.exe argocd.exe
   ```
2. Check if file exists:
   ```bash
   ls /c/Windows/System32/argocd.exe
   ```
3. Install if missing (see Prerequisites above)

### Issue: "Login failed after 3 attempts"

**Solution:**
1. Verify port-forward is working:
   ```bash
   curl -k https://localhost:8080
   ```
2. Check ArgoCD server logs:
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
   ```
3. Manually verify password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
   ```

### Issue: "Port 8080 already in use"

**Solution:**
The script automatically kills processes using port 8080. If it persists:
```bash
# Find the process
netstat -ano | grep ":8080"

# Kill it manually
taskkill.exe //PID <PID> //F
```

### Issue: Script hangs during port-forward

**Solution:**
1. Check if ArgoCD server pod is running:
   ```bash
   kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
   ```
2. Verify pod is ready:
   ```bash
   kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server
   ```
3. Restart the script

## Compatibility

✅ **Supported Environments:**
- Git Bash on Windows 10/11
- MSYS2 on Windows
- MinGW on Windows
- PowerShell (graceful fallback)
- Linux (native bash)
- macOS (native bash)

✅ **ArgoCD CLI Locations:**
- `C:\Windows\System32\argocd.exe`
- `C:\Program Files\argocd\argocd.exe`
- Any directory in system PATH
- Custom user directories (~/bin, etc.)

## Technical Details

### Path Conversion Logic

Windows paths are converted to Git Bash compatible Unix-style paths:

```bash
# Input:  C:\Windows\System32\argocd.exe
# Step 1: Replace backslashes: C:/Windows/System32/argocd.exe
# Step 2: Convert drive letter: /c/Windows/System32/argocd.exe
```

The conversion is handled by:
```bash
echo "$windows_path" | sed 's/\\/\//g' | sed 's/^\([A-Za-z]\):/\/\L\1/'
```

### Function Export Behavior

The wrapper function is exported to make it available in subshells:
```bash
export -f argocd 2>/dev/null || true
```

- The `2>/dev/null` suppresses errors on systems that don't support function export
- The `|| true` ensures the script continues even if export fails
- Function export works in bash but may not work in all shells (hence the error suppression)

## Key Improvements

1. **No Manual PATH Modification**: Script handles path resolution internally
2. **Automatic Detection**: Intelligently finds ArgoCD CLI without user intervention
3. **Cross-Platform**: Works on Windows, Linux, and macOS
4. **Robust Error Handling**: Clear error messages with actionable instructions
5. **Idempotent**: Safe to run multiple times
6. **Transparent**: All argocd commands work as expected after setup

## Related Documentation

- [ArgoCD Official Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD CLI Installation](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
- [Local Deployment Guide](./local-deployment.md)
- [AWS Deployment Guide](./aws-deployment.md)
- [General Deployment Guide](./DEPLOYMENT_GUIDE.md)

## Contributing

If you encounter issues or have suggestions for improving the script:

1. Check existing issues in the repository
2. Create a new issue with:
   - Your environment details (Windows version, Git Bash version)
   - Complete error output
   - Steps to reproduce
3. Submit a pull request with fixes or improvements

## License

This script is part of the Production-Ready EKS Cluster with GitOps project.
See the LICENSE file in the repository root for details.
