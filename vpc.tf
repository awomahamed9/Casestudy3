resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project}-vpc"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Public Subnets
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.project}-public-1"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.project}-public-2"
    "kubernetes.io/role/elb" = "1"
  }
}

# Private App Subnets (for EKS)
resource "aws_subnet" "private_app_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name                                       = "${var.project}-private-app-1"
    "kubernetes.io/role/internal-elb"          = "1"
    "kubernetes.io/cluster/${var.project}-eks" = "shared"
  }
}

resource "aws_subnet" "private_app_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name                                       = "${var.project}-private-app-2"
    "kubernetes.io/role/internal-elb"          = "1"
    "kubernetes.io/cluster/${var.project}-eks" = "shared"
  }
}

# Private DB Subnets
resource "aws_subnet" "private_db_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project}-private-db-1"
  }
}

resource "aws_subnet" "private_db_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project}-private-db-2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-igw"
  }
}

# NAT Instance AMI
data "aws_ami" "amzn2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# NAT Instance
resource "aws_instance" "nat_instance" {
  ami                         = data.aws_ami.amzn2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_1.id
  associate_public_ip_address = true
  source_dest_check           = false
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.nat_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y iptables-services
    
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
    
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    iptables -A FORWARD -j ACCEPT
    
    service iptables save
    systemctl start iptables
    systemctl enable iptables
  EOF
  )

  tags = {
    Name = "${var.project}-nat-instance"
  }
}

resource "aws_eip" "nat" {
  instance = aws_instance.nat_instance.id
  domain   = "vpc"

  tags = {
    Name = "${var.project}-nat-eip"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.nat_instance.primary_network_interface_id
  }

  tags = {
    Name = "${var.project}-private-rt"
  }
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-database-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_app_1" {
  subnet_id      = aws_subnet.private_app_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_app_2" {
  subnet_id      = aws_subnet.private_app_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_db_1" {
  subnet_id      = aws_subnet.private_db_1.id
  route_table_id = aws_route_table.database.id
}

resource "aws_route_table_association" "private_db_2" {
  subnet_id      = aws_subnet.private_db_2.id
  route_table_id = aws_route_table.database.id
}

# VPN routes
resource "aws_route" "vpn_to_private" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "10.8.0.0/24"
  network_interface_id   = aws_instance.openvpn_server.primary_network_interface_id
}

resource "aws_route" "vpn_to_database" {
  route_table_id         = aws_route_table.database.id
  destination_cidr_block = "10.8.0.0/24"
  network_interface_id   = aws_instance.openvpn_server.primary_network_interface_id
}

resource "aws_route" "vpn_to_public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "10.8.0.0/24"
  network_interface_id   = aws_instance.openvpn_server.primary_network_interface_id
}

# VPN clients to private app subnets route
resource "aws_route" "vpn_to_private_app" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "10.8.0.0/24"
  network_interface_id   = aws_instance.openvpn_server.primary_network_interface_id
}