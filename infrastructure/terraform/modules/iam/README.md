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
