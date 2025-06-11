# Remote backend configuration for Terraform state
# This does NOT create the S3 bucket or DynamoDB table, it only configures usage
# Resource creation is documented in README and can be managed manually or via a bootstrap script
terraform {
  backend "s3" {
    bucket         = "eks-gitops-prod-tfstate"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eks-gitops-prod-tflock"
    encrypt        = true
  }
}
