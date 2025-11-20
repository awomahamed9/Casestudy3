resource "aws_instance" "grafana" {
  ami                         = data.aws_ami.amzn2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_app_1.id
  vpc_security_group_ids      = [aws_security_group.grafana_sg.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.grafana_profile.name

  tags = {
    Name = "${var.project}-grafana"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    
    # Wait for network
    sleep 30
    
    # Update system
    yum update -y
    
    # Add Grafana repository
    cat > /etc/yum.repos.d/grafana.repo <<'REPO'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
REPO
    
    # Install Grafana
    yum install -y grafana
    
    # Start and enable Grafana
    systemctl daemon-reload
    systemctl start grafana-server
    systemctl enable grafana-server
    
    # Configure CloudWatch datasource
    mkdir -p /etc/grafana/provisioning/datasources
    cat > /etc/grafana/provisioning/datasources/cloudwatch.yaml <<'YAML'
apiVersion: 1
datasources:
  - name: CloudWatch
    type: cloudwatch
    access: proxy
    jsonData:
      defaultRegion: ${var.aws_region}
      authType: default
YAML
    
    # Restart to load datasource
    systemctl restart grafana-server
  EOF
  )
}

# Security Group for Grafana
resource "aws_security_group" "grafana_sg" {
  name   = "${var.project}-grafana-sg"
  vpc_id = aws_vpc.main.id

  # Grafana web interface from VPN
  ingress {
    description = "Grafana from VPN"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.8.0.0/24"]
  }

  # SSH from VPN
  ingress {
    description = "SSH from VPN"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.8.0.0/24"]
  }

  # ICMP from VPN
  ingress {
    description = "Ping from VPN"
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
    Name = "${var.project}-grafana-sg"
  }
}

# IAM Role for Grafana to access CloudWatch
resource "aws_iam_role" "grafana_role" {
  name = "${var.project}-grafana-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "grafana_policy" {
  name = "${var.project}-grafana-policy"
  role = aws_iam_role.grafana_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "cloudwatch:DescribeAlarmsForMetric",
        "cloudwatch:DescribeAlarmHistory",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:GetMetricData",
        "logs:DescribeLogGroups",
        "logs:GetLogGroupFields",
        "logs:StartQuery",
        "logs:StopQuery",
        "logs:GetQueryResults",
        "logs:GetLogEvents",
        "logs:FilterLogEvents",
        "ec2:DescribeTags",
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "rds:DescribeDBInstances",
        "rds:ListTagsForResource"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "grafana_profile" {
  name = "${var.project}-grafana-profile"
  role = aws_iam_role.grafana_role.name
}

# Output
output "grafana_private_ip" {
  value       = aws_instance.grafana.private_ip
  description = "Grafana private IP (access via VPN at http://IP:3000)"
}
