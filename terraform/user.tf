locals {
  error_log_notifier_deployment_user_policy_name = "${var.camel_case_name_prefix}ErrorLogNotifierDeploymentUserPolicy"
}

resource "aws_iam_policy" "error_log_notifier_deployment_user_policy" {
  name = local.error_log_notifier_deployment_user_policy_name
  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: [
          "iam:Describe*",
          "lambda:Describe*",
          "logs:Describe*",
          "sns:Describe*"
        ],
        Resource: [
          "*"
        ]
      },
      {
        Effect: "Allow",
        Action: [
          "iam:Get*",
          "iam:List*",
          "lambda:Get*",
          "lambda:List*",
          "logs:Get*",
          "logs:List*",
          "sns:Get*",
          "sns:List*"
        ],
        Resource: [
          "${aws_cloudwatch_log_group.error_log_notifier_lambda_log_group.arn}*",
          "${aws_iam_role.error_log_notifier_lambda_role.arn}*",
          "${aws_lambda_function.error_log_notifier_lambda.arn}*",
          "${aws_sns_topic.error_log_notifier_sns_topic.arn}*"
        ]
      },
      {
        Effect: "Allow",
        Action: [
          "sns:List*",
        ],
        Resource: [
          "*"
        ]
      },
      {
        Effect : "Allow",
        Action : [
          "lambda:PublishVersion",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration"
        ],
        Resource : [
          aws_lambda_function.error_log_notifier_lambda.arn,
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "error_log_notifier_deployment_user_policy_attachment" {
  user = var.deployment_user_name
  policy_arn = aws_iam_policy.error_log_notifier_deployment_user_policy.arn
}
