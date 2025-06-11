# Terraform version and provider requirements
# This file ensures you are using compatible versions of Terraform and the AWS provider.

terraform {
  required_version = ">= 1.4.0" # Minimum Terraform version required
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0" # Minimum AWS provider version required
    }
  }
}

provider "aws" {
  region = "eu-west-1" # Default AWS region (can be overridden by variables)
}
