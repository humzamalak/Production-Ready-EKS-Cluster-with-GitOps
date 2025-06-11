# Root-level outputs for EKS GitOps Infrastructure
# These outputs expose key resource IDs and endpoints for use in other modules or for reference after deployment.

output "vpc_id" {
  description = "VPC ID from the VPC module. Useful for referencing the created VPC."
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name from the EKS module. Use this to identify your cluster."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint. This is the API server endpoint for Kubernetes."
  value       = module.eks.cluster_endpoint
}

output "eks_node_group_role_arn" {
  description = "IAM role ARN for EKS node group. Attach policies to this role for node permissions."
  value       = module.eks.node_group_role_arn
}
