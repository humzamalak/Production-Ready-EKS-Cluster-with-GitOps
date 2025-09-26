# Remote backend configuration for Terraform state
# This file configures where Terraform stores its state file and how it locks state for safe concurrent use.
# Note: This does NOT create the S3 bucket or DynamoDB table, it only configures usage.
# Resource creation is documented in README and can be managed manually or via a bootstrap script.

terraform {
  # Configure the S3 backend at init time using -backend-config to avoid hardcoding env-specific values.
  # Example:
  # terraform init \
  #   -backend-config="bucket=eks-gitops-<env>-tfstate" \
  #   -backend-config="key=<env>/terraform.tfstate" \
  #   -backend-config="region=<aws-region>" \
  #   -backend-config="dynamodb_table=eks-gitops-<env>-tflock" \
  #   -backend-config="encrypt=true"
  backend "s3" {}
}
