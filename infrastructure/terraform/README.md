# EKS GitOps Infrastructure - Terraform Root

This directory contains the root Terraform configuration for provisioning a production-ready EKS (Elastic Kubernetes Service) cluster and supporting AWS infrastructure using GitOps principles.

## Purpose
- Orchestrate all infrastructure modules (VPC, EKS, IAM, Backup)
- Enable secure, scalable, and maintainable Kubernetes environments
- Integrate with CI/CD and GitOps workflows

## Getting Started

### Prerequisites
- AWS account with programmatic access
- AWS CLI configured (`aws configure`)
- Terraform >= 1.4.0
- AWS provider >= 5.0

### Minimal IAM Policy
See below for a minimal IAM policy for Terraform provisioning:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "eks:*",
        "iam:PassRole",
        "iam:GetRole",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PutRolePolicy",
        "iam:ListRoles",
        "cloudwatch:*",
        "logs:*",
        "autoscaling:*",
        "elasticloadbalancing:*",
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "*"
    }
  ]
}
```

### Usage
1. Clone the repo
2. Configure AWS CLI with your desired region (e.g., `eu-west-1`)
3. Run Terraform from the root directory:
   ```bash
   terraform init
   terraform plan -var-file="dev.tfvars"
   terraform apply -var-file="dev.tfvars"
   ```

## Module Structure
- `modules/vpc`: VPC, subnets, NAT, IGW, flow logs
- `modules/eks`: EKS cluster (v1.33) and node groups
- `modules/iam`: IAM roles for EKS, GitHub Actions, IRSA
- `modules/backup`: EBS volume snapshot automation

## Kubernetes Version
- **Default**: 1.33
- **Supported**: 1.29+
- Update via `kubernetes_version` variable in `terraform.tfvars`

## Best Practices
- Use feature branches for changes
- Run `terraform plan` before PRs
- Use PR templates and follow commit guidelines
- Store secrets securely (never in code)

## Troubleshooting
- Check Terraform logs for errors
- Ensure AWS credentials and permissions are correct
- See the main [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) for more help

## Next Steps
- Complete EKS module
- Integrate ArgoCD bootstrap
- Add CI/CD workflows
- Expand documentation
