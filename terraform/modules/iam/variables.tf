# IAM Module Variables
# These variables allow you to customise the IAM module for different environments and cluster configurations.

variable "project_prefix" {
  description = "Project prefix for resource naming. Used to identify resources created by this project."
  type        = string
}

variable "environment" {
  description = "Deployment environment name (e.g., dev, staging, prod). Helps separate resources by environment."
  type        = string
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster. Used for service account conditions."
  type        = string
}

variable "eks_oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider. Used for IRSA trust relationships."
  type        = string
}

variable "tags" {
  description = "Map of tags to apply to resources. Useful for cost allocation and organisation."
  type        = map(string)
  default     = {}
}
