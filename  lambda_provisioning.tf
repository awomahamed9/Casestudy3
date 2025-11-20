resource "aws_lambda_function" "provisioning" {
  filename         = "provisioning.zip"
  function_name    = "${var.project}-provisioning"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "provisioning.lambda_handler"
  runtime          = "python3.11"
  timeout          = 60
  source_code_hash = filebase64sha256("provisioning.zip")

  vpc_config {
    subnet_ids         = [aws_subnet.private_app_1.id, aws_subnet.private_app_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_HOST     = aws_db_instance.employee_db.endpoint
      DB_NAME     = aws_db_instance.employee_db.db_name
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password
    }
  }

  depends_on = [aws_iam_role_policy.lambda_policy]

  tags = {
    Name = "${var.project}-provisioning"
  }
}