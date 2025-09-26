# EKS Module for EKS GitOps Infrastructure
# This module creates an EKS cluster, managed node group, and required IAM roles for secure, scalable Kubernetes workloads.

# Create the EKS cluster
resource "aws_eks_cluster" "this" {
  name     = "${var.project_prefix}-${var.environment}-cluster" # Cluster name
  role_arn = aws_iam_role.eks_cluster.arn # IAM role for the EKS control plane
  version  = var.kubernetes_version # Kubernetes version

  vpc_config {
    subnet_ids         = var.private_subnet_ids # Use private subnets for worker nodes
    security_group_ids = [var.eks_cluster_sg_id] # Security group for control plane
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"] # Enable logging for troubleshooting

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
    resources = ["secrets"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-eks-cluster"
  })
}

# KMS key for EKS secrets envelope encryption
resource "aws_kms_key" "eks_secrets" {
  description             = "KMS key for EKS secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-eks-secrets-kms"
  })
}

# IAM role for EKS control plane
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_prefix}-${var.environment}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-eks-cluster-role"
  })
}

data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# Managed node group for running workloads
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_prefix}-${var.environment}-ng-main"
  node_role_arn   = aws_iam_role.eks_node_group.arn # IAM role for nodes
  subnet_ids      = var.private_subnet_ids
  scaling_config {
    desired_size = 2 # Default number of nodes
    max_size     = 10 # Maximum nodes for autoscaling
    min_size     = 2 # Minimum nodes
  }
  instance_types = [var.node_instance_type] # EC2 instance type for nodes
  ami_type       = "AL2_x86_64" # Amazon Linux 2
  disk_size      = 50 # Disk size in GB
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-ng-main"
    "k8s.io/cluster-autoscaler/enabled" = "true"
    "k8s.io/cluster-autoscaler/${aws_eks_cluster.this.name}" = "owned"
  })
}

# Enable OIDC provider for IRSA
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-eks-oidc"
  })
}

# Managed EKS Addons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"
  most_recent  = true
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"
  most_recent  = true
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"
  most_recent  = true
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "aws-ebs-csi-driver"
  most_recent  = true
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "eks-pod-identity-agent"
  most_recent  = true
}

# IAM role for EKS node group
resource "aws_iam_role" "eks_node_group" {
  name = "${var.project_prefix}-${var.environment}-eks-ng-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-eks-ng-role"
  })
}

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Attach required policies to EKS control plane role
resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSServicePolicy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

# Attach required policies to EKS node group role
resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
