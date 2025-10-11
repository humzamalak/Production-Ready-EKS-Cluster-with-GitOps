# Root Terraform configuration for EKS GitOps Infrastructure
# This file orchestrates the creation of the core AWS infrastructure using modules.
# It provisions the VPC and EKS cluster by calling their respective modules.

## AWS provider is defined in versions.tf; removing duplicate declaration to avoid confusion.

# Kubernetes and Helm providers will be configured after EKS cluster is created
# These providers are used by ArgoCD and application deployment scripts

# VPC Module: Creates the Virtual Private Cloud and networking resources
module "vpc" {
  source                = "./modules/vpc"                   # Path to the VPC module
  project_prefix        = var.project_prefix                # Prefix for naming AWS resources
  environment           = var.environment                   # Environment name (e.g., dev, prod)
  aws_region            = var.aws_region                    # AWS region
  vpc_cidr              = var.vpc_cidr                      # VPC CIDR block
  azs                   = var.azs                           # Availability zones
  flow_log_iam_role_arn = module.iam.vpc_flow_logs_role_arn # IAM role ARN for VPC flow logs
  tags                  = var.tags                          # Optional tags
}

# EKS Module: Provisions the EKS cluster and node groups
module "eks" {
  source               = "./modules/eks" # Path to the EKS module
  project_prefix       = var.project_prefix
  environment          = var.environment
  aws_region           = var.aws_region
  private_subnet_ids   = module.vpc.private_subnet_ids   # Private subnets for worker nodes
  public_subnet_ids    = module.vpc.public_subnet_ids    # Public subnets for load balancers
  eks_cluster_sg_id    = module.vpc.eks_cluster_sg_id    # Security group for EKS control plane
  eks_node_group_sg_id = module.vpc.eks_node_group_sg_id # Security group for EKS worker nodes
  kubernetes_version   = var.kubernetes_version          # Kubernetes version
  tags                 = var.tags
}

# IAM Module: Creates service roles and policies for EKS workloads
module "iam" {
  source                = "./modules/iam" # Path to the IAM module
  project_prefix        = var.project_prefix
  environment           = var.environment
  eks_cluster_name      = module.eks.cluster_name
  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  tags                  = var.tags
}

# Note: Outputs for these modules are defined in their respective directories and exposed via outputs.tf in the root.
