locals {
  log_notifier_lambda_name = "${var.kebab_case_name_prefix}log-notifier-lambda"
}

data "archive_file" "log_notifier_lambda_archive_file" {
  type        = "zip"
  output_path = var.log_notifier_lambda_target_path
  dynamic "source" {
    for_each = toset([
      var.log_notifier_lambda_name_src_file_path
    ])
    content {
      content  = file("${path.module}/${source.value}")
      filename = basename(source.value)
    }
  }
}

resource "aws_lambda_function" "log_notifier_lambda" {
  filename = var.log_notifier_lambda_target_path
  function_name = local.log_notifier_lambda_name
  role = aws_iam_role.log_notifier_lambda_role.arn
  handler = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.log_notifier_lambda_archive_file.output_base64sha256
  runtime = "python3.9"
  depends_on = [
    aws_iam_role_policy_attachment.log_notifier_lambda_role_log_policy_attachment,
    aws_cloudwatch_log_group.log_notifier_lambda_log_group
  ]
  environment {
    variables = {
      LOG_NOTIFIER_SNS_TOPIC_ARN = aws_sns_topic.log_notifier_sns_topic.arn,
      EMAIL_SUBJECT_PREFIX = var.email_subject_prefix
    }
  }
  tags = {
    Application = var.application
    Customer    = var.customer
    Name        = local.log_notifier_lambda_name
    Project     = var.project
  }
}

resource "aws_lambda_permission" "log_notifier_lambda_permission" {
  statement_id  = "AllowExecutionFromCloudwatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_notifier_lambda.arn
  principal     = "logs.${var.aws_region}.amazonaws.com"
  source_arn    = "${var.log_group_arn}:*"
}
