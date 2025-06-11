# EKS GitOps Infrastructure

This repository provisions a production-ready EKS cluster with GitOps using ArgoCD, following best practices for security, scalability, and maintainability.

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
2. Configure AWS CLI with `eu-west-1` as default region
3. Run Terraform from the root directory:
   ```bash
   terraform init
   terraform plan -var-file="dev.tfvars"
   terraform apply -var-file="dev.tfvars"
   ```

## Module Structure
- `modules/vpc`: VPC, subnets, NAT, IGW, flow logs
- `modules/eks`: EKS cluster and node groups (to be implemented)

## Next Steps
- Complete EKS module
- Integrate ArgoCD bootstrap
- Add CI/CD workflows
- Expand documentation
