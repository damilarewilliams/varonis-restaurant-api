# dev environment — module composition root.
#
# Each module call below is enabled by the issue that implements the
# module. Keeping the wiring visible-but-commented documents the target
# architecture while letting `terraform validate` pass at every commit.

# ---------------------------------------------------------------------------
# Issue #6 — Provision AWS Networking
# ---------------------------------------------------------------------------
module "networking" {
  source = "../../modules/networking"

  project     = var.project
  environment = var.environment
  vpc_cidr    = "10.0.0.0/16"
  az_count    = 3

  # dev cost mode: one shared NAT (~$32/mo) instead of one per AZ.
  # Production would set this false for AZ-fault-isolated egress.
  single_nat_gateway = true

  # Deterministic cluster name (created in Issue #7); enables the
  # kubernetes.io/cluster subnet tags for LB subnet discovery now.
  cluster_name = "${var.project}-${var.environment}"
}

# ---------------------------------------------------------------------------
# Issue #7 — Provision Amazon EKS
# ---------------------------------------------------------------------------
module "eks" {
  source = "../../modules/eks"

  project            = var.project
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  # dev sizing: 2 small nodes, room to scale to 4.
  node_instance_types = ["t3.medium"]
  node_min_size       = 2
  node_desired_size   = 2
  node_max_size       = 4

  # Public endpoint for GitHub-hosted runners + local kubectl.
  # TODO: narrow to known CIDRs; private-only is the hardened posture.
  endpoint_public_access       = true
  endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # Control-plane log group is created inside the eks module (before the
  # cluster) so audit logs are CMK-encrypted from the first byte.
  log_group_kms_key_arn = module.kms_logs.key_arn
}

# ---------------------------------------------------------------------------
# Issue #8 — Provision Amazon ECR
# ---------------------------------------------------------------------------
module "ecr" {
  source = "../../modules/ecr"

  project     = var.project
  environment = var.environment
}

# ---------------------------------------------------------------------------
# Issue #9 — Provision DynamoDB (+ the data CMK it encrypts with)
# ---------------------------------------------------------------------------
module "kms_data" {
  source = "../../modules/kms"

  project     = var.project
  environment = var.environment
  purpose     = "data"
}

module "dynamodb" {
  source = "../../modules/dynamodb"

  project     = var.project
  environment = var.environment
  kms_key_arn = module.kms_data.key_arn

  # dev: allow terraform destroy to work; production keeps this true.
  deletion_protection = false
}

# ---------------------------------------------------------------------------
# Issue #10 — Provision IAM Roles and Policies
# ---------------------------------------------------------------------------
module "iam" {
  source = "../../modules/iam"

  project             = var.project
  environment         = var.environment
  cluster_name        = module.eks.cluster_name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
  dynamodb_table_arns = [module.dynamodb.table_arn]
  github_repository   = "damilarewilliams/varonis-restaurant-api"
}

# ---------------------------------------------------------------------------
# Issue #11 — Provision Logging Infrastructure (own CMK: separate blast
# radius from the data key; needs the CloudWatch Logs service grant)
# ---------------------------------------------------------------------------
module "kms_logs" {
  source = "../../modules/kms"

  project               = var.project
  environment           = var.environment
  purpose               = "logs"
  allow_cloudwatch_logs = true
}

module "logging" {
  source = "../../modules/logging"

  project     = var.project
  environment = var.environment
  kms_key_arn       = module.kms_logs.key_arn
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}
