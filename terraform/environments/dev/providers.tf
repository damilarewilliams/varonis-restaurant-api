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

# Helm provider — targets the EKS cluster Terraform itself created.
# Auth uses `aws eks get-token` (exec plugin): short-lived tokens from the
# caller's IAM identity, no kubeconfig file dependency. This is how
# Terraform installs in-cluster platform components (ArgoCD, ADR-004)
# while remaining the bootstrap tool that works before ArgoCD exists.
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}
