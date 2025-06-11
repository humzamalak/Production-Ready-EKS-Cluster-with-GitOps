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

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Defines the IP address range for the network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones to use. Distributes resources for high availability."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "flow_log_iam_role_arn" {
  description = "IAM role ARN for VPC flow logs. Allows VPC to write logs to CloudWatch. Must be supplied by the user."
  type        = string
}

variable "tags" {
  description = "Map of tags to apply to resources. Useful for cost allocation and organization."
  type        = map(string)
  default     = {}
}
