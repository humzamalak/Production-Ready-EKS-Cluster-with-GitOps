# EKS Module for EKS GitOps Infrastructure
# Creates an EKS cluster, managed node group, and required IAM roles

resource "aws_eks_cluster" "this" {
  name     = "${var.project_prefix}-${var.environment}-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = var.private_subnet_ids
    security_group_ids = [var.eks_cluster_sg_id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-eks-cluster"
  })
}

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

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_prefix}-${var.environment}-ng-main"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = var.private_subnet_ids
  scaling_config {
    desired_size = 2
    max_size     = 10
    min_size     = 2
  }
  instance_types = [var.node_instance_type]
  ami_type       = "AL2_x86_64"
  disk_size      = 50
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-ng-main"
  })
}

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

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSServicePolicy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

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

output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "node_group_role_arn" {
  value = aws_iam_role.eks_node_group.arn
}
