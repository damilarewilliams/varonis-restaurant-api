# Module: dynamodb
# Restaurant catalog table.

locals {
  table_name = "${var.project}-${var.environment}-${var.table_suffix}"
}

resource "aws_dynamodb_table" "this" {
  name = local.table_name

  # On-demand capacity: no capacity planning, pay per request, scales to
  # zero cost when idle - the right default for a small, spiky catalog.
  # Provisioned capacity only wins with sustained, predictable traffic.
  billing_mode = "PAY_PER_REQUEST"

  # Simple primary key. The API's access pattern is scan-with-filters
  # over a small bounded catalog (documented trade-off in
  # app/repositories/dynamodb.py); a GSI on `style` is the documented
  # evolution when the catalog grows.
  hash_key = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # Encryption at rest with our customer-managed key - auditable usage
  # via CloudTrail, revocable, rotated annually (kms module).
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  # Continuous backups: restore to any second in the last 35 days.
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Refuse table deletion (console or terraform destroy) until the flag
  # is flipped - data outlives infrastructure mistakes. Dev may disable.
  deletion_protection_enabled = var.deletion_protection

  tags = {
    Name = local.table_name
  }
}
