resource "aws_cloudwatch_event_rule" "db_poll_schedule" {
  name                = "${var.project}-db-poll"
  description         = "Trigger DB poller every 5 minutes"
  schedule_expression = "rate(1 minutes)"

  tags = {
    Name = "${var.project}-db-poll-schedule"
  }
}

resource "aws_cloudwatch_event_target" "db_poller" {
  rule      = aws_cloudwatch_event_rule.db_poll_schedule.name
  target_id = "DbPollerLambda"
  arn       = aws_lambda_function.db_poller.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.db_poller.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.db_poll_schedule.arn
}