# IAM Module Outputs
# These outputs expose IAM role ARNs for use in other modules or Kubernetes service accounts.

output "fluentbit_role_arn" {
  description = "ARN of the FluentBit IAM role for CloudWatch Logs access"
  value       = aws_iam_role.fluentbit.arn
}

output "vault_external_secrets_role_arn" {
  description = "ARN of the Vault External Secrets Operator IAM role for HashiCorp Vault access"
  value       = aws_iam_role.vault_external_secrets.arn
}

output "vault_production_role_arn" {
  description = "ARN of the Vault Production IAM role for HashiCorp Vault access"
  value       = aws_iam_role.vault_production.arn
}

output "vault_monitoring_role_arn" {
  description = "ARN of the Vault Monitoring IAM role for HashiCorp Vault access"
  value       = aws_iam_role.vault_monitoring.arn
}

output "vault_staging_role_arn" {
  description = "ARN of the Vault Staging IAM role for HashiCorp Vault access"
  value       = aws_iam_role.vault_staging.arn
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI Driver IAM role for EBS volume management"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role for load balancer management"
  value       = aws_iam_role.load_balancer_controller.arn
}

output "vpc_flow_logs_role_arn" {
  description = "ARN of the VPC Flow Logs IAM role for CloudWatch Logs access"
  value       = aws_iam_role.vpc_flow_logs.arn
}

output "ebs_backup_role_arn" {
  description = "ARN of the EBS Backup IAM role for backup operations"
  value       = aws_iam_role.ebs_backup.arn
}
