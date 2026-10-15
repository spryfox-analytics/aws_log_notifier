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

variable "kebab_case_name_prefix" {
  type = string
}

variable "camel_case_name_prefix" {
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
  type = string
}

variable "log_notifier_lambda_target_path" {
  type = string
}

variable "filter_pattern" {
  type    = string
  default = null
}

variable "exclude_patterns" {
  type    = list(string)
  default = []
}

variable "dedup_window_in_minutes" {
  type    = number
  default = 60
}

variable "dedup_table_deletion_protection" {
  type    = bool
  default = false
}

variable "max_sample_lines" {
  type    = number
  default = 20
}

variable "email_subject_prefix" {
  type = string
}

variable "log_retention_in_days" {
  type = number
}

variable "lambda_runtime" {
  type    = string
  default = "python3.13"
}
