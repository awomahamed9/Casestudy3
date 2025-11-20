# NAT Instance Security Group
resource "aws_security_group" "nat_sg" {
  name        = "${var.project}-nat-sg"
  description = "Security group for NAT instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow from private subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.11.0/24", "10.0.12.0/24"]
  }

  ingress {
    description = "Allow from VPN"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.8.0.0/24"]
  }

  ingress {
    description = "ICMP from VPN"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.8.0.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-nat-sg"
  }
}

# Database Security Group
resource "aws_security_group" "db_sg" {
  name        = "${var.project}-db-sg"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project}-db-sg"
  }
}

resource "aws_security_group_rule" "db_from_vpn" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["10.8.0.0/24"]
  security_group_id = aws_security_group.db_sg.id
  description       = "MySQL from VPN"
}

# Allow MySQL from entire VPC (for EKS pods with dynamic IPs)
resource "aws_security_group_rule" "db_from_vpc" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.db_sg.id
  description       = "MySQL from VPC CIDR"
}

resource "aws_security_group_rule" "db_from_eks" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.db_sg.id
  description              = "MySQL from EKS nodes"
}

resource "aws_security_group_rule" "db_from_lambda" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda_sg.id
  security_group_id        = aws_security_group.db_sg.id
  description              = "MySQL from Lambda"
}

# EKS Cluster Security Group
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project}-eks-cluster-sg"
  description = "EKS cluster security group"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-eks-cluster-sg"
  }
}

# EKS Nodes Security Group
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project}-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                       = "${var.project}-eks-nodes-sg"
    "kubernetes.io/cluster/${var.project}-eks" = "owned"
  }
}

resource "aws_security_group_rule" "nodes_internal" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.eks_nodes.id
  description              = "Allow nodes to communicate"
}

resource "aws_security_group_rule" "nodes_from_cluster" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
  security_group_id        = aws_security_group.eks_nodes.id
  description              = "Allow pods to receive communication from cluster control plane"
}

resource "aws_security_group_rule" "cluster_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.eks_cluster.id
  description              = "Allow nodes to communicate with cluster API"
}

resource "aws_security_group_rule" "nodes_ssh_from_vpn" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["10.8.0.0/24"]
  security_group_id = aws_security_group.eks_nodes.id
  description       = "SSH from VPN"
}

resource "aws_security_group_rule" "nodes_icmp_from_vpn" {
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["10.8.0.0/24"]
  security_group_id = aws_security_group.eks_nodes.id
  description       = "Ping from VPN"
}

# Lambda Security Group
resource "aws_security_group" "lambda_sg" {
  name        = "${var.project}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-lambda-sg"
  }
}