# EKS Module Outputs
# These outputs expose key resource IDs for use in other modules or for reference after deployment.

output "cluster_name" {
  value = aws_eks_cluster.this.name # Output the actual EKS cluster name
}

output "region" {
  value = var.aws_region # Output the AWS region used for the cluster
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "node_group_role_arn" {
  value = aws_iam_role.eks_node_group.arn
}

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
} 