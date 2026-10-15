module "log_notifier" {
  source = "./modules/terraform"

  application                            = var.application
  aws_region                             = var.aws_region
  camel_case_name_prefix                 = var.camel_case_name_prefix
  customer                               = var.customer
  email_subject_prefix                   = var.email_subject_prefix
  filter_pattern                         = var.filter_pattern
  exclude_patterns                       = var.exclude_patterns
  dedup_window_in_minutes                = var.dedup_window_in_minutes
  dedup_table_deletion_protection        = var.dedup_table_deletion_protection
  max_sample_lines                       = var.max_sample_lines
  lambda_runtime                         = var.lambda_runtime
  log_receiver_email_address             = var.log_receiver_email_address
  log_retention_in_days                  = var.log_retention_in_days
  kebab_case_name_prefix                 = var.kebab_case_name_prefix
  log_group_arn                          = var.log_group_arn
  log_group_name                         = var.log_group_name
  log_notifier_lambda_name_src_file_path = var.log_notifier_lambda_name_src_file_path
  log_notifier_lambda_target_path        = var.log_notifier_lambda_target_path
  project                                = var.project
}
