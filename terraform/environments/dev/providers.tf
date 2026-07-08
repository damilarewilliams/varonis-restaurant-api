# AWS provider configuration.
#
# No credentials here — ever. Locally the provider resolves the ambient
# AWS profile; in CI it uses the OIDC-assumed role (Issue #14).
#
# default_tags stamps every resource this configuration creates, giving
# cost attribution and "who manages this?" answers for free.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "damilarewilliams/varonis-restaurant-api"
    }
  }
}
