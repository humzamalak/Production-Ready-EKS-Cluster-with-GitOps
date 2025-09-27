# Deployment Scripts

This directory contains modular deployment scripts for the Production-Ready EKS Cluster with GitOps project. The scripts are designed to be run independently or orchestrated together for a complete deployment.

## Script Structure

### Main Orchestration Script

- **`deploy.sh`** - Main deployment script that orchestrates all components

### Component Scripts

- **`backend-management.sh`** - Manages Terraform backend resources (S3 bucket and DynamoDB table)
- **`infrastructure-deploy.sh`** - Deploys EKS cluster and associated infrastructure using Terraform
- **`argocd-deploy.sh`** - Installs and configures ArgoCD for GitOps workflow
- **`applications-deploy.sh`** - Deploys applications using ArgoCD's app-of-apps pattern

### Shared Library

- **`lib/common.sh`** - Shared functions and utilities used across all scripts

## Usage

### Full Deployment

```bash
# Deploy everything
./scripts/deploy.sh

# Deploy with auto-approval
./scripts/deploy.sh -y

# Verbose output
./scripts/deploy.sh -v
```

### Selective Deployment

```bash
# Skip infrastructure deployment
./scripts/deploy.sh --skip-infra

# Skip ArgoCD deployment
./scripts/deploy.sh --skip-argocd

# Skip application deployment
./scripts/deploy.sh --skip-apps
```

### Validation and Testing

```bash
# Validate all components
./scripts/deploy.sh --validate-only

# Dry run (show what would be deployed)
./scripts/deploy.sh --dry-run

# Create backend resources only
./scripts/deploy.sh --create-backend-only
```

### Individual Component Scripts

```bash
# Deploy backend resources only
./scripts/backend-management.sh

# Deploy infrastructure only
./scripts/infrastructure-deploy.sh

# Deploy ArgoCD only
./scripts/argocd-deploy.sh

# Deploy applications only
./scripts/applications-deploy.sh
```

## Script Features

### Common Options

All scripts support these common options:

- `-h, --help` - Show help message
- `-v, --verbose` - Enable verbose output
- `-y, --auto-approve` - Auto-approve operations
- `--validate-only` - Only validate prerequisites and configuration
- `--dry-run` - Show what would be deployed without actually deploying

### Error Handling

- Comprehensive error handling with meaningful error messages
- Automatic cleanup of temporary files
- Detailed logging to `deployment.log`
- Exit codes for script chaining

### Logging

- Colored output for better readability
- Timestamps for all log entries
- Log file: `deployment.log` in the project root
- Different log levels: INFO, SUCCESS, WARNING, ERROR

## Prerequisites

### Required Tools

- AWS CLI (configured with appropriate permissions)
- kubectl
- Helm
- Terraform (>= 1.4.0)
- Git

### Required Files

- `terraform/terraform.tfvars` - Terraform configuration
- `argo-cd/bootstrap/values.yaml` - ArgoCD Helm values
- `argo-cd/apps/root-app.yaml` - Root ArgoCD application

### AWS Permissions

The AWS credentials must have permissions to:

- Create and manage EKS clusters
- Create and manage VPC resources
- Create and manage IAM roles and policies
- Create and manage S3 buckets and DynamoDB tables
- Create and manage EC2 instances and security groups

## Script Dependencies

### Execution Order

The scripts are designed to be run in this order:

1. `backend-management.sh` - Creates Terraform backend resources
2. `infrastructure-deploy.sh` - Deploys EKS cluster (requires backend)
3. `argocd-deploy.sh` - Installs ArgoCD (requires cluster)
4. `applications-deploy.sh` - Deploys applications (requires ArgoCD)

### State Management

- Terraform state is stored in S3 with DynamoDB locking
- Backend configuration is cached in `backend-config.env`
- Component scripts can be run independently if prerequisites are met

## Troubleshooting

### Common Issues

1. **AWS Credentials Not Configured**
   ```bash
   aws configure
   aws sts get-caller-identity
   ```

2. **Terraform Backend Issues**
   ```bash
   # Check if backend resources exist
   aws s3api head-bucket --bucket <bucket-name>
   aws dynamodb describe-table --table-name <table-name>
   ```

3. **Cluster Access Issues**
   ```bash
   # Update kubeconfig
   aws eks update-kubeconfig --region <region> --name <cluster-name>
   ```

4. **ArgoCD Not Ready**
   ```bash
   # Check ArgoCD pods
   kubectl get pods -n argocd
   ```

### Log Files

- Main log: `deployment.log`
- Terraform logs: Check Terraform output
- Kubernetes logs: Use `kubectl logs` for specific pods

### Getting Help

```bash
# Show help for any script
./scripts/deploy.sh --help
./scripts/backend-management.sh --help
./scripts/infrastructure-deploy.sh --help
./scripts/argocd-deploy.sh --help
./scripts/applications-deploy.sh --help
```

## Development

### Adding New Scripts

1. Create the script in the `scripts/` directory
2. Source `lib/common.sh` for shared functions
3. Follow the existing pattern for argument parsing and error handling
4. Update this README with usage information

### Modifying Existing Scripts

1. Test changes with `--dry-run` first
2. Update documentation if behavior changes
3. Ensure backward compatibility when possible

## Security Considerations

- Scripts use least-privilege AWS permissions
- Sensitive data is stored in Kubernetes secrets
- Default passwords should be changed in production
- All scripts support dry-run mode for safe testing
