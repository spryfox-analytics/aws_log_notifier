locals {
  log_notifier_lambda_role_name         = "${var.camel_case_name_prefix}LogNotifierLambdaRole"
  log_notifier_lambda_log_policy_name   = "${var.camel_case_name_prefix}LogNotifierLambdaLogPolicy"
  log_notifier_lambda_sns_policy_name   = "${var.camel_case_name_prefix}LogNotifierLambdaSnsPolicy"
  log_notifier_lambda_dedup_policy_name = "${var.camel_case_name_prefix}LogNotifierLambdaDedupPolicy"
}

resource "aws_iam_role" "log_notifier_lambda_role" {
  name = local.log_notifier_lambda_role_name
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Action : "sts:AssumeRole",
        Principal : {
          Service : "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_policy" "log_notifier_lambda_log_policy" {
  name        = local.log_notifier_lambda_log_policy_name
  path        = "/"
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
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*",
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "log_notifier_lambda_role_log_policy_attachment" {
  role       = aws_iam_role.log_notifier_lambda_role.name
  policy_arn = aws_iam_policy.log_notifier_lambda_log_policy.arn
}

resource "aws_iam_policy" "log_notifier_lambda_sns_policy" {
  name        = local.log_notifier_lambda_sns_policy_name
  path        = "/"
  description = "This policy allows the respective lambda to publish SNS messages for logs to be sent out."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sns:Publish",
        ]
        Effect   = "Allow"
        Resource = aws_sns_topic.log_notifier_sns_topic.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "log_notifier_lambda_role_sns_policy_attachment" {
  role       = aws_iam_role.log_notifier_lambda_role.name
  policy_arn = aws_iam_policy.log_notifier_lambda_sns_policy.arn
}

resource "aws_iam_policy" "log_notifier_lambda_dedup_policy" {
  count = local.dedup_enabled ? 1 : 0

  name        = local.log_notifier_lambda_dedup_policy_name
  path        = "/"
  description = "Lets the log notifier remember which messages it has already sent."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.log_notifier_dedup_table[0].arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "log_notifier_lambda_role_dedup_policy_attachment" {
  count = local.dedup_enabled ? 1 : 0

  role       = aws_iam_role.log_notifier_lambda_role.name
  policy_arn = aws_iam_policy.log_notifier_lambda_dedup_policy[0].arn
}
