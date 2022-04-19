locals {
  error_log_notifier_lambda_role_name = "${var.camel_case_name_prefix}ErrorLogNotifierLambdaRole"
  error_log_notifier_lambda_log_policy_name = "${var.camel_case_name_prefix}ErrorLogNotifierLambdaLogPolicy"
  error_log_notifier_lambda_sns_policy_name = "${var.camel_case_name_prefix}ErrorLogNotifierLambdaSnsPolicy"
}

resource "aws_iam_role" "error_log_notifier_lambda_role" {
  name = local.error_log_notifier_lambda_role_name
  assume_role_policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
        Action: "sts:AssumeRole",
        Principal: {
          Service: "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid = ""
      }
    ]
  })
}

resource "aws_iam_policy" "error_log_notifier_lambda_log_policy" {
  name = local.error_log_notifier_lambda_log_policy_name
  path = "/"
  description = "IAM policy for logging from a lambda"

  policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*",
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "error_log_notifier_lambda_role_log_policy_attachment" {
  role = aws_iam_role.error_log_notifier_lambda_role.name
  policy_arn = aws_iam_policy.error_log_notifier_lambda_log_policy.arn
}

resource "aws_iam_policy" "error_log_notifier_lambda_sns_policy" {
  name = local.error_log_notifier_lambda_sns_policy_name
  path = "/"
  description = "This policy allows the respective lambda to publish SNS messages for logs to be sent out."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sns:Publish",
        ]
        Effect = "Allow"
        Resource = aws_sns_topic.error_log_notifier_sns_topic.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "error_log_notifier_lambda_role_sns_policy_attachment" {
  role = aws_iam_role.error_log_notifier_lambda_role.name
  policy_arn = aws_iam_policy.error_log_notifier_lambda_sns_policy.arn
}
