data "archive_file" "isolate_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/isolate_instance.py"
  output_path = "${path.module}/lambda/isolate_instance.zip"
}

resource "aws_lambda_function" "isolate_instance" {
  function_name = "soar-isolate-instance"
  role          = aws_iam_role.soar_lambda_role.arn
  handler       = "isolate_instance.handler"
  runtime       = "python3.12"
  filename      = data.archive_file.isolate_zip.output_path
  timeout       = 30

  environment {
    variables = {
      QUARANTINE_SG_ID = aws_security_group.sg_quarantine.id
      SNS_ARN          = aws_sns_topic.soar_alerts.arn
    }
  }
}
