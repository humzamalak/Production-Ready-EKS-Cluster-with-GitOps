# EKS Module Variables
# These variables allow you to customise the EKS module for different environments, cluster sizes, and networking needs.

variable "project_prefix" {
  description = "Project prefix for resource naming. Used to identify resources created by this project."
  type        = string
}

variable "environment" {
  description = "Deployment environment name (e.g., dev, staging, prod). Helps separate resources by environment."
  type        = string
}

variable "aws_region" {
  description = "AWS region for resource deployment. All resources will be created in this region."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS worker nodes. Ensures nodes are not publicly accessible."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs (for load balancers, etc)."
  type        = list(string)
}

variable "eks_cluster_sg_id" {
  description = "Security group ID for EKS cluster. Controls network access to the control plane."
  type        = string
}

variable "eks_node_group_sg_id" {
  description = "Security group ID for EKS node group. Controls network access to worker nodes."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster. Use the latest stable version unless you have specific requirements."
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS node group. Choose based on workload requirements."
  type        = string
  default     = "t3.medium"
}

variable "tags" {
  description = "Map of tags to apply to resources. Useful for cost allocation and organisation."
  type        = map(string)
  default     = {}
}

# Name of the EKS cluster (used by autoscaler and other integrations)
variable "cluster_name" {
  description = "Name of the EKS cluster. Should match the cluster resource name."
  type        = string
  default     = "eks-gitops-prod-cluster"
}

# AWS region (used by autoscaler and other integrations)
variable "region" {
  description = "AWS region for the EKS cluster."
  type        = string
  default     = "eu-west-1"
}
