# IRSA (IAM Roles for Service Accounts) Example
# This file demonstrates how to create an IAM role for Kubernetes service accounts using IRSA.
# IRSA allows fine-grained AWS permissions for pods in EKS.

# Variables required for this example
variable "region" {
  description = "AWS region for the EKS cluster."
  type        = string
}

variable "eks_oidc_id" {
  description = "OIDC ID for the EKS cluster."
  type        = string
}

resource "aws_iam_role" "irsa_example" {
  name = "eks-irsa-example" # Name of the IAM role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/${var.eks_oidc_id}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "oidc.eks.${var.region}.amazonaws.com/id/${var.eks_oidc_id}:sub" : "system:serviceaccount:production:my-service-account"
        }
      }
    }]
  })
}
