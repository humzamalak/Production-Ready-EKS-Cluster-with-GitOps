# VPC Module for EKS GitOps Infrastructure
# Creates a VPC with public/private subnets, IGW, NAT, and flow logs

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-igw"
  })
}

resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(var.azs, count.index)
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = element(var.azs, count.index)
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-private-${count.index + 1}"
    Tier = "private"
  })
}

resource "aws_nat_gateway" "this" {
  count         = 3
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-nat-${count.index + 1}"
  })
}

resource "aws_eip" "nat" {
  count = 3
  vpc   = true
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-eip-nat-${count.index + 1}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-public-rt"
  })
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-private-rt-${count.index + 1}"
  })
}

resource "aws_route" "private_nat" {
  count                  = 3
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_flow_log" "this" {
  log_destination_type = "cloud-watch-logs"
  log_group_name       = "/aws/vpc/flowlogs/${var.project_prefix}-${var.environment}"
  resource_id          = aws_vpc.this.id
  traffic_type         = "ALL"
  iam_role_arn         = var.flow_log_iam_role_arn
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-flowlog"
  })
}

resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_prefix}-${var.environment}-eks-sg"
  description = "EKS cluster communication"
  vpc_id      = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.environment}-eks-sg"
  })
}

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
