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

output "fluentbit_role_arn" {
  description = "IAM role ARN for FluentBit service account. Use this for IRSA configuration."
  value       = module.iam.fluentbit_role_arn
}

output "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets Operator service account. Use this for IRSA configuration."
  value       = module.iam.external_secrets_role_arn
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI Driver service account. Use this for IRSA configuration."
  value       = module.iam.ebs_csi_driver_role_arn
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller service account. Use this for IRSA configuration."
  value       = module.iam.load_balancer_controller_role_arn
}

output "vpc_flow_logs_role_arn" {
  description = "IAM role ARN for VPC Flow Logs. Used by VPC module for flow log configuration."
  value       = module.iam.vpc_flow_logs_role_arn
}

output "ebs_backup_role_arn" {
  description = "IAM role ARN for EBS backup operations. Use this for backup configuration."
  value       = module.iam.ebs_backup_role_arn
}

output "security_groups" {
  description = "Map of security group IDs for different components"
  value = {
    eks_cluster   = module.vpc.eks_cluster_sg_id
    eks_node_group = module.vpc.eks_node_group_sg_id
    alb           = module.vpc.alb_sg_id
    app           = module.vpc.app_sg_id
    database      = module.vpc.database_sg_id
    redis         = module.vpc.redis_sg_id
  }
}
