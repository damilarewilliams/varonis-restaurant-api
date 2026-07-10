# Module: fluentbit
# The log shipper: node-level DaemonSet that tails container stdout and
# ships it to the CMK-encrypted CloudWatch log group. Completes the
# logging pipeline: app masks in-process -> stdout -> Fluent Bit ->
# encrypted group (docs/architecture.md §logging).

terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# Namespace + SA are ours, not chart-created: the IRSA annotation must
# match the logging module's trust policy exactly
# (system:serviceaccount:logging:fluent-bit) — same pattern as ARC.
resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_service_account" "this" {
  metadata {
    name      = var.service_account
    namespace = kubernetes_namespace.this.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = var.shipper_role_arn
    }
  }
}

resource "helm_release" "fluent_bit" {
  name      = "fluent-bit"
  namespace = kubernetes_namespace.this.metadata[0].name

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"

  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.this.metadata[0].name
      }

      # Only the app namespace's container logs — platform namespaces
      # (argocd, arc, kube-system) are noise for this log group and
      # would exceed the shipper role's write-only single-group scope.
      input = {
        path = "/var/log/containers/*_${var.app_namespace}_*.log"
      }

      cloudWatchLogs = {
        enabled = true
        region  = var.aws_region
        # The group already exists (Terraform-managed, encrypted,
        # bounded retention); the role cannot create groups — so
        # auto-creation stays off and misconfig fails loudly.
        logGroupName    = var.log_group_name
        autoCreateGroup = false
      }

      # Disable the other default outputs; CloudWatch is the destination.
      firehose      = { enabled = false }
      kinesis       = { enabled = false }
      elasticsearch = { enabled = false }
    }),
  ]
}
