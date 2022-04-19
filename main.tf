module "log_notifier" {
  source = "./modules/terraform"

  application = var.application
  aws_region = var.aws_region
  camel_case_name_prefix = var.camel_case_name_prefix
  customer = var.customer
  deployment_user_name = var.deployment_user_name
  email_subject_prefix = var.email_subject_prefix
  filter_pattern = var.filter_pattern
  log_receiver_email_address = var.log_receiver_email_address
  kebab_case_name_prefix =var.kebab_case_name_prefix
  log_group_arn = var.log_group_arn
  log_group_name = var.log_group_name
  log_notifier_lambda_name_src_file_path = var.log_notifier_lambda_name_src_file_path
  log_notifier_lambda_target_path = var.log_notifier_lambda_target_path
  project = var.project
}
