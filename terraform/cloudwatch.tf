resource "aws_cloudwatch_log_subscription_filter" "log_notifier_cloudwatch_log_subscription_filter" {
  depends_on      = [aws_lambda_permission.log_notifier_lambda_permission]
  name            = "${var.kebab_case_name_prefix}log-notifier-cloudwatch-log-subscription-filter"
  log_group_name  = var.log_group_name
  filter_pattern  = var.filter_pattern
  destination_arn = aws_lambda_function.log_notifier_lambda.arn
}

resource "aws_cloudwatch_log_group" "log_notifier_lambda_log_group" {
  name = "/aws/lambda/${local.log_notifier_lambda_name}"
  retention_in_days = 30
}
