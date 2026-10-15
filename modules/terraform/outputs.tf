output "filter_pattern" {
  value = aws_cloudwatch_log_subscription_filter.log_notifier_cloudwatch_log_subscription_filter.filter_pattern
}

output "default_filter_pattern" {
  value = local.default_filter_pattern
}

output "sns_topic_arn" {
  value = aws_sns_topic.log_notifier_sns_topic.arn
}
