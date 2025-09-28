# Cluster Autoscaler Deployment for EKS
# This file deploys the Kubernetes Cluster Autoscaler using Helm.
# The autoscaler automatically adjusts the number of nodes in your cluster based on resource demand.
# The variables cluster_name and region are provided by the module or parent configuration.

resource "aws_iam_role" "cluster_autoscaler" {
  name = "${var.project_prefix}-${var.environment}-cluster-autoscaler"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" : "system:serviceaccount:kube-system:cluster-autoscaler"
        }
      }
    }]
  })
  tags = {
    Name = "${var.project_prefix}-${var.environment}-cluster-autoscaler"
  }
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.project_prefix}-${var.environment}-ClusterAutoscalerPolicy"
  description = "Permissions for Cluster Autoscaler"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "autoscaling:UpdateAutoScalingGroup"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "ec2:DescribeLaunchTemplateVersions"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_attach" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"                      # Name of the Helm release
  repository = "https://kubernetes.github.io/autoscaler" # Helm chart repository
  chart      = "cluster-autoscaler"                      # Chart name
  version    = "9.29.0"                                  # Chart version
  namespace  = "kube-system"                             # Namespace to deploy the autoscaler
  values = [
    <<EOF
    autoDiscovery:
      clusterName: ${var.cluster_name} # Name of the EKS cluster (from variable)
    awsRegion: ${var.region} # AWS region (from variable)
    rbac:
      create: true
      serviceAccount:
        create: true
        name: cluster-autoscaler
        annotations:
          eks.amazonaws.com/role-arn: ${aws_iam_role.cluster_autoscaler.arn}
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 250m
        memory: 256Mi
    EOF
  ]
}
