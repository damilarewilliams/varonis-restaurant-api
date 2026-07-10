# Module: iam
# Every principal in the system gets exactly the permissions its job
# requires — nothing is shared, nothing is account-wide:
#
#   API pod (IRSA)     → read one DynamoDB table
#   ARC runner (IRSA)  → describe the cluster + namespaced view access
#   CI delivery (OIDC) → push to ECR
#   CI terraform (OIDC)→ manage infra, IAM bounded to project-prefixed roles
#
# No principal anywhere uses a static access key.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ===========================================================================
# IRSA role: API pod — DynamoDB read on exactly the restaurants table.
# Trust is scoped to ONE service account in ONE namespace: no other pod
# in the cluster can assume this role.
# ===========================================================================
data "aws_iam_policy_document" "api_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.api_namespace}:${var.api_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api" {
  name               = "${local.name_prefix}-api"
  assume_role_policy = data.aws_iam_policy_document.api_assume.json
}

data "aws_iam_policy_document" "api_dynamodb_read" {
  statement {
    sid = "ReadRestaurantsTable"
    # Read-only: the API recommends, it never writes. Seeding uses the
    # operator's own credentials, not the pod role.
    actions = [
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:DescribeTable",
    ]
    resources = var.dynamodb_table_arns
  }

  statement {
    sid = "DecryptTableData"
    # The table is encrypted with a customer-managed key: DynamoDB
    # decrypts on the caller's behalf, so the caller needs kms:Decrypt
    # on exactly that key. Decrypt only — the API never writes.
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [var.dynamodb_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "api_dynamodb_read" {
  name   = "dynamodb-read"
  role   = aws_iam_role.api.id
  policy = data.aws_iam_policy_document.api_dynamodb_read.json
}

# ===========================================================================
# IRSA role: ARC runner pods — CD verification only.
# AWS-side: describe the cluster (to build a kubeconfig).
# Kubernetes-side: an EKS access entry grants namespaced VIEW access —
# rollout status and health checks need to read, never mutate. ArgoCD
# does the mutating; the runner only verifies.
# ===========================================================================
data "aws_iam_policy_document" "runner_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.runner_namespace}:${var.runner_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "runner" {
  name               = "${local.name_prefix}-cd-runner"
  assume_role_policy = data.aws_iam_policy_document.runner_assume.json
}

data "aws_iam_policy_document" "runner_eks" {
  statement {
    sid       = "DescribeClusterForKubeconfig"
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:aws:eks:*:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"]
  }
}

resource "aws_iam_role_policy" "runner_eks" {
  name   = "eks-describe"
  role   = aws_iam_role.runner.id
  policy = data.aws_iam_policy_document.runner_eks.json
}

resource "aws_eks_access_entry" "runner" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.runner.arn
}

resource "aws_eks_access_policy_association" "runner_view" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.runner.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [var.api_namespace]
  }

  depends_on = [aws_eks_access_entry.runner]
}

# ===========================================================================
# GitHub OIDC provider — GitHub Actions exchanges its job token for
# short-lived AWS credentials. This is what removes AWS access keys
# from GitHub Secrets entirely.
# ===========================================================================
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# ---------------------------------------------------------------------------
# CI role 1: delivery — ECR push only, main branch only.
# The `sub` condition means a job on a PR branch or a fork cannot
# assume this role: only workflows running on refs/heads/main.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "gha_delivery_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "gha_delivery" {
  name               = "${local.name_prefix}-gha-delivery"
  assume_role_policy = data.aws_iam_policy_document.gha_delivery_assume.json
}

data "aws_iam_policy_document" "gha_delivery" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # GetAuthorizationToken does not support resource scoping
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = ["arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/${local.name_prefix}"]
  }
}

resource "aws_iam_role_policy" "gha_delivery" {
  name   = "ecr-push"
  role   = aws_iam_role.gha_delivery.id
  policy = data.aws_iam_policy_document.gha_delivery.json
}

# ---------------------------------------------------------------------------
# CI role 2: terraform — assumable ONLY by jobs running in the protected
# GitHub Environment (the plan/apply approval gate, Issue #15). Broad by
# necessity (it provisions everything), but bounded:
#   - PowerUserAccess denies all IAM writes
#   - the custom statement re-grants IAM strictly on project-prefixed
#     roles/policies, so CI can manage this stack's roles and nothing else
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "gha_terraform_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      # Plan runs in an unprotected environment; apply in the protected
      # one (required reviewers). Same role: the protection difference is
      # enforced by GitHub, the credential scope stays identical.
      values = [
        "repo:${var.github_repository}:environment:${var.terraform_plan_environment}",
        "repo:${var.github_repository}:environment:${var.terraform_apply_environment}",
      ]
    }
  }
}

resource "aws_iam_role" "gha_terraform" {
  name               = "${local.name_prefix}-gha-terraform"
  assume_role_policy = data.aws_iam_policy_document.gha_terraform_assume.json
}

resource "aws_iam_role_policy_attachment" "gha_terraform_poweruser" {
  role       = aws_iam_role.gha_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "gha_terraform_iam" {
  statement {
    sid = "ManageProjectScopedIam"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:CreateServiceLinkedRole",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name_prefix}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/*",
    ]
  }

  statement {
    sid = "ManageOidcProviders"
    actions = [
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/*"]
  }
}

resource "aws_iam_role_policy" "gha_terraform_iam" {
  name   = "iam-project-scoped"
  role   = aws_iam_role.gha_terraform.id
  policy = data.aws_iam_policy_document.gha_terraform_iam.json
}

# Terraform manages in-cluster resources (namespaces, Helm releases for
# ArgoCD/ARC/Fluent Bit), so the CI terraform role also needs KUBERNETES
# credentials, not just AWS ones — an EKS access entry. Without it the
# kubernetes/helm providers get "Unauthorized" in CI: the cluster creator
# (local operator) receives an admin access entry automatically, a CI
# role does not. Cluster-scoped admin is warranted here — this role
# provisions the platform itself. The runner role above stays namespaced
# view-only; the asymmetry is deliberate.
resource "aws_eks_access_entry" "gha_terraform" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.gha_terraform.arn
}

resource "aws_eks_access_policy_association" "gha_terraform_admin" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.gha_terraform.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.gha_terraform]
}
