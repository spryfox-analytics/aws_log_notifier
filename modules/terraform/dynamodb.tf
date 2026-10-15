locals {
  dedup_enabled    = var.dedup_window_in_minutes > 0
  dedup_table_name = "${var.kebab_case_name_prefix}log-notifier-dedup"
}

# Remembers which messages were mailed recently, one item per log group and
# message fingerprint. Items expire through TTL, so the table stays tiny and
# on-demand billing keeps the cost near zero.
resource "aws_dynamodb_table" "log_notifier_dedup_table" {
  count = local.dedup_enabled ? 1 : 0

  name                        = local.dedup_table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "pk"
  deletion_protection_enabled = var.dedup_table_deletion_protection

  attribute {
    name = "pk"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Application = var.application
    Customer    = var.customer
    Name        = local.dedup_table_name
    Project     = var.project
  }
}
