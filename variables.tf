variable "application" {
  type = string
}

variable "customer" {
  type = string
}

variable "project" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "camel_case_name_prefix" {
  type = string
}

variable "email_subject_prefix" {
  type = string
}

variable "filter_pattern" {
  type        = string
  default     = null
  description = "CloudWatch Logs filter pattern of the subscription. Null uses the built-in pattern for ERROR/FATAL/CRITICAL log levels and runtime failures (output default_filter_pattern)."
}

variable "exclude_patterns" {
  type        = list(string)
  default     = []
  description = "Python regular expressions; matching log lines are dropped before the e-mail is built (e.g. expected messages)."
}

variable "dedup_window_in_minutes" {
  type        = number
  default     = 60
  description = "Identical messages (after normalising timestamps, ids and numbers) of a log group are mailed at most once per window. 0 turns de-duplication off and creates no DynamoDB table."
}

variable "dedup_table_deletion_protection" {
  type        = bool
  default     = false
  description = "Deletion protection of the de-duplication table."
}

variable "max_sample_lines" {
  type        = number
  default     = 20
  description = "Maximum number of log lines quoted in one e-mail."
}

variable "kebab_case_name_prefix" {
  type = string
}

variable "log_group_arn" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "log_receiver_email_address" {
  type = string
}

variable "log_notifier_lambda_name_src_file_path" {
  type    = string
  default = "../python/lambda_function.py"
}

variable "log_notifier_lambda_target_path" {
  type    = string
  default = "../target/lambda_function.zip"
}

variable "log_retention_in_days" {
  type = number
}

variable "lambda_runtime" {
  type        = string
  default     = "python3.13"
  description = "Python runtime of the notifier Lambda."
}
