locals {
  sns_topic_name = "${var.kebab_case_name_prefix}log-notifier-sns-topic"
}

resource "aws_sns_topic" "log_notifier_sns_topic" {
  name            = local.sns_topic_name
  tags = {
    Customer    = var.customer
    Project     = var.project
    Application = var.application
    Name        = local.sns_topic_name
  }
}

resource "aws_sns_topic_subscription" "log_notifier_sns_topic_subscription" {
  topic_arn = aws_sns_topic.log_notifier_sns_topic.arn
  protocol  = "email"
  endpoint  = var.log_receiver_email_address
}
