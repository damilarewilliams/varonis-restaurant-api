# Module: eks
# Managed EKS control plane + managed node group in private subnets,
# OIDC provider for IRSA, and core add-ons.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    # Used to read the cluster's OIDC issuer certificate thumbprint.
    tls = {
      source = "hashicorp/tls"
    }
  }
}

locals {
  cluster_name = "${var.project}-${var.environment}"
}

# ---------------------------------------------------------------------------
# IAM: cluster role — what the EKS control plane itself may do
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${local.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ---------------------------------------------------------------------------
# IAM: node role — the minimum AWS-managed set for worker nodes.
# Note: NO application permissions here. Pods get AWS access via IRSA
# (Issue #10), never via the node instance role — otherwise every pod
# on the node would inherit those permissions.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${local.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",          # join the cluster
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",               # VPC CNI: manage pod ENIs/IPs
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly", # pull images from ECR
  ])

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# ---------------------------------------------------------------------------
# Control-plane log group — created BEFORE the cluster. If EKS creates it
# implicitly on first api/audit log, it gets no encryption and no
# retention; pre-creating it means the audit trail is CMK-encrypted and
# bounded from the first byte.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "control_plane" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.log_group_kms_key_arn != "" ? var.log_group_kms_key_arn : null

  tags = {
    Name = "${local.cluster_name}-control-plane-logs"
  }
}

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------
resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access_cidrs
  }

  # Modern access management: API access entries instead of the legacy
  # aws-auth ConfigMap. The creator gets admin so Terraform can continue
  # managing the cluster (Helm releases for ArgoCD/ARC).
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # API-server audit trail to CloudWatch — part of the logging story.
  enabled_cluster_log_types = var.cluster_log_types

  # IAM must settle before/after the cluster (destroys wedge otherwise);
  # the log group must pre-exist so control-plane logs land encrypted.
  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.control_plane,
  ]
}

# ---------------------------------------------------------------------------
# OIDC provider — the foundation of IRSA. Kubernetes service accounts get
# JWT tokens from this issuer; IAM roles trust the issuer; pods exchange
# the token for role credentials via STS. No static keys anywhere.
# ---------------------------------------------------------------------------
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
}

# ---------------------------------------------------------------------------
# Managed node group — private subnets only
# ---------------------------------------------------------------------------
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.node_instance_types
  disk_size      = var.node_disk_size
  ami_type       = "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  # Rolling node updates: replace one node at a time.
  update_config {
    max_unavailable = 1
  }

  # Let the cluster autoscaler (or Karpenter) own desired_size later
  # without Terraform fighting it on every plan.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

# ---------------------------------------------------------------------------
# Core add-ons — managed by EKS, versions resolved to the cluster default.
# EBS CSI is intentionally omitted: no workload uses persistent volumes;
# adding it means adding its IRSA role — do that when a need exists.
# ---------------------------------------------------------------------------
resource "aws_eks_addon" "core" {
  for_each = toset(["coredns", "kube-proxy"])

  cluster_name = aws_eks_cluster.this.name
  addon_name   = each.value

  # On conflicting self-managed config, prefer the managed add-on.
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.this]
}

# vpc-cni gets its own resource: NetworkPolicy objects are inert unless
# the CNI enforces them (aws-network-policy-agent). Without this flag the
# chart's default-deny policy would silently do nothing — the worst kind
# of security control.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"

  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
  })

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.this]
}
