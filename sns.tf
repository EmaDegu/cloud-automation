resource "aws_sns_topic" "soar_alerts" {
  name = "soar-alerts"
}

# Optional: email subscription (confirm via email link)
resource "aws_sns_topic_subscription" "soar_email" {
  topic_arn = aws_sns_topic.soar_alerts.arn
  protocol  = "email"
  endpoint  = "560523@student.fontys.nl"
}
