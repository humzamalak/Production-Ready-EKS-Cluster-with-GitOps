# VPC Module for EKS GitOps Infrastructure
# This module creates a VPC with public/private subnets, Internet Gateway, NAT Gateways, and VPC Flow Logs.
# It is designed for high availability, security, and scalability across three Availability Zones.

# Create the main VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr # Main CIDR block for the VPC
  enable_dns_support   = true         # Enable DNS support for internal resolution
  enable_dns_hostnames = true         # Enable DNS hostnames for EC2 instances
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-vpc"
  })
}

# Internet Gateway for public subnets
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-igw"
  })
}

# Public subnets (one per AZ)
resource "aws_subnet" "public" {
  count                   = 3 # Number of public subnets (one per AZ)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index) # Calculate subnet CIDR
  map_public_ip_on_launch = true                                     # Assign public IPs to instances in this subnet
  availability_zone       = element(var.azs, count.index)
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-public-${count.index + 1}"
    Tier = "public"
  })
}

# Private subnets (one per AZ)
resource "aws_subnet" "private" {
  count             = 3 # Number of private subnets (one per AZ)
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10) # Offset to avoid overlap with public
  availability_zone = element(var.azs, count.index)
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-private-${count.index + 1}"
    Tier = "private"
  })
}

# NAT Gateways for private subnets (one per AZ)
resource "aws_nat_gateway" "this" {
  count         = 3
  allocation_id = aws_eip.nat[count.index].id       # Elastic IP for each NAT Gateway
  subnet_id     = aws_subnet.public[count.index].id # Place NAT in public subnet
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-nat-${count.index + 1}"
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = 3
  domain = "vpc"
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-eip-nat-${count.index + 1}"
  })
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-public-rt"
  })
}

# Route for public subnets to access the internet
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0" # Default route to the internet
  gateway_id             = aws_internet_gateway.this.id
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route tables for private subnets (one per AZ)
resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-private-rt-${count.index + 1}"
  })
}

# Route for private subnets to access the internet via NAT
resource "aws_route" "private_nat" {
  count                  = 3
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

# Associate private subnets with their route tables
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# VPC Flow Logs for monitoring network traffic
resource "aws_kms_key" "vpc_flow_logs" {
  description             = "KMS key for VPC Flow Logs"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = merge(var.tags, { Name = "${var.project_prefix}-${var.environment}-flowlogs-kms" })
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs/${var.project_prefix}-${var.environment}"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.vpc_flow_logs.arn
  tags              = merge(var.tags, { Name = "${var.project_prefix}-${var.environment}-flowlogs" })
}

resource "aws_flow_log" "this" {
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"                     # Capture all traffic (accepted, rejected, etc.)
  iam_role_arn         = var.flow_log_iam_role_arn # IAM role for CloudWatch logs
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-flowlog"
  })
}

# Security group for EKS control plane
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_prefix}-${var.environment}-eks-sg"
  description = "EKS cluster communication"
  vpc_id      = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-eks-sg"
  })
}

# Security group for EKS node group
resource "aws_security_group" "eks_node_group" {
  name        = "${var.project_prefix}-${var.environment}-eks-node-sg"
  description = "EKS node group communication"
  vpc_id      = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-eks-node-sg"
  })
}

# Security group for Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "${var.project_prefix}-${var.environment}-alb-sg"
  description = "Application Load Balancer security group"
  vpc_id      = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-alb-sg"
  })
}

# Security group for applications
resource "aws_security_group" "app" {
  name        = "${var.project_prefix}-${var.environment}-app-sg"
  description = "Application security group"
  vpc_id      = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-app-sg"
  })
}

# Security group for database (if needed)
resource "aws_security_group" "database" {
  name        = "${var.project_prefix}-${var.environment}-db-sg"
  description = "Database security group"
  vpc_id      = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-db-sg"
  })
}

# Security group for Redis/ElastiCache (if needed)
resource "aws_security_group" "redis" {
  name        = "${var.project_prefix}-${var.environment}-redis-sg"
  description = "Redis/ElastiCache security group"
  vpc_id      = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-redis-sg"
  })
}

# Security group rules for EKS cluster
resource "aws_security_group_rule" "eks_cluster_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.eks_cluster.id
  description       = "HTTPS from VPC"
}

resource "aws_security_group_rule" "eks_cluster_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster.id
  description       = "All outbound traffic"
}

# Security group rules for EKS node group
resource "aws_security_group_rule" "eks_node_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.eks_node_group.id
  description       = "All traffic from self"
}

resource "aws_security_group_rule" "eks_node_ingress_cluster" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
  security_group_id        = aws_security_group.eks_node_group.id
  description              = "Node to node communication"
}

resource "aws_security_group_rule" "eks_node_ingress_cluster_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
  security_group_id        = aws_security_group.eks_node_group.id
  description              = "Cluster to node HTTPS"
}

resource "aws_security_group_rule" "eks_node_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_node_group.id
  description       = "All outbound traffic"
}

# Security group rules for ALB
resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere"
}

resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from anywhere"
}

resource "aws_security_group_rule" "alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "All outbound traffic"
}

# Security group rules for applications
resource "aws_security_group_rule" "app_ingress_alb" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.app.id
  description              = "Traffic from ALB"
}

resource "aws_security_group_rule" "app_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.app.id
  description       = "Traffic from self"
}

resource "aws_security_group_rule" "app_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "All outbound traffic"
}

# Security group rules for database
resource "aws_security_group_rule" "db_ingress_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.database.id
  description              = "PostgreSQL from applications"
}

resource "aws_security_group_rule" "db_ingress_self" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.database.id
  description       = "PostgreSQL from self"
}

resource "aws_security_group_rule" "db_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.database.id
  description       = "All outbound traffic"
}

# Security group rules for Redis
resource "aws_security_group_rule" "redis_ingress_app" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.redis.id
  description              = "Redis from applications"
}

resource "aws_security_group_rule" "redis_ingress_self" {
  type              = "ingress"
  from_port         = 6379
  to_port           = 6379
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.redis.id
  description       = "Redis from self"
}

resource "aws_security_group_rule" "redis_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.redis.id
  description       = "All outbound traffic"
}

// Outputs moved to outputs.tf to avoid duplication
