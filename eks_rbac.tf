# IAM roles for Kubernetes access

# Role for HR admins (full K8s access)
resource "aws_iam_role" "k8s_hr_admin" {
  name = "${var.project}-k8s-hr-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project}-k8s-hr-admin"
  }
}

# Role for developers (read-only K8s access)
resource "aws_iam_role" "k8s_developer" {
  name = "${var.project}-k8s-developer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project}-k8s-developer"
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Map IAM roles to Kubernetes RBAC groups
resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      # EKS nodes
      {
        rolearn  = aws_iam_role.eks_nodes.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      },
      # HR admins
      {
        rolearn  = aws_iam_role.k8s_hr_admin.arn
        username = "hr-admin"
        groups   = ["hr-admins"]
      },
      # Developers
      {
        rolearn  = aws_iam_role.k8s_developer.arn
        username = "developer"
        groups   = ["developers"]
      }
    ])
  }

  force = true

  depends_on = [aws_eks_node_group.main]
}

# Outputs
output "k8s_rbac_roles" {
  value = {
    hr_admin_role_arn  = aws_iam_role.k8s_hr_admin.arn
    developer_role_arn = aws_iam_role.k8s_developer.arn
  }
  description = "IAM roles for Kubernetes access"
}