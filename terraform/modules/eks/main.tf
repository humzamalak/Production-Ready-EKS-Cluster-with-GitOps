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
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"] # Enable logging for troubleshooting

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-eks-cluster"
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
  })
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

# Outputs: Expose key resource IDs for use in other modules
output "cluster_name" {
  value = aws_eks_cluster.this.name # Output the actual EKS cluster name
}

output "region" {
  value = var.aws_region # Output the AWS region used for the cluster
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "node_group_role_arn" {
  value = aws_iam_role.eks_node_group.arn
}
