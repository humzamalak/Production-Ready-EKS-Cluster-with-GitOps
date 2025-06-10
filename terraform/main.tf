provider "aws" {
  region = var.backend_region
}

module "vpc" {
  source = "./modules/vpc"
  environment = var.environment
}

module "eks" {
  source = "./modules/eks"
  environment = var.environment
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
}
