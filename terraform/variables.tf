# Root-level variables for EKS GitOps Infrastructure

variable "project_prefix" {
  description = "Project prefix for resource naming."
  type        = string
  default     = "eks-gitops"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for resource deployment."
  type        = string
  default     = "us-east-1"
}
