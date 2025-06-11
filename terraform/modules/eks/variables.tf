# EKS Module Variables

variable "project_prefix" {
  description = "Project prefix for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "aws_region" {
  description = "AWS region for resource deployment."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS worker nodes."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs (for load balancers, etc)."
  type        = list(string)
}

variable "eks_cluster_sg_id" {
  description = "Security group ID for EKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster."
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS node group."
  type        = string
  default     = "t3.medium"
}

variable "tags" {
  description = "Map of tags to apply to resources."
  type        = map(string)
  default     = {}
}
