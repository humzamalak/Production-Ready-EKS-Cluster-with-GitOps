# VPC Module Variables

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

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones to use."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "tags" {
  description = "Map of tags to apply to resources."
  type        = map(string)
  default     = {}
}

variable "flow_log_iam_role_arn" {
  description = "IAM role ARN for VPC flow logs."
  type        = string
  default     = "arn:aws:iam::123456789012:role/flow-logs-role" # Placeholder, update as needed
}
