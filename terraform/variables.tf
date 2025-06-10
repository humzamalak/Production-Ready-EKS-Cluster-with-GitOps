variable "backend_bucket" {
  description = "S3 bucket for Terraform state storage"
  type        = string
}

variable "backend_key" {
  description = "Path within the bucket for the state file"
  type        = string
  default     = "global/terraform.tfstate"
}

variable "backend_region" {
  description = "AWS region for the backend S3 bucket"
  type        = string
  default     = "us-west-2"
}

variable "backend_dynamodb_table" {
  description = "DynamoDB table for state locking"
  type        = string
}
