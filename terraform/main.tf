# Root Terraform configuration for EKS GitOps Infrastructure
# This file orchestrates the creation of the core AWS infrastructure using modules.
# It provisions the VPC and EKS cluster by calling their respective modules.

provider "aws" {
  region = var.aws_region # AWS region to deploy resources in (set via variables.tf)
}

# VPC Module: Creates the Virtual Private Cloud and networking resources
module "vpc" {
  source = "./modules/vpc" # Path to the VPC module
  project_prefix         = var.project_prefix # Prefix for naming AWS resources
  environment            = var.environment    # Environment name (e.g., dev, prod)
  aws_region             = var.aws_region     # AWS region
  vpc_cidr               = var.vpc_cidr       # VPC CIDR block
  azs                    = var.azs            # Availability zones
  flow_log_iam_role_arn  = var.flow_log_iam_role_arn # IAM role ARN for VPC flow logs
  tags                   = var.tags           # Optional tags
}

# EKS Module: Provisions the EKS cluster and node groups
module "eks" {
  source = "./modules/eks" # Path to the EKS module
  project_prefix      = var.project_prefix
  environment         = var.environment
  aws_region          = var.aws_region
  private_subnet_ids  = module.vpc.private_subnet_ids # Private subnets for worker nodes
  public_subnet_ids   = module.vpc.public_subnet_ids  # Public subnets for load balancers
  eks_cluster_sg_id   = module.vpc.eks_cluster_sg_id  # Security group for EKS control plane
  # Optional: pass through other variables as needed (e.g., kubernetes_version, node_instance_type, tags)
  tags                = var.tags
}

# Note: Outputs for these modules are defined in their respective directories and exposed via outputs.tf in the root.
