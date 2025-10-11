# Version and provider requirements for the VPC module
# Ensures compatibility with Terraform and AWS provider versions.

terraform {
  required_version = ">= 1.4.0" # Minimum Terraform version required
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0" # Minimum AWS provider version required
    }
  }
}
