# Terraform and provider version constraints.
#
# - required_version >= 1.10: needed for S3-native state locking
#   (`use_lockfile`), which removes the DynamoDB lock-table dependency.
# - AWS provider: bounded range rather than an exact pin; the exact
#   version is pinned by .terraform.lock.hcl (committed), which is what
#   guarantees reproducible CI runs.

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70, < 7.0"
    }
  }
}
