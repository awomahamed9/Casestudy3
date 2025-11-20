resource "aws_ecr_repository" "hr_app" {
  name                 = "${var.project}-hr-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project}-hr-app"
  }
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.hr_app.repository_url
  description = "ECR repository URL for HR application"
}