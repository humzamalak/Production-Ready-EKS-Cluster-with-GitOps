# Root Terraform configuration for EKS GitOps Infrastructure
# Orchestrates VPC and EKS modules

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"
  project_prefix = var.project_prefix
  environment    = var.environment
  aws_region     = var.aws_region
}

module "eks" {
  source = "./modules/eks"
  project_prefix = var.project_prefix
  environment    = var.environment
  aws_region     = var.aws_region
  vpc_id         = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  eks_cluster_sg_id  = module.vpc.eks_cluster_sg_id
}
