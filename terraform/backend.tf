terraform {
  required_version = ">= 1.5"

  backend "s3" {
    bucket         = var.backend_bucket
    key            = var.backend_key
    region         = var.backend_region
    dynamodb_table = var.backend_dynamodb_table
    encrypt        = true
  }
}
