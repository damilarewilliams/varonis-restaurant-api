# Module: kms
# One customer-managed key (CMK) per purpose. Instantiate the module once
# per concern (data, logs) rather than sharing a single key everywhere:
# separate keys mean separate access policies and separate blast radius.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  alias = "${var.project}-${var.environment}-${var.purpose}"
}

data "aws_iam_policy_document" "key" {
  # Root account retains full key administration - without this statement
  # the key can become unmanageable (a locked-out CMK is unrecoverable).
  statement {
    sid       = "EnableRootAccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # CloudWatch Logs is a service principal: log groups encrypted with a
  # CMK need the service granted use of the key, scoped to this account's
  # log groups via the encryption context condition.
  dynamic "statement" {
    for_each = var.allow_cloudwatch_logs ? [1] : []

    content {
      sid = "AllowCloudWatchLogs"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:Describe*",
      ]
      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
      }

      condition {
        test     = "ArnLike"
        variable = "kms:EncryptionContext:aws:logs:arn"
        values   = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
      }
    }
  }
}

resource "aws_kms_key" "this" {
  description = "CMK for ${local.alias}"
  policy      = data.aws_iam_policy_document.key.json

  # Annual automatic rotation: AWS rotates the backing key material,
  # old material is retained for decrypting existing data.
  enable_key_rotation = true

  # Window to recover from an accidental scheduled deletion.
  deletion_window_in_days = var.deletion_window_in_days

  tags = {
    Name = local.alias
  }
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.alias}"
  target_key_id = aws_kms_key.this.key_id
}
