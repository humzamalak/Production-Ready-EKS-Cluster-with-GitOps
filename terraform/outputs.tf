# Root-level outputs for EKS GitOps Infrastructure

output "vpc_id" {
  description = "VPC ID from the VPC module."
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name from the EKS module."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = module.eks.cluster_endpoint
}

output "eks_node_group_role_arn" {
  description = "IAM role ARN for EKS node group."
  value       = module.eks.node_group_role_arn
}
