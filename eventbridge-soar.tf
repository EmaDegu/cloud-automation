# Example: Trigger isolation when we detect a specific CloudTrail event pattern (demo)
resource "aws_cloudwatch_event_rule" "isolate_on_sg_change" {
  name        = "soar-isolate-on-suspicious-sg-change"
  description = "Demo: trigger isolate when a specific event matches pattern"
  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["AWS API Call via CloudTrail"],
    "detail" : {
      "eventName" : ["AuthorizeSecurityGroupIngress"]
    }
  })
}

resource "aws_cloudwatch_event_target" "isolate_target" {
  rule      = aws_cloudwatch_event_rule.isolate_on_sg_change.name
  target_id = "lambda-isolate"
  arn       = aws_lambda_function.isolate_instance.arn
}

resource "aws_lambda_permission" "allow_eventbridge_isolate" {
  statement_id  = "AllowEventBridgeInvokeIsolate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.isolate_instance.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.isolate_on_sg_change.arn
}

# Scheduled stop for idle instances (e.g., every night 22:00 UTC)
resource "aws_cloudwatch_event_rule" "stop_idle_schedule" {
  name                = "soar-stop-idle-schedule"
  schedule_expression = "cron(0 22 * * ? *)"
}

resource "aws_cloudwatch_event_target" "stop_idle_target" {
  rule      = aws_cloudwatch_event_rule.stop_idle_schedule.name
  target_id = "lambda-stop-idle"
  arn       = aws_lambda_function.stop_idle.arn
}

resource "aws_lambda_permission" "allow_eventbridge_stop_idle" {
  statement_id  = "AllowEventBridgeInvokeStopIdle"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_idle.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_idle_schedule.arn
}
