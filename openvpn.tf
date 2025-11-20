resource "aws_security_group" "openvpn_sg" {
  name        = "${var.project}-openvpn-sg"
  description = "Security group for OpenVPN server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "OpenVPN UDP"
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-openvpn-sg"
  }
}

resource "aws_instance" "openvpn_server" {
  ami                         = data.aws_ami.amzn2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_2.id
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.openvpn_sg.id]
  associate_public_ip_address = true
  source_dest_check           = false

  user_data = base64encode(templatefile("${path.module}/openvpn_user_data.sh", {
    vpc_cidr        = var.vpc_cidr
    vpn_client_cidr = "10.8.0.0/24"
    dns_server      = cidrhost(var.vpc_cidr, 2)
    key_name        = var.key_pair_name
  }))

  tags = {
    Name = "${var.project}-openvpn"
  }
}

output "openvpn_public_ip" {
  value       = aws_instance.openvpn_server.public_ip
  description = "OpenVPN server public IP"
}

output "openvpn_scp_command" {
  value       = "scp -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_instance.openvpn_server.public_ip}:client.ovpn ./"
  description = "Command to download VPN client config"
}