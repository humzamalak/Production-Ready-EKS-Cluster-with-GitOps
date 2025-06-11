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