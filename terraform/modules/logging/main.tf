# Module: logging
# Logs are treated as sensitive data (docs/architecture.md §logging):
# KMS-encrypted log groups, bounded retention, and a write-only shipper
# identity. Masking already happened in-process (app/core/logging.py) —
# this module is the encrypted, access-controlled destination.

locals {
  name_prefix        = "${var.project}-${var.environment}"
  app_log_group_name = "/${var.project}/${var.environment}/application"
}

# ---------------------------------------------------------------------------
# Application log group — Fluent Bit ships container stdout here.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = local.app_log_group_name
  retention_in_days = var.retention_in_days
  kms_key_id        = var.kms_key_arn

  tags = {
    Name = "${local.name_prefix}-app-logs"
  }
}

# NOTE: the EKS control-plane log group lives in the eks module (created
# there BEFORE the cluster so api/audit logs land encrypted and bounded
# from the first byte). It cannot live here: this module consumes eks
# outputs for the shipper role, so eks-depends-on-logging would be a cycle.

# ---------------------------------------------------------------------------
# IRSA role: log shipper (Fluent Bit DaemonSet) — WRITE-ONLY.
# It can create streams and put events in the app log group; it cannot
# read logs back, cannot touch other log groups, and cannot change
# retention. Writers write; reading is a separate human concern.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "shipper_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.shipper_namespace}:${var.shipper_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "shipper" {
  name               = "${local.name_prefix}-log-shipper"
  assume_role_policy = data.aws_iam_policy_document.shipper_assume.json
}

data "aws_iam_policy_document" "shipper_write" {
  statement {
    sid = "WriteAppLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = [
      aws_cloudwatch_log_group.app.arn,
      "${aws_cloudwatch_log_group.app.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "shipper_write" {
  name   = "cloudwatch-write-only"
  role   = aws_iam_role.shipper.id
  policy = data.aws_iam_policy_document.shipper_write.json
}
