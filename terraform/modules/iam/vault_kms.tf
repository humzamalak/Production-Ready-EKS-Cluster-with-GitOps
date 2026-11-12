# KMS key and IRSA role for HashiCorp Vault auto-unseal on EKS.
# helm-charts/vault/values-aws.yaml points the awskms seal at this alias and
# runs Vault as the vault/vault-server service account.

locals {
  oidc_provider = replace(var.eks_oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")
}

resource "aws_kms_key" "vault_unseal" {
  description             = "Vault auto-unseal key for ${var.project_prefix}-${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-vault-unseal"
  })
}

resource "aws_kms_alias" "vault_unseal" {
  name          = var.vault_kms_alias
  target_key_id = aws_kms_key.vault_unseal.key_id
}

resource "aws_iam_role" "vault_server" {
  name = "${var.project_prefix}-${var.environment}-vault-server-role"
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
          "${local.oidc_provider}:sub" = "system:serviceaccount:${var.vault_namespace}:${var.vault_service_account}"
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-vault-server-role"
  })
}

resource "aws_iam_role_policy" "vault_unseal" {
  name = "vault-kms-unseal"
  role = aws_iam_role.vault_server.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey"]
      Resource = aws_kms_key.vault_unseal.arn
    }]
  })
}
