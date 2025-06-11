# Remote backend configuration for Terraform state
# This file configures where Terraform stores its state file and how it locks state for safe concurrent use.
# Note: This does NOT create the S3 bucket or DynamoDB table, it only configures usage.
# Resource creation is documented in README and can be managed manually or via a bootstrap script.

terraform {
  backend "s3" {
    bucket         = "eks-gitops-prod-tfstate" # Name of the S3 bucket to store the state file
    key            = "global/s3/terraform.tfstate" # Path within the bucket for the state file
    region         = "us-east-1" # AWS region where the S3 bucket and DynamoDB table exist
    dynamodb_table = "eks-gitops-prod-tflock" # DynamoDB table for state locking (prevents concurrent changes)
    encrypt        = true # Encrypt the state file at rest
  }
}
