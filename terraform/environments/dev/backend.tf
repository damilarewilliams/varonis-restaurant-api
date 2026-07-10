# Remote state: S3 with native lockfile locking (ADR-006).
#
# Why remote state: local state files can't be shared, reviewed, or
# locked; CI and engineers must see the same state.
# Why S3-native locking (use_lockfile) over a DynamoDB lock table:
# supported since Terraform 1.10, one less resource to provision and
# pay for, same protection against concurrent applies.
#
# BOOTSTRAP (one-time, before first `terraform init`) — the state
# bucket cannot manage itself, so it is created once via CLI:
#
#   aws s3api create-bucket --bucket varonis-restaurant-api-tfstate-b \
#       --region us-east-1
#   aws s3api put-bucket-versioning --bucket varonis-restaurant-api-tfstate-b \
#       --versioning-configuration Status=Enabled
#   aws s3api put-bucket-encryption --bucket varonis-restaurant-api-tfstate-b \
#       --server-side-encryption-configuration \
#       '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"}}]}'
#   aws s3api put-public-access-block --bucket varonis-restaurant-api-tfstate-b \
#       --public-access-block-configuration \
#       BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
#
# Versioning = state history/recovery. Encryption = state contains
# resource IDs and can contain secrets. Public access block = obvious.
#
# NOTE: S3 bucket names are globally unique — if this name is taken,
# suffix it with your AWS account ID and update `bucket` below.

terraform {
  backend "s3" {
    bucket       = "varonis-restaurant-api-tfstate-b"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
