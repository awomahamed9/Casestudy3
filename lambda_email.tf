resource "aws_lambda_function" "email_sender" {
  filename         = "email_sender.zip"
  function_name    = "${var.project}-email-sender"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "email_sender.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  source_code_hash = filebase64sha256("email_sender.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.employee_notifications.arn
    }
  }

  depends_on = [aws_iam_role_policy.lambda_policy]

  tags = {
    Name = "${var.project}-email-sender"
  }
}