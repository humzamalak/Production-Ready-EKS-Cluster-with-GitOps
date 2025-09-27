# VPC Module Outputs
# These outputs expose key resource IDs for use in other modules or for reference after deployment.

output "vpc_id" {
  description = "The ID of the VPC. Use this to reference the VPC in other modules."
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs. Used for EKS worker nodes and private workloads."
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs. Used for load balancers and public-facing resources."
  value       = aws_subnet.public[*].id
}

output "eks_cluster_sg_id" {
  description = "Security group ID for EKS cluster. Attach this to the EKS control plane."
  value       = aws_security_group.eks_cluster.id
}

output "eks_node_group_sg_id" {
  description = "Security group ID for EKS node group. Attach this to the EKS worker nodes."
  value       = aws_security_group.eks_node_group.id
}

output "alb_sg_id" {
  description = "Security group ID for Application Load Balancer."
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "Security group ID for applications."
  value       = aws_security_group.app.id
}

output "database_sg_id" {
  description = "Security group ID for database."
  value       = aws_security_group.database.id
}

output "redis_sg_id" {
  description = "Security group ID for Redis/ElastiCache."
  value       = aws_security_group.redis.id
}
