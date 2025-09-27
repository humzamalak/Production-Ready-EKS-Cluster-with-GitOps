# IRSA (IAM Roles for Service Accounts) Example
# This file demonstrates how to create an IAM role for Kubernetes service accounts using IRSA.
# IRSA allows fine-grained AWS permissions for pods in EKS.

# Variables are defined in variables.tf

resource "aws_iam_role" "irsa_example" {
  name = "eks-irsa-example" # Name of the IAM role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.eks_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.eks_oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")}:sub" = "system:serviceaccount:production:my-service-account"
          "${replace(var.eks_oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}
