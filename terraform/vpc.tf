resource "aws_vpc" "eks_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.dns_hostnames_enabled
  enable_dns_support   = var.dns_support_enabled

  tags = {
    Name = "eks-vpc-${var.aws_environment}"
  }
}

resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-igw-${var.aws_environment}"
  }
}



resource "aws_subnet" "eks_cp_subnets" {
  count             = length(var.eks_cp_public_subnets)
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.eks_cp_public_subnets[count.index][0]
  availability_zone = "${var.aws_region}${var.eks_cp_public_subnets[count.index][1]}"

  tags = {
    Name = "eks-cp-subnet-${var.aws_region}${var.eks_cp_public_subnets[count.index][1]}"
  }
}

resource "aws_subnet" "eks_worker_subnets" {
  count             = length(var.eks_worker_nodes_subnets)
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.eks_worker_nodes_subnets[count.index][0]
  availability_zone = "${var.aws_region}${var.eks_worker_nodes_subnets[count.index][1]}"

  tags = {
    Name                                               = "eks-worker-subnet-${var.aws_region}${var.eks_worker_nodes_subnets[count.index][1]}"
    "kubernetes.io/role/internal-elb"                  = "1"
    "kubernetes.io/cluster/eks-${var.aws_environment}" = "shared"
  }
}

resource "aws_eip" "nat_gw_eip" {
  count  = length(var.eks_worker_nodes_subnets)
  domain = "vpc"
  tags = {
    Name = "eks-nat-gw-eip"
  }
  depends_on = [aws_internet_gateway.eks_igw]
}

resource "aws_nat_gateway" "eks_ngw" {
  count         = length(var.eks_worker_nodes_subnets)
  allocation_id = aws_eip.nat_gw_eip[count.index].id
  subnet_id     = aws_subnet.eks_cp_subnets[count.index].id

  tags = {
    Name = "eks-nat-gw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.eks_igw]
}

resource "aws_route_table" "public_subnet_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name = "eks-public-subnet-rt"
  }

}

resource "aws_route_table" "private_subnets_rt" {
  count  = length(var.eks_worker_nodes_subnets)
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.eks_ngw[count.index].id
  }

  tags = {
    Name = "eks-private-subnet-rt"
  }
}

resource "aws_route_table_association" "public_subnet" {
  count          = length(var.eks_cp_public_subnets)
  subnet_id      = aws_subnet.eks_cp_subnets[count.index].id
  route_table_id = aws_route_table.public_subnet_rt.id
}

resource "aws_route_table_association" "private_subnet" {
  count          = length(var.eks_worker_nodes_subnets)
  subnet_id      = aws_subnet.eks_worker_subnets[count.index].id
  route_table_id = aws_route_table.private_subnets_rt[count.index].id
}
