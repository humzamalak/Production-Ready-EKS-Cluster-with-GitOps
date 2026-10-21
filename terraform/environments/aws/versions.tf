# Terraform version and provider requirements
# This file ensures you are using compatible versions of Terraform and the AWS provider.

terraform {
  required_version = ">= 1.4.0" # Minimum Terraform version required
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0" # Minimum AWS provider version required
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region # Use variable for region
}

# Kubernetes and Helm providers target the EKS cluster created by module.eks
# (used by the resource quota and cluster-autoscaler release in that module).
# Without this they fall back to the local kubeconfig context.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}
