# Simulated managed employee workstations using AWS Systems Manager
resource "aws_instance" "managed_workstation" {
  count                  = 2
  ami                    = data.aws_ami.amzn2.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_app_1.id
  vpc_security_group_ids = [aws_security_group.workstation_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_managed.name

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum install -y amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    
    # Security baseline - install antivirus and updates
    yum update -y
    yum install -y clamav
    
    echo "Workstation enrolled and secured" > /var/log/baseline.log
  EOF
  )

  tags = {
    Name        = "${var.project}-workstation-${count.index + 1}"
    ManagedBy   = "SSM"
    Compliance  = "security-baseline-v1"
    Environment = "production"
  }
}

# IAM role for SSM-managed instances
resource "aws_iam_role" "ssm_managed" {
  name = "${var.project}-ssm-managed-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ssm_managed.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_managed" {
  name = "${var.project}-ssm-managed-profile"
  role = aws_iam_role.ssm_managed.name
}

# Enforce security baseline via SSM State Manager
resource "aws_ssm_association" "security_baseline" {
  name = "AWS-RunPatchBaseline"

  targets {
    key    = "tag:ManagedBy"
    values = ["SSM"]
  }

  schedule_expression = "rate(7 days)"
}

# Security group for managed workstations
resource "aws_security_group" "workstation_sg" {
  name        = "${var.project}-workstation-sg"
  description = "Security group for managed employee workstations"
  vpc_id      = aws_vpc.main.id

  # Allow outbound internet for updates
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow access from VPN
  ingress {
    description = "Management from VPN"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.8.0.0/24"]
  }

  # Allow ping from VPN
  ingress {
    description = "ICMP from VPN"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.8.0.0/24"]
  }

  tags = {
    Name = "${var.project}-workstation-sg"
  }
}

# Outputs for documentation
output "managed_workstations" {
  value = {
    for idx, instance in aws_instance.managed_workstation :
    "workstation-${idx + 1}" => {
      id          = instance.id
      private_ip  = instance.private_ip
      ssm_managed = "yes"
      compliance  = "security-baseline-v1"
    }
  }
  description = "Managed workstations with security baseline"
}