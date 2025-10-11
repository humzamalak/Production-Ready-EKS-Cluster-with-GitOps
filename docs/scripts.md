# Scripts Documentation

> **Management Scripts for GitOps Repository**

Comprehensive documentation for all deployment and management scripts in this repository.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Core Scripts](#core-scripts)
3. [Script Integration](#script-integration)
4. [Cross-Platform Compatibility](#cross-platform-compatibility)
5. [Best Practices](#best-practices)
6. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This repository includes **8 core scripts** for deployment, validation, and management:

| Script | Purpose | Platform | Complexity |
|--------|---------|----------|------------|
| `deploy.sh` | Unified deployment interface | All | Medium |
| `setup-minikube.sh` | Automated Minikube setup | All | Low |
| `setup-aws.sh` | Automated AWS EKS setup | All | Medium |
| `argocd-login.sh` | ArgoCD CLI authentication | All | Medium |
| `validate.sh` | Comprehensive validation | All | Medium |
| `vault-init.sh` | Vault initialization | All | Low |
| `secrets.sh` | Secrets management | All | Low |
| `cleanup.sh` | Safe file cleanup | All | Low |

---

## 🔧 Core Scripts

### 1. deploy.sh - Unified Deployment Interface

**Purpose**: Orchestrate infrastructure, ArgoCD, and application deployments

**Location**: `scripts/deploy.sh`

**Usage:**
```bash
./scripts/deploy.sh <command> <environment> [options]
```

**Commands:**
- `terraform` - Deploy infrastructure using Terraform
- `bootstrap` - Bootstrap ArgoCD and initial applications
- `secrets` - Create monitoring and application secrets
- `validate` - Validate deployments and configurations
- `sync` - Sync ArgoCD applications
- `status` - Show deployment status

**Environments:**
- `dev` - Development environment
- `staging` - Staging environment
- `prod` - Production environment

**Options:**
- `--timeout N` - Set operation timeout (default: 300s)
- `--dry-run` - Preview without executing
- `--help` - Show help message

**Examples:**
```bash
# Deploy production infrastructure
./scripts/deploy.sh terraform prod

# Bootstrap ArgoCD in production
./scripts/deploy.sh bootstrap prod

# Create monitoring secrets
./scripts/deploy.sh secrets monitoring

# Sync all applications
./scripts/deploy.sh sync prod

# Show deployment status
./scripts/deploy.sh status prod
```

**Functions:**
- `check_prerequisites()` - Validates required tools
- `deploy_terraform()` - Deploys infrastructure
- `bootstrap_argocd()` - Bootstraps ArgoCD
- `create_monitoring_secrets()` - Creates secrets
- `sync_argocd()` - Syncs applications
- `show_status()` - Displays status

**Integration:**
```bash
# Via Makefile
make deploy-infra ENV=prod
make deploy-bootstrap ENV=prod
make deploy-sync ENV=prod
```

---

### 2. setup-minikube.sh - Minikube Setup

**Purpose**: Automated deployment of complete GitOps stack on Minikube

**Location**: `scripts/setup-minikube.sh`

**Usage:**
```bash
./scripts/setup-minikube.sh
```

**What It Does:**
1. ✅ Checks prerequisites (minikube, kubectl, helm)
2. ✅ Starts Minikube (if not running)
3. ✅ Enables addons (ingress, metrics-server)
4. ✅ Deploys ArgoCD
5. ✅ Bootstraps applications
6. ✅ Displays access information

**Configuration:**
- CPU: 4 cores
- Memory: 8GB
- Disk: 20GB
- Driver: docker (auto-detected)
- Kubernetes: v1.33.0

**Functions:**
- `check_prerequisites()` - Tool validation
- `start_minikube()` - Minikube startup
- `deploy_argocd()` - ArgoCD deployment
- `deploy_applications()` - Bootstrap applications
- `display_access_info()` - Show access details

**Integration:**
```bash
# Via Makefile
make deploy-minikube
```

**Output Example:**
```
[INFO] Starting Minikube GitOps Stack Setup...
[INFO] Checking prerequisites...
[INFO] All prerequisites met!
[INFO] Minikube is already running
[INFO] Deploying ArgoCD...
[SUCCESS] ArgoCD deployed successfully!
[INFO] Applications deployed!

===================================================================
Minikube GitOps Stack Deployment Complete!
===================================================================

Next Steps:
  1. Login to ArgoCD CLI:
     ./scripts/argocd-login.sh
```

---

### 3. setup-aws.sh - AWS EKS Setup

**Purpose**: Automated deployment of complete GitOps stack on AWS EKS

**Location**: `scripts/setup-aws.sh`

**Usage:**
```bash
./scripts/setup-aws.sh [--skip-terraform]
```

**Options:**
- `--skip-terraform` - Skip Terraform provisioning (use existing cluster)

**What It Does:**
1. ✅ Checks prerequisites (aws, terraform, kubectl, helm)
2. ✅ Provisions AWS infrastructure (optional)
3. ✅ Configures kubectl for EKS
4. ✅ Deploys ArgoCD
5. ✅ Bootstraps applications
6. ✅ Displays access information

**Configuration:**
- Cluster Name: From environment variable or default
- AWS Region: From environment variable or us-east-1
- ArgoCD Version: 2.13.0

**Functions:**
- `check_prerequisites()` - Tool and AWS credential validation
- `provision_infrastructure()` - Terraform deployment
- `configure_kubectl()` - EKS kubeconfig setup
- `deploy_argocd()` - ArgoCD deployment
- `deploy_applications()` - Bootstrap applications
- `configure_ingress()` - ALB ingress guidance
- `display_access_info()` - Show access details

**Integration:**
```bash
# Via Makefile
make deploy-aws

# With existing cluster
./scripts/setup-aws.sh --skip-terraform
```

---

### 4. argocd-login.sh - ArgoCD CLI Authentication

**Purpose**: Automated ArgoCD CLI setup with cross-platform support

**Location**: `scripts/argocd-login.sh`

**Usage:**
```bash
./scripts/argocd-login.sh [options]
```

**Options:**
- `--verbose` - Enable detailed logging
- `--help` - Show help message

**Features:**
- ✅ Cross-platform CLI detection (Linux, macOS, Windows)
- ✅ Automatic port-forwarding
- ✅ Password retrieval from Kubernetes
- ✅ Login with retry logic
- ✅ Application listing

**Platform Support:**

**Linux/macOS:**
```bash
# Detects argocd binary in PATH
# Direct execution
```

**Windows Git Bash:**
```bash
# Auto-detects argocd.exe using where.exe
# Converts Windows paths to Git Bash format
# Creates wrapper function for transparent usage
# Tests direct execution vs cmd.exe wrapper
```

**Functions:**
- `is_git_bash_windows()` - Environment detection
- `convert_windows_path()` - Path format conversion
- `find_argocd_cli()` - Multi-strategy CLI detection
- `test_argocd_cli()` - Execution method testing
- `setup_argocd_cli()` - Wrapper function creation
- `kill_port_forward()` - Cleanup port conflicts
- `verify_argocd_ready()` - Readiness check
- `setup_port_forward()` - Port-forward management
- `login_argocd()` - Authentication with retry

**Integration:**
```bash
# Via Makefile
make argo-login
make port-forward-argocd
```

**Troubleshooting:**
See [ArgoCD CLI Setup Guide](argocd-cli-setup.md) for detailed troubleshooting.

---

### 5. validate.sh - Comprehensive Validation

**Purpose**: Validate repository structure, applications, Helm charts, and security configurations

**Location**: `scripts/validate.sh`

**Usage:**
```bash
./scripts/validate.sh [scope] [options]
```

**Scopes:**
- `all` - Validate everything (default)
- `structure` - Repository structure and GitOps layout
- `apps` - ArgoCD applications
- `helm` - Helm charts
- `vault` - Vault integration
- `manifests` - Kubernetes manifests
- `security` - Security configurations

**Options:**
- `--verbose` - Enable verbose output
- `--fix` - Attempt to fix common issues
- `--environment ENV` - Specify environment (dev/staging/prod)
- `--help` - Show help message

**Examples:**
```bash
# Validate everything
./scripts/validate.sh all

# Validate ArgoCD applications
./scripts/validate.sh apps

# Validate with verbose output
./scripts/validate.sh all --verbose

# Validate specific environment
./scripts/validate.sh structure --environment prod
```

**Validation Checks:**

**Structure Validation:**
- Required directories exist
- Environment-specific files present
- Application manifests valid
- Bootstrap files present

**Application Validation:**
- Annotation size limits (< 256KB)
- Required fields present
- Inline Helm values size
- YAML syntax

**Helm Validation:**
- Chart.yaml present and valid
- values.yaml present and valid
- Helm lint passes
- Template rendering succeeds

**Security Validation:**
- Pod Security Standards configured
- Network Policies present
- Security contexts defined
- Non-root containers
- Read-only root filesystem
- RBAC configurations

**Functions:**
- `validate_structure()` - Directory structure checks
- `validate_apps()` - ArgoCD application validation
- `validate_helm()` - Helm chart validation
- `validate_manifests()` - Kubernetes manifest validation
- `validate_security()` - Security configuration validation
- `validate_vault()` - Vault integration checks

**Integration:**
```bash
# Via Makefile
make validate-all
make validate-apps
make validate-helm
make validate-security
```

---

### 6. vault-init.sh - Vault Initialization

**Purpose**: Initialize HashiCorp Vault for secret management

**Location**: `scripts/vault-init.sh`

**Usage:**
```bash
./scripts/vault-init.sh
```

**What It Does:**
1. ✅ Waits for Vault pod to be ready
2. ✅ Initializes Vault
3. ✅ Saves recovery keys
4. ✅ Waits for auto-unseal (AWS KMS)
5. ✅ Enables audit logging
6. ✅ Configures Kubernetes auth
7. ✅ Enables KV v2 secrets engine

**Prerequisites:**
- Vault deployed and running
- AWS KMS configured (for AWS deployments)
- kubectl configured

**Output:**
- `vault-keys.json` - Recovery keys and root token
- **⚠️ IMPORTANT**: Backup securely and delete this file

**Example:**
```bash
# Run initialization
./scripts/vault-init.sh

# Backup keys
cp vault-keys.json /secure/location/vault-keys-backup.json

# Delete local copy
rm vault-keys.json
```

---

### 7. secrets.sh - Secrets Management (Simplified)

**Purpose**: Create and manage Kubernetes secrets

**Location**: `scripts/secrets.sh`

**Usage:**
```bash
./scripts/deploy.sh secrets <component>
```

**Components:**
- `monitoring` - Grafana, Prometheus secrets
- `web-app` - Application secrets

**Note**: This script has been simplified. Full secrets management is handled via Vault integration.

---

### 8. cleanup.sh - Safe File Cleanup

**Purpose**: Remove obsolete files with backup and rollback support

**Location**: `scripts/cleanup.sh`

**Usage:**
```bash
./scripts/cleanup.sh [options]
```

**Options:**
- (default) - Dry-run mode (shows what would be deleted)
- `--execute` - Actually delete files (with backup)
- `--backup-only` - Create backup without deletion
- `--force` - Skip confirmation prompts
- `--rollback PATH` - Restore from backup
- `--help` - Show help message

**Features:**
- ✅ Dry-run mode by default (safe)
- ✅ Creates timestamped backups
- ✅ Confirmation prompts
- ✅ Execution logging
- ✅ Rollback capability

**Examples:**
```bash
# Preview what would be deleted (safe)
./scripts/cleanup.sh

# Create backup and delete files
./scripts/cleanup.sh --execute

# Create backup only
./scripts/cleanup.sh --backup-only

# Rollback from backup
./scripts/cleanup.sh --rollback /path/to/backup
```

**Integration:**
```bash
# Via Makefile
make cleanup-dry-run     # Preview
make cleanup-execute     # Execute with backup
make cleanup-backup      # Backup only
```

---

## 🔗 Script Integration

### Makefile Integration

All scripts are accessible via Makefile targets:

```bash
make help                     # Show all commands
make deploy-minikube          # setup-minikube.sh
make deploy-aws               # setup-aws.sh
make argo-login               # argocd-login.sh
make validate-all             # validate.sh all
make cleanup-dry-run          # cleanup.sh
```

### GitHub Actions Integration

Scripts are called from workflows:

**validate.yaml:**
```yaml
- name: Validate Shell Scripts
  run: |
    for script in scripts/*.sh; do
      bash -n "$script"
    done
```

**deploy-argocd.yaml:**
```yaml
- name: Sync Applications
  run: |
    for app in argo-apps/apps/*.yaml; do
      argocd app sync $(yq eval '.metadata.name' "$app")
    done
```

### Chain Multiple Scripts

```bash
# Full deployment pipeline
./scripts/setup-aws.sh && \
./scripts/argocd-login.sh && \
./scripts/validate.sh all
```

---

## 🌍 Cross-Platform Compatibility

### Platform Support Matrix

| Script | Linux | macOS | Windows Git Bash | Windows PowerShell |
|--------|-------|-------|------------------|-------------------|
| deploy.sh | ✅ | ✅ | ✅ | ⚠️ (limited) |
| setup-minikube.sh | ✅ | ✅ | ✅ | ⚠️ (limited) |
| setup-aws.sh | ✅ | ✅ | ✅ | ⚠️ (limited) |
| argocd-login.sh | ✅ | ✅ | ✅ (enhanced) | ❌ |
| validate.sh | ✅ | ✅ | ✅ | ⚠️ (limited) |
| vault-init.sh | ✅ | ✅ | ✅ | ⚠️ (limited) |
| secrets.sh | ✅ | ✅ | ✅ | ⚠️ (limited) |
| cleanup.sh | ✅ | ✅ | ✅ | ⚠️ (limited) |

### Windows Considerations

**Git Bash (Recommended for Windows):**
- ✅ Full POSIX compatibility
- ✅ All bash scripts work natively
- ✅ Special handling in `argocd-login.sh` for .exe detection

**PowerShell:**
- ⚠️ Limited support
- ⚠️ Requires WSL for bash scripts
- ✅ Makefile targets work via WSL

**WSL (Windows Subsystem for Linux):**
- ✅ Full compatibility
- ✅ Recommended for Windows users
- ✅ All scripts work natively

### ArgoCD CLI Detection (Windows)

**argocd-login.sh** includes intelligent Windows support:

**Detection Strategy:**
```bash
1. Check for 'argocd' in PATH
2. Check for 'argocd.exe' in PATH
3. Search common Windows paths:
   - C:\Windows\System32\argocd.exe
   - C:\Program Files\argocd\argocd.exe
   - C:\ProgramData\chocolatey\bin\argocd.exe
4. Use where.exe to locate binary
5. Convert Windows paths to Git Bash format
```

**Path Conversion:**
```bash
# Windows: C:\Windows\System32\argocd.exe
# Git Bash: /c/Windows/System32/argocd.exe
```

**Execution Methods:**
```bash
# Method 1: Direct execution (if in PATH)
argocd version

# Method 2: cmd.exe wrapper (if in System32)
cmd.exe /c "C:\Windows\System32\argocd.exe" version
```

For detailed Windows setup, see [ArgoCD CLI Setup Guide](argocd-cli-setup.md).

---

## 🛠️ Best Practices

### Error Handling

All scripts use:
```bash
#!/bin/bash
set -euo pipefail

# -e: Exit on error
# -u: Error on undefined variable
# -o pipefail: Catch errors in pipes
```

### Logging Standards

Scripts use consistent color-coded logging:

```bash
# Functions used across scripts
print_header()   # Blue - Section headers
print_status()   # Cyan - Informational messages
print_success()  # Green - Success messages
print_warning()  # Yellow - Warnings
print_error()    # Red - Errors
print_step()     # Purple - Step indicators
```

### Idempotent Operations

All scripts can be run multiple times safely:
```bash
# Safe to run repeatedly
./scripts/setup-minikube.sh
./scripts/setup-minikube.sh  # No errors, handles existing resources
```

### Dry-Run Modes

Scripts support previewing operations:
```bash
# Cleanup with dry-run (default)
./scripts/cleanup.sh

# Deploy with dry-run
./scripts/deploy.sh terraform prod --dry-run
```

---

## 🔍 Script Dependencies

### Tool Requirements

**All Scripts:**
- `kubectl` - Kubernetes CLI
- `bash` - Bourne Again Shell (v4+)

**Infrastructure Scripts:**
- `terraform` - Infrastructure as Code
- `aws` - AWS CLI (for AWS deployments)

**ArgoCD Scripts:**
- `argocd` - ArgoCD CLI (auto-installed by setup scripts)
- `helm` - Helm package manager

**Validation Scripts:**
- `yq` - YAML processor (optional but recommended)
- `jq` - JSON processor (optional)

**Checking Dependencies:**
```bash
# Via Makefile
make dev-setup

# Manual check
command -v kubectl || echo "kubectl not found"
command -v helm || echo "helm not found"
command -v terraform || echo "terraform not found"
```

---

## 🚨 Troubleshooting

### Common Issues

#### Script Permission Denied

**Symptom:**
```
bash: ./scripts/setup-minikube.sh: Permission denied
```

**Solution (Linux/macOS/Git Bash):**
```bash
chmod +x scripts/*.sh
./scripts/setup-minikube.sh
```

**Solution (Windows PowerShell):**
```bash
# Use Git Bash or WSL instead
```

#### Command Not Found

**Symptom:**
```
./scripts/deploy.sh: line 42: kubectl: command not found
```

**Solution:**
```bash
# Check prerequisites
make dev-setup

# Install missing tools
# See deployment guides for installation instructions
```

#### ArgoCD CLI Not Found (Windows)

**Symptom:**
```
[ERROR] ArgoCD CLI not found!
```

**Solution:**
```bash
# Download ArgoCD CLI for Windows
curl -sSL -o argocd.exe https://github.com/argoproj/argo-cd/releases/latest/download/argocd-windows-amd64.exe

# Move to System32 (requires admin)
mv argocd.exe /c/Windows/System32/

# Or use Chocolatey
choco install argocd-cli

# Verify
where.exe argocd.exe
```

#### Port Already in Use

**Symptom:**
```
Error: listen tcp :8080: bind: address already in use
```

**Solution:**
```bash
# Scripts automatically kill conflicting processes
# Or manual cleanup:
pkill -f "kubectl port-forward.*8080"

# On Windows
taskkill //F //IM kubectl.exe
```

#### Terraform State Locked

**Symptom:**
```
Error: Error locking state: ConditionalCheckFailedException
```

**Solution:**
```bash
# Check lock status
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (use with caution)
cd terraform/environments/aws
terraform force-unlock <lock-id>
```

---

## 📚 Script Development Guidelines

### Adding New Scripts

**1. Create with template:**
```bash
#!/bin/bash
# =============================================================================
# Script Name - Brief Description
# =============================================================================
#
# Detailed description
#
# Usage:
#   ./scripts/script-name.sh [options]
#
# Author: Production-Ready EKS Cluster with GitOps
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Functions
main() {
    echo "Script implementation"
}

# Run
main "$@"
```

**2. Add to Makefile:**
```makefile
## new-target: Description of new target
new-target:
	./scripts/new-script.sh
```

**3. Document usage:**
- Add to this file (scripts.md)
- Add to README.md if user-facing
- Add inline comments

**4. Test cross-platform:**
```bash
# Test on Linux
bash scripts/new-script.sh

# Test syntax
bash -n scripts/new-script.sh

# Test on Windows Git Bash
# Test on macOS
```

### Deprecated Scripts

The following scripts were consolidated during the repository audit:

| Deprecated Script | Replaced By | Functionality |
|------------------|-------------|---------------|
| `argo-diagnose.sh` | `argocd-login.sh` | Merged diagnostic features |
| `debug-monitoring-sync.sh` | `validate.sh apps` | Integrated into validation |
| `setup-vault-minikube.sh` | Helm values | Automated via GitOps |
| `test-argocd-windows.sh` | `argocd-login.sh --test` | Integrated testing |
| `verify-vault.sh` | `validate.sh vault` | Consolidated validation |

---

## 🔗 Related Documentation

- **[Deployment Guide](deployment.md)** - How to deploy using these scripts
- **[ArgoCD CLI Setup](argocd-cli-setup.md)** - Detailed ArgoCD CLI configuration
- **[Troubleshooting Guide](troubleshooting.md)** - Common script issues
- **[CI/CD Pipeline](ci_cd_pipeline.md)** - GitHub Actions integration

---

## 📊 Usage Examples

### Complete Minikube Deployment

```bash
# Step 1: Deploy Minikube
./scripts/setup-minikube.sh

# Step 2: Login to ArgoCD
./scripts/argocd-login.sh

# Step 3: Validate deployment
./scripts/validate.sh all

# Step 4: Check status
./scripts/deploy.sh status prod
```

### Complete AWS Deployment

```bash
# Step 1: Deploy AWS infrastructure
./scripts/setup-aws.sh

# Step 2: Login to ArgoCD
./scripts/argocd-login.sh

# Step 3: Validate deployment
./scripts/validate.sh all

# Step 4: Initialize Vault (optional)
./scripts/vault-init.sh
```

### Update Configuration

```bash
# Edit Helm values
vi helm-charts/web-app/values-aws.yaml

# Commit changes
git add helm-charts/web-app/values-aws.yaml
git commit -m "Update web app config"
git push

# Sync via script
./scripts/deploy.sh sync prod

# Or validate before sync
./scripts/validate.sh all && ./scripts/deploy.sh sync prod
```

---

**Last Updated**: 2025-10-11  
**Version**: 1.0.0  
**Maintained By**: Platform Engineering Team

