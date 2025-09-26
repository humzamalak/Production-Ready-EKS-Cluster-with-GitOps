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
  map_public_ip_on_launch = true # Assign public IPs to instances in this subnet
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
  allocation_id = aws_eip.nat[count.index].id # Elastic IP for each NAT Gateway
  subnet_id     = aws_subnet.public[count.index].id # Place NAT in public subnet
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-nat-${count.index + 1}"
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = 3
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
  tags = merge(var.tags, { Name = "${var.project_prefix}-${var.environment}-flowlogs-kms" })
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs/${var.project_prefix}-${var.environment}"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.vpc_flow_logs.arn
  tags = merge(var.tags, { Name = "${var.project_prefix}-${var.environment}-flowlogs" })
}

resource "aws_flow_log" "this" {
  log_destination_type = "cloud-watch-logs"
  log_group_name       = aws_cloudwatch_log_group.vpc_flow_logs.name
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL" # Capture all traffic (accepted, rejected, etc.)
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

# Outputs: Expose key resource IDs for use in other modules
output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "eks_cluster_sg_id" {
  value = aws_security_group.eks_cluster.id
}
