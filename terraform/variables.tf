# Root-level variables for EKS GitOps Infrastructure
# These variables allow you to customize the deployment for different environments and naming conventions.

variable "project_prefix" {
  description = "Project prefix for resource naming. Used to identify resources created by this project."
  type        = string
  default     = "eks-gitops" # Change this to your project name if desired
}

variable "environment" {
  description = "Deployment environment name (e.g., dev, staging, prod). Helps separate resources by environment."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for resource deployment. All resources will be created in this region."
  type        = string
  default     = "us-east-1"
}
