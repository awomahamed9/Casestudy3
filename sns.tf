resource "aws_sns_topic" "employee_notifications" {
  name = "${var.project}-employee-notifications"

  tags = {
    Name = "${var.project}-employee-notifications"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.employee_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

output "sns_topic_arn" {
  value = aws_sns_topic.employee_notifications.arn
}