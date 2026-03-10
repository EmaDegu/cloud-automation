
# Basic logging permissions
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.soar_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create a tiny Lambda zip from inline code
data "archive_file" "soar_zip" {
  type        = "zip"
  output_path = "${path.module}/soar.zip"

  source {
    content  = <<PY
def handler(event, context):
    print("SOAR test event:", event)
    return {"ok": True}
PY
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "soar" {
  function_name = "soar_handle_event"
  role          = aws_iam_role.soar_lambda_role.arn
  runtime       = "python3.11"
  handler       = "lambda_function.handler"
  filename      = data.archive_file.soar_zip.output_path
  timeout       = 10
}

# EventBridge rule that matches a simple custom event
resource "aws_cloudwatch_event_rule" "soar_rule" {
  name        = "soar-test-rule"
  description = "Trigger SOAR lambda on custom.soar events"
  event_pattern = jsonencode({
    "source" : ["custom.soar"]
  })
}

resource "aws_cloudwatch_event_target" "soar_target" {
  rule      = aws_cloudwatch_event_rule.soar_rule.name
  target_id = "soar-lambda"
  arn       = aws_lambda_function.soar.arn
}

# Allow EventBridge to invoke the Lambda
resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.soar_rule.arn
}
