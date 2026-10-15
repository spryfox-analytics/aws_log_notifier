locals {
  # Log levels and runtime failures instead of any "error" substring, which
  # also matched class names such as PrismaClientInitializationError in WARN
  # lines. Terms are case-sensitive substrings; "?" combines them with OR.
  default_filter_terms = [
    "\tERROR\t",           # Lambda text logs (Node.js console.error, Python logging)
    "[ERROR]",             # Lambda Python, "[%(levelname)s]" formats
    " ERROR ",             # "%(asctime)s ERROR ..." and " - ERROR - " formats
    "ERROR:",              # Python default format "ERROR:root:...", Scrapy "ERROR: ..."
    "\"level\":\"ERROR\"", # JSON logs (Lambda JSON log format, structured loggers)
    "\"level\": \"ERROR\"",
    "\"level\":\"error\"",
    "\"level\": \"error\"",
    "\"levelname\":\"ERROR\"",
    "\"levelname\": \"ERROR\"",
    "\tFATAL\t",
    "[CRITICAL]",
    " CRITICAL ",
    "CRITICAL:",
    "\"level\":\"FATAL\"",
    "\"level\":\"fatal\"",
    "\"level\": \"CRITICAL\"",
    "Traceback (most recent call last)", # uncaught Python exceptions
    "Task timed out",
    "Runtime exited",
    "Process exited before completing",
    "Runtime.ImportModuleError",
    "Runtime.HandlerNotFound",
    "Runtime.UserCodeSyntaxError",
  ]
  default_filter_pattern = join(" ", [for term in local.default_filter_terms : "?\"${replace(term, "\"", "\\\"")}\""])
}

resource "aws_cloudwatch_log_subscription_filter" "log_notifier_cloudwatch_log_subscription_filter" {
  depends_on      = [aws_lambda_permission.log_notifier_lambda_permission]
  name            = "${var.kebab_case_name_prefix}log-notifier-cloudwatch-log-subscription-filter"
  log_group_name  = var.log_group_name
  filter_pattern  = coalesce(var.filter_pattern, local.default_filter_pattern)
  destination_arn = aws_lambda_function.log_notifier_lambda.arn
}

resource "aws_cloudwatch_log_group" "log_notifier_lambda_log_group" {
  name              = "/aws/lambda/${local.log_notifier_lambda_name}"
  retention_in_days = var.log_retention_in_days
}
