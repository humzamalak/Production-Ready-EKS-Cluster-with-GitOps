# IAM Terraform Module

This module provisions IAM resources required for secure operation of EKS and GitOps workflows, including IRSA (IAM Roles for Service Accounts) and GitHub Actions OIDC integration.

## Purpose
- Enable secure, least-privilege access for EKS workloads
- Support GitHub Actions OIDC authentication for CI/CD
- Provide IRSA for Kubernetes service accounts

## Features
- OIDC provider for GitHub Actions
- IAM roles and policies for GitHub Actions and EKS workloads
- Example IRSA configuration
- Policy attachment for least-privilege access

## Recent Security Improvements (v1.3.0)

### GitHub Actions OIDC Role
- ❌ **Removed**: `AdministratorAccess` managed policy
- ✅ **Added**: Least-privilege custom policy with scoped permissions:
  - EKS describe/list operations
  - ECR push/pull for container images
  - S3 access for Terraform state (scoped to `terraform-state-*` buckets)
  - DynamoDB access for state locking

### Service Role Policies
All service role policies have been updated to follow least-privilege principles:

1. **Vault External Secrets**
   - Scoped to AWS Secrets Manager with resource prefix restrictions
   - Changed from wildcard `*` to specific secret ARNs

2. **FluentBit CloudWatch Logs**
   - Scoped to specific EKS cluster log groups
   - Changed from `log-group:*` to cluster-specific log groups

3. **VPC Flow Logs**
   - Scoped to specific VPC flow log groups
   - Changed from wildcard to VPC-specific log groups

### Migration Notes
If upgrading from v1.2.0 or earlier, review the IAM policy changes in:
- `github_actions_oidc.tf` - GitHub Actions role
- `service_roles.tf` - All service roles

Test in a non-production environment first to ensure the scoped policies work for your use case.

## Usage
```hcl
module "iam" {
  source = "./modules/iam"
  region = var.aws_region
  eks_oidc_id = module.eks.oidc_id
}
```

## Inputs
| Name         | Description                                 | Type   | Default |
|--------------|---------------------------------------------|--------|---------|
| region       | AWS region                                  | string | n/a     |
| eks_oidc_id  | OIDC ID for EKS cluster                     | string | n/a     |

## Outputs
- None (IAM resources are referenced by other modules)

## Requirements
- AWS CLI configured
- Terraform >= 1.4.0
- AWS provider >= 5.0

## IAM Policy
See root README for minimal IAM policy required.
