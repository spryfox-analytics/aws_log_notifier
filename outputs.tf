output "filter_pattern" {
  description = "Filter pattern in use by the subscription."
  value       = module.log_notifier.filter_pattern
}

output "default_filter_pattern" {
  description = "Built-in filter pattern, e.g. to extend it with own terms."
  value       = module.log_notifier.default_filter_pattern
}

output "sns_topic_arn" {
  description = "SNS topic the notifications are published to."
  value       = module.log_notifier.sns_topic_arn
}
