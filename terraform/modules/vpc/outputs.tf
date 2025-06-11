# VPC Module Outputs

output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs."
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs."
  value       = aws_subnet.public[*].id
}

output "eks_cluster_sg_id" {
  description = "Security group ID for EKS cluster."
  value       = aws_security_group.eks_cluster.id
}
