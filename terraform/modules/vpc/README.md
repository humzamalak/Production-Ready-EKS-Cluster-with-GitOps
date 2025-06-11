# VPC Terraform Module

This module provisions a production-ready VPC in AWS with public and private subnets across three Availability Zones in `eu-west-1`. It includes NAT gateways, Internet Gateway, and VPC Flow Logs.

## Features
- Customizable CIDR block (default: 10.0.0.0/16)
- 3 public and 3 private subnets (1 per AZ)
- Internet Gateway for public subnets
- NAT Gateway per AZ for private subnets
- VPC Flow Logs to CloudWatch
- Standard tagging

## Usage
```hcl
module "vpc" {
  source = "./modules/vpc"
  vpc_cidr = "10.0.0.0/16"
  azs = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  environment = "dev"
  project     = "eks-gitops"
}
```

## Inputs
| Name        | Description                | Type   | Default         |
|-------------|----------------------------|--------|-----------------|
| vpc_cidr    | VPC CIDR block             | string | "10.0.0.0/16"   |
| azs         | List of AZs                | list   | ["eu-west-1a", "eu-west-1b", "eu-west-1c"] |
| environment | Environment tag            | string | n/a             |
| project     | Project tag                | string | n/a             |

## Outputs
| Name                | Description                |
|---------------------|----------------------------|
| vpc_id              | The VPC ID                 |
| public_subnet_ids   | List of public subnet IDs  |
| private_subnet_ids  | List of private subnet IDs |

## Requirements
- AWS CLI configured
- Terraform >= 1.4.0
- AWS provider >= 5.0

## IAM Policy
See root README for minimal IAM policy required.
